import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/tournament.dart' show TiebreakerMode;
import '../../router/route_paths.dart';
import '../../services/tournament_repository.dart';

/// Turnuva formatı seçenekleri.
enum TournamentFormat {
  league('Lig', 'Herkes herkesle, puan tablosu', Icons.table_rows_outlined),
  knockout('Eleme', 'Tek/çift maç eleme ağacı', Icons.account_tree_outlined),
  groupKnockout(
    'Grup + Eleme',
    'Grup aşaması, sonra eleme',
    Icons.grid_view_outlined,
  ),
  championsLeague(
    'Şampiyonlar Ligi',
    'Grup + iki ayaklı eleme',
    Icons.emoji_events_outlined,
  );

  const TournamentFormat(this.title, this.description, this.icon);

  final String title;
  final String description;
  final IconData icon;
}

/// Skor giriş sistemi seçenekleri.
enum ScoreEntryMode {
  bothPlayers(
    'Çift Giriş',
    'Her iki oyuncu skoru girer, eşleşince onaylanır',
    Icons.people_alt_outlined,
  ),
  winnerEnters(
    'Kazanan Girer',
    'Sonucu yalnızca kazanan taraf bildirir',
    Icons.military_tech_outlined,
  ),
  adminOnly(
    'Sadece Admin',
    'Skorları yalnızca turnuva yöneticisi girer',
    Icons.shield_outlined,
  );

  const ScoreEntryMode(this.title, this.description, this.icon);

  final String title;
  final String description;
  final IconData icon;
}

/// Turnuva oluşturma ekranı.
///
/// Üç adımlı bir formdur ([PageView] ile animasyonlu geçiş):
/// 1. Temel bilgiler (ad + not), 2. Format seçimi, 3. Skor giriş sistemi.
/// Üstte animasyonlu adım göstergesi, altta "Geri" / "Devam Et" navigasyonu
/// bulunur. Her adımda kendi doğrulaması yapılır. Tüm renkler tema üzerinden
/// gelir.
class CreateTournamentScreen extends ConsumerStatefulWidget {
  const CreateTournamentScreen({super.key});

  @override
  ConsumerState<CreateTournamentScreen> createState() =>
      _CreateTournamentScreenState();
}

class _CreateTournamentScreenState
    extends ConsumerState<CreateTournamentScreen> {
  static const int _stepCount = 3;
  static const Duration _pageDuration = Duration(milliseconds: 350);

  final _pageController = PageController();
  final _basicInfoFormKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _noteController = TextEditingController();

  int _currentStep = 0;
  TournamentFormat? _selectedFormat;
  ScoreEntryMode? _selectedScoreMode;
  TiebreakerMode _selectedTiebreaker = TiebreakerMode.uefa;
  bool _submitting = false;

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  /// Mevcut adımın geçerli olup olmadığını döner (Devam/Oluştur aktifliği için).
  bool get _isCurrentStepValid {
    switch (_currentStep) {
      case 0:
        return _nameController.text.trim().length >= 3;
      case 1:
        return _selectedFormat != null;
      case 2:
        return _selectedScoreMode != null;
      default:
        return false;
    }
  }

  void _goToStep(int step) {
    _pageController.animateToPage(
      step,
      duration: _pageDuration,
      curve: Curves.easeInOut,
    );
  }

  void _onBack() {
    FocusScope.of(context).unfocus();
    if (_currentStep == 0) {
      context.pop();
      return;
    }
    _goToStep(_currentStep - 1);
  }

  void _onNext() {
    FocusScope.of(context).unfocus();

    // Adıma özel doğrulama.
    if (_currentStep == 0) {
      final form = _basicInfoFormKey.currentState;
      if (form == null || !form.validate()) return;
    } else if (!_isCurrentStepValid) {
      _showSelectionWarning();
      return;
    }

    if (_currentStep == _stepCount - 1) {
      _submit();
      return;
    }
    _goToStep(_currentStep + 1);
  }

  void _showSelectionWarning() {
    final message =
        _currentStep == 1 ? 'Lütfen bir format seçin.' : 'Lütfen bir skor giriş sistemi seçin.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final format = _selectedFormat;
    final scoreMode = _selectedScoreMode;
    if (format == null || scoreMode == null) return;

    setState(() => _submitting = true);

    final effectiveTiebreaker = format == TournamentFormat.knockout
        ? TiebreakerMode.uefa
        : _selectedTiebreaker;

    try {
      final id = await ref.read(tournamentRepositoryProvider).createTournament(
            name: _nameController.text.trim(),
            note: _noteController.text.trim(),
            format: format.name,
            scoreMode: scoreMode.name,
            tiebreakerMode: effectiveTiebreaker,
          );
      if (!mounted) return;
      HapticFeedback.heavyImpact();

      // Şablon kaydetme teklifi
      final shouldSave = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Şablon Olarak Kaydet'),
          content: const Text(
            'Bu ayarları gelecekte tekrar kullanmak ister misin?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Hayır'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Evet'),
            ),
          ],
        ),
      );

      if (shouldSave == true && mounted) {
        ref
            .read(tournamentRepositoryProvider)
            .saveAsTemplate(
              name: _nameController.text.trim(),
              format: format.name,
              scoreMode: scoreMode.name,
              tiebreakerMode: effectiveTiebreaker.value,
            )
            .ignore();
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Turnuva oluşturuldu.')),
      );
      context.pushReplacementNamed(
        RoutePaths.tournamentDetailName,
        pathParameters: {'id': id},
      );
    } catch (_) {
      if (!mounted) return;
      final scheme = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Turnuva oluşturulamadı. Lütfen tekrar deneyin.',
            style: TextStyle(color: scheme.onError),
          ),
          backgroundColor: scheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ── Şablondan Başla ────────────────────────────────────────────────

  void _showTemplateSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) => Consumer(
        builder: (_, ref, __) {
          final templatesAsync = ref.watch(myTemplatesProvider);
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Şablon Seç',
                    style: Theme.of(sheetCtx).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 12),
                  templatesAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, __) =>
                        const Center(child: Text('Yüklenemedi.')),
                    data: (templates) {
                      if (templates.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text('Henüz kaydedilmiş şablon yok.'),
                          ),
                        );
                      }
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final t in templates)
                            ListTile(
                              title: Text(t.name),
                              subtitle: Text(
                                '${_formatDisplayName(t.format)} • '
                                '${_scoreModeDisplayName(t.scoreMode)}',
                              ),
                              leading: const Icon(Icons.bookmark_outlined),
                              onTap: () {
                                Navigator.of(sheetCtx).pop();
                                _applyTemplate(t);
                              },
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _applyTemplate(TournamentTemplate template) {
    TournamentFormat? format;
    try {
      format = TournamentFormat.values.byName(template.format);
    } catch (_) {}

    ScoreEntryMode? scoreMode;
    try {
      scoreMode = ScoreEntryMode.values.byName(template.scoreMode);
    } catch (_) {}

    setState(() {
      _nameController.text = template.name;
      if (format != null) _selectedFormat = format;
      if (scoreMode != null) _selectedScoreMode = scoreMode;
      _selectedTiebreaker = TiebreakerMode.fromString(template.tiebreakerMode);
    });
  }

  static String _formatDisplayName(String format) => switch (format) {
        'league' => 'Lig',
        'knockout' => 'Eleme',
        'groupKnockout' => 'Grup+Eleme',
        'championsLeague' => 'Şampiyonlar Ligi',
        _ => format,
      };

  static String _scoreModeDisplayName(String scoreMode) => switch (scoreMode) {
        'adminOnly' => 'Sadece Admin',
        'winnerEnters' => 'Kazanan Girer',
        'bothPlayers' => 'Çift Giriş',
        _ => scoreMode,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Turnuva Oluştur'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _submitting ? null : _onBack,
          tooltip: 'Geri',
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: _StepIndicator(
                currentStep: _currentStep,
                stepCount: _stepCount,
              ),
            ),
            // "Şablondan Başla" yalnızca adım 0'da görünür
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _currentStep == 0 ? 1.0 : 0.0,
              child: IgnorePointer(
                ignoring: _currentStep != 0,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _showTemplateSheet,
                      icon: const Icon(Icons.bookmark_border, size: 18),
                      label: const Text('Şablondan Başla'),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) => setState(() => _currentStep = index),
                children: [
                  _BasicInfoStep(
                    formKey: _basicInfoFormKey,
                    nameController: _nameController,
                    noteController: _noteController,
                    onChanged: () => setState(() {}),
                  ),
                  _FormatStep(
                    selected: _selectedFormat,
                    onSelected: (format) =>
                        setState(() => _selectedFormat = format),
                    tiebreaker: _selectedTiebreaker,
                    onTiebreakerSelected: (mode) =>
                        setState(() => _selectedTiebreaker = mode),
                  ),
                  _ScoreModeStep(
                    selected: _selectedScoreMode,
                    onSelected: (mode) =>
                        setState(() => _selectedScoreMode = mode),
                    name: _nameController.text.trim(),
                    format: _selectedFormat,
                  ),
                ],
              ),
            ),
            _NavigationBar(
              theme: theme,
              currentStep: _currentStep,
              stepCount: _stepCount,
              enabled: _isCurrentStepValid && !_submitting,
              submitting: _submitting,
              onBack: _submitting ? null : _onBack,
              onNext: _onNext,
            ),
          ],
        ),
      ),
    );
  }
}

/// Üstteki animasyonlu adım göstergesi: "Adım n/3" + dolan ilerleme çubukları.
class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.currentStep, required this.stepCount});

  final int currentStep;
  final int stepCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Adım ${currentStep + 1}/$stepCount',
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              _titleForStep(currentStep),
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: List.generate(stepCount, (index) {
            final bool active = index <= currentStep;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: index == stepCount - 1 ? 0 : 8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  height: 6,
                  decoration: BoxDecoration(
                    color: active
                        ? scheme.primary
                        : scheme.outline.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  String _titleForStep(int step) {
    switch (step) {
      case 0:
        return 'Temel Bilgiler';
      case 1:
        return 'Format Seç';
      case 2:
        return 'Skor Giriş Sistemi';
      default:
        return '';
    }
  }
}

/// Adım 1 — Turnuva adı ve opsiyonel not.
class _BasicInfoStep extends StatelessWidget {
  const _BasicInfoStep({
    required this.formKey,
    required this.nameController,
    required this.noteController,
    required this.onChanged,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController noteController;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Form(
      key: formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        children: [
          _StepHeading(
            title: 'Temel Bilgiler',
            subtitle: 'Turnuvana bir ad ver ve istersen kısa bir not ekle.',
          ),
          const SizedBox(height: 24),
          _FieldLabel('Turnuva Adı'),
          const SizedBox(height: 6),
          TextFormField(
            controller: nameController,
            textInputAction: TextInputAction.next,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            onChanged: (_) => onChanged(),
            decoration: const InputDecoration(
              hintText: 'Örn. Mahalle Ligi 2026',
              prefixIcon: Icon(Icons.emoji_events_outlined),
            ),
            validator: (value) {
              final text = value?.trim() ?? '';
              if (text.isEmpty) return 'Turnuva adı gerekli';
              if (text.length < 3) return 'En az 3 karakter olmalı';
              return null;
            },
          ),
          const SizedBox(height: 20),
          _FieldLabel('Not (opsiyonel)'),
          const SizedBox(height: 6),
          TextFormField(
            controller: noteController,
            maxLines: 4,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              hintText: 'Kurallar, ödüller veya katılımcılarla ilgili notlar…',
              alignLabelWithHint: true,
              prefixIcon: Padding(
                padding: const EdgeInsets.only(bottom: 48),
                child: Icon(Icons.notes_outlined, color: scheme.onSurfaceVariant),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Adım 2 — 2x2 format kart grid'i + (lig türü formatlarda) sıralama kriteri.
class _FormatStep extends StatelessWidget {
  const _FormatStep({
    required this.selected,
    required this.onSelected,
    required this.tiebreaker,
    required this.onTiebreakerSelected,
  });

  final TournamentFormat? selected;
  final ValueChanged<TournamentFormat> onSelected;
  final TiebreakerMode tiebreaker;
  final ValueChanged<TiebreakerMode> onTiebreakerSelected;

  @override
  Widget build(BuildContext context) {
    // Eleme formatında sıralama/puan tablosu olmadığı için averaj seçimi
    // gösterilmez.
    final bool showTiebreaker =
        selected != null && selected != TournamentFormat.knockout;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        _StepHeading(
          title: 'Format Seç',
          subtitle: 'Turnuvanın nasıl işleyeceğini belirleyen formatı seç.',
        ),
        const SizedBox(height: 24),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 0.92,
          children: [
            for (final format in TournamentFormat.values)
              _SelectableCard(
                icon: format.icon,
                title: format.title,
                description: format.description,
                selected: selected == format,
                onTap: () => onSelected(format),
              ),
          ],
        ),
        if (showTiebreaker) ...[
          const SizedBox(height: 28),
          _TiebreakerSelector(
            selected: tiebreaker,
            onSelected: onTiebreakerSelected,
          ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0),
        ],
      ],
    );
  }
}

/// Puan eşitliğinde uygulanacak sıralama kriteri seçimi (FIFA / UEFA / Karma).
class _TiebreakerSelector extends StatelessWidget {
  const _TiebreakerSelector({
    required this.selected,
    required this.onSelected,
  });

  final TiebreakerMode selected;
  final ValueChanged<TiebreakerMode> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.sort, size: 18, color: scheme.primary),
            const SizedBox(width: 8),
            Text(
              'Sıralama Kriteri',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Puan eşitliğinde sıralamanın nasıl belirleneceğini seç.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        for (final mode in TiebreakerMode.values) ...[
          _TiebreakerOption(
            mode: mode,
            selected: selected == mode,
            onTap: () => onSelected(mode),
          ),
          if (mode != TiebreakerMode.values.last) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _TiebreakerOption extends StatelessWidget {
  const _TiebreakerOption({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final TiebreakerMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? scheme.primary.withValues(alpha: 0.12)
                : scheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? scheme.primary
                  : scheme.outline.withValues(alpha: 0.25),
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mode.label,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: selected ? scheme.primary : scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      mode.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Adım 3 — Skor giriş sistemi + seçim özeti.
class _ScoreModeStep extends StatelessWidget {
  const _ScoreModeStep({
    required this.selected,
    required this.onSelected,
    required this.name,
    required this.format,
  });

  final ScoreEntryMode? selected;
  final ValueChanged<ScoreEntryMode> onSelected;
  final String name;
  final TournamentFormat? format;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        _StepHeading(
          title: 'Skor Giriş Sistemi',
          subtitle: 'Maç sonuçlarının nasıl girileceğini seç.',
        ),
        const SizedBox(height: 24),
        for (final mode in ScoreEntryMode.values) ...[
          _SelectableCard(
            icon: mode.icon,
            title: mode.title,
            description: mode.description,
            selected: selected == mode,
            onTap: () => onSelected(mode),
            fullWidth: true,
          ),
          const SizedBox(height: 14),
        ],
        const SizedBox(height: 10),
        _SummaryCard(name: name, format: format, scoreMode: selected),
      ],
    );
  }
}

/// Seçilebilir kart (hem grid hem tam genişlik kullanımında).
///
/// Seçiliyken yeşil kenarlık + hafif yeşil arka plan tonu + sağ üstte
/// checkmark gösterilir.
class _SelectableCard extends StatelessWidget {
  const _SelectableCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
    this.fullWidth = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final Color borderColor =
        selected ? scheme.primary : scheme.outline.withValues(alpha: 0.25);
    final Color background = selected
        ? scheme.primary.withValues(alpha: 0.12)
        : scheme.surface;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: borderColor,
              width: selected ? 2 : 1,
            ),
          ),
          child: fullWidth
              ? _buildRowLayout(theme, scheme)
              : _buildColumnLayout(theme, scheme),
        ),
      ),
    );
  }

  /// Grid kartı: ikon üstte, başlık + açıklama altta, checkmark sağ üstte.
  Widget _buildColumnLayout(ThemeData theme, ColorScheme scheme) {
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _IconBadge(icon: icon, selected: selected),
            const SizedBox(height: 12),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: selected ? scheme.primary : scheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.3,
              ),
            ),
          ],
        ),
        if (selected)
          Positioned(top: 0, right: 0, child: _CheckMark()),
      ],
    );
  }

  /// Tam genişlik kart: ikon solda, metinler ortada, checkmark sağda.
  Widget _buildRowLayout(ThemeData theme, ColorScheme scheme) {
    return Row(
      children: [
        _IconBadge(icon: icon, selected: selected),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: selected ? scheme.primary : scheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        selected
            ? _CheckMark()
            : Icon(
                Icons.radio_button_unchecked,
                color: scheme.outline.withValues(alpha: 0.5),
              ),
      ],
    );
  }
}

/// Kart ikonu için yumuşak yeşil zemine oturtulmuş rozet.
class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, required this.selected});

  final IconData icon;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: selected
            ? scheme.primary.withValues(alpha: 0.18)
            : scheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        icon,
        color: scheme.primary,
        size: 24,
      ),
    );
  }
}

/// Seçili durumda gösterilen yeşil daire içinde tik.
class _CheckMark extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: scheme.primary,
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.check, size: 16, color: scheme.onPrimary),
    ).animate().scale(
          duration: 200.ms,
          curve: Curves.easeOutBack,
          begin: const Offset(0.6, 0.6),
          end: const Offset(1, 1),
        );
  }
}

/// Adım 3'teki seçim özeti kartı (adım 1-2'den gelen bilgiler).
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.name,
    required this.format,
    required this.scoreMode,
  });

  final String name;
  final TournamentFormat? format;
  final ScoreEntryMode? scoreMode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.fact_check_outlined, size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Text(
                'Özet',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SummaryRow(
            label: 'Ad',
            value: name.isEmpty ? '—' : name,
          ),
          const Divider(height: 20),
          _SummaryRow(
            label: 'Format',
            value: format?.title ?? '—',
          ),
          const Divider(height: 20),
          _SummaryRow(
            label: 'Skor Sistemi',
            value: scoreMode?.title ?? 'Seçilmedi',
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// Her adımın başındaki başlık + açıklama.
class _StepHeading extends StatelessWidget {
  const _StepHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
      ],
    ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.1, end: 0);
  }
}

/// Form alanı üst etiketi (auth ekranlarıyla tutarlı stil).
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

/// Alttaki "Geri" / "Devam Et" (son adımda "Turnuvayı Oluştur") navigasyonu.
class _NavigationBar extends StatelessWidget {
  const _NavigationBar({
    required this.theme,
    required this.currentStep,
    required this.stepCount,
    required this.enabled,
    required this.submitting,
    required this.onBack,
    required this.onNext,
  });

  final ThemeData theme;
  final int currentStep;
  final int stepCount;
  final bool enabled;
  final bool submitting;
  final VoidCallback? onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    final bool isLastStep = currentStep == stepCount - 1;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(color: scheme.outline.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back, size: 20),
              label: Text(currentStep == 0 ? 'İptal' : 'Geri'),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: enabled ? onNext : null,
              child: submitting
                  ? SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: scheme.onPrimary,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(isLastStep ? 'Turnuvayı Oluştur' : 'Devam Et'),
                        const SizedBox(width: 8),
                        Icon(
                          isLastStep ? Icons.check : Icons.arrow_forward,
                          size: 20,
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
