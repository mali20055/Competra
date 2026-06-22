import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_notification.dart';
import 'firebase_providers.dart';

/// Bildirim belgeleri üzerinde işlemler.
class NotificationRepository {
  NotificationRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _notifications =>
      _firestore.collection('notifications');

  /// Bildirimi okundu olarak işaretler. Kritik olmayan bir işlem olduğundan
  /// hata durumunda kullanıcıya gösterilmez; yalnızca sessizce loglanır.
  Future<void> markRead(String id) async {
    try {
      await _notifications.doc(id).update({'read': true});
    } catch (e) {
      debugPrint('Bildirim okundu olarak işaretlenemedi ($id): $e');
    }
  }
}

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepository(ref.watch(firestoreProvider)),
);

/// O an oturum açmış kullanıcının bildirimleri (en yeni en üstte).
final notificationsProvider = StreamProvider<List<AppNotification>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(const []);
  return ref
      .watch(firestoreProvider)
      .collection('notifications')
      .where('userId', isEqualTo: user.uid)
      .snapshots()
      .map((snap) {
    final list = snap.docs.map(AppNotification.fromDoc).toList()
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
