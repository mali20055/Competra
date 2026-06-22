# COMPETRA — Kapsamlı Kod Analiz Raporu (V3)

> **Dosya:** `CURSOR__COMPETRA_ANALIZ_V3.md`  
> **Tarih:** 22 Haziran 2026  
> **Kapsam:** `lib/` (54 Dart dosyası), `functions/src/` (5 TS dosyası), `pubspec.yaml`, `firebase.json`, `firestore.rules`, `storage.rules`, `firestore.indexes.json`, `android/app/build.gradle.kts`, `AndroidManifest.xml`, `CLAUDE.md`  
> **Yöntem:** Kaynak kod statik analizi, `flutter analyze`, V2 karşılaştırması  
> **Sürüm:** `1.1.0+2` | Firebase: `competra-9e396` (bölge: `europe-west3`)

---

## 1. YÖNETİCİ ÖZETİ

### 1.1 Projenin Genel Durumu ve Olgunluk Seviyesi

Competra, arkadaşlar arası futbol/oyun turnuvaları için **Flutter + Firebase** tabanlı bir mobil uygulamadır. V2 analizinden bu yana proje **önemli bir mimari sıçrama** yapmıştır:

- Cloud Functions ile sunucu tarafı istatistik/tur ilerletme
- FCM push bildirimleri (uçtan uca)
- Crashlytics, hesap silme, gizlilik politikası
- Onboarding, global liderlik, çift maçlı eleme, tournament wrapped ekranı

| Boyut | Seviye | Açıklama |
|---|---|---|
| Ürün / MVP | **Beta-yayına yakın** | Çekirdek döngü mimari olarak tamamlandı |
| Mühendislik | **Orta-ileri** | Repository + Riverpod tutarlı; teknik borç ve test eksik |
| Güvenlik | **Orta** (rules deploy edilmeden düşük) | Kodda sıkı kurallar var; **production'a deploy edilmemiş** |
| Operasyon | **Erken** | CI/CD yok, emulator yok |

`flutter analyze` → **0 sorun**.

### 1.2 En Kritik 5 Bulgu

| # | Tür | Bulgu | Etki |
|---|---|---|---|
| 1 | 🔴 Negatif | **`firestore.rules` production'a deploy EDİLMEDİ** (`CLAUDE.md:160`) | Canlıda eski/gevşek kurallar geçerli olabilir |
| 2 | 🔴 Negatif | **`users/{uid}` yazma kuralı tüm alanlara izin veriyor** (`firestore.rules:75`) | Kullanıcı `totalWins`, `badges` şişirebilir |
| 3 | 🟠 Negatif | **Bildirim onay/itiraz akışı sahte** (`notifications_screen.dart:213-214`) | Mod B/C bildirimden onaylanamıyor |
| 4 | 🟢 Pozitif | **Cloud Functions: istatistik + tur ilerletme sunucuda** (`functions/src/index.ts`) | V2'nin en kritik sorunu çözüldü |
| 5 | 🟢 Pozitif | **FCM push uçtan uca** (`notification_service.dart`, `onNotificationCreated`) | Maç onayı, turnuva bitişi push ile iletilir |

### 1.3 Modül Bazlı Puanlama (1-10)

| Modül | V2 | V3 | Gerekçe |
|---|---|---|---|
| UI/UX | 8 | **8** | Tema, animasyon, onboarding, wrapped; i18n uygulanmadı |
| Backend | 4 | **7** | CF eklendi; rules deploy eksik |
| Güvenlik | 3 | **5** | participants write:false, match allowlist; users tam yazım açık |
| Performans | 6 | **6** | Küçük ölçekte iyi; pagination yok |
| Kod Kalitesi | 7 | **7** | İyi yorumlanmış; 2227 satırlık dosya, DRY ihlalleri |
| Test Coverage | 1 | **2** | 2 widget testi; birim test yok |
| DevOps | — | **3** | CI/CD yok; Functions deploy edildi |
| Ölçeklenebilirlik | — | **6** | 1K sorunsuz; 10K+ pagination/CF optimizasyonu şart |
| Kullanıcı Deneyimi | — | **7** | Onboarding, haptic; bildirim onayı eksik |

### 1.4 V2 ile Karşılaştırma

| Alan | V2 | V3 |
|---|---|---|
| Cloud Functions | ❌ | ✅ `onMatchWritten`, `onNotificationCreated` deploy |
| İstatistik yazımı | 🔴 İstemci, kurallarla çelişiyor | ✅ Sunucuda transaction + `statsApplied` |
| Tur ilerletme race | 🔴 Transaction yok | ✅ CF `currentRound` koruması |
| Splash auth | 🔴 Her zaman login | ✅ Onboarding + auth (`splash_screen.dart:44-64`) |
| Push / Crashlytics | ❌ | ✅ |
| Hesap silme / Gizlilik | ❌ | ✅ `auth_service.dart:228`, `privacy_policy_screen.dart` |
| Global liderlik / Çift ayak | ❌ | ✅ |
| i18n | ❌ | ⚠️ Altyapı only |
| Test | 0 | 2 widget testi |
| `usernames` okuma | 🔴 Herkese açık | ✅ `isSignedIn()` |
| Rules deploy | — | 🔴 Hâlâ deploy edilmedi |

### 1.5 Tahmini MVP Tamamlanma: **~%82**

---

## 2. MİMARİ ANALİZ

### 2.1 Genel Mimari

```
Flutter İstemci (screens → services/Riverpod → models → Firebase SDK)
         │
         ▼
Firebase (Firestore, Auth, Storage, FCM)
         │
         ▼ onWrite / onCreate
Cloud Functions (admin SDK: istatistik, tur, push)
```

### 2.2 Flutter Katmanları

| Bileşen | Konum | Değerlendirme |
|---|---|---|
| Riverpod | `lib/services/*` | StreamProvider canlı veri, family ID'ler ✅ |
| GoRouter | `app_router.dart` | IndexedStack bottom nav, deep link `competra://join/KOD` ✅ |
| Repository | 7 repo + servisler | UI Firestore'a doğrudan gitmiyor ✅ |

**Skor akışı:**

```dart
// tournament_detail_screen → TournamentRepository.updateMatchScore()
// → Firestore matches onWrite → onMatchWritten (CF)
//   → applyMatchStats (transaction) → checkTournamentProgression
```

### 2.3 Cloud Functions

| Tetikleyici | Yol | Görev |
|---|---|---|
| `onMatchWritten` | `tournaments/{tid}/matches/{mid}` | İstatistik, grup stats, rozet, tur, şampiyon |
| `onNotificationCreated` | `notifications/{id}` | FCM push, geçersiz token temizleme |

Modüller: `index.ts` (587 satır), `types.ts`, `standings.ts`, `fixtures.ts`, `achievements.ts`

**Güçlü:** `statsApplied` idempotent damga (`index.ts:190-218`), `currentRound` transaction koruması (`516-528`).

**Zayıf:** Her maç yazımında tüm maçlar çekilir (`index.ts:353`); Callable endpoint yok.

### 2.4 İstemci ↔ Sunucu Sorumlulukları

| İşlem | İstemci | Sunucu |
|---|---|---|
| Skor yazma | ✅ | — |
| İstatistik / tur / şampiyon | — | ✅ |
| Rozet (istatistik bazlı) | — | ✅ |
| Bildirim oluşturma | ✅ | — |
| FCM gönderimi | — | ✅ |
| Başlangıç fikstürü | ✅ `startTournament` | — |
| Tur fikstürü | — | ✅ |

### 2.5 Circular Dependency

**Risk: DÜŞÜK.** `notification_service.dart` → `app_router.dart` (kabul edilebilir).

**Ölü kod:**
- `social_repository.dart:94` — `updateFriendGroupStats` (CF'ye taşındı, çağrılmıyor)
- `achievement_service.dart` — `checkAndUpdateAchievements` (CF'ye taşındı, çağrılmıyor)

### 2.6 Mimari İyileştirme Örnekleri

**users yazma kısıtı (rules):**

```javascript
allow update: if isSignedIn() && request.auth.uid == uid
  && changedKeysWithin([
       'username', 'usernameLower', 'bio', 'favoriteTeam',
       'photoUrl', 'coverUrl', 'fcmToken', 'fcmTokenUpdatedAt'
     ]);
```

**ScoreService (Dart):**

```dart
class ScoreService {
  Future<void> submitScore({...}) async {
    switch (tournament.scoreEntrySystem) {
      case ScoreEntrySystem.adminOnly:
        await _repo.updateMatchScore(...);
      case ScoreEntrySystem.winnerEntry:
        await _repo.submitScoreForConfirmation(...);
      // doubleEntry karşılaştırma burada
    }
  }
}
```

---

## 3. KRİTİK HATALAR VE RİSKLER

| Konum | Açıklama | Risk | Çözüm |
|---|---|---|---|
| `tournament_detail_screen.dart:1471-1480` | `enteredHomeScore!` force unwrap | Orta | Null guard |
| `tournament_detail_screen.dart:2142-2153` | `homeScore!` çift ayakta | Orta | `isPlayed` sonrası güvenli erişim |
| iOS `Info.plist` | `NSPhotoLibraryUsageDescription` yok | Yüksek (iOS) | Mac'te ekle |
| `auth_service.dart:96-97` | Kayıt race yetim hesap | Orta | Callable register |
| `tournament_repository.dart:126-149` | 500+ maç batch limiti | Düşük-Orta | Parçalı batch |
| `index.ts:81-83` | CF hata yutma | Orta | Dead-letter + alert |
| `notification_service.dart:65,68` | Stream abonelik iptal yok | Düşük | Subscription sakla |

**Memory leak:** Genel olarak **düşük** (Timer/Controller dispose doğru).

**Race:** `joinByInviteCode` `arrayUnion` idempotent ✅; CF `currentRound` koruması ✅.

---

## 4. GÜVENLİK ANALİZİ (DETAYLI)

> ⚠️ Kurallar **kodda** sıkı; **production deploy edilmemiş** (`CLAUDE.md:160`).

### 4.1 Firestore — Koleksiyon Bazlı

| Koleksiyon | Read | Write | Risk | CVSS | Çözüm |
|---|---|---|---|---|---|
| `users` | Oturumlu herkes | Sahibi TÜM alanlar | İstatistik hilesi | **7.5** | Alan allowlist |
| `usernames` | Oturumlu | Create/delete sahibi | Email enum | **5.3** | Callable lookup |
| `tournaments` | Katılımcı / limit≤1 | Admin / self-join | Düşük | 3.0 | — |
| `participants` | Katılımcı | **false** | ✅ | — | — |
| `matches` | Katılımcı | Oyuncu allowlist | Status bypass | **6.5** | Mod bazlı status |
| `friendGroups` | Üye | Create serbest | Sahte createdBy | **4.3** | createdBy doğrula |
| `notifications` | Hedef | Create başkasına | Spam | **5.0** | senderId doğrula |
| `wheels` | Sahibi | Sahibi | ✅ | — | — |
| `feedback` | false | Create only | ✅ | — | — |

**matches allowlist** (`firestore.rules:147-151`):

```javascript
changedKeysWithin([
  'homeScore', 'awayScore', 'played', 'status',
  'enteredBy', 'enteredHomeScore', 'enteredAwayScore',
  'secondEnteredBy', 'secondEnteredHomeScore', 'secondEnteredAwayScore'
])
// statsApplied YAZILAMAZ ✅
```

### 4.2 Storage (`storage.rules`)

- Profil/kapak: herkes okur, `{uid}.jpg` sahibi yazar ✅
- **Boyut/content-type sınırı yok** → CVSS 4.0

```javascript
// Önerilen
allow write: if ... && request.resource.size < 5 * 1024 * 1024
  && request.resource.contentType.matches('image/.*');
```

### 4.3 Cloud Functions

Admin SDK (tasarım gereği), App Check ❌, rate limit ❌.

### 4.4 Authentication

| Bulgu | Konum | Risk |
|---|---|---|
| Geçici anonim oturum username arama | `auth_service.dart:46-48` | Orta |
| Misafir `users` belgesi yok | `auth_service.dart:190-195` | Orta |
| iOS Google Sign-In URL scheme eksik | Info.plist | Yüksek |

### 4.5 Input Validasyon

İstemci: `Validators`, skor `tryParse` ✅. Sunucu: negatif skor kontrolü ❌.

### 4.6 KVKK/GDPR (~%55 uyum)

| Gereksinim | Durum |
|---|---|
| Aydınlatma | ⚠️ Uygulama içi (`privacy_policy_screen.dart`) |
| Hesap silme | ✅ `settings_screen.dart:134` |
| Veri export | ❌ |
| PII minimizasyon | 🟠 `users.email` tüm oturumlulara açık |
| Harici politika URL | ❌ (mağaza için gerekli) |

### 4.7 Penetrasyon Senaryoları

1. `totalWins: 9999` yazma → **BAŞARILI** (kural izin verir)
2. `status: completed` + sahte skor → **BAŞARILI**
3. Bildirim spam → **BAŞARILI**
4. `statsApplied` yazma → **BAŞARISIZ** ✅
5. Başkasının participant stats → **BAŞARISIZ** ✅

---

## 5. PERFORMANS ANALİZİ (DETAYLI)

| Konum | Sorun | Etki | Çözüm | Kazanım |
|---|---|---|---|---|
| `index.ts:353` | CF tüm maçları çeker | Yüksek | Round sorgusu | %70-90 CF okuma |
| `tournament_repository.dart:306` | Turnuva istemci sort | Orta | orderBy+limit | %40-60 |
| `social_repository` | N+1 grup okuma | Orta | Denormalize | N→1 |
| `profile_screen.dart:179` | Image.network | Düşük | CachedNetworkImage | Önbellek |
| `tournament_detail_screen.dart:108` | Her rebuild standings | Düşük | Memoize | CPU |

**Cold start:** Node 22 v2, tahmini 1-3 sn.

**Pagination eksik:** `myTournamentsStreamProvider`, `notificationsProvider`.

**Index:** Leaderboard aktif ✅; tournaments/friendships index'leri istemci sort nedeniyle atıl.

---

## 6. KOD KALİTESİ ANALİZİ

### 6.1 DRY İhlalleri

| Tekrar | Dosyalar | Refactor |
|---|---|---|
| `_formatLabel` | `home_screen.dart:752`, `leagues_screen.dart:418`, `tournament_detail_screen.dart:2329` | `core/format_labels.dart` |
| `_EmptyState` | 6+ ekran | `components/empty_state.dart` |
| `_showError` | 7+ ekran | Context extension |
| `achievement_service` ↔ `achievements.ts` | Dart ölü kod | Sil |

### 6.2 En Uzun Dosyalar

| Dosya | Satır |
|---|---|
| `tournament_detail_screen.dart` | **2227** |
| `create_tournament_screen.dart` | 962 |
| `wheel_screen.dart` | 937 |
| `profile_screen.dart` | 878 |
| `functions/src/index.ts` | 587 |

### 6.3 Magic String'ler

Format: `league`, `knockout`, `groupKnockout`, `championsLeague`  
Durum: `waiting`, `active`, `completed`, `awaitingConfirmation`, `disputed`  
Bildirim: `matchConfirm`, `match_confirm`, `friendRequest`, `tournamentComplete`

### 6.4 TypeScript

ESLint + predeploy lint ✅. `standings.ts`, `fixtures.ts` Dart portu temiz.

---

## 7. KLASÖR YAPISI VE MİMARİ ÖNERİSİ

### 7.1 Mevcut Yapı

```
lib/
  components/     (5 dosya)
  core/theme, validators, time_ago
  l10n/
  models/         (8 dosya)
  router/
  screens/        (feature alt klasörleri)
  services/       (12 dosya)
functions/src/    (5 TS dosyası)
test/widget_test.dart
```

### 7.2 Sorunlar

1. `services/` hem repo hem provider hem ölü iş mantığı
2. `constants/`, `extensions/` yok
3. Monolitik `tournament_detail_screen.dart`
4. Ölü kod: `achievement_service.dart`, `updateFriendGroupStats`

### 7.3 Önerilen Yapı

```
lib/
  app/                    # main, router
  core/constants, extensions, utils, theme
  data/models, repositories, providers
  presentation/components, features/tournament/widgets/
  l10n/
```

**Öneri:** Feature-based + shared `core/`.

---

## 8. FRONTEND GELİŞTİRME ÖNERİLERİ

| # | Öneri | Öncelik | Zorluk | Süre |
|---|---|---|---|---|
| 1 | Paylaşılan `EmptyState`, `PlayerAvatar` bileşenleri | Yüksek | Kolay | 1-2 gün |
| 2 | `shimmer` skeleton loading (paket var, kullanılmıyor) | Orta | Kolay | 1 gün |
| 3 | `CachedNetworkImage` profil önbelleği | Orta | Kolay | 0.5 gün |
| 4 | i18n: string'leri `AppLocalizations`'a taşı | Yüksek | Orta | 3-5 gün |
| 5 | `Semantics` (çark, skor kartları) | Orta | Orta | 2 gün |
| 6 | Responsive `LayoutBuilder` | Orta | Orta | 2 gün |
| 7 | Loading/Error/Empty standardizasyonu | Yüksek | Kolay | 1-2 gün |
| 8 | Bildirim onay → turnuva detayı | Yüksek | Orta | 1-2 gün |
| 9 | `tournamentComplete` tap → wrapped (şu an leagues) | Yüksek | Kolay | 0.5 gün |
| 10 | GoRouter auth guard | Orta | Orta | 1 gün |
| 11 | Dark/Light: `_WheelPainter` sabit `Colors.white` | Düşük | Kolay | 0.5 gün |
| 12 | textScaleFactor taşma koruması | Orta | Orta | 1 gün |

---

## 9. BACKEND GELİŞTİRME ÖNERİLERİ

| # | Öneri | Öncelik | Zorluk | Süre |
|---|---|---|---|---|
| 1 | `firestore.rules` deploy | **Kritik** | Kolay | 0.5 gün |
| 2 | `users` yazma alan kısıtı | **Kritik** | Orta | 1 gün |
| 3 | Callable `resolveUsername` | Yüksek | Orta | 1-2 gün |
| 4 | Callable `deleteAccount` (atomik) | Yüksek | Orta | 2 gün |
| 5 | Scheduled: eski bildirim temizleme | Düşük | Kolay | 1 gün |
| 6 | `onUserDeleted` Auth trigger | Yüksek | Orta | 2 gün |
| 7 | Rate limiting (davet kodu, bildirim) | Orta | Zor | 3 gün |
| 8 | Denormalize `users.groupIds[]` | Orta | Orta | 2 gün |

**Callable vs HTTP:** Firebase ekosisteminde Callable tercih edilmeli.

---

## 10. FİREBASE GELİŞTİRME ÖNERİLERİ

| # | Öneri | Öncelik | Maliyet | Zorluk |
|---|---|---|---|---|
| 1 | Firestore rules deploy | Kritik | — | Kolay |
| 2 | Firebase App Check | Yüksek | Düşük | Orta |
| 3 | Firebase Analytics | Yüksek | Ücretsiz | Kolay |
| 4 | Emulator Suite | Yüksek | — | Orta |
| 5 | Remote Config (feature flags) | Orta | Ücretsiz | Kolay |
| 6 | Performance Monitoring | Orta | Ücretsiz | Kolay |
| 7 | Storage image resize extension | Orta | Düşük | Kolay |
| 8 | TTL: eski notifications | Düşük | Düşük | Kolay |
| 9 | Apple Sign-In / Phone Auth | Orta | Düşük | Orta |
| 10 | Dynamic Links (davet paylaşımı) | Orta | Ücretsiz | Orta |

---

## 11. YENİ ÖZELLİK ÖNERİLERİ (30)

### Sosyal
| Özellik | User Story | Zorluk | Süre | Öncelik |
|---|---|---|---|---|
| Maç sohbeti | Maç öncesi/sonrası mesajlaşma | Orta | 5 gün | Orta |
| Grup davet linki | Tek linkle arkadaş davet | Kolay | 2 gün | Orta |
| Arkadaş aktivite feed | Son maçları görme | Orta | 4 gün | Orta |
| Emoji reaksiyonları | Maç sonucuna emoji | Kolay | 2 gün | Düşük |

### Rekabet
| Özellik | User Story | Zorluk | Süre | Öncelik |
|---|---|---|---|---|
| Head-to-Head | Rakiple geçmiş maçlar | Orta | 3 gün | Yüksek |
| Sezon sistemi | Aylık/yıllık sıralama | Zor | 8 gün | Orta |
| Elo puanı | Dinamik sıralama | Orta | 4 gün | Orta |
| Haftalık mücadele | En çok gol atan | Orta | 3 gün | Orta |
| Turnuva tahmin oyunu | Sonuç tahmini | Orta | 5 gün | Orta |
| Rozet vitrin | 3 rozet sergileme | Kolay | 1 gün | Düşük |

### Organizasyon
| Özellik | User Story | Zorluk | Süre | Öncelik |
|---|---|---|---|---|
| Maç tarihi/saati | Hatırlatma almak | Orta | 4 gün | Yüksek |
| Saha/konum | Nerede oynanacak | Kolay | 2 gün | Orta |
| Turnuva şablonları | Ayarları kaydet | Kolay | 2 gün | Orta |
| Çoklu admin | Yardımcı yönetici | Orta | 3 gün | Orta |
| PDF fikstür export | Paylaşılabilir fikstür | Orta | 3 gün | Düşük |

### Monetizasyon
| Özellik | User Story | Zorluk | Süre | Öncelik |
|---|---|---|---|---|
| Premium turnuva (16+ kişi) | Büyük turnuva | Orta | 5 gün | Orta |
| Reklamsız IAP | Reklam kaldırma | Orta | 3 gün | Düşük |
| Sponsor banner | Turnuvaya sponsor | Kolay | 2 gün | Düşük |

### Teknik / UX
| Özellik | User Story | Zorluk | Süre | Öncelik |
|---|---|---|---|---|
| Offline skor girişi | İnternet yokken skor | Orta | 3 gün | Orta |
| Veri export (GDPR) | Verilerimi indir | Orta | 3 gün | Yüksek |
| Admin web panel | Web'den yönetim | Zor | 15 gün | Düşük |
| Takım renkleri | Oyuncuya renk | Kolay | 1 gün | Düşük |
| Ana ekran widget | Sıradaki maç | Zor | 5 gün | Düşük |

---

## 12. EK API VE SERVİS ÖNERİLERİ

| Servis | Kullanım | Maliyet | Zorluk | Değer | Süre |
|---|---|---|---|---|---|
| API-Football | Maç sonuçları, logolar | $10-50/ay | Orta | Orta | 3-5 gün |
| SendGrid | E-posta davet | Ücretsiz tier | Kolay | Orta | 2 gün |
| RevenueCat | IAP/abonelik | %1 gelir | Orta | Yüksek | 3-5 gün |
| AdMob | Banner reklam | Gelir | Kolay | Orta | 2 gün |
| Mixpanel | Analytics funnel | Ücretsiz | Kolay | Yüksek | 2 gün |
| OpenAI | Maç özeti, rapor | $5-20/ay | Orta | Düşük | 3 gün |
| Algolia | Gelişmiş arama | Ücretsiz tier | Orta | Orta | 3 gün |

---

## 13. MONETİZASYON STRATEJİLERİ

| Strateji | Tahmini Gelir (10K kullanıcı) | Kullanıcı Etkisi | Zorluk |
|---|---|---|---|
| Freemium (8+ kişi premium) | $2-5K/ay | Düşük sürtünme | Orta |
| Premium abonelik ($2.99/ay) | $3-8K/ay | Orta | Orta |
| AdMob banner | $500-2K/ay | Negatif | Kolay |
| B2B kafe/kulüp ($29.99/ay) | $1-5K/ay | Pozitif | Zor |
| IAP rozet paketi ($0.99) | $200-500/ay | Pozitif | Kolay |

**Önerilen başlangıç:** Freemium + opsiyonel reklam kaldırma IAP.

---

## 14. TEST STRATEJİSİ (DETAYLI)

### 14.1 Mevcut Coverage (~%2)

| Tür | Sayı |
|---|---|
| Widget test | 2 (`test/widget_test.dart`) |
| Unit test | 0 |
| Integration | 0 |
| CF / Rules test | 0 |

### 14.2 Unit Test Öncelikleri (20)

1-5. `computeStandings` — FIFA/UEFA/Hybrid/3'lü eşitlik/bye  
6. `computeScorers`  
7-12. `fixture_generator` — lig, eleme, çift ayak, grup, seed  
13-15. `Validators`, `timeAgoTr`  
16-18. Model `fromDoc` fallback'leri  
19-20. TS `deriveAchievementUpdate`, `resolveTieWinner`

### 14.3 Diğer Testler

- **Widget:** Empty state, skor dialog, leaderboard madalya
- **Integration (Emulator):** Kayıt → turnuva → skor → şampiyon
- **Rules:** `@firebase/rules-unit-testing`
- **E2E:** Patrol / `integration_test`
- **CI:** GitHub Actions → `flutter test` + `tsc --noEmit`

### 14.4 Öncelik Matrisi

| Sıra | Test | Değer | Kolaylık |
|---|---|---|---|
| 1 | computeStandings unit | Çok yüksek | Kolay |
| 2 | fixture_generator unit | Çok yüksek | Kolay |
| 3 | Firestore rules test | Çok yüksek | Orta |
| 4 | CF applyMatchStats | Yüksek | Orta |
| 5 | Integration E2E | Yüksek | Zor |

---

## 15. DEVOPS VE YAYINA HAZIRLIK

### 15.1 Mevcut Durum

- CI/CD: **YOK**
- Functions: deploy edildi ✅
- Rules: **deploy edilmedi** 🔴
- Crashlytics: ✅
- Analytics: ❌
- Release signing: `key.properties` ile hazır (`build.gradle.kts:47-55`)

### 15.2 GitHub Actions Önerisi

```yaml
name: CI
on: [push, pull_request]
jobs:
  flutter:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
      - run: flutter pub get && flutter analyze && flutter test
      - run: flutter build apk --release
  functions:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 22 }
      - run: cd functions && npm ci && npm run lint && npx tsc --noEmit
  deploy:
    needs: [flutter, functions]
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
      - uses: w9jds/firebase-action@master
        with:
          args: deploy --only functions,firestore:rules,firestore:indexes
        env:
          FIREBASE_TOKEN: ${{ secrets.FIREBASE_TOKEN }}
```

### 15.3 Yayın Kontrol Listesi

| Madde | Android | iOS |
|---|---|---|
| İşlevsel skor döngüsü | ✅ (CF ile) | ⚠️ test gerek |
| Hesap silme | ✅ | ✅ |
| Gizlilik politikası | ⚠️ URL gerek | ⚠️ URL gerek |
| Push | ✅ | 🔴 Mac/Xcode gerek |
| Google Sign-In | ✅ | 🔴 URL scheme |
| image_picker izni | ✅ | 🔴 Info.plist |
| Data Safety formu | 🔴 | 🔴 |

---

## 16. ÖLÇEKLENEBİLİRLİK ANALİZİ

### 16.1 Kullanıcı Bazlı

| Metrik | 1K | 10K | 100K |
|---|---|---|---|
| Firestore okuma/gün | ~50K | ~500K | ~5M |
| CF invocations/gün | ~5K | ~50K | ~500K |
| Durum | ✅ | ⚠️ pagination | 🔴 mimari değişiklik |

### 16.2 Aylık Maliyet Tahmini

| Kullanıcı | Tahmini Maliyet |
|---|---|
| 1K | $5-10 |
| 10K | $50-80 |
| 100K | $500-800 |

### 16.3 Darboğazlar ve Çözümler

1. CF tüm maçları çekme → round bazlı sorgu
2. `collectionGroup('members')` → `users.groupIds[]`
3. İstemci sort → `orderBy` + pagination
4. Leaderboard tek koleksiyon → sezon alt koleksiyonu

---

## 17. KULLANICI DENEYİMİ (UX) DERİN ANALİZİ

### 17.1 Ana Akış

```
Splash → Onboarding? → Login/Guest → Home
  → Create/Join Tournament → Lobby → Start → Detail (3 sekme)
  → Score → CF Stats → Complete → Wrapped 🎉
```

### 17.2 Retention

| Mekanizma | Durum |
|---|---|
| Push bildirimleri | ✅ |
| Rozet/unvan | ✅ |
| Global liderlik | ✅ |
| Son aktiviteler (home) | ✅ |
| Günlük mücadele / streak | ❌ |

### 17.3 Pain Point'ler

| Sorun | Çözüm |
|---|---|
| Bildirimden skor onaylanamıyor | Gerçek onay akışı |
| Misafir sınırlı, belge yok | Guest banner + kısıtlama |
| Wrapped'a otomatik gitme yok | Push deep link |
| Sabit Türkçe string'ler | i18n |

### 17.4 Personalar

| Persona | Karşılama |
|---|---|
| Turnuva organizatörü | ✅ Güçlü |
| Rekabetçi oyuncu | ⚠️ H2H yok |
| Gündelik oyuncu | ✅ İyi |
| Misafir | ⚠️ Sınırlı |

### 17.5 Rekabet ve ASO

**Avantaj:** 4 format, tiebreaker, çark, gamification, Türkçe UX.  
**ASO:** "Competra - Turnuva & Lig", anahtar: turnuva, fikstür, skor, arkadaş.

---

## 18. TEKNİK BORÇ ANALİZİ

| # | Borç | Etki | Maliyet | Risk | Öncelik |
|---|---|---|---|---|---|
| 1 | Rules deploy edilmedi | Kritik | 0.5 gün | Yüksek | P0 |
| 2 | users tam yazım kuralı | Yüksek | 1 gün | Yüksek | P0 |
| 3 | tournament_detail 2227 satır | Orta | 3 gün | Orta | P1 |
| 4 | Ölü kod (achievement_service vb.) | Düşük | 0.5 gün | Düşük | P2 |
| 5 | Magic string'ler | Orta | 2 gün | Orta | P1 |
| 6 | i18n uygulanmadı | Orta | 5 gün | Orta | P1 |
| 7 | Test ~%2 | Yüksek | 5-10 gün | Yüksek | P1 |
| 8 | CI/CD yok | Orta | 2 gün | Orta | P1 |
| 9 | Bildirim onay sahte | Orta | 2 gün | Orta | P1 |
| 10 | Kullanılmayan paketler (lottie, rive, shimmer, cached_network_image) | Düşük | 0.5 gün | Düşük | P3 |

### Sprint Planı

| Sprint | İş |
|---|---|
| 1 (0-2 hf) | Rules deploy, users kısıtı, bildirim onay, ölü kod |
| 2 (2-4 hf) | Detail bölme, enum/constants, unit testler |
| 3 (4-6 hf) | i18n, CI/CD, pagination, iOS |
| 4 (6-8 hf) | CF optimizasyon, integration test, analytics |

---

## 19. ÖNCELİKLİ YOL HARİTASI

### Faz 1 — Kritik (0-2 hafta)

| # | Madde | Neden | Süre |
|---|---|---|---|
| 1 | firestore.rules deploy | Canlı güvenlik | 0.5 gün |
| 2 | users alan kısıtı | İstatistik hilesi | 1 gün |
| 3 | Bildirim onay/itiraz gerçek akış | Mod B/C UX | 2 gün |
| 4 | AppNotification + tournamentId/matchId | Yönlendirme | 0.5 gün |
| 5 | tournamentComplete → wrapped | UX | 0.5 gün |
| 6 | Ölü kod temizliği | Karmaşıklık | 0.5 gün |
| 7 | Harici gizlilik URL (mağaza) | Yasal | 1 gün |

### Faz 2 — Temel İyileştirmeler (2-6 hafta)

| # | Madde | Fayda | Süre |
|---|---|---|---|
| 8 | Unit testler (standings, fixtures) | Regresyon | 3 gün |
| 9 | tournament_detail bölme | Bakım | 3 gün |
| 10 | Enum/constants | Tip güvenliği | 2 gün |
| 11 | i18n migrasyonu | Global erişim | 5 gün |
| 12 | CI/CD GitHub Actions | Kalite | 2 gün |
| 13 | Pagination | Ölçek | 2 gün |
| 14 | Firebase Analytics | İçgörü | 1 gün |
| 15 | iOS yapılandırması | iOS yayın | 2 gün |

### Faz 3 — Yeni Özellikler (6-12 hafta)

| # | Madde | İş Değeri | Süre |
|---|---|---|---|
| 16 | Head-to-Head | Rekabet | 3 gün |
| 17 | Maç tarihi + hatırlatma | Organizasyon | 4 gün |
| 18 | Veri export (GDPR) | Yasal | 3 gün |
| 19 | Callable resolveUsername | Güvenlik | 2 gün |
| 20 | Freemium model | Gelir | 5 gün |

### Faz 4 — Ölçekleme (3-6 ay)

| # | Madde | Etki | Süre |
|---|---|---|---|
| 21 | CF maç okuma optimizasyonu | %70 maliyet düşüşü | 3 gün |
| 22 | Denormalizasyon (groupIds) | N+1 kalkar | 3 gün |
| 23 | Admin web panel | Operasyon | 15 gün |
| 24 | B2B kafe/kulüp paketi | Gelir | 10 gün |

---

## 20. KAPANIŞ DEĞERLENDİRMESİ

### 20.1 Güçlü Yanlar (13)

1. Cloud Functions ile sunucu mimarisi (V2 kritik sorun çözüldü)
2. 4 turnuva formatı + 3 skor modu + tiebreaker (FIFA/UEFA/Karma)
3. Tutarlı UI/UX, tema, animasyonlar, boş durumlar
4. FCM push uçtan uca
5. Repository + Riverpod pattern
6. Türkçe kod dokümantasyonu
7. Gamification: rozet, unvan, liderlik, konfeti wrapped
8. Hesap silme + gizlilik politikası
9. Crashlytics
10. Çift maçlı eleme (away goals)
11. Deep link davet (`competra://join/KOD`)
12. `flutter analyze` temiz
13. Profil/kapak fotoğrafı yükleme

### 20.2 Zayıf Yanlar ve Acil Eylemler

| Zayıflık | Eylem |
|---|---|
| Rules deploy edilmedi | Cloud Shell'den deploy |
| users istatistik hilesi | Alan kısıtlı kural |
| Test ~%2 | Unit testler |
| Bildirim onay sahte | Gerçek implementasyon |
| CI/CD yok | GitHub Actions |
| iOS hazır değil | Mac yapılandırması |

### 20.3 Rekabetçi Avantajlar

Türkçe-first UX, çok formatlı turnuva + tiebreaker, sosyal katman entegre, şans çarkı, gerçek zamanlı Firebase.

### 20.4 Pazar Potansiyeli

Türkiye amatör futbol/grup oyunu ~5M potansiyel. Gerçekçi 12 ay hedef: **5-10K aktif kullanıcı**.

### 20.5 Takım Önerisi

| Rol | Zamanlama |
|---|---|
| Flutter (mevcut) | i18n, test, UI — şimdi |
| Firebase uzmanı | Rules, CF, App Check — Faz 1-2 |
| iOS (part-time) | Push, Sign-In — Faz 2 |
| QA (part-time) | Emulator, E2E — Faz 2 |

### 20.6 6 Aylık Vizyon

```
Ay 1-2: Güvenlik + stabilite (rules, test, bildirim onay)
Ay 2-3: i18n + CI/CD + Android Play Store yayını
Ay 3-4: H2H, maç tarihi, freemium, analytics
Ay 4-5: Sezon, App Check, B2B pilot
Ay 5-6: Ölçekleme, iOS yayını, 5K kullanıcı
```

**6 ay hedef:** Android + iOS yayında, kritik modüllerde test coverage, 5K+ aktif kullanıcı, freemium aktif.

---

> **Rapor sonu** — `CURSOR__COMPETRA_ANALIZ_V3.md`  
> Statik kod analizi ile üretilmiştir. Canlı Firebase deploy durumu ayrıca doğrulanmalıdır.

