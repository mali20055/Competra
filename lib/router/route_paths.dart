/// Uygulamadaki tüm route yol ve isim sabitleri.
///
/// `path` GoRouter URL'i, `name` ise tip güvenli navigasyon
/// (`context.goNamed(...)`) için kullanılır.
class RoutePaths {
  const RoutePaths._();

  // Onboarding / Auth
  static const String splash = '/';
  static const String splashName = 'splash';

  static const String onboarding = '/onboarding';
  static const String onboardingName = 'onboarding';

  static const String login = '/login';
  static const String loginName = 'login';

  static const String guestWarning = '/guest-warning';
  static const String guestWarningName = 'guest-warning';

  // Bottom navigation sekmeleri
  static const String home = '/home';
  static const String homeName = 'home';

  static const String leagues = '/leagues';
  static const String leaguesName = 'leagues';

  static const String wheel = '/wheel';
  static const String wheelName = 'wheel';

  static const String social = '/social';
  static const String socialName = 'social';

  static const String profile = '/profile';
  static const String profileName = 'profile';

  static const String leaderboard = '/leaderboard';
  static const String leaderboardName = 'leaderboard';

  // Turnuva akışları
  static const String createTournament = '/create-tournament';
  static const String createTournamentName = 'create-tournament';

  static const String joinTournament = '/join-tournament';
  static const String joinTournamentName = 'join-tournament';

  /// Deep link ile katılma — `:code` path parametresi alır
  /// (competra://join/ABC123).
  static const String joinByCode = '/join/:code';
  static const String joinByCodeName = 'join-by-code';

  /// Turnuva detayı — `:id` path parametresi alır.
  static const String tournamentDetail = '/tournament/:id';
  static const String tournamentDetailName = 'tournament-detail';

  /// Turnuva kutlama/özet (wrapped) ekranı — `:id` path parametresi alır.
  static const String tournamentWrapped = '/tournament/:id/wrapped';
  static const String tournamentWrappedName = 'tournament-wrapped';

  static const String notifications = '/notifications';
  static const String notificationsName = 'notifications';

  static const String settings = '/settings';
  static const String settingsName = 'settings';

  static const String premium = '/premium';
  static const String premiumName = 'premium';

  static const String theme = '/theme';
  static const String themeName = 'theme';

  static const String privacyPolicy = '/privacy-policy';
  static const String privacyPolicyName = 'privacy-policy';

  static const String editProfile = '/edit-profile';
  static const String editProfileName = 'edit-profile';

  static const String badgeShowcase = '/badge-showcase';
  static const String badgeShowcaseName = 'badge-showcase';

  /// Arkadaş grubu detayı / sıralama tablosu — `:id` path parametresi alır.
  static const String friendGroup = '/friend-group/:id';
  static const String friendGroupName = 'friend-group';

  /// Oyuncu profili ziyareti — `:uid` path parametresi alır.
  static const String userProfile = '/user/:uid';
  static const String userProfileName = 'user-profile';

  /// Turnuva düzenleme — `:id` path parametresi alır. Yalnızca 'waiting' turnuvalar.
  static const String editTournament = '/tournament/:id/edit';
  static const String editTournamentName = 'tournament-edit';
}
