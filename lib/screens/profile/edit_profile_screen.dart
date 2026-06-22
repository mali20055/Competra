import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/firebase_providers.dart';
import '../../services/user_repository.dart';

/// Profil düzenleme ekranı.
///
/// Profil fotoğrafı (galeriden seçilip Firebase Storage'a yüklenir), biyografi
/// ve favori takım düzenlenebilir; kullanıcı adı salt-okunurdur. Kaydedince
/// `users/{uid}` belgesi güncellenir. Tüm renkler tema üzerinden gelir.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  static const int _bioMaxLength = 150;

  final _bioController = TextEditingController();
  final _teamController = TextEditingController();

  String _username = 'Oyuncu';
  String _photoUrl = '';
  String _coverUrl = '';
  XFile? _pickedImage;
  XFile? _pickedCover;

  bool _uploading = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Mevcut profil değerlerini başlangıçta doldur.
    final profile = ref.read(userProfileProvider).asData?.value;
    if (profile != null) {
      _username = profile.username;
      _photoUrl = profile.photoUrl;
      _coverUrl = profile.coverUrl;
      _bioController.text = profile.bio;
      _teamController.text = profile.favoriteTeam;
    }
  }

  @override
  void dispose() {
    _bioController.dispose();
    _teamController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_saving) return;
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1024,
      );
      if (image == null) return;
      setState(() => _pickedImage = image);
    } catch (_) {
      if (mounted) _showError('Fotoğraf seçilemedi.');
    }
  }

  Future<void> _pickCover() async {
    if (_saving) return;
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1600,
      );
      if (image == null) return;
      setState(() => _pickedCover = image);
    } catch (_) {
      if (mounted) _showError('Kapak fotoğrafı seçilemedi.');
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final user = ref.read(currentUserProvider);
    if (user == null) {
      _showError('Oturum bulunamadı.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _saving = true);

    try {
      final repo = ref.read(userRepositoryProvider);

      // Yeni profil ve/veya kapak fotoğrafı seçildiyse önce Storage'a yükle.
      String? photoUrl;
      String? coverUrl;
      if (_pickedImage != null || _pickedCover != null) {
        setState(() => _uploading = true);
        if (_pickedImage != null) {
          photoUrl = await repo.uploadProfilePhoto(
            uid: user.uid,
            file: File(_pickedImage!.path),
          );
        }
        if (_pickedCover != null) {
          coverUrl = await repo.uploadCoverPhoto(
            uid: user.uid,
            file: File(_pickedCover!.path),
          );
        }
        if (mounted) setState(() => _uploading = false);
      }

      await repo.updateProfile(
        uid: user.uid,
        bio: _bioController.text.trim(),
        favoriteTeam: _teamController.text.trim(),
        photoUrl: photoUrl,
        coverUrl: coverUrl,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil güncellendi ✓')),
      );
      context.pop();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _uploading = false;
      });
      _showError('Bir hata oluştu');
    }
  }

  void _showError(String message) {
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, style: TextStyle(color: scheme.onError)),
          backgroundColor: scheme.error,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profili Düzenle'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(
              'Kaydet',
              style: TextStyle(
                color: _saving ? scheme.onSurfaceVariant : scheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // Kapak fotoğrafı alanı (tam genişlik, 160dp).
            _buildCoverArea(theme, scheme),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
            // Profil fotoğrafı + kamera overlay.
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircleAvatar(
                      radius: 56,
                      backgroundColor: scheme.surface,
                      backgroundImage: _avatarImage(),
                      child: _avatarImage() == null
                          ? Text(
                              _initials(_username),
                              style: theme.textTheme.headlineMedium?.copyWith(
                                color: scheme.primary,
                                fontWeight: FontWeight.w800,
                              ),
                            )
                          : null,
                    ),
                    // Yükleme sırasında ilerleme göstergesi.
                    if (_uploading)
                      Container(
                        width: 112,
                        height: 112,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: scheme.onPrimary,
                          ),
                        ),
                      ),
                    // Kamera ikonu overlay (sağ alt).
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.scaffoldBackgroundColor,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          Icons.photo_camera,
                          size: 18,
                          color: scheme.onPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Fotoğrafı değiştirmek için dokun',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Kullanıcı adı (salt-okunur).
            _FieldLabel('Kullanıcı Adı'),
            const SizedBox(height: 6),
            TextFormField(
              initialValue: _username,
              enabled: false,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                'Kullanıcı adı değiştirilemez',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Biyografi (çok satırlı, 150 karakter sınırı + sayaç).
            _FieldLabel('Biyografi'),
            const SizedBox(height: 6),
            TextField(
              controller: _bioController,
              maxLines: 3,
              maxLength: _bioMaxLength,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Kendinden kısaca bahset…',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),

            // Favori takım.
            _FieldLabel('Favori Takım'),
            const SizedBox(height: 6),
            TextField(
              controller: _teamController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                hintText: 'Favori takımın',
                prefixIcon: Icon(Icons.favorite_outline),
              ),
            ),
            const SizedBox(height: 32),

            // Kaydet (tam genişlik, primary).
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: scheme.onPrimary,
                        ),
                      )
                    : const Text('Kaydet'),
              ),
            ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Kapak fotoğrafı alanı: tam genişlik 160dp, dokununca galeriden seçim,
  /// sağ altta kamera rozeti; yükleme sırasında ilerleme göstergesi.
  Widget _buildCoverArea(ThemeData theme, ColorScheme scheme) {
    final cover = _coverImage();
    return GestureDetector(
      onTap: _pickCover,
      child: SizedBox(
        height: 160,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (cover != null)
              Image(image: cover, fit: BoxFit.cover)
            else
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      scheme.primary.withValues(alpha: 0.85),
                      scheme.primary.withValues(alpha: 0.35),
                    ],
                  ),
                ),
              ),
            // Kamera rozeti (sağ alt).
            Positioned(
              right: 12,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: scheme.surface.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                  border: Border.all(color: scheme.primary.withValues(alpha: 0.4)),
                ),
                child: Icon(Icons.photo_camera, size: 18, color: scheme.primary),
              ),
            ),
            if (_uploading)
              ColoredBox(
                color: Colors.black.withValues(alpha: 0.35),
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: scheme.onPrimary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Kapak önizlemesi: seçili dosya > mevcut URL > yok (degrade gösterilir).
  ImageProvider? _coverImage() {
    if (_pickedCover != null) return FileImage(File(_pickedCover!.path));
    if (_coverUrl.isNotEmpty) return NetworkImage(_coverUrl);
    return null;
  }

  /// Önizleme için avatar görseli: seçili dosya > mevcut URL > yok (baş harf).
  ImageProvider? _avatarImage() {
    if (_pickedImage != null) return FileImage(File(_pickedImage!.path));
    if (_photoUrl.isNotEmpty) return NetworkImage(_photoUrl);
    return null;
  }

  String _initials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.substring(0, trimmed.length >= 2 ? 2 : 1).toUpperCase();
  }
}

/// Form alanı üst etiketi (diğer ekranlarla tutarlı stil).
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
