import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../models/app_notification.dart';
import 'firebase_providers.dart';

/// Bir bildirim sayfası: öğeler + sonraki sayfa için `startAfterDocument`
/// anahtarı + daha fazla sayfa olup olmadığı.
class NotificationsPage {
  const NotificationsPage({
    required this.items,
    required this.lastDoc,
    required this.hasMore,
  });

  final List<AppNotification> items;
  final DocumentSnapshot<Map<String, dynamic>>? lastDoc;
  final bool hasMore;
}

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

  /// Tek bir bildirim belgesinin canlı olmayan anlık görüntüsü.
  ///
  /// "Daha fazla yükle" akışında, canlı ([notificationsProvider]) ilk sayfanın
  /// son öğesi için `startAfterDocument` anahtarı gereklidir; ama stream yalnızca
  /// modelleri yayınladığından (ham [DocumentSnapshot] değil), bu anahtar id ile
  /// tek seferlik bir okuma ile çözülür.
  Future<DocumentSnapshot<Map<String, dynamic>>> docSnapshot(String id) {
    return _notifications.doc(id).get();
  }

  /// `startAfter`'dan sonraki sonraki bildirim sayfasını çeker.
  Future<NotificationsPage> fetchNextPage({
    required String uid,
    required DocumentSnapshot<Map<String, dynamic>> startAfter,
    int limit = AppConstants.notificationsLimit,
  }) async {
    final snap = await _notifications
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .startAfterDocument(startAfter)
        .limit(limit)
        .get();
    return NotificationsPage(
      items: snap.docs.map(AppNotification.fromDoc).toList(),
      lastDoc: snap.docs.isEmpty ? null : snap.docs.last,
      hasMore: snap.docs.length == limit,
    );
  }
}

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepository(ref.watch(firestoreProvider)),
);

/// O an oturum açmış kullanıcının en yeni [AppConstants.notificationsLimit]
/// bildirimi (en yeni en üstte). Daha eskiler "Daha fazla yükle" ile
/// [NotificationRepository.fetchNextPage] üzerinden ayrıca çekilir.
final notificationsProvider = StreamProvider<List<AppNotification>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(const []);
  return ref
      .watch(firestoreProvider)
      .collection('notifications')
      .where('userId', isEqualTo: user.uid)
      .orderBy('createdAt', descending: true)
      .limit(AppConstants.notificationsLimit)
      .snapshots()
      .map((snap) => snap.docs.map(AppNotification.fromDoc).toList());
});
