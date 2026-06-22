/// Bildirim tipi (`notification.type`) dize sabitleri.
///
/// `firestore.rules` ve `functions/src/index.ts` ile aynı değerleri kullanır.
abstract class NotificationTypes {
  static const String friendRequest = 'friendRequest';
  static const String matchConfirm = 'matchConfirm';
  static const String tournamentComplete = 'tournamentComplete';
  static const String generic = 'generic';
}
