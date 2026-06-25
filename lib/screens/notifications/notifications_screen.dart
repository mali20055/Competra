import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/time_ago.dart';
import '../../models/app_notification.dart';
import '../../router/route_paths.dart';
import '../../services/firebase_providers.dart';
import '../../services/notification_repository.dart';

/// Bildirimler ekranı.
///
/// Kullanıcının en yeni [AppConstants.notificationsLimit] bildirimini canlı
/// dinler; maç onayı, arkadaşlık isteği ve turnuva daveti türlerini
/// okundu/okunmadı durumuyla gösterir. Liste sonuna gelindiğinde "Daha fazla
/// yükle" butonuyla bir önceki sayfayı [NotificationRepository.fetchNextPage]
/// ile çekip mevcut listeye ekler. Tüm renkler tema üzerinden gelir.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final List<AppNotification> _moreItems = [];
  DocumentSnapshot<Map<String, dynamic>>? _lastDoc;
  bool _hasMore = true;
  bool _loadingMore = false;

  Future<void> _loadMore(List<AppNotification> liveItems) async {
    if (_loadingMore || !_hasMore) return;
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;

    setState(() => _loadingMore = true);
    final repo = ref.read(notificationRepositoryProvider);
    try {
      var anchor = _lastDoc;
      if (anchor == null) {
        // İlk "daha fazla yükle": canlı listenin son öğesinin belgesini çöz.
        final loaded = [...liveItems, ..._moreItems];
        if (loaded.isEmpty) {
          setState(() => _loadingMore = false);
          return;
        }
        anchor = await repo.docSnapshot(loaded.last.id);
      }

      final page = await repo.fetchNextPage(uid: uid, startAfter: anchor);
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
    final notificationsAsync = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Bildirimler')),
      body: notificationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const _EmptyState(
          icon: Icons.cloud_off_outlined,
          title: 'Bildirimler yüklenemedi',
          message: 'Lütfen daha sonra tekrar dene.',
        ),
        data: (liveItems) {
          final items = [...liveItems, ..._moreItems];
          if (items.isEmpty) {
            return const _EmptyState(
              icon: Icons.notifications_none_outlined,
              title: 'Bildirim yok',
              message: 'Yeni bir şey olduğunda burada göreceksin.',
            );
          }
          // Canlı sayfa AppConstants.notificationsLimit'ten azsa zaten tüm
          // bildirimler yüklenmiştir; "daha fazla yükle" gösterilmez.
          final showLoadMore =
              _hasMore && liveItems.length >= AppConstants.notificationsLimit;
          return RefreshIndicator(
            color: Theme.of(context).colorScheme.primary,
            onRefresh: () async {
              ref.invalidate(notificationsProvider);
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length + (showLoadMore ? 1 : 0),
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                if (index >= items.length) {
                  return _LoadMoreButton(
                    loading: _loadingMore,
                    onPressed: () => _loadMore(liveItems),
                  );
                }
                return _NotificationTile(item: items[index])
                    .animate()
                    .fadeIn(delay: (index * 60).ms, duration: 320.ms)
                    .slideY(begin: 0.1, end: 0);
              },
            ),
          );
        },
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

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({required this.item});

  final AppNotification item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final meta = _metaFor(item.type);
    final time = timeAgoTr(item.createdAt);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onTap(context, ref),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            // Okunmamış bildirimler hafif vurgulu.
            color: item.read
                ? scheme.surface
                : scheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: item.read
                  ? scheme.outline.withValues(alpha: 0.2)
                  : scheme.primary.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(meta.icon, color: scheme.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title.isEmpty ? meta.title : item.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (!item.read)
                          Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              color: scheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.message.isEmpty ? meta.fallbackMessage : item.message,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurface,
                        height: 1.3,
                      ),
                    ),
                    if (time.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        time,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (item.type == NotificationType.matchConfirm &&
                        item.tournamentId != null &&
                        item.tournamentId!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _GoToTournamentButton(item: item),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onTap(BuildContext context, WidgetRef ref) async {
    if (!item.read) {
      await ref.read(notificationRepositoryProvider).markRead(item.id);
      HapticFeedback.lightImpact();
    }
    if (!context.mounted) return;
    final tournamentId = item.tournamentId;
    final hasTournament = tournamentId != null && tournamentId.isNotEmpty;
    switch (item.type) {
      case NotificationType.friendRequest:
        context.goNamed(RoutePaths.socialName);
      case NotificationType.tournamentInvite:
        context.goNamed(RoutePaths.joinTournamentName);
      case NotificationType.tournamentComplete:
        // Turnuva belliyse doğrudan kutlama/özet (wrapped) ekranına git.
        if (hasTournament) {
          context.goNamed(
            RoutePaths.tournamentWrappedName,
            pathParameters: {'id': tournamentId},
          );
        } else {
          context.goNamed(RoutePaths.leaguesName);
        }
      case NotificationType.matchConfirm:
        // Onay/itiraz işlemi turnuva detay ekranında yapılır; bildirim yalnızca
        // oraya yönlendirir.
        if (hasTournament) {
          context.goNamed(
            RoutePaths.tournamentDetailName,
            pathParameters: {'id': tournamentId},
          );
        }
      case NotificationType.generic:
        break;
    }
  }

  ({IconData icon, String title, String fallbackMessage}) _metaFor(
    NotificationType type,
  ) {
    switch (type) {
      case NotificationType.matchConfirm:
        return (
          icon: Icons.scoreboard_outlined,
          title: 'Maç Onayı',
          fallbackMessage: 'Bir maç skoru onayını bekliyor.',
        );
      case NotificationType.friendRequest:
        return (
          icon: Icons.person_add_alt,
          title: 'Arkadaşlık İsteği',
          fallbackMessage: 'Yeni bir arkadaşlık isteğin var.',
        );
      case NotificationType.tournamentInvite:
        return (
          icon: Icons.emoji_events_outlined,
          title: 'Turnuva Daveti',
          fallbackMessage: 'Bir turnuvaya davet edildin.',
        );
      case NotificationType.tournamentComplete:
        return (
          icon: Icons.emoji_events,
          title: 'Turnuva Tamamlandı',
          fallbackMessage: 'Bir turnuva tamamlandı.',
        );
      case NotificationType.generic:
        return (
          icon: Icons.notifications_outlined,
          title: 'Bildirim',
          fallbackMessage: '',
        );
    }
  }
}

/// Maç onayı bildirimleri için "Turnuvaya Git" aksiyonu.
///
/// Skor onay/itiraz işlemi artık turnuva detay ekranında yapıldığından, bildirim
/// yalnızca ilgili turnuvaya yönlendirir (yalnızca `tournamentId` mevcutsa
/// gösterilir).
class _GoToTournamentButton extends ConsumerWidget {
  const _GoToTournamentButton({required this.item});

  final AppNotification item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _goToTournament(context, ref),
        icon: const Icon(Icons.arrow_forward, size: 18),
        label: const Text('Turnuvaya Git'),
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(40),
        ),
      ),
    );
  }

  Future<void> _goToTournament(BuildContext context, WidgetRef ref) async {
    final tournamentId = item.tournamentId;
    if (tournamentId == null || tournamentId.isEmpty) return;
    if (!item.read) {
      await ref.read(notificationRepositoryProvider).markRead(item.id);
    }
    if (!context.mounted) return;
    context.goNamed(
      RoutePaths.tournamentDetailName,
      pathParameters: {'id': tournamentId},
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
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
            Icon(icon, size: 56, color: scheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
