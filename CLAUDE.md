# CLAUDE.md — Competra

Bu dosya, gelecekteki Claude Code oturumlarının projeyi hızla kavrayıp kaldığı
yerden devam edebilmesi için projenin mimarisini, mevcut durumunu ve tamamlanan
özellikleri özetler.

## Proje Özeti

**Competra**, arkadaşlar arası futbol/oyun turnuvaları düzenlemek için bir
Flutter uygulamasıdır. Turnuva oluşturma, davet koduyla katılma, fikstür üretimi,
skor girişi/onayı, puan tablosu, gol krallığı, rozetler/unvanlar, arkadaşlık ve
arkadaş grupları, şans çarkı, global sıralama ve push bildirimleri içerir.

- **Firebase projesi:** `competra-9e396` (Firestore bölgesi: `europe-west3`)
- **Platformlar:** öncelik Android (iOS yapılandırması Mac'te tamamlanacak)
- **Sürüm:** `pubspec.yaml` → `1.1.0+2`

## Teknoloji Yığını

- **Flutter** 3.35.1 (Dart SDK ^3.9.0)
- **Durum yönetimi:** `flutter_riverpod` ^3.x (provider'lar `lib/services/`)
- **Yönlendirme:** `go_router` ^17.x (`lib/router/`)
- **Backend:** Firebase — Auth, Cloud Firestore, Storage, Crashlytics,
  Cloud Messaging (FCM)
- **Cloud Functions:** TypeScript, 2. nesil (v2), Node.js 22 (`functions/`)
- **i18n:** `flutter_localizations` + `intl`, ARB tabanlı gen-l10n (`lib/l10n/`)
- Diğer: `google_fonts`, `flutter_animate`, `lottie`, `rive`, `confetti`,
  `shimmer`, `share_plus`, `cached_network_image`, `google_sign_in`,
  `image_picker`, `shared_preferences`, `fl_chart`

## Dizin Yapısı

```
lib/
  main.dart                      # Giriş; Firebase + NotificationService init; MaterialApp.router
  firebase_options.dart          # FlutterFire yapılandırması
  core/
    theme/                       # app_theme.dart, app_colors.dart
    time_ago.dart                # timeAgoTr() — Türkçe göreli zaman
    validators.dart
  components/                    # Ortak widget'lar (nav bar, arka plan, logo, text field)
  l10n/                          # app_en.arb, app_tr.arb + üretilen app_localizations*.dart
  models/                        # tournament, user_profile, app_notification, wheel,
                                 # friendship, friend_group, badge/title_definitions
  router/                        # app_router.dart, route_paths.dart
  screens/                       # auth, home, leagues, tournament, wheel, social,
                                 # profile, settings, notifications, leaderboard,
                                 # onboarding, splash
  services/                      # Riverpod provider'ları + repository'ler
functions/
  src/
    index.ts                     # Tetikleyiciler: onMatchWritten, onNotificationCreated
    types.ts                     # Match/Tournament parse + tipler (Flutter modelleriyle paralel)
    standings.ts                 # computeStandings (tiebreaker mantığı)
    fixtures.ts                  # eleme turu üreticileri (fixture_generator.dart portu)
    achievements.ts              # rozet/unvan türetimi
firestore.rules                  # Güvenlik kuralları
firestore.indexes.json           # Bileşik + tek-alan dizinleri (deploy edildi)
```

## Mimari Notları

### Veri akışı
- Ekranlar Firebase'e doğrudan değil, `lib/services/` altındaki Riverpod
  provider'ları üzerinden erişir (`firebase_providers.dart` temel örnekleri verir).
- Canlı veriler `StreamProvider` ile gelir (turnuva, maçlar, bildirimler, profil).

### İstemci ↔ Sunucu güvenlik modeli
- **İstatistikler, tur ilerletme, şampiyon belirleme yalnızca Cloud Functions
  (admin SDK) tarafından yazılır.** İstemci sadece maç skorunu yazar.
- `firestore.rules` buna göre sıkılaştırılmıştır:
  - `users/{uid}`: yalnızca sahibi yazabilir (`fcmToken` dahil — ekstra kural
    gerekmez).
  - `participants` / istatistik alanları istemciden yazılamaz (`allow write: if false`).
  - `matches`: oyuncular yalnızca skor/onay alanlarını (allowlist) yazar;
    `statsApplied` istemciden yazılamaz.
- `functions/src/*.ts`, `lib/services/*.dart` ve `lib/models/*.dart` ile AYNI
  alan adlarını ve normalizasyon kurallarını kullanır (istemci/sunucu paritesi).

### Turnuva formatları (`tournament.format`)
- `league` — herkes herkesle (round-robin)
- `knockout` — tek maçlı eleme (bracket + bye)
- `groupKnockout` — grup fazı + çapraz eleme
- `championsLeague` — kısmi lig fazı + **çift maçlı (iki ayaklı) eleme**

### Skor giriş sistemi (`tournament.scoreEntrySystem`)
- `adminOnly` — yalnızca yönetici girer
- `winnerEntry` — bir taraf girer, rakip onaylar/itiraz eder (banner)
- `doubleEntry` — iki taraf ayrı girer; uyuşursa kesinleşir, uyuşmazsa anlaşmazlık

### Puan eşitliği (`tournament.tiebreakerMode`)
- `fifa` (Genel averaj önce), `uefa` (İkili averaj önce — varsayılan),
  `hybrid` (Karma). Mantık hem `lib/models/tournament.dart` (`computeStandings`)
  hem `functions/src/standings.ts` içinde.

### Cloud Functions tetikleyicileri (`functions/src/index.ts`)
- **`onMatchWritten`** (`tournaments/{tid}/matches/{mid}` onWrite): maç
  kesinleşince istatistik uygular (idempotent `statsApplied` damgası), arkadaş
  grubu istatistiklerini ve rozetleri günceller, turnuva ilerlemesini değerlendirir.
- **`onNotificationCreated`** (`notifications/{id}` onCreate): hedef kullanıcının
  `fcmToken`'ına FCM push gönderir; token yoksa sessizce geçer; geçersiz token'ı
  (`invalid-registration-token` / `registration-token-not-registered`) Firestore'dan
  siler.

## Tamamlanan Özellikler (oturum geçmişi)

### Push Bildirimleri (FCM) — uçtan uca ✅
- **İstemci:** `lib/services/notification_service.dart` (`NotificationService`):
  izin isteme (iOS + Android 13+), token alma ve `users/{uid}.fcmToken` yazma,
  `onTokenRefresh` + `authStateChanges` ile güncel tutma, ön planda SnackBar
  (global `messengerKey` → `MaterialApp.scaffoldMessengerKey`), `onMessageOpenedApp`
  + `getInitialMessage` ile yönlendirme, top-level arka plan handler.
- **Yönlendirme payload kuralı:** `type == 'friendRequest'` → `/social`;
  `type == 'tournamentComplete'` (+`tournamentId`) → `/tournament/:id/wrapped`;
  `tournamentId` → `/tournament/:id`.
- `main.dart`'ta `NotificationService.initialize()` (Firebase init sonrası).
- `AndroidManifest.xml`'e `POST_NOTIFICATIONS` izni eklendi.
- `ios/Runner/Info.plist`'e Mac/Xcode'da yapılacaklar (Push Notifications +
  Background Modes capability, APNs key) XML yorumu olarak bırakıldı.
- **Sunucu:** `onNotificationCreated` tetikleyicisi (yukarıda).

### Çift Maçlı Eleme (Şampiyonlar Ligi) ✅
- `TournamentMatch` modeline `leg` alanı (1/2, varsayılan 1) eklendi; TS
  `Match` + `parseMatch` paralel.
- `generateKnockoutFromSeeds` (Dart + TS) her eşleşme için 1. ayak (üst sıralı
  ev sahibi) ve 2. ayak (ev/deplasman ters) üretir; bye tek maç.
- `generateNextKnockoutRound`'a `twoLegged` parametresi (CL boyunca iki ayaklı).
- **Sunucu tur ilerletme (`advanceKnockout` + `resolveTieWinner`):** maçları
  eşleşmeye göre gruplar; kazanan kuralı: toplam gol → deplasman golü (away goals)
  → 1. maçın ev sahibi (basit kural). Tek maçlı formatlar değişmeden çalışır.
- **UI (`tournament_detail_screen.dart`):** `_TwoLeggedTieCard` çift ayağı
  "1. Maç"/"2. Maç" olarak gösterir, "Toplam: ..." satırı ve turu geçeni yeşil
  kenarlık + "{kazanan} tur atladı" ile vurgular.

### Turnuva Ekranı İyileştirmeleri ✅
- Puan tablosu üstünde tiebreaker rozeti (`_TiebreakerBadge`) + açıklama bottom sheet.
- `tournament.note` doluysa detay ekranında 📝 not kartı (`_NoteCard`).
- Maç kartlarında baş harfli placeholder avatarlar (`_PlayerAvatar`).

### Home Ekranı İyileştirmeleri ✅
- Hızlı istatistik satırı (`_QuickStats`): Toplam Maç | Galibiyet % | Toplam Gol
  (`userProfileProvider`).
- Son aktiviteler (`_RecentActivity`): son 10 bildirim (`notificationsProvider`)
  ikon + mesaj + `timeAgoTr`.

### Çoklu Dil (i18n) Altyapısı ✅
- `flutter_localizations` + `intl`, `pubspec.yaml` → `flutter: generate: true`.
- `l10n.yaml` (arb-dir/output `lib/l10n`, sınıf `AppLocalizations`).
- `lib/l10n/app_en.arb` + `app_tr.arb` (temel string'ler). `flutter gen-l10n`
  ile üretildi. `main.dart`'ta `localizationsDelegates` + `supportedLocales` bağlı.
- NOT: String'ler henüz `AppLocalizations` ile DEĞİŞTİRİLMEDİ — yalnızca altyapı kuruldu.

### Crashlytics ✅
- `main.dart`'ta `FlutterError.onError` + `PlatformDispatcher.onError` kaydı;
  oturuma göre `setUserIdentifier`. Android Gradle eklentisi yapılandırıldı.

### Release İmzalama / Keystore Güvenliği 🔐
- Release keystore: `android/app/competra-release.jks`.
- **Bu dosya git'e ASLA eklenmez** — hem kök `.gitignore` hem `android/.gitignore`
  `*.jks` ile yok sayar; dosya git tarafından izlenmiyor (untracked).
- **ÖNEMLİ:** Keystore (ve `key.properties`) güvenli bir yerde yedeklenmelidir
  (parola yöneticisi / şifreli yedek). Keystore kaybedilirse Google Play'de
  yayınlanan uygulama bir daha aynı imzayla güncellenemez. Yedeğin güvenli ve
  erişilebilir bir konumda saklandığı doğrulanmalıdır.

### Dağıtım durumu
- **Firestore indexes:** deploy edildi.
- **Cloud Functions:** deploy edildi (`onMatchWritten`, `onNotificationCreated`).
- **Firestore rules:** deploy edildi.
- **Storage rules:** deploy edildi.

## Komutlar

```bash
# Analiz
flutter analyze

# i18n yeniden üret
flutter gen-l10n

# Release app bundle
flutter build appbundle --release        # çıktı: build/app/outputs/bundle/release/app-release.aab

# Cloud Functions tip kontrol / derleme
cd functions && npx tsc --noEmit         # veya: npm run build

# Deploy (proje: competra-9e396)
firebase deploy --only functions --project competra-9e396
firebase deploy --only firestore:indexes --project competra-9e396
firebase deploy --only firestore:rules --project competra-9e396
```

## Ortam / Bilinen Sorunlar

- **DNS/IPv6 dağıtım sorunu (bu geliştirme makinesi):** Bazı Google API host'ları
  (`firebaserules.googleapis.com`, `cloudfunctions.googleapis.com` vb.) yerel
  resolver'da yalnızca IPv6 (AAAA) döndürüyor ve makinede çalışan global IPv6
  bağlantısı yok → Node `getaddrinfo ENOTFOUND`. Belirtileri:
  - `firestore:rules` deploy başarısız olabilir (firebaserules host'u). Geçici
    çözüm: index deploy'da `firebase.json`'dan `firestore.rules` satırı çıkarılıp
    geri konuldu.
  - `functions` deploy bu host'u atlayamaz; çözüm: ağ/DNS düzeltmesi (hosts dosyası
    ile googleapis host'larını çalışan bir Google IPv4'e yönlendirme, public DNS,
    IPv6'yı etkinleştirme) veya **Google Cloud Shell'den deploy**.
- `firebase-functions` paketi "outdated" uyarısı veriyor (deploy'u engellemiyor;
  yükseltme breaking change içerebilir, ayrı iş olarak ele alınmalı).

## Sıradaki Olası İşler (öneri)

- `firestore.rules`'u deploy etmek (DNS sorunu çözülünce).
- i18n: ekranlardaki sabit Türkçe string'leri `AppLocalizations`'a taşımak.
- Profil fotoğrafı yükleme (maç kartı avatarları şu an baş harf placeholder).
- iOS push yapılandırmasını Mac'te tamamlamak (Info.plist notuna bakın).
