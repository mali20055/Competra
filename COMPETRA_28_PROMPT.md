S# COMPETRA — 28 Prompt (Tam Liste)
> Roadmap'e birebir uygun, Claude Code'a verilmeye hazır
> G1, G2, K1, K2 tamamlandı. K3'ten devam edilecek.

---

## DURUM TABLOSU

| # | Prompt | Durum |
|---|---|---|
| 1 | G1 — Güvenlik Kuralları + Keystore | ✅ TAMAMLANDI |
| 2 | G2 — Hata Yönetimi + Bildirim Akışı | ✅ TAMAMLANDI |
| 3 | K1 — Sabitler + Ölü Kod | ✅ TAMAMLANDI |
| 4 | K2 — Ortak UI + Detail Bölme | ✅ TAMAMLANDI |
| 5 | K3 — CI/CD + Emulator | 🔲 SIRADAKI |
| 6 | K4 — Temel Unit Testler | 🔲 |
| 7 | P1 — Pagination + Query Optimizasyon | 🔲 |
| 8 | P2 — Analytics + App Check + Perf | 🔲 |
| 9 | Y1 — Pull-to-Refresh + Haptic + Confetti + QR | 🔲 |
| 10 | Y2 — Profil Kırpma + Oyuncu Profil Ziyareti | 🔲 |
| 11 | Y3 — Turnuva Düzenleme + Katılımcı Çıkarma + Şablonlar | 🔲 |
| 12 | Y4 — Push Tercihleri + Onboarding İyileştirme | 🔲 |
| 13 | B1 — Head-to-Head + İstatistik Dashboard | 🔲 |
| 14 | B2 — ELO / MMR Derecelendirme | 🔲 |
| 15 | B3 — Arkadaş Aktivite Feed'i | 🔲 |
| 16 | B4 — Başarım Vitrini + Paylaşılabilir Kart | 🔲 |
| 17 | B5 — Çoklu Admin + Takım Havuzu | 🔲 |
| 18 | S1 — Sezon Altyapısı | 🔲 |
| 19 | S2 — Grup Sezonları + Global Sezonluk Lig | 🔲 |
| 20 | S3 — MVP Ödülü + Kazanan Tahmini | 🔲 |
| 21 | W1 — Wrapped 2.0 | 🔲 |
| 22 | M1 — Freemium + Premium Altyapısı | 🔲 |
| 23 | M2 — Özel Tema + Kozmetik | 🔲 |
| 24 | M3 — AdMob Entegrasyonu | 🔲 |
| 25 | I1 — i18n Tam Migrasyon | 🔲 |
| 26 | O1 — Offline Mod | 🔲 |
| 27 | O2 — Turnuva Bracket Görseli | 🔲 |
| 28 | O3 — Web Versiyonu | 🔲 |

---

## ✅ PROMPT 1 — G1 (TAMAMLANDI)
Güvenlik Kuralları + Keystore. Yapılanlar:
- users write allowlist eklendi
- Storage 5MB + image/* sınırı
- notifications alan kısıtı
- friendGroups createdBy kontrolü
- joinByInviteCode status kontrolü
- firestore.rules + storage deploy edildi

---

## ✅ PROMPT 2 — G2 (TAMAMLANDI)
Hata Yönetimi + Bildirim Akışı. Yapılanlar:
- markRead/deleteWheel/recordResult/acceptRequest/declineRequest try/catch
- CF runAchievements + updateFriendGroupStats try/catch
- notifications_screen sahte butonlar düzeltildi
- AppNotification modeline tournamentId/matchId/senderId eklendi
- StreamSubscription yönetimi eklendi
- CF deploy edildi

---

## ✅ PROMPT 3 — K1 (TAMAMLANDI)
Sabitler + Ölü Kod. Yapılanlar:
- lib/core/constants/ (tournament_constants, notification_constants, app_constants)
- lib/core/utils/ (sort_utils, format_labels)
- lib/core/extensions/context_extensions
- achievement_service.dart silindi
- social_repository updateFriendGroupStats + yardımcılar silindi
- sort utils 4 repository'de kullanıma alındı
- format labels 3 ekranda birleştirildi

---

## ✅ PROMPT 4 — K2 (TAMAMLANDI)
Ortak UI + Tournament Detail Bölme. Yapılanlar:
- empty_state, player_avatar, stat_chip, loading_overlay, primary_button bileşenleri
- tournament_detail_screen widget'lara bölündü
- CLAUDE.md güncellendi

---

## 🔲 PROMPT 5 — K3: CI/CD + Firebase Emulator

```
Aşağıdaki görevleri sırasıyla yap:

GÖREV 1 — GitHub Actions CI Pipeline:
Proje kökünde .github/workflows/ klasörü oluştur.
.github/workflows/ci.yml dosyasını oluştur:

name: Competra CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  flutter:
    name: Flutter Analyze & Test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Flutter kurulum
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.35.1'
          channel: stable
          cache: true

      - name: Bağımlılıkları yükle
        run: flutter pub get

      - name: Analiz
        run: flutter analyze

      - name: Testleri çalıştır
        run: flutter test --coverage

  functions:
    name: Cloud Functions Lint & Build
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: functions
    steps:
      - uses: actions/checkout@v4

      - name: Node.js kurulum
        uses: actions/setup-node@v4
        with:
          node-version: '22'
          cache: 'npm'
          cache-dependency-path: functions/package-lock.json

      - name: Bağımlılıkları yükle
        run: npm ci

      - name: ESLint
        run: npm run lint

      - name: TypeScript derleme kontrolü
        run: npx tsc --noEmit

GÖREV 2 — Firebase Emulator Yapılandırması:
firebase.json dosyasını oku.
Mevcut bölümleri (firestore, storage, hosting vb.) koru.
"emulators" bloğunu ekle:

{
  "emulators": {
    "auth": { "port": 9099 },
    "firestore": { "port": 8080 },
    "storage": { "port": 9199 },
    "functions": { "port": 5001 },
    "ui": { "enabled": true, "port": 4000 }
  }
}

GÖREV 3 — Functions Test Altyapısı:
functions/ klasöründe Jest kurulumu yap:
npm install --save-dev jest @types/jest ts-jest firebase-functions-test

functions/jest.config.js dosyası oluştur:
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  testMatch: ['**/tests/**/*.test.ts'],
  collectCoverage: false,
};

functions/package.json scripts bölümüne ekle:
"test": "jest",
"test:watch": "jest --watch"

functions/tests/ klasörü oluştur.
functions/tests/placeholder.test.ts dosyası oluştur:
describe('Cloud Functions', () => {
  it('placeholder - test altyapısı çalışıyor', () => {
    expect(true).toBe(true);
  });
});

GÖREV 4 — .gitignore Güncellemesi:
.gitignore dosyasına şunları ekle (yoksa):
functions/coverage/
.firebase/
.firebaserc.local

GÖREV 5 — CLAUDE.md Güncelleme:
CLAUDE.md'ye şu bilgileri ekle:

### CI/CD
- GitHub Actions: .github/workflows/ci.yml
- Her push/PR'da otomatik: flutter analyze, flutter test, tsc --noEmit, eslint
- Firebase Emulator: firebase emulators:start
  - Auth: 9099, Firestore: 8080, Functions: 5001, UI: 4000
- Functions test: cd functions && npm test

GÖREV 6 — Doğrulama:
flutter analyze çalıştır.
cd functions && npx tsc --noEmit çalıştır.
Her ikisi temiz olduğunu doğrula.

---

BU PROMPTUN SONUNDA ŞUNU YAZ:

## 📋 PROMPT K3 ÖZET RAPORU

### ✅ Tamamlananlar
(Her görev için: ne yapıldı, hangi dosyalar değişti)

### ⚠️ Yarım Kalanlar veya Sorunlar
(Tamamlanamayan görevler, çıkan hatalar)

### 🔍 Dikkat Edilmesi Gerekenler
(Yan etkiler, test edilmesi gereken senaryolar)

### 📊 Genel Durum
(Başarılı mı? Sonraki prompta geçilebilir mi?)
```

---

## 🔲 PROMPT 6 — K4: Temel Unit Testler

```
Aşağıdaki görevleri sırasıyla yap:

GÖREV 1 — Flutter Test Klasörü Yapısı:
test/ altında şu dosyaları oluştur:
test/domain/standings_test.dart
test/domain/fixtures_test.dart
test/domain/validators_test.dart
test/models/tournament_model_test.dart

GÖREV 2 — standings_test.dart:
lib/services/standings_service.dart veya
lib/models/tournament.dart'taki computeStandings
fonksiyonu için testler yaz.

Önce computeStandings'in tam imzasını oku,
sonra aşağıdaki senaryolar için testler yaz:

1. 2 oyuncu, kazanan 3 puan, kaybedenin 0 puanı var,
   kazanan birinci sıraya gelmeli.
2. 2 oyuncu eşit puan, gol averajı üstün olan birinci.
3. 3 oyuncu eşit puan ve eşit averaj olduğunda
   UEFA ikili averaj kuralı devreye girmeli.
4. Bye maçı olan turnuvada bye maçı istatistiğe sayılmamalı.
5. FIFA modu ve UEFA modu aynı girdide farklı sıralama
   üretiyorsa farkı doğrula.
6. computeScorers: en çok gol atan birinci sıraya gelmeli,
   eşit golde maç sayısı az olan üstte.

GÖREV 3 — fixtures_test.dart:
lib/services/fixture_generator.dart için testler yaz.
Önce dosyayı oku, fonksiyon imzalarını gör, sonra yaz:

1. generateLeagueFixtures(4 katılımcı):
   Her çift tam olarak 1 kez eşleşmeli (6 maç toplam).
2. generateLeagueFixtures(3 katılımcı):
   Bye mantığı doğru, 3 tur * 1 maç = 3 maç.
3. generateKnockoutFixtures(8 katılımcı):
   İlk turda 4 maç üretilmeli.
4. generateKnockoutFixtures(5 katılımcı):
   Tek sayıda oyuncuda en az 1 bye olmalı.
5. generateNextKnockoutRound:
   4 kazanandan 2 maç üretilmeli.
6. Çift maçlı eleme (leg parametresi varsa):
   Her eşleşme için 2 maç üretilmeli.

GÖREV 4 — validators_test.dart:
lib/core/validators.dart'ı oku, sonra yaz:

1. Geçerli kullanıcı adı (3-20 karakter) → null döner.
2. 2 karakterlik kullanıcı adı → hata mesajı döner.
3. 21 karakterlik kullanıcı adı → hata mesajı döner.
4. Özel karakter içeren kullanıcı adı (@#!) → hata döner.
5. Geçerli email formatı → null döner.
6. @ içermeyen email → hata döner.
7. Geçerli şifre (6+ karakter) → null döner.
8. 5 karakterlik şifre → hata döner.
9. Şifreler eşleşiyor → null döner.
10. Şifreler eşleşmiyor → hata döner.

GÖREV 5 — tournament_model_test.dart:
lib/models/tournament.dart dosyasını oku, sonra yaz:

1. Tournament.fromDoc eksik alan olduğunda
   varsayılan değerler doğru set ediliyor mu.
2. _normalizeScoreEntry:
   eski 'bothPlayers' → 'doubleEntry' dönüşümü.
3. _normalizeScoreEntry:
   eski 'winnerEnters' → 'winnerEntry' dönüşümü.
4. TournamentMatch.fromDoc:
   legacy 'stage' alanı 'phase'e doğru düşüyor mu.
5. TournamentMatch.isBye:
   bye maçı doğru tanınıyor mu.

GÖREV 6 — Functions Testleri:
functions/tests/ klasöründeki placeholder.test.ts'i
standings.test.ts olarak yeniden yaz veya
yeni standings.test.ts dosyası oluştur.

functions/src/standings.ts dosyasını oku.
computeStandings fonksiyonu için:

1. 2 oyuncu, net bir kazanan → kazanan birinci.
2. Eşit puanda gol averajı devreye giriyor.
3. Dart tarafı ile aynı sonucu üretiyor
   (aynı 4 katılımcı + 6 maç girdisi için
   her iki taraf aynı sıralama vermeli).

GÖREV 7 — Test Çalıştırma:
flutter test çalıştır. Kaç test geçti, kaç başarısız göster.
cd functions && npm test çalıştır. Sonucu raporla.
flutter analyze çalıştır.

---

BU PROMPTUN SONUNDA ŞUNU YAZ:

## 📋 PROMPT K4 ÖZET RAPORU

### ✅ Tamamlananlar
### ⚠️ Yarım Kalanlar veya Sorunlar
### 🔍 Dikkat Edilmesi Gerekenler
### 📊 Genel Durum
```

---

## 🔲 PROMPT 7 — P1: Pagination + Query Optimizasyonu

```
Aşağıdaki görevleri sırasıyla yap:

GÖREV 1 — Bildirim Pagination:
lib/services/notification_repository.dart dosyasını oku.
notificationsProvider'a şunları ekle:
.orderBy('createdAt', descending: true)
.limit(30)   // AppConstants.notificationsLimit kullan

notifications_screen.dart'a "Daha fazla yükle" butonu ekle:
- Liste sonuna gelince buton görünsün
- Son belgeyi startAfterDocument olarak state'te sakla
- Butona basınca bir sonraki 30 bildirimi çek,
  mevcut listeye ekle (replace etme)
- Başka bildirim kalmayınca butonu gizle

GÖREV 2 — Turnuva Listesi Pagination:
lib/services/tournament_repository.dart dosyasını oku.
myTournamentsStreamProvider'a ekle:
.orderBy('createdAt', descending: true)
.limit(20)   // AppConstants.tournamentsLimit kullan

leagues_screen.dart'a pagination ekle:
- ScrollController ile liste sonunu takip et
- Sona gelinince sonraki 20 turnuvayı yükle
- Yükleme sırasında küçük CircularProgressIndicator göster

GÖREV 3 — Liderlik Tablosu Limit:
leaderboard_screen.dart'taki leaderboard sorgusuna
.limit(50) ekle.
"Daha fazla yükle" butonu ekle:
startAfter ile sonraki 50 kayıt.
Her filtre (galibiyet/gol/turnuva) değişince
listeyi sıfırla ve baştan yükle.

GÖREV 4 — Son Maçlar Limiti:
lib/services/user_repository.dart dosyasını oku.
userRecentMatchesProvider'daki her iki
collectionGroup sorgusuna da .limit(20) ekle.

GÖREV 5 — Cloud Functions Okuma Optimizasyonu:
functions/src/index.ts dosyasını oku.
checkTournamentProgression fonksiyonunu bul.

Mevcut sorun: her maç yazımında tüm matches çekiliyor.
Çözüm:

Önce sadece mevcut roundNumber ve phase'e göre filtrele:
const roundSnapshot = await tRef
  .collection('matches')
  .where('roundNumber', '==', currentRound)
  .where('phase', '==', currentPhase)
  .get();

Bu turda hâlâ tamamlanmamış maç varsa erken çık:
const allDone = roundSnapshot.docs.every(
  d => d.data().status === 'completed' || d.data().isBye
);
if (!allDone) return;

Sadece tüm tur bittiyse tam koleksiyon oku
(tur ilerletme veya şampiyon belirlemek için).

GÖREV 6 — Firestore Index Kontrolü:
firestore.indexes.json dosyasını oku.
Şu index'lerin var olduğunu doğrula, eksik olanları ekle:

tournaments: ownerId ASC + createdAt DESC
notifications: userId ASC + createdAt DESC
users: totalWins DESC (leaderboard)
users: totalGoalsScored DESC
users: tournamentsWon DESC
matches (collectionGroup): homeUid ASC
matches (collectionGroup): awayUid ASC

Eksik varsa ekle. Ardından:
firebase deploy --only firestore:indexes --project competra-9e396

GÖREV 7 — Functions Deploy:
functions'ta değişiklik yaptıysan:
firebase deploy --only functions --project competra-9e396
(DNS sorunu olursa hosts dosyasına googleapis IP'lerini ekle)

GÖREV 8 — Doğrulama:
flutter analyze çalıştır.
cd functions && npx tsc --noEmit çalıştır.
Her ikisi temiz olduğunu doğrula.

---

BU PROMPTUN SONUNDA ŞUNU YAZ:

## 📋 PROMPT P1 ÖZET RAPORU

### ✅ Tamamlananlar
### ⚠️ Yarım Kalanlar veya Sorunlar
### 🔍 Dikkat Edilmesi Gerekenler
### 📊 Genel Durum
```

---

## 🔲 PROMPT 8 — P2: Analytics + App Check + Performance

```
Aşağıdaki görevleri sırasıyla yap:

GÖREV 1 — Firebase Analytics Kurulumu:
Terminalde: flutter pub add firebase_analytics

lib/services/analytics_service.dart dosyası oluştur:

import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  static final _a = FirebaseAnalytics.instance;

  static Future<void> logTournamentCreated(String format) =>
      _a.logEvent(name: 'tournament_created',
                  parameters: {'format': format});

  static Future<void> logTournamentJoined() =>
      _a.logEvent(name: 'tournament_joined');

  static Future<void> logMatchScoreEntered() =>
      _a.logEvent(name: 'match_score_entered');

  static Future<void> logWheelSpun() =>
      _a.logEvent(name: 'wheel_spin');

  static Future<void> logWrappedViewed() =>
      _a.logEvent(name: 'wrapped_viewed');

  static Future<void> logShareResult() =>
      _a.logEvent(name: 'share_result');

  static Future<void> logInviteSent() =>
      _a.logEvent(name: 'invite_sent');

  static Future<void> setUserId(String uid) =>
      _a.setUserId(id: uid);
}

Şu yerlere AnalyticsService çağrısı ekle:
- tournament_repository.dart → createTournament başarıyla bitince:
  AnalyticsService.logTournamentCreated(format)
- tournament_repository.dart → joinByInviteCode başarıyla bitince:
  AnalyticsService.logTournamentJoined()
- tournament_repository.dart → updateMatchScore başarıyla bitince:
  AnalyticsService.logMatchScoreEntered()
- wheel_screen.dart → çark çevirme animasyonu başlayınca:
  AnalyticsService.logWheelSpun()
- tournament_wrapped_screen.dart → initState içinde:
  AnalyticsService.logWrappedViewed()
- share_service.dart → paylaşım başarılı olunca:
  AnalyticsService.logShareResult()
- auth_service.dart → başarılı login sonrası:
  AnalyticsService.setUserId(user.uid)

GÖREV 2 — Firebase App Check:
Terminalde: flutter pub add firebase_app_check

main.dart dosyasında Firebase.initializeApp satırından
hemen sonraya ekle:

await FirebaseAppCheck.instance.activate(
  androidProvider: AndroidProvider.playIntegrity,
  appleProvider: AppleProvider.appAttest,
);

import 'package:firebase_app_check/firebase_app_check.dart'; ekle.

NOT: App Check'in tam çalışması için Firebase Console'da
da aktivasyon gerekiyor. Bunu CLAUDE.md'ye not olarak ekle.

GÖREV 3 — Shimmer Skeleton Loading:
pubspec.yaml'da shimmer paketi mevcut.
lib/components/ altına skeleton_widgets.dart oluştur:

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key, this.height = 80});
  final double height;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    final highlight = Theme.of(context).colorScheme.surfaceContainerLow;
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: Container(
        height: height,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

class SkeletonListTile extends StatelessWidget {
  const SkeletonListTile({super.key});

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    final highlight = Theme.of(context).colorScheme.surfaceContainerLow;
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: ListTile(
        leading: CircleAvatar(backgroundColor: base, radius: 20),
        title: Container(height: 14, color: base,
                         margin: const EdgeInsets.only(right: 80)),
        subtitle: Container(height: 10, color: base,
                            margin: const EdgeInsets.only(right: 40, top: 4)),
      ),
    );
  }
}

Şu ekranlarda AsyncValue.loading durumunda
shimmer skeleton göster:

leagues_screen.dart:
  loading: () => Column(children: List.generate(
    4, (_) => const SkeletonCard())),

leaderboard_screen.dart:
  loading: () => Column(children: List.generate(
    6, (_) => const SkeletonListTile())),

social_screen.dart (arkadaş listesi):
  loading: () => Column(children: List.generate(
    4, (_) => const SkeletonListTile())),

GÖREV 4 — CachedNetworkImage Standardizasyonu:
Tüm lib/ altındaki dosyalarda Image.network( kullanımlarını
CachedNetworkImage ile değiştir.

Her yerde şu pattern'i kullan:
CachedNetworkImage(
  imageUrl: url,
  fit: BoxFit.cover,
  placeholder: (ctx, _) => Container(
    color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
    child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
  ),
  errorWidget: (ctx, _, __) => CircleAvatar(
    backgroundColor: Theme.of(ctx).colorScheme.primaryContainer,
    child: Text(
      initials,  // ilgili bağlamdan al
      style: TextStyle(color: Theme.of(ctx).colorScheme.onPrimaryContainer),
    ),
  ),
)

GÖREV 5 — Cloud Functions Cold Start:
functions/src/index.ts dosyasını oku.
onMatchWritten fonksiyonuna minInstances ekle:

export const onMatchWritten = onDocumentWritten(
  {
    document: 'tournaments/{tournamentId}/matches/{matchId}',
    region: 'europe-west3',
    minInstances: 1,
    timeoutSeconds: 60,
  },
  async (event) => {
    // mevcut kod değişmeden kalır
  }
);

onNotificationCreated için minInstances: 0 bırak
(push bildirimi için cold start kabul edilebilir).

GÖREV 6 — Functions Deploy:
firebase deploy --only functions --project competra-9e396

GÖREV 7 — Doğrulama:
flutter analyze çalıştır, temiz olduğunu doğrula.

---

BU PROMPTUN SONUNDA ŞUNU YAZ:

## 📋 PROMPT P2 ÖZET RAPORU

### ✅ Tamamlananlar
### ⚠️ Yarım Kalanlar veya Sorunlar
### 🔍 Dikkat Edilmesi Gerekenler
### 📊 Genel Durum
```

---

## 🔲 PROMPT 9 — Y1: Pull-to-Refresh + Haptic + Confetti + QR

```
Aşağıdaki görevleri sırasıyla yap:

GÖREV 1 — Pull-to-Refresh:
Şu ekranlarda, liste widget'ını RefreshIndicator ile sar:

a) leagues_screen.dart:
onRefresh: () async {
  ref.invalidate(myTournamentsStreamProvider);
  await ref.read(myTournamentsStreamProvider.future)
           .catchError((_) {});
}

b) notifications_screen.dart:
onRefresh: () async {
  ref.invalidate(notificationsProvider);
}

c) leaderboard_screen.dart:
onRefresh: () async {
  ref.invalidate(leaderboardProvider); // doğru provider adını oku
}

d) social_screen.dart:
onRefresh: () async {
  ref.invalidate(friendsProvider);
  ref.invalidate(myFriendGroupsProvider);
}

e) home_screen.dart:
onRefresh: () async {
  ref.invalidate(myTournamentsStreamProvider);
  ref.invalidate(notificationsProvider);
}

Her ekranda color: Theme.of(context).colorScheme.primary kullan.

GÖREV 2 — Haptic Feedback İyileştirmeleri:
Şu yerlere HapticFeedback çağrısı ekle
(import 'package:flutter/services.dart' gerekiyorsa ekle):

a) social_screen.dart veya social_repository çağrısı sonrası:
   Arkadaşlık isteği GÖNDER butonuna basınca:
   HapticFeedback.mediumImpact()

b) social_screen.dart:
   Arkadaşlık isteği KABUL butonuna basınca:
   HapticFeedback.heavyImpact()

c) join_tournament_screen.dart:
   Turnuvaya katılım başarılı olunca:
   HapticFeedback.heavyImpact()

d) create_tournament_screen.dart:
   Turnuva başarıyla oluşturulunca:
   HapticFeedback.heavyImpact()

e) notifications_screen.dart:
   Bildirime okundu işareti atılınca:
   HapticFeedback.lightImpact()

GÖREV 3 — Confetti İyileştirmesi:
tournament_wrapped_screen.dart dosyasını oku.
confetti paketinin doğru kullanıldığını kontrol et:

- ConfettiController dispose ediliyor mu? (dispose içinde)
- Ekran açılınca otomatik başlıyor mu? (initState içinde play())
- Şampiyon slaytında patlama var mı?

Eksik varsa düzelt. Confetti renkleri:
colors: [
  Theme.of(context).colorScheme.primary,
  Theme.of(context).colorScheme.secondary,
  Colors.amber,
  Colors.white,
  Colors.greenAccent,
]

GÖREV 4 — QR Kod ile Katılma:
flutter pub add qr_flutter
flutter pub add mobile_scanner

a) Turnuva detayında QR Modal:
tournament_detail_screen.dart dosyasını oku.
AppBar'a veya paylaş butonunun yanına QR ikonu ekle.
İkona basınca showModalBottomSheet aç:

showModalBottomSheet(
  context: context,
  builder: (_) => Padding(
    padding: const EdgeInsets.all(32),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(tournament.name,
             style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        QrImageView(
          data: 'competra://join/${tournament.inviteCode}',
          size: 200,
          backgroundColor: Colors.white,
        ),
        const SizedBox(height: 12),
        Text('Davet Kodu: ${tournament.inviteCode}',
             style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            // share_plus ile QR görselini veya
            // davet metnini paylaş
            Share.share(
              '${tournament.name} turnuvasına katıl!\n'
              'Kod: ${tournament.inviteCode}\n'
              'competra://join/${tournament.inviteCode}',
            );
          },
          icon: const Icon(Icons.share),
          label: const Text('Paylaş'),
        ),
      ],
    ),
  ),
);

b) Katılma ekranında QR Tarayıcı:
join_tournament_screen.dart dosyasını oku.
Davet kodu alanının altına "QR ile Katıl" butonu ekle:

ElevatedButton.icon(
  onPressed: _scanQR,
  icon: const Icon(Icons.qr_code_scanner),
  label: const Text('QR ile Katıl'),
)

_scanQR metodu:
- Navigator.push ile MobileScannerPage aç
- QR okunduğunda barcodeCapture.barcodes.first.rawValue al
- 'competra://join/' prefix'ini kaldır, kodu al
- _codeController.text = code şeklinde doldur
- Sayfayı kapat

MobileScannerPage widget'ı aynı dosyaya veya
lib/screens/tournament/qr_scanner_screen.dart'a ekle:

class QrScannerScreen extends StatelessWidget {
  const QrScannerScreen({super.key, required this.onCodeScanned});
  final void Function(String code) onCodeScanned;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QR Tara')),
      body: MobileScanner(
        onDetect: (capture) {
          final raw = capture.barcodes.firstOrNull?.rawValue;
          if (raw == null) return;
          final code = raw.replaceFirst('competra://join/', '');
          onCodeScanned(code);
          Navigator.pop(context);
        },
      ),
    );
  }
}

AndroidManifest.xml'e kamera izni ekle (yoksa):
<uses-permission android:name="android.permission.CAMERA"/>

GÖREV 5 — Doğrulama:
flutter analyze çalıştır, temiz olduğunu doğrula.

---

BU PROMPTUN SONUNDA ŞUNU YAZ:

## 📋 PROMPT Y1 ÖZET RAPORU

### ✅ Tamamlananlar
### ⚠️ Yarım Kalanlar veya Sorunlar
### 🔍 Dikkat Edilmesi Gerekenler
### 📊 Genel Durum
```

---

## 🔲 PROMPT 10 — Y2: Profil Fotoğrafı Kırpma + Oyuncu Profili Ziyareti

```
Aşağıdaki görevleri sırasıyla yap:

GÖREV 1 — Profil Fotoğrafı Kırpma:
flutter pub add image_cropper

edit_profile_screen.dart dosyasını oku.
Profil ve kapak fotoğrafı seçiminden sonra kırpma ekle:

Profil fotoğrafı için (1:1 kare):
final croppedFile = await ImageCropper().cropImage(
  sourcePath: picked.path,
  uiSettings: [
    AndroidUiSettings(
      toolbarTitle: 'Profil Fotoğrafını Kırp',
      toolbarColor: Theme.of(context).colorScheme.primary,
      toolbarWidgetColor: Colors.white,
      initAspectRatio: CropAspectRatioPreset.square,
      lockAspectRatio: true,
    ),
  ],
);
if (croppedFile == null) return; // kullanıcı iptal etti

Kapak fotoğrafı için (16:9 yatay):
Aynı yapı ama lockAspectRatio: false,
initAspectRatio: CropAspectRatioPreset.ratio16x9

Kırpma sonucunu upload fonksiyonuna gönder
(mevcut upload kodu değişmez, sadece path değişir).

GÖREV 2 — Oyuncu Profili Ziyareti Route:
route_paths.dart dosyasını oku. Şunları ekle:
static const String userProfile = '/user/:uid';
static const String userProfileName = 'user-profile';

app_router.dart dosyasını oku. Route ekle:
GoRoute(
  path: RoutePaths.userProfile,
  name: RoutePaths.userProfileName,
  builder: (context, state) => UserProfileScreen(
    uid: state.pathParameters['uid'] ?? '',
  ),
),

GÖREV 3 — UserProfileScreen Oluştur:
lib/screens/profile/user_profile_screen.dart dosyası oluştur:

class UserProfileScreen extends ConsumerWidget {
  const UserProfileScreen({super.key, required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // users/{uid} stream'ini dinle
    // Mevcut auth uid ile karşılaştır
    // Kendi profilin → edit_profile_screen'e yönlendir
    // Başkasının profili → ziyaret görünümü göster
  }
}

Ekran içeriği:
- AppBar: kullanıcı adı + geri butonu
- Kapak fotoğrafı (varsa, Stack ile)
- Büyük profil fotoğrafı (CircleAvatar, radius: 50)
- Kullanıcı adı + aktif unvan chip'i
- Bio metni (varsa)
- Favori takım (varsa, ikon + metin)
- İstatistik satırı: 3 chip yan yana
  (Maç: X | Galibiyet: Y | Gol: Z)
- Kazanılmış rozetler grid (en fazla 6, küçük ikonlar)
- "Arkadaş Ekle" butonu:
  → sendFriendRequest çağır, zaten arkadaşsa gizle
- "Arkadaşsınız ✓" chip (zaten arkadaşsa göster)
- Kendi profiline girince:
  → "Profili Düzenle" butonu, diğer butonlar yok

GÖREV 4 — Profil Ziyaret Bağlantıları:
Şu yerlerden UserProfileScreen'e git bağlantısı ekle:

a) social_screen.dart — arkadaş listesindeki her kişiye tıklayınca:
context.pushNamed(
  RoutePaths.userProfileName,
  pathParameters: {'uid': friend.uid},
)

b) leaderboard_screen.dart — sıralamadaki her satıra tıklayınca:
Aynı şekilde uid ile push.

c) tournament_detail_screen.dart — katılımcı listesindeki
her isme tıklayınca:
Aynı şekilde uid ile push.
(Kendi uid'ine tıklayınca profile screen'e git)

GÖREV 5 — Doğrulama:
flutter analyze çalıştır, temiz olduğunu doğrula.

---

BU PROMPTUN SONUNDA ŞUNU YAZ:

## 📋 PROMPT Y2 ÖZET RAPORU

### ✅ Tamamlananlar
### ⚠️ Yarım Kalanlar veya Sorunlar
### 🔍 Dikkat Edilmesi Gerekenler
### 📊 Genel Durum
```

---

## 🔲 PROMPT 11 — Y3: Turnuva Düzenleme + Katılımcı Çıkarma + Şablonlar

```
Aşağıdaki görevleri sırasıyla yap:

GÖREV 1 — Turnuva Düzenleme Ekranı:
route_paths.dart'a ekle:
static const String editTournament = '/tournament/:id/edit';
static const String editTournamentName = 'tournament-edit';

app_router.dart'a route ekle.

lib/screens/tournament/edit_tournament_screen.dart oluştur:

Sadece status == 'waiting' olan turnuvalara erişilebilir.
Ekran açılınca mevcut değerleri form'a doldur.

D�zenlenebilir alanlar:
- Turnuva adı (TextFormField, max 50 karakter)
- Turnuva notu/açıklaması (TextFormField, max 200, nullable)
- Skor giriş modu (DropdownButtonFormField):
    adminOnly → 'Yalnızca Yönetici'
    winnerEntry → 'Kazanan Girer'
    doubleEntry → 'Çift Giriş'
- Tiebreaker modu (DropdownButtonFormField):
    FIFA / UEFA / Karma seçenekleri

Değiştirilemeyen alanlar (disabled + açıklama):
- Format: "Fikstür oluşturulduktan sonra format değiştirilemez"
- Davet kodu: göster ama readonly

Kaydet butonu:
await _tournaments.doc(id).update({
  'name': nameController.text.trim(),
  'note': noteController.text.trim(),
  'scoreEntrySystem': selectedScoreMode,
  'tiebreakerMode': selectedTiebreaker,
});
Başarıda context.pop() ve SnackBar.

tournament_detail_screen.dart'ta:
Turnuva waiting durumundayken ve
currentUser.uid == tournament.ownerId iken
AppBar'a düzenleme ikonu ekle:
onPressed: () => context.pushNamed(
  RoutePaths.editTournamentName,
  pathParameters: {'id': tournament.id},
)

GÖREV 2 — Katılımcı Çıkarma:
tournament_repository.dart'a fonksiyon ekle:

Future<void> removeParticipant({
  required String tournamentId,
  required String participantUid,
}) async {
  final doc = await _tournaments.doc(tournamentId).get();
  final status = (doc.data()?['status'] as String?) ?? '';
  if (status != 'waiting') {
    throw Exception('Başlamış turnuvadan katılımcı çıkarılamaz.');
  }
  // Mevcut participants listesini oku
  final participants = List<Map<String, dynamic>>.from(
    (doc.data()?['participants'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map)),
  );
  // uid'i listeden çıkar
  participants.removeWhere((p) => p['uid'] == participantUid);

  await _tournaments.doc(tournamentId).update({
    'participantIds': FieldValue.arrayRemove([participantUid]),
    'participants': participants,
  });
}

tournament_detail_screen.dart'ta lobi bölümünde
(status == 'waiting' ve currentUser == owner iken):
Her katılımcının yanına küçük "Çıkar" ikonu (Icons.remove_circle_outline).
Tıklayınca AlertDialog:
"[kullanıcı adı] turnuvadan çıkarılsın mı?"
Onaylanınca removeParticipant çağır.
ownerId olan kişinin yanında bu ikon görünmez.

GÖREV 3 — Turnuva Şablonları:
Firestore'a 'templates' koleksiyonu ekle.

firestore.rules'a ekle:
match /templates/{templateId} {
  allow read: if isSignedIn()
    && resource.data.userId == request.auth.uid;
  allow create: if isSignedIn()
    && request.resource.data.userId == request.auth.uid;
  allow update, delete: if isSignedIn()
    && resource.data.userId == request.auth.uid;
}

tournament_repository.dart'a ekle:

Future<void> saveAsTemplate({
  required String name,
  required String format,
  required String scoreMode,
  required String tiebreakerMode,
}) async {
  final uid = _auth.currentUser?.uid;
  if (uid == null) return;
  await _firestore.collection('templates').add({
    'userId': uid,
    'name': name,
    'format': format,
    'scoreMode': scoreMode,
    'tiebreakerMode': tiebreakerMode,
    'createdAt': FieldValue.serverTimestamp(),
  });
}

StreamProvider myTemplatesProvider:
_firestore.collection('templates')
  .where('userId', isEqualTo: uid)
  .orderBy('createdAt', descending: true)
  .limit(10)
  .snapshots()

create_tournament_screen.dart'a ekle:
a) İlk adımda (turnuva adı girme sayfası) üstte
   "Şablondan Başla" butonu:
   Tıklanınca myTemplatesProvider'dan şablonları çek,
   BottomSheet'te listele,
   seçilince form alanlarını doldur.

b) Turnuva başarıyla oluşturulduktan sonra:
   "Şablon olarak kaydet" seçeneği sunan dialog:
   "Bu ayarları gelecekte tekrar kullanmak ister misin?"
   Evet → saveAsTemplate çağır.

GÖREV 4 — Deploy:
firebase deploy --only firestore:rules --project competra-9e396

GÖREV 5 — Doğrulama:
flutter analyze çalıştır, temiz olduğunu doğrula.

---

BU PROMPTUN SONUNDA ŞUNU YAZ:

## 📋 PROMPT Y3 ÖZET RAPORU

### ✅ Tamamlananlar
### ⚠️ Yarım Kalanlar veya Sorunlar
### 🔍 Dikkat Edilmesi Gerekenler
### 📊 Genel Durum
```

---

## 🔲 PROMPT 12 — Y4: Push Tercihleri + Onboarding İyileştirme

```
Aşağıdaki görevleri sırasıyla yap:

GÖREV 1 — Push Bildirim Tercihleri (Flutter Tarafı):
settings_screen.dart dosyasını oku.
"Bildirimler" bölümü ekle:

Firestore'dan mevcut tercihleri oku:
users/{uid}.notificationPrefs map'i (varsayılan: hepsi true)

3 adet SwitchListTile:
- "Maç Onayı Bildirimleri" → key: 'matchConfirm'
- "Turnuva Tamamlanma" → key: 'tournamentComplete'
- "Arkadaşlık İstekleri" → key: 'friendRequest'

Her switch değişince:
await _firestore.collection('users').doc(uid).update({
  'notificationPrefs.$key': value,
});

UserProfile modeline notificationPrefs: Map<String, bool> ekle
(fromDoc'ta data['notificationPrefs'] as Map? ?? {}).

GÖREV 2 — Push Bildirim Tercihleri (Cloud Functions):
functions/src/index.ts'teki onNotificationCreated fonksiyonunu oku.
FCM göndermeden önce tercih kontrolü ekle:

// Hedef kullanıcının tercihlerini kontrol et
const userDoc = await db.collection('users').doc(userId).get();
const prefs = userDoc.data()?.notificationPrefs ?? {};
const notifType = notifData.type as string;

// İlgili tercih false ise push gönderme
if (prefs[notifType] === false) {
  logger.info(`Push skipped: user ${userId} disabled ${notifType}`);
  return;
}
// Mevcut FCM gönderme kodu devam eder...

GÖREV 3 — Onboarding İyileştirme:
onboarding_screen.dart dosyasını oku.
Mevcut yapıyı koru, şunları ekle/düzelt:

a) Her slayta flutter_animate animasyonu ekle
   (pubspec'te flutter_animate varsa kullan, yoksa
   AnimatedOpacity + AnimatedSlide ile yap):

   Slayta ilk kez geçilince:
   - Ana ikon veya görsel: scale 0.8→1.0, 400ms
   - Başlık: fadeIn + slideY, 300ms gecikme ile
   - Açıklama: fadeIn, 500ms gecikme ile

b) Son slayta (Başla sayfası) büyük CTA butonu:
   Mevcut "Başla" butonu varsa güçlendir:
   ElevatedButton(
     style: ElevatedButton.styleFrom(
       minimumSize: const Size(double.infinity, 56),
       textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
     ),
     onPressed: () {
       // onboarding'i tamamla
       // /home'a git
       // create_tournament ekranını push et
     },
     child: const Text('İlk Turnuvanı Oluştur 🏆'),
   )

c) "Atla" butonu:
   Mevcut varsa konumunu sağ üste taşı (Align + Padding).
   Yoksa ekle: TextButton(child: Text('Atla'))

d) Misafir kullanıcı onboarding akışı:
   Onboarding bittikten sonra misafir uyarısı yerine
   home_screen'de ince bir banner göster (GÖREV 4).

GÖREV 4 — Misafir Kullanıcı Banner:
home_screen.dart dosyasını oku.
Misafir (anonim) kullanıcı için ekranın en üstüne
ince bilgi banner'ı ekle:

Koşul: currentUser.isAnonymous == true

Widget:
Container(
  width: double.infinity,
  color: Theme.of(context).colorScheme.primaryContainer,
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  child: Row(
    children: [
      Icon(Icons.info_outline, size: 16,
           color: Theme.of(context).colorScheme.onPrimaryContainer),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          'Misafir modundasın. Verilerini kaybetme!',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
      ),
      TextButton(
        onPressed: () => context.pushNamed(RoutePaths.loginName),
        child: Text('Kayıt Ol',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    ],
  ),
)

GÖREV 5 — Functions Deploy:
functions'ta değişiklik varsa:
firebase deploy --only functions --project competra-9e396

GÖREV 6 — Doğrulama:
flutter analyze çalıştır, temiz olduğunu doğrula.

---

BU PROMPTUN SONUNDA ŞUNU YAZ:

## 📋 PROMPT Y4 ÖZET RAPORU

### ✅ Tamamlananlar
### ⚠️ Yarım Kalanlar veya Sorunlar
### 🔍 Dikkat Edilmesi Gerekenler
### 📊 Genel Durum
```

---

## 🔲 PROMPT 13 — B1: Head-to-Head + İstatistik Dashboard

```
Aşağıdaki görevleri sırasıyla yap:

GÖREV 1 — H2H Route ve Model:
route_paths.dart'a ekle:
static const String h2h = '/h2h/:uid1/:uid2';
static const String h2hName = 'h2h';

app_router.dart'a route ekle:
GoRoute(
  path: RoutePaths.h2h,
  name: RoutePaths.h2hName,
  builder: (context, state) => H2HScreen(
    uid1: state.pathParameters['uid1'] ?? '',
    uid2: state.pathParameters['uid2'] ?? '',
  ),
)

lib/models/h2h_data.dart oluştur:
class H2HData {
  final int uid1Wins;
  final int uid2Wins;
  final int draws;
  final int totalGoalsUid1;
  final int totalGoalsUid2;
  final int totalMatches;
  final List<TournamentMatch> recentMatches; // son 10
}

GÖREV 2 — H2H Provider:
lib/services/user_repository.dart'a FutureProvider ekle:

h2hProvider = FutureProvider.family<H2HData, ({String uid1, String uid2})>(
  (ref, args) async {
    final firestore = ref.read(firestoreProvider);

    // uid1 ev sahibi, uid2 deplasman
    final q1 = await firestore
        .collectionGroup('matches')
        .where('homeUid', isEqualTo: args.uid1)
        .where('awayUid', isEqualTo: args.uid2)
        .where('status', isEqualTo: 'completed')
        .get();

    // uid2 ev sahibi, uid1 deplasman
    final q2 = await firestore
        .collectionGroup('matches')
        .where('homeUid', isEqualTo: args.uid2)
        .where('awayUid', isEqualTo: args.uid1)
        .where('status', isEqualTo: 'completed')
        .get();

    final allMatches = [
      ...q1.docs.map(TournamentMatch.fromDoc),
      ...q2.docs.map(TournamentMatch.fromDoc),
    ];

    // uid1 perspektifinden hesapla
    int uid1Wins = 0, uid2Wins = 0, draws = 0;
    int goalsUid1 = 0, goalsUid2 = 0;

    for (final m in allMatches) {
      final isHome = m.homeUid == args.uid1;
      final myScore = isHome ? (m.homeScore ?? 0) : (m.awayScore ?? 0);
      final oppScore = isHome ? (m.awayScore ?? 0) : (m.homeScore ?? 0);
      goalsUid1 += myScore;
      goalsUid2 += oppScore;
      if (myScore > oppScore) uid1Wins++;
      else if (oppScore > myScore) uid2Wins++;
      else draws++;
    }

    // Son 10 maçı tarihe göre sırala
    allMatches.sort((a, b) =>
        (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));

    return H2HData(
      uid1Wins: uid1Wins, uid2Wins: uid2Wins, draws: draws,
      totalGoalsUid1: goalsUid1, totalGoalsUid2: goalsUid2,
      totalMatches: allMatches.length,
      recentMatches: allMatches.take(10).toList(),
    );
  },
)

GÖREV 3 — H2HScreen Oluştur:
lib/screens/profile/h2h_screen.dart oluştur.

Parametreler: uid1, uid2 (her ikisi için de user profile çek)

Ekran düzeni:
AppBar: "[kullanıcı1] vs [kullanıcı2]"

Özet kart (kartın içinde 3 sütun):
[uid1Wins büyük yeşil] [berabere sayısı küçük gri] [uid2Wins büyük yeşil]
[uid1 avatarı + adı]                              [uid2 avatarı + adı]
Altta toplam maç sayısı

İstatistik karşılaştırma tablosu:
Her satır: [uid1 değer] — [kategori adı] — [uid2 değer]
- Toplam Gol
- Maç Başı Ort. Gol
- Galibiyet Oranı %

Son 10 Maç listesi:
Her satır: [Tarih] [uid1Score - uid2Score] [Turnuva adı]
Kazanan taraf kalın, kaybeden soluk

Boş durum: "Henüz karşılaşmadınız"
Loading: shimmer

GÖREV 4 — H2H Erişim Noktaları:
user_profile_screen.dart'ta:
Arkadaş profilini ziyaret ederken "H2H" butonu ekle:
Tıklayınca:
context.pushNamed(
  RoutePaths.h2hName,
  pathParameters: {'uid1': currentUserUid, 'uid2': profileUid},
)

GÖREV 5 — İstatistik Dashboard Genişletme:
profile_screen.dart dosyasını oku.
Mevcut grafiklerin yanına şunları ekle:

a) Turnuva format dağılımı (PieChart, fl_chart):
   users/{uid}'deki turnuva verilerinden veya
   collectionGroup matches'ten türet.
   Lig / Eleme / Grup+Eleme / ŞL renk kodlu dilimler.
   Boş durumda "Henüz turnuva yok" mesajı.

b) En uzun galibiyet serisi:
   userRecentMatchesProvider'dan hesapla.
   Profil ekranında StatChip olarak göster:
   "🔥 En uzun seri: X maç"

GÖREV 6 — Doğrulama:
flutter analyze çalıştır, temiz olduğunu doğrula.

---

BU PROMPTUN SONUNDA ŞUNU YAZ:

## 📋 PROMPT B1 ÖZET RAPORU

### ✅ Tamamlananlar
### ⚠️ Yarım Kalanlar veya Sorunlar
### 🔍 Dikkat Edilmesi Gerekenler
### 📊 Genel Durum
```

---

## 🔲 PROMPT 14 — B2: ELO / MMR Derecelendirme

```
Aşağıdaki görevleri sırasıyla yap:

GÖREV 1 — Firestore Modeli:
UserProfile modeline ekle:
final int eloRating;        // varsayılan: 1000
final List<Map<String, dynamic>> eloHistory; // varsayılan: []

fromDoc'ta:
eloRating: (data['eloRating'] as int?) ?? 1000,
eloHistory: List<Map<String, dynamic>>.from(
  data['eloHistory'] as List? ?? []),

GÖREV 2 — ELO Cloud Functions Modülü:
functions/src/elo.ts yeni dosyası oluştur:

import * as admin from 'firebase-admin';
const FieldValue = admin.firestore.FieldValue;
const Timestamp = admin.firestore.Timestamp;

export const K_FACTOR = 32;
export const DEFAULT_ELO = 1000;
export const MAX_ELO_HISTORY = 20;

export function expectedScore(ratingA: number, ratingB: number): number {
  return 1 / (1 + Math.pow(10, (ratingB - ratingA) / 400));
}

export function newRating(
  rating: number,
  expected: number,
  actual: number
): number {
  return Math.round(rating + K_FACTOR * (actual - expected));
}

export async function updateElo(
  db: admin.firestore.Firestore,
  homeUid: string,
  awayUid: string,
  homeScore: number,
  awayScore: number
): Promise<void> {
  const [homeSnap, awaySnap] = await Promise.all([
    db.collection('users').doc(homeUid).get(),
    db.collection('users').doc(awayUid).get(),
  ]);

  const homeR = (homeSnap.data()?.eloRating as number) ?? DEFAULT_ELO;
  const awayR = (awaySnap.data()?.eloRating as number) ?? DEFAULT_ELO;

  const homeExp = expectedScore(homeR, awayR);
  const awayExp = expectedScore(awayR, homeR);

  let homeActual: number, awayActual: number;
  if (homeScore > awayScore) { homeActual = 1; awayActual = 0; }
  else if (awayScore > homeScore) { homeActual = 0; awayActual = 1; }
  else { homeActual = 0.5; awayActual = 0.5; }

  const newHome = newRating(homeR, homeExp, homeActual);
  const newAway = newRating(awayR, awayExp, awayActual);
  const now = Timestamp.now();

  await Promise.all([
    db.collection('users').doc(homeUid).update({
      eloRating: newHome,
      eloHistory: FieldValue.arrayUnion([{
        rating: newHome,
        change: newHome - homeR,
        date: now,
      }]),
    }),
    db.collection('users').doc(awayUid).update({
      eloRating: newAway,
      eloHistory: FieldValue.arrayUnion([{
        rating: newAway,
        change: newAway - awayR,
        date: now,
      }]),
    }),
  ]);
}

GÖREV 3 — index.ts'e ELO Entegrasyonu:
functions/src/index.ts dosyasını oku.
En üste import ekle:
import { updateElo } from './elo';

applyMatchStats fonksiyonunda,
istatistikler başarıyla yazıldıktan sonra ekle:

// ELO hesapla (bye maçı değilse)
const isBye = applied.homeUid === 'bye' || applied.awayUid === 'bye';
if (!isBye && applied.homeUid && applied.awayUid) {
  try {
    await updateElo(
      db,
      applied.homeUid,
      applied.awayUid,
      homeGoals,
      awayGoals,
    );
  } catch (err) {
    logger.error('ELO update failed', { err });
  }
}

GÖREV 4 — Flutter ELO Gösterimi:
profile_screen.dart dosyasını oku.
İstatistik bölümüne ELO'yu ekle:

StatChip: "⚡ ELO: {eloRating}"

ELO değişim göstergesi (son maçtan):
Son eloHistory kaydına bak,
change > 0 → "+{change} ↑" yeşil
change < 0 → "{change} ↓" kırmızı
change == 0 → gösterme

lib/screens/profile/widgets/elo_chart.dart oluştur:
Son 10 eloHistory kaydını LineChart ile göster.
x: sıra, y: ELO değeri.
Çizgi rengi: son değer başlangıçtan yüksekse yeşil, düşükse kırmızı.
Noktaları göster (FlDotData).
Boş durum: "Henüz maç yok".

ELO widget'ını profile_screen.dart'ta grafik bölümüne ekle.

GÖREV 5 — Leaderboard ELO Filtresi:
leaderboard_screen.dart dosyasını oku.
Mevcut filtreler: Galibiyet / Gol / Turnuva
Yeni filtre ekle: ELO

ELO sorgusu:
_firestore.collection('users')
  .orderBy('eloRating', descending: true)
  .limit(50)

firestore.indexes.json'a ekle:
users: eloRating DESC

GÖREV 6 — Firestore Rules Güncelleme:
firestore.rules'ta users UPDATE allowlist'ini oku.
eloRating ve eloHistory'nin listede OLMADIĞINI doğrula
(sadece CF yazacak).
Listede varsa çıkar, yoksa işlem yok.

GÖREV 7 — Deploy:
firebase deploy --only functions --project competra-9e396
firebase deploy --only firestore:rules --project competra-9e396
firebase deploy --only firestore:indexes --project competra-9e396

GÖREV 8 — Doğrulama:
flutter analyze çalıştır.
cd functions && npx tsc --noEmit çalıştır.

---

BU PROMPTUN SONUNDA ŞUNU YAZ:

## 📋 PROMPT B2 ÖZET RAPORU

### ✅ Tamamlananlar
### ⚠️ Yarım Kalanlar veya Sorunlar
### 🔍 Dikkat Edilmesi Gerekenler
### 📊 Genel Durum
```

---

## 🔲 PROMPT 15 — B3: Arkadaş Aktivite Feed'i

```
Aşağıdaki görevleri sırasıyla yap:

GÖREV 1 — FeedItem Modeli:
lib/models/feed_item.dart oluştur:

class FeedItem {
  final String id;
  final String type; // 'tournament_won' | 'badge_earned' | 'elo_milestone'
  final String actorUid;
  final String actorName;
  final String? actorPhotoUrl;
  final String message;
  final String? tournamentId;
  final String? badgeId;
  final DateTime? createdAt;
  final bool read;

  // fromDoc factory constructor
  factory FeedItem.fromDoc(DocumentSnapshot<Map<String,dynamic>> doc) { ... }
}

GÖREV 2 — Feed Repository:
lib/services/feed_repository.dart oluştur:

activityFeedProvider = StreamProvider.autoDispose<List<FeedItem>>(
  (ref) {
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return Stream.value([]);
    return ref.read(firestoreProvider)
        .collection('activity_feed')
        .doc(uid)
        .collection('items')
        .orderBy('createdAt', descending: true)
        .limit(30)
        .snapshots()
        .map((s) => s.docs.map(FeedItem.fromDoc).toList());
  },
)

GÖREV 3 — Firestore Rules:
firestore.rules'a ekle:

match /activity_feed/{uid} {
  match /items/{itemId} {
    allow read: if isSignedIn() && request.auth.uid == uid;
    allow write: if false; // sadece Cloud Functions
  }
}

GÖREV 4 — Cloud Functions Fan-Out:
functions/src/index.ts dosyasını oku.

Yeni yardımcı fonksiyon ekle:

async function pushToFriendFeeds(
  db: admin.firestore.Firestore,
  actorUid: string,
  feedItem: Record<string, unknown>
): Promise<void> {
  // Aktörün kabul edilmiş arkadaşlarını bul
  const snap = await db.collection('friendships')
    .where('users', 'array-contains', actorUid)
    .where('status', '==', 'accepted')
    .get();

  if (snap.empty) return;

  const batch = db.batch();
  for (const doc of snap.docs) {
    const users = doc.data().users as string[];
    const friendUid = users.find(u => u !== actorUid);
    if (!friendUid) continue;
    const ref = db
      .collection('activity_feed')
      .doc(friendUid)
      .collection('items')
      .doc();
    batch.set(ref, {
      ...feedItem,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      read: false,
    });
  }
  await batch.commit();
}

finalizeTournament fonksiyonunda şampiyon belirlenince:
try {
  // Şampiyonun adını users koleksiyonundan çek
  const winnerDoc = await db.collection('users').doc(winnerId).get();
  const winnerName = winnerDoc.data()?.username ?? 'Bir oyuncu';
  await pushToFriendFeeds(db, winnerId, {
    type: 'tournament_won',
    actorUid: winnerId,
    actorName: winnerName,
    message: `${winnerName} turnuvayı kazandı! 🏆`,
    tournamentId: tournamentId,
  });
} catch (err) {
  logger.error('Feed fan-out failed (tournament_won)', { err });
}

runAchievements fonksiyonunda rozet verilince:
(deriveAchievementUpdate sonucu incelenerek,
 yeni kazanılan rozet varsa push yap)
try {
  for (const newBadge of newlyEarnedBadges) {
    await pushToFriendFeeds(db, uid, {
      type: 'badge_earned',
      actorUid: uid,
      actorName: userName,
      message: `${userName} yeni bir rozet kazandı! 🎖️`,
      badgeId: newBadge,
    });
  }
} catch (err) {
  logger.error('Feed fan-out failed (badge_earned)', { err });
}

GÖREV 5 — Flutter Feed UI:
home_screen.dart dosyasını oku.
"Son Aktiviteler" veya "Arkadaş Aktivitesi" bölümünü
activityFeedProvider'a bağla.

Her FeedItem için kart:
Row(
  children: [
    CircleAvatar(actorPhotoUrl veya baş harf),
    const SizedBox(width: 12),
    Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.message),
          Text(timeAgoTr(item.createdAt), style: küçük gri),
        ],
      ),
    ),
    if (item.tournamentId != null)
      IconButton(
        icon: const Icon(Icons.arrow_forward_ios, size: 14),
        onPressed: () => context.pushNamed(
          RoutePaths.tournamentDetailName,
          pathParameters: {'id': item.tournamentId!},
        ),
      ),
  ],
)

Boş durum: "Arkadaşlarının aktivitesi burada görünür"
Loading: 3 adet SkeletonListTile

GÖREV 6 — Deploy:
firebase deploy --only functions --project competra-9e396
firebase deploy --only firestore:rules --project competra-9e396

GÖREV 7 — Doğrulama:
flutter analyze çalıştır.
cd functions && npx tsc --noEmit çalıştır.

---

BU PROMPTUN SONUNDA ŞUNU YAZ:

## 📋 PROMPT B3 ÖZET RAPORU

### ✅ Tamamlananlar
### ⚠️ Yarım Kalanlar veya Sorunlar
### 🔍 Dikkat Edilmesi Gerekenler
### 📊 Genel Durum
```

---

## 🔲 PROMPT 16 — B4: Başarım Vitrini + Paylaşılabilir Kart

```
Aşağıdaki görevleri sırasıyla yap:

GÖREV 1 — Vitrin Modeli:
UserProfile modeline ekle:
final List<String> showcaseBadges; // en fazla 3 rozet id'si
fromDoc'ta: List<String>.from(data['showcaseBadges'] as List? ?? [])

GÖREV 2 — Vitrin Seçim Ekranı:
route_paths.dart'a ekle:
static const String badgeShowcase = '/badge-showcase';
static const String badgeShowcaseName = 'badge-showcase';

lib/screens/profile/badge_showcase_screen.dart oluştur:

- Başlık: "Vitrin Rozetlerini Seç"
- Alt başlık: "Profilinde göstermek istediğin 3 rozeti seç"
- Kullanıcının kazandığı rozetleri grid olarak göster
  (badge_definitions.dart'tan isEarned olanları filtrele)
- Her rozete tıklanınca seçili/seçilmez toggle
- En fazla 3 seçilebilir (3. seçilince geri kalanlar disable)
- Seçili rozetler ön planda (border + checkmark)

"Kaydet" butonu:
await _firestore.collection('users').doc(uid).update({
  'showcaseBadges': selectedBadgeIds,
});
Başarıda pop + SnackBar.

GÖREV 3 — Profil Ekranında Vitrin:
profile_screen.dart dosyasını oku.
Rozet bölümünün üstüne "Vitrin" bölümü ekle:

Row ile 3 kutu yan yana (eşit genişlik):
Her kutu:
- showcaseBadges[i] varsa: rozet ikonu + kısa isim
- Yoksa: "+" ikonu, soluk/ghost stil

Tüm kutuya tıklanınca badge_showcase_screen'e git.
Üstte "Vitrin" başlığı + sağda "Düzenle" TextButton.

GÖREV 4 — Paylaşılabilir Başarım Kartı:
lib/widgets/achievement_share_card.dart oluştur:
(Bu widget ekranda render edilmez, RepaintBoundary içinde)

Widget tasarımı (200x350 sabit boyut):
- Arka plan: koyu yeşil (#0D2818) veya tema primary koyu tonu
- Üstte: "⚽ COMPETRA" küçük beyaz metin
- Ortada: Profil fotoğrafı (CircleAvatar, radius 40)
- Kullanıcı adı (büyük, beyaz, bold)
- Aktif unvan (küçük, sarı/altın rengi chip)
- ELO değeri: "⚡ {eloRating}"
- 3 vitrin rozeti ikonu yan yana (varsa)
- İstatistik satırı: "{wins} Galibiyet  {goals} Gol"
- Altta: "competra.app" küçük gri metin

profile_screen.dart'ta AppBar'a veya üst bölgeye
paylaşım ikonu ekle:

_shareAchievement metodu:
1. RenderRepaintBoundary.toImage() ile PNG oluştur
2. Geçici dosyaya kaydet
3. Share.shareXFiles([XFile(path)]) ile paylaş
   text: "${user.username} Competra'da ${user.totalWins} galibiyet! 🏆"

GÖREV 5 — Doğrulama:
flutter analyze çalıştır, temiz olduğunu doğrula.

---

BU PROMPTUN SONUNDA ŞUNU YAZ:

## 📋 PROMPT B4 ÖZET RAPORU

### ✅ Tamamlananlar
### ⚠️ Yarım Kalanlar veya Sorunlar
### 🔍 Dikkat Edilmesi Gerekenler
### 📊 Genel Durum
```

---

## 🔲 PROMPT 17 — B5: Çoklu Admin + Takım/Oyuncu Havuzu

```
Aşağıdaki görevleri sırasıyla yap:

GÖREV 1 — Çoklu Admin Modeli:
Tournament modeline adminIds: List<String> ekle
(fromDoc'ta: List<String>.from(data['adminIds'] as List? ?? []))

tournament_repository.dart'a ekle:
Future<void> addCoAdmin(String tournamentId, String uid) async {
  await _tournaments.doc(tournamentId).update({
    'adminIds': FieldValue.arrayUnion([uid]),
  });
}

Future<void> removeCoAdmin(String tournamentId, String uid) async {
  await _tournaments.doc(tournamentId).update({
    'adminIds': FieldValue.arrayRemove([uid]),
  });
}

GÖREV 2 — Firestore Rules Güncelleme:
firestore.rules dosyasını oku.
isTournamentAdmin yardımcı fonksiyonunu güncelle:

function isTournamentAdmin(tid) {
  let d = get(/databases/$(database)/documents/tournaments/$(tid)).data;
  return isSignedIn() && (
    d.ownerId == request.auth.uid ||
    (d.keys().hasAll(['adminIds']) && request.auth.uid in d.adminIds)
  );
}

GÖREV 3 — Admin Yönetimi UI:
tournament_detail_screen.dart dosyasını oku.
waiting ve active durumundaki turnuvada
sadece ownerId'ye görünür "Yöneticiler" bölümü ekle:

Mevcut admin listesi (adminIds):
- Her adminin adı + "Kaldır" butonu
- Kaldır → removeCoAdmin

"Yardımcı Yönetici Ekle" butonu:
BottomSheet açılır, katılımcı listesi gösterilir (ownerId ve mevcut adminler hariç),
seçilince addCoAdmin çağrılır.

GÖREV 4 — Takım/Oyuncu Havuzu (Roster):
Tournament modeline
roster: List<RosterEntry> ekle.

lib/models/roster_entry.dart oluştur:
class RosterEntry {
  final String uid;
  final String? teamName;
  final String teamColor; // hex renk kodu, varsayılan '#4CAF50'
  factory RosterEntry.fromMap(Map<String, dynamic> map) { ... }
  Map<String, dynamic> toMap() { ... }
}

tournament_repository.dart'a ekle:
Future<void> updateRoster(
  String tournamentId,
  List<RosterEntry> roster,
) async {
  await _tournaments.doc(tournamentId).update({
    'roster': roster.map((e) => e.toMap()).toList(),
  });
}

GÖREV 5 — Roster UI:
tournament_detail_screen.dart'ta lobi bölümünde
(waiting durumu, owner veya admin iken):
Her katılımcının yanına takım rengi circle + takım adı ekle.
"Takım Ata" butonu veya her katılımcıya tıklanınca
küçük bir dialog/bottom sheet aç:

Dialog içeriği:
- Takım adı TextFormField (isteğe bağlı)
- 8 renk seçeneği (küçük daireler):
  Kırmızı, Mavi, Yeşil, Sarı, Mor, Turuncu, Pembe, Beyaz
- Kaydet butonu

Değişiklikler lokal state'te tutulsun.
"Tümünü Kaydet" butonu ile updateRoster çağrılsın.

Maç kartlarında (fixture_tab.dart veya match_card.dart):
homeUid ve awayUid'e karşılık gelen roster kaydı varsa
takım adı ve renk noktası göster.
Roster yoksa kullanıcı adı göster.

GÖREV 6 — Deploy:
firebase deploy --only firestore:rules --project competra-9e396

GÖREV 7 — Doğrulama:
flutter analyze çalıştır, temiz olduğunu doğrula.

---

BU PROMPTUN SONUNDA ŞUNU YAZ:

## 📋 PROMPT B5 ÖZET RAPORU

### ✅ Tamamlananlar
### ⚠️ Yarım Kalanlar veya Sorunlar
### 🔍 Dikkat Edilmesi Gerekenler
### 📊 Genel Durum
```

---

## 🔲 PROMPT 18 — S1: Sezon Altyapısı

```
Aşağıdaki görevleri sırasıyla yap:

GÖREV 1 — Sezon Firestore Modeli:
lib/models/season.dart oluştur:
class Season {
  final String id;
  final String name;       // "Haziran 2026 Sezonu"
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;
  factory Season.fromDoc(DocumentSnapshot<Map<String,dynamic>> doc) { ... }
}

GÖREV 2 — Sezon Repository:
lib/services/season_repository.dart oluştur:

activeSeasonProvider = FutureProvider<Season?>(
  (ref) async {
    final snap = await ref.read(firestoreProvider)
        .collection('seasons')
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return Season.fromDoc(snap.docs.first);
  },
)

GÖREV 3 — Scheduled Functions (Sezon Yönetimi):
functions/src/index.ts dosyasına ekle:

import { onSchedule } from 'firebase-functions/v2/scheduler';

// Her ayın 1'inde çalışır (00:00 Türkiye saati = UTC+3)
export const startNewSeason = onSchedule(
  {
    schedule: '0 21 1 * *',  // UTC 21:00 = TR 00:00
    region: 'europe-west3',
    timeZone: 'Europe/Istanbul',
  },
  async () => {
    const db = admin.firestore();
    const now = new Date();

    // Aktif sezonu kapat
    const activeSnap = await db.collection('seasons')
      .where('isActive', '==', true).get();
    const batch = db.batch();
    for (const doc of activeSnap.docs) {
      batch.update(doc.ref, { isActive: false });
    }

    // Yeni sezon oluştur
    const monthNames = [
      'Ocak','Şubat','Mart','Nisan','Mayıs','Haziran',
      'Temmuz','Ağustos','Eylül','Ekim','Kasım','Aralık'
    ];
    const monthName = monthNames[now.getMonth()];
    const year = now.getFullYear();
    const newSeasonRef = db.collection('seasons').doc();
    batch.set(newSeasonRef, {
      name: `${monthName} ${year} Sezonu`,
      startDate: admin.firestore.Timestamp.now(),
      endDate: admin.firestore.Timestamp.fromDate(
        new Date(year, now.getMonth() + 1, 1)
      ),
      isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    await batch.commit();
    logger.info(`New season started: ${monthName} ${year}`);
  }
);

GÖREV 4 — Kullanıcı Sezon İstatistikleri:
onMatchWritten tetikleyicisinde,
applyMatchStats başarıyla çalıştıktan sonra:
aktif sezonu çek ve users/{uid}.seasonStats.{seasonId} güncelle:

// Aktif sezonu bul
const seasonSnap = await db.collection('seasons')
  .where('isActive', '==', true).limit(1).get();
if (!seasonSnap.empty) {
  const seasonId = seasonSnap.docs[0].id;
  // Her iki oyuncu için sezon istatistiklerini güncelle
  // Aynı userDelta mantığını seasonStats.{seasonId} altında uygula
}

GÖREV 5 — Leaderboard Sezon Filtresi:
leaderboard_screen.dart dosyasını oku.
Üste "Bu Sezon / Tüm Zamanlar" toggle ekle (SegmentedButton).

"Bu Sezon" seçilince:
activeSeasonProvider'dan seasonId al.
users'ta seasonStats.{seasonId}.totalWins DESC ile sırala.

"Tüm Zamanlar" seçilince:
Mevcut sorgular (totalWins DESC vb.).

GÖREV 6 — Sezon Geri Sayım:
home_screen.dart'a küçük sezon bilgisi widget'ı ekle:
"Sezon: {season.name} — {kalan gün} gün kaldı"
activeSeasonProvider'dan veri çek.
Sezon yoksa gösterme.

GÖREV 7 — Firestore Rules:
firestore.rules'a ekle:
match /seasons/{seasonId} {
  allow read: if isSignedIn();
  allow write: if false; // sadece Cloud Functions
}

GÖREV 8 — Deploy:
firebase deploy --only functions --project competra-9e396
firebase deploy --only firestore:rules --project competra-9e396

GÖREV 9 — Doğrulama:
flutter analyze çalıştır.
cd functions && npx tsc --noEmit çalıştır.

---

BU PROMPTUN SONUNDA ŞUNU YAZ:

## 📋 PROMPT S1 ÖZET RAPORU

### ✅ Tamamlananlar
### ⚠️ Yarım Kalanlar veya Sorunlar
### 🔍 Dikkat Edilmesi Gerekenler
### 📊 Genel Durum
```

---

## 🔲 PROMPT 19 — S2: Arkadaş Grubu Sezonları + Sezonluk Global Lig

```
Aşağıdaki görevleri sırasıyla yap:

GÖREV 1 — Grup Sezon Koleksiyonu:
friendGroups/{groupId}/seasons/{seasonId}/memberStats/{uid}
Her belge: {uid, totalWins, totalMatches, totalGoalsScored, totalPoints}

onMatchWritten tetikleyicisinde updateFriendGroupStats
(bu artık Cloud Functions'ta), mevcut grup stats yazımının yanına
sezon-bazlı istatistikleri de yaz:

// Aktif sezonu çek
const seasonSnap = await db.collection('seasons')
  .where('isActive', '==', true).limit(1).get();
if (!seasonSnap.empty) {
  const seasonId = seasonSnap.docs[0].id;
  for (const groupId of sharedGroupIds) {
    // Her iki oyuncu için sezon istatistiklerini güncelle
    db.collection('friendGroups').doc(groupId)
      .collection('seasons').doc(seasonId)
      .collection('memberStats').doc(homeUid)
      .set(homeSeasonDelta, { merge: true });
    // awayUid için de aynısı
  }
}

GÖREV 2 — Grup Sezon Sıralama:
friend_group_screen.dart dosyasını oku.
Grup sıralama bölümüne sezon filtresi ekle:

SegmentedButton:
"Bu Sezon" / "Tüm Zamanlar"

"Bu Sezon" seçilince:
friendGroups/{groupId}/seasons/{seasonId}/memberStats
altındaki tüm belgeleri çek, totalPoints DESC sırala.

"Tüm Zamanlar" seçilince:
Mevcut friendGroups/{groupId}/members sorgusu.

GÖREV 3 — Sezon Sonu Grup Ödülü:
startNewSeason scheduled function'ında
sezon kapanmadan önce:

Her friendGroup için o sezonun en yüksek puanlı üyesini bul.
Bu kişinin badges listesine 'season_group_champion' ekle.
Kullanıcıya bildirim gönder:
"{grup adı} grubunda {sezon adı} şampiyonusun! 🏆"

GÖREV 4 — Sezonluk Global Lig:
startNewSeason'da sezon kapanınca:
Global leaderboard'da o sezon en yüksek ELO'ya sahip top 10 kullanıcıya:
- Özel "season_legend" unvanı ver (title_definitions.dart'a ekle)
  Unvan adı: "{sezon adı} Efsanesi"
- Bildirim gönder

GÖREV 5 — Wrapped Sezon Özeti Slaytı:
tournament_wrapped_screen.dart'a sezon özeti slaytı ekle
(W1 promptu gelene kadar placeholder olarak):

"Bu Sezon" başlıklı slayt:
- Sezonda oynanan toplam maç
- Sezonda kazanılan toplam galibiyet
- ELO değişimi (sezon başı → sonu)
- "Sezon Sona Erdi" veya "Sezon Devam Ediyor"

Veri kaynağı: users/{uid}.seasonStats.{activeSeasonId}

GÖREV 6 — Deploy:
firebase deploy --only functions --project competra-9e396
firebase deploy --only firestore:rules --project competra-9e396

GÖREV 7 — Doğrulama:
flutter analyze çalıştır.
cd functions && npx tsc --noEmit çalıştır.

---

BU PROMPTUN SONUNDA ŞUNU YAZ:

## 📋 PROMPT S2 ÖZET RAPORU

### ✅ Tamamlananlar
### ⚠️ Yarım Kalanlar veya Sorunlar
### 🔍 Dikkat Edilmesi Gerekenler
### 📊 Genel Durum
```

---

## 🔲 PROMPT 20 — S3: MVP Ödülü + Kazanan Tahmini

```
Aşağıdaki görevleri sırasıyla yap:

GÖREV 1 — MVP Oylaması Modeli:
tournaments/{id}/votes/{uid} koleksiyonu:
{ nomineeUid: String, createdAt: Timestamp }

tournament_repository.dart'a ekle:
Future<void> voteMvp(String tournamentId, String nomineeUid) async {
  final uid = _auth.currentUser?.uid;
  if (uid == null) return;
  await _tournaments.doc(tournamentId)
    .collection('votes')
    .doc(uid)
    .set({
      'nomineeUid': nomineeUid,
      'voterUid': uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
}

Future<Map<String, int>> getMvpVotes(String tournamentId) async {
  final snap = await _tournaments.doc(tournamentId)
    .collection('votes').get();
  final counts = <String, int>{};
  for (final doc in snap.docs) {
    final nominee = doc.data()['nomineeUid'] as String?;
    if (nominee != null) counts[nominee] = (counts[nominee] ?? 0) + 1;
  }
  return counts;
}

GÖREV 2 — MVP Oylama UI:
tournament_detail_screen.dart dosyasını oku.
Turnuva 'completed' durumunda
wrapped butonunun yanına "MVP Oyla" butonu ekle
(24 saat sonra kapanacak, ileride timer eklenebilir):

BottomSheet:
"En Değerli Oyuncu'yu Seç"
Katılımcı listesi, her birine tıklanınca:
voteMvp(tournamentId, nomineeUid)
SnackBar: "Oyunuz alındı!"
Daha önce oy verdiyse butonu "Oy Verdim ✓" yap.

Cloud Functions'ta finalizeTournament içinde
(veya ayrı bir onVoteCreated tetikleyicisinde — daha basit
olanı bir scheduled function ile 24 saat sonra sonuçları say):
MVP belgesi: tournaments/{id}.mvpUid alanı set et.
MVP'ye 'mvp' rozeti ver + bildirim gönder.

Basit yaklaşım için şimdilik:
Turnuva completed'dan 1 gün sonra
bir kez getMvpVotes çekip en yüksek oy alanı MVP yap
(bunu UI'dan manuel tetikleme butonu ile yap).

GÖREV 3 — Kazanan Tahmini:
tournaments/{id}/predictions/{uid} koleksiyonu:
{ winnerUid: String, createdAt: Timestamp }

tournament_repository.dart'a ekle:
Future<void> predictWinner(String tournamentId, String winnerUid) async {
  final uid = _auth.currentUser?.uid;
  if (uid == null) return;
  await _tournaments.doc(tournamentId)
    .collection('predictions')
    .doc(uid)
    .set({
      'winnerUid': winnerUid,
      'predictorUid': uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
}

tournament_detail_screen.dart'ta lobi bölümünde
(waiting durumunda, henüz başlamamışken):
"Kazananı Tahmin Et" butonu:
BottomSheet: Katılımcı listesi, birine tıklanınca predictWinner.
"Tahminim: {oyuncu adı}" chip göster (tahmin yaptıktan sonra).

Turnuva bittikten sonra:
Cloud Functions finalizeTournament içinde:
// Tüm tahminleri al
const predsSnap = await tRef.collection('predictions').get();
for (const pred of predsSnap.docs) {
  if (pred.data().winnerUid === winnerId) {
    // Doğru tahmin eden kullanıcıya 'prophet' rozeti ver
    await addBadge(db, pred.data().predictorUid, 'prophet');
    // Bildirim: "Kazananı doğru tahmin ettin! 🔮"
  }
}

badge_definitions.dart'a 'prophet' rozetini ekle:
BadgeDefinition(id: 'prophet', name: 'Kahin',
  description: 'Turnuva kazananını doğru tahmin etti',
  icon: '🔮')

GÖREV 4 — Firestore Rules:
match /tournaments/{tid}/votes/{uid} {
  allow read: if isSignedIn() && isTournamentParticipant(tid);
  allow create: if isSignedIn()
    && request.auth.uid == uid
    && isTournamentParticipant(tid);
  allow update, delete: if false;
}

match /tournaments/{tid}/predictions/{uid} {
  allow read: if isSignedIn() && isTournamentParticipant(tid);
  allow create: if isSignedIn()
    && request.auth.uid == uid
    && isTournamentParticipant(tid);
  allow update, delete: if false;
}

GÖREV 5 — Deploy:
firebase deploy --only functions --project competra-9e396
firebase deploy --only firestore:rules --project competra-9e396

GÖREV 6 — Doğrulama:
flutter analyze çalıştır.
cd functions && npx tsc --noEmit çalıştır.

---

BU PROMPTUN SONUNDA ŞUNU YAZ:

## 📋 PROMPT S3 ÖZET RAPORU

### ✅ Tamamlananlar
### ⚠️ Yarım Kalanlar veya Sorunlar
### 🔍 Dikkat Edilmesi Gerekenler
### 📊 Genel Durum
```

---

## 🔲 PROMPT 21 — W1: Wrapped 2.0

```
Aşağıdaki görevleri sırasıyla yap:

GÖREV 1 — tournament_wrapped_screen.dart'ı oku:
Mevcut slaytları say ve listele.
Slaytların PageView veya AnimatedSwitcher ile mi
yapıldığını belirle. Veri kaynaklarını belirle.

GÖREV 2 — Yeni Slaytlar Ekle:
Mevcut slaytları koru, aralarına yenilerini ekle:

Slayt sırası:
1. Şampiyon (mevcut) — confetti iyileştirmesi (GÖREV 3)
2. Gol Krallığı (mevcut)
3. MVP Ödülü (YENİ):
   tournaments/{id}/votes'tan en çok oyu alanı göster.
   "Turnuvanın MVP'si: {oyuncu adı} 🏅"
   Votes yoksa bu slaytı atla (slayt sayısını dinamik tut)
4. En Dramatik Maç (mevcut — varsa, yoksa ekle):
   En yakın skorlu maçı bul (|homeScore-awayScore| en küçük),
   "En çekişmeli maç: {oyuncu1} {skor} {oyuncu2}"
5. ELO Değişimleri (YENİ):
   Her katılımcının ELO kazanımını listele:
   En çok ELO kazanan: "+{değişim} ⚡"
   En çok kaybeden: "-{değişim}"
   (B2 tamamlandıktan sonra eloHistory'den veri gelir,
    tamamlanmadıysa placeholder text göster)
6. Demir Duvar (mevcut — varsa, en az gol yiyen)
7. Turnuva Zaman Çizelgesi (YENİ):
   "Turnuva {startDate} tarihinde başladı"
   "{totalDays} günde tamamlandı"
   "Toplam {totalMatches} maç oynandı"
   "{busiestDay} tarihinde {maxMatches} maç oynandı"
   (maçların createdAt'larından hesapla)
8. Özet İstatistikler (mevcut + genişlet):
   Toplam gol, en golcü oyuncu, toplam maç, ortalama skor

GÖREV 3 — Confetti İyileştirmesi:
Şampiyon slaytında (1. slayt):
- Slayta girilince confetti.play() tetiklenir
- Farklı renklerde yağmur efekti
- Şampiyon kullanıcı avatarı parlıyor (Container ile glow efekti)

GÖREV 4 — Her Slayta Paylaşım Butonu:
Her slaytın altına küçük paylaşım butonu ekle:
Icons.share_outlined
Tıklanınca o slaytı RepaintBoundary ile görüntü al + paylaş.
Her slaytın RepaintBoundary'si için GlobalKey list tut.

GÖREV 5 — "Tümünü Paylaş" Butonu:
Son slaytta veya AppBar'da büyük bir paylaşım butonu:
"Wrapped'ı Paylaş"
Tüm slaytları tek tek görüntü al, zip değil,
en önemli 3 slaytı (şampiyon, gol krallığı, özet) paylaş.
Share.shareXFiles([...]) ile.

GÖREV 6 — Dinamik Slayt Sayısı:
Bazı slaytlar veri yoksa atlanmalı (MVP, ELO).
final slides = <Widget>[];
if (champion != null) slides.add(ChampionSlide(...));
if (topScorer != null) slides.add(TopScorerSlide(...));
if (mvpVotes.isNotEmpty) slides.add(MvpSlide(...));
// vb.
PageView.builder(itemCount: slides.length, ...)

GÖREV 7 — Doğrulama:
flutter analyze çalıştır, temiz olduğunu doğrula.

---

BU PROMPTUN SONUNDA ŞUNU YAZ:

## 📋 PROMPT W1 ÖZET RAPORU

### ✅ Tamamlananlar
### ⚠️ Yarım Kalanlar veya Sorunlar
### 🔍 Dikkat Edilmesi Gerekenler
### 📊 Genel Durum
```

---

## 🔲 PROMPT 22 — M1: Freemium + Premium Altyapısı

```
Aşağıdaki görevleri sırasıyla yap:

GÖREV 1 — RevenueCat Kurulumu:
flutter pub add purchases_flutter

main.dart'ta Firebase başlatıldıktan sonra:
import 'package:purchases_flutter/purchases_flutter.dart';

await Purchases.configure(
  PurchasesConfiguration('YOUR_REVENUECAT_PUBLIC_KEY'),
);

NOT: RevenueCat public key'i şimdilik placeholder bırak,
gerçek key sonradan girilecek. Bunu CLAUDE.md'ye not ekle.

GÖREV 2 — Premium Durumu Servisi:
lib/services/premium_service.dart oluştur:

class PremiumService {
  static Future<bool> isPremium() async {
    try {
      final info = await Purchases.getCustomerInfo();
      return info.entitlements.active.containsKey('premium');
    } catch (_) {
      return false;
    }
  }

  static Future<void> purchase(String packageId) async {
    final offerings = await Purchases.getOfferings();
    final package = offerings.current?.availablePackages
        .firstWhere((p) => p.identifier == packageId);
    if (package != null) {
      await Purchases.purchasePackage(package);
    }
  }

  static Future<void> restorePurchases() async {
    await Purchases.restorePurchases();
  }
}

lib/services/firebase_providers.dart'a ekle:
final isPremiumProvider = FutureProvider<bool>(
  (ref) => PremiumService.isPremium(),
)

GÖREV 3 — UserProfile Premium Alanı:
UserProfile modeline isPremium: bool ekle (varsayılan: false).
NOT: isPremium alanı Firestore'da saklanmayacak,
RevenueCat'tan gerçek zamanlı kontrol edilecek.
Ancak CF'ten bazı premium özellikler için
users/{uid}.isPremium yazılabilir (opsiyonel).

GÖREV 4 — Premium Paywall Ekranı:
lib/screens/settings/premium_screen.dart oluştur:

AppBar: "Competra Pro"

Avantajlar listesi:
✅ Reklamsız deneyim
✅ Sınırsız turnuva
✅ ELO geçmişi ve gelişmiş istatistikler
✅ Özel temalar ve kozmetikler
✅ Öncelikli destek

Fiyat bilgisi:
"₺49.99 / ay" veya "₺299.99 / yıl (en iyi değer)"

2 büyük buton:
- "Aylık Abone Ol" → Purchases.purchasePackage(monthlyPackage)
- "Yıllık Abone Ol" → Purchases.purchasePackage(yearlyPackage)

"Mevcut satın alımları geri yükle" TextButton
"Gizlilik Politikası" ve "Kullanım Koşulları" linkleri

GÖREV 5 — Premium Gate:
Şu yerlere premium kontrolü ekle:

a) tournament_repository.dart'ta createTournament:
   Ücretsiz kullanıcı için aktif turnuva sayısını kontrol et.
   Firestore'da o kullanıcının status=='active' turnuvalarını say.
   3'ten fazlaysa ve premium değilse Exception fırlat:
   "Ücretsiz hesaplarda en fazla 3 aktif turnuva oluşturabilirsin."
   Fırlatan kodu try/catch ile yakala, UI'da paywall aç.

b) Leaderboard ELO filtresi (B2'de eklendiyse) premium-only yap.

c) settings_screen.dart'a "Competra Pro" menü öğesi ekle:
   premium_screen.dart'a yönlendir.

GÖREV 6 — Doğrulama:
flutter analyze çalıştır, temiz olduğunu doğrula.

---

BU PROMPTUN SONUNDA ŞUNU YAZ:

## 📋 PROMPT M1 ÖZET RAPORU

### ✅ Tamamlananlar
### ⚠️ Yarım Kalanlar veya Sorunlar
### 🔍 Dikkat Edilmesi Gerekenler
### 📊 Genel Durum
```

---

## 🔲 PROMPT 23 — M2: Özel Tema + Kozmetik

```
Aşağıdaki görevleri sırasıyla yap:

GÖREV 1 — Tema Sistemi:
lib/core/theme/app_themes.dart oluştur:

enum AppThemeId { fieldAndGlory, nightArena, goldTrophy, oceanLeague }

class AppThemeConfig {
  final AppThemeId id;
  final String name;
  final bool isPremium;
  final ColorScheme lightScheme;
  final ColorScheme darkScheme;
}

Temalar:
1. fieldAndGlory (varsayılan, ücretsiz):
   Mevcut yeşil tema — değişmez.

2. nightArena (premium):
   primary: Color(0xFF7B2FBE)  // mor
   secondary: Color(0xFF3D0066)
   surface: Color(0xFF0A0010)
   Koyu mor/siyah atmosfer.

3. goldTrophy (premium):
   primary: Color(0xFFFFB300)  // altın sarısı
   secondary: Color(0xFFFF6F00)
   surface: Color(0xFF1A1200)
   Altın/koyu kombini.

4. oceanLeague (premium):
   primary: Color(0xFF0277BD)  // okyanus mavisi
   secondary: Color(0xFF00897B)
   surface: Color(0xFF001529)
   Mavi/yeşil deniz teması.

GÖREV 2 — Tema Yönetimi:
lib/core/theme/theme_notifier.dart oluştur:

class ThemeNotifier extends Notifier<AppThemeId> {
  @override
  AppThemeId build() => AppThemeId.fieldAndGlory;

  Future<void> setTheme(AppThemeId id) async {
    // SharedPreferences'a kaydet
    state = id;
  }

  Future<void> loadSavedTheme() async {
    // SharedPreferences'tan yükle
  }
}

final themeNotifierProvider = NotifierProvider<ThemeNotifier, AppThemeId>(
  ThemeNotifier.new);

main.dart'ta MaterialApp.router'da:
theme: AppThemes.getTheme(ref.watch(themeNotifierProvider), Brightness.light),
darkTheme: AppThemes.getTheme(ref.watch(themeNotifierProvider), Brightness.dark),

GÖREV 3 — Tema Seçim Ekranı:
lib/screens/settings/theme_screen.dart oluştur:

AppBar: "Temalar"

Her tema için büyük önizleme kartı:
- Tema adı
- Küçük renk paleti (3 circle)
- Premium rozeti (premium temalar için)
- "Aktif" etiketi (seçili tema)

Ücretsiz temalar: direkt seç.
Premium temalar: isPremiumProvider kontrol et,
değilse premium_screen'e yönlendir.

settings_screen.dart'a "Tema" menü öğesi ekle.

GÖREV 4 — Avatar Çerçeveleri:
lib/models/avatar_frame.dart oluştur:

class AvatarFrame {
  final String id;
  final String name;
  final bool isPremium;
  final Color primaryColor;
  final Color? secondaryColor;
  // Gradient veya solid border
}

Tanımlı çerçeveler:
- 'default': Yok (sade)
- 'gold': Altın çerçeve (rozet kazanımıyla veya premium)
- 'champion': Kupa ikonu ile çerçeve (şampiyon rozeti olanlar)
- 'flame': Alev animasyonu çerçeve (premium)

lib/components/player_avatar.dart'ı güncelle:
activeFrame parametresi ekle, çerçeveye göre
Container dekorasyonu uygula:
BoxDecoration(
  shape: BoxShape.circle,
  border: Border.all(color: frame.primaryColor, width: 3),
  // veya gradient border için ShaderMask
)

UserProfile modeline activeFrame: String ekle (varsayılan: 'default').

GÖREV 5 — Kozmetik IAP:
settings_screen.dart veya theme_screen.dart'a
"Kozmetik Mağaza" bölümü ekle (basit liste):

Her kozmetik için kart:
- İkon/önizleme
- İsim ve açıklama
- Fiyat butonu: "₺14.99" veya "Premium'a Dahil"

Şimdilik placeholder butonlar koy
(M1'de RevenueCat kurulduktan sonra bağlanacak).
Her biri için ayrı product ID tanımla.

GÖREV 6 — Doğrulama:
flutter analyze çalıştır, temiz olduğunu doğrula.

---

BU PROMPTUN SONUNDA ŞUNU YAZ:

## 📋 PROMPT M2 ÖZET RAPORU

### ✅ Tamamlananlar
### ⚠️ Yarım Kalanlar veya Sorunlar
### 🔍 Dikkat Edilmesi Gerekenler
### 📊 Genel Durum
```

---

## 🔲 PROMPT 24 — M3: AdMob Entegrasyonu

```
Aşağıdaki görevleri sırasıyla yap:

GÖREV 1 — AdMob Kurulumu:
flutter pub add google_mobile_ads

android/app/src/main/AndroidManifest.xml'e ekle
(<application> tagının içine):
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="ca-app-pub-XXXXXXXXXXXXXXXX~XXXXXXXXXX"/>

NOT: Gerçek AdMob app ID sonradan girilecek.
Şimdilik test ID kullan:
android: ca-app-pub-3940256099942544~3347511713

lib/services/ad_service.dart oluştur:

import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  // Test ID'leri — prodüksiyonda değiştirilecek
  static const _rewardedAdId =
      'ca-app-pub-3940256099942544/5224354917'; // Android test

  static RewardedAd? _rewardedAd;
  static bool _isAdReady = false;

  static Future<void> initialize() async {
    await MobileAds.instance.initialize();
  }

  static Future<void> loadRewardedAd() async {
    await RewardedAd.load(
      adUnitId: _rewardedAdId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isAdReady = true;
        },
        onAdFailedToLoad: (err) {
          _isAdReady = false;
        },
      ),
    );
  }

  static Future<bool> showRewardedAd({
    required VoidCallback onRewarded,
  }) async {
    if (!_isAdReady || _rewardedAd == null) return false;
    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _isAdReady = false;
        loadRewardedAd(); // sonraki için önceden yükle
      },
    );
    await _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) => onRewarded(),
    );
    return true;
  }
}

main.dart'ta:
await AdService.initialize();
await AdService.loadRewardedAd();

GÖREV 2 — Çark Ödüllü Reklam:
wheel_screen.dart dosyasını oku.
Çark çevirme limitini ekle:

SharedPreferences'ta günlük çevirme sayısını tut:
key: 'wheel_spins_{date}' (bugünün tarihi ile)
varsayılan: 0

Her çark çevirmeden önce kontrol:
- Günlük limit 3 ise ve sayaç >= 3 ise:
  _showAdForExtraSpin() çağır
- Limit altındaysa direkt çevir ve sayacı artır

_showAdForExtraSpin:
showDialog(
  "Günlük çevirme hakkın doldu",
  "30 saniye reklam izleyerek 1 hak kazan",
  [İptal, Reklam İzle]
)

"Reklam İzle" seçilince:
AdService.showRewardedAd(
  onRewarded: () {
    // Reklam izlendi, çark çevirilsin
    _spinWheel();
  },
)

GÖREV 3 — Premium Reklam Bypass:
isPremiumProvider'ı kontrol et.
Premium kullanıcılara limit ve reklam gösterme.
Doğrudan çevirsin.

GÖREV 4 — UMP (GDPR Consent):
main.dart'ta AdService.initialize() öncesine ekle:

final params = ConsentRequestParameters();
ConsentInformation.instance.requestConsentInfoUpdate(
  params,
  () async {
    if (await ConsentInformation.instance.isConsentFormAvailable()) {
      ConsentForm.loadAndShowConsentFormIfRequired((formError) {});
    }
  },
  (error) {},
);

GÖREV 5 — CLAUDE.md Güncelleme:
CLAUDE.md'ye ekle:
- AdMob test App ID: ca-app-pub-3940256099942544~3347511713
- Rewarded Ad test unit: ca-app-pub-3940256099942544/5224354917
- Prodüksiyon'a geçmeden gerçek ID'ler alınmalı
- RevenueCat key: [placeholder]

GÖREV 6 — Doğrulama:
flutter analyze çalıştır, temiz olduğunu doğrula.

---

BU PROMPTUN SONUNDA ŞUNU YAZ:

## 📋 PROMPT M3 ÖZET RAPORU

### ✅ Tamamlananlar
### ⚠️ Yarım Kalanlar veya Sorunlar
### 🔍 Dikkat Edilmesi Gerekenler
### 📊 Genel Durum
```

---

## 🔲 PROMPT 25 — I1: i18n Tam Migrasyon

```
Aşağıdaki görevleri sırasıyla yap:

GÖREV 1 — Mevcut ARB Durumunu İncele:
lib/l10n/ klasörünü oku.
app_tr.arb ve app_en.arb dosyalarının mevcut içeriğini gör.
Kaç string var, eksikler neler?

GÖREV 2 — Tüm Hard-Coded String'leri Tara:
lib/ altında tüm .dart dosyalarında
Türkçe metin içeren Text() widget'larını tara.
En az 30 kritik string'i listele.

GÖREV 3 — ARB Dosyalarını Tamamla:
app_tr.arb ve app_en.arb dosyalarını güncelle.
Şu kategorilerdeki tüm string'leri ekle:

Auth:
- loginTitle, registerTitle, emailLabel, passwordLabel
- loginButton, registerButton, guestButton
- forgotPassword, resetPassword
- logoutConfirm

Turnuva:
- createTournament, joinTournament, startTournament
- tournamentFormats (lig, eleme, grupKnockout, championsLeague)
- tournamentStatuses (waiting, active, completed)
- matchConfirmTitle, matchDisputeTitle
- scoreEntryMode (adminOnly, winnerEntry, doubleEntry)

Sosyal:
- sendRequest, cancelRequest, acceptRequest, declineRequest
- friends, friendGroups, leaderboard
- createGroup, joinGroup

Genel:
- save, cancel, confirm, delete, edit, share, back
- loading, error, empty, retry
- settings, profile, notifications

Hata mesajları:
- networkError, unknownError
- tournamentFull, tournamentClosed
- usernameExists, emailExists

GÖREV 4 — Kritik Ekranlarda String Geçişi:
Şu ekranlardaki Text() widget'larını AppLocalizations ile değiştir:

a) auth/ klasörü (login_screen.dart):
   Text('Giriş Yap') → Text(l10n.loginTitle)
   Text('E-posta') → Text(l10n.emailLabel)
   Vb. tüm string'ler

b) screens/tournament/create_tournament_screen.dart:
   Turnuva oluşturma ekranındaki tüm label'lar

c) screens/settings/settings_screen.dart:
   Ayarlar menüsündeki tüm başlıklar

d) screens/home/home_screen.dart:
   Ana sayfa başlıkları ve butonlar

Her ekranda:
final l10n = AppLocalizations.of(context)!;

GÖREV 5 — Dil Seçimi:
settings_screen.dart'a dil seçimi ekle:

lib/services/app_settings.dart'ı oku/güncelle.
Locale tercihi SharedPreferences'ta sakla.

main.dart'ta localeResolutionCallback:
locale: savedLocale ?? deviceLocale,
supportedLocales: AppLocalizations.supportedLocales,
localizationsDelegates: AppLocalizations.localizationsDelegates,

Settings'te:
DropdownButtonFormField<Locale>:
  - 🇹🇷 Türkçe (tr)
  - 🇬🇧 English (en)

Seçilince app restart olmadan locale değişsin
(MaterialApp.router'ı Consumer ile sar).

GÖREV 6 — flutter gen-l10n Çalıştır:
flutter gen-l10n

Üretilen dosyaların hatasız olduğunu doğrula.
flutter analyze çalıştır.

---

BU PROMPTUN SONUNDA ŞUNU YAZ:

## 📋 PROMPT I1 ÖZET RAPORU

### ✅ Tamamlananlar
### ⚠️ Yarım Kalanlar veya Sorunlar
### 🔍 Dikkat Edilmesi Gerekenler
### 📊 Genel Durum
```

---

## 🔲 PROMPT 26 — O1: Offline Mod

```
Aşağıdaki görevleri sırasıyla yap:

GÖREV 1 — Bağlantı Takibi:
flutter pub add connectivity_plus

lib/services/connectivity_service.dart oluştur:

final connectivityProvider = StreamProvider<bool>(
  (ref) => Connectivity()
      .onConnectivityChanged
      .map((result) => result != ConnectivityResult.none),
)

final isOnlineProvider = Provider<bool>(
  (ref) => ref.watch(connectivityProvider).valueOrNull ?? true,
)

GÖREV 2 — Offline Banner:
lib/components/offline_banner.dart oluştur:

class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider);
    if (isOnline) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.error,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: Row(
        children: [
          Icon(Icons.wifi_off, size: 14,
               color: Theme.of(context).colorScheme.onError),
          const SizedBox(width: 8),
          Text(
            'Çevrimdışı — veriler kaydedilecek',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onError,
            ),
          ),
        ],
      ),
    );
  }
}

scaffold_with_nav_bar.dart dosyasını oku.
AppBar altına OfflineBanner ekle.

GÖREV 3 — Firestore Offline Persistence Optimizasyonu:
main.dart'ta FirebaseFirestore.instanceFor() veya
FirebaseFirestore.instance ayarları:

FirebaseFirestore.instance.settings = const Settings(
  persistenceEnabled: true,
  cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
);

(Bu zaten varsayılan açık olabilir, kontrol et,
 açıksa zaten çalışıyor)

GÖREV 4 — Offline Skor Girişi:
flutter pub add hive_ce
flutter pub add hive_ce_flutter

lib/models/pending_score.dart oluştur:
@HiveType(typeId: 0)
class PendingScore extends HiveObject {
  @HiveField(0) late String tournamentId;
  @HiveField(1) late String matchId;
  @HiveField(2) late int homeScore;
  @HiveField(3) late int awayScore;
  @HiveField(4) late DateTime createdAt;
}

lib/services/offline_score_service.dart oluştur:

class OfflineScoreService {
  static Box<PendingScore>? _box;

  static Future<void> init() async {
    Hive.registerAdapter(PendingScoreAdapter());
    _box = await Hive.openBox<PendingScore>('pending_scores');
  }

  static Future<void> saveScore(PendingScore score) async {
    await _box?.add(score);
  }

  static List<PendingScore> getPendingScores() =>
      _box?.values.toList() ?? [];

  static Future<void> clearScore(int index) async {
    await _box?.deleteAt(index);
  }
}

tournament_repository.dart'ta updateMatchScore'u güncelle:
İnternet yoksa (isOnlineProvider false ise):
- OfflineScoreService.saveScore() ile local'e kaydet
- SnackBar: "Çevrimdışısınız. Skor bağlantı gelince gönderilecek."
- return (exception fırlatma)

İnternet gelince sync:
connectivityProvider'ı dinle, online olunca:
final pending = OfflineScoreService.getPendingScores();
for (final s in pending) {
  try {
    await updateMatchScore(
      tournamentId: s.tournamentId,
      matchId: s.matchId,
      homeScore: s.homeScore,
      awayScore: s.awayScore,
    );
    await OfflineScoreService.clearScore(index);
  } catch (_) {
    // Başarısız olursa listede kalsın
  }
}

main.dart'ta OfflineScoreService.init() çağır.

GÖREV 5 — Doğrulama:
flutter analyze çalıştır, temiz olduğunu doğrula.

---

BU PROMPTUN SONUNDA ŞUNU YAZ:

## 📋 PROMPT O1 ÖZET RAPORU

### ✅ Tamamlananlar
### ⚠️ Yarım Kalanlar veya Sorunlar
### 🔍 Dikkat Edilmesi Gerekenler
### 📊 Genel Durum
```

---

## 🔲 PROMPT 27 — O2: Turnuva Bracket Görseli

```
Aşağıdaki görevleri sırasıyla yap:

GÖREV 1 — Bracket Veri Yapısı:
tournament_detail_screen.dart ve fixture_tab.dart dosyalarını oku.
Mevcut maç verilerinin nasıl yapılandırıldığını anla.

Bracket için gerekli veri:
- Eleme turnuvalarında roundNumber ve order alanları
- homeUid, awayUid, homeScore, awayScore, status
- isBye

Bracket için veriyi hazırlayan yardımcı fonksiyon yaz:
(lib/core/utils/bracket_utils.dart)

/// Maç listesini bracket tree yapısına dönüştürür.
/// Dönüş: round bazında gruplandırılmış maç listesi.
/// [[tur1Maç1, tur1Maç2], [tur2Maç1], [final]]
List<List<TournamentMatch>> buildBracketTree(
  List<TournamentMatch> matches,
  String phase, // 'knockout'
) {
  final rounds = <int, List<TournamentMatch>>{};
  for (final m in matches.where((m) => m.phase == phase || m.stage == phase)) {
    final r = m.roundNumber ?? 0;
    rounds.putIfAbsent(r, () => []).add(m);
  }
  final sortedKeys = rounds.keys.toList()..sort();
  return sortedKeys.map((k) {
    final list = rounds[k]!..sort((a, b) => (a.order ?? 0).compareTo(b.order ?? 0));
    return list;
  }).toList();
}

GÖREV 2 — BracketPainter (CustomPainter):
lib/screens/tournament/widgets/bracket_painter.dart oluştur:

class BracketPainter extends CustomPainter {
  final List<List<TournamentMatch>> rounds;
  final Map<String, String> playerNames; // uid → kullanıcı adı
  final ColorScheme colorScheme;

  // Sabitler
  static const double boxWidth = 130;
  static const double boxHeight = 48;
  static const double horizontalGap = 40;
  static const double verticalGap = 16;

  @override
  void paint(Canvas canvas, Size size) {
    // Her tur için x konumunu hesapla
    // Her maç çifti için y konumunu hesapla
    // Her maç kutusu çiz (drawMatchBox)
    // Kutuları bağlayan çizgileri çiz (drawConnectorLines)
  }

  void drawMatchBox(Canvas canvas, Offset topLeft,
                    TournamentMatch match, String homeName, String awayName) {
    final paint = Paint()..color = colorScheme.surfaceContainerHigh;
    // Arka plan kutu
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(topLeft.dx, topLeft.dy, boxWidth, boxHeight * 2),
      const Radius.circular(8),
    );
    canvas.drawRRect(rect, paint);

    // Kazanan vurgulaması
    // Oyuncu adları ve skorlar text olarak çiz
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    // Home oyuncu
    textPainter.text = TextSpan(
      text: '${homeName.length > 12 ? homeName.substring(0, 12) : homeName}',
      style: TextStyle(color: colorScheme.onSurface, fontSize: 12),
    );
    textPainter.layout(maxWidth: boxWidth - 40);
    textPainter.paint(canvas, Offset(topLeft.dx + 8, topLeft.dy + 8));
    // Skor
    // Away oyuncu
    // vb.
  }

  void drawConnectorLines(Canvas canvas, Offset fromRight, Offset toLeft) {
    final paint = Paint()
      ..color = colorScheme.outline
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final midX = (fromRight.dx + toLeft.dx) / 2;
    final path = Path()
      ..moveTo(fromRight.dx, fromRight.dy)
      ..lineTo(midX, fromRight.dy)
      ..lineTo(midX, toLeft.dy)
      ..lineTo(toLeft.dx, toLeft.dy);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(BracketPainter old) =>
      old.rounds != rounds || old.playerNames != playerNames;
}

GÖREV 3 — Bracket Widget ve Sekme:
lib/screens/tournament/widgets/bracket_tab.dart oluştur:

Sadece eleme veya bracket aşaması olan turnuvalarda göster.
Yatay kaydırılabilir (SingleChildScrollView horizontal):
InteractiveViewer ile zoom desteği.

RepaintBoundary ile sar (paylaşım için).

tournament_detail_screen.dart dosyasını oku.
Uygun formatlarda (knockout, groupKnockout, championsLeague)
"Bracket" adında yeni sekme ekle.

Grup + Eleme formatında:
- Grup aşaması: mevcut standings_tab kullan
- Eleme aşaması: bracket_tab kullan
- Sekme geçişi tur ilerledikçe otomatik değişebilir

GÖREV 4 — Bracket Paylaşımı:
bracket_tab.dart'ta "Paylaş" butonu ekle:
RepaintBoundary key'inden image al.
Share.shareXFiles ile paylaş.
Text: "Turnuva braketi! {tournament.name}"

GÖREV 5 — Doğrulama:
flutter analyze çalıştır, temiz olduğunu doğrula.

---

BU PROMPTUN SONUNDA ŞUNU YAZ:

## 📋 PROMPT O2 ÖZET RAPORU

### ✅ Tamamlananlar
### ⚠️ Yarım Kalanlar veya Sorunlar
### 🔍 Dikkat Edilmesi Gerekenler
### 📊 Genel Durum
```

---

## 🔲 PROMPT 28 — O3: Web Versiyonu

```
Aşağıdaki görevleri sırasıyla yap:

GÖREV 1 — Flutter Web Hazırlığı:
flutter pub get
flutter build web --release

Build başarılı olursa devam et.
Hata varsa hataları listele ve çöz.

web/index.html dosyasını oku.
<title>Competra</title> olduğunu doğrula.
manifest.json'daki app adı ve ikonları kontrol et.

GÖREV 2 — Responsive Layout Kontrol:
Şu ekranları web'de çalışıp çalışmadığını kontrol et
(flutter run -d chrome ile açarak):

Kritik ekranlar:
- login_screen.dart
- home_screen.dart
- tournament_detail_screen.dart
- leaderboard_screen.dart

Web'de sorun çıkan yaygın sorunlar:
- LayoutBuilder olmayan sabit genişlik widget'lar
- Kaydırma davranışı (web'de mouse scroll)
- CachedNetworkImage (web'de çalışıyor mu kontrol et)
- Image.file (web'de çalışmaz, Image.network kullan)

Tespit edilen sorunları listele.

GÖREV 3 — Temel Responsive Düzeltmeler:
home_screen.dart, leagues_screen.dart,
leaderboard_screen.dart için:

Geniş ekranda (> 600px) 2 sütunlu grid:
LayoutBuilder(builder: (context, constraints) {
  if (constraints.maxWidth > 600) {
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 3.0,
        crossAxisSpacing: 16,
        mainAxisSpacing: 8,
      ),
      ...
    );
  }
  return ListView.builder(...); // mobil düzen
})

GÖREV 4 — Firebase Hosting Yapılandırması:
firebase.json dosyasını oku.
"hosting" bölümü yoksa ekle:

"hosting": {
  "public": "build/web",
  "ignore": ["firebase.json", "**/.*", "**/node_modules/**"],
  "rewrites": [
    { "source": "**", "destination": "/index.html" }
  ],
  "headers": [
    {
      "source": "**/*.@(js|css)",
      "headers": [{"key": "Cache-Control", "value": "max-age=31536000"}]
    }
  ]
}

GÖREV 5 — PWA Desteği:
web/manifest.json'ı kontrol et.
Şu alanların mevcut olduğunu doğrula:
- name: "Competra"
- short_name: "Competra"
- start_url: "/"
- display: "standalone"
- background_color, theme_color
- icons (192x192 ve 512x512)

web/index.html'de service worker kaydı var mı kontrol et.
Flutter web varsayılan olarak SW üretiyor.

GÖREV 6 — Web Build ve Deploy:
flutter build web --release --web-renderer canvaskit

firebase deploy --only hosting --project competra-9e396
(DNS sorunu varsa hosts dosyasını hatırlat)

Deploy başarılıysa URL'yi raporla.

GÖREV 7 — CLAUDE.md Güncelleme:
Web versiyonu ile ilgili notları ekle:
- Web URL: competra-{project}.web.app
- Build komutu: flutter build web --release
- Deploy: firebase deploy --only hosting
- Renderer: canvaskit (html renderer'a göre trade-off)
- Bilinen web kısıtlamaları: image_picker, image_cropper,
  mobile_scanner web'de çalışmaz, koşullu import gerekir

GÖREV 8 — Doğrulama:
flutter analyze çalıştır, temiz olduğunu doğrula.

---

BU PROMPTUN SONUNDA ŞUNU YAZ:

## 📋 PROMPT O3 ÖZET RAPORU

### ✅ Tamamlananlar
### ⚠️ Yarım Kalanlar veya Sorunlar
### 🔍 Dikkat Edilmesi Gerekenler
### 📊 Genel Durum
```

---

*Dosya sonu — COMPETRA_28_PROMPT.md*
*Toplam: 28 prompt | G1-G2 tamamlandı | K3'ten devam*
