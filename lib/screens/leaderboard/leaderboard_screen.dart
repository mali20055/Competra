import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/user_profile.dart';
import '../../services/firebase_providers.dart';

/// Liderlik tablosunun sıralandığı ölçüt.
enum LeaderboardMetric {
  wins('Galibiyet', 'totalWins'),
  goals('Gol', 'totalGoalsScored'),
  tournaments('Turnuva', 'tournamentsWon');

  const LeaderboardMetric(this.label, this.field);

  /// Sekme etiketi.
  final String label;

  /// Firestore'da sıralanacak (DESC) alan adı.
  final String field;

  /// Bir profilden bu ölçüte karşılık gelen değeri okur.
  int valueOf(UserProfile p) => switch (this) {
        LeaderboardMetric.wins => p.totalWins,
        LeaderboardMetric.goals => p.totalGoalsScored,
        LeaderboardMetric.tournaments => p.tournamentsWon,
      };
}

/// Seçilen [LeaderboardMetric]'e göre, ilgili alanda azalan sıralı ilk 50
/// kullanıcıyı canlı yayınlar (`users` koleksiyonu).
final leaderboardProvider =
    StreamProvider.family<List<UserProfile>, LeaderboardMetric>((ref, metric) {
  return ref
      .watch(firestoreProvider)
      .collection('users')
      .orderBy(metric.field, descending: true)
      .limit(50)
      .snapshots()
      .map((snap) => snap.docs.map(UserProfile.fromDoc).toList());
});

/// Global liderlik tablosu ekranı.
///
/// Üç ölçüt (galibiyet, gol, turnuva) arasında geçiş yapılabilir; her ölçüt
/// için ilk 50 kullanıcı canlı olarak listelenir. İlk üç sıra altın/gümüş/bronz
/// madalyayla, oturum açmış kullanıcının kendi sırası vurgulu arka planla
/// gösterilir. Tüm renkler (madalya tonları hariç) tema üzerinden gelir.
class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  LeaderboardMetric _metric = LeaderboardMetric.wins;

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(leaderboardProvider(_metric));
    final myUid = ref.watch(currentUserProvider)?.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Global Sıralama')),
      body: Column(
        children: [
          _MetricSelector(
            selected: _metric,
            onChanged: (m) => setState(() => _metric = m),
          ),
          Expanded(
            child: entriesAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (_, __) => const _EmptyState(message: 'Henüz veri yok'),
              data: (entries) {
                if (entries.isEmpty) {
                  return const _EmptyState(message: 'Henüz veri yok');
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final profile = entries[index];
                    return _LeaderboardTile(
                      rank: index + 1,
                      profile: profile,
                      metric: _metric,
                      isMe: profile.uid == myUid,
                    )
                        .animate()
                        .fadeIn(delay: (index * 50).ms, duration: 320.ms)
                        .slideX(begin: 0.1, end: 0);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Ölçüt seçim sekmeleri (Galibiyet | Gol | Turnuva).
class _MetricSelector extends StatelessWidget {
  const _MetricSelector({required this.selected, required this.onChanged});

  final LeaderboardMetric selected;
  final ValueChanged<LeaderboardMetric> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: SegmentedButton<LeaderboardMetric>(
        segments: [
          for (final m in LeaderboardMetric.values)
            ButtonSegment<LeaderboardMetric>(value: m, label: Text(m.label)),
        ],
        selected: {selected},
        showSelectedIcon: false,
        onSelectionChanged: (set) => onChanged(set.first),
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return scheme.primary;
            }
            return scheme.surface;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return scheme.onPrimary;
            }
            return scheme.onSurfaceVariant;
          }),
        ),
      ),
    );
  }
}

/// Tek bir sıralama satırı.
class _LeaderboardTile extends StatelessWidget {
  const _LeaderboardTile({
    required this.rank,
    required this.profile,
    required this.metric,
    required this.isMe,
  });

  final int rank;
  final UserProfile profile;
  final LeaderboardMetric metric;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final initial =
        profile.username.isNotEmpty ? profile.username[0].toUpperCase() : '?';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        // Kendi sıram vurgulu arka planla gösterilir.
        color: isMe
            ? scheme.primary.withValues(alpha: 0.14)
            : scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isMe
              ? scheme.primary.withValues(alpha: 0.5)
              : scheme.outline.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          // Sıra numarası ya da ilk üç için madalya.
          SizedBox(width: 36, child: _RankBadge(rank: rank)),
          const SizedBox(width: 8),

          // Avatar (baş harf).
          CircleAvatar(
            radius: 20,
            backgroundColor: scheme.primary.withValues(alpha: 0.18),
            child: Text(
              initial,
              style: theme.textTheme.titleMedium?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Kullanıcı adı + aktif unvan.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (profile.activeTitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    profile.activeTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),

          // İlgili istatistik değeri.
          Text(
            '${metric.valueOf(profile)}',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: scheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

/// İlk üç sıra için madalya ikonu (altın/gümüş/bronz), diğerleri için numara.
class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank});

  final int rank;

  // Madalya tonları (sıralamaya özgü, bilinçli olarak temadan bağımsız).
  static const Color _gold = Color(0xFFFFD700);
  static const Color _silver = Color(0xFFC0C0C0);
  static const Color _bronze = Color(0xFFCD7F32);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final medal = switch (rank) {
      1 => _gold,
      2 => _silver,
      3 => _bronze,
      _ => null,
    };

    if (medal != null) {
      return Center(child: Icon(Icons.emoji_events, color: medal, size: 28));
    }
    return Center(
      child: Text(
        '$rank',
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

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
            Icon(Icons.leaderboard_outlined,
                size: 56, color: scheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
