import '../../models/tournament.dart';
import '../../l10n/app_localizations.dart';

/// Turnuva formatının kullanıcıya gösterilecek locale duyarlı etiketi.
String tournamentFormatLabel(String format, AppLocalizations l10n) {
  switch (format) {
    case 'league':
      return l10n.formatLeague;
    case 'knockout':
      return l10n.formatKnockout;
    case 'groupKnockout':
      return l10n.formatGroupKnockout;
    case 'championsLeague':
      return l10n.formatChampionsLeague;
    default:
      return format;
  }
}

/// Puan eşitliği (tiebreaker) modunun locale duyarlı etiketi.
String tiebreakerModeLabel(TiebreakerMode mode, AppLocalizations l10n) {
  switch (mode) {
    case TiebreakerMode.fifa:
      return l10n.tiebreakerFifa;
    case TiebreakerMode.uefa:
      return l10n.tiebreakerUefa;
    case TiebreakerMode.hybrid:
      return l10n.tiebreakerHybrid;
  }
}
