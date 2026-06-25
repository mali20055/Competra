import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  static final _a = FirebaseAnalytics.instance;

  static Future<void> logTournamentCreated(String format) =>
      _a.logEvent(name: 'tournament_created', parameters: {'format': format});

  static Future<void> logTournamentJoined() =>
      _a.logEvent(name: 'tournament_joined');

  static Future<void> logMatchScoreEntered() =>
      _a.logEvent(name: 'match_score_entered');

  static Future<void> logWheelSpun() => _a.logEvent(name: 'wheel_spin');

  static Future<void> logWrappedViewed() =>
      _a.logEvent(name: 'wrapped_viewed');

  static Future<void> logShareResult() => _a.logEvent(name: 'share_result');

  static Future<void> logInviteSent() => _a.logEvent(name: 'invite_sent');

  static Future<void> setUserId(String uid) => _a.setUserId(id: uid);
}
