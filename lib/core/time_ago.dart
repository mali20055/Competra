/// Verilen zamandan bu yana geçen süreyi locale duyarlı, kısa biçimde döner.
///
/// Örn: "az önce", "5 dk önce", "3 sa önce", "2 gün önce", "4 hafta önce".
/// English: "just now", "5m ago", "3h ago", "2d ago", "4w ago".
/// [from] verilmezse `null` durumunda boş dize döner.
String timeAgo(DateTime? from, String languageCode) {
  if (from == null) return '';
  final diff = DateTime.now().difference(from);
  final bool isEn = languageCode == 'en';

  if (diff.isNegative) return isEn ? 'just now' : 'az önce';
  if (diff.inMinutes < 1) return isEn ? 'just now' : 'az önce';
  if (diff.inMinutes < 60) return isEn ? '${diff.inMinutes}m ago' : '${diff.inMinutes} dk önce';
  if (diff.inHours < 24) return isEn ? '${diff.inHours}h ago' : '${diff.inHours} sa önce';
  if (diff.inDays < 7) return isEn ? '${diff.inDays}d ago' : '${diff.inDays} gün önce';
  if (diff.inDays < 30) return isEn ? '${(diff.inDays / 7).floor()}w ago' : '${(diff.inDays / 7).floor()} hafta önce';
  if (diff.inDays < 365) return isEn ? '${(diff.inDays / 30).floor()}mo ago' : '${(diff.inDays / 30).floor()} ay önce';
  return isEn ? '${(diff.inDays / 365).floor()}y ago' : '${(diff.inDays / 365).floor()} yıl önce';
}

/// Geriye dönük uyumluluk için Türkçe göreli zaman dönen helper.
String timeAgoTr(DateTime? from) {
  return timeAgo(from, 'tr');
}
