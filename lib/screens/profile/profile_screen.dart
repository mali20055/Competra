import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/tournament.dart';
import '../../models/user_profile.dart';
import '../../router/route_paths.dart';
import '../../services/tournament_repository.dart';
import '../../services/user_repository.dart';

/// Bir rozet tanımı (kazanılmış olsun ya da olmasın katalogda yer alır).
typedef _BadgeDef = ({String id, String label, IconData icon});

/// Profil sekmesi.
///
/// FirebaseAuth + Firestore'dan kullanıcı verisini okur; kapak/avatar, kısa
/// biyografi, istatistikler, rozetler ve geçmiş turnuvaları gösterir. Tüm
/// renkler tema üzerinden gelir.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  /// Uygulamadaki tüm rozetlerin kataloğu.
  static const List<_BadgeDef> _badgeCatalog = [
    (id: 'first_win', label: 'İlk Galibiyet', icon: Icons.star),
    (id: 'champion', label: 'Şampiyon', icon: Icons.emoji_events),
    (id: 'hat_trick', label: 'Hat-trick', icon: Icons.sports_soccer),
    (id: 'veteran', label: 'Veteran', icon: Icons.shield),
    (id: 'social', label: 'Sosyal', icon: Icons.group),
    (id: 'sharpshooter', label: 'Keskin Nişancı', icon: Icons.my_location),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const _CenterMessage(
          icon: Icons.cloud_off_outlined,
          message: 'Profil yüklenemedi.',
        ),
        data: (profile) {
          if (profile == null) {
            return const _SignedOutView();
          }
          return _ProfileView(profile: profile, badgeCatalog: _badgeCatalog);
        },
      ),
    );
  }
}

class _ProfileView extends ConsumerWidget {
  const _ProfileView({required this.profile, required this.badgeCatalog});

  final UserProfile profile;
  final List<_BadgeDef> badgeCatalog;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tournamentsAsync = ref.watch(myTournamentsStreamProvider);
    final past = tournamentsAsync.asData?.value
            .where((t) => t.isCompleted)
            .toList() ??
        const <Tournament>[];

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _Header(profile: profile)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 56, 16, 0),
            child: Column(
              children: [
                Text(
                  profile.username,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (profile.favoriteTeam.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.favorite, size: 14, color: scheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        profile.favoriteTeam,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
                if (profile.bio.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    profile.bio,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurface,
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                _StatsRow(profile: profile),
                const SizedBox(height: 28),
                _SectionTitle(icon: Icons.workspace_premium, title: 'Rozetler'),
                const SizedBox(height: 12),
                _BadgeGrid(catalog: badgeCatalog, earned: profile.badges),
                const SizedBox(height: 28),
                _SectionTitle(icon: Icons.history, title: 'Geçmiş Turnuvalar'),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        if (past.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 32),
              child: _InlineEmpty(message: 'Henüz tamamlanan turnuvan yok.'),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            sliver: SliverList.separated(
              itemCount: past.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) => _PastTournamentTile(
                tournament: past[index],
                onTap: () => context.pushNamed(
                  RoutePaths.tournamentDetailName,
                  pathParameters: {'id': past[index].id},
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Kapak alanı + avatar + ayarlar ikonu.
class _Header extends StatelessWidget {
  const _Header({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SizedBox(
      height: 200,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Kapak fotoğrafı alanı (görsel yoksa dekoratif degrade).
          Container(
            height: 160,
            width: double.infinity,
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
            child: profile.coverUrl.isEmpty
                ? null
                : Image.network(
                    profile.coverUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
          ),
          // Ayarlar ikonu.
          Positioned(
            top: 8,
            right: 8,
            child: SafeArea(
              child: Material(
                color: scheme.surface.withValues(alpha: 0.85),
                shape: const CircleBorder(),
                child: IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  tooltip: 'Ayarlar',
                  onPressed: () => context.pushNamed(RoutePaths.settingsName),
                ),
              ),
            ),
          ),
          // Profil fotoğrafı (kapak ile içerik arasında ortalanmış).
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  shape: BoxShape.circle,
                ),
                child: CircleAvatar(
                  radius: 48,
                  backgroundColor: scheme.surface,
                  backgroundImage: profile.photoUrl.isEmpty
                      ? null
                      : NetworkImage(profile.photoUrl),
                  child: profile.photoUrl.isEmpty
                      ? Text(
                          _initials(profile.username),
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        )
                      : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first.characters.take(2).toString().toUpperCase();
    }
    return (parts.first.characters.take(1).toString() +
            parts[1].characters.take(1).toString())
        .toUpperCase();
  }
}

/// Maç / Galibiyet% / Gol / Şampiyonluk istatistik satırı.
class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          _StatItem(value: '${profile.matches}', label: 'Maç'),
          _Divider(),
          _StatItem(value: '%${profile.winRate}', label: 'Galibiyet'),
          _Divider(),
          _StatItem(value: '${profile.goals}', label: 'Gol'),
          _Divider(),
          _StatItem(value: '${profile.championships}', label: 'Şampiyonluk'),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 36,
      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
    );
  }
}

/// Rozet grid'i — kazanılanlar renkli, kazanılmayanlar soluk/gri.
class _BadgeGrid extends StatelessWidget {
  const _BadgeGrid({required this.catalog, required this.earned});

  final List<_BadgeDef> catalog;
  final Set<String> earned;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.95,
      children: [
        for (final badge in catalog)
          _BadgeTile(badge: badge, earned: earned.contains(badge.id)),
      ],
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.badge, required this.earned});

  final _BadgeDef badge;
  final bool earned;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final Color accent =
        earned ? scheme.primary : scheme.onSurfaceVariant.withValues(alpha: 0.5);

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: earned
            ? scheme.primary.withValues(alpha: 0.10)
            : scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: earned
              ? scheme.primary.withValues(alpha: 0.4)
              : scheme.outline.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(badge.icon, size: 28, color: accent),
          const SizedBox(height: 8),
          Text(
            badge.label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: earned ? scheme.onSurface : scheme.onSurfaceVariant,
              fontWeight: earned ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _PastTournamentTile extends StatelessWidget {
  const _PastTournamentTile({required this.tournament, required this.onTap});

  final Tournament tournament;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: scheme.outline.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.emoji_events_outlined, color: scheme.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  tournament.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

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
      ],
    );
  }
}

class _InlineEmpty extends StatelessWidget {
  const _InlineEmpty({required this.message});

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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.15)),
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

/// Oturum açılmamışken gösterilen görünüm.
class _SignedOutView extends StatelessWidget {
  const _SignedOutView();

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
            Icon(Icons.account_circle_outlined,
                size: 64, color: scheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              'Oturum açılmamış',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Profilini görmek için giriş yap.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.goNamed(RoutePaths.loginName),
              child: const Text('Giriş Yap'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CenterMessage extends StatelessWidget {
  const _CenterMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: scheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
