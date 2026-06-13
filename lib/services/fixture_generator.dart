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
    ));
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
          group: label,
        ));
      }
    }
  }
  return matches;
}

/// Gruplardan çıkan (seeding'e göre sıralı) oyunculardan eleme eşleşmeleri.
///
/// Çapraz eşleşme: 1. sıra vs son sıra, 2. sıra vs sondan bir önceki…
/// Grup aşaması tamamlandığında çağrılır.
List<GeneratedMatch> generateKnockoutFromGroups(List<Participant> seeded) {
  if (seeded.length < 2) return const [];
  final roundName = _knockoutRoundName(_nextPowerOfTwo(seeded.length));
  final matches = <GeneratedMatch>[];
  var order = 0;
  for (var i = 0; i < seeded.length ~/ 2; i++) {
    final home = seeded[i];
    final away = seeded[seeded.length - 1 - i];
    matches.add(GeneratedMatch(
      round: roundName,
      order: order++,
      homeUid: home.uid,
      homeName: home.username,
      awayUid: away.uid,
      awayName: away.username,
      stage: 'knockout',
    ));
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
      ));
    }
  }
  return matches;
}
