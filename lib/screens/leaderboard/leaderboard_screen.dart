import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/skeleton_widgets.dart';
import '../../components/player_avatar.dart';
import '../../core/constants/app_constants.dart';
import '../../models/user_profile.dart';
import '../../router/route_paths.dart';
import '../../services/firebase_providers.dart';
import '../../services/season_repository.dart';

/// Liderlik tablosunun sıralandığı ölçüt.
enum LeaderboardMetric {
  wins('Galibiyet', 'totalWins'),
  goals('Gol', 'totalGoalsScored'),
  tournaments('Turnuva', 'tournamentsWon'),
  elo('ELO', 'eloRating');

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
        LeaderboardMetric.elo => p.eloRating,
      };
}

/// Seçilen [LeaderboardMetric]'e göre, ilgili alanda azalan sıralı ilk
/// [AppConstants.leaderboardLimit] kullanıcıyı canlı yayınlar (`users`
/// koleksiyonu). Daha fazlası "Daha fazla yükle" ile [fetchNextLeaderboardPage]
/// üzerinden ayrıca çekilir.
class LeaderboardArgs {
  final LeaderboardMetric metric;
  final String? seasonId;

  const LeaderboardArgs({required this.metric, this.seasonId});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeaderboardArgs &&
          runtimeType == other.runtimeType &&
          metric == other.metric &&
          seasonId == other.seasonId;

  @override
  int get hashCode => metric.hashCode ^ seasonId.hashCode;
}

final leaderboardProvider =
    StreamProvider.family<List<UserProfile>, LeaderboardArgs>((ref, args) {
  final queryField = args.seasonId != null
      ? (args.metric == LeaderboardMetric.goals
          ? 'seasonStats.${args.seasonId}.totalGoalsScored'
          : 'seasonStats.${args.seasonId}.totalWins')
      : args.metric.field;

  return ref
      .watch(firestoreProvider)
      .collection('users')
      .orderBy(queryField, descending: true)
      .limit(AppConstants.leaderboardLimit)
      .snapshots()
      .map((snap) => snap.docs.map(UserProfile.fromDoc).toList());
});

/// Bir liderlik tablosu sayfası: öğeler + sonraki sayfa için
/// `startAfterDocument` anahtarı + daha fazla sayfa olup olmadığı.
class LeaderboardPage {
  const LeaderboardPage({
    required this.items,
    required this.lastDoc,
    required this.hasMore,
  });

  final List<UserProfile> items;
  final DocumentSnapshot<Map<String, dynamic>>? lastDoc;
  final bool hasMore;
}

/// `startAfter`'dan sonraki liderlik tablosu sayfasını çeker.
Future<LeaderboardPage> fetchNextLeaderboardPage({
  required FirebaseFirestore firestore,
  required LeaderboardMetric metric,
  required String? seasonId,
  required DocumentSnapshot<Map<String, dynamic>> startAfter,
  int limit = AppConstants.leaderboardLimit,
}) async {
  final queryField = seasonId != null
      ? (metric == LeaderboardMetric.goals
          ? 'seasonStats.$seasonId.totalGoalsScored'
          : 'seasonStats.$seasonId.totalWins')
      : metric.field;

  final snap = await firestore
      .collection('users')
      .orderBy(queryField, descending: true)
      .startAfterDocument(startAfter)
      .limit(limit)
      .get();
  return LeaderboardPage(
    items: snap.docs.map(UserProfile.fromDoc).toList(),
    lastDoc: snap.docs.isEmpty ? null : snap.docs.last,
    hasMore: snap.docs.length == limit,
  );
}

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

enum LeaderboardTimeScope {
  thisSeason('Bu Sezon'),
  allTime('Tüm Zamanlar');

  const LeaderboardTimeScope(this.label);
  final String label;
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  LeaderboardMetric _metric = LeaderboardMetric.wins;
  LeaderboardTimeScope _timeScope = LeaderboardTimeScope.allTime;

  final List<UserProfile> _moreItems = [];
  DocumentSnapshot<Map<String, dynamic>>? _lastDoc;
  bool _hasMore = true;
  bool _loadingMore = false;

  void _changeMetric(LeaderboardMetric metric) async {
    if (metric == LeaderboardMetric.elo) {
      final isPremium = await ref.read(isPremiumProvider.future);
      if (!isPremium) {
        if (mounted) {
          context.pushNamed(RoutePaths.premiumName);
        }
        return;
      }
    }
    setState(() {
      _metric = metric;
      // Ölçüt değişince sıralama tamamen değişir; eklenen sayfaları sıfırla.
      _moreItems.clear();
      _lastDoc = null;
      _hasMore = true;
      _loadingMore = false;
    });
  }

  void _changeTimeScope(LeaderboardTimeScope scope) {
    setState(() {
      _timeScope = scope;
      _moreItems.clear();
      _lastDoc = null;
      _hasMore = true;
      _loadingMore = false;
    });
  }

  Future<void> _loadMore(List<UserProfile> liveItems, String? seasonId) async {
    if (_loadingMore || !_hasMore) return;

    setState(() => _loadingMore = true);
    final firestore = ref.read(firestoreProvider);
    try {
      var anchor = _lastDoc;
      if (anchor == null) {
        final loaded = [...liveItems, ..._moreItems];
        if (loaded.isEmpty) {
          setState(() => _loadingMore = false);
          return;
        }
        anchor =
            await firestore.collection('users').doc(loaded.last.uid).get();
      }

      final page = await fetchNextLeaderboardPage(
        firestore: firestore,
        metric: _metric,
        seasonId: seasonId,
        startAfter: anchor,
      );
      setState(() {
        _moreItems.addAll(page.items);
        _lastDoc = page.lastDoc ?? anchor;
        _hasMore = page.hasMore;
        _loadingMore = false;
      });
    } catch (_) {
      setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeSeasonAsync = ref.watch(activeSeasonProvider);
    final activeSeason = activeSeasonAsync.asData?.value;
    final seasonId = _timeScope == LeaderboardTimeScope.thisSeason ? activeSeason?.id : null;

    final queryArgs = LeaderboardArgs(metric: _metric, seasonId: seasonId);
    final entriesAsync = ref.watch(leaderboardProvider(queryArgs));
    final myUid = ref.watch(currentUserProvider)?.uid;
    final isPremium = ref.watch(isPremiumProvider).value ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Global Sıralama')),
      body: Column(
        children: [
          _TimeScopeSelector(
            selected: _timeScope,
            onChanged: _changeTimeScope,
          ),
          _MetricSelector(
            selected: _metric,
            onChanged: _changeMetric,
            isPremium: isPremium,
          ),
          Expanded(
            child: entriesAsync.when(
              loading: () => Column(
                children: List.generate(6, (_) => const SkeletonListTile()),
              ),
              error: (_, __) => const _EmptyState(message: 'Henüz veri yok'),
              data: (liveItems) {
                final entries = [...liveItems, ..._moreItems];
                if (entries.isEmpty) {
                  return const _EmptyState(message: 'Henüz veri yok');
                }
                final showLoadMore = _hasMore &&
                    liveItems.length >= AppConstants.leaderboardLimit;
                return RefreshIndicator(
                  color: Theme.of(context).colorScheme.primary,
                  onRefresh: () async {
                    ref.invalidate(leaderboardProvider);
                    ref.invalidate(activeSeasonProvider);
                  },
                  child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: entries.length + (showLoadMore ? 1 : 0),
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    if (index >= entries.length) {
                      return _LoadMoreButton(
                        loading: _loadingMore,
                        onPressed: () => _loadMore(liveItems, seasonId),
                      );
                    }
                    final profile = entries[index];
                    return _LeaderboardTile(
                      rank: index + 1,
                      profile: profile,
                      metric: _metric,
                      seasonId: seasonId,
                      isMe: profile.uid == myUid,
                      onTap: () => context.pushNamed(
                        RoutePaths.userProfileName,
                        pathParameters: {'uid': profile.uid},
                      ),
                    )
                        .animate()
                        .fadeIn(delay: (index * 50).ms, duration: 320.ms)
                        .slideX(begin: 0.1, end: 0);
                  },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Liste sonundaki "Daha fazla yükle" butonu.
class _LoadMoreButton extends StatelessWidget {
  const _LoadMoreButton({required this.loading, required this.onPressed});

  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: loading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            : OutlinedButton(
                onPressed: onPressed,
                child: const Text('Daha fazla yükle'),
              ),
      ),
    );
  }
}

/// Ölçüt seçim sekmeleri (Galibiyet | Gol | Turnuva).
class _MetricSelector extends StatelessWidget {
  const _MetricSelector({
    required this.selected,
    required this.onChanged,
    required this.isPremium,
  });

  final LeaderboardMetric selected;
  final ValueChanged<LeaderboardMetric> onChanged;
  final bool isPremium;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: SegmentedButton<LeaderboardMetric>(
        segments: [
          for (final m in LeaderboardMetric.values)
            ButtonSegment<LeaderboardMetric>(
              value: m,
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(m.label),
                  if (m == LeaderboardMetric.elo && !isPremium) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.lock, size: 14),
                  ],
                ],
              ),
            ),
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

class _TimeScopeSelector extends StatelessWidget {
  const _TimeScopeSelector({
    required this.selected,
    required this.onChanged,
  });

  final LeaderboardTimeScope selected;
  final ValueChanged<LeaderboardTimeScope> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: SegmentedButton<LeaderboardTimeScope>(
        segments: [
          for (final s in LeaderboardTimeScope.values)
            ButtonSegment<LeaderboardTimeScope>(
              value: s,
              label: Text(s.label),
            ),
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
    this.seasonId,
    required this.isMe,
    this.onTap,
  });

  final int rank;
  final UserProfile profile;
  final LeaderboardMetric metric;
  final String? seasonId;
  final bool isMe;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
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
          PlayerAvatar(
            name: profile.username,
            radius: 20,
            activeFrame: profile.activeFrame,
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
            seasonId != null
                ? '${profile.getSeasonMetric(seasonId!, metric.field)}'
                : '${metric.valueOf(profile)}',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: scheme.primary,
            ),
          ),
        ],
      ),
    ),
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
