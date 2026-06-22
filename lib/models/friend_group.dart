import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore'daki `friendGroups/{id}` belgesinin model karşılığı.
///
/// Grup içi sıralama tablosu, `members` alt koleksiyonundaki
/// [FriendGroupMember] belgelerinden türetilir.
class FriendGroup {
  const FriendGroup({
    required this.id,
    required this.name,
    required this.createdBy,
    required this.memberCount,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String createdBy;
  final int memberCount;
  final DateTime? createdAt;

  factory FriendGroup.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return FriendGroup(
      id: doc.id,
      name: (data['name'] as String?) ?? 'Grup',
      createdBy: (data['createdBy'] as String?) ?? '',
      memberCount: (data['memberCount'] as num?)?.toInt() ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// `friendGroups/{id}/members/{uid}` belgesinin model karşılığı.
///
/// Bir maç tamamlandığında [SocialRepository.updateFriendGroupStats] tarafından
/// güncellenen, grup içi kümülatif istatistikleri taşır.
class FriendGroupMember {
  const FriendGroupMember({
    required this.uid,
    required this.username,
    required this.totalMatches,
    required this.totalWins,
    required this.totalLosses,
    required this.totalGoalsScored,
    required this.totalGoalsConceded,
    required this.totalPoints,
  });

  final String uid;
  final String username;
  final int totalMatches;
  final int totalWins;
  final int totalLosses;
  final int totalGoalsScored;
  final int totalGoalsConceded;
  final int totalPoints;

  factory FriendGroupMember.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    int asInt(String key) => (data[key] as num?)?.toInt() ?? 0;
    return FriendGroupMember(
      uid: (data['uid'] as String?) ?? doc.id,
      username: (data['username'] as String?) ?? 'Oyuncu',
      totalMatches: asInt('totalMatches'),
      totalWins: asInt('totalWins'),
      totalLosses: asInt('totalLosses'),
      totalGoalsScored: asInt('totalGoalsScored'),
      totalGoalsConceded: asInt('totalGoalsConceded'),
      totalPoints: asInt('totalPoints'),
    );
  }
}
