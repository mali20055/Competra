import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore'daki `users/{uid}` belgesinin profil model karşılığı.
///
/// Belgede bulunmayan alanlar makul varsayılanlarla doldurulur; böylece yeni
/// veya eksik profiller de sorunsuz gösterilir. İstatistik alanları Backend
/// dokümanındaki şemayla aynı adları taşır (`totalMatches`, `tournamentsWon`…).
class UserProfile {
  const UserProfile({
    required this.uid,
    required this.username,
    required this.bio,
    required this.favoriteTeam,
    required this.photoUrl,
    required this.coverUrl,
    required this.activeTitle,
    required this.totalMatches,
    required this.totalWins,
    required this.totalLosses,
    required this.totalGoalsScored,
    required this.totalGoalsConceded,
    required this.tournamentsPlayed,
    required this.tournamentsWon,
    required this.badges,
    required this.isAnonymous,
  });

  final String uid;
  final String username;
  final String bio;
  final String favoriteTeam;
  final String photoUrl;
  final String coverUrl;
  final String activeTitle;
  final int totalMatches;
  final int totalWins;
  final int totalLosses;
  final int totalGoalsScored;
  final int totalGoalsConceded;
  final int tournamentsPlayed;
  final int tournamentsWon;
  final Set<String> badges;
  final bool isAnonymous;

  // Geriye dönük uyumlu kısa adlar (profil ekranı bunları kullanır).
  int get matches => totalMatches;
  int get wins => totalWins;
  int get goals => totalGoalsScored;
  int get championships => tournamentsWon;

  /// Galibiyet yüzdesi (maç yoksa 0).
  int get winRate =>
      totalMatches > 0 ? ((totalWins / totalMatches) * 100).round() : 0;

  /// Misafir (anonim) kullanıcı için varsayılan profil.
  factory UserProfile.guest(String uid) => UserProfile(
        uid: uid,
        username: 'Misafir',
        bio: '',
        favoriteTeam: '',
        photoUrl: '',
        coverUrl: '',
        activeTitle: '',
        totalMatches: 0,
        totalWins: 0,
        totalLosses: 0,
        totalGoalsScored: 0,
        totalGoalsConceded: 0,
        tournamentsPlayed: 0,
        tournamentsWon: 0,
        badges: const {},
        isAnonymous: true,
      );

  factory UserProfile.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final rawBadges = (data['badges'] as List?) ?? const [];

    int intField(String key) => (data[key] as num?)?.toInt() ?? 0;

    return UserProfile(
      uid: doc.id,
      username: (data['username'] as String?) ?? 'Oyuncu',
      bio: (data['bio'] as String?) ?? '',
      favoriteTeam: (data['favoriteTeam'] as String?) ?? '',
      photoUrl: (data['photoUrl'] as String?) ?? '',
      coverUrl: (data['coverUrl'] as String?) ?? '',
      activeTitle: (data['activeTitle'] as String?) ?? '',
      totalMatches: intField('totalMatches'),
      totalWins: intField('totalWins'),
      totalLosses: intField('totalLosses'),
      totalGoalsScored: intField('totalGoalsScored'),
      totalGoalsConceded: intField('totalGoalsConceded'),
      tournamentsPlayed: intField('tournamentsPlayed'),
      tournamentsWon: intField('tournamentsWon'),
      badges: {for (final b in rawBadges) '$b'},
      isAnonymous: false,
    );
  }
}
