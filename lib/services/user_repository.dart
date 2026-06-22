import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/tournament.dart';
import '../models/user_profile.dart';
import 'firebase_providers.dart';

/// `users/{uid}` profil belgesi ve profil fotoğrafı üzerinde yazma işlemleri.
class UserRepository {
  UserRepository(this._firestore, this._storage);

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  /// Profil fotoğrafını `profile_photos/{uid}.jpg` yoluna yükler ve indirilebilir
  /// URL'i döner.
  Future<String> uploadProfilePhoto({
    required String uid,
    required File file,
  }) async {
    final ref = _storage.ref('profile_photos/$uid.jpg');
    await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }

  /// Kapak fotoğrafını `cover_photos/{uid}.jpg` yoluna yükler ve indirilebilir
  /// URL'i döner.
  Future<String> uploadCoverPhoto({
    required String uid,
    required File file,
  }) async {
    final ref = _storage.ref('cover_photos/$uid.jpg');
    await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }

  /// Profil alanlarını (`bio`, `favoriteTeam` ve verildiyse `photoUrl`/`coverUrl`)
  /// günceller. Belge yoksa oluşturur (merge).
  Future<void> updateProfile({
    required String uid,
    required String bio,
    required String favoriteTeam,
    String? photoUrl,
    String? coverUrl,
  }) {
    final data = <String, dynamic>{
      'bio': bio,
      'favoriteTeam': favoriteTeam,
    };
    if (photoUrl != null) data['photoUrl'] = photoUrl;
    if (coverUrl != null) data['coverUrl'] = coverUrl;
    return _firestore
        .collection('users')
        .doc(uid)
        .set(data, SetOptions(merge: true));
  }
}

final userRepositoryProvider = Provider<UserRepository>(
  (ref) => UserRepository(
    ref.watch(firestoreProvider),
    ref.watch(firebaseStorageProvider),
  ),
);

/// Bir maçın, belirli kullanıcı açısından sonucu (galibiyet/mağlubiyet/beraberlik).
enum MatchResultKind { win, loss, draw }

/// Kullanıcı açısından tek bir maç sonucu (form grafiği için).
class RecentMatchResult {
  const RecentMatchResult({
    required this.kind,
    required this.goalsFor,
    required this.goalsAgainst,
  });

  final MatchResultKind kind;
  final int goalsFor;
  final int goalsAgainst;
}

/// O an oturum açmış kullanıcının (tüm turnuvalardaki) son 10 tamamlanmış maçı,
/// soldan sağa eskiden yeniye sıralı.
///
/// `matches` koleksiyon grubu üzerinde iki sorgu (homeUid / awayUid) çalıştırıp
/// birleştirir. Maç başına ayrı bir "oynanma zamanı" alanı bulunmadığından
/// "son" maçlar, fikstür oluşturma zamanı (`createdAt`) ve maç sırası (`order`)
/// ile yaklaşık belirlenir. Misafir/oturumsuz kullanıcıda boş döner.
///
/// NOT: Koleksiyon-grubu sorguları `matches.homeUid` ve `matches.awayUid` için
/// COLLECTION_GROUP kapsamlı tek-alan dizinleri gerektirir
/// (bkz. firestore.indexes.json).
final userRecentMatchesProvider =
    FutureProvider.autoDispose<List<RecentMatchResult>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null || user.isAnonymous) return const [];
  final firestore = ref.watch(firestoreProvider);
  final uid = user.uid;

  final snaps = await Future.wait([
    firestore.collectionGroup('matches').where('homeUid', isEqualTo: uid).get(),
    firestore.collectionGroup('matches').where('awayUid', isEqualTo: uid).get(),
  ]);

  final seen = <String>{};
  final rows =
      <({Timestamp? createdAt, int order, RecentMatchResult result})>[];
  for (final snap in snaps) {
    for (final doc in snap.docs) {
      if (!seen.add(doc.reference.path)) continue;
      final m = TournamentMatch.fromDoc(doc);
      if (!m.isPlayed || m.isBye) continue;
      final isHome = m.homeUid == uid;
      final gf = isHome ? m.homeScore! : m.awayScore!;
      final ga = isHome ? m.awayScore! : m.homeScore!;
      final kind = gf > ga
          ? MatchResultKind.win
          : (gf < ga ? MatchResultKind.loss : MatchResultKind.draw);
      rows.add((
        createdAt: doc.data()['createdAt'] as Timestamp?,
        order: m.order,
        result:
            RecentMatchResult(kind: kind, goalsFor: gf, goalsAgainst: ga),
      ));
    }
  }

  // En son oynananlar üstte: createdAt (yoksa sona) → order, azalan.
  rows.sort((a, b) {
    final ac = a.createdAt;
    final bc = b.createdAt;
    final byTime = (ac == null && bc == null)
        ? 0
        : (ac == null ? 1 : (bc == null ? -1 : bc.compareTo(ac)));
    if (byTime != 0) return byTime;
    return b.order.compareTo(a.order);
  });

  final recent = rows.take(10).map((e) => e.result).toList();
  // Grafikte soldan sağa eskiden yeniye okunsun diye ters çevir.
  return recent.reversed.toList();
});

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
