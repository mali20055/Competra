import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/tournament.dart' show TiebreakerMode;
import '../../router/route_paths.dart';
import '../../services/tournament_repository.dart';
import '../../l10n/app_localizations.dart';

/// Turnuva formatı seçenekleri.
enum TournamentFormat {
  league(Icons.table_rows_outlined),
  knockout(Icons.account_tree_outlined),
  groupKnockout(Icons.grid_view_outlined),
  championsLeague(Icons.emoji_events_outlined);

  const TournamentFormat(this.icon);

  final IconData icon;
}

/// Skor giriş sistemi seçenekleri.
enum ScoreEntryMode {
  bothPlayers(Icons.people_alt_outlined),
  winnerEnters(Icons.military_tech_outlined),
  adminOnly(Icons.shield_outlined);

  const ScoreEntryMode(this.icon);

  final IconData icon;
}

extension TournamentFormatExtension on TournamentFormat {
  String getTitle(AppLocalizations l10n) {
    switch (this) {
      case TournamentFormat.league:
        return l10n.formatLeague;
      case TournamentFormat.knockout:
        return l10n.formatKnockout;
      case TournamentFormat.groupKnockout:
        return l10n.formatGroupKnockout;
      case TournamentFormat.championsLeague:
        return l10n.formatChampionsLeague;
    }
  }

  String getDescription(AppLocalizations l10n) {
    switch (this) {
      case TournamentFormat.league:
        return l10n.formatLeagueDesc;
      case TournamentFormat.knockout:
        return l10n.formatKnockoutDesc;
      case TournamentFormat.groupKnockout:
        return l10n.formatGroupKnockoutDesc;
      case TournamentFormat.championsLeague:
        return l10n.formatChampionsLeagueDesc;
    }
  }
}

extension ScoreEntryModeExtension on ScoreEntryMode {
  String getTitle(AppLocalizations l10n) {
    switch (this) {
      case ScoreEntryMode.bothPlayers:
        return l10n.scoreEntryModeDouble;
      case ScoreEntryMode.winnerEnters:
        return l10n.scoreEntryModeWinner;
      case ScoreEntryMode.adminOnly:
        return l10n.scoreEntryModeAdmin;
    }
  }

  String getDescription(AppLocalizations l10n) {
    switch (this) {
      case ScoreEntryMode.bothPlayers:
        return l10n.scoreModeDoubleDesc;
      case ScoreEntryMode.winnerEnters:
        return l10n.scoreModeWinnerDesc;
      case ScoreEntryMode.adminOnly:
        return l10n.scoreModeAdminDesc;
    }
  }
}

extension TiebreakerModeExtension on TiebreakerMode {
  String getTitle(AppLocalizations l10n) {
    switch (this) {
      case TiebreakerMode.fifa:
        return l10n.tiebreakerFifa;
      case TiebreakerMode.uefa:
        return l10n.tiebreakerUefa;
      case TiebreakerMode.hybrid:
        return l10n.tiebreakerHybrid;
    }
  }

  String getDescription(AppLocalizations l10n) {
    switch (this) {
      case TiebreakerMode.fifa:
        return l10n.tiebreakerFifaDesc;
      case TiebreakerMode.uefa:
        return l10n.tiebreakerUefaDesc;
      case TiebreakerMode.hybrid:
        return l10n.tiebreakerHybridDesc;
    }
  }
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
    final l10n = AppLocalizations.of(context)!;
    final message =
        _currentStep == 1 ? l10n.enterFormatWarning : l10n.enterScoreModeWarning;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final format = _selectedFormat;
    final scoreMode = _selectedScoreMode;
    if (format == null || scoreMode == null) return;

    final l10n = AppLocalizations.of(context)!;
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
          title: Text(l10n.saveAsTemplateTitle),
          content: Text(l10n.saveAsTemplateDesc),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l10n.no),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l10n.yes),
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
        SnackBar(content: Text(l10n.tournamentCreated)),
      );
      context.pushReplacementNamed(
        RoutePaths.tournamentDetailName,
        pathParameters: {'id': id},
      );
    } catch (e) {
      if (!mounted) return;
      final errorMessage = e.toString();
      final isLimitError = errorMessage.contains('en fazla 3 aktif turnuva');

      if (isLimitError) {
        context.pushNamed(RoutePaths.premiumName);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.activeTournamentLimitExceeded),
          ),
        );
      } else {
        final scheme = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.tournamentCreateFailed,
              style: TextStyle(color: scheme.onError),
            ),
            backgroundColor: scheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ── Şablondan Başla ────────────────────────────────────────────────

  void _showTemplateSheet() {
    final l10n = AppLocalizations.of(context)!;
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
                    l10n.templateSelectTitle,
                    style: Theme.of(sheetCtx).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 12),
                  templatesAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, __) =>
                        Center(child: Text(l10n.failedToLoad)),
                    data: (templates) {
                      if (templates.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text(l10n.noTemplatesYet),
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
                                '${_formatDisplayName(t.format, l10n)} • '
                                '${_scoreModeDisplayName(t.scoreMode, l10n)}',
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

  String _titleForStep(int step, AppLocalizations l10n) {
    switch (step) {
      case 0:
        return l10n.basicInfo;
      case 1:
        return l10n.selectFormat;
      case 2:
        return l10n.selectScoreMode;
      default:
        return '';
    }
  }

  static String _formatDisplayName(String format, AppLocalizations l10n) => switch (format) {
        'league' => l10n.formatLeague,
        'knockout' => l10n.formatKnockout,
        'groupKnockout' => l10n.formatGroupKnockout,
        'championsLeague' => l10n.formatChampionsLeague,
        _ => format,
      };

  static String _scoreModeDisplayName(String scoreMode, AppLocalizations l10n) => switch (scoreMode) {
        'adminOnly' => l10n.scoreEntryModeAdmin,
        'winnerEnters' => l10n.scoreEntryModeWinner,
        'bothPlayers' => l10n.scoreEntryModeDouble,
        _ => scoreMode,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.createTournament),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _submitting ? null : _onBack,
          tooltip: l10n.back,
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
                title: _titleForStep(_currentStep, l10n),
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
                      label: Text(l10n.startFromTemplate),
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
                    l10n: l10n,
                  ),
                  _FormatStep(
                    selected: _selectedFormat,
                    onSelected: (format) =>
                        setState(() => _selectedFormat = format),
                    tiebreaker: _selectedTiebreaker,
                    onTiebreakerSelected: (mode) =>
                        setState(() => _selectedTiebreaker = mode),
                    l10n: l10n,
                  ),
                  _ScoreModeStep(
                    selected: _selectedScoreMode,
                    onSelected: (mode) =>
                        setState(() => _selectedScoreMode = mode),
                    name: _nameController.text.trim(),
                    format: _selectedFormat,
                    l10n: l10n,
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
              l10n: l10n,
            ),
          ],
        ),
      ),
    );
  }
}

/// Üstteki animasyonlu adım göstergesi: "Adım n/3" + dolan ilerleme çubukları.
class _StepIndicator extends StatelessWidget {
  const _StepIndicator({
    required this.currentStep,
    required this.stepCount,
    required this.title,
  });

  final int currentStep;
  final int stepCount;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.stepCountLabel(currentStep + 1, stepCount),
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              title,
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
}

/// Adım 1 — Turnuva adı ve opsiyonel not.
class _BasicInfoStep extends StatelessWidget {
  const _BasicInfoStep({
    required this.formKey,
    required this.nameController,
    required this.noteController,
    required this.onChanged,
    required this.l10n,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController noteController;
  final VoidCallback onChanged;
  final AppLocalizations l10n;

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
            title: l10n.basicInfo,
            subtitle: l10n.basicInfoDesc,
          ),
          const SizedBox(height: 24),
          _FieldLabel(l10n.tournamentName),
          const SizedBox(height: 6),
          TextFormField(
            controller: nameController,
            textInputAction: TextInputAction.next,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            onChanged: (_) => onChanged(),
            decoration: InputDecoration(
              hintText: l10n.tournamentNameHint,
              prefixIcon: const Icon(Icons.emoji_events_outlined),
            ),
            validator: (value) {
              final text = value?.trim() ?? '';
              if (text.isEmpty) return l10n.tournamentNameRequired;
              if (text.length < 3) return l10n.tournamentNameMinLength(3);
              return null;
            },
          ),
          const SizedBox(height: 20),
          _FieldLabel(l10n.noteOptional),
          const SizedBox(height: 6),
          TextFormField(
            controller: noteController,
            maxLines: 4,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              hintText: l10n.noteHint,
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
    required this.l10n,
  });

  final TournamentFormat? selected;
  final ValueChanged<TournamentFormat> onSelected;
  final TiebreakerMode tiebreaker;
  final ValueChanged<TiebreakerMode> onTiebreakerSelected;
  final AppLocalizations l10n;

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
          title: l10n.selectFormat,
          subtitle: l10n.selectFormatSubtitle,
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
                title: format.getTitle(l10n),
                description: format.getDescription(l10n),
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
            l10n: l10n,
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
    required this.l10n,
  });

  final TiebreakerMode selected;
  final ValueChanged<TiebreakerMode> onSelected;
  final AppLocalizations l10n;

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
              l10n.tiebreakerCriteria,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          l10n.tiebreakerSubtitle,
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
            l10n: l10n,
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
    required this.l10n,
  });

  final TiebreakerMode mode;
  final bool selected;
  final VoidCallback onTap;
  final AppLocalizations l10n;

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
                      mode.getTitle(l10n),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: selected ? scheme.primary : scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      mode.getDescription(l10n),
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
    required this.l10n,
  });

  final ScoreEntryMode? selected;
  final ValueChanged<ScoreEntryMode> onSelected;
  final String name;
  final TournamentFormat? format;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        _StepHeading(
          title: l10n.selectScoreMode,
          subtitle: l10n.selectScoreModeSubtitle,
        ),
        const SizedBox(height: 24),
        for (final mode in ScoreEntryMode.values) ...[
          _SelectableCard(
            icon: mode.icon,
            title: mode.getTitle(l10n),
            description: mode.getDescription(l10n),
            selected: selected == mode,
            onTap: () => onSelected(mode),
            fullWidth: true,
          ),
          const SizedBox(height: 14),
        ],
        const SizedBox(height: 10),
        _SummaryCard(
          name: name,
          format: format,
          scoreMode: selected,
          l10n: l10n,
        ),
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
    required this.l10n,
  });

  final String name;
  final TournamentFormat? format;
  final ScoreEntryMode? scoreMode;
  final AppLocalizations l10n;

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
                l10n.summary,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SummaryRow(
            label: l10n.name,
            value: name.isEmpty ? '—' : name,
          ),
          const Divider(height: 20),
          _SummaryRow(
            label: l10n.formatLabel,
            value: format != null ? format!.getTitle(l10n) : '—',
          ),
          const Divider(height: 20),
          _SummaryRow(
            label: l10n.scoreSystem,
            value: scoreMode != null ? scoreMode!.getTitle(l10n) : l10n.notSelected,
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
    required this.l10n,
  });

  final ThemeData theme;
  final int currentStep;
  final int stepCount;
  final bool enabled;
  final bool submitting;
  final VoidCallback? onBack;
  final VoidCallback onNext;
  final AppLocalizations l10n;

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
              label: Text(currentStep == 0 ? l10n.cancel : l10n.back),
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
                        Text(isLastStep ? l10n.createTournament : l10n.next),
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
