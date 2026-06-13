import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/pitch_pattern_background.dart';
import '../../models/tournament.dart';
import '../../router/route_paths.dart';
import '../../services/tournament_repository.dart';
import '../../services/user_repository.dart';

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

    return Scaffold(
      appBar: _HomeAppBar(username: username),
      body: PitchPatternBackground(
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              const _ActionButtons()
                  .animate()
                  .fadeIn(duration: 400.ms)
                  .slideY(begin: 0.12, end: 0),
              const SizedBox(height: 28),
              tournamentsAsync
                  .when(
                    loading: () => const _LoadingCard(),
                    error: (_, __) => const _MessageCard(
                      message: 'Turnuvalar yüklenemedi.',
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
            ],
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
    final initial =
        username.isEmpty ? '?' : username.substring(0, 1).toUpperCase();

    return AppBar(
      centerTitle: false,
      titleSpacing: 20,
      title: Text(
        'Merhaba, $username 👋',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      actions: [
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
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            icon: Icons.emoji_events_outlined,
            label: 'Turnuva Oluştur',
            onPressed: () =>
                context.pushNamed(RoutePaths.createTournamentName),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _ActionButton(
            icon: Icons.link,
            label: 'Turnuvaya Katıl',
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
// Aktif turnuvalar (yatay liste)
// ---------------------------------------------------------------------------

/// "Aktif Turnuvalar" başlığı + yatay kaydırmalı kart listesi.
class _ActiveTournaments extends StatelessWidget {
  const _ActiveTournaments({required this.tournaments});

  final List<Tournament> tournaments;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Aktif Turnuvalar'),
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
                    '${tournament.participants.length} oyuncu',
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
                      tournament.isWaiting ? 'Bekleme lobisi' : 'Devam ediyor',
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.secondary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        _formatLabel(format),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Aktif Turnuvalar'),
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
                'Henüz turnuvan yok',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Arkadaşlarınla rekabete başlamak için ilk turnuvanı oluştur.',
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
                label: const Text('İlk turnuvanı oluştur'),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Aktif Turnuvalar'),
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Aktif Turnuvalar'),
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
String _formatLabel(String format) {
  switch (format) {
    case 'league':
      return 'LİG';
    case 'knockout':
      return 'ELEME';
    case 'groupKnockout':
      return 'GRUP+ELEME';
    case 'championsLeague':
      return 'ŞAMPİYONLAR';
    default:
      return 'TURNUVA';
  }
}
