import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/sort_utils.dart';
import '../models/tournament.dart';
import 'fixture_generator.dart';
import 'firebase_providers.dart';

/// Verilen davet koduyla turnuva bulunamadığında fırlatılır.
class TournamentNotFoundException implements Exception {
  const TournamentNotFoundException();
}

/// Turnuva katılıma kapalı olduğunda (zaten başlamış / tamamlanmış) fırlatılır.
class TournamentJoinClosedException implements Exception {
  const TournamentJoinClosedException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Turnuva belgeleri üzerinde okuma/yazma işlemleri.
///
/// NOT: Maç tamamlandıktan sonraki tüm sunucu mantığı (oyuncu/katılımcı
/// istatistikleri, hat-trick rozeti, şampiyon belirleme, tur ilerletme, arkadaş
/// grubu istatistikleri, rozet/unvan türetimi) artık Cloud Functions tarafında
/// (`functions/src/index.ts`, `onMatchWritten`) yapılır. İstemci yalnızca maç
/// skorunu yazar; bu hem hile yüzeyini kapatır hem de Mod B/C'de admin olmayan
/// oyuncu son skoru girdiğinde sonraki turun oluşturulamaması sorununu çözer
/// (maçları artık admin SDK üretir, güvenlik kuralları engellemez).
class TournamentRepository {
  TournamentRepository(this._firestore, this._auth);

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  // Karışabilen karakterler (0/O, 1/I) hariç tutulur.
  static const String _codeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  CollectionReference<Map<String, dynamic>> get _tournaments =>
      _firestore.collection('tournaments');

  /// 6 haneli, benzersiz bir davet kodu üretir.
  Future<String> _generateInviteCode() async {
    final rnd = Random.secure();
    for (var attempt = 0; attempt < 5; attempt++) {
      final code = List.generate(
        6,
        (_) => _codeAlphabet[rnd.nextInt(_codeAlphabet.length)],
      ).join();
      final existing = await _tournaments
          .where('inviteCode', isEqualTo: code)
          .limit(1)
          .get();
      if (existing.docs.isEmpty) return code;
    }
    // Çok düşük olasılıkla çakışma sürerse zaman damgalı kod döner.
    return DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase();
  }

  /// Yeni turnuva oluşturur; oluşturanı ilk katılımcı yapar. Turnuva, admin
  /// başlatana kadar 'waiting' (bekleme lobisi) durumunda başlar.
  /// Oluşturulan turnuvanın id'sini döner.
  Future<String> createTournament({
    required String name,
    required String note,
    required String format,
    required String scoreMode,
    TiebreakerMode tiebreakerMode = TiebreakerMode.uefa,
  }) async {
    final user = _auth.currentUser;
    final uid = user?.uid ?? '';
    final username = await _usernameFor(user);
    final inviteCode = await _generateInviteCode();

    final doc = await _tournaments.add({
      'name': name,
      'note': note,
      'format': format,
      'scoreMode': scoreMode,
      'tiebreakerMode': tiebreakerMode.value,
      'inviteCode': inviteCode,
      'ownerId': uid,
      'participantIds': [uid],
      'participants': [
        {'uid': uid, 'username': username},
      ],
      'status': 'waiting',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  /// Davet koduyla turnuvaya katılır ve turnuva id'sini döner.
  ///
  /// Kod bulunamazsa [TournamentNotFoundException] fırlatır. Kullanıcı zaten
  /// katılımcıysa tekrar eklenmez (idempotent).
  Future<String> joinByInviteCode(String code) async {
    final normalized = code.trim().toUpperCase();
    final query = await _tournaments
        .where('inviteCode', isEqualTo: normalized)
        .limit(1)
        .get();
    if (query.docs.isEmpty) {
      throw const TournamentNotFoundException();
    }

    final doc = query.docs.first;

    // Turnuva yalnızca 'waiting' (lobi) durumundayken yeni katılıma açıktır.
    final status = (doc.data()['status'] as String?) ?? 'active';
    if (status != 'waiting') {
      switch (status) {
        case 'active':
          throw const TournamentJoinClosedException(
            'Turnuva zaten başlamış, katılamazsın',
          );
        case 'completed':
          throw const TournamentJoinClosedException('Turnuva tamamlanmış');
        default:
          throw const TournamentJoinClosedException(
            'Turnuvaya katılım kapalı',
          );
      }
    }

    final user = _auth.currentUser;
    if (user != null) {
      final participantIds =
          (doc.data()['participantIds'] as List?) ?? const [];
      if (!participantIds.contains(user.uid)) {
        final username = await _usernameFor(user);
        await doc.reference.update({
          'participantIds': FieldValue.arrayUnion([user.uid]),
          'participants': FieldValue.arrayUnion([
            {'uid': user.uid, 'username': username},
          ]),
        });
      }
    }
    return doc.id;
  }

  /// Turnuvayı başlatır: formata göre fikstürü üretip `matches` alt
  /// koleksiyonuna tek batch'te yazar ve turnuva durumunu 'active' yapar.
  ///
  /// Üretilen maç sayısı Firestore'un 500 işlemlik batch sınırını aşarsa
  /// (çok büyük turnuvalar) bu metot yetersiz kalır; tipik arkadaş turnuvaları
  /// için fazlasıyla yeterlidir.
  Future<void> startTournament({
    required String tournamentId,
    required String format,
    required List<Participant> participants,
  }) async {
    final matches = generateFixtures(format, participants);
    final matchesCol = _tournaments.doc(tournamentId).collection('matches');
    final batch = _firestore.batch();

    for (final match in matches) {
      batch.set(matchesCol.doc(), {
        ...match.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    batch.update(_tournaments.doc(tournamentId), {
      'status': 'active',
      'startedAt': FieldValue.serverTimestamp(),
      // Çok aşamalı formatlarda başlangıç fazı; eleme tur ilerletme için tur 1.
      'currentPhase': _initialPhaseFor(format),
      'currentRound': 1,
    });

    await batch.commit();
  }

  /// Formata göre turnuvanın başlangıç fazı.
  /// Grup+eleme → 'group', diğer hepsi (lig, eleme, ŞL lig fazı) → ilk fazları.
  static String _initialPhaseFor(String format) {
    switch (format) {
      case 'knockout':
        return 'knockout';
      case 'groupKnockout':
      case 'groupElimination':
        return 'group';
      case 'championsLeague':
      case 'league':
      default:
        return 'league';
    }
  }

  /// Bir maçın skorunu yazar ve maçı 'completed' yapar.
  ///
  /// İstemci YALNIZCA skoru ve durumu yazar. İstatistik işleme (turnuva
  /// katılımcı + kullanıcı istatistikleri, hat-trick rozeti), şampiyon belirleme,
  /// tur ilerletme ve arkadaş grubu istatistikleri Cloud Functions tarafından
  /// (`onMatchWritten` tetikleyicisi) sunucuda yapılır. Bu sayede aynı maç
  /// tekrar kaydedilse bile (skor düzeltme) istatistikler çift sayılmaz: sunucu
  /// maça `statsApplied` damgası vurarak idempotentliği garanti eder.
  Future<void> updateMatchScore({
    required String tournamentId,
    required String matchId,
    required int homeScore,
    required int awayScore,
  }) async {
    final matchRef =
        _tournaments.doc(tournamentId).collection('matches').doc(matchId);
    await matchRef.update({
      'homeScore': homeScore,
      'awayScore': awayScore,
      'played': true,
      'status': 'completed',
    });
  }

  /// winnerEntry/doubleEntry modunda bir oyuncunun skor girişini kaydeder;
  /// maç, karşı tarafın onayını (winnerEntry) veya ikinci girişini (doubleEntry)
  /// beklemek üzere 'awaitingConfirmation' durumuna alınır.
  ///
  /// Skor henüz kesinleşmediği için `homeScore`/`awayScore` yazılmaz; yalnızca
  /// `enteredHomeScore`/`enteredAwayScore` saklanır.
  Future<void> submitScoreForConfirmation({
    required String tournamentId,
    required String matchId,
    required String enteredBy,
    required int homeScore,
    required int awayScore,
  }) async {
    final matchRef =
        _tournaments.doc(tournamentId).collection('matches').doc(matchId);

    // Karşı oyuncuyu ve skoru gireni belirlemek için maçı çek.
    final matchSnap = await matchRef.get();
    final matchData = matchSnap.data() ?? const <String, dynamic>{};
    final homeUid = (matchData['homeUid'] as String?) ?? '';
    final awayUid = (matchData['awayUid'] as String?) ?? '';
    final homeName = (matchData['homeName'] as String?) ?? 'Oyuncu';
    final awayName = (matchData['awayName'] as String?) ?? 'Oyuncu';

    // Skoru giren = enteredBy; bildirim karşı oyuncuya gider.
    final enteredByName = enteredBy == homeUid ? homeName : awayName;
    final opponentUid = enteredBy == homeUid ? awayUid : homeUid;

    final batch = _firestore.batch();
    batch.update(matchRef, {
      'status': 'awaitingConfirmation',
      'enteredBy': enteredBy,
      'enteredHomeScore': homeScore,
      'enteredAwayScore': awayScore,
    });

    if (opponentUid.isNotEmpty) {
      final notifRef = _firestore.collection('notifications').doc();
      batch.set(notifRef, {
        'userId': opponentUid,
        'type': 'matchConfirm',
        'title': 'Skor Onayı Bekleniyor',
        'message':
            '$enteredByName skoru girdi: $homeScore-$awayScore. Onayla veya itiraz et!',
        'tournamentId': tournamentId,
        'matchId': matchId,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  /// Bir maçı anlaşmazlık ('disputed') durumuna alır ve turnuva yöneticisine
  /// `notifications` koleksiyonuna bir bildirim yazar. İşlem tek batch'tedir.
  ///
  /// [extra] alanları (ör. doubleEntry'de ikinci giriş) maç belgesine eklenir.
  Future<void> markDisputed({
    required String tournamentId,
    required String matchId,
    required String adminUid,
    required String title,
    required String message,
    Map<String, dynamic> extra = const {},
  }) async {
    final batch = _firestore.batch();
    final matchRef =
        _tournaments.doc(tournamentId).collection('matches').doc(matchId);
    batch.update(matchRef, {
      'status': 'disputed',
      ...extra,
    });

    // Yöneticiye bildirim — ancak anlaşmazlığı açan kişi yöneticinin kendisiyse
    // (admin de oyuncuysa) kurallar kendine bildirimi engellediğinden atlanır.
    if (adminUid.isNotEmpty && adminUid != _auth.currentUser?.uid) {
      final notifRef = _firestore.collection('notifications').doc();
      batch.set(notifRef, {
        'userId': adminUid,
        'type': 'matchConfirm',
        'title': title,
        'message': message,
        'read': false,
        'tournamentId': tournamentId,
        'matchId': matchId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  /// Kullanıcının görünen adını Firestore'dan (yoksa makul varsayılan) çözer.
  Future<String> _usernameFor(User? user) async {
    if (user == null) return 'Oyuncu';
    final snap = await _firestore.collection('users').doc(user.uid).get();
    final username = snap.data()?['username'] as String?;
    if (username != null && username.isNotEmpty) return username;
    return user.isAnonymous ? 'Misafir' : 'Oyuncu';
  }
}

final tournamentRepositoryProvider = Provider<TournamentRepository>(
  (ref) => TournamentRepository(
    ref.watch(firestoreProvider),
    ref.watch(firebaseAuthProvider),
  ),
);

/// O an oturum açmış kullanıcının katıldığı turnuvalar (en yeni en üstte).
///
/// `participantIds arrayContains` ile sorgulanır; sıralama, bileşik dizin
/// gerektirmemek için istemci tarafında yapılır.
final myTournamentsStreamProvider =
    StreamProvider<List<Tournament>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(const []);
  return ref
      .watch(firestoreProvider)
      .collection('tournaments')
      .where('participantIds', arrayContains: user.uid)
      .snapshots()
      .map((snap) {
    final list = snap.docs.map(Tournament.fromDoc).toList()
      ..sort((a, b) => compareByCreatedAtDesc(a.createdAt, b.createdAt));
    return list;
  });
});

/// Tek bir turnuvanın canlı verisi. Belge yoksa `null` yayınlar.
final tournamentStreamProvider =
    StreamProvider.family<Tournament?, String>((ref, id) {
  return ref
      .watch(firestoreProvider)
      .collection('tournaments')
      .doc(id)
      .snapshots()
      .map((doc) => doc.exists ? Tournament.fromDoc(doc) : null);
});

/// Bir turnuvanın maçları (fikstür). Sıralama istemci tarafında yapılır.
final matchesStreamProvider =
    StreamProvider.family<List<TournamentMatch>, String>((ref, id) {
  return ref
      .watch(firestoreProvider)
      .collection('tournaments')
      .doc(id)
      .collection('matches')
      .snapshots()
      .map((snap) {
    final matches = snap.docs.map(TournamentMatch.fromDoc).toList()
      ..sort((a, b) {
        final byOrder = a.order.compareTo(b.order);
        if (byOrder != 0) return byOrder;
        return a.round.compareTo(b.round);
      });
    return matches;
  });
});
