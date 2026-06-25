// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Competra';

  @override
  String get login => 'Log In';

  @override
  String get register => 'Register';

  @override
  String get continueAsGuest => 'Continue as Guest';

  @override
  String get createTournament => 'Create Tournament';

  @override
  String get joinTournament => 'Join Tournament';

  @override
  String get home => 'Home';

  @override
  String get tournaments => 'Tournaments';

  @override
  String get wheel => 'Wheel';

  @override
  String get friends => 'Friends';

  @override
  String get profile => 'Profile';

  @override
  String get standings => 'Standings';

  @override
  String get fixtures => 'Fixtures';

  @override
  String get statistics => 'Statistics';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'Confirm';

  @override
  String get delete => 'Delete';

  @override
  String get errorGeneric => 'Something went wrong. Please try again.';

  @override
  String get errorNetwork => 'No internet connection.';

  @override
  String get tournamentCompleted => 'Tournament completed';

  @override
  String get champion => 'Champion';

  @override
  String get noDataYet => 'No data yet';

  @override
  String get loading => 'Loading...';

  @override
  String get loginTitle => 'Log In';

  @override
  String get registerTitle => 'Register';

  @override
  String get usernameLabel => 'Username';

  @override
  String get emailLabel => 'Email';

  @override
  String get passwordLabel => 'Password';

  @override
  String get confirmPasswordLabel => 'Confirm Password';

  @override
  String get forgotPassword => 'Forgot Password?';

  @override
  String get orDivider => 'or';

  @override
  String get googleLogin => 'Sign in with Google';

  @override
  String get guestContinue => 'Continue as Guest';

  @override
  String get logoutConfirm => 'Are you sure you want to log out?';

  @override
  String get startTournament => 'Start Tournament';

  @override
  String get formatLeague => 'League';

  @override
  String get formatKnockout => 'Knockout';

  @override
  String get formatGroupKnockout => 'Group + Knockout';

  @override
  String get formatChampionsLeague => 'Champions League';

  @override
  String get statusWaiting => 'Waiting';

  @override
  String get statusActive => 'Active';

  @override
  String get statusCompleted => 'Completed';

  @override
  String get scoreEntryModeAdmin => 'Admin Only';

  @override
  String get scoreEntryModeWinner => 'Winner Enters';

  @override
  String get scoreEntryModeDouble => 'Double Entry';

  @override
  String get matchConfirmTitle => 'Score Confirmation Pending';

  @override
  String get matchDisputeTitle => 'Score Dispute';

  @override
  String get sendRequest => 'Send Request';

  @override
  String get cancelRequest => 'Cancel Request';

  @override
  String get acceptRequest => 'Accept';

  @override
  String get declineRequest => 'Decline';

  @override
  String get friendGroups => 'Friend Groups';

  @override
  String get leaderboard => 'Leaderboard';

  @override
  String get createGroup => 'Create Group';

  @override
  String get joinGroup => 'Join Group';

  @override
  String get edit => 'Edit';

  @override
  String get share => 'Share';

  @override
  String get back => 'Back';

  @override
  String get error => 'Error';

  @override
  String get retry => 'Retry';

  @override
  String get settings => 'Settings';

  @override
  String get notifications => 'Notifications';

  @override
  String get unknownError => 'An unexpected error occurred. Please try again.';

  @override
  String get tournamentFull => 'Tournament is full!';

  @override
  String get tournamentClosed => 'Tournament is closed for joining';

  @override
  String get usernameExists => 'This username is already taken.';

  @override
  String get emailExists => 'This email address is already in use.';

  @override
  String get basicInfo => 'Basic Info';

  @override
  String get tournamentName => 'Tournament Name';

  @override
  String get noteOptional => 'Note (optional)';

  @override
  String get selectFormat => 'Select Format';

  @override
  String get selectFormatSubtitle =>
      'Choose the format that determines how the tournament will work.';

  @override
  String get selectScoreMode => 'Score Entry Mode';

  @override
  String get selectScoreModeSubtitle =>
      'Choose how match scores will be entered.';

  @override
  String get tiebreakerCriteria => 'Standings Criteria';

  @override
  String get tiebreakerSubtitle =>
      'Choose how standings are decided on points tie.';

  @override
  String get formatLeagueDesc => 'Round-robin standings table';

  @override
  String get formatKnockoutDesc => 'Single/double leg brackets';

  @override
  String get formatGroupKnockoutDesc => 'Group stage then knockout';

  @override
  String get formatChampionsLeagueDesc => 'Group + two-leg knockout';

  @override
  String get scoreModeDoubleDesc =>
      'Both players enter score, confirmed when matching';

  @override
  String get scoreModeWinnerDesc => 'Only the winner reports the score';

  @override
  String get scoreModeAdminDesc => 'Only the tournament admin enters scores';

  @override
  String get templateSelectTitle => 'Select Template';

  @override
  String get noTemplatesYet => 'No saved templates yet.';

  @override
  String get failedToLoad => 'Failed to load.';

  @override
  String get saveAsTemplateTitle => 'Save as Template';

  @override
  String get saveAsTemplateDesc =>
      'Would you like to save these settings to reuse in the future?';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get tournamentCreated => 'Tournament created.';

  @override
  String get activeTournamentLimitExceeded =>
      'Active tournament limit reached! Get Competra Pro to continue.';

  @override
  String get tournamentCreateFailed =>
      'Could not create tournament. Please try again.';

  @override
  String get startFromTemplate => 'Start from Template';

  @override
  String stepCountLabel(int current, int total) {
    return 'Step $current of $total';
  }

  @override
  String get tournamentNameRequired => 'Tournament name is required';

  @override
  String tournamentNameMinLength(int min) {
    return 'Must be at least $min characters';
  }

  @override
  String get enterFormatWarning => 'Please select a format.';

  @override
  String get enterScoreModeWarning => 'Please select a score entry mode.';

  @override
  String get summary => 'Summary';

  @override
  String get name => 'Name';

  @override
  String get scoreSystem => 'Score System';

  @override
  String get notSelected => 'Not Selected';

  @override
  String get tiebreakerFifa => 'FIFA Style';

  @override
  String get tiebreakerUefa => 'UEFA Style';

  @override
  String get tiebreakerHybrid => 'Hybrid';

  @override
  String get tiebreakerFifaDesc => 'Overall goal difference first';

  @override
  String get tiebreakerUefaDesc => 'Head-to-head first';

  @override
  String get tiebreakerHybridDesc => 'Overall goal diff + head-to-head';

  @override
  String get basicInfoDesc =>
      'Give your tournament a name and optionally add a short note.';

  @override
  String get tournamentNameHint => 'e.g. Community League 2026';

  @override
  String get noteHint => 'Rules, prizes, or notes about participants...';

  @override
  String get formatLabel => 'Format';

  @override
  String get next => 'Continue';

  @override
  String get language => 'Language';

  @override
  String get appearance => 'Appearance';

  @override
  String get darkTheme => 'Dark Theme';

  @override
  String get darkThemeEnabled => 'Dark appearance active';

  @override
  String get lightThemeEnabled => 'Light appearance active';

  @override
  String get themesAndCosmetics => 'Themes & Cosmetics';

  @override
  String get themesAndCosmeticsDesc => 'Select app theme color and cosmetics';

  @override
  String get general => 'General';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get subscription => 'Subscription';

  @override
  String get proSubscriptionDesc => 'Remove limits and unlock premium';

  @override
  String get account => 'Account';

  @override
  String get signOut => 'Sign Out';

  @override
  String get dangerZone => 'Danger Zone';

  @override
  String get deleteAccount => 'Delete Account';

  @override
  String get deleteAccountDesc => 'All your data will be permanently deleted';

  @override
  String get areYouSure => 'Are you sure?';

  @override
  String get deleteAccountConfirmDesc =>
      'Deleting your account permanently removes all your tournament data, statistics, and badges. This action cannot be undone.';

  @override
  String get enterPassword => 'Enter Password';

  @override
  String get deleteAccountPasswordDesc =>
      'Confirm your password to verify ownership before deletion.';

  @override
  String get deleteAccountFailed =>
      'Failed to delete account. Please try again.';

  @override
  String get deviceLanguage => 'Device Language (Default)';

  @override
  String welcomeMessage(String username) {
    return 'Hello, $username 👋';
  }

  @override
  String get tournamentsLoadFailed => 'Failed to load tournaments.';

  @override
  String get totalMatches => 'Total Matches';

  @override
  String get wins => 'Wins';

  @override
  String get totalGoals => 'Total Goals';

  @override
  String get recentActivity => 'Recent Activity';

  @override
  String get activityLoadFailed => 'Failed to load activities.';

  @override
  String get noActivityYet => 'Your friends\' activity will appear here';

  @override
  String get activeTournaments => 'Active Tournaments';

  @override
  String participantCountLabel(int count) {
    return '$count players';
  }

  @override
  String get noTournamentsYet => 'No tournaments yet';

  @override
  String get noTournamentsYetDesc =>
      'Create your first tournament to start competing with friends.';

  @override
  String get createFirstTournament => 'Create your first tournament';

  @override
  String seasonCountdownLabel(String name, int days) {
    return 'Season: $name — $days days remaining';
  }

  @override
  String get lobbyStatus => 'Waiting lobby';

  @override
  String get ongoingStatus => 'In progress';

  @override
  String get usernameHint => 'Enter your username';

  @override
  String get passwordHint => 'Enter your password';

  @override
  String get usernameRegisterHint => 'Choose a username';

  @override
  String get passwordRegisterHint => 'Choose a password';

  @override
  String get confirmPasswordHint => 'Re-enter your password';

  @override
  String get enterUsernameFirst => 'Enter username first.';

  @override
  String get passwordResetSent => 'Password reset link sent to your email.';
}
