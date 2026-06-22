import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/sort_utils.dart';
import '../models/friend_group.dart';
import '../models/friendship.dart';
import '../models/tournament.dart' show Participant;
import 'firebase_providers.dart';

/// Arkadaşlık (istek + arkadaş) işlemleri ve kullanıcı araması.
class SocialRepository {
  SocialRepository(this._firestore);

  final FirebaseFirestore _firestore;

  // Firestore ön ek (prefix) sorgusu için yüksek Unicode sınırı.
  static final String _highBound = String.fromCharCode(0xF8FF);

  CollectionReference<Map<String, dynamic>> get _friendships =>
      _firestore.collection('friendships');

  /// Kullanıcı adına göre ön ek (prefix) araması yapar (kendisi hariç).
  Future<List<Participant>> searchUsers({
    required String query,
    required String excludeUid,
  }) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];

    final snap = await _firestore
        .collection('users')
        .where('usernameLower', isGreaterThanOrEqualTo: q)
        .where('usernameLower', isLessThan: q + _highBound)
        .limit(20)
        .get();

    return snap.docs
        .where((d) => d.id != excludeUid)
        .map((d) => Participant(
              uid: d.id,
              username: (d.data()['username'] as String?) ?? 'Oyuncu',
            ))
        .toList();
  }

  /// Arkadaşlık isteği gönderir (özet bilgileri denormalize ederek) ve hedef
  /// kullanıcıya bir bildirim yazar. İlişki + bildirim tek batch'te işlenir.
  Future<void> sendRequest({
    required Participant me,
    required Participant target,
  }) async {
    final batch = _firestore.batch();

    final friendshipRef = _friendships.doc();
    batch.set(friendshipRef, {
      'users': [me.uid, target.uid],
      'requesterId': me.uid,
      'recipientId': target.uid,
      'status': 'pending',
      'summaries': {
        me.uid: {'username': me.username},
        target.uid: {'username': target.username},
      },
      'createdAt': FieldValue.serverTimestamp(),
    });

    final notifRef = _firestore.collection('notifications').doc();
    batch.set(notifRef, {
      'userId': target.uid,
      'type': 'friendRequest',
      'title': 'Arkadaşlık İsteği',
      'message': '${me.username} sana arkadaşlık isteği gönderdi',
      'senderId': me.uid,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// Gelen isteği kabul eder.
  Future<void> acceptRequest(String friendshipId) async {
    try {
      await _friendships.doc(friendshipId).update({'status': 'accepted'});
    } catch (e) {
      debugPrint('Arkadaşlık isteği kabul edilemedi ($friendshipId): $e');
      rethrow;
    }
  }

  /// Gelen isteği reddeder (belgeyi siler).
  Future<void> declineRequest(String friendshipId) async {
    try {
      await _friendships.doc(friendshipId).delete();
    } catch (e) {
      debugPrint('Arkadaşlık isteği reddedilemedi ($friendshipId): $e');
      rethrow;
    }
  }

  /// Yeni bir arkadaş grubu oluşturur ve oluşturanı ilk üye yapar.
  ///
  /// Önce grup belgesi yazılır, ardından üye belgesi eklenir: güvenlik
  /// kuralları üye yazımında grup belgesinin `createdBy` alanını okuduğundan,
  /// grup belgesinin önceden var olması gerekir (tek batch'te get() henüz
  /// yazılmamış belgeyi göremezdi). Oluşturulan grubun id'sini döner.
  Future<String> createFriendGroup({
    required Participant owner,
    required String name,
  }) async {
    final groups = _firestore.collection('friendGroups');
    final groupRef = groups.doc();

    await groupRef.set({
      'name': name,
      'createdBy': owner.uid,
      'memberCount': 1,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await groupRef.collection('members').doc(owner.uid).set({
      'uid': owner.uid,
      'username': owner.username,
      'totalMatches': 0,
      'totalWins': 0,
      'totalLosses': 0,
      'totalGoalsScored': 0,
      'totalGoalsConceded': 0,
      'totalPoints': 0,
      'joinedAt': FieldValue.serverTimestamp(),
    });

    return groupRef.id;
  }

  /// Bir arkadaşı gruba üye olarak ekler ve grup üye sayısını artırır.
  ///
  /// Yalnızca grup sahibi çağırmalıdır (güvenlik kuralları da bunu zorlar).
  /// Zaten üye olan kişi tekrar eklenmez (idempotent).
  Future<void> addMemberToGroup({
    required String groupId,
    required Participant member,
  }) async {
    final groupRef = _firestore.collection('friendGroups').doc(groupId);
    final memberRef = groupRef.collection('members').doc(member.uid);

    final existing = await memberRef.get();
    if (existing.exists) return;

    final batch = _firestore.batch();
    batch.set(memberRef, {
      'uid': member.uid,
      'username': member.username,
      'totalMatches': 0,
      'totalWins': 0,
      'totalLosses': 0,
      'totalGoalsScored': 0,
      'totalGoalsConceded': 0,
      'totalPoints': 0,
      'joinedAt': FieldValue.serverTimestamp(),
    });
    batch.update(groupRef, {'memberCount': FieldValue.increment(1)});
    await batch.commit();
  }

}

final socialRepositoryProvider = Provider<SocialRepository>(
  (ref) => SocialRepository(ref.watch(firestoreProvider)),
);

/// O an oturum açmış kullanıcıya gelen, bekleyen arkadaşlık istekleri.
final incomingRequestsProvider = StreamProvider<List<Friendship>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(const []);
  return ref
      .watch(firestoreProvider)
      .collection('friendships')
      .where('recipientId', isEqualTo: user.uid)
      .snapshots()
      .map((snap) => snap.docs
          .map(Friendship.fromDoc)
          .where((f) => f.isPending)
          .toList());
});

/// O an oturum açmış kullanıcının arkadaşları (kabul edilmiş ilişkiler).
final friendsProvider = StreamProvider<List<Friendship>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(const []);
  return ref
      .watch(firestoreProvider)
      .collection('friendships')
      .where('users', arrayContains: user.uid)
      .snapshots()
      .map((snap) => snap.docs
          .map(Friendship.fromDoc)
          .where((f) => f.isAccepted)
          .toList());
});

/// O an oturum açmış kullanıcının üye olduğu arkadaş grupları.
///
/// Üyelik, `members` alt koleksiyonundaki `uid` alanına göre collectionGroup
/// sorgusuyla bulunur; her üyelik belgesinin üst (grup) belgesi okunarak grup
/// bilgisi (ad, üye sayısı) elde edilir.
final myFriendGroupsProvider = StreamProvider<List<FriendGroup>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(const []);
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collectionGroup('members')
      .where('uid', isEqualTo: user.uid)
      .snapshots()
      .asyncMap((snap) async {
    final groups = <FriendGroup>[];
    for (final doc in snap.docs) {
      final groupRef = doc.reference.parent.parent;
      if (groupRef == null) continue;
      final groupSnap = await groupRef.get();
      if (groupSnap.exists) groups.add(FriendGroup.fromDoc(groupSnap));
    }
    groups.sort((a, b) => compareByCreatedAtDesc(a.createdAt, b.createdAt));
    return groups;
  });
});

/// Tek bir arkadaş grubunun canlı verisi (ad, sahip, üye sayısı).
final friendGroupProvider =
    StreamProvider.family<FriendGroup?, String>((ref, groupId) {
  return ref
      .watch(firestoreProvider)
      .collection('friendGroups')
      .doc(groupId)
      .snapshots()
      .map((doc) => doc.exists ? FriendGroup.fromDoc(doc) : null);
});

/// Belirli bir arkadaş grubunun üyeleri (grup içi sıralama tablosu için).
final friendGroupMembersProvider =
    StreamProvider.family<List<FriendGroupMember>, String>((ref, groupId) {
  return ref
      .watch(firestoreProvider)
      .collection('friendGroups')
      .doc(groupId)
      .collection('members')
      .snapshots()
      .map((snap) => snap.docs.map(FriendGroupMember.fromDoc).toList());
});
