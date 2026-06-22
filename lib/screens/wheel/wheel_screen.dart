import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/wheel.dart';
import '../../services/firebase_providers.dart';
import '../../services/wheel_repository.dart';

/// Çark sekmesi.
///
/// Kullanıcının Firestore'da kayıtlı çarklarını listeler; seçili çarkı bir
/// [CustomPainter] ile dairesel olarak çizer ve "ÇEVİR" ile ease-out yavaşlayan
/// bir dönüş animasyonu sonrası rastgele bir takımı seçer. FAB ile yeni çark
/// oluşturulabilir.
class WheelScreen extends ConsumerStatefulWidget {
  const WheelScreen({super.key});

  @override
  ConsumerState<WheelScreen> createState() => _WheelScreenState();
}

class _WheelScreenState extends ConsumerState<WheelScreen>
    with SingleTickerProviderStateMixin {
  final Random _random = Random();

  late final AnimationController _spinController;
  late Animation<double> _spinAnimation;

  double _rotation = 0;
  bool _isSpinning = false;
  String? _selectedId;
  int? _resultIndex;

  // Haptic "tıkırtı" için: dönerken geçilen dilim sayısı ve son tetiklenen dilim.
  int _currentSpinSlices = 0;
  int? _lastTickIndex;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    );
    _spinAnimation = const AlwaysStoppedAnimation(0);
    // Dönüş boyunca her dilim geçişinde hafif titreşim (ratchet hissi).
    _spinController.addListener(_onSpinTick);
  }

  @override
  void dispose() {
    _spinController.removeListener(_onSpinTick);
    _spinController.dispose();
    super.dispose();
  }

  /// Dönerken, çark bir dilim genişliği kadar döndüğünde hafif titreşim verir.
  void _onSpinTick() {
    if (!_isSpinning || _currentSpinSlices < 2) return;
    final sweep = 2 * pi / _currentSpinSlices;
    final index = (_spinAnimation.value / sweep).floor() % _currentSpinSlices;
    if (index != _lastTickIndex) {
      _lastTickIndex = index;
      HapticFeedback.mediumImpact();
    }
  }

  /// Gelen listeden seçili çarkı çözer (seçim yoksa ilki).
  Wheel? _resolveSelected(List<Wheel> wheels) {
    if (wheels.isEmpty) return null;
    return wheels.firstWhere(
      (w) => w.id == _selectedId,
      orElse: () => wheels.first,
    );
  }

  void _select(Wheel wheel) {
    if (_isSpinning) return;
    setState(() {
      _selectedId = wheel.id;
      _resultIndex = null;
    });
  }

  void _spin(Wheel wheel) {
    final n = wheel.teams.length;
    if (_isSpinning || n < 2) return;

    final sweep = 2 * pi / n;
    final target = _random.nextInt(n);
    const pointer = 3 * pi / 2; // çark tepesindeki sabit gösterge
    final targetCenter = target * sweep + sweep / 2;

    double desired = (pointer - targetCenter) % (2 * pi);
    if (desired < 0) desired += 2 * pi;
    double currentNorm = _rotation % (2 * pi);
    if (currentNorm < 0) currentNorm += 2 * pi;
    double delta = desired - currentNorm;
    if (delta < 0) delta += 2 * pi;

    final end = _rotation + 2 * pi * 5 + delta; // 5 tam tur + hedefe hizalama
    _spinAnimation = Tween<double>(begin: _rotation, end: end).animate(
      CurvedAnimation(parent: _spinController, curve: Curves.easeOutQuart),
    );

    setState(() {
      _isSpinning = true;
      _resultIndex = null;
      _currentSpinSlices = n;
      _lastTickIndex = null;
    });

    _spinController.forward(from: 0).whenComplete(() {
      if (!mounted) return;
      setState(() {
        _rotation = end;
        _isSpinning = false;
        _resultIndex = target;
      });
      // Sonuç açıklandı → güçlü titreşim + geçmişe kaydet.
      HapticFeedback.heavyImpact();
      _recordResult(wheel, wheel.teams[target]);
    });
  }

  /// Sonucu çarkın geçmişine (Firestore) yazar; hata sessizce yutulur.
  Future<void> _recordResult(Wheel wheel, String result) async {
    try {
      await ref.read(wheelRepositoryProvider).recordResult(
            wheelId: wheel.id,
            result: result,
            previous: wheel.lastResults,
          );
    } catch (_) {
      // Geçmiş kaydı kritik değil; sessizce geç.
    }
  }

  /// Çarkı onay alarak Firestore'dan siler.
  Future<void> _confirmDelete(Wheel wheel) async {
    if (_isSpinning) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Çarkı Sil'),
        content: Text(
          '"${wheel.name}" çarkını silmek istediğine emin misin? '
          'Bu işlem geri alınamaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Sil',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(wheelRepositoryProvider).deleteWheel(wheel.id);
      if (mounted && _selectedId == wheel.id) {
        // Silinen çark seçiliyse seçim sıfırlanır (ilki seçilecek).
        setState(() => _selectedId = null);
      }
    } catch (_) {
      if (!mounted) return;
      final scheme = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Çark silinemedi. Lütfen tekrar deneyin.',
            style: TextStyle(color: scheme.onError),
          ),
          backgroundColor: scheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final wheelsAsync = ref.watch(myWheelsStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Çark')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isSpinning ? null : _openCreateSheet,
        icon: const Icon(Icons.add),
        label: const Text('Yeni Çark'),
      ),
      body: wheelsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const _EmptyState(
          icon: Icons.cloud_off_outlined,
          title: 'Çarklar yüklenemedi',
          message: 'Lütfen daha sonra tekrar dene.',
        ),
        data: (wheels) {
          if (wheels.isEmpty) {
            return const _EmptyState(
              icon: Icons.donut_large_outlined,
              title: 'Henüz çarkın yok',
              message:
                  'Sağ alttaki "Yeni Çark" ile bir takım çarkı oluştur.',
            );
          }
          final selected = _resolveSelected(wheels)!;
          return _WheelBody(
            wheels: wheels,
            selected: selected,
            rotationListenable: _spinController,
            rotationOf: () =>
                _isSpinning ? _spinAnimation.value : _rotation,
            isSpinning: _isSpinning,
            resultIndex: _resultIndex,
            onSelect: _select,
            onSpin: () => _spin(selected),
            onDelete: _confirmDelete,
          );
        },
      ),
    );
  }

  void _openCreateSheet() {
    final user = ref.read(currentUserProvider);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CreateWheelSheet(ownerId: user?.uid ?? ''),
    );
  }
}

/// Seçili çark + chip listesi + çevir butonu + sonuç.
class _WheelBody extends StatelessWidget {
  const _WheelBody({
    required this.wheels,
    required this.selected,
    required this.rotationListenable,
    required this.rotationOf,
    required this.isSpinning,
    required this.resultIndex,
    required this.onSelect,
    required this.onSpin,
    required this.onDelete,
  });

  final List<Wheel> wheels;
  final Wheel selected;
  final Listenable rotationListenable;
  final double Function() rotationOf;
  final bool isSpinning;
  final int? resultIndex;
  final ValueChanged<Wheel> onSelect;
  final VoidCallback onSpin;
  final ValueChanged<Wheel> onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bool canSpin = selected.teams.length >= 2 && !isSpinning;

    return Column(
      children: [
        // Kayıtlı çarklar — yatay chip listesi.
        SizedBox(
          height: 56,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: wheels.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final w = wheels[index];
              return _WheelChip(
                label: w.name,
                selected: w.id == selected.id,
                onTap: () => onSelect(w),
                onLongPress: () => onDelete(w),
              );
            },
          ),
        ),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  // Seçili çark adı + silme butonu.
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            selected.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline, color: scheme.error),
                          tooltip: 'Çarkı Sil',
                          onPressed:
                              isSpinning ? null : () => onDelete(selected),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Çark + tepe göstergesi.
                  SizedBox(
                    width: 300,
                    height: 300,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        AnimatedBuilder(
                          animation: rotationListenable,
                          builder: (context, _) {
                            return Transform.rotate(
                              angle: rotationOf(),
                              child: CustomPaint(
                                size: const Size(280, 280),
                                painter: _WheelPainter(
                                  teams: selected.teams,
                                  borderColor: scheme.surface,
                                  hubColor: scheme.surface,
                                  hubBorderColor: scheme.primary,
                                ),
                              ),
                            );
                          },
                        ),
                        // Tepe göstergesi (aşağı bakan ok).
                        Positioned(
                          top: 0,
                          child: _Pointer(color: scheme.primary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _ResultArea(
                    selected: selected,
                    resultIndex: resultIndex,
                    isSpinning: isSpinning,
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: canSpin ? onSpin : null,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(56),
                        ),
                        child: Text(
                          isSpinning ? 'DÖNÜYOR…' : 'ÇEVİR',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: scheme.onPrimary,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (selected.teams.length < 2)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        'Çevirmek için en az 2 takım gerekir.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  const SizedBox(height: 28),
                  _ResultHistory(results: selected.lastResults),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Çark sonucu / dönüş durumu metni.
class _ResultArea extends StatelessWidget {
  const _ResultArea({
    required this.selected,
    required this.resultIndex,
    required this.isSpinning,
  });

  final Wheel selected;
  final int? resultIndex;
  final bool isSpinning;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (isSpinning) {
      return Text(
        'Çark dönüyor…',
        style: theme.textTheme.titleMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      );
    }
    if (resultIndex == null || resultIndex! >= selected.teams.length) {
      return Text(
        'Çevir ve takımını gör!',
        style: theme.textTheme.titleMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      );
    }
    return Column(
      children: [
        Text(
          'SONUÇ',
          style: theme.textTheme.labelMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          selected.teams[resultIndex!],
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium?.copyWith(
            color: scheme.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _WheelChip extends StatelessWidget {
  const _WheelChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? scheme.primary : scheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? scheme.primary
                : scheme.outline.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.donut_large,
              size: 16,
              color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: selected ? scheme.onPrimary : scheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Çarkın tepesindeki sabit, aşağı bakan üçgen gösterge.
class _Pointer extends StatelessWidget {
  const _Pointer({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: const Size(28, 22), painter: _PointerPainter(color));
  }
}

class _PointerPainter extends CustomPainter {
  _PointerPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PointerPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Çarkın dilimlerini ve takım adlarını çizen ressam.
class _WheelPainter extends CustomPainter {
  _WheelPainter({
    required this.teams,
    required this.borderColor,
    required this.hubColor,
    required this.hubBorderColor,
  });

  final List<String> teams;
  final Color borderColor;
  final Color hubColor;
  final Color hubBorderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final n = teams.length;
    if (n == 0) return;

    final sweep = 2 * pi / n;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (var i = 0; i < n; i++) {
      final start = i * sweep;
      final slicePaint = Paint()
        ..color = _sliceColor(i, n)
        ..style = PaintingStyle.fill;
      canvas.drawArc(rect, start, sweep, true, slicePaint);
      canvas.drawArc(rect, start, sweep, true, borderPaint);

      _drawLabel(canvas, center, radius, start + sweep / 2, teams[i]);
    }

    // Orta göbek.
    canvas.drawCircle(center, radius * 0.12, Paint()..color = hubColor);
    canvas.drawCircle(
      center,
      radius * 0.12,
      Paint()
        ..color = hubBorderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  void _drawLabel(
    Canvas canvas,
    Offset center,
    double radius,
    double angle,
    String text,
  ) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: radius * 0.62);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    // Sol yarıdaki etiketleri ters dönmemesi için 180° çevir.
    final bool flip = angle > pi / 2 && angle < 3 * pi / 2;
    canvas.rotate(flip ? angle + pi : angle);
    final double dx = flip ? -radius * 0.92 : radius * 0.30;
    canvas.translate(dx, 0);
    tp.paint(canvas, Offset(0, -tp.height / 2));
    canvas.restore();
  }

  /// Dilim rengi — eşit aralıklı ton (hue) ile her dilime ayrı renk.
  Color _sliceColor(int i, int n) {
    final hue = (i * 360.0 / n) % 360.0;
    return HSVColor.fromAHSV(1, hue, 0.55, 0.80).toColor();
  }

  @override
  bool shouldRepaint(covariant _WheelPainter oldDelegate) =>
      oldDelegate.teams != teams;
}

/// Yeni çark oluşturma alt sayfası.
class _CreateWheelSheet extends ConsumerStatefulWidget {
  const _CreateWheelSheet({required this.ownerId});

  final String ownerId;

  @override
  ConsumerState<_CreateWheelSheet> createState() => _CreateWheelSheetState();
}

class _CreateWheelSheetState extends ConsumerState<_CreateWheelSheet> {
  final _nameController = TextEditingController();
  final _teamController = TextEditingController();
  final List<String> _teams = [];
  String? _selectedLeague;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _teamController.dispose();
    super.dispose();
  }

  void _applyLeague(String league) {
    setState(() {
      _selectedLeague = league;
      _teams
        ..clear()
        ..addAll(LeaguePresets.all[league] ?? const []);
      if (_nameController.text.trim().isEmpty) {
        _nameController.text = league;
      }
    });
  }

  void _addTeam() {
    final value = _teamController.text.trim();
    if (value.isEmpty) return;
    if (!_teams.contains(value)) {
      setState(() => _teams.add(value));
    }
    _teamController.clear();
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _nameController.text.trim();
    final scheme = Theme.of(context).colorScheme;

    if (name.isEmpty || _teams.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Bir ad gir ve en az 2 takım ekle.',
            style: TextStyle(color: scheme.onError),
          ),
          backgroundColor: scheme.error,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(wheelRepositoryProvider).createWheel(
            ownerId: widget.ownerId,
            name: name,
            teams: List<String>.from(_teams),
          );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Çark kaydedilemedi. Lütfen tekrar deneyin.',
            style: TextStyle(color: scheme.onError),
          ),
          backgroundColor: scheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.outline.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Yeni Çark',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Çark Adı',
                hintText: 'Örn. Cuma Maçı',
                prefixIcon: Icon(Icons.label_outline),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Lig Seç (hazır takımlar)',
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final league in LeaguePresets.all.keys)
                  ChoiceChip(
                    label: Text(league),
                    selected: _selectedLeague == league,
                    onSelected: (_) => _applyLeague(league),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Takımlar (${_teams.length})',
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _teamController,
                    textCapitalization: TextCapitalization.words,
                    onSubmitted: (_) => _addTeam(),
                    decoration: const InputDecoration(
                      hintText: 'Takım adı ekle',
                      prefixIcon: Icon(Icons.add),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _addTeam,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(56, 52),
                    ),
                    child: const Icon(Icons.add),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_teams.isEmpty)
              Text(
                'Henüz takım eklenmedi. Bir lig seç ya da elle ekle.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final team in _teams)
                    Chip(
                      label: Text(team),
                      onDeleted: () => setState(() => _teams.remove(team)),
                    ),
                ],
              ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
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
    );
  }
}

/// Çarkın son sonuçlarını chip'ler halinde gösteren bölüm (son 5).
class _ResultHistory extends StatelessWidget {
  const _ResultHistory({required this.results});

  final List<String> results;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final recent = results.take(5).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history, size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Text(
                'Son Sonuçlar',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (recent.isEmpty)
            Text(
              'Henüz çark çevrilmedi',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < recent.length; i++)
                  _ResultChip(label: recent[i], highlight: i == 0),
              ],
            ),
        ],
      ),
    );
  }
}

/// Tek bir geçmiş sonuç chip'i; en yeni (ilk) sonuç vurgulanır.
class _ResultChip extends StatelessWidget {
  const _ResultChip({required this.label, required this.highlight});

  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: highlight
            ? scheme.primary.withValues(alpha: 0.14)
            : scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: highlight
              ? scheme.primary.withValues(alpha: 0.5)
              : scheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: highlight ? scheme.primary : scheme.onSurface,
          fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: scheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
