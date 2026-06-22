import 'dart:math';

import '../models/tournament.dart';

/// Bye (boş rakip) için sahte oyuncu kimliği.
const String kByeUid = '__bye__';

bool _isBye(Participant p) => p.uid == kByeUid;
Participant get _byePlayer => const Participant(uid: kByeUid, username: 'Bye');

/// Henüz Firestore'a yazılmamış (id'siz) bir fikstür maçı.
class GeneratedMatch {
  GeneratedMatch({
    required this.round,
    required this.order,
    required this.homeUid,
    required this.homeName,
    required this.awayUid,
    required this.awayName,
    this.homeScore,
    this.awayScore,
    this.isBye = false,
    this.stage = '',
    this.group = '',
    this.roundNumber = 1,
    this.phase = '',
  });

  final String round;
  final int order;
  final String homeUid;
  final String homeName;
  final String awayUid;
  final String awayName;
  final int? homeScore;
  final int? awayScore;
  final bool isBye;
  final String stage;
  final String group;

  /// Eleme formatında sayısal tur numarası (1 = açılış turu).
  final int roundNumber;

  /// Maç fazı: 'knockout' | 'group' | 'league'.
  final String phase;

  Map<String, dynamic> toMap() => {
        'round': round,
        'order': order,
        'homeUid': homeUid,
        'homeName': homeName,
        'awayUid': awayUid,
        'awayName': awayName,
        'homeScore': homeScore,
        'awayScore': awayScore,
        'played': homeScore != null && awayScore != null,
        'isBye': isBye,
        'stage': stage,
        'group': group,
        'roundNumber': roundNumber,
        'phase': phase,
        'leg': 1,
      };
}

/// Turnuva formatına ([Tournament.format] string'i) göre uygun fikstürü üretir.
///
/// Grup+Eleme ve Şampiyonlar Ligi'nde yalnızca ilk aşama (grup / lig fazı)
/// maçları üretilir; eleme aşaması, ilgili aşama tamamlandığında oluşturulur.
List<GeneratedMatch> generateFixtures(
  String format,
  List<Participant> players,
) {
  switch (format) {
    case 'knockout':
      return generateKnockoutFixtures(players);
    case 'groupKnockout':
      return generateGroupFixtures(generateGroups(players));
    case 'championsLeague':
      return generateChampionsLeaguePhaseFixtures(players);
    case 'league':
    default:
      return generateLeagueFixtures(players);
  }
}

// ---------------------------------------------------------------------------
// Lig — round robin
// ---------------------------------------------------------------------------

/// Circle-method round-robin turları. Her tur bir tam eşleşmedir (perfect
/// matching). Tek sayıda oyuncuda bir bye eklenir; bye eşleşmeleri maç üretmez.
List<List<(Participant, Participant)>> _roundRobinRounds(
  List<Participant> players,
) {
  final list = [...players];
  if (list.length.isOdd) list.add(_byePlayer);
  final n = list.length;
  if (n < 2) return const [];

  final fixed = list.first;
  final rotating = list.sublist(1);
  final rounds = <List<(Participant, Participant)>>[];

  for (var r = 0; r < n - 1; r++) {
    final roundPlayers = [fixed, ...rotating];
    final pairs = <(Participant, Participant)>[];
    for (var i = 0; i < n ~/ 2; i++) {
      pairs.add((roundPlayers[i], roundPlayers[n - 1 - i]));
    }
    rounds.add(pairs);
    // Sağa bir döndür (ilk oyuncu sabit).
    rotating.insert(0, rotating.removeLast());
  }
  return rounds;
}

/// Lig fikstürü: herkes herkesle bir kez. N×(N-1)/2 maç.
List<GeneratedMatch> generateLeagueFixtures(List<Participant> players) {
  final rounds = _roundRobinRounds(players);
  final matches = <GeneratedMatch>[];
  var order = 0;
  for (var r = 0; r < rounds.length; r++) {
    for (final pair in rounds[r]) {
      if (_isBye(pair.$1) || _isBye(pair.$2)) continue;
      matches.add(GeneratedMatch(
        round: '${r + 1}. Hafta',
        order: order++,
        homeUid: pair.$1.uid,
        homeName: pair.$1.username,
        awayUid: pair.$2.uid,
        awayName: pair.$2.username,
        stage: 'league',
        phase: 'league',
      ));
    }
  }
  return matches;
}

// ---------------------------------------------------------------------------
// Eleme — bracket (ilk tur + bye)
// ---------------------------------------------------------------------------

int _nextPowerOfTwo(int n) {
  var p = 1;
  while (p < n) {
    p <<= 1;
  }
  return p;
}

String _knockoutRoundName(int bracketSize) {
  switch (bracketSize) {
    case 2:
      return 'Final';
    case 4:
      return 'Yarı Final';
    case 8:
      return 'Çeyrek Final';
    case 16:
      return 'Son 16';
    case 32:
      return 'Son 32';
    default:
      return 'Eleme Turu';
  }
}

/// Eleme fikstürü (açılış turu). Oyuncular karıştırılır; katılımcı sayısı 2'nin
/// kuvveti değilse bazı oyuncular bye alır (otomatik tur atlar). Sonraki turlar
/// sonuçlar girildikçe oluşturulur.
List<GeneratedMatch> generateKnockoutFixtures(
  List<Participant> players, {
  Random? random,
}) {
  if (players.length < 2) return const [];
  final rnd = random ?? Random();
  final shuffled = [...players]..shuffle(rnd);

  final bracket = _nextPowerOfTwo(shuffled.length);
  final byes = bracket - shuffled.length;
  final roundName = _knockoutRoundName(bracket);

  final byePlayers = shuffled.take(byes).toList();
  final rest = shuffled.skip(byes).toList();

  final matches = <GeneratedMatch>[];
  var order = 0;

  // Bye maçları: 3-0 ile otomatik kazanılmış sayılır (averaja katılmaz).
  for (final p in byePlayers) {
    matches.add(GeneratedMatch(
      round: roundName,
      order: order++,
      homeUid: p.uid,
      homeName: p.username,
      awayUid: kByeUid,
      awayName: 'Bye',
      homeScore: 3,
      awayScore: 0,
      isBye: true,
      stage: 'knockout',
      phase: 'knockout',
      roundNumber: 1,
    ));
  }

  // Gerçek ilk tur eşleşmeleri.
  for (var i = 0; i + 1 < rest.length; i += 2) {
    matches.add(GeneratedMatch(
      round: roundName,
      order: order++,
      homeUid: rest[i].uid,
      homeName: rest[i].username,
      awayUid: rest[i + 1].uid,
      awayName: rest[i + 1].username,
      stage: 'knockout',
      phase: 'knockout',
      roundNumber: 1,
    ));
  }
  return matches;
}

/// Bir eleme turu tamamlandığında kazananlardan sonraki turun maçlarını üretir.
///
/// [winnerUids] bracket sırasında olmalıdır (KARIŞTIRILMAZ); böylece eşleşmeler
/// (0,1), (2,3), (4,5)… şeklinde ilerler ve ağaç yapısı korunur. Tek sayıda
/// kazanan varsa son kişi bir bye maçı alarak otomatik tur atlar.
///
/// Dönen her Map doğrudan `tournaments/{id}/matches` belgesine yazılabilir.
/// `round` kullanıcıya gösterilen etiket (ör. 'Final'), `roundNumber` ise
/// sayısal tur ([nextRound])'dur.
/// [twoLegged] true ise her gerçek eşleşme için iki ayak (ev/deplasman) üretilir
/// (Şampiyonlar Ligi eleme aşaması); bye eşleşmeleri tek maçtır.
List<Map<String, dynamic>> generateNextKnockoutRound({
  required List<String> winnerUids,
  required Map<String, String> uidToName,
  required int nextRound,
  bool twoLegged = false,
}) {
  if (winnerUids.length < 2) return const [];

  final roundName = _knockoutRoundName(_nextPowerOfTwo(winnerUids.length));
  // Sonraki turun maçları mevcut turlardan sonra sıralansın diye order ofseti.
  final orderBase = nextRound * 1000;

  final matches = <Map<String, dynamic>>[];
  var order = 0;
  for (var i = 0; i < winnerUids.length; i += 2) {
    if (i + 1 < winnerUids.length) {
      final homeUid = winnerUids[i];
      final awayUid = winnerUids[i + 1];
      final homeName = uidToName[homeUid] ?? 'Oyuncu';
      final awayName = uidToName[awayUid] ?? 'Oyuncu';
      // 1. ayak.
      matches.add(_koMap(
        homeUid: homeUid,
        homeName: homeName,
        awayUid: awayUid,
        awayName: awayName,
        isBye: false,
        roundNumber: nextRound,
        order: orderBase + order++,
        roundName: roundName,
        leg: 1,
      ));
      // 2. ayak (yalnızca iki ayaklıysa): ev/deplasman değişir.
      if (twoLegged) {
        matches.add(_koMap(
          homeUid: awayUid,
          homeName: awayName,
          awayUid: homeUid,
          awayName: homeName,
          isBye: false,
          roundNumber: nextRound,
          order: orderBase + order++,
          roundName: roundName,
          leg: 2,
        ));
      }
    } else {
      // Tek kalan son kişi bye alır (tek maç).
      matches.add(_koMap(
        homeUid: winnerUids[i],
        homeName: uidToName[winnerUids[i]] ?? 'Oyuncu',
        awayUid: kByeUid,
        awayName: 'Bye',
        isBye: true,
        roundNumber: nextRound,
        order: orderBase + order++,
        roundName: roundName,
        leg: 1,
      ));
    }
  }
  return matches;
}

// ---------------------------------------------------------------------------
// Grup + Eleme
// ---------------------------------------------------------------------------

String _groupLabel(int index) => String.fromCharCode(65 + index); // A, B, C…

/// Oyuncuları dengeli biçimde gruplara dağıtır (grup başına 3-4 kişi hedefi).
Map<String, List<Participant>> generateGroups(
  List<Participant> players, {
  Random? random,
}) {
  final rnd = random ?? Random();
  final shuffled = [...players]..shuffle(rnd);
  final groupCount = max(1, (shuffled.length / 4).ceil());

  final groups = <String, List<Participant>>{
    for (var i = 0; i < groupCount; i++) _groupLabel(i): <Participant>[],
  };
  for (var i = 0; i < shuffled.length; i++) {
    groups[_groupLabel(i % groupCount)]!.add(shuffled[i]);
  }
  return groups;
}

/// Her grup için kendi içinde round-robin grup maçları.
List<GeneratedMatch> generateGroupFixtures(
  Map<String, List<Participant>> groups,
) {
  final matches = <GeneratedMatch>[];
  var order = 0;
  for (final entry in groups.entries) {
    final label = entry.key;
    final rounds = _roundRobinRounds(entry.value);
    for (var r = 0; r < rounds.length; r++) {
      for (final pair in rounds[r]) {
        if (_isBye(pair.$1) || _isBye(pair.$2)) continue;
        matches.add(GeneratedMatch(
          round: '$label Grubu • ${r + 1}. Maç',
          order: order++,
          homeUid: pair.$1.uid,
          homeName: pair.$1.username,
          awayUid: pair.$2.uid,
          awayName: pair.$2.username,
          stage: 'group',
          phase: 'group',
          group: label,
        ));
      }
    }
  }
  return matches;
}

/// Tek bir eleme maçı için Firestore'a yazılabilir Map üretir (ortak şablon).
Map<String, dynamic> _koMap({
  required String homeUid,
  required String homeName,
  required String awayUid,
  required String awayName,
  required bool isBye,
  required int roundNumber,
  required int order,
  required String roundName,
  int leg = 1,
}) =>
    {
      'round': roundName,
      'roundNumber': roundNumber,
      'order': order,
      'homeUid': homeUid,
      'homeName': homeName,
      'awayUid': awayUid,
      'awayName': awayName,
      'homeScore': null,
      'awayScore': null,
      'played': false,
      'isBye': isBye,
      'stage': 'knockout',
      'phase': 'knockout',
      'group': '',
      'status': 'pending',
      'leg': leg,
    };

/// Grup aşaması bittiğinde, grup birincileri ve ikincilerini ÇAPRAZ eşleştirerek
/// ilk eleme turunu üretir.
///
/// [groupWinners] her grup için `[1.oyuncu_uid, 2.oyuncu_uid]` listesidir
/// (grup etiketine göre sıralı: A, B, C…). Eşleşme deseni:
/// - 2 grup:  A1-B2, B1-A2
/// - 3 grup:  A1-B2, B1-C2, C1-A2  (döngüsel)
/// - 4 grup:  A1-B2, C1-D2, B1-A2, D1-C2  (ikişerli çapraz)
///
/// Dönen Map'ler `roundNumber: startRound`, `phase: 'knockout'`,
/// `status: 'pending'`, `isBye: false` taşır.
List<Map<String, dynamic>> generateKnockoutFromGroups({
  required List<List<String>> groupWinners,
  required Map<String, String> uidToName,
  required int startRound,
}) {
  // Yalnızca tam (1. + 2.) çıkan gruplar eşleşmeye katılır.
  final valid = groupWinners.where((g) => g.length >= 2).toList();
  final g = valid.length;
  if (g == 0) return const [];

  final pairs = <(String, String)>[]; // (homeUid, awayUid)
  if (g.isEven) {
    // İkişerli çapraz: önce her çiftin X1-Y2'si, sonra Y1-X2'si.
    for (var i = 0; i < g; i += 2) {
      pairs.add((valid[i][0], valid[i + 1][1]));
    }
    for (var i = 0; i < g; i += 2) {
      pairs.add((valid[i + 1][0], valid[i][1]));
    }
  } else {
    // Tek sayıda grup: döngüsel çapraz (g'nin 1.si vs (g+1)'in 2.si).
    for (var i = 0; i < g; i++) {
      pairs.add((valid[i][0], valid[(i + 1) % g][1]));
    }
  }

  final roundName = _knockoutRoundName(_nextPowerOfTwo(pairs.length * 2));
  final orderBase = startRound * 1000;
  final matches = <Map<String, dynamic>>[];
  for (var i = 0; i < pairs.length; i++) {
    final (homeUid, awayUid) = pairs[i];
    matches.add(_koMap(
      homeUid: homeUid,
      homeName: uidToName[homeUid] ?? 'Oyuncu',
      awayUid: awayUid,
      awayName: uidToName[awayUid] ?? 'Oyuncu',
      isBye: false,
      roundNumber: startRound,
      order: orderBase + i,
      roundName: roundName,
    ));
  }
  return matches;
}

/// Sıralı (seeded) bir oyuncu listesinden ÇAPRAZ eşleşmeli eleme turu üretir:
/// 1. vs sonuncu, 2. vs sondan ikinci… Tek sayıda oyuncuda ortadaki bye alır.
///
/// Şampiyonlar Ligi lig fazından elemeye geçişte kullanılır. Eleme aşaması ÇİFT
/// MAÇLIDIR (iki ayaklı): her gerçek eşleşme için 1. ayak (üst sıralı ev sahibi)
/// ve 2. ayak (ev/deplasman değişir) üretilir. Bye eşleşmeleri tek maçtır.
List<Map<String, dynamic>> generateKnockoutFromSeeds({
  required List<String> seedUids,
  required Map<String, String> uidToName,
  required int startRound,
}) {
  final q = seedUids.length;
  if (q < 2) return const [];

  final roundName = _knockoutRoundName(_nextPowerOfTwo(q));
  final orderBase = startRound * 1000;
  final matches = <Map<String, dynamic>>[];
  var order = 0;
  for (var i = 0; i * 2 < q; i++) {
    final awayIdx = q - 1 - i;
    if (awayIdx > i) {
      final homeUid = seedUids[i];
      final awayUid = seedUids[awayIdx];
      final homeName = uidToName[homeUid] ?? 'Oyuncu';
      final awayName = uidToName[awayUid] ?? 'Oyuncu';
      // 1. ayak: üst sıralı (seed) oyuncu ev sahibi.
      matches.add(_koMap(
        homeUid: homeUid,
        homeName: homeName,
        awayUid: awayUid,
        awayName: awayName,
        isBye: false,
        roundNumber: startRound,
        order: orderBase + order++,
        roundName: roundName,
        leg: 1,
      ));
      // 2. ayak: ev/deplasman değişir.
      matches.add(_koMap(
        homeUid: awayUid,
        homeName: awayName,
        awayUid: homeUid,
        awayName: homeName,
        isBye: false,
        roundNumber: startRound,
        order: orderBase + order++,
        roundName: roundName,
        leg: 2,
      ));
    } else if (awayIdx == i) {
      // Ortadaki oyuncu (tek sayı) bye alır (tek maç).
      final homeUid = seedUids[i];
      matches.add(_koMap(
        homeUid: homeUid,
        homeName: uidToName[homeUid] ?? 'Oyuncu',
        awayUid: kByeUid,
        awayName: 'Bye',
        isBye: true,
        roundNumber: startRound,
        order: orderBase + order++,
        roundName: roundName,
        leg: 1,
      ));
    }
  }
  return matches;
}

// ---------------------------------------------------------------------------
// Şampiyonlar Ligi — kısmi round-robin (lig fazı)
// ---------------------------------------------------------------------------

/// Lig fazı: herkes belirli sayıda farklı rakiple oynar (kimse aynı kişiyle iki
/// kez oynamaz). Round-robin programının ilk K turu alınır; bu, dengeli ve
/// tekrarsız bir eşleşme dağılımı garanti eder.
///
/// - 8 oyuncuya kadar: herkes 4 rakiple
/// - 8+ oyuncuda: herkes ceil(N/2) rakiple
List<GeneratedMatch> generateChampionsLeaguePhaseFixtures(
  List<Participant> players,
) {
  final n = players.length;
  if (n < 2) return const [];

  var k = n <= 8 ? 4 : (n / 2).ceil();
  k = min(k, n - 1); // en fazla N-1 farklı rakip olabilir

  final rounds = _roundRobinRounds(players);
  final take = min(k, rounds.length);

  final matches = <GeneratedMatch>[];
  var order = 0;
  for (var r = 0; r < take; r++) {
    for (final pair in rounds[r]) {
      if (_isBye(pair.$1) || _isBye(pair.$2)) continue;
      matches.add(GeneratedMatch(
        round: 'Lig Fazı • ${r + 1}. Maç',
        order: order++,
        homeUid: pair.$1.uid,
        homeName: pair.$1.username,
        awayUid: pair.$2.uid,
        awayName: pair.$2.username,
        stage: 'league',
        phase: 'league',
      ));
    }
  }
  return matches;
}
