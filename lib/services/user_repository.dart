import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_profile.dart';
import 'firebase_providers.dart';

/// O an oturum açmış kullanıcının profili.
///
/// Oturum yoksa `null`; misafir (anonim) kullanıcı için varsayılan misafir
/// profili; aksi halde `users/{uid}` belgesi canlı olarak yayınlanır.
final userProfileProvider = StreamProvider<UserProfile?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(null);
  if (user.isAnonymous) return Stream.value(UserProfile.guest(user.uid));
  return ref
      .watch(firestoreProvider)
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .map(UserProfile.fromDoc);
});
