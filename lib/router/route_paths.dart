/// Uygulamadaki tüm route yol ve isim sabitleri.
///
/// `path` GoRouter URL'i, `name` ise tip güvenli navigasyon
/// (`context.goNamed(...)`) için kullanılır.
class RoutePaths {
  const RoutePaths._();

  // Onboarding / Auth
  static const String splash = '/';
  static const String splashName = 'splash';

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

  // Turnuva akışları
  static const String createTournament = '/create-tournament';
  static const String createTournamentName = 'create-tournament';

  static const String joinTournament = '/join-tournament';
  static const String joinTournamentName = 'join-tournament';

  /// Turnuva detayı — `:id` path parametresi alır.
  static const String tournamentDetail = '/tournament/:id';
  static const String tournamentDetailName = 'tournament-detail';

  static const String notifications = '/notifications';
  static const String notificationsName = 'notifications';

  static const String settings = '/settings';
  static const String settingsName = 'settings';
}
