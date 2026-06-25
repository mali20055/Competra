import 'package:competra/models/tournament.dart';
import 'package:competra/services/fixture_generator.dart';
import 'package:flutter_test/flutter_test.dart';

List<Participant> _players(int n) => [
      for (var i = 0; i < n; i++) Participant(uid: 'p$i', username: 'P$i'),
    ];

String _pairKey(String a, String b) {
  final sorted = [a, b]..sort();
  return sorted.join('-');
}

void main() {
  group('generateLeagueFixtures', () {
    test('4 katılımcı: her çift tam olarak 1 kez eşleşir (6 maç)', () {
      final matches = generateLeagueFixtures(_players(4));

      expect(matches.length, 6);
      final keys = matches.map((m) => _pairKey(m.homeUid, m.awayUid)).toSet();
      expect(keys.length, 6, reason: 'Her çift yalnızca 1 kez görünmeli');
    });

    test('3 katılımcı: bye mantığı doğru, 3 tur * 1 maç = 3 maç', () {
      final matches = generateLeagueFixtures(_players(3));

      expect(matches.length, 3);
      // Hiçbir maç bye oyuncusunu içermemeli (lig fikstüründe bye maç üretmez).
      expect(matches.every((m) => m.homeUid != kByeUid && m.awayUid != kByeUid),
          isTrue);
    });
  });

  group('generateKnockoutFixtures', () {
    test('8 katılımcı: ilk turda 4 maç üretilir, bye yok', () {
      final matches = generateKnockoutFixtures(_players(8));

      expect(matches.length, 4);
      expect(matches.where((m) => m.isBye), isEmpty);
    });

    test('5 katılımcı: tek sayıda oyuncuda en az 1 bye olur', () {
      final matches = generateKnockoutFixtures(_players(5));

      final byes = matches.where((m) => m.isBye).toList();
      // bracket=8, byes=8-5=3: 3 bye + 1 gerçek maç.
      expect(byes.length, greaterThanOrEqualTo(1));
      expect(matches.length, byes.length + 1);
    });
  });

  group('generateNextKnockoutRound', () {
    test('4 kazanandan 2 maç üretilir', () {
      final matches = generateNextKnockoutRound(
        winnerUids: ['p0', 'p1', 'p2', 'p3'],
        uidToName: {'p0': 'P0', 'p1': 'P1', 'p2': 'P2', 'p3': 'P3'},
        nextRound: 2,
      );

      expect(matches.length, 2);
    });

    test('twoLegged=true: her eşleşme için 2 maç (1. ve 2. ayak) üretilir', () {
      final matches = generateNextKnockoutRound(
        winnerUids: ['p0', 'p1', 'p2', 'p3'],
        uidToName: {'p0': 'P0', 'p1': 'P1', 'p2': 'P2', 'p3': 'P3'},
        nextRound: 2,
        twoLegged: true,
      );

      // 4 kazanan -> 2 eşleşme, her eşleşme 2 ayak = 4 maç.
      expect(matches.length, 4);
      final legs = matches.map((m) => m['leg']).toSet();
      expect(legs, {1, 2});
    });
  });
}
