import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../components/scaffold_with_nav_bar.dart';
import '../screens/auth/guest_warning_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/leaderboard/leaderboard_screen.dart';
import '../screens/leagues/leagues_screen.dart';
import '../screens/notifications/notifications_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/profile/edit_profile_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/profile/user_profile_screen.dart';
import '../screens/settings/privacy_policy_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/social/friend_group_screen.dart';
import '../screens/social/social_screen.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/tournament/create_tournament_screen.dart';
import '../screens/tournament/join_tournament_screen.dart';
import '../screens/tournament/tournament_detail_screen.dart';
import '../screens/tournament/tournament_wrapped_screen.dart';
import '../screens/wheel/wheel_screen.dart';
import 'route_paths.dart';

/// Uygulamanın tek [GoRouter] örneği.
///
/// Bottom navigation, her sekmenin durumunu koruyan
/// [StatefulShellRoute.indexedStack] ile kurulmuştur.
class AppRouter {
  const AppRouter._();

  static final GlobalKey<NavigatorState> _rootKey =
      GlobalKey<NavigatorState>(debugLabel: 'root');

  static final GoRouter router = GoRouter(
    navigatorKey: _rootKey,
    initialLocation: RoutePaths.splash,
    debugLogDiagnostics: true,
    // Özel şema deep link'lerini (competra://join/ABC123) iç route'a eşler.
    // Normal gezinmede host boş olduğundan null döner ve hiçbir etkisi olmaz.
    redirect: (context, state) {
      final uri = state.uri;
      String? code;
      if (uri.host == 'join' && uri.pathSegments.isNotEmpty) {
        // competra://join/ABC123  → host=join, ilk segment = kod
        code = uri.pathSegments.first;
      } else if (uri.pathSegments.length >= 2 &&
          uri.pathSegments.first == 'join') {
        // /join/ABC123 biçiminde gelirse
        code = uri.pathSegments[1];
      }
      if (code != null && code.isNotEmpty) {
        return '/join/$code';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: RoutePaths.splash,
        name: RoutePaths.splashName,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: RoutePaths.onboarding,
        name: RoutePaths.onboardingName,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: RoutePaths.login,
        name: RoutePaths.loginName,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: RoutePaths.guestWarning,
        name: RoutePaths.guestWarningName,
        builder: (context, state) => const GuestWarningScreen(),
      ),

      // Bottom navigation kabuğu
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            ScaffoldWithNavBar(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.home,
                name: RoutePaths.homeName,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.leagues,
                name: RoutePaths.leaguesName,
                builder: (context, state) => const LeaguesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.wheel,
                name: RoutePaths.wheelName,
                builder: (context, state) => const WheelScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.social,
                name: RoutePaths.socialName,
                builder: (context, state) => const SocialScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.profile,
                name: RoutePaths.profileName,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      // Turnuva akışları (kabuk dışında, tam ekran)
      GoRoute(
        path: RoutePaths.createTournament,
        name: RoutePaths.createTournamentName,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const CreateTournamentScreen(),
      ),
      GoRoute(
        path: RoutePaths.joinTournament,
        name: RoutePaths.joinTournamentName,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const JoinTournamentScreen(),
      ),
      GoRoute(
        path: RoutePaths.joinByCode,
        name: RoutePaths.joinByCodeName,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => JoinTournamentScreen(
          initialCode: state.pathParameters['code'],
        ),
      ),
      GoRoute(
        path: RoutePaths.tournamentDetail,
        name: RoutePaths.tournamentDetailName,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => TournamentDetailScreen(
          tournamentId: state.pathParameters['id'] ?? '',
        ),
      ),
      GoRoute(
        path: RoutePaths.tournamentWrapped,
        name: RoutePaths.tournamentWrappedName,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => TournamentWrappedScreen(
          tournamentId: state.pathParameters['id'] ?? '',
        ),
      ),
      GoRoute(
        path: RoutePaths.leaderboard,
        name: RoutePaths.leaderboardName,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const LeaderboardScreen(),
      ),
      GoRoute(
        path: RoutePaths.notifications,
        name: RoutePaths.notificationsName,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: RoutePaths.settings,
        name: RoutePaths.settingsName,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: RoutePaths.privacyPolicy,
        name: RoutePaths.privacyPolicyName,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const PrivacyPolicyScreen(),
      ),
      GoRoute(
        path: RoutePaths.editProfile,
        name: RoutePaths.editProfileName,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: RoutePaths.friendGroup,
        name: RoutePaths.friendGroupName,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => FriendGroupScreen(
          groupId: state.pathParameters['id'] ?? '',
          groupName: state.extra is String ? state.extra as String : null,
        ),
      ),
      GoRoute(
        path: RoutePaths.userProfile,
        name: RoutePaths.userProfileName,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => UserProfileScreen(
          uid: state.pathParameters['uid'] ?? '',
        ),
      ),
    ],
  );
}
