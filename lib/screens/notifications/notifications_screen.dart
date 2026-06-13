import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/time_ago.dart';
import '../../models/app_notification.dart';
import '../../router/route_paths.dart';
import '../../services/notification_repository.dart';

/// Bildirimler ekranı.
///
/// Kullanıcının `notifications` belgelerini canlı dinler; maç onayı, arkadaşlık
/// isteği ve turnuva daveti türlerini okundu/okunmadı durumuyla gösterir.
/// Tüm renkler tema üzerinden gelir.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        data: (items) {
          if (items.isEmpty) {
            return const _EmptyState(
              icon: Icons.notifications_none_outlined,
              title: 'Bildirim yok',
              message: 'Yeni bir şey olduğunda burada göreceksin.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) => _NotificationTile(item: items[index])
                .animate()
                .fadeIn(delay: (index * 60).ms, duration: 320.ms)
                .slideY(begin: 0.1, end: 0),
          );
        },
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
                    if (item.type == NotificationType.matchConfirm) ...[
                      const SizedBox(height: 12),
                      _MatchConfirmActions(item: item),
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
    }
    if (!context.mounted) return;
    switch (item.type) {
      case NotificationType.friendRequest:
        context.goNamed(RoutePaths.socialName);
      case NotificationType.tournamentInvite:
        context.goNamed(RoutePaths.joinTournamentName);
      case NotificationType.matchConfirm:
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
      case NotificationType.generic:
        return (
          icon: Icons.notifications_outlined,
          title: 'Bildirim',
          fallbackMessage: '',
        );
    }
  }
}

/// Maç onayı bildirimleri için Onayla / Reddet aksiyonları.
///
/// Şimdilik her iki işlem de bildirimi okundu olarak işaretler; gerçek maç
/// onay/itiraz akışı skor giriş sistemiyle birlikte eklenecektir.
class _MatchConfirmActions extends ConsumerWidget {
  const _MatchConfirmActions({required this.item});

  final AppNotification item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _resolve(ref, 'Skor onaylandı.'),
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Onayla'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(40),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _resolve(ref, 'Skor reddedildi.'),
            icon: const Icon(Icons.close, size: 18),
            label: const Text('Reddet'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(40),
              foregroundColor: scheme.error,
              side: BorderSide(color: scheme.error.withValues(alpha: 0.5)),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _resolve(WidgetRef ref, String message) async {
    await ref.read(notificationRepositoryProvider).markRead(item.id);
    final context = ref.context;
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
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
