import '../../models/tournament.dart';

/// Turnuva formatının kullanıcıya gösterilecek Türkçe etiketi.
String tournamentFormatLabel(String format) {
  switch (format) {
    case 'league':
      return 'Lig';
    case 'knockout':
      return 'Eleme';
    case 'groupKnockout':
      return 'Grup + Eleme';
    case 'championsLeague':
      return 'Şampiyonlar Ligi';
    default:
      return format;
  }
}

/// Puan eşitliği (tiebreaker) modunun Türkçe etiketi.
String tiebreakerModeLabel(TiebreakerMode mode) {
  switch (mode) {
    case TiebreakerMode.fifa:
      return 'FIFA Stili';
    case TiebreakerMode.uefa:
      return 'UEFA Stili';
    case TiebreakerMode.hybrid:
      return 'Karma';
  }
}
