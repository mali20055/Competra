import 'package:cached_network_image/cached_network_image.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/badge_definitions.dart';
import '../../models/tournament.dart';
import '../../models/user_profile.dart';
import '../../router/route_paths.dart';
import '../../services/share_service.dart';
import '../../services/tournament_repository.dart';
import '../../services/user_repository.dart';
import '../../widgets/achievement_share_card.dart';
import 'widgets/elo_chart.dart';

/// Profil sekmesi.
///
/// FirebaseAuth + Firestore'dan kullanıcı verisini okur; kapak/avatar, kısa
/// biyografi, istatistikler, rozetler ve geçmiş turnuvaları gösterir. Tüm
/// renkler tema üzerinden gelir.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

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
          return _ProfileView(profile: profile);
        },
      ),
    );
  }
}

class _ProfileView extends ConsumerStatefulWidget {
  const _ProfileView({required this.profile});

  final UserProfile profile;

  @override
  ConsumerState<_ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends ConsumerState<_ProfileView> {
  final GlobalKey _shareKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tournamentsAsync = ref.watch(myTournamentsStreamProvider);
    final past = tournamentsAsync.asData?.value
            .where((t) => t.isCompleted)
            .toList() ??
        const <Tournament>[];

    return Stack(
      children: [
        Positioned(
          left: -1000,
          top: -1000,
          child: RepaintBoundary(
            key: _shareKey,
            child: AchievementShareCard(profile: profile),
          ),
        ),
        CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _Header(
                profile: profile,
                shareKey: _shareKey,
              ),
            ),
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
                    const SizedBox(height: 12),
                    _EloChip(profile: profile),
                    const SizedBox(height: 28),
                    _SectionTitle(icon: Icons.show_chart, title: 'Son Form'),
                    const SizedBox(height: 12),
                    const _FormChart(),
                    const SizedBox(height: 28),
                    _SectionTitle(icon: Icons.percent, title: 'Galibiyet Oranı'),
                    const SizedBox(height: 12),
                    _WinRateGauge(profile: profile),
                    const SizedBox(height: 28),
                    _SectionTitle(icon: Icons.bolt, title: 'ELO Geçmişi'),
                    const SizedBox(height: 12),
                    EloChart(history: profile.eloHistory),
                    const SizedBox(height: 28),
                    const _ShowcaseHeader(),
                    const SizedBox(height: 12),
                    _ShowcaseGrid(profile: profile),
                    const SizedBox(height: 28),
                    _SectionTitle(icon: Icons.workspace_premium, title: 'Rozetler'),
                    const SizedBox(height: 12),
                    _BadgeGrid(earned: profile.badges),
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
        ),
      ],
    );
  }
}

/// Kapak alanı + avatar + ayarlar ikonu.
class _Header extends StatelessWidget {
  const _Header({required this.profile, required this.shareKey});

  final UserProfile profile;
  final GlobalKey shareKey;

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
                : CachedNetworkImage(
                    imageUrl: profile.coverUrl,
                    fit: BoxFit.cover,
                    placeholder: (ctx, _) => Container(
                      color: Theme.of(ctx)
                          .colorScheme
                          .surfaceContainerHighest,
                    ),
                    errorWidget: (ctx, _, __) => const SizedBox.shrink(),
                  ),
          ),
          // Profili düzenle ikonu (sol üst).
          Positioned(
            top: 8,
            left: 8,
            child: SafeArea(
              child: Material(
                color: scheme.surface.withValues(alpha: 0.85),
                shape: const CircleBorder(),
                child: IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Profili Düzenle',
                  onPressed: () => context.pushNamed(RoutePaths.editProfileName),
                ),
              ),
            ),
          ),
          // Paylaş ikonu (sağ üst, ayarların solunda).
          Positioned(
            top: 8,
            right: 56,
            child: SafeArea(
              child: Material(
                color: scheme.surface.withValues(alpha: 0.85),
                shape: const CircleBorder(),
                child: IconButton(
                  icon: const Icon(Icons.share_outlined),
                  tooltip: 'Paylaş',
                  onPressed: () => _shareAchievement(context, profile, shareKey),
                ),
              ),
            ),
          ),
          // Ayarlar ikonu (sağ üst).
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

// Form/oran grafiklerinde galibiyet/mağlubiyet/beraberlik için sabit, anlamsal
// renkler (yeşil/kırmızı/amber) — veri görselleştirmesinde alışıldık kodlama.
const Color _winColor = Color(0xFF2E9E5B);
const Color _lossColor = Color(0xFFD64545);
const Color _drawColor = Color(0xFFD9A21B);

/// Son 10 maçın sonucunu renkli barlarla gösteren form grafiği.
///
/// Her bar bir maçtır: galibiyet yeşil, mağlubiyet kırmızı, beraberlik amber.
/// Veri yoksa "Henüz maç oynanmadı" gösterilir.
class _FormChart extends ConsumerWidget {
  const _FormChart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final resultsAsync = ref.watch(userRecentMatchesProvider);

    Widget shell(Widget child) => Container(
          height: 150,
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.outline.withValues(alpha: 0.2)),
          ),
          child: child,
        );

    return resultsAsync.when(
      loading: () =>
          shell(const Center(child: CircularProgressIndicator())),
      error: (_, __) =>
          shell(const _InlineEmpty(message: 'Form yüklenemedi.')),
      data: (results) {
        if (results.isEmpty) {
          return shell(const _InlineEmpty(message: 'Henüz maç oynanmadı'));
        }
        return shell(
          BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: 1.2,
              minY: 0,
              barTouchData: BarTouchData(enabled: false),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 22,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i < 0 || i >= results.length) {
                        return const SizedBox.shrink();
                      }
                      final (letter, color) = switch (results[i].kind) {
                        MatchResultKind.win => ('G', _winColor),
                        MatchResultKind.loss => ('M', _lossColor),
                        MatchResultKind.draw => ('B', _drawColor),
                      };
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          letter,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: color,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < results.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: 1,
                        width: 16,
                        borderRadius: BorderRadius.circular(4),
                        color: switch (results[i].kind) {
                          MatchResultKind.win => _winColor,
                          MatchResultKind.loss => _lossColor,
                          MatchResultKind.draw => _drawColor,
                        },
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Galibiyet/mağlubiyet oranını gösteren dairesel (donut) gösterge.
///
/// Yeşil dilim galibiyetleri, kırmızı dilim mağlubiyetleri temsil eder; ortada
/// galibiyet yüzdesi yazar.
class _WinRateGauge extends StatelessWidget {
  const _WinRateGauge({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final wins = profile.totalWins;
    final losses = profile.totalLosses;
    final total = wins + losses;
    final winPct = total > 0 ? ((wins / total) * 100).round() : 0;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 160,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 52,
                    startDegreeOffset: -90,
                    sections: total == 0
                        ? [
                            PieChartSectionData(
                              value: 1,
                              color:
                                  scheme.onSurfaceVariant.withValues(alpha: 0.2),
                              radius: 18,
                              showTitle: false,
                            ),
                          ]
                        : [
                            PieChartSectionData(
                              value: wins.toDouble(),
                              color: _winColor,
                              radius: 18,
                              showTitle: false,
                            ),
                            PieChartSectionData(
                              value: losses.toDouble(),
                              color: _lossColor,
                              radius: 18,
                              showTitle: false,
                            ),
                          ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      total == 0 ? '—' : '%$winPct',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: scheme.primary,
                      ),
                    ),
                    Text(
                      'Galibiyet',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendDot(color: _winColor, label: 'Galibiyet ($wins)'),
              const SizedBox(width: 20),
              _LegendDot(color: _lossColor, label: 'Mağlubiyet ($losses)'),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

/// Rozet grid'i — kazanılanlar renkli, kazanılmayanlar soluk (opacity 0.3).
/// Tüm rozet kataloğu [BadgeDefinitions.all] üzerinden gösterilir.
class _BadgeGrid extends StatelessWidget {
  const _BadgeGrid({required this.earned});

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
        for (final badge in BadgeDefinitions.all)
          _BadgeTile(badge: badge, earned: earned.contains(badge.id)),
      ],
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.badge, required this.earned});

  final BadgeDefinition badge;
  final bool earned;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final tile = Container(
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
          Icon(
            badge.icon,
            size: 28,
            color: earned ? scheme.primary : scheme.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Text(
            badge.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurface,
              fontWeight: earned ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showBadgeDetail(context, badge, earned),
        // Kazanılmamış rozetler soluk gösterilir.
        child: earned ? tile : Opacity(opacity: 0.3, child: tile),
      ),
    );
  }
}

/// Bir rozete tıklanınca açılan alt sayfa: ikon + isim + açıklama.
void _showBadgeDetail(
  BuildContext context,
  BadgeDefinition badge,
  bool earned,
) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      final theme = Theme.of(context);
      final scheme = theme.colorScheme;
      final Color accent =
          earned ? scheme.primary : scheme.onSurfaceVariant;

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.outline.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: earned
                      ? scheme.primary.withValues(alpha: 0.12)
                      : scheme.onSurfaceVariant.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: earned
                        ? scheme.primary.withValues(alpha: 0.4)
                        : scheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                child: Icon(badge.icon, size: 40, color: accent),
              ),
              const SizedBox(height: 16),
              Text(
                badge.name,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                badge.description,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: earned
                      ? scheme.primary.withValues(alpha: 0.14)
                      : scheme.onSurfaceVariant.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      earned ? Icons.check_circle : Icons.lock_outline,
                      size: 16,
                      color: accent,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      earned ? 'Kazanıldı' : 'Henüz kazanılmadı',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// ELO puanını ve son maçtaki değişimi gösteren chip satırı.
class _EloChip extends StatelessWidget {
  const _EloChip({required this.profile});

  final UserProfile profile;

  static const Color _upColor = Color(0xFF2E9E5B);
  static const Color _downColor = Color(0xFFD64545);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final history = profile.eloHistory;
    final lastChange =
        history.isNotEmpty ? (history.last['change'] as num?)?.toInt() : null;

    Color? changeColor;
    String? changeText;
    if (lastChange != null && lastChange != 0) {
      changeColor = lastChange > 0 ? _upColor : _downColor;
      changeText = lastChange > 0 ? '+$lastChange ↑' : '$lastChange ↓';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bolt, size: 18, color: scheme.primary),
          const SizedBox(width: 6),
          Text(
            'ELO: ${profile.eloRating}',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: scheme.primary,
            ),
          ),
          if (changeText != null) ...[
            const SizedBox(width: 10),
            Text(
              changeText,
              style: theme.textTheme.labelMedium?.copyWith(
                color: changeColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
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

// ---------------------------------------------------------------------------
// Başarım Vitrini Widgets & Paylaşım Metotları
// ---------------------------------------------------------------------------

class _ShowcaseHeader extends StatelessWidget {
  const _ShowcaseHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(Icons.star_outline, size: 20, color: scheme.primary),
            const SizedBox(width: 8),
            Text(
              'Vitrin',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        TextButton(
          onPressed: () => context.pushNamed(RoutePaths.badgeShowcaseName),
          child: const Text('Düzenle'),
        ),
      ],
    );
  }
}

class _ShowcaseGrid extends StatelessWidget {
  const _ShowcaseGrid({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final showcase = profile.showcaseBadges;

    return Row(
      children: List.generate(3, (index) {
        final hasBadge = index < showcase.length;
        final badgeId = hasBadge ? showcase[index] : null;
        final badge = badgeId != null ? BadgeDefinitions.byId(badgeId) : null;

        return Expanded(
          child: Container(
            margin: EdgeInsets.only(
              left: index == 0 ? 0 : 6,
              right: index == 2 ? 0 : 6,
            ),
            child: AspectRatio(
              aspectRatio: 1.1,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => context.pushNamed(RoutePaths.badgeShowcaseName),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: hasBadge
                          ? scheme.primary.withValues(alpha: 0.10)
                          : scheme.surface.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: hasBadge
                            ? scheme.primary.withValues(alpha: 0.4)
                            : scheme.outline.withValues(alpha: 0.15),
                      ),
                    ),
                    child: hasBadge && badge != null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                badge.icon,
                                size: 28,
                                color: scheme.primary,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                badge.name,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: scheme.onSurface,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add,
                                size: 28,
                                color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

Future<void> _shareAchievement(
  BuildContext context,
  UserProfile user,
  GlobalKey boundaryKey,
) async {
  try {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Paylaşım kartı hazırlanıyor...'),
        duration: Duration(seconds: 1),
      ),
    );

    // Wait a brief moment to ensure layout/paint is completed if it just mounted
    await Future.delayed(const Duration(milliseconds: 100));

    await ShareService.captureAndShare(
      boundaryKey: boundaryKey,
      text: "${user.username} Competra'da ${user.totalWins} galibiyet! 🏆",
    );
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Paylaşım hatası: $e')),
      );
    }
  }
}
