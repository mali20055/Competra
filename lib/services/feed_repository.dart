import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/feed_item.dart';
import 'firebase_providers.dart';

class FeedRepository {
  FeedRepository(this._firestore);

  final FirebaseFirestore _firestore;

  Stream<List<FeedItem>> watchFeed(String uid) {
    return _firestore
        .collection('activity_feed')
        .doc(uid)
        .collection('items')
        .orderBy('createdAt', descending: true)
        .limit(30)
        .snapshots()
        .map((s) => s.docs.map(FeedItem.fromDoc).toList());
  }
}

final feedRepositoryProvider = Provider<FeedRepository>(
  (ref) => FeedRepository(ref.watch(firestoreProvider)),
);

final activityFeedProvider = StreamProvider.autoDispose<List<FeedItem>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(const []);
  return ref.watch(feedRepositoryProvider).watchFeed(user.uid);
});
