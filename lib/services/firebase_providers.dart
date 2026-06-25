import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'premium_service.dart';

/// Firebase servis örnekleri ve oturum durumu için ortak Riverpod sağlayıcıları.
///
/// Tüm ekranlar Firebase'e doğrudan değil, bu sağlayıcılar üzerinden erişir;
/// böylece test ve yeniden kullanım kolaylaşır.
final firebaseAuthProvider = Provider<FirebaseAuth>(
  (ref) => FirebaseAuth.instance,
);

final firestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);

final firebaseStorageProvider = Provider<FirebaseStorage>(
  (ref) => FirebaseStorage.instance,
);

/// Oturum açma/kapama durumunu yayınlar.
final authStateProvider = StreamProvider<User?>(
  (ref) => ref.watch(firebaseAuthProvider).authStateChanges(),
);

/// O an oturum açmış kullanıcı (yoksa `null`).
final currentUserProvider = Provider<User?>(
  (ref) => ref.watch(authStateProvider).asData?.value,
);

final isPremiumProvider = FutureProvider<bool>(
  (ref) => PremiumService.isPremium(),
);
