import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore'daki `users/{uid}` belgesinin profil model karşılığı.
///
/// Belgede bulunmayan alanlar makul varsayılanlarla doldurulur; böylece yeni
/// veya eksik profiller de sorunsuz gösterilir.
class UserProfile {
  const UserProfile({
    required this.uid,
    required this.username,
    required this.bio,
    required this.favoriteTeam,
    required this.photoUrl,
    required this.coverUrl,
    required this.matches,
    required this.wins,
    required this.goals,
    required this.championships,
    required this.badges,
    required this.isAnonymous,
  });

  final String uid;
  final String username;
  final String bio;
  final String favoriteTeam;
  final String photoUrl;
  final String coverUrl;
  final int matches;
  final int wins;
  final int goals;
  final int championships;
  final Set<String> badges;
  final bool isAnonymous;

  /// Galibiyet yüzdesi (maç yoksa 0).
  int get winRate => matches > 0 ? ((wins / matches) * 100).round() : 0;

  /// Misafir (anonim) kullanıcı için varsayılan profil.
  factory UserProfile.guest(String uid) => UserProfile(
        uid: uid,
        username: 'Misafir',
        bio: '',
        favoriteTeam: '',
        photoUrl: '',
        coverUrl: '',
        matches: 0,
        wins: 0,
        goals: 0,
        championships: 0,
        badges: const {},
        isAnonymous: true,
      );

  factory UserProfile.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final stats = (data['stats'] as Map?) ?? const {};
    final rawBadges = (data['badges'] as List?) ?? const [];

    int statInt(String key) => (stats[key] as num?)?.toInt() ?? 0;

    return UserProfile(
      uid: doc.id,
      username: (data['username'] as String?) ?? 'Oyuncu',
      bio: (data['bio'] as String?) ?? '',
      favoriteTeam: (data['favoriteTeam'] as String?) ?? '',
      photoUrl: (data['photoUrl'] as String?) ?? '',
      coverUrl: (data['coverUrl'] as String?) ?? '',
      matches: statInt('matches'),
      wins: statInt('wins'),
      goals: statInt('goals'),
      championships: statInt('championships'),
      badges: {for (final b in rawBadges) '$b'},
      isAnonymous: false,
    );
  }
}
