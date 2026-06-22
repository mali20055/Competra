import 'user_profile.dart';

/// İstatistiklere göre otomatik atanan bir unvanın tanımı.
///
/// [condition] bir [UserProfile] alıp bu unvanın hak edilip edilmediğini döner.
/// [priority] ne kadar yüksekse unvan o kadar prestijlidir; birden çok koşul
/// sağlandığında en yüksek [priority]'li unvan aktif olur.
class TitleDefinition {
  const TitleDefinition({
    required this.id,
    required this.label,
    required this.condition,
    required this.priority,
  });

  final String id;
  final String label;
  final bool Function(UserProfile profile) condition;
  final int priority;
}

/// Uygulamadaki tüm unvanların kataloğu (artan prestij = artan priority).
class TitleDefinitions {
  const TitleDefinitions._();

  static final List<TitleDefinition> all = [
    TitleDefinition(
      id: 'rookie',
      label: 'Çaylak',
      priority: 0,
      condition: (p) => p.tournamentsPlayed == 0,
    ),
    TitleDefinition(
      id: 'amateur',
      label: 'Amatör',
      priority: 1,
      condition: (p) => p.tournamentsPlayed >= 1,
    ),
    TitleDefinition(
      id: 'semi_pro',
      label: 'Yarı Pro',
      priority: 2,
      condition: (p) => p.tournamentsPlayed >= 5,
    ),
    TitleDefinition(
      id: 'pro',
      label: 'Pro',
      priority: 3,
      condition: (p) => p.tournamentsWon >= 1,
    ),
    TitleDefinition(
      id: 'goal_king',
      label: 'Gol Kralı',
      priority: 4,
      condition: (p) => p.totalGoalsScored >= 50,
    ),
    TitleDefinition(
      id: 'iron_wall',
      label: 'Demir Duvar',
      priority: 5,
      condition: (p) => p.totalGoalsConceded <= 10 && p.totalMatches >= 10,
    ),
    TitleDefinition(
      id: 'king',
      label: 'Kral',
      priority: 6,
      condition: (p) => p.tournamentsWon >= 3,
    ),
    TitleDefinition(
      id: 'comeback_king',
      label: 'Geri Dönüş Kralı',
      priority: 7,
      condition: (p) =>
          p.totalWins >= 10 &&
          p.totalMatches > 0 &&
          (p.totalWins / p.totalMatches) >= 0.7,
    ),
    TitleDefinition(
      id: 'legend',
      label: 'Efsane',
      priority: 8,
      condition: (p) => p.tournamentsWon >= 5,
    ),
  ];
}
