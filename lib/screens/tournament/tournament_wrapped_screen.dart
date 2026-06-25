import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/tournament.dart';
import '../../services/analytics_service.dart';
import '../../services/share_service.dart';
import '../../services/tournament_repository.dart';

/// Tamamlanmış bir turnuvanın "kutlama / özet" (wrapped) ekranı.
///
/// Şampiyon, podyum (ilk 3), gol kralı ve toplam istatistikleri kart kart
/// gösterir. Ekran açılınca tüm ekrana konfeti yağar; şampiyon kartında ayrıca
/// ekstra bir konfeti patlaması olur. Renkler tema (primary + secondary)
/// üzerinden gelir.
class TournamentWrappedScreen extends ConsumerStatefulWidget {
  const TournamentWrappedScreen({super.key, required this.tournamentId});

  final String tournamentId;

  @override
  ConsumerState<TournamentWrappedScreen> createState() =>
      _TournamentWrappedScreenState();
}

class _TournamentWrappedScreenState
    extends ConsumerState<TournamentWrappedScreen> {
  late final ConfettiController _screenConfetti;
  late final ConfettiController _championConfetti;

  /// Paylaşılabilir şampiyon kartının (ekran dışı) yakalama sınırı.
  final GlobalKey _shareCardKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _screenConfetti =
        ConfettiController(duration: const Duration(seconds: 3));
    _championConfetti =
        ConfettiController(duration: const Duration(seconds: 3));
    // Ekran açılır açılmaz kutlama: konfeti + güçlü titreşim.
    _screenConfetti.play();
    _championConfetti.play();
    HapticFeedback.heavyImpact();
    AnalyticsService.logWrappedViewed().ignore();
  }

  @override
  void dispose() {
    _screenConfetti.dispose();
    _championConfetti.dispose();
    super.dispose();
  }

  /// Ekran dışındaki [ChampionShareCard]'ı görsele çevirip paylaşır.
  Future<void> _shareChampion(String tournamentName, String championName) async {
    try {
      await ShareService.captureAndShare(
        boundaryKey: _shareCardKey,
        text: '🏆 $championName, $tournamentName turnuvasının şampiyonu oldu! '
            'Sen de Competra ile turnuvanı oluştur. competra.app',
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Görsel paylaşılamadı, tekrar dene.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final confettiColors = [
      scheme.primary,
      scheme.secondary,
      scheme.tertiary,
    ];

    final tournamentAsync =
        ref.watch(tournamentStreamProvider(widget.tournamentId));

    return Scaffold(
      appBar: AppBar(title: const Text('Turnuva Özeti')),
      body: tournamentAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Özet yüklenemedi.')),
        data: (tournament) {
          if (tournament == null) {
            return const Center(child: Text('Turnuva bulunamadı.'));
          }
          final matchesAsync =
              ref.watch(matchesStreamProvider(widget.tournamentId));
          return matchesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const Center(child: Text('Özet yüklenemedi.')),
            data: (matches) {
              final standings = computeStandings(
                tournament.participants,
                matches,
                tournament.tiebreakerMode,
              );
              final scorers = computeScorers(tournament.participants, matches);
              final championName =
                  standings.isNotEmpty ? standings.first.name : '—';
              final totalGoals =
                  scorers.fold<int>(0, (sum, s) => sum + s.goals);
              final playedCount =
                  matches.where((m) => m.isPlayed && !m.isBye).length;
              return Stack(
                // Ekran dışı paylaşım kartının kırpılmaması için.
                clipBehavior: Clip.none,
                children: [
                  _WrappedContent(
                    tournament: tournament,
                    standings: standings,
                    scorers: scorers,
                    matches: matches,
                    championConfetti: _championConfetti,
                    confettiColors: confettiColors,
                    onShareChampion: () =>
                        _shareChampion(tournament.name, championName),
                  ),
                  // Ekran dışında (sol -4000) tutulan, yalnızca yakalama için
                  // çizilen markalı paylaşım kartı.
                  Positioned(
                    left: -4000,
                    top: 0,
                    child: RepaintBoundary(
                      key: _shareCardKey,
                      child: ChampionShareCard(
                        tournamentName: tournament.name,
                        championName: championName,
                        totalMatches: playedCount,
                        totalGoals: totalGoals,
                      ),
                    ),
                  ),
                  // Tüm ekrana yayılan üst konfeti.
                  Align(
                    alignment: Alignment.topCenter,
                    child: ConfettiWidget(
                      confettiController: _screenConfetti,
                      blastDirectionality: BlastDirectionality.explosive,
                      shouldLoop: false,
                      emissionFrequency: 0.05,
                      numberOfParticles: 20,
                      maxBlastForce: 24,
                      minBlastForce: 8,
                      gravity: 0.25,
                      colors: confettiColors,
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _WrappedContent extends StatelessWidget {
  const _WrappedContent({
    required this.tournament,
    required this.standings,
    required this.scorers,
    required this.matches,
    required this.championConfetti,
    required this.confettiColors,
    required this.onShareChampion,
  });

  final Tournament tournament;
  final List<StandingRow> standings;
  final List<ScorerRow> scorers;
  final List<TournamentMatch> matches;
  final ConfettiController championConfetti;
  final List<Color> confettiColors;
  final VoidCallback onShareChampion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final champion = standings.isNotEmpty ? standings.first : null;
    final topScorer = scorers.isNotEmpty ? scorers.first : null;
    final totalGoals = scorers.fold<int>(0, (sum, s) => sum + s.goals);
    final playedCount = matches.where((m) => m.isPlayed && !m.isBye).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Text(
          tournament.name,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Turnuva tamamlandı! 🎉',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),

        // Şampiyon kartı (1. kart) — ekstra konfeti patlamasıyla.
        _ChampionCard(
          name: champion?.name ?? '—',
          championConfetti: championConfetti,
          confettiColors: confettiColors,
          onShare: onShareChampion,
        ),
        const SizedBox(height: 20),

        // Podyum (ilk 3).
        if (standings.length >= 2) ...[
          _SectionTitle(
            icon: Icons.leaderboard_outlined,
            title: 'Podyum',
            onShare: () => ShareService.shareText(_podiumSummary()),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < standings.length && i < 3; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _PodiumRow(rank: i + 1, row: standings[i]),
            ),
          const SizedBox(height: 20),
        ],

        // Gol kralı.
        if (topScorer != null && topScorer.goals > 0) ...[
          _SectionTitle(
            icon: Icons.sports_soccer,
            title: 'Gol Kralı',
            onShare: () => ShareService.shareText(
              '⚽ ${tournament.name} gol kralı: ${topScorer.name} '
              '(${topScorer.goals} gol)! competra.app',
            ),
          ),
          const SizedBox(height: 12),
          _HighlightTile(
            icon: Icons.emoji_events,
            title: topScorer.name,
            trailing: '${topScorer.goals} gol',
          ),
          const SizedBox(height: 20),
        ],

        // Özet istatistik.
        _SectionTitle(
          icon: Icons.insights_outlined,
          title: 'Özet',
          onShare: () => ShareService.shareText(
            '📊 ${tournament.name}: $playedCount maç, $totalGoals gol, '
            '${tournament.participants.length} oyuncu. competra.app',
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatBox(
                value: '$playedCount',
                label: 'Oynanan maç',
                icon: Icons.sports_soccer_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatBox(
                value: '$totalGoals',
                label: 'Toplam gol',
                icon: Icons.scoreboard_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatBox(
                value: '${tournament.participants.length}',
                label: 'Oyuncu',
                icon: Icons.group_outlined,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Podyumu (ilk 3) paylaşılabilir kısa metne çevirir.
  String _podiumSummary() {
    final medals = ['🥇', '🥈', '🥉'];
    final lines = <String>['🏆 ${tournament.name} podyumu:'];
    for (var i = 0; i < standings.length && i < 3; i++) {
      lines.add('${medals[i]} ${standings[i].name} (${standings[i].points} P)');
    }
    lines.add('competra.app');
    return lines.join('\n');
  }
}

/// Şampiyon kartı — kupa, ad ve kartın üstünden patlayan ekstra konfeti.
class _ChampionCard extends StatelessWidget {
  const _ChampionCard({
    required this.name,
    required this.championConfetti,
    required this.confettiColors,
    required this.onShare,
  });

  final String name;
  final ConfettiController championConfetti;
  final List<Color> confettiColors;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Stack(
      alignment: Alignment.topCenter,
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                scheme.primary.withValues(alpha: 0.25),
                scheme.secondary.withValues(alpha: 0.15),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: scheme.primary.withValues(alpha: 0.5)),
          ),
          child: Column(
            children: [
              Icon(Icons.emoji_events, size: 56, color: scheme.primary),
              const SizedBox(height: 12),
              Text(
                'ŞAMPİYON',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                name,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 20),
              // Büyük "Paylaş" butonu — markalı şampiyon görselini paylaşır.
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onShare,
                  icon: const Icon(Icons.share),
                  label: const Text('Paylaş'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    backgroundColor: scheme.primary,
                    foregroundColor: scheme.onPrimary,
                    textStyle: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Kartın tepesinden patlayan ekstra konfeti.
        ConfettiWidget(
          confettiController: championConfetti,
          blastDirectionality: BlastDirectionality.explosive,
          shouldLoop: false,
          emissionFrequency: 0.04,
          numberOfParticles: 12,
          maxBlastForce: 18,
          minBlastForce: 6,
          gravity: 0.3,
          colors: confettiColors,
        ),
      ],
    );
  }
}

class _PodiumRow extends StatelessWidget {
  const _PodiumRow({required this.rank, required this.row});

  final int rank;
  final StandingRow row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final medal = switch (rank) {
      1 => const Color(0xFFFFD700),
      2 => const Color(0xFFC0C0C0),
      _ => const Color(0xFFCD7F32),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: medal, width: 4),
          top: BorderSide(color: scheme.outline.withValues(alpha: 0.2)),
          right: BorderSide(color: scheme.outline.withValues(alpha: 0.2)),
          bottom: BorderSide(color: scheme.outline.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        children: [
          Text(
            '$rank',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: medal,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              row.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            '${row.points} P',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: scheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _HighlightTile extends StatelessWidget {
  const _HighlightTile({
    required this.icon,
    required this.title,
    required this.trailing,
  });

  final IconData icon;
  final String title;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: scheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            trailing,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: scheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.value,
    required this.label,
    required this.icon,
  });

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: scheme.primary, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.title,
    this.onShare,
  });

  final IconData icon;
  final String title;

  /// Verilirse, başlığın sağında bir paylaşım ikon butonu gösterilir.
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      children: [
        Icon(icon, size: 20, color: scheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        if (onShare != null) ...[
          const Spacer(),
          IconButton(
            onPressed: onShare,
            visualDensity: VisualDensity.compact,
            tooltip: 'Paylaş',
            icon: Icon(Icons.share_outlined, size: 20, color: scheme.primary),
          ),
        ],
      ],
    );
  }
}
