/// Turnuva ile ilgili dize (string) sabitleri.
///
/// İstemci/sunucu paritesini korumak için `functions/src/*.ts` ve
/// `lib/models/*.dart` ile AYNI değerleri kullanır. Ekran/repository kodunda
/// elle yazılan dize literal'leri yerine bu sabitler kullanılmalıdır.
library;

/// Turnuva formatları (`tournament.format`).
abstract class TournamentFormats {
  static const String league = 'league';
  static const String knockout = 'knockout';
  static const String groupKnockout = 'groupKnockout';
  static const String championsLeague = 'championsLeague';
}

/// Turnuva durumları (`tournament.status`).
abstract class TournamentStatuses {
  static const String waiting = 'waiting';
  static const String active = 'active';
  static const String completed = 'completed';
}

/// Maç durumları (`match.status`).
abstract class MatchStatuses {
  static const String pending = 'pending';
  static const String awaitingConfirmation = 'awaitingConfirmation';
  static const String disputed = 'disputed';
  static const String completed = 'completed';
}

/// Turnuva fazları (`tournament.currentPhase`).
abstract class TournamentPhases {
  static const String waiting = 'waiting';
  static const String league = 'league';
  static const String group = 'group';
  static const String knockout = 'knockout';
  static const String completed = 'completed';
}

/// Skor giriş sistemleri (`tournament.scoreEntrySystem`).
abstract class ScoreEntryModes {
  static const String adminOnly = 'adminOnly';
  static const String winnerEntry = 'winnerEntry';
  static const String doubleEntry = 'doubleEntry';
}
