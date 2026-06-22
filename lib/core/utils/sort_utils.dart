/// `createdAt` alanına göre azalan (en yeni en üstte) sıralama yardımcısı.
///
/// Tüm repository'lerdeki tekrar eden, null güvenli `createdAt` sıralama
/// bloğunu tekilleştirir. `null` değerler her zaman listenin sonuna düşer.
int compareByCreatedAtDesc(DateTime? a, DateTime? b) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return b.compareTo(a);
}
