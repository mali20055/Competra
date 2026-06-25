import 'package:cloud_firestore/cloud_firestore.dart';

class FeedItem {
  const FeedItem({
    required this.id,
    required this.type,
    required this.actorUid,
    required this.actorName,
    this.actorPhotoUrl,
    required this.message,
    this.tournamentId,
    this.badgeId,
    this.createdAt,
    required this.read,
  });

  final String id;
  final String type; // 'tournament_won' | 'badge_earned' | 'elo_milestone'
  final String actorUid;
  final String actorName;
  final String? actorPhotoUrl;
  final String message;
  final String? tournamentId;
  final String? badgeId;
  final DateTime? createdAt;
  final bool read;

  factory FeedItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return FeedItem(
      id: doc.id,
      type: (data['type'] as String?) ?? '',
      actorUid: (data['actorUid'] as String?) ?? '',
      actorName: (data['actorName'] as String?) ?? '',
      actorPhotoUrl: data['actorPhotoUrl'] as String?,
      message: (data['message'] as String?) ?? '',
      tournamentId: data['tournamentId'] as String?,
      badgeId: data['badgeId'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      read: (data['read'] as bool?) ?? false,
    );
  }
}
