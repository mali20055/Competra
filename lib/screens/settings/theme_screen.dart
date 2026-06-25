import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/player_avatar.dart';
import '../../core/theme/app_themes.dart';
import '../../core/theme/theme_notifier.dart';
import '../../models/avatar_frame.dart';
import '../../router/route_paths.dart';
import '../../services/firebase_providers.dart';
import '../../services/user_repository.dart';

class ThemeScreen extends ConsumerStatefulWidget {
  const ThemeScreen({super.key});

  @override
  ConsumerState<ThemeScreen> createState() => _ThemeScreenState();
}

class _ThemeScreenState extends ConsumerState<ThemeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleThemeSelection(AppThemeConfig config) async {
    final isPremium = ref.read(isPremiumProvider).value ?? false;
    if (config.isPremium && !isPremium) {
      context.pushNamed(RoutePaths.premiumName);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${config.name} teması Competra Pro abonelerine özeldir!')),
      );
      return;
    }

    setState(() => _isProcessing = true);
    try {
      await ref.read(themeNotifierProvider.notifier).setTheme(config.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${config.name} teması uygulandı.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tema uygulanamadı: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _handleFrameSelection(String frameId) async {
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;

    setState(() => _isProcessing = true);
    try {
      await ref.read(firestoreProvider).collection('users').doc(uid).update({
        'activeFrame': frameId,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Çerçeve başarıyla etkinleştirildi.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Çerçeve seçilemedi: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _handleFramePurchase(AvatarFrame frame) async {
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${frame.name} Satın Al'),
        content: Text('${frame.priceLabel} karşılığında bu çerçeveyi kalıcı olarak açmak istiyor musunuz?\n\n(Bu bir demo IAP simülasyonudur.)'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Satın Al'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);
    try {
      // SharedPreferences / Firestore güncelleyerek satın alınanları ekle ve etkinleştir
      final userDocRef = ref.read(firestoreProvider).collection('users').doc(uid);
      await ref.read(firestoreProvider).runTransaction((transaction) async {
        final snapshot = await transaction.get(userDocRef);
        final currentPurchased = List<String>.from(snapshot.data()?['purchasedFrames'] as List? ?? []);
        if (!currentPurchased.contains(frame.id)) {
          currentPurchased.add(frame.id);
        }
        transaction.update(userDocRef, {
          'purchasedFrames': currentPurchased,
          'activeFrame': frame.id,
        });
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${frame.name} başarıyla satın alındı ve etkinleştirildi!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Satın alma başarısız: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final selectedTheme = ref.watch(themeNotifierProvider);
    final isPremium = ref.watch(isPremiumProvider).value ?? false;
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kişiselleştirme'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: scheme.primary,
          labelColor: scheme.primary,
          unselectedLabelColor: scheme.onSurfaceVariant,
          tabs: const [
            Tab(text: 'Uygulama Temaları'),
            Tab(text: 'Kozmetik Çerçeveler'),
          ],
        ),
      ),
      body: _isProcessing
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // TAB 1: Uygulama Temaları
                _buildThemesTab(theme, scheme, selectedTheme),
                // TAB 2: Kozmetik Çerçeveler
                _buildFramesTab(theme, scheme, isPremium, profileAsync),
              ],
            ),
    );
  }

  Widget _buildThemesTab(ThemeData theme, ColorScheme scheme, AppThemeId selectedTheme) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: AppThemes.themes.values.map((config) {
        final isSelected = config.id == selectedTheme;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Card(
            elevation: isSelected ? 4 : 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: isSelected ? scheme.primary : scheme.outline.withValues(alpha: 0.2),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: InkWell(
              onTap: () => _handleThemeSelection(config),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    // Theme color indicator dots
                    Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: config.lightScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: config.lightScheme.secondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 36,
                          height: 16,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: config.darkScheme.surface,
                          ),
                          child: Center(
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: config.darkScheme.primary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            config.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (config.isPremium) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFFFD700), width: 0.5),
                              ),
                              child: Text(
                                'Competra Pro',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: const Color(0xFFFFB300),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (isSelected)
                      Icon(Icons.check_circle, color: scheme.primary, size: 28)
                    else if (config.isPremium)
                      const Icon(Icons.lock_outline, color: Colors.grey, size: 24),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFramesTab(ThemeData theme, ColorScheme scheme, bool isPremium, AsyncValue profileAsync) {
    return profileAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Hata: $err')),
      data: (profile) {
        if (profile == null) {
          return const Center(child: Text('Kullanıcı profili yüklenemedi.'));
        }

        final activeFrameId = profile.activeFrame;
        final purchasedFrames = profile.purchasedFrames;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: AvatarFrame.frames.values.map((frame) {
            final isCurrentlyActive = frame.id == activeFrameId;
            final isUnlocked = !frame.isPremium || isPremium || purchasedFrames.contains(frame.id);

            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Card(
                elevation: isCurrentlyActive ? 3 : 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isCurrentlyActive ? scheme.primary : scheme.outline.withValues(alpha: 0.2),
                    width: isCurrentlyActive ? 2 : 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      // Avatar frame preview
                      PlayerAvatar(
                        name: profile.username.isNotEmpty ? profile.username : 'Oyuncu',
                        radius: 24,
                        activeFrame: frame.id,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              frame.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              frame.description,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            if (frame.isPremium && !isPremium && !purchasedFrames.contains(frame.id)) ...[
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFD700).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Pro veya Satın Alınabilir',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: const Color(0xFFFFB300),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Action Button
                      if (isCurrentlyActive)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Aktif',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      else if (isUnlocked)
                        ElevatedButton(
                          onPressed: () => _handleFrameSelection(frame.id),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(80, 36),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('Seç', style: TextStyle(fontSize: 13)),
                        )
                      else
                        ElevatedButton.icon(
                          onPressed: () => _handleFramePurchase(frame),
                          icon: const Icon(Icons.shopping_cart_outlined, size: 14),
                          label: Text(frame.priceLabel, style: const TextStyle(fontSize: 13)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFD700),
                            foregroundColor: Colors.black,
                            minimumSize: const Size(100, 36),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
