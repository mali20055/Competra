/// Uygulama geneli sabitler: Firestore koleksiyon adları, limitler ve süreler.
abstract class AppConstants {
  // Firestore koleksiyon adları
  static const String colUsers = 'users';
  static const String colUsernames = 'usernames';
  static const String colTournaments = 'tournaments';
  static const String colMatches = 'matches';
  static const String colParticipants = 'participants';
  static const String colNotifications = 'notifications';
  static const String colFriendships = 'friendships';
  static const String colFriendGroups = 'friendGroups';
  static const String colMembers = 'members';
  static const String colWheels = 'wheels';
  static const String colFeedback = 'feedback';

  // Limitler
  static const int maxWheelResults = 10;
  static const int inviteCodeLength = 6;
  static const int maxBatchSize = 500;
  static const int recentMatchesLimit = 20;
  static const int notificationsLimit = 30;
  static const int leaderboardLimit = 50;
  static const int tournamentsLimit = 20;

  // Süreler
  static const int splashDurationMs = 2600;
}
