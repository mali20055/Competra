// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:competra/models/tournament.dart';
import 'package:flutter_test/flutter_test.dart';

/// `Tournament.fromDoc` yalnızca `doc.id` ve `doc.data()` kullanır; gerçek bir
/// Firestore bağımlılığı (emulator/fake_cloud_firestore) eklemeden test etmek
/// için minimal bir sahte [DocumentSnapshot] yeterlidir.
class _FakeDocSnapshot implements DocumentSnapshot<Map<String, dynamic>> {
  _FakeDocSnapshot(this._id, this._data);

  final String _id;
  final Map<String, dynamic> _data;

  @override
  String get id => _id;

  @override
  Map<String, dynamic>? data() => _data;

  @override
  bool get exists => true;

  @override
  DocumentReference<Map<String, dynamic>> get reference =>
      throw UnimplementedError();

  @override
  SnapshotMetadata get metadata => throw UnimplementedError();

  @override
  dynamic get(Object field) => _data[field];

  @override
  dynamic operator [](Object field) => _data[field];
}

/// `TournamentMatch.fromDoc` için aynı amaçla minimal sahte
/// [QueryDocumentSnapshot].
class _FakeQueryDocSnapshot
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  _FakeQueryDocSnapshot(this._id, this._data);

  final String _id;
  final Map<String, dynamic> _data;

  @override
  String get id => _id;

  @override
  Map<String, dynamic> data() => _data;

  @override
  bool get exists => true;

  @override
  DocumentReference<Map<String, dynamic>> get reference =>
      throw UnimplementedError();

  @override
  SnapshotMetadata get metadata => throw UnimplementedError();

  @override
  dynamic get(Object field) => _data[field];

  @override
  dynamic operator [](Object field) => _data[field];
}

void main() {
  group('Tournament.fromDoc', () {
    test('eksik alanlarda varsayılan değerler doğru set edilir', () {
      final tournament =
          Tournament.fromDoc(_FakeDocSnapshot('t1', const <String, dynamic>{}));

      expect(tournament.id, 't1');
      expect(tournament.name, 'Turnuva');
      expect(tournament.note, '');
      expect(tournament.format, '');
      expect(tournament.inviteCode, '');
      expect(tournament.ownerId, '');
      expect(tournament.participants, isEmpty);
      expect(tournament.status, 'active');
      expect(tournament.tiebreakerMode, TiebreakerMode.uefa);
      expect(tournament.createdAt, isNull);
      // format='' ve status='active' -> _derivePhase varsayılan dalı 'league'.
      expect(tournament.currentPhase, 'league');
      // raw scoreEntrySystem/scoreMode boş -> normalize varsayılanı 'doubleEntry'.
      expect(tournament.scoreEntrySystem, 'doubleEntry');
    });

    test("_normalizeScoreEntry: eski 'bothPlayers' -> 'doubleEntry'", () {
      final tournament = Tournament.fromDoc(
        _FakeDocSnapshot('t2', const {'scoreMode': 'bothPlayers'}),
      );

      expect(tournament.scoreEntrySystem, 'doubleEntry');
      expect(tournament.isDoubleEntryScoring, isTrue);
    });

    test("_normalizeScoreEntry: eski 'winnerEnters' -> 'winnerEntry'", () {
      final tournament = Tournament.fromDoc(
        _FakeDocSnapshot('t3', const {'scoreMode': 'winnerEnters'}),
      );

      expect(tournament.scoreEntrySystem, 'winnerEntry');
      expect(tournament.isWinnerEntryScoring, isTrue);
    });
  });

  group('TournamentMatch.fromDoc', () {
    test("legacy 'stage' alanı, phase boşken phase'e düşer", () {
      final match = TournamentMatch.fromDoc(
        _FakeQueryDocSnapshot('m1', const {'stage': 'knockout'}),
      );

      expect(match.phase, 'knockout');
    });

    test("phase doluysa 'stage' yerine phase kullanılır", () {
      final match = TournamentMatch.fromDoc(
        _FakeQueryDocSnapshot(
          'm2',
          const {'phase': 'group', 'stage': 'knockout'},
        ),
      );

      expect(match.phase, 'group');
    });

    test('isBye: bye maçı doğru tanınır', () {
      final byeMatch = TournamentMatch.fromDoc(
        _FakeQueryDocSnapshot('m3', const {'isBye': true}),
      );
      final normalMatch = TournamentMatch.fromDoc(
        _FakeQueryDocSnapshot('m4', const <String, dynamic>{}),
      );

      expect(byeMatch.isBye, isTrue);
      expect(normalMatch.isBye, isFalse);
    });
  });
}
