import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/season.dart';
import 'firebase_providers.dart';

final activeSeasonProvider = FutureProvider<Season?>(
  (ref) async {
    final snap = await ref.read(firestoreProvider)
        .collection('seasons')
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return Season.fromDoc(snap.docs.first);
  },
);
