import 'package:competra/models/tournament.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ortak test maçı oluşturucu — boilerplate'i azaltır.
TournamentMatch _match({
  required String home,
  required String away,
  int? homeScore,
  int? awayScore,
  bool isBye = false,
  String id = 'm',
}) {
  return TournamentMatch(
    id: id,
    round: '1',
    order: 0,
    homeUid: home,
    homeName: home,
    awayUid: away,
    awayName: away,
    homeScore: homeScore,
    awayScore: awayScore,
    isBye: isBye,
    status: 'completed',
    enteredBy: '',
    enteredHomeScore: null,
    enteredAwayScore: null,
    secondEnteredBy: '',
    secondEnteredHomeScore: null,
    secondEnteredAwayScore: null,
  );
}

const _a = Participant(uid: 'A', username: 'A');
const _b = Participant(uid: 'B', username: 'B');
const _c = Participant(uid: 'C', username: 'C');

/// Üç oyunculu döngüsel senaryo: A,B,C kendi aralarında 1'er kez oynar
/// (A 3-0 B, B 1-0 C, C 1-0 A) + her biri ayrıca "D" rakibine karşı 1 galibiyet
/// + 1 mağlubiyet alır (skor farkları, genel puan ve genel averajı üçü için
/// de eşitleyecek şekilde seçilmiştir). Bu, "genel averaj eşit ama ikili
/// averaj farklı" durumunu üretir — UEFA/FIFA modlarının farklı sıralama
/// verdiğini göstermek için kullanılır.
List<TournamentMatch> _threeWayCycleMatches() => [
      _match(id: '1', home: 'A', away: 'B', homeScore: 3, awayScore: 0),
      _match(id: '2', home: 'B', away: 'C', homeScore: 1, awayScore: 0),
      _match(id: '3', home: 'C', away: 'A', homeScore: 1, awayScore: 0),
      _match(id: '4', home: 'A', away: 'D', homeScore: 1, awayScore: 0),
      _match(id: '5', home: 'D', away: 'A', homeScore: 3, awayScore: 0),
      _match(id: '6', home: 'B', away: 'D', homeScore: 3, awayScore: 0),
      _match(id: '7', home: 'D', away: 'B', homeScore: 1, awayScore: 0),
      _match(id: '8', home: 'C', away: 'D', homeScore: 1, awayScore: 0),
      _match(id: '9', home: 'D', away: 'C', homeScore: 1, awayScore: 0),
    ];

void main() {
  group('computeStandings', () {
    test('2 oyuncu: net kazanan birinci sıraya gelir', () {
      final result = computeStandings(
        [_a, _b],
        [_match(home: 'A', away: 'B', homeScore: 3, awayScore: 0)],
        TiebreakerMode.uefa,
      );

      expect(result.first.uid, 'A');
      expect(result.first.points, 3);
      expect(result.last.points, 0);
    });

    test('2 oyuncu eşit puan: gol averajı üstün olan birinci', () {
      // İkisi de 1 galibiyet + 1 mağlubiyet alır (3 puan), ama A'nın averajı
      // (+2) B'nin averajından (-2) üstün.
      final result = computeStandings(
        [_a, _b],
        [
          _match(id: '1', home: 'A', away: 'B', homeScore: 3, awayScore: 0),
          _match(id: '2', home: 'B', away: 'A', homeScore: 1, awayScore: 0),
        ],
        TiebreakerMode.uefa,
      );

      expect(result.first.uid, 'A');
      expect(result.first.points, 3);
      expect(result.last.uid, 'B');
      expect(result.first.goalDiff, greaterThan(result.last.goalDiff));
    });

    test(
        '3 oyuncu eşit puan + eşit genel averaj: UEFA ikili averaj kuralı '
        'devreye girer', () {
      final participants = [_a, _b, _c];
      final matches = _threeWayCycleMatches();

      final result = computeStandings(participants, matches, TiebreakerMode.uefa);

      // Önce genel puan/averajın gerçekten eşit olduğunu doğrula.
      final aRow = result.firstWhere((r) => r.uid == 'A');
      final bRow = result.firstWhere((r) => r.uid == 'B');
      final cRow = result.firstWhere((r) => r.uid == 'C');
      expect(aRow.points, bRow.points);
      expect(bRow.points, cRow.points);
      expect(aRow.goalDiff, 0);
      expect(bRow.goalDiff, 0);
      expect(cRow.goalDiff, 0);

      // İkili averaj (h2h) devreye girince sıralama A > C > B olmalı.
      final order = result.map((r) => r.uid).where(['A', 'B', 'C'].contains);
      expect(order, ['A', 'C', 'B']);
    });

    test('bye maçı istatistiğe sayılmaz', () {
      final result = computeStandings(
        [_a, _b],
        [
          _match(
            id: 'bye',
            home: 'A',
            away: 'BYE',
            homeScore: 3,
            awayScore: 0,
            isBye: true,
          ),
          _match(id: 'real', home: 'A', away: 'B', homeScore: 2, awayScore: 1),
        ],
        TiebreakerMode.uefa,
      );

      final aRow = result.firstWhere((r) => r.uid == 'A');
      // Sadece gerçek maç sayılmalı: 1 maç, 2 gol (bye'daki 3 gol hariç).
      expect(aRow.played, 1);
      expect(aRow.goalsFor, 2);
      expect(aRow.points, 3);
    });

    test('FIFA ve UEFA modu aynı girdide farklı sıralama üretir', () {
      final participants = [_a, _b, _c];
      final matches = _threeWayCycleMatches();

      final fifaOrder = computeStandings(participants, matches, TiebreakerMode.fifa)
          .map((r) => r.uid)
          .where(['A', 'B', 'C'].contains)
          .toList();
      final uefaOrder = computeStandings(participants, matches, TiebreakerMode.uefa)
          .map((r) => r.uid)
          .where(['A', 'B', 'C'].contains)
          .toList();

      expect(fifaOrder, ['A', 'B', 'C']);
      expect(uefaOrder, ['A', 'C', 'B']);
      expect(fifaOrder, isNot(equals(uefaOrder)));
    });
  });

  group('computeScorers', () {
    test('en çok gol atan birinci sıraya gelir', () {
      final result = computeScorers(
        [_a, _b],
        [_match(home: 'A', away: 'B', homeScore: 5, awayScore: 2)],
      );

      expect(result.first.uid, 'A');
      expect(result.first.goals, 5);
    });

    test('eşit golde isme göre (alfabetik) sıralanır', () {
      // NOT: Gerçek implementasyon eşit golde MAÇ SAYISINA göre değil, isme
      // göre (alfabetik) sıralıyor (bkz. lib/models/tournament.dart
      // computeScorers — `a.name.toLowerCase().compareTo(b.name...)`).
      const ahmet = Participant(uid: 'ahmet', username: 'Ahmet');
      const zeynep = Participant(uid: 'zeynep', username: 'Zeynep');

      final result = computeScorers(
        [ahmet, zeynep],
        [
          _match(id: '1', home: 'ahmet', away: 'zeynep', homeScore: 5, awayScore: 5),
        ],
      );

      expect(result[0].name, 'Ahmet');
      expect(result[1].name, 'Zeynep');
    });
  });
}
