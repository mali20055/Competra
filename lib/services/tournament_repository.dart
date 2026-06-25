import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../models/tournament.dart';
import '../models/roster_entry.dart';
import 'analytics_service.dart';
import 'fixture_generator.dart';
import 'firebase_providers.dart';
import 'premium_service.dart';

/// Turnuva şablonu — kullanıcının kaydettiği oluşturma ayarları.
class TournamentTemplate {
  const TournamentTemplate({
    required this.id,
    required this.name,
    required this.format,
    required this.scoreMode,
    required this.tiebreakerMode,
  });

  final String id;
  final String name;
  final String format;
  final String scoreMode;
  final String tiebreakerMode;

  factory TournamentTemplate.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return TournamentTemplate(
      id: doc.id,
      name: (data['name'] as String?) ?? '',
      format: (data['format'] as String?) ?? '',
      scoreMode: (data['scoreMode'] as String?) ?? '',
      tiebreakerMode: (data['tiebreakerMode'] as String?) ?? 'uefa',
    );
  }
}

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

    final isPremium = await PremiumService.isPremium();
    if (!isPremium) {
      final activeTournaments = await _tournaments
          .where('ownerId', isEqualTo: uid)
          .where('status', isEqualTo: 'active')
          .get();
      if (activeTournaments.docs.length >= 3) {
        throw Exception('Ücretsiz hesaplarda en fazla 3 aktif turnuva oluşturabilirsin.');
      }
    }

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
    AnalyticsService.logTournamentCreated(format).ignore();
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
    AnalyticsService.logTournamentJoined().ignore();
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
    AnalyticsService.logMatchScoreEntered().ignore();
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

  /// Bekleme ('waiting') durumundaki bir turnuvadan katılımcıyı çıkarır.
  ///
  /// Turnuva başlamışsa hata fırlatır. `participantIds` dizisinden ve
  /// `participants` listesinden ilgili kullanıcıyı temizler.
  Future<void> removeParticipant({
    required String tournamentId,
    required String participantUid,
  }) async {
    final doc = await _tournaments.doc(tournamentId).get();
    final status = (doc.data()?['status'] as String?) ?? '';
    if (status != 'waiting') {
      throw Exception('Başlamış turnuvadan katılımcı çıkarılamaz.');
    }
    final participants = List<Map<String, dynamic>>.from(
      (doc.data()?['participants'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map)),
    );
    participants.removeWhere((p) => p['uid'] == participantUid);

    await _tournaments.doc(tournamentId).update({
      'participantIds': FieldValue.arrayRemove([participantUid]),
      'participants': participants,
    });
  }

  Future<void> addCoAdmin(String tournamentId, String uid) async {
    await _tournaments.doc(tournamentId).update({
      'adminIds': FieldValue.arrayUnion([uid]),
    });
  }

  Future<void> removeCoAdmin(String tournamentId, String uid) async {
    await _tournaments.doc(tournamentId).update({
      'adminIds': FieldValue.arrayRemove([uid]),
    });
  }

  Future<void> updateRoster(
    String tournamentId,
    List<RosterEntry> roster,
  ) async {
    await _tournaments.doc(tournamentId).update({
      'roster': roster.map((e) => e.toMap()).toList(),
    });
  }

  Future<void> voteMvp(String tournamentId, String nomineeUid) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _tournaments.doc(tournamentId)
      .collection('votes')
      .doc(uid)
      .set({
        'nomineeUid': nomineeUid,
        'voterUid': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
  }

  Future<Map<String, int>> getMvpVotes(String tournamentId) async {
    final snap = await _tournaments.doc(tournamentId)
      .collection('votes').get();
    final counts = <String, int>{};
    for (final doc in snap.docs) {
      final nominee = doc.data()['nomineeUid'] as String?;
      if (nominee != null) counts[nominee] = (counts[nominee] ?? 0) + 1;
    }
    return counts;
  }

  Future<void> predictWinner(String tournamentId, String winnerUid) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _tournaments.doc(tournamentId)
      .collection('predictions')
      .doc(uid)
      .set({
        'winnerUid': winnerUid,
        'predictorUid': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
  }

  /// Mevcut kullanıcının `templates` koleksiyonuna bir şablon kaydeder.
  Future<void> saveAsTemplate({
    required String name,
    required String format,
    required String scoreMode,
    required String tiebreakerMode,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _firestore.collection('templates').add({
      'userId': uid,
      'name': name,
      'format': format,
      'scoreMode': scoreMode,
      'tiebreakerMode': tiebreakerMode,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Tek bir turnuva belgesinin canlı olmayan anlık görüntüsü.
  ///
  /// "Daha fazla yükle" akışında, canlı ([myTournamentsStreamProvider]) ilk
  /// sayfanın son öğesi için `startAfterDocument` anahtarı gereklidir; stream
  /// yalnızca modelleri yayınladığından bu anahtar id ile tek seferlik bir
  /// okumayla çözülür.
  Future<DocumentSnapshot<Map<String, dynamic>>> docSnapshot(String id) {
    return _tournaments.doc(id).get();
  }

  /// `startAfter`'dan sonraki turnuva sayfasını çeker.
  Future<TournamentsPage> fetchNextPage({
    required String uid,
    required DocumentSnapshot<Map<String, dynamic>> startAfter,
    int limit = AppConstants.tournamentsLimit,
  }) async {
    final snap = await _tournaments
        .where('participantIds', arrayContains: uid)
        .orderBy('createdAt', descending: true)
        .startAfterDocument(startAfter)
        .limit(limit)
        .get();
    return TournamentsPage(
      items: snap.docs.map(Tournament.fromDoc).toList(),
      lastDoc: snap.docs.isEmpty ? null : snap.docs.last,
      hasMore: snap.docs.length == limit,
    );
  }
}

/// Bir turnuva sayfası: öğeler + sonraki sayfa için `startAfterDocument`
/// anahtarı + daha fazla sayfa olup olmadığı.
class TournamentsPage {
  const TournamentsPage({
    required this.items,
    required this.lastDoc,
    required this.hasMore,
  });

  final List<Tournament> items;
  final DocumentSnapshot<Map<String, dynamic>>? lastDoc;
  final bool hasMore;
}

final tournamentRepositoryProvider = Provider<TournamentRepository>(
  (ref) => TournamentRepository(
    ref.watch(firestoreProvider),
    ref.watch(firebaseAuthProvider),
  ),
);

/// O an oturum açmış kullanıcının katıldığı en yeni
/// [AppConstants.tournamentsLimit] turnuva (en yeni en üstte).
///
/// `participantIds arrayContains` + `createdAt DESC` bileşik dizini gerektirir
/// (bkz. firestore.indexes.json). Daha eskiler "Daha fazla yükle" ile
/// [TournamentRepository.fetchNextPage] üzerinden ayrıca çekilir.
final myTournamentsStreamProvider =
    StreamProvider<List<Tournament>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(const []);
  return ref
      .watch(firestoreProvider)
      .collection('tournaments')
      .where('participantIds', arrayContains: user.uid)
      .orderBy('createdAt', descending: true)
      .limit(AppConstants.tournamentsLimit)
      .snapshots()
      .map((snap) => snap.docs.map(Tournament.fromDoc).toList());
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

/// Oturum açmış kullanıcının kayıtlı turnuva şablonları (en yeni 10).
final myTemplatesProvider =
    StreamProvider<List<TournamentTemplate>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(const []);
  return ref
      .watch(firestoreProvider)
      .collection('templates')
      .where('userId', isEqualTo: user.uid)
      .orderBy('createdAt', descending: true)
      .limit(10)
      .snapshots()
      .map(
        (snap) => snap.docs
            .map(TournamentTemplate.fromDoc)
            .toList(),
      );
});

/// Oturum açmış kullanıcının bu turnuva için yaptığı kazanan tahminini canlı dinler.
final myTournamentPredictionProvider =
    StreamProvider.family<String?, String>((ref, tournamentId) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(null);
  return ref
      .watch(firestoreProvider)
      .collection('tournaments')
      .doc(tournamentId)
      .collection('predictions')
      .doc(user.uid)
      .snapshots()
      .map((doc) => doc.data()?['winnerUid'] as String?);
});

/// Oturum açmış kullanıcının bu turnuva için verdiği MVP oyunu canlı dinler.
final myMvpVoteProvider =
    StreamProvider.family<String?, String>((ref, tournamentId) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(null);
  return ref
      .watch(firestoreProvider)
      .collection('tournaments')
      .doc(tournamentId)
      .collection('votes')
      .doc(user.uid)
      .snapshots()
      .map((doc) => doc.data()?['nomineeUid'] as String?);
});
