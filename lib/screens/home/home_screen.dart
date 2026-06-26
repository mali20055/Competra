import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/pitch_pattern_background.dart';
import '../../core/time_ago.dart';
import '../../core/utils/format_labels.dart';
import '../../models/feed_item.dart';
import '../../models/tournament.dart';
import '../../router/route_paths.dart';
import '../../services/feed_repository.dart';
import '../../services/tournament_repository.dart';
import '../../services/user_repository.dart';
import '../../services/season_repository.dart';
import '../../components/skeleton_widgets.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../l10n/app_localizations.dart';

/// Ana panel (Home Dashboard).
///
/// Tüm veriler Firestore'dan canlı ([StreamProvider]) gelir; veri yoksa boş
/// durum gösterilir. Tüm renkler tema üzerinden ([Theme.of]) alınır. Bölümler
/// [flutter_animate] ile kademeli (staggered) fade-in + slide ile belirir.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final username =
        ref.watch(userProfileProvider).asData?.value?.username ?? 'Oyuncu';
    final tournamentsAsync = ref.watch(myTournamentsStreamProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: _HomeAppBar(username: username),
      body: PitchPatternBackground(
        child: SafeArea(
          top: false,
          child: RefreshIndicator(
            color: Theme.of(context).colorScheme.primary,
            onRefresh: () async {
              ref.invalidate(myTournamentsStreamProvider);
              ref.invalidate(activityFeedProvider);
              ref.invalidate(activeSeasonProvider);
            },
            child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              const _SeasonCountdownWidget()
                  .animate()
                  .fadeIn(duration: 350.ms)
                  .slideY(begin: 0.1, end: 0),
              const SizedBox(height: 16),
              const _ActionButtons()
                  .animate()
                  .fadeIn(duration: 400.ms)
                  .slideY(begin: 0.12, end: 0),
              const SizedBox(height: 20),
              const _QuickStats()
                  .animate()
                  .fadeIn(delay: 80.ms, duration: 420.ms)
                  .slideY(begin: 0.12, end: 0),
              const SizedBox(height: 28),
              tournamentsAsync
                  .when(
                    loading: () => const _LoadingCard(),
                    error: (_, __) => _MessageCard(
                      message: l10n.tournamentsLoadFailed,
                    ),
                    data: (all) {
                      final active =
                          all.where((t) => !t.isCompleted).toList();
                      if (active.isEmpty) return const _EmptyTournaments();
                      return _ActiveTournaments(tournaments: active);
                    },
                  )
                  .animate()
                  .fadeIn(delay: 120.ms, duration: 450.ms)
                  .slideY(begin: 0.12, end: 0),
              const SizedBox(height: 28),
              const _RecentActivity()
                  .animate()
                  .fadeIn(delay: 200.ms, duration: 450.ms)
                  .slideY(begin: 0.12, end: 0),
            ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// AppBar
// ---------------------------------------------------------------------------

/// Selamlama metni + sağda kullanıcı avatarı içeren üst bar.
class _HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _HomeAppBar({required this.username});

  final String username;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 8);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final initial =
        username.isEmpty ? '?' : username.substring(0, 1).toUpperCase();

    return AppBar(
      centerTitle: false,
      titleSpacing: 20,
      title: Text(
        l10n.welcomeMessage(username),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      actions: [
        IconButton(
          tooltip: l10n.leaderboard,
          onPressed: () => context.pushNamed(RoutePaths.leaderboardName),
          icon: const Icon(Icons.leaderboard_outlined),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 20),
          child: CircleAvatar(
            radius: 20,
            backgroundColor: scheme.primary.withValues(alpha: 0.15),
            child: Text(
              initial,
              style: theme.textTheme.titleMedium?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Aksiyon butonları
// ---------------------------------------------------------------------------

/// Yan yana iki ana aksiyon: "Turnuva Oluştur" ve "Turnuvaya Katıl".
class _ActionButtons extends StatelessWidget {
  const _ActionButtons();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            icon: Icons.emoji_events_outlined,
            label: l10n.createTournament,
            onPressed: () =>
                context.pushNamed(RoutePaths.createTournamentName),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _ActionButton(
            icon: Icons.link,
            label: l10n.joinTournament,
            onPressed: () => context.pushNamed(RoutePaths.joinTournamentName),
          ),
        ),
      ],
    );
  }
}

/// İkon + etiket içeren, tam yükseklikte primary aksiyon butonu.
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(96),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 30),
          const SizedBox(height: 10),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bölüm başlığı
// ---------------------------------------------------------------------------

/// Bölümlerin üstünde kullanılan ortak başlık.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hızlı istatistik özeti
// ---------------------------------------------------------------------------

/// Oturum açmış kullanıcının `users/{uid}` istatistiklerinden hızlı özet:
/// toplam maç, galibiyet yüzdesi ve toplam gol.
class _QuickStats extends ConsumerWidget {
  const _QuickStats();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider).asData?.value;
    final matches = profile?.totalMatches ?? 0;
    final winRate = profile?.winRate ?? 0;
    final goals = profile?.totalGoalsScored ?? 0;
    final l10n = AppLocalizations.of(context);

    return Row(
      children: [
        Expanded(
          child: _StatTile(
            icon: Icons.sports_soccer,
            value: '$matches',
            label: l10n.totalMatches,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatTile(
            icon: Icons.emoji_events_outlined,
            value: '%$winRate',
            label: l10n.wins,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatTile(
            icon: Icons.sports_score_outlined,
            value: '$goals',
            label: l10n.totalGoals,
          ),
        ),
      ],
    );
  }
}

/// Hızlı istatistik satırındaki tek bir kutu.
class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 22, color: scheme.primary),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Arkadaş aktivitesi (Feed)
// ---------------------------------------------------------------------------

/// Arkadaşlarının son aktivitelerini gösteren bölüm.
class _RecentActivity extends ConsumerWidget {
  const _RecentActivity();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(activityFeedProvider);
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(l10n.recentActivity),
        const SizedBox(height: 14),
        async.when(
          loading: () => Column(
            children: List.generate(3, (_) => const SkeletonListTile()),
          ),
          error: (_, __) =>
              _MessageCardBody(message: l10n.activityLoadFailed),
          data: (items) {
            if (items.isEmpty) {
              return _MessageCardBody(
                message: l10n.noActivityYet,
              );
            }
            final recent = items.take(10).toList();
            return Column(
              children: [
                for (var i = 0; i < recent.length; i++) ...[
                  _ActivityTile(item: recent[i]),
                  if (i != recent.length - 1) const SizedBox(height: 10),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Tek bir aktivite satırı: aktör resmi + mesaj + zaman.
class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.item});

  final FeedItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final time = timeAgo(item.createdAt, l10n.localeName);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: scheme.primary.withValues(alpha: 0.15),
            backgroundImage: item.actorPhotoUrl != null && item.actorPhotoUrl!.isNotEmpty
                ? CachedNetworkImageProvider(item.actorPhotoUrl!)
                : null,
            child: item.actorPhotoUrl == null || item.actorPhotoUrl!.isEmpty
                ? Text(
                    item.actorName.isEmpty ? '?' : item.actorName.substring(0, 1).toUpperCase(),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.message,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.3),
                ),
                if (time.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    time,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (item.tournamentId != null)
            IconButton(
              icon: Icon(Icons.arrow_forward_ios, size: 14, color: scheme.primary),
              onPressed: () => context.pushNamed(
                RoutePaths.tournamentDetailName,
                pathParameters: {'id': item.tournamentId!},
              ),
            ),
        ],
      ),
    );
  }
}

/// Bölüm içinde kullanılan basit mesaj/boş durum kartı (başlıksız).
class _MessageCardBody extends StatelessWidget {
  const _MessageCardBody({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.2)),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Aktif turnuvalar (yatay liste)
// ---------------------------------------------------------------------------

/// "Aktif Turnuvalar" başlığı + yatay kaydırmalı kart listesi.
class _ActiveTournaments extends StatelessWidget {
  const _ActiveTournaments({required this.tournaments});

  final List<Tournament> tournaments;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(l10n.activeTournaments),
        const SizedBox(height: 14),
        SizedBox(
          height: 168,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: tournaments.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, index) =>
                _TournamentCard(tournament: tournaments[index]),
          ),
        ),
      ],
    );
  }
}

/// Tek bir turnuvayı özetleyen kart.
class _TournamentCard extends StatelessWidget {
  const _TournamentCard({required this.tournament});

  final Tournament tournament;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return SizedBox(
      width: 240,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.pushNamed(
          RoutePaths.tournamentDetailName,
          pathParameters: {'id': tournament.id},
        ),
        child: Container(
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
                  Expanded(
                    child: Text(
                      tournament.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _FormatBadge(format: tournament.format),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.group_outlined,
                    size: 15,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    l10n.participantCountLabel(tournament.participants.length),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      tournament.isWaiting
                          ? Icons.hourglass_top
                          : Icons.sports_soccer,
                      size: 16,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      tournament.isWaiting ? l10n.lobbyStatus : l10n.ongoingStatus,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w600,
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

/// Turnuva formatını gösteren küçük rozet.
class _FormatBadge extends StatelessWidget {
  const _FormatBadge({required this.format});

  final String format;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.secondary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        tournamentFormatLabel(format, l10n).toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: scheme.primary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Durum widget'ları
// ---------------------------------------------------------------------------

/// Aktif turnuva yokken gösterilen boş durum widget'ı.
class _EmptyTournaments extends StatelessWidget {
  const _EmptyTournaments();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(l10n.activeTournaments),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.outline.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              Icon(
                Icons.sports_soccer,
                size: 56,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.noTournamentsYet,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.noTournamentsYetDesc,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () =>
                    context.pushNamed(RoutePaths.createTournamentName),
                icon: const Icon(Icons.add, size: 20),
                label: Text(l10n.createFirstTournament),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Turnuvalar yüklenirken gösterilen yer tutucu.
class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(l10n.activeTournaments),
        const SizedBox(height: 14),
        const SizedBox(
          height: 120,
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
    );
  }
}

/// Hata gibi durumlarda gösterilen basit mesaj kartı.
class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(l10n.activeTournaments),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.outline.withValues(alpha: 0.2)),
          ),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// Turnuva formatı kod adını kısa Türkçe etikete çevirir.

class _SeasonCountdownWidget extends ConsumerWidget {
  const _SeasonCountdownWidget();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeSeasonAsync = ref.watch(activeSeasonProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return activeSeasonAsync.when(
      data: (season) {
        if (season == null) return const SizedBox.shrink();
        final daysRemaining = DateTime.now().isAfter(season.endDate)
            ? 0
            : season.endDate.difference(DateTime.now()).inDays;

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: scheme.primary.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 16,
                color: scheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.seasonCountdownLabel(season.name, daysRemaining),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.primary,
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
