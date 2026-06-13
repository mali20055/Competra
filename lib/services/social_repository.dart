import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  /// Arkadaşlık isteği gönderir (özet bilgileri denormalize ederek).
  Future<void> sendRequest({
    required Participant me,
    required Participant target,
  }) async {
    await _friendships.add({
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
  }

  /// Gelen isteği kabul eder.
  Future<void> acceptRequest(String friendshipId) =>
      _friendships.doc(friendshipId).update({'status': 'accepted'});

  /// Gelen isteği reddeder (belgeyi siler).
  Future<void> declineRequest(String friendshipId) =>
      _friendships.doc(friendshipId).delete();
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
