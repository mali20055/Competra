import '../../models/tournament.dart';

/// Maç listesini bracket tree yapısına dönüştürür.
/// Dönüş: round bazında gruplandırılmış maç listesi.
/// [[tur1Maç1, tur1Maç2], [tur2Maç1], [final]]
List<List<TournamentMatch>> buildBracketTree(
  List<TournamentMatch> matches,
  String phase, // 'knockout'
) {
  final rounds = <int, List<TournamentMatch>>{};
  for (final m in matches.where((m) => m.phase == phase)) {
    final r = m.roundNumber;
    rounds.putIfAbsent(r, () => []).add(m);
  }
  final sortedKeys = rounds.keys.toList()..sort();
  return sortedKeys.map((k) {
    final list = rounds[k]!..sort((a, b) => (a.order).compareTo(b.order));
    return list;
  }).toList();
}
