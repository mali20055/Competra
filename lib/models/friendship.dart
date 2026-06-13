import 'package:cloud_firestore/cloud_firestore.dart';

/// Bir arkadaşlık içindeki tek bir kullanıcının özet (denormalize) bilgisi.
class FriendSummary {
  const FriendSummary({
    required this.uid,
    required this.username,
    required this.activeTitle,
    required this.lastActive,
  });

  final String uid;
  final String username;
  final String activeTitle;
  final DateTime? lastActive;

  factory FriendSummary.fromMap(String uid, Map<String, dynamic> map) =>
      FriendSummary(
        uid: uid,
        username: (map['username'] as String?) ?? 'Oyuncu',
        activeTitle: (map['activeTitle'] as String?) ?? '',
        lastActive: (map['lastActive'] as Timestamp?)?.toDate(),
      );

  /// Özet bilgisi bulunmayan kullanıcılar için makul varsayılan.
  factory FriendSummary.fallback(String uid) => FriendSummary(
        uid: uid,
        username: 'Oyuncu',
        activeTitle: '',
        lastActive: null,
      );
}

/// Firestore'daki `friendships/{id}` belgesinin model karşılığı.
///
/// `status` 'pending' (istek) ya da 'accepted' (arkadaş) olabilir. Karşı
/// tarafın özeti [otherSummary] ile, o anki kullanıcının uid'ine göre çözülür.
class Friendship {
  const Friendship({
    required this.id,
    required this.users,
    required this.requesterId,
    required this.recipientId,
    required this.status,
    required this.summaries,
    required this.createdAt,
  });

  final String id;
  final List<String> users;
  final String requesterId;
  final String recipientId;
  final String status;
  final Map<String, FriendSummary> summaries;
  final DateTime? createdAt;

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';

  /// [myUid] dışındaki diğer kullanıcının uid'i.
  String otherUid(String myUid) =>
      users.firstWhere((u) => u != myUid, orElse: () => '');

  /// [myUid]'e göre karşı tarafın özeti.
  FriendSummary otherSummary(String myUid) {
    final other = otherUid(myUid);
    return summaries[other] ?? FriendSummary.fallback(other);
  }

  factory Friendship.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final rawUsers = (data['users'] as List?) ?? const [];
    final rawSummaries = (data['summaries'] as Map?) ?? const {};

    final summaries = <String, FriendSummary>{};
    rawSummaries.forEach((key, value) {
      summaries['$key'] = FriendSummary.fromMap(
        '$key',
        Map<String, dynamic>.from(value as Map),
      );
    });

    return Friendship(
      id: doc.id,
      users: [for (final u in rawUsers) '$u'],
      requesterId: (data['requesterId'] as String?) ?? '',
      recipientId: (data['recipientId'] as String?) ?? '',
      status: (data['status'] as String?) ?? 'pending',
      summaries: summaries,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
