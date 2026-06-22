import 'package:cloud_firestore/cloud_firestore.dart';

/// Bildirim türleri.
enum NotificationType {
  matchConfirm,
  friendRequest,
  tournamentInvite,
  tournamentComplete,
  generic;

  // Hem snake_case (eski) hem camelCase (yeni) tip adları desteklenir.
  static NotificationType fromString(String? value) {
    switch (value) {
      case 'match_confirm':
      case 'matchConfirm':
        return NotificationType.matchConfirm;
      case 'friend_request':
      case 'friendRequest':
        return NotificationType.friendRequest;
      case 'tournament_invite':
      case 'tournamentInvite':
        return NotificationType.tournamentInvite;
      case 'tournament_complete':
      case 'tournamentComplete':
        return NotificationType.tournamentComplete;
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
    this.tournamentId,
    this.matchId,
    this.senderId,
  });

  final String id;
  final NotificationType type;
  final String title;
  final String message;
  final bool read;
  final DateTime? createdAt;

  /// İlgili turnuva (varsa) — maç onayı / turnuva tamamlandı bildirimleri için
  /// yönlendirmede kullanılır.
  final String? tournamentId;

  /// İlgili maç (varsa) — maç onayı bildirimleri için.
  final String? matchId;

  /// Bildirimi tetikleyen kullanıcı (varsa) — ör. arkadaşlık isteği gönderen.
  final String? senderId;

  factory AppNotification.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return AppNotification(
      id: doc.id,
      type: NotificationType.fromString(data['type'] as String?),
      title: (data['title'] as String?) ?? '',
      message: (data['message'] as String?) ?? '',
      read: (data['read'] as bool?) ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      tournamentId: data['tournamentId'] as String?,
      matchId: data['matchId'] as String?,
      senderId: data['senderId'] as String?,
    );
  }
}
