import 'package:cloud_firestore/cloud_firestore.dart';

/// Bildirim türleri.
enum NotificationType {
  matchConfirm,
  friendRequest,
  tournamentInvite,
  generic;

  static NotificationType fromString(String? value) {
    switch (value) {
      case 'match_confirm':
        return NotificationType.matchConfirm;
      case 'friend_request':
        return NotificationType.friendRequest;
      case 'tournament_invite':
        return NotificationType.tournamentInvite;
      default:
        return NotificationType.generic;
    }
  }
}

/// Firestore'daki `notifications/{id}` belgesinin model karşılığı.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.read,
    required this.createdAt,
  });

  final String id;
  final NotificationType type;
  final String title;
  final String message;
  final bool read;
  final DateTime? createdAt;

  factory AppNotification.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return AppNotification(
      id: doc.id,
      type: NotificationType.fromString(data['type'] as String?),
      title: (data['title'] as String?) ?? '',
      message: (data['message'] as String?) ?? '',
      read: (data['read'] as bool?) ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
