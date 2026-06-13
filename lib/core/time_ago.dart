/// Verilen zamandan bu yana geçen süreyi Türkçe, kısa biçimde döner.
///
/// Örn: "az önce", "5 dk önce", "3 sa önce", "2 gün önce", "4 hafta önce".
/// [from] verilmezse `null` durumunda boş dize döner.
String timeAgoTr(DateTime? from) {
  if (from == null) return '';
  final diff = DateTime.now().difference(from);

  if (diff.isNegative) return 'az önce';
  if (diff.inMinutes < 1) return 'az önce';
  if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
  if (diff.inHours < 24) return '${diff.inHours} sa önce';
  if (diff.inDays < 7) return '${diff.inDays} gün önce';
  if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} hafta önce';
  if (diff.inDays < 365) return '${(diff.inDays / 30).floor()} ay önce';
  return '${(diff.inDays / 365).floor()} yıl önce';
}
