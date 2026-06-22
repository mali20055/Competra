import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/format_labels.dart';
import '../../models/tournament.dart';
import '../../router/route_paths.dart';
import '../../services/tournament_repository.dart';

/// Turnuva durumuna göre liste filtresi.
enum _TournamentFilter {
  active('Aktif'),
  completed('Tamamlanan'),
  all('Tümü');

  const _TournamentFilter(this.label);
  final String label;

  bool matches(Tournament t) => switch (this) {
        _TournamentFilter.active => !t.isCompleted,
        _TournamentFilter.completed => t.isCompleted,
        _TournamentFilter.all => true,
      };
}

/// "Turnuvalarım" sekmesi.
///
/// Kullanıcının katıldığı turnuvaları Firestore'dan canlı ([StreamProvider])
/// dinler ve duruma göre filtreler. Tüm renkler tema üzerinden gelir.
class LeaguesScreen extends ConsumerStatefulWidget {
  const LeaguesScreen({super.key});

  @override
  ConsumerState<LeaguesScreen> createState() => _LeaguesScreenState();
}

class _LeaguesScreenState extends ConsumerState<LeaguesScreen> {
  _TournamentFilter _filter = _TournamentFilter.active;

  @override
  Widget build(BuildContext context) {
    final tournamentsAsync = ref.watch(myTournamentsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Turnuvalarım'),
        actions: [
          IconButton(
            icon: const Icon(Icons.vpn_key_outlined),
            tooltip: 'Turnuvaya Katıl',
            onPressed: () => context.pushNamed(RoutePaths.joinTournamentName),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Turnuva Oluştur',
            onPressed: () => context.pushNamed(RoutePaths.createTournamentName),
          ),
        ],
      ),
      body: Column(
        children: [
          _FilterBar(
            selected: _filter,
            onSelected: (f) => setState(() => _filter = f),
          ),
          Expanded(
            child: tournamentsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const _EmptyState(
                icon: Icons.cloud_off_outlined,
                message: 'Turnuvalar yüklenemedi.',
              ),
              data: (tournaments) {
                final filtered =
                    tournaments.where(_filter.matches).toList();
                if (filtered.isEmpty) {
                  return _EmptyTournaments(filter: _filter);
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final t = filtered[index];
                    return _TournamentCard(
                      tournament: t,
                      onTap: () => context.pushNamed(
                        RoutePaths.tournamentDetailName,
                        pathParameters: {'id': t.id},
                      ),
                    )
                        .animate()
                        .fadeIn(
                          delay: (index * 70).ms,
                          duration: 400.ms,
                        )
                        .slideY(begin: 0.15, end: 0);
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

/// Üstteki Aktif / Tamamlanan / Tümü filtre çubuğu.
class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.selected, required this.onSelected});

  final _TournamentFilter selected;
  final ValueChanged<_TournamentFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: scheme.outline.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        children: [
          for (final f in _TournamentFilter.values) ...[
            _FilterChip(
              label: f.label,
              selected: f == selected,
              onTap: () => onSelected(f),
            ),
            if (f != _TournamentFilter.values.last) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
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
        child: Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Tek bir turnuva kartı: ad, format rozeti, katılımcı sayısı, durum.
class _TournamentCard extends StatelessWidget {
  const _TournamentCard({required this.tournament, required this.onTap});

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
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.outline.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.emoji_events_outlined,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tournament.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _Badge(
                          label: tournamentFormatLabel(tournament.format).toUpperCase(),
                          color: scheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.group_outlined,
                          size: 14,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${tournament.participants.length}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const Spacer(),
                        _StatusBadge(completed: tournament.isCompleted),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.completed});

  final bool completed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final Color color = completed ? scheme.onSurfaceVariant : scheme.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          completed ? 'Tamamlandı' : 'Aktif',
          style: theme.textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Filtreye uygun turnuva olmadığında gösterilen boş durum.
class _EmptyTournaments extends StatelessWidget {
  const _EmptyTournaments({required this.filter});

  final _TournamentFilter filter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bool isActiveFilter = filter == _TournamentFilter.active ||
        filter == _TournamentFilter.all;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.emoji_events_outlined,
              size: 56,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              filter == _TournamentFilter.completed
                  ? 'Tamamlanan turnuvan yok'
                  : 'Henüz turnuvan yok',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Yeni bir turnuva oluştur ya da bir davet koduyla katıl.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            if (isActiveFilter) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () =>
                    context.pushNamed(RoutePaths.createTournamentName),
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Turnuva Oluştur'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Yükleme/hata gibi durumlar için ortak boş gösterim.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});

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

/// Turnuva formatı kod adını Türkçe etikete çevirir.
