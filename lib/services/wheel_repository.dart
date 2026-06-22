import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/sort_utils.dart';
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

  Future<void> deleteWheel(String id) async {
    try {
      await _wheels.doc(id).delete();
    } catch (e) {
      debugPrint('Çark silinemedi ($id): $e');
      rethrow;
    }
  }

  /// Yeni bir çevirme sonucunu kaydeder: sonucu listenin başına ekler ve en
  /// fazla 10 kayıt tutar (eskiler düşer).
  Future<void> recordResult({
    required String wheelId,
    required String result,
    required List<String> previous,
  }) async {
    final updated = [result, ...previous];
    final capped = updated.length > 10 ? updated.sublist(0, 10) : updated;
    try {
      await _wheels.doc(wheelId).update({'lastResults': capped});
    } catch (e) {
      debugPrint('Çark sonucu kaydedilemedi ($wheelId): $e');
    }
  }
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
      ..sort((a, b) => compareByCreatedAtDesc(a.createdAt, b.createdAt));
    return list;
  });
});
