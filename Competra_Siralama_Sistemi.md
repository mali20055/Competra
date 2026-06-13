# Competra — Fikstür, Sıralama ve Averaj Sistemi

Bu doküman Competra uygulamasındaki tüm turnuva formatlarının kurallarını,
fikstür oluşturma algoritmalarını ve puan tablosu sıralama kriterlerini açıklar.
Claude Code bu dokümanı referans alarak ilgili Dart kodunu yazmalıdır.

---

## 1. Turnuva Formatları

Competra'da 4 turnuva formatı vardır. Her format farklı fikstür algoritması ve
sıralama mantığı kullanır.

---

### 1.1 Lig Formatı (League)

**Nasıl çalışır:**
Her katılımcı diğer tüm katılımcılarla birer kez karşılaşır.
N oyunculu bir ligde toplam maç sayısı: N × (N-1) / 2

**Örnek (4 kişi):**
- Toplam maç: 4 × 3 / 2 = 6 maç
- A-B, A-C, A-D, B-C, B-D, C-D

**Fikstür algoritması — Round Robin:**
1. Oyuncular listesi al (N kişi)
2. N tekse sona bir "bye" (boş) oyuncu ekle → N çift olur
3. İlk oyuncu sabit, diğerleri her turda bir sola döner
4. Her turda N/2 maç çifti oluşur
5. T = N-1 tur (bye varsa N tur) sonunda herkes herkesle oynamış olur

**Tur sayısı:** N-1 (N çift ise), N (N tek ise)

**Puan sistemi:**
- Galibiyet: 3 puan
- Beraberlik: 1 puan
- Mağlubiyet: 0 puan

**Sıralama:** Puan tablosu (bkz. Bölüm 3)

---

### 1.2 Eleme Formatı (Knockout / Cup)

**Nasıl çalışır:**
Tek maç eleme. Her turda kaybeden elenir, kazanan bir sonraki tura geçer.
Final kazananı şampiyon olur.

**Fikstür algoritması:**
1. Katılımcılar rastgele karıştırılır (shuffle)
2. Çiftler sırayla eşleştirilir: (1-2), (3-4), (5-6)...
3. Katılımcı sayısı 2'nin kuvveti değilse (örn. 6 kişi):
   - İlk turda bazı oyuncular "bye" alır (direkt tur atlar)
   - Bye sayısı = (sonraki 2'nin kuvveti) - N
   - Örn. 6 kişi → 8'e tamamlamak için 2 bye
4. Kazananlar bracket'te yukarı çıkar

**Tur isimleri (katılımcıya göre):**
- 2 kişi: Final
- 4 kişi: Yarı Final → Final
- 8 kişi: Çeyrek Final → Yarı Final → Final
- 16 kişi: Son 16 → Çeyrek Final → Yarı Final → Final

**Puan sistemi:** Yok — sadece kazanan/kaybeden

**Sıralama:** Bracket ağacı

---

### 1.3 Grup + Eleme Formatı (Group + Knockout)

**Nasıl çalışır:**
İki aşamalı format.

**Aşama 1 — Grup Aşaması:**
- Katılımcılar gruplara eşit dağıtılır (tercihen 3-4 kişilik)
- Grup sayısı hesabı: ceil(N / 4) — 4'ten fazla olmasın
- Her grup kendi içinde round-robin oynuyor (bkz. 1.1)
- Her gruptan ilk 2 kişi eleme aşamasına geçer

**Aşama 2 — Eleme Aşaması:**
- Gruplardan çıkan oyuncular bracket'e yerleşir
- A grubu 1. → B grubu 2. ile eşleşir (çapraz eşleşme)
- Standart eleme algoritması devam eder

**Örnek (8 kişi, 2 grup):**
```
Grup A: A1, A2, A3, A4  →  A1, A2 çıkar
Grup B: B1, B2, B3, B4  →  B1, B2 çıkar

Yarı Final: A1 vs B2 | B1 vs A2
Final: Kazanan vs Kazanan
```

**Puan sistemi:** Grup aşamasında lig puanı, elemede kazanan/kaybeden

---

### 1.4 Şampiyonlar Ligi Formatı (Champions League)

**Nasıl çalışır:**
UEFA Şampiyonlar Ligi'nin arkadaş grubu uyarlaması. İki aşamalı.

**Aşama 1 — Lig Fazı:**
- Herkes aynı havuzda, ama herkes herkesle oynamaz
- Her oyuncu belirli sayıda rakiple oynuyor:
  - 8 oyuncuya kadar: herkes 4 farklı rakiple (toplam N×2 maç)
  - 8+ oyuncuda: herkes ceil(N/2) rakiple
- Eşleşmeler rastgele ama dengeli dağıtılır (kimse aynı kişiyle 2 kez oynamaz)
- Lig fazı sonunda tüm oyuncular puana göre sıralanır
- İlk 8 (veya N/2, hangisi küçükse) eleme aşamasına geçer

**Aşama 2 — Eleme Aşaması:**
- 1. sıra vs 8. sıra, 2. sıra vs 7. sıra şeklinde çapraz eşleşme
- Standart tek maç eleme devam eder

**Puan sistemi:** Lig fazında 3/1/0, elemede kazanan/kaybeden

---

## 2. Puan Tablosu Kolonları

Puan tablosunda her oyuncu için şu değerler gösterilir:

| Kolon | Açıklama |
|-------|----------|
| O | Oynanan maç sayısı |
| G | Galibiyet |
| B | Beraberlik |
| M | Mağlubiyet |
| AG | Atılan gol (Goals For) |
| YG | Yenilen gol (Goals Against) |
| A | Averaj (hesaplama yöntemine göre değişir) |
| P | Puan (G×3 + B×1) |

---

## 3. Sıralama Kriterleri ve Averaj Sistemi

### 3.1 Temel Sıralama

Tüm formatlarda önce **puan** esastır.
Puan eşitliğinde averaj/tiebreaker devreye girer.

---

### 3.2 Averaj Türleri — Admin Seçimi

**Admin turnuva oluştururken averaj türünü seçer.**
Bu seçim sıralama kriterlerinin sırasını belirler.

Competra'da 3 averaj modu vardır:

---

#### MOD A — Genel Averaj (FIFA / Premier League stili)

Gerçek dünya karşılığı: Premier League, Bundesliga, Ligue 1

**Sıralama sırası:**
1. Puan (yüksek olan üstte)
2. Genel Averaj = Atılan Gol − Yenilen Gol (tüm maçlar)
3. Atılan Gol (yüksek olan üstte)
4. İkili Averaj (hâlâ eşitse, sadece iki oyuncu arasındaki maç/maçlar)
5. Kura (rastgele)

**Hesaplama örneği:**
```
Oyuncu A: 3G 2M, 10 gol attı, 6 yedi → Averaj: +4
Oyuncu B: 3G 2M, 8 gol attı, 5 yedi → Averaj: +3
Sonuç: A > B (averaj farkıyla)
```

**Ne zaman tercih edilir:**
Gol atmayı ödüllendirmek, savunmacı oynamayı caydırmak istiyorsan.

---

#### MOD B — İkili Averaj Önce (UEFA / La Liga / Serie A stili)

Gerçek dünya karşılığı: La Liga, Serie A, UEFA Şampiyonlar Ligi grup aşaması

**Sıralama sırası:**
1. Puan
2. İkili Puan = Sadece eşit puanlı oyuncular arasındaki maçlardan elde edilen puan
3. İkili Averaj = Sadece eşit puanlı oyuncular arasındaki maçlardaki gol farkı
4. İkili Atılan Gol = Eşit puanlı oyuncular arasındaki maçlarda atılan gol
5. Genel Averaj (tüm maçlar)
6. Genel Atılan Gol
7. Kura

**Önemli detay — 3+ oyuncu eşit puandaysa:**
UEFA kuralına göre sadece o oyuncular arasındaki maçlardan
yeni bir mini-tablo oluşturulur ve sıralama bu mini-tabloya göre yapılır.

**Hesaplama örneği:**
```
A, B, C eşit puanda.
A-B: 2-1 (A kazandı)
A-C: 0-1 (C kazandı)  
B-C: 1-1 (beraberlik)

Mini-tablo:
A: 1G 0B 1M → 3 puan, averaj: +1
C: 1G 0B 1M → 3 puan, averaj: 0
B: 0G 1B 1M → 1 puan

Sıra: A > C > B
```

**Ne zaman tercih edilir:**
Doğrudan karşılaşmanın daha belirleyici olmasını istiyorsan.
Arkadaş gruplarında "beni yenen üstte olsun" mantığı için ideal.

---

#### MOD C — Karma (Genel Averaj + İkili Tiebreaker)

**Sıralama sırası:**
1. Puan
2. Genel Averaj
3. Genel Atılan Gol
4. İkili Averaj (hâlâ eşitse)
5. İkili Atılan Gol
6. Kura

**Ne zaman tercih edilir:**
İkisinin ortası. Genel performansı önceliklendir, ama
genel averaj da eşitse ikili sonuca bak.

---

### 3.3 Özet Karşılaştırma Tablosu

| Kriter | MOD A (FIFA) | MOD B (UEFA) | MOD C (Karma) |
|--------|-------------|-------------|--------------|
| 1. | Puan | Puan | Puan |
| 2. | Genel Averaj | İkili Puan | Genel Averaj |
| 3. | Genel AG | İkili Averaj | Genel AG |
| 4. | İkili Averaj | İkili AG | İkili Averaj |
| 5. | Kura | Genel Averaj | İkili AG |
| 6. | — | Genel AG | Kura |
| 7. | — | Kura | — |

---

### 3.4 Averaj Hesaplama Formülleri

```dart
// Genel averaj
int genelAveraj = toplamAtılanGol - toplamYenilenGol;

// İkili averaj (sadece iki oyuncu arasındaki maçlar)
int ikiliAveraj = ikiliAtılanGol - ikiliYenilenGol;

// İkili puan (iki oyuncu arasındaki maçlardan puan)
int ikiliPuan = ikiliGalibiyet * 3 + ikiliBeraberlik * 1;

// Gol ortalaması (eski yöntem, artık kullanılmıyor)
// double golOrtalaması = atılanGol / yenilenGol; // KULLANMA
```

**Not:** Eski "gol ortalaması" (atılan/yenilen) 1970 öncesi kullanılırdı.
Savunmacı oyunu teşvik ettiği için terk edildi. Competra'da kullanılmaz.

---

## 4. Uygulama — Dart Kod Gereksinimleri

### 4.1 Veri Modeli Gereksinimleri

Tournament modeline şu alanlar eklenmelidir:

```dart
// Turnuva oluşturma ekranında admin seçer
enum TiebreakerMode {
  fifa,    // MOD A — Genel averaj önce
  uefa,    // MOD B — İkili averaj önce  
  hybrid,  // MOD C — Karma
}

// Tournament modeline eklenecek
TiebreakerMode tiebreakerMode; // default: fifa
```

Firestore'da `tiebreakerMode` string olarak saklanır:
`'fifa'` | `'uefa'` | `'hybrid'`

---

### 4.2 Sıralama Algoritması Gereksinimleri

`computeStandings()` fonksiyonu `tiebreakerMode` parametresi almalı:

```dart
List<StandingRow> computeStandings(
  List<TournamentMatch> matches,
  List<String> participantIds,
  TiebreakerMode mode,
)
```

**MOD A (FIFA) için sıralama comparator:**
```
puan DESC → genelAveraj DESC → genelAG DESC → ikiliAveraj DESC → rastgele
```

**MOD B (UEFA) için sıralama comparator:**
Eşit puanlı oyuncular varsa önce onlar arasında mini-tablo oluştur,
mini-tablodaki ikiliPuan → ikiliAveraj → ikiliAG sırasıyla karşılaştır.
Hâlâ eşitse genel averaja bak.

**MOD C (Karma) için sıralama comparator:**
```
puan DESC → genelAveraj DESC → genelAG DESC → ikiliAveraj DESC → ikiliAG DESC → rastgele
```

---

### 4.3 Fikstür Üretim Fonksiyonları

Her format için ayrı fonksiyon:

```dart
// Lig: round-robin
List<TournamentMatch> generateLeagueFixtures(List<String> playerIds)

// Eleme: bracket
List<TournamentMatch> generateKnockoutFixtures(List<String> playerIds)

// Grup + Eleme
Map<String, List<String>> generateGroups(List<String> playerIds)
List<TournamentMatch> generateGroupFixtures(Map<String, List<String>> groups)
List<TournamentMatch> generateKnockoutFromGroups(List<String> groupWinners)

// Şampiyonlar Ligi
List<TournamentMatch> generateChampionsLeaguePhaseFixtures(List<String> playerIds)
```

Tüm fonksiyonlar `tournaments/{id}/matches` koleksiyonuna batch write yapmalı.

---

### 4.4 Turnuva Oluşturma Ekranı Güncellemesi

`create_tournament_screen.dart` Adım 2'ye (Format Seç) şu ekleme yapılmalı:

**Lig ve Grup+Eleme ve Şampiyonlar Ligi formatı seçildiğinde** ek seçenek çıkar:

```
Sıralama Kriteri:
○ FIFA Stili  (Genel averaj önce)
○ UEFA Stili  (İkili averaj önce)  ← default
○ Karma       (Genel averaj + ikili tiebreaker)
```

Eleme formatında bu seçenek gösterilmez (sıralama yoktur).

Seçim `tiebreakerMode` alanına kaydedilir.

---

### 4.5 Puan Tablosu Ekranı Güncellemesi

`tournament_detail_screen.dart` Puan Tablosu sekmesinde:

- Tablo başlığında averaj türü badge olarak gösterilir:
  `"FIFA Stili"` / `"UEFA Stili"` / `"Karma"`
- Eşit puanlı satırlar arasında ince sarı/turuncu vurgu çizgisi
  (ikili averaj hesaplanıyor göstergesi)
- Tooltip: averaj türüne tıklayınca açıklama modal'ı

---

## 5. Gerçek Dünya Karşılıkları (Referans)

| Lig / Turnuva | Averaj Modu |
|---------------|-------------|
| Premier League | MOD A (Genel averaj) |
| Bundesliga | MOD A (Genel averaj) |
| Ligue 1 | MOD A (Genel averaj) |
| La Liga | MOD B (İkili önce) |
| Serie A | MOD B (İkili önce) |
| UEFA Champions League grup | MOD B (İkili önce) |
| FIFA World Cup grup | MOD A (Genel averaj) |
| Süper Lig | MOD B (İkili önce) |

---

## 6. Kenar Durumlar (Edge Cases)

Claude Code bu durumları mutlaka ele almalıdır:

1. **Oynanmamış maç varken sıralama:** Sadece tamamlanmış maçlar hesaba katılır.
2. **Tek oyuncu kaldıysa:** Otomatik şampiyon ilan edilir.
3. **Bye maçı:** Bye olan oyuncu 3-0 skoru ile kazanmış sayılır (averaja dahil edilmez, sadece tura geçer).
4. **MOD B'de 3+ eşit puanlı oyuncu:** Mini-tablo oluşturulur, mini-tabloda da eşitlik varsa genel averaja geçilir.
5. **Sıfır maç oynandıysa:** Tüm oyuncular 0 puan, sıralama kayıt sırasına göre.
6. **Negatif averaj:** Geçerlidir, sıralamada dezavantajdır.

---

*Competra Sıralama Dokümanı v1.0*