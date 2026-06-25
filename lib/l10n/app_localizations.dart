import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_tr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('tr'),
  ];

  /// The application name
  ///
  /// In en, this message translates to:
  /// **'Competra'**
  String get appName;

  /// Login button / screen title
  ///
  /// In en, this message translates to:
  /// **'Log In'**
  String get login;

  /// Register button / screen title
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get register;

  /// Guest sign-in option
  ///
  /// In en, this message translates to:
  /// **'Continue as Guest'**
  String get continueAsGuest;

  /// Create tournament action
  ///
  /// In en, this message translates to:
  /// **'Create Tournament'**
  String get createTournament;

  /// Join tournament action
  ///
  /// In en, this message translates to:
  /// **'Join Tournament'**
  String get joinTournament;

  /// Home tab
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// Tournaments tab/section
  ///
  /// In en, this message translates to:
  /// **'Tournaments'**
  String get tournaments;

  /// Wheel tab
  ///
  /// In en, this message translates to:
  /// **'Wheel'**
  String get wheel;

  /// Friends tab
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get friends;

  /// Profile tab
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// Standings table title
  ///
  /// In en, this message translates to:
  /// **'Standings'**
  String get standings;

  /// Fixtures list title
  ///
  /// In en, this message translates to:
  /// **'Fixtures'**
  String get fixtures;

  /// Statistics section title
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get statistics;

  /// Save action
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Cancel action
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Confirm action
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// Delete action
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Generic error message
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errorGeneric;

  /// Network error message
  ///
  /// In en, this message translates to:
  /// **'No internet connection.'**
  String get errorNetwork;

  /// Tournament finished message
  ///
  /// In en, this message translates to:
  /// **'Tournament completed'**
  String get tournamentCompleted;

  /// Champion label
  ///
  /// In en, this message translates to:
  /// **'Champion'**
  String get champion;

  /// Empty state message
  ///
  /// In en, this message translates to:
  /// **'No data yet'**
  String get noDataYet;

  /// Loading indicator label
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Log In'**
  String get loginTitle;

  /// No description provided for @registerTitle.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get registerTitle;

  /// No description provided for @usernameLabel.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get usernameLabel;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @confirmPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPasswordLabel;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPassword;

  /// No description provided for @orDivider.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get orDivider;

  /// No description provided for @googleLogin.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google'**
  String get googleLogin;

  /// No description provided for @guestContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue as Guest'**
  String get guestContinue;

  /// No description provided for @logoutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to log out?'**
  String get logoutConfirm;

  /// No description provided for @startTournament.
  ///
  /// In en, this message translates to:
  /// **'Start Tournament'**
  String get startTournament;

  /// No description provided for @formatLeague.
  ///
  /// In en, this message translates to:
  /// **'League'**
  String get formatLeague;

  /// No description provided for @formatKnockout.
  ///
  /// In en, this message translates to:
  /// **'Knockout'**
  String get formatKnockout;

  /// No description provided for @formatGroupKnockout.
  ///
  /// In en, this message translates to:
  /// **'Group + Knockout'**
  String get formatGroupKnockout;

  /// No description provided for @formatChampionsLeague.
  ///
  /// In en, this message translates to:
  /// **'Champions League'**
  String get formatChampionsLeague;

  /// No description provided for @statusWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get statusWaiting;

  /// No description provided for @statusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get statusActive;

  /// No description provided for @statusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get statusCompleted;

  /// No description provided for @scoreEntryModeAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admin Only'**
  String get scoreEntryModeAdmin;

  /// No description provided for @scoreEntryModeWinner.
  ///
  /// In en, this message translates to:
  /// **'Winner Enters'**
  String get scoreEntryModeWinner;

  /// No description provided for @scoreEntryModeDouble.
  ///
  /// In en, this message translates to:
  /// **'Double Entry'**
  String get scoreEntryModeDouble;

  /// No description provided for @matchConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Score Confirmation Pending'**
  String get matchConfirmTitle;

  /// No description provided for @matchDisputeTitle.
  ///
  /// In en, this message translates to:
  /// **'Score Dispute'**
  String get matchDisputeTitle;

  /// No description provided for @sendRequest.
  ///
  /// In en, this message translates to:
  /// **'Send Request'**
  String get sendRequest;

  /// No description provided for @cancelRequest.
  ///
  /// In en, this message translates to:
  /// **'Cancel Request'**
  String get cancelRequest;

  /// No description provided for @acceptRequest.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get acceptRequest;

  /// No description provided for @declineRequest.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get declineRequest;

  /// No description provided for @friendGroups.
  ///
  /// In en, this message translates to:
  /// **'Friend Groups'**
  String get friendGroups;

  /// No description provided for @leaderboard.
  ///
  /// In en, this message translates to:
  /// **'Leaderboard'**
  String get leaderboard;

  /// No description provided for @createGroup.
  ///
  /// In en, this message translates to:
  /// **'Create Group'**
  String get createGroup;

  /// No description provided for @joinGroup.
  ///
  /// In en, this message translates to:
  /// **'Join Group'**
  String get joinGroup;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @unknownError.
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred. Please try again.'**
  String get unknownError;

  /// No description provided for @tournamentFull.
  ///
  /// In en, this message translates to:
  /// **'Tournament is full!'**
  String get tournamentFull;

  /// No description provided for @tournamentClosed.
  ///
  /// In en, this message translates to:
  /// **'Tournament is closed for joining'**
  String get tournamentClosed;

  /// No description provided for @usernameExists.
  ///
  /// In en, this message translates to:
  /// **'This username is already taken.'**
  String get usernameExists;

  /// No description provided for @emailExists.
  ///
  /// In en, this message translates to:
  /// **'This email address is already in use.'**
  String get emailExists;

  /// No description provided for @basicInfo.
  ///
  /// In en, this message translates to:
  /// **'Basic Info'**
  String get basicInfo;

  /// No description provided for @tournamentName.
  ///
  /// In en, this message translates to:
  /// **'Tournament Name'**
  String get tournamentName;

  /// No description provided for @noteOptional.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get noteOptional;

  /// No description provided for @selectFormat.
  ///
  /// In en, this message translates to:
  /// **'Select Format'**
  String get selectFormat;

  /// No description provided for @selectFormatSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose the format that determines how the tournament will work.'**
  String get selectFormatSubtitle;

  /// No description provided for @selectScoreMode.
  ///
  /// In en, this message translates to:
  /// **'Score Entry Mode'**
  String get selectScoreMode;

  /// No description provided for @selectScoreModeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose how match scores will be entered.'**
  String get selectScoreModeSubtitle;

  /// No description provided for @tiebreakerCriteria.
  ///
  /// In en, this message translates to:
  /// **'Standings Criteria'**
  String get tiebreakerCriteria;

  /// No description provided for @tiebreakerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose how standings are decided on points tie.'**
  String get tiebreakerSubtitle;

  /// No description provided for @formatLeagueDesc.
  ///
  /// In en, this message translates to:
  /// **'Round-robin standings table'**
  String get formatLeagueDesc;

  /// No description provided for @formatKnockoutDesc.
  ///
  /// In en, this message translates to:
  /// **'Single/double leg brackets'**
  String get formatKnockoutDesc;

  /// No description provided for @formatGroupKnockoutDesc.
  ///
  /// In en, this message translates to:
  /// **'Group stage then knockout'**
  String get formatGroupKnockoutDesc;

  /// No description provided for @formatChampionsLeagueDesc.
  ///
  /// In en, this message translates to:
  /// **'Group + two-leg knockout'**
  String get formatChampionsLeagueDesc;

  /// No description provided for @scoreModeDoubleDesc.
  ///
  /// In en, this message translates to:
  /// **'Both players enter score, confirmed when matching'**
  String get scoreModeDoubleDesc;

  /// No description provided for @scoreModeWinnerDesc.
  ///
  /// In en, this message translates to:
  /// **'Only the winner reports the score'**
  String get scoreModeWinnerDesc;

  /// No description provided for @scoreModeAdminDesc.
  ///
  /// In en, this message translates to:
  /// **'Only the tournament admin enters scores'**
  String get scoreModeAdminDesc;

  /// No description provided for @templateSelectTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Template'**
  String get templateSelectTitle;

  /// No description provided for @noTemplatesYet.
  ///
  /// In en, this message translates to:
  /// **'No saved templates yet.'**
  String get noTemplatesYet;

  /// No description provided for @failedToLoad.
  ///
  /// In en, this message translates to:
  /// **'Failed to load.'**
  String get failedToLoad;

  /// No description provided for @saveAsTemplateTitle.
  ///
  /// In en, this message translates to:
  /// **'Save as Template'**
  String get saveAsTemplateTitle;

  /// No description provided for @saveAsTemplateDesc.
  ///
  /// In en, this message translates to:
  /// **'Would you like to save these settings to reuse in the future?'**
  String get saveAsTemplateDesc;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @tournamentCreated.
  ///
  /// In en, this message translates to:
  /// **'Tournament created.'**
  String get tournamentCreated;

  /// No description provided for @activeTournamentLimitExceeded.
  ///
  /// In en, this message translates to:
  /// **'Active tournament limit reached! Get Competra Pro to continue.'**
  String get activeTournamentLimitExceeded;

  /// No description provided for @tournamentCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not create tournament. Please try again.'**
  String get tournamentCreateFailed;

  /// No description provided for @startFromTemplate.
  ///
  /// In en, this message translates to:
  /// **'Start from Template'**
  String get startFromTemplate;

  /// No description provided for @stepCountLabel.
  ///
  /// In en, this message translates to:
  /// **'Step {current} of {total}'**
  String stepCountLabel(int current, int total);

  /// No description provided for @tournamentNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Tournament name is required'**
  String get tournamentNameRequired;

  /// No description provided for @tournamentNameMinLength.
  ///
  /// In en, this message translates to:
  /// **'Must be at least {min} characters'**
  String tournamentNameMinLength(int min);

  /// No description provided for @enterFormatWarning.
  ///
  /// In en, this message translates to:
  /// **'Please select a format.'**
  String get enterFormatWarning;

  /// No description provided for @enterScoreModeWarning.
  ///
  /// In en, this message translates to:
  /// **'Please select a score entry mode.'**
  String get enterScoreModeWarning;

  /// No description provided for @summary.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get summary;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @scoreSystem.
  ///
  /// In en, this message translates to:
  /// **'Score System'**
  String get scoreSystem;

  /// No description provided for @notSelected.
  ///
  /// In en, this message translates to:
  /// **'Not Selected'**
  String get notSelected;

  /// No description provided for @tiebreakerFifa.
  ///
  /// In en, this message translates to:
  /// **'FIFA Style'**
  String get tiebreakerFifa;

  /// No description provided for @tiebreakerUefa.
  ///
  /// In en, this message translates to:
  /// **'UEFA Style'**
  String get tiebreakerUefa;

  /// No description provided for @tiebreakerHybrid.
  ///
  /// In en, this message translates to:
  /// **'Hybrid'**
  String get tiebreakerHybrid;

  /// No description provided for @tiebreakerFifaDesc.
  ///
  /// In en, this message translates to:
  /// **'Overall goal difference first'**
  String get tiebreakerFifaDesc;

  /// No description provided for @tiebreakerUefaDesc.
  ///
  /// In en, this message translates to:
  /// **'Head-to-head first'**
  String get tiebreakerUefaDesc;

  /// No description provided for @tiebreakerHybridDesc.
  ///
  /// In en, this message translates to:
  /// **'Overall goal diff + head-to-head'**
  String get tiebreakerHybridDesc;

  /// No description provided for @basicInfoDesc.
  ///
  /// In en, this message translates to:
  /// **'Give your tournament a name and optionally add a short note.'**
  String get basicInfoDesc;

  /// No description provided for @tournamentNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Community League 2026'**
  String get tournamentNameHint;

  /// No description provided for @noteHint.
  ///
  /// In en, this message translates to:
  /// **'Rules, prizes, or notes about participants...'**
  String get noteHint;

  /// No description provided for @formatLabel.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get formatLabel;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get next;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @darkTheme.
  ///
  /// In en, this message translates to:
  /// **'Dark Theme'**
  String get darkTheme;

  /// No description provided for @darkThemeEnabled.
  ///
  /// In en, this message translates to:
  /// **'Dark appearance active'**
  String get darkThemeEnabled;

  /// No description provided for @lightThemeEnabled.
  ///
  /// In en, this message translates to:
  /// **'Light appearance active'**
  String get lightThemeEnabled;

  /// No description provided for @themesAndCosmetics.
  ///
  /// In en, this message translates to:
  /// **'Themes & Cosmetics'**
  String get themesAndCosmetics;

  /// No description provided for @themesAndCosmeticsDesc.
  ///
  /// In en, this message translates to:
  /// **'Select app theme color and cosmetics'**
  String get themesAndCosmeticsDesc;

  /// No description provided for @general.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get general;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @subscription.
  ///
  /// In en, this message translates to:
  /// **'Subscription'**
  String get subscription;

  /// No description provided for @proSubscriptionDesc.
  ///
  /// In en, this message translates to:
  /// **'Remove limits and unlock premium'**
  String get proSubscriptionDesc;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOut;

  /// No description provided for @dangerZone.
  ///
  /// In en, this message translates to:
  /// **'Danger Zone'**
  String get dangerZone;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccount;

  /// No description provided for @deleteAccountDesc.
  ///
  /// In en, this message translates to:
  /// **'All your data will be permanently deleted'**
  String get deleteAccountDesc;

  /// No description provided for @areYouSure.
  ///
  /// In en, this message translates to:
  /// **'Are you sure?'**
  String get areYouSure;

  /// No description provided for @deleteAccountConfirmDesc.
  ///
  /// In en, this message translates to:
  /// **'Deleting your account permanently removes all your tournament data, statistics, and badges. This action cannot be undone.'**
  String get deleteAccountConfirmDesc;

  /// No description provided for @enterPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter Password'**
  String get enterPassword;

  /// No description provided for @deleteAccountPasswordDesc.
  ///
  /// In en, this message translates to:
  /// **'Confirm your password to verify ownership before deletion.'**
  String get deleteAccountPasswordDesc;

  /// No description provided for @deleteAccountFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete account. Please try again.'**
  String get deleteAccountFailed;

  /// No description provided for @deviceLanguage.
  ///
  /// In en, this message translates to:
  /// **'Device Language (Default)'**
  String get deviceLanguage;

  /// No description provided for @welcomeMessage.
  ///
  /// In en, this message translates to:
  /// **'Hello, {username} 👋'**
  String welcomeMessage(String username);

  /// No description provided for @tournamentsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load tournaments.'**
  String get tournamentsLoadFailed;

  /// No description provided for @totalMatches.
  ///
  /// In en, this message translates to:
  /// **'Total Matches'**
  String get totalMatches;

  /// No description provided for @wins.
  ///
  /// In en, this message translates to:
  /// **'Wins'**
  String get wins;

  /// No description provided for @totalGoals.
  ///
  /// In en, this message translates to:
  /// **'Total Goals'**
  String get totalGoals;

  /// No description provided for @recentActivity.
  ///
  /// In en, this message translates to:
  /// **'Recent Activity'**
  String get recentActivity;

  /// No description provided for @activityLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load activities.'**
  String get activityLoadFailed;

  /// No description provided for @noActivityYet.
  ///
  /// In en, this message translates to:
  /// **'Your friends\' activity will appear here'**
  String get noActivityYet;

  /// No description provided for @activeTournaments.
  ///
  /// In en, this message translates to:
  /// **'Active Tournaments'**
  String get activeTournaments;

  /// No description provided for @participantCountLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} players'**
  String participantCountLabel(int count);

  /// No description provided for @noTournamentsYet.
  ///
  /// In en, this message translates to:
  /// **'No tournaments yet'**
  String get noTournamentsYet;

  /// No description provided for @noTournamentsYetDesc.
  ///
  /// In en, this message translates to:
  /// **'Create your first tournament to start competing with friends.'**
  String get noTournamentsYetDesc;

  /// No description provided for @createFirstTournament.
  ///
  /// In en, this message translates to:
  /// **'Create your first tournament'**
  String get createFirstTournament;

  /// No description provided for @seasonCountdownLabel.
  ///
  /// In en, this message translates to:
  /// **'Season: {name} — {days} days remaining'**
  String seasonCountdownLabel(String name, int days);

  /// No description provided for @lobbyStatus.
  ///
  /// In en, this message translates to:
  /// **'Waiting lobby'**
  String get lobbyStatus;

  /// No description provided for @ongoingStatus.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get ongoingStatus;

  /// No description provided for @usernameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your username'**
  String get usernameHint;

  /// No description provided for @passwordHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get passwordHint;

  /// No description provided for @usernameRegisterHint.
  ///
  /// In en, this message translates to:
  /// **'Choose a username'**
  String get usernameRegisterHint;

  /// No description provided for @passwordRegisterHint.
  ///
  /// In en, this message translates to:
  /// **'Choose a password'**
  String get passwordRegisterHint;

  /// No description provided for @confirmPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Re-enter your password'**
  String get confirmPasswordHint;

  /// No description provided for @enterUsernameFirst.
  ///
  /// In en, this message translates to:
  /// **'Enter username first.'**
  String get enterUsernameFirst;

  /// No description provided for @passwordResetSent.
  ///
  /// In en, this message translates to:
  /// **'Password reset link sent to your email.'**
  String get passwordResetSent;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'tr':
      return AppLocalizationsTr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
