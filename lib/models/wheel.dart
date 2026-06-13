import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore'daki `wheels/{id}` belgesinin model karşılığı.
///
/// Bir çark, bir ada ve üzerinde yazan takım/seçenek listesine sahiptir.
class Wheel {
  const Wheel({
    required this.id,
    required this.name,
    required this.teams,
    required this.createdAt,
  });

  final String id;
  final String name;
  final List<String> teams;
  final DateTime? createdAt;

  factory Wheel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final rawTeams = (data['teams'] as List?) ?? const [];
    return Wheel(
      id: doc.id,
      name: (data['name'] as String?) ?? 'Çark',
      teams: [for (final t in rawTeams) '$t'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// Yeni çark oluştururken hazır takım listesi sunan lig ön ayarları.
class LeaguePresets {
  const LeaguePresets._();

  static const Map<String, List<String>> all = {
    'Premier League': [
      'Arsenal',
      'Aston Villa',
      'AFC Bournemouth',
      'Brentford',
      'Brighton',
      'Chelsea',
      'Coventry City',
      'Crystal Palace',
      'Everton',
      'Fulham',
      'Hull City',
      'Ipswich Town',
      'Leeds United',
      'Liverpool',
      'Manchester City',
      'Manchester United',
      'Newcastle United',
      'Nottingham Forest',
      'Sunderland',
      'Tottenham',
    ],
    'La Liga': [
      'Barcelona',
      'Real Madrid',
      'Villarreal',
      'Atletico Madrid',
      'Real Betis',
      'Celta Vigo',
      'Getafe',
      'Rayo Vallecano',
      'Valencia',
      'Real Sociedad',
      'Espanyol',
      'Athletic Bilbao',
      'Sevilla',
      'Alaves',
      'Elche',
      'Levante',
      'Osasuna',
      'Racing Santander',
      'Deportivo La Coruña',
    ],
    'Bundesliga': [
      'Bayern München',
      'Borussia Dortmund',
      'RB Leipzig',
      'VfB Stuttgart',
      'Hoffenheim',
      'Bayer Leverkusen',
      'SC Freiburg',
      'Eintracht Frankfurt',
      'Augsburg',
      'Mainz 05',
      'Union Berlin',
      'Borussia Mönchengladbach',
      'Hamburger SV',
      '1. FC Köln',
      'Werder Bremen',
      'Schalke 04',
      'SV 07 Elversberg',
      'SC Paderborn',
    ],
    'Serie A': [
      'Inter Milan',
      'Napoli',
      'AC Milan',
      'Roma',
      'Como',
      'Juventus',
      'Atalanta',
      'Bologna',
      'Lazio',
      'Udinese',
      'Sassuolo',
      'Torino',
      'Parma',
      'Genoa',
      'Fiorentina',
      'Cagliari',
      'Venezia',
      'Frosinone',
      'Lecce',
      'Monza',
    ],
    'Ligue 1': [
      'Auxerre',
      'Angers',
      'Monaco',
      'Troyes',
      'Lorient',
      'Le Havre',
      'Le Mans FC',
      'Lille',
      'Nice',
      'Lyon',
      'Marseille',
      'Paris FC',
      'PSG',
      'Lens',
      'Brest',
      'Rennes',
      'RC Strasbourg',
      'Toulouse',
    ],
    'Süper Lig': [
      'Galatasaray',
      'Fenerbahçe',
      'Trabzonspor',
      'Beşiktaş',
      'İstanbul Başakşehir',
      'Göztepe',
      'Samsunspor',
      'Çaykur Rizespor',
      'Konyaspor',
      'Kocaelispor',
      'Alanyaspor',
      'Gaziantep FK',
      'Kasımpaşa',
      'Gençlerbirliği',
      'Eyüpspor',
      'Erzurumspor FK',
      'Çorum FK',
    ],
  };
}
