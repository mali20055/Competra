import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/wheel.dart';
import 'firebase_providers.dart';

/// Çark belgeleri üzerinde okuma/yazma işlemleri.
class WheelRepository {
  WheelRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _wheels =>
      _firestore.collection('wheels');

  /// Yeni çark oluşturur ve id'sini döner.
  Future<String> createWheel({
    required String ownerId,
    required String name,
    required List<String> teams,
  }) async {
    final doc = await _wheels.add({
      'ownerId': ownerId,
      'name': name,
      'teams': teams,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Future<void> deleteWheel(String id) => _wheels.doc(id).delete();
}

final wheelRepositoryProvider = Provider<WheelRepository>(
  (ref) => WheelRepository(ref.watch(firestoreProvider)),
);

/// O an oturum açmış kullanıcının çarkları (en yeni en üstte).
final myWheelsStreamProvider = StreamProvider<List<Wheel>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(const []);
  return ref
      .watch(firestoreProvider)
      .collection('wheels')
      .where('ownerId', isEqualTo: user.uid)
      .snapshots()
      .map((snap) {
    final list = snap.docs.map(Wheel.fromDoc).toList()
      ..sort((a, b) {
        final ad = a.createdAt;
        final bd = b.createdAt;
        if (ad == null && bd == null) return 0;
        if (ad == null) return 1;
        if (bd == null) return -1;
        return bd.compareTo(ad);
      });
    return list;
  });
});
