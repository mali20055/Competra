import 'dart:io';
import 'dart:ui' as ui;
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/tournament.dart';
import '../../services/analytics_service.dart';
import '../../services/share_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/tournament_repository.dart';

final _mvpVotesProvider = FutureProvider.family<Map<String, int>, String>((ref, id) {
  return ref.read(tournamentRepositoryProvider).getMvpVotes(id);
});

typedef _EloEntry = ({String name, int change});

final _tournamentEloChangesProvider = FutureProvider.family<List<_EloEntry>, String>(
  (ref, tournamentId) async {
    final tDoc = await FirebaseFirestore.instance
        .collection('tournaments')
        .doc(tournamentId)
        .get();
    if (!tDoc.exists) return [];

    final tData = tDoc.data()!;
    final createdAt = (tData['createdAt'] as Timestamp?)?.toDate();
    if (createdAt == null) return [];
    final completedAt = (tData['completedAt'] as Timestamp?)?.toDate();

    final participants = List<Map<String, dynamic>>.from(
      tData['participants'] as List? ?? [],
    );

    final results = <_EloEntry>[];
    for (final p in participants) {
      final uid = p['uid'] as String? ?? '';
      final name = p['username'] as String? ?? 'Oyuncu';
      if (uid.isEmpty) continue;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (!userDoc.exists) continue;

      final history = List<Map<String, dynamic>>.from(
        userDoc.data()?['eloHistory'] as List? ?? [],
      );

      int totalChange = 0;
      for (final entry in history) {
        final entryDate = (entry['date'] as Timestamp?)?.toDate();
        if (entryDate == null) continue;
        final afterStart = entryDate.isAfter(createdAt);
        final beforeEnd = completedAt == null ||
            entryDate.isBefore(completedAt.add(const Duration(hours: 1)));
        if (afterStart && beforeEnd) {
          totalChange += ((entry['change'] as num?) ?? 0).toInt();
        }
      }

      if (totalChange != 0) results.add((name: name, change: totalChange));
    }

    results.sort((a, b) => b.change.compareTo(a.change));
    return results;
  },
);

class TournamentWrappedScreen extends ConsumerStatefulWidget {
  const TournamentWrappedScreen({super.key, required this.tournamentId});

  final String tournamentId;

  @override
  ConsumerState<TournamentWrappedScreen> createState() =>
      _TournamentWrappedScreenState();
}

class _TournamentWrappedScreenState extends ConsumerState<TournamentWrappedScreen> {
  late final ConfettiController _championConfetti;
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Persisted keys for each slide to enable RepaintBoundary capture
  final GlobalKey _championSlideKey = GlobalKey();
  final GlobalKey _scorerSlideKey = GlobalKey();
  final GlobalKey _mvpSlideKey = GlobalKey();
  final GlobalKey _dramaticSlideKey = GlobalKey();
  final GlobalKey _eloSlideKey = GlobalKey();
  final GlobalKey _ironWallSlideKey = GlobalKey();
  final GlobalKey _timelineSlideKey = GlobalKey();
  final GlobalKey _summarySlideKey = GlobalKey();

  // Off-screen card keys for the "Share All" feature
  final GlobalKey _shareChampionKey = GlobalKey();
  final GlobalKey _shareScorerKey = GlobalKey();
  final GlobalKey _shareSummaryKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _championConfetti =
        ConfettiController(duration: const Duration(seconds: 4));
    
    // Play confetti and trigger impact haptic on load
    _championConfetti.play();
    HapticFeedback.heavyImpact();
    AnalyticsService.logWrappedViewed().ignore();
  }

  @override
  void dispose() {
    _championConfetti.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _shareSlide(GlobalKey key, String text) async {
    try {
      await ShareService.captureAndShare(
        boundaryKey: key,
        text: text,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Görsel paylaşılamadı, tekrar dene.')),
      );
    }
  }

  Future<void> _shareWrapped(
    String tournamentName,
    String championName,
    String topScorerName,
    int topScorerGoals,
    int playedCount,
    int totalGoals,
    int totalPlayers,
  ) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final files = <XFile>[];

      Future<XFile?> captureBoundary(GlobalKey key) async {
        final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
        if (boundary == null) return null;
        final image = await boundary.toImage(pixelRatio: 3.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        if (byteData == null) return null;
        final bytes = byteData.buffer.asUint8List();
        final dir = await getTemporaryDirectory();
        final fileName = 'competra_wrapped_${key.hashCode}_${DateTime.now().millisecondsSinceEpoch}.png';
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(bytes);
        return XFile(file.path);
      }

      final f1 = await captureBoundary(_shareChampionKey);
      if (f1 != null) files.add(f1);

      final f2 = await captureBoundary(_shareScorerKey);
      if (f2 != null) files.add(f2);

      final f3 = await captureBoundary(_shareSummaryKey);
      if (f3 != null) files.add(f3);

      if (mounted) Navigator.of(context).pop(); // dismiss loader

      if (files.isNotEmpty) {
        await SharePlus.instance.share(
          ShareParams(
            files: files,
            text: '🏆 $tournamentName turnuvası Wrapped özetlerim! Sen de Competra ile turnuvanı oluştur. competra.app',
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop(); // dismiss loader
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Wrapped paylaşılamadı, tekrar deneyin.')),
        );
      }
    }
  }

  String _monthName(int month) {
    const months = [
      'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
    ];
    if (month >= 1 && month <= 12) return months[month - 1];
    return 'Ay';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final confettiColors = [
      scheme.primary,
      scheme.secondary,
      Colors.amber,
      Colors.white,
      Colors.greenAccent,
    ];

    final tournamentAsync = ref.watch(tournamentStreamProvider(widget.tournamentId));
    final mvpVotesAsync = ref.watch(_mvpVotesProvider(widget.tournamentId));
    final eloChangesAsync = ref.watch(_tournamentEloChangesProvider(widget.tournamentId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Turnuva Özeti (Wrapped)'),
      ),
      body: tournamentAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Özet yüklenemedi.')),
        data: (tournament) {
          if (tournament == null) {
            return const Center(child: Text('Turnuva bulunamadı.'));
          }

          final matchesAsync = ref.watch(matchesStreamProvider(widget.tournamentId));
          return matchesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const Center(child: Text('Özet yüklenemedi.')),
            data: (matches) {
              return mvpVotesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const Center(child: Text('Özet yüklenemedi.')),
                data: (mvpVotes) {
                  final standings = computeStandings(
                    tournament.participants,
                    matches,
                    tournament.tiebreakerMode,
                  );
                  final scorers = computeScorers(tournament.participants, matches);

                  // Extract statistics
                  final championName = standings.isNotEmpty ? standings.first.name : '—';
                  final topScorer = scorers.isNotEmpty ? scorers.first : null;
                  final topScorerName = topScorer?.name ?? '—';
                  final topScorerGoals = topScorer?.goals ?? 0;
                  final totalGoals = scorers.fold<int>(0, (acc, s) => acc + s.goals);
                  final playedMatches = matches.where((m) => m.isPlayed && !m.isBye).toList();
                  final playedCount = playedMatches.length;

                  // Find MVP (if any votes)
                  String? mvpName;
                  int mvpVoteCount = 0;
                  if (mvpVotes.isNotEmpty) {
                    String? maxMvpUid;
                    int maxVotes = -1;
                    mvpVotes.forEach((uid, voteCount) {
                      if (voteCount > maxVotes) {
                        maxVotes = voteCount;
                        maxMvpUid = uid;
                      }
                    });
                    if (maxMvpUid != null) {
                      mvpName = tournament.participants.firstWhere(
                        (p) => p.uid == maxMvpUid,
                        orElse: () => const Participant(uid: '', username: 'Bilinmeyen Oyuncu'),
                      ).username;
                      mvpVoteCount = maxVotes;
                    }
                  }

                  // Find Most Dramatic Match
                  TournamentMatch? dramaticMatch;
                  if (playedMatches.isNotEmpty) {
                    int minDiff = 999999;
                    int maxTotalGoals = -1;
                    for (final m in playedMatches) {
                      final diff = (m.homeScore! - m.awayScore!).abs();
                      final total = m.homeScore! + m.awayScore!;
                      if (diff < minDiff || (diff == minDiff && total > maxTotalGoals)) {
                        minDiff = diff;
                        maxTotalGoals = total;
                        dramaticMatch = m;
                      }
                    }
                  }

                  // Find Iron Wall (least conceded goals with at least 1 match played)
                  StandingRow? ironWall;
                  int minConceded = 999999;
                  for (final s in standings) {
                    if (s.played > 0 && s.goalsAgainst < minConceded) {
                      minConceded = s.goalsAgainst;
                      ironWall = s;
                    }
                  }

                  // Timeline Calculations
                  int totalDays = 1;
                  if (tournament.createdAt != null && tournament.completedAt != null) {
                    totalDays = tournament.completedAt!.difference(tournament.createdAt!).inDays;
                    if (totalDays <= 0) totalDays = 1;
                  }
                  String formattedStartDate = '—';
                  if (tournament.createdAt != null) {
                    formattedStartDate = '${tournament.createdAt!.day} ${_monthName(tournament.createdAt!.month)} ${tournament.createdAt!.year}';
                  }

                  // Busiest Day
                  String busiestDate = '—';
                  int maxMatches = 0;
                  if (playedMatches.isNotEmpty) {
                    final Map<String, int> dayCounts = {};
                    for (final m in playedMatches) {
                      if (m.createdAt != null) {
                        final dateStr = '${m.createdAt!.day} ${_monthName(m.createdAt!.month)} ${m.createdAt!.year}';
                        dayCounts[dateStr] = (dayCounts[dateStr] ?? 0) + 1;
                      }
                    }
                    if (dayCounts.isNotEmpty) {
                      dayCounts.forEach((date, dayCount) {
                        if (dayCount > maxMatches) {
                          maxMatches = dayCount;
                          busiestDate = date;
                        }
                      });
                    } else if (tournament.createdAt != null) {
                      busiestDate = formattedStartDate;
                      maxMatches = playedCount;
                    }
                  }

                  final averageScore = playedCount > 0 ? totalGoals / playedCount : 0.0;

                  // Build dynamic slides list
                  final List<({Widget child, GlobalKey key, String shareText})> slides = [];

                  // Slide 1: Champion
                  slides.add((
                    key: _championSlideKey,
                    shareText: '🏆 $championName, ${tournament.name} turnuvasının şampiyonu oldu! competra.app',
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            // Confetti rain local to champion slide
                            Align(
                              alignment: Alignment.topCenter,
                              child: ConfettiWidget(
                                confettiController: _championConfetti,
                                blastDirectionality: BlastDirectionality.explosive,
                                shouldLoop: false,
                                emissionFrequency: 0.06,
                                numberOfParticles: 15,
                                maxBlastForce: 20,
                                minBlastForce: 6,
                                gravity: 0.2,
                                colors: confettiColors,
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: scheme.primary.withValues(alpha: 0.6),
                                    blurRadius: 40,
                                    spreadRadius: 10,
                                  ),
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 56,
                                backgroundColor: scheme.primaryContainer,
                                child: Icon(Icons.emoji_events, size: 56, color: scheme.primary),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        Text(
                          'ŞAMPİYON',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          championName,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Turnuvayı domine ederek zafere ulaştı! 🏆',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ));

                  // Slide 2: Top Scorer
                  if (topScorer != null && topScorer.goals > 0) {
                    slides.add((
                      key: _scorerSlideKey,
                      shareText: '⚽ $topScorerName, ${tournament.name} turnuvasında $topScorerGoals gol ile Gol Kralı oldu! competra.app',
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 48,
                            backgroundColor: scheme.secondaryContainer,
                            child: Icon(Icons.sports_soccer, size: 48, color: scheme.secondary),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'GOL KRALI',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: scheme.secondary,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 4,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            topScorerName,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tam $topScorerGoals gol atarak krallık koltuğuna oturdu! ⚽',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: scheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ));
                  }

                  // Slide 3: MVP
                  if (mvpName != null) {
                    slides.add((
                      key: _mvpSlideKey,
                      shareText: '🏅 $mvpName, ${tournament.name} turnuvasında MVP seçildi! competra.app',
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 48,
                            backgroundColor: Colors.amber.withValues(alpha: 0.2),
                            child: const Icon(Icons.stars, size: 48, color: Colors.amber),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'EN DEĞERLİ OYUNCU (MVP)',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: Colors.amber[800],
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            mvpName,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Oyuncuların oylarıyla turnuvanın en iyisi seçildi! 🏅\n($mvpVoteCount oy)',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ));
                  }

                  // Slide 4: Dramatic Match
                  if (dramaticMatch != null) {
                    slides.add((
                      key: _dramaticSlideKey,
                      shareText: '🔥 Turnuvanın en çekişmeli maçı: ${dramaticMatch.homeName} ${dramaticMatch.homeScore}-${dramaticMatch.awayScore} ${dramaticMatch.awayName}! competra.app',
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 48,
                            backgroundColor: Colors.orange.withValues(alpha: 0.2),
                            child: const Icon(Icons.local_fire_department, size: 48, color: Colors.orange),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'EN ÇEKİŞMELİ MAÇ',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: Colors.orange[800],
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              '${dramaticMatch.homeName}  ${dramaticMatch.homeScore} - ${dramaticMatch.awayScore}  ${dramaticMatch.awayName}',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Nefes kesen bu mücadele turnuvanın en dramatik maçı oldu! 🔥',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ));
                  }

                  // Slide 5: ELO Changes — gerçek eloHistory verisiyle
                  final eloChanges = eloChangesAsync.asData?.value ?? [];
                  if (eloChanges.isNotEmpty) {
                    slides.add((
                      key: _eloSlideKey,
                      shareText: '⚡ ELO değişimleri ve turnuva istatistikleri competra.app\'te!',
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.bolt, size: 48, color: scheme.primary),
                          const SizedBox(height: 16),
                          Text(
                            'ELO DEĞİŞİMLERİ',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 3,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: scheme.primary.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              children: [
                                for (int i = 0; i < eloChanges.length && i < 5; i++) ...[
                                  if (i > 0) const Divider(height: 16),
                                  _EloChangeRow(
                                    name: eloChanges[i].name,
                                    change: eloChanges[i].change.abs(),
                                    isGain: eloChanges[i].change >= 0,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ));
                  }

                  // Slide 6: Iron Wall
                  if (ironWall != null) {
                    slides.add((
                      key: _ironWallSlideKey,
                      shareText: '🛡️ En az gol yiyen Demir Duvar: ${ironWall.name} ($minConceded gol)! competra.app',
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 48,
                            backgroundColor: Colors.blue.withValues(alpha: 0.2),
                            child: const Icon(Icons.security, size: 48, color: Colors.blue),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'DEMİR DUVAR',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: Colors.blue[800],
                              fontWeight: FontWeight.w800,
                              letterSpacing: 4,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            ironWall.name,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Turnuva boyunca kalesinde sadece $minConceded gol gördü! 🛡️',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ));
                  }

                  // Slide 7: Timeline
                  slides.add((
                    key: _timelineSlideKey,
                    shareText: '📅 ${tournament.name} turnuvası zaman tüneli! competra.app',
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.calendar_month, size: 48, color: scheme.primary),
                        const SizedBox(height: 16),
                        Text(
                          'TURNUVA ZAMAN TÜNELİ',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _TimelineDetailRow(icon: Icons.flag_outlined, text: 'Turnuva başlangıcı: $formattedStartDate'),
                        const SizedBox(height: 12),
                        _TimelineDetailRow(icon: Icons.timer_outlined, text: '$totalDays günde tamamlandı'),
                        const SizedBox(height: 12),
                        _TimelineDetailRow(icon: Icons.sports_soccer, text: 'Toplam $playedCount maç oynandı'),
                        const SizedBox(height: 12),
                        _TimelineDetailRow(icon: Icons.bolt, text: 'En yoğun gün: $busiestDate ($maxMatches maç)'),
                      ],
                    ),
                  ));

                  // Slide 8: Stats Summary
                  slides.add((
                    key: _summarySlideKey,
                    shareText: '📊 ${tournament.name} turnuvası genel özet istatistikleri! competra.app',
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.analytics_outlined, size: 48, color: scheme.primary),
                        const SizedBox(height: 16),
                        Text(
                          'GENEL İSTATİSTİKLER',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 3,
                          ),
                        ),
                        const SizedBox(height: 24),
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.4,
                          children: [
                            _StatBox(value: '$playedCount', label: 'Toplam Maç', icon: Icons.sports_soccer_outlined),
                            _StatBox(value: '$totalGoals', label: 'Toplam Gol', icon: Icons.scoreboard_outlined),
                            _StatBox(value: '${tournament.participants.length}', label: 'Katılımcı', icon: Icons.group_outlined),
                            _StatBox(value: averageScore.toStringAsFixed(1), label: 'Maç Başı Gol', icon: Icons.insights_outlined),
                          ],
                        ),
                      ],
                    ),
                  ));

                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Column(
                        children: [
                          const SizedBox(height: 16),
                          // Premium Instagram-like stories progress bar
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Row(
                              children: List.generate(slides.length, (index) {
                                final isCompleted = index < _currentPage;
                                final isCurrent = index == _currentPage;
                                return Expanded(
                                  child: Container(
                                    height: 4,
                                    margin: const EdgeInsets.symmetric(horizontal: 2),
                                    decoration: BoxDecoration(
                                      color: isCompleted
                                          ? scheme.primary
                                          : isCurrent
                                              ? scheme.primary.withValues(alpha: 0.6)
                                              : scheme.onSurface.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Slide count indicator
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                '${_currentPage + 1} / ${slides.length}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: PageView.builder(
                              controller: _pageController,
                              itemCount: slides.length,
                              onPageChanged: (index) {
                                setState(() {
                                  _currentPage = index;
                                });
                                // Re-trigger confetti when Champion slide is viewed
                                if (index == 0) {
                                  _championConfetti.play();
                                } else {
                                  _championConfetti.stop();
                                }
                              },
                              itemBuilder: (context, index) {
                                final slide = slides[index];
                                return _SlideContainer(
                                  boundaryKey: slide.key,
                                  onShare: () => _shareSlide(slide.key, slide.shareText),
                                  child: slide.child,
                                );
                              },
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                OutlinedButton(
                                  onPressed: _currentPage > 0
                                      ? () {
                                          _pageController.previousPage(
                                            duration: const Duration(milliseconds: 300),
                                            curve: Curves.easeInOut,
                                          );
                                        }
                                      : null,
                                  child: const Text('Geri'),
                                ),
                                ElevatedButton.icon(
                                  onPressed: () => _shareWrapped(
                                    tournament.name,
                                    championName,
                                    topScorerName,
                                    topScorerGoals,
                                    playedCount,
                                    totalGoals,
                                    tournament.participants.length,
                                  ),
                                  icon: const Icon(Icons.share),
                                  label: const Text('Özeti Paylaş'),
                                ),
                                OutlinedButton(
                                  onPressed: _currentPage < slides.length - 1
                                      ? () {
                                          _pageController.nextPage(
                                            duration: const Duration(milliseconds: 300),
                                            curve: Curves.easeInOut,
                                          );
                                        }
                                      : null,
                                  child: const Text('İleri'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Off-screen elements kept only for full compilation share captures
                      Positioned(
                        left: -4000,
                        top: 0,
                        child: RepaintBoundary(
                          key: _shareChampionKey,
                          child: ChampionShareCard(
                            tournamentName: tournament.name,
                            championName: championName,
                            totalMatches: playedCount,
                            totalGoals: totalGoals,
                          ),
                        ),
                      ),
                      Positioned(
                        left: -4000,
                        top: 1000,
                        child: RepaintBoundary(
                          key: _shareScorerKey,
                          child: ScorerShareCard(
                            tournamentName: tournament.name,
                            scorerName: topScorerName,
                            goals: topScorerGoals,
                          ),
                        ),
                      ),
                      Positioned(
                        left: -4000,
                        top: 2000,
                        child: RepaintBoundary(
                          key: _shareSummaryKey,
                          child: SummaryShareCard(
                            tournamentName: tournament.name,
                            totalMatches: playedCount,
                            totalGoals: totalGoals,
                            totalPlayers: tournament.participants.length,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _SlideContainer extends StatelessWidget {
  const _SlideContainer({
    required this.boundaryKey,
    required this.child,
    required this.onShare,
  });

  final GlobalKey boundaryKey;
  final Widget child;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            Expanded(
              child: RepaintBoundary(
                key: boundaryKey,
                child: Container(
                  color: scheme.surface,
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: SingleChildScrollView(
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: onShare,
                    icon: const Icon(Icons.share_outlined, size: 18),
                    label: const Text('Bu Slaytı Paylaş'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
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
}

class _EloChangeRow extends StatelessWidget {
  const _EloChangeRow({
    required this.name,
    required this.change,
    required this.isGain,
  });

  final String name;
  final int change;
  final bool isGain;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            name,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          isGain ? '+$change ⚡' : '-$change',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: isGain ? Colors.green : scheme.error,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _TimelineDetailRow extends StatelessWidget {
  const _TimelineDetailRow({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: scheme.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
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
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.15)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: scheme.primary, size: 18),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
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
