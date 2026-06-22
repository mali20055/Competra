# COMPETRA — Kapsamlı Kod Analiz Raporu (V3)

> **Tarih:** 2026-06-22
> **Kapsam:** `lib/` altındaki tüm Dart dosyaları (52 dosya, ~15.850 satır), `functions/src/` altındaki tüm TypeScript dosyaları (5 dosya), `pubspec.yaml`, `firebase.json`, `firestore.rules`, `storage.rules`, `firestore.indexes.json`, `android/app/build.gradle.kts`, `AndroidManifest.xml`, `CLAUDE.md`.
> **Yöntem:** Yalnızca mevcut kaynak kod statik olarak incelendi. Bir önceki rapor (V2, 2026-06-16) ile karşılaştırmalı değerlendirme yapıldı.
> **Önceki sürümle fark:** V2'deki **kritik mimari sorun (istemci-tarafı istatistik yazımının güvenlik kurallarıyla çelişmesi)** bu sürümde **Cloud Functions** eklenerek çözülmüştür. Bu rapor yeni mimariyi değerlendirir.

---

## İçindekiler

1. Yönetici Özeti
2. Mimari Analiz
3. Kritik Hatalar ve Riskler
4. Güvenlik Analizi (Detaylı)
5. Performans Analizi (Detaylı)
6. Kod Kalitesi Analizi
7. Klasör Yapısı ve Mimari Öneri
8. Frontend Geliştirme Önerileri
9. Backend Geliştirme Önerileri
10. Firebase Tarafındaki Geliştirme Önerileri
11. Yeni Özellik Önerileri (25+)
12. Ek API ve Servis Önerileri
13. Monetizasyon Stratejileri
14. Test Stratejisi
15. DevOps ve Yayına Hazırlık
16. Ölçeklenebilirlik Analizi
17. Kullanıcı Deneyimi (UX) Derin Analizi
18. Teknik Borç Analizi
19. Öncelikli Yol Haritası
20. Kapanış Değerlendirmesi

---

## 1. YÖNETİCİ ÖZETİ

### 1.1 Genel Durum ve Olgunluk Seviyesi

Competra; **Flutter 3.35 + Riverpod 3 + GoRouter 17 + Firebase (Auth/Firestore/Storage/Crashlytics/FCM) + Cloud Functions (TypeScript, v2)** üzerine kurulu, görsel ve mimari olarak **olgun** bir arkadaşlar-arası turnuva uygulamasıdır. V2'ye kıyasla en büyük sıçrama, güvenlik açısından hassas tüm yazma işlemlerinin (istatistik, şampiyon, tur ilerletme) **sunucuya (Cloud Functions) taşınması** ve `firestore.rules`'un buna göre sıkılaştırılmasıdır.

Uygulama, **"ileri MVP / beta'ya hazır"** seviyededir. Çekirdek özellikler (turnuva, fikstür, skor, puan tablosu, sosyal, çark, rozet, bildirim) uçtan uca çalışır durumdadır. Yayına engel teşkil eden **fonksiyonel bir bloklayıcı kalmamıştır**; kalan eksikler ağırlıkla **kalite, test, güvenlik sertleştirmesi ve ölçeklenebilirlik** kategorisindedir.

### 1.2 En Kritik 5 Bulgu

| # | Bulgu | Yön | Önem |
|---|---|---|---|
| 1 | **Cloud Functions ile istemci/sunucu paritesi kuruldu.** İstatistik/şampiyon/tur ilerletme artık admin SDK ile sunucuda, idempotent (`statsApplied`) yapılıyor. V2'nin yayın bloklayıcısı çözüldü. | 🟢 Pozitif | Kritik |
| 2 | **Hiç anlamlı test yok.** Yalnızca varsayılan `widget_test.dart` mevcut. Karmaşık tiebreaker/fikstür/tur-ilerletme mantığı (Dart **ve** TS'de iki kez yazılmış) hiç test edilmiyor; iki port arasında sessiz sapma riski yüksek. | 🔴 Negatif | Kritik |
| 3 | **`_emailForUsername` geçici anonim oturum açıyor** (`auth_service.dart:41`). Giriş/şifre-sıfırlama akışında oturumsuz kullanıcı için `signInAnonymously()` → arama → `signOut()` yapılıyor; bu kırılgan, yan etkili ve yetim anonim hesap üretebilir. Callable Function ile değiştirilmeli (kod yorumu da bunu kabul ediyor). | 🔴 Negatif | Yüksek |
| 4 | **Firebase App Check yok, Cloud Functions rate-limiting yok, `notifications` create kuralı hâlâ geniş.** Herhangi bir giriş yapmış kullanıcı başka herhangi birine bildirim yazabiliyor (spam/spoofing yüzeyi). | 🔴 Negatif | Yüksek |
| 5 | **`tournament_detail_screen.dart` 2.405 satır.** Tek dosyada onlarca private widget; bakım ve rebuild maliyeti yüksek. Genel olarak ekran dosyaları çok büyük (5 dosya 800+ satır). | 🟡 Karışık | Orta |

### 1.3 Modül Bazlı Puanlama (1-10)

| Modül | V3 Puanı | V2 | Gerekçe |
|---|---|---|---|
| **UI/UX** | 8/10 | 8/10 | Tutarlı tema, animasyon, boş/yükleme durumları. Erişilebilirlik ve responsive eksikleri sürüyor. |
| **Backend** | 7/10 | 4/10 | Cloud Functions ile büyük sıçrama; idempotent transaction'lar. Scheduled/callable fonksiyon yok, tek tetikleyici tüm yükü taşıyor. |
| **Güvenlik** | 6/10 | 3/10 | Kurallar ciddi sertleşti; istemci-güvenli istatistik. App Check/rate-limit yok, notification create geniş, anonim-oturum hilesi. |
| **Performans** | 6/10 | 6/10 | Küçük ölçekte iyi. `collectionGroup('members')` N+1, tüm `matches` çekme, pagination yok, cold start yönetilmiyor. |
| **Kod Kalitesi** | 7/10 | 7/10 | İyi yorumlu, tutarlı. Aşırı uzun dosyalar, magic string, Dart↔TS mantık tekrarı. |
| **Test Coverage** | 1/10 | 1/10 | Hiç test yok. |
| **DevOps** | 4/10 | 3/10 | İmzalama yapılandırması var; CI/CD, emülatör, otomasyon yok. DNS/deploy sorunu belgelenmiş. |
| **Ölçeklenebilirlik** | 6/10 | 5/10 | europe-west3 tekil bölge; index tasarımı makul. Liderlik tablosu/collectionGroup darboğaz adayı. |
| **Kullanıcı Deneyimi** | 7/10 | 7/10 | Onboarding + wrapped + gamification güçlü; gerçek zamanlılık (StreamProvider) iyi. Pagination/offline boşlukları var. |

**Ağırlıklı ortalama: ~5.8/10** (V2: ~4.6/10). Net iyileşme: **+1.2**, ağırlıklı olarak Backend ve Güvenlik eksenlerinde.

### 1.4 V2'ye Göre Gelişim

| Konu | V2 Durumu | V3 Durumu |
|---|---|---|
| İstatistik yazımı | 🔴 İstemci yazıyordu, kurallarla çelişiyordu (yayın bloklayıcı) | 🟢 Cloud Functions (admin SDK), idempotent `statsApplied` |
| Şampiyon/tur ilerletme | 🔴 İstemci, transaction yok | 🟢 Sunucu, `runTransaction` + `currentRound`/`currentPhase` koruması |
| Push bildirim | ❌ Yoktu | 🟢 FCM uçtan uca (`onNotificationCreated` + `NotificationService`) |
| `usernames` herkese açık okuma (e-posta sızıntısı) | 🔴 `allow read: if true` | 🟢 `allow read: if isSignedIn()` (ama bkz. anonim-oturum hilesi) |
| Çift maçlı eleme (ŞL) | ❌ Yoktu | 🟢 `leg` alanı + iki ayaklı üretim/çözüm |
| i18n altyapısı | Kısmi | 🟢 ARB + gen-l10n kurulu (string'ler henüz taşınmadı) |
| Crashlytics | Kısmi | 🟢 `FlutterError.onError` + `PlatformDispatcher.onError` |
| Test | 🔴 Yok | 🔴 Hâlâ yok |
| Notification onay/itiraz ekranı | 🔴 Sahte buton | 🔴 Hâlâ stub (`notifications_screen.dart:213` "Şimdilik...") |

### 1.5 Tahmini Tamamlanma (MVP)

| Kategori | Tamamlanma |
|---|---|
| Çekirdek işlevsellik (turnuva/skor/tablo/sosyal) | ~%90 |
| Sunucu mantığı (Functions) | ~%80 |
| Güvenlik sertleştirme | ~%65 |
| Test & QA | ~%5 |
| DevOps & yayın hazırlığı (Android) | ~%55 |
| iOS hazırlığı | ~%30 (Info.plist notları, Mac'te tamamlanacak) |
| **Genel MVP** | **~%75** |

---

## 2. MİMARİ ANALİZ

### 2.1 Genel Mimari Değerlendirme

Katmanlı (layered) bir mimari uygulanmıştır:

```
UI (screens/, components/)
   ↓ ref.watch / ref.read
State + Veri Erişimi (services/ → Riverpod Provider + Repository)
   ↓ Firestore SDK
Firebase (Auth / Firestore / Storage / Messaging)
   ↑ onWrite / onCreate tetikleyicileri
Sunucu Mantığı (functions/src/ → admin SDK)
```

**Güçlü yanlar:**
- Ekranlar Firebase'e **doğrudan değil**, `firebase_providers.dart`'taki tekil sağlayıcılar üzerinden erişiyor → test edilebilirlik ve mock kolaylığı.
- Repository deseni tutarlı: her domain (`tournament`, `user`, `social`, `wheel`, `notification`) kendi repository + provider'ına sahip.
- Canlı veri `StreamProvider` ile; `family` varyantları parametrik kaynaklar için doğru kullanılmış.
- **İstemci/sunucu paritesi**: `functions/src/*.ts`, `lib/services/*.dart` ve `lib/models/*.dart` ile aynı alan adlarını ve normalizasyon kurallarını kullanıyor (örn. `parseMatch` ↔ `TournamentMatch.fromDoc`, `computeStandings` iki dilde birebir).

**Zayıf yanlar:**
- **Mantık çift yazımı (DRY ihlali, mimari ölçekte):** `computeStandings`, tüm fixture üreticiler ve tiebreaker hem Dart hem TS'de var. İstemci önizleme için Dart'ı, sunucu otorite için TS'yi kullanıyor; ancak **tek doğruluk kaynağı yok**. İki taraf saparsa istemci farklı bir şampiyon gösterip sunucu farklısını yazabilir.
- **UI katmanında iş mantığı sızıntısı:** `tournament_detail_screen.dart` puan tablosu/gol krallığı hesabını (`computeStandings`, `computeScorers`) doğrudan widget `build`'inde çağırıyor (her rebuild'de yeniden hesap).
- Repository'ler bazen UI'a özgü davranış içeriyor (örn. `markDisputed` içinde bildirim metni Türkçe gömülü).

### 2.2 Flutter İstemci Mimarisi

- **Riverpod 3:** `Provider`, `StreamProvider`, `FutureProvider.autoDispose`, `NotifierProvider` doğru kullanılmış. `currentUserProvider` `authStateProvider`'ı senkron okuyor (`asData?.value`) — basit ama splash'te yarış potansiyeli (bkz. §3).
- **GoRouter 17:** `StatefulShellRoute.indexedStack` ile 5 sekmeli bottom-nav, durum koruması doğru. Deep link `redirect` mantığı `competra://join/KOD` ve `/join/KOD` formatlarını normalize ediyor (`app_router.dart:42`).
- **Tema:** `app_theme.dart` tamamen `ColorScheme` tabanlı; açık/koyu mod `ThemeModeNotifier` ile (varsayılan koyu). Hard-coded renk neredeyse yok.
- **Eksik:** Router'da **auth guard / redirect yok**. Oturum durumuna göre yönlendirme yalnızca splash'te tek seferlik yapılıyor; oturum koparsa korumalı route'lar boş veri ile kalır.

### 2.3 Cloud Functions Mimarisi

İki tetikleyici:

1. **`onMatchWritten`** (`tournaments/{tid}/matches/{mid}` onWrite, `index.ts:49`):
   - `becameFinal` idempotent geçişi (`isFinal(after) && !isFinal(before)`) → `applyMatchStats` (tek transaction, `statsApplied` damgası) → arkadaş grubu istatistikleri → rozet türetimi.
   - Her yazımda `checkTournamentProgression` (format'a göre tur ilerletme/şampiyon).
2. **`onNotificationCreated`** (`notifications/{id}` onCreate, `index.ts:111`):
   - Hedef `users/{userId}.fcmToken` okur, FCM push gönderir, geçersiz token'ı temizler.

**Değerlendirme:**
- ✅ İdempotentlik iyi düşünülmüş: `statsApplied`, `currentRound`/`currentPhase` transaction koruması, `status === 'completed'` erken çıkış.
- ✅ Tur ilerletme tek/çift maçlı (away-goals) mantığı doğru modellenmiş (`resolveTieWinner`).
- ⚠️ **Tek tetikleyici tüm yükü taşıyor:** `onMatchWritten` her maç yazımında **tüm** `matches` koleksiyonunu okuyor (`tRef.collection("matches").get()`). 100+ maçlı turnuvada her skor girişinde tam okuma → maliyet/gecikme.
- ⚠️ **`updateFriendGroupStats` collectionGroup taraması** her tamamlanan maçta iki `collectionGroup('members')` sorgusu yapıyor (oyuncu başına).
- ⚠️ **Cold start:** v2 fonksiyonlar için `minInstances`, `concurrency`, region ayarı kodda yok (varsayılanlar).
- ❌ **Callable/Scheduled fonksiyon yok:** kullanıcı arama, hesap silme temizliği, davet-kodu çözümü gibi işler hâlâ istemcide.

### 2.4 Firestore Veri Modeli Tutarlılığı

| Koleksiyon | Anahtar alanlar | Tutarlılık notu |
|---|---|---|
| `users/{uid}` | username, usernameLower, email, totalMatches, totalWins, ..., badges, activeTitle, fcmToken | İstatistik alanları yalnız Functions yazar. Geriye dönük varsayılanlar iyi. |
| `usernames/{key}` | uid, username, email | Benzersizlik + e-posta eşlemesi. `create`/`delete` var, `update` yok (yarış koruması). |
| `tournaments/{id}` | name, format, ownerId, participantIds[], participants[], status, currentPhase, currentRound, tiebreakerMode, inviteCode | `participantIds` (sorgu) + `participants` (denormalize) çift tutuluyor; senkron tutmak istemciye bağlı. |
| `.../matches/{id}` | round, roundNumber, order, phase/stage, group, leg, homeUid/awayUid, skorlar, status, statsApplied | `phase` yoksa `stage`'e düşülüyor (legacy). `leg` çift maçlı için. |
| `.../participants/{uid}` | matchesPlayed, points, goalsFor/Against... | Yalnız Functions yazar. |
| `friendships/{id}` | users[], requesterId, recipientId, status, summaries | Denormalize özet iyi. |
| `friendGroups/{id}` + `members/{uid}` | name, createdBy, memberCount; üye istatistikleri | Üye istatistikleri Functions yazar. |
| `wheels/{id}` | ownerId, name, teams[], lastResults[] | Basit, sahip-bazlı. |
| `notifications/{id}` | userId, type, title, message, tournamentId?, matchId?, read | Create kuralı geniş (bkz. §4). |

**Tutarsızlık/risk noktaları:**
- `scoreMode` (eski) ve `scoreEntrySystem` (kanonik) ikisi de yazılıyor; model normalize ediyor ama veri çift.
- `participantIds` ve `participants` arasında atomik garanti yok: `joinByInviteCode` ikisini birlikte `arrayUnion` ediyor, ama bir taraf başarısız olursa sapma olabilir.
- Maçta ayrı "oynanma zamanı" alanı yok; "son maçlar" `createdAt + order` ile yaklaşık (`user_repository.dart:90`).

### 2.5 İstemci ↔ Sunucu Sorumluluk Dağılımı

| İşlem | İstemci | Sunucu |
|---|---|---|
| Turnuva oluştur/katıl/başlat | ✅ | — |
| Maç skoru yaz | ✅ (sadece skor/onay alanları) | — |
| İstatistik artışı | ❌ | ✅ Functions |
| Şampiyon/tur ilerletme | ❌ (önizleme hesabı için Dart var) | ✅ Functions |
| Rozet/unvan | İstemcide `AchievementService` **var ama artık çağrılmıyor** (ölü kod adayı) | ✅ Functions |
| Bildirim push | ❌ | ✅ Functions |
| Kullanıcı arama / davet kodu çözümü | ✅ (geniş okuma + anonim oturum hilesi) | ❌ (callable olmalı) |

**Bulgu:** `lib/services/achievement_service.dart` ve `social_repository.dart` içindeki `updateFriendGroupStats`, sunucuya taşındıktan sonra **istemcide kullanılmıyor olabilir** → ölü kod / kafa karışıklığı.

### 2.6 Bağımlılık Grafiği / Circular Dependency Riski

- `services/*` → `firebase_providers.dart` → Firebase SDK (tek yönlü, temiz).
- `notification_service.dart` → `router/app_router.dart` (yönlendirme için). `AppRouter` statik; `NotificationService` de statik → **gizli global bağ**. Router henüz kurulmadan push gelirse `AppRouter.router` erişimi sorun olabilir (pratikte main'de init sırası koruyor).
- Modeller saf (Firebase dışında bağımlılık yok) — iyi.
- **Döngüsel bağımlılık tespit edilmedi.** Tek dikkat: `NotificationService` (servis) → `AppRouter` (router) ters yön bağ; ileride router'a `redirect`/observer enjekte ederek gevşetilmeli.

### 2.7 Önerilen Mimari İyileştirmeler (kod örnekleriyle)

**(a) UI'dan hesaplamayı çıkar — `select` + memoize.** Puan tablosunu provider'a taşı:

```dart
// services/tournament_repository.dart
final standingsProvider =
    Provider.family<List<StandingRow>, ({String id, TiebreakerMode mode})>((ref, args) {
  final matches = ref.watch(matchesStreamProvider(args.id)).valueOrNull ?? const [];
  final t = ref.watch(tournamentStreamProvider(args.id)).valueOrNull;
  if (t == null) return const [];
  return computeStandings(t.participants, matches, args.mode);
});
```
Böylece her widget rebuild'inde değil, yalnız maç/tablo değiştiğinde hesaplanır.

**(b) Auth guard'ı router'a taşı:**

```dart
GoRouter(
  refreshListenable: GoRouterRefreshStream(FirebaseAuth.instance.authStateChanges()),
  redirect: (context, state) {
    final signedIn = FirebaseAuth.instance.currentUser != null;
    final loggingIn = state.matchedLocation == RoutePaths.login;
    if (!signedIn && _isProtected(state.matchedLocation)) return RoutePaths.login;
    if (signedIn && loggingIn) return RoutePaths.home;
    return null;
  },
);
```

**(c) Hesaplama mantığını tek dile indir:** Uzun vadede istemci, tabloyu **sunucudan denormalize** okusun (örn. `tournaments/{id}/standings` belgesi Functions tarafından yazılır). Böylece Dart↔TS çift bakım ortadan kalkar.

---

## 3. KRİTİK HATALAR VE RİSKLER

| # | Konum | Açıklama | Risk | Çözüm |
|---|---|---|---|---|
| 3.1 | `auth_service.dart:41-62` `_emailForUsername` | Oturumsuz girişte `signInAnonymously()` açıp arama yapıp `signOut()` ediyor. İstisna/ağ kopması olursa `finally` blokunda signOut atlanabilir; ayrıca FCM/authState listener'ları tetiklenir, yetim anonim hesap üretebilir. | 🟠 Yüksek | Callable Function `resolveUsernameEmail(username)` ile değiştir; istemci hiç anonim oturum açmasın. |
| 3.2 | `tournament_repository.dart:92` `joinByInviteCode` | `status` kontrolü yok. Turnuva **başlamış/bitmiş** olsa bile kullanıcı katılımcı listesine eklenebilir; fikstürde yer almadığı için "hayalet katılımcı" olur. | 🟠 Yüksek | `status == 'waiting'` değilse `TournamentClosedException` fırlat. |
| 3.3 | `splash_screen.dart:58` | `FirebaseAuth.instance.currentUser`'ı doğrudan okuyor; `authStateChanges` henüz emit etmemişse (token yenileme gecikmesi) yanlış route. | 🟡 Orta | `authStateChanges().first` bekle veya router redirect kullan. |
| 3.4 | `index.ts:353` `checkTournamentProgression` | Her maç yazımında **tüm** `matches` koleksiyonu okunuyor. Büyük turnuvada her skorda tam tarama → gecikme + maliyet + transaction çakışma artışı. | 🟡 Orta | Yalnız ilgili tur/faz maçlarını sorgula (`where('roundNumber','==',currentRound)`). |
| 3.5 | `tournament_repository.dart:126` `startTournament` | Tek `batch` 500 işlem sınırı. ~30 oyuncuda lig fikstürü 435 maç → sınıra yaklaşır; daha fazlası sessizce patlar. | 🟡 Orta | `WriteBatch` parçalama veya BulkWriter; oyuncu sayısı üst sınırı uygula. |
| 3.6 | `index.ts:539` `resolveTieWinner` | Çift maçta toplam+deplasman eşitse "1. maçın ev sahibi" geçiyor. Bu deterministik ama **basit kural**; gerçek UEFA'da uzatma/penaltı var. Beklenmeyen sonuç algısı. | 🟢 Düşük | UI'da kuralı açıkça belirt; gelecekte penaltı skoru alanı ekle. |
| 3.7 | `notifications_screen.dart:213` | Maç onay/itiraz butonları **sahte** ("Şimdilik... okundu işaretler"). Gerçek akış yalnız turnuva detayında. Kullanıcı bildirimden onayladığını sanır ama hiçbir şey olmaz. | 🟠 Yüksek (UX) | Butonları gerçek `submitScoreForConfirmation`/onay akışına bağla veya kaldır. |
| 3.8 | Genel | **Null safety**: model katmanı `?? default` ile sağlam; ancak `m.homeScore as number` (TS `standings.ts:78`) ve Dart `m.homeScore!` (`tournament.dart:430`) yalnız `isPlayed` filtresinden sonra güvenli — filtre atlanırsa runtime hata. | 🟡 Orta | Yardımcı `playedScore()` ile guard'ı tek yerde topla. |
| 3.9 | `auth_service.dart:292` `_deleteUserData` | Hesap silmede `tournaments`/`friendGroups` üyelikleri **temizlenmiyor**; silinen kullanıcı turnuva katılımcı listelerinde ve grup üyelerinde kalıyor → kırık referans. | 🟡 Orta | Cloud Function ile artıkları temizle veya `onDelete` tetikleyici. |
| 3.10 | `index.ts:268` `updateFriendGroupStats` | Maç düzeltilirse (skor değişip tekrar tamamlanırsa) `applyMatchStats` `statsApplied` ile korunuyor ama grup istatistikleri **ilk tamamlanmada bir kez** uygulanıyor; düzeltme grup tablosuna yansımaz (istatistik sapması). | 🟡 Orta | Grup istatistiğini de `statsApplied` transaction'ına dahil et veya ters-uygula. |

**Memory leak / race:**
- `NotificationService` statik listener'ları (`onTokenRefresh`, `authStateChanges`) **hiç iptal edilmiyor** — uygulama ömrü boyunca tek instance olduğundan sızıntı değil, ama test/hot-restart'ta birikebilir.
- `splash_screen.dart` `Timer` ve `_navigated` guard'ı doğru yönetilmiş (dispose'ta cancel).
- Tur ilerletmede eşzamanlı iki maç tamamlanması: `runTransaction` + `liveRound !== currentRound` koruması race'i kapatıyor — iyi.

---

## 4. GÜVENLİK ANALİZİ (DETAYLI)

### 4.1 Firestore Güvenlik Kuralları — Koleksiyon Bazlı

| Koleksiyon | Kural Özeti | Değerlendirme | Risk / CVSS (tahmini) |
|---|---|---|---|
| `users/{uid}` | read: signed-in; write: yalnız sahibi | İstatistik alanları artık sadece sahibi+Functions yazıyor. **Ama** kullanıcı kendi `users/{uid}.badges`/`totalWins`'i **kendisi** yazabilir (kural alan-bazlı değil) → **kendi istatistiğini şişirebilir.** | 🟠 Orta / CVSS ~5.3 |
| `usernames/{key}` | read: signed-in; create/delete: sahibi | Enumerasyon oturum gerektiriyor; ama anonim oturum trivially açılabildiğinden (§4.4) e-posta sızıntısı pratikte hâlâ mümkün. | 🟡 Orta / 4.3 |
| `tournaments/{id}` | get: katılımcı; list: katılımcı veya `limit<=1`; create: signed-in; update: owner veya `joiningSelfOnly()` | `joiningSelfOnly` kritik alanları (owner/status/code/name/format) koruyor — iyi. `list limit<=1` davet kodu numaralandırmasını sınırlıyor (yine de brute-force kod denemesi mümkün). | 🟡 Orta / 4.0 |
| `.../matches/{id}` | update: admin veya (oyuncu + allowlist alanlar); `statsApplied` istemciden yazılamaz | Allowlist iyi düşünülmüş. **Ama** oyuncu `homeScore`/`awayScore`'u `winnerEntry`/`doubleEntry` modunda doğrudan yazıp onay akışını **atlayabilir** (kural moda bakmıyor). | 🟠 Orta / 5.0 |
| `.../participants` | write: false | Mükemmel — yalnız Functions. | 🟢 |
| `friendships/{id}` | users[] içindeyse read/update/delete | Kullanıcı **karşı tarafın da** `users` içinde olduğu ilişkide `status`'u keyfi değiştirebilir (örn. kendi isteğini "accepted" yapamaz çünkü recipient değil — ama recipient her şeyi yazabilir). Düşük risk. | 🟡 Düşük / 3.1 |
| `friendGroups` + `members` | grup okuma üyeyse; yazma createdBy | `create: if isSignedIn()` — herkes grup oluşturabilir (beklenen). Üye istatistikleri Functions. İyi. | 🟢 |
| `wheels/{id}` | tümü ownerId == uid | Temiz, sahip-bazlı. | 🟢 |
| `feedback/{id}` | create only, read/update/delete false | İyi (write-only kutu). | 🟢 |
| `notifications/{id}` | read: userId==uid; create: `userId != uid`; update: userId==uid | **Create aşırı geniş:** herhangi bir kullanıcı, herhangi bir başka kullanıcıya istediği içerikte bildirim yazabilir → **spam/phishing** ("Şampiyon oldun, linke tıkla"). FCM ile push'a dönüştüğü için etki yüksek. | 🔴 Yüksek / CVSS ~6.5 |

**En kritik kural bulguları:**
1. **`notifications.create` spoofing** (yukarıda) — bildirim üretimi Functions'a taşınmalı; istemci doğrudan `notifications` yazmamalı.
2. **`users` self-write ile istatistik şişirme** — istatistik alanları için `request.resource.data.diff(resource.data).affectedKeys()` allowlist'i; kullanıcı yalnız `bio/favoriteTeam/photoUrl/coverUrl/fcmToken/username` yazabilsin.
3. **Maç skoru moddan bağımsız yazılabiliyor** — `winnerEntry`/`doubleEntry`'de doğrudan `status:'completed'` yazımı engellenmeli (kural turnuva belgesinden modu okuyup kısıtlamalı, maliyetli ama mümkün).

### 4.2 Storage Güvenlik Kuralları

```
profile_photos/{imageId}: read true; write if uid+'.jpg'
cover_photos/{imageId}:   read true; write if uid+'.jpg'
default:                   read,write false
```

| Bulgu | Risk | Çözüm |
|---|---|---|
| **Boyut/içerik-tip sınırı yok** | Kullanıcı 100 MB dosya yükleyip maliyet üretebilir; `image/jpeg` dışı içerik konabilir. | `request.resource.size < 5*1024*1024 && request.resource.contentType.matches('image/.*')` ekle. |
| **read: true** (herkese açık) | Profil/kapak fotoğrafları kimliksiz okunabilir; URL bilinirse herkes erişir. | Kabul edilebilir (avatar paylaşımı), ama hassasiyet varsa `if isSignedIn()`. |

### 4.3 Cloud Functions Güvenliği

- ✅ Admin SDK yalnız tetikleyicilerde; istemci çağıramaz (callable yok).
- ✅ Idempotentlik kötüye kullanımı (çift sayım) `statsApplied`/transaction ile kapalı.
- ⚠️ **Servis hesabı izinleri** değerlendirilemedi (kod dışı); en az ayrıcalık prensibi için Functions servis hesabının yalnız gerekli rollere sahip olduğu doğrulanmalı.
- ⚠️ **Girdi doğrulama:** `parseMatch`/`parseTournament` tip-güvenli parse yapıyor (iyi), ama negatif skor/aşırı büyük skor sınırı yok — istemci `homeScore: 999999` yazabilir, sunucu aynen işler.
- ❌ **Rate limiting / abuse yok:** kötü niyetli istemci maçı binlerce kez yazıp `onMatchWritten`'ı tetikleyebilir (her seferinde tam koleksiyon okuma → maliyet saldırısı).

### 4.4 Authentication Güvenlik Açıkları

| Bulgu | Açıklama | Risk |
|---|---|---|
| Anonim oturum trivially açık | `signInAsGuest` + `_emailForUsername` anonim oturum açıyor; anonim kullanıcı `users`/`usernames`/`tournaments(limit1)` okuyabiliyor. Veri kazıma yüzeyi. | 🟠 |
| Sentetik e-posta `@competra.internal` | Eski hesaplar için; şifre sıfırlama imkânsız (kullanıcı kilitlenir). | 🟡 |
| App Check yok | Auth/Firestore/Functions sahte istemcilerden korunmuyor; emülatör/script ile API kötüye kullanımı. | 🟠 |
| E-posta doğrulama yok | `register` e-posta doğrulamadan hesap açıyor; sahte e-postalarla kayıt. | 🟡 |

### 4.5 Input Validasyon Eksiklikleri

- **İstemci:** `validators.dart` var (kapsamı sınırlı). Turnuva adı/not uzunluk sınırı, skor üst sınırı, kullanıcı adı karakter seti UI'da kısmen.
- **Sunucu:** Skor aralığı, oyuncu sayısı, isim uzunluğu doğrulanmıyor.

### 4.6 API Anahtarları ve Hassas Veri

- `firebase_options.dart` ve `google-services.json` istemci API anahtarları içerir (normal; bunlar kısıtlanmalı = Firebase Console + App Check). `.firebaserc` ve config dosyaları gitignore notu var.
- `key.properties` ile imzalama anahtarı VCS dışında — iyi.
- **Risk:** Web API anahtarına HTTP-referrer / App Check kısıtı yoksa kota suistimali.

### 4.7 KVKK/GDPR Uyumluluk

| Madde | Durum |
|---|---|
| Gizlilik politikası ekranı | ✅ `privacy_policy_screen.dart` var |
| Hesap silme (right to erasure) | ⚠️ Var ama turnuva/grup artıkları kalıyor (§3.9) |
| Veri taşınabilirliği (export) | ❌ Yok |
| Açık rıza / onay akışı | ❌ Kayıtta açık rıza ekranı yok |
| Veri saklama/TTL | ❌ `notifications` süresiz birikiyor |
| E-posta saklanması | `usernames` ve `users`'da düz metin e-posta — erişim kuralları sıkı olmalı |

### 4.8 Penetrasyon Testi Senaryoları

1. **Bildirim spoofing:** Saldırgan giriş yapıp `notifications` koleksiyonuna kurban `userId`'siyle sahte "şifreni sıfırla" bildirimi yazar → FCM push olarak kurbana gider. (§4.1-1)
2. **İstatistik şişirme:** Kullanıcı doğrudan `users/{kendiUid}` belgesine `tournamentsWon: 999, badges:['legend']` yazar → liderlik tablosunu manipüle eder. (§4.1-2)
3. **Onay akışı atlama:** `winnerEntry` modunda oyuncu `submitScoreForConfirmation` yerine doğrudan `updateMatchScore` çağırır (`status:'completed'`) → rakip onayı olmadan skor kesinleşir. (§4.1-3)
4. **Davet kodu brute-force:** 6 karakter, 31-harf alfabe = ~887M kombinasyon; `limit<=1` ile tek tek denenebilir (rate-limit yok) → özel turnuvalara sızma (yavaş ama mümkün).
5. **Storage maliyet saldırısı:** Boyut sınırı olmadığından kullanıcı büyük dosyaları kendi `{uid}.jpg`'sine yükleyip Storage maliyeti üretir.
6. **Fonksiyon tetikleme spam'i:** Maçı döngüde güncelleyerek `onMatchWritten`'ı binlerce kez tetiklemek (her seferi tam `matches` okuması).

---

## 5. PERFORMANS ANALİZİ (DETAYLI)

| # | Konum | Etki | Çözüm | Tahmini Kazanım |
|---|---|---|---|---|
| 5.1 | `tournament_detail_screen.dart` build | Her rebuild'de `computeStandings` + `computeScorers` yeniden hesaplanıyor (O(n²·m) tiebreaker). | Provider'a taşı + memoize (§2.7a). | Büyük turnuvada rebuild başına ms→0; daha akıcı sekme geçişi. |
| 5.2 | `index.ts:353` | Her maç yazımında tüm `matches` okuması (N okuma). | Yalnız ilgili tur/faz sorgula. | Skor başına okuma %50-90 ↓ (büyük turnuva). |
| 5.3 | `social_repository.dart:289` `myFriendGroupsProvider` | `collectionGroup('members')` snapshot + her grup için ayrı `get()` (N+1). | Grup özetini üyelik belgesinde denormalize et. | Grup başına 1 ekstra okuma elenir. |
| 5.4 | `user_repository.dart:96` `userRecentMatchesProvider` | İki `collectionGroup('matches')` sorgusu **tüm** kullanıcı maçlarını çekiyor (limit yok). | `.limit(20)` + `orderBy` (index ile). | Çok oynayan kullanıcıda yüzlerce okuma → 20. |
| 5.5 | `matchesStreamProvider` | Tüm `matches` canlı dinleniyor; sıralama istemcide. | Pagination/faz-bazlı dinleme; büyük turnuvada sayfalama. | Bant genişliği + rebuild ↓ |
| 5.6 | Liderlik tablosu (`leaderboard_screen.dart`) | `users` koleksiyonunu `totalWins/goals/tournamentsWon` ile sıralı çekme; pagination yok. | `.limit(50)` + sayfalama (`startAfter`). | 10K kullanıcıda kritik. |
| 5.7 | Cloud Functions cold start | v2 fonksiyonlarda `minInstances`/`concurrency` ayarı yok. | Kritik fonksiyona `minInstances: 1`, `concurrency: 80`. | İlk push/istatistik gecikmesi ~2-5s → ~ms. |
| 5.8 | Görüntü yükleme | `cached_network_image` var (iyi); ama Storage'da resize yok, orijinal boyut indiriliyor. | "Resize Images" Extension veya thumbnail. | Avatar trafiği büyük ölçüde ↓ |
| 5.9 | Index kullanımı | `firestore.indexes.json` makul (tournaments, friendships, wheels, notifications + collectionGroup members/matches). | `users` sıralama alanları + `notifications` TTL ekle. | Sorgu hatasız + maliyet ↓ |

**Pagination eksikliği genel:** turnuva listesi, bildirimler, liderlik, sosyal arama, maç listesi — hiçbirinde sayfalama yok. Küçük ölçekte sorunsuz, 1K+ kullanıcıda kritik.

---

## 6. KOD KALİTESİ ANALİZİ

### 6.1 Aşırı Uzun Dosyalar (öncelikli refactor)

| Dosya | Satır | Sorun |
|---|---|---|
| `tournament_detail_screen.dart` | **2.405** | Onlarca private widget tek dosyada; fikstür/tablo/istatistik/lobi/çift-maç kartı hepsi içeride. |
| `create_tournament_screen.dart` | 1.039 | 3 adımlı sihirbaz tek dosyada. |
| `wheel_screen.dart` | 1.014 | CustomPainter + UI + repository çağrıları. |
| `profile_screen.dart` | 934 | Profil + istatistik + rozet + form grafiği. |
| `social_screen.dart` | 834 | Arkadaş + grup + arama. |
| `home_screen.dart` | 765 | Quick stats + recent activity + turnuva listesi. |
| `tournament.dart` | 614 | Model + tiebreaker algoritması bir arada. |
| `fixture_generator.dart` | 549 | Kabul edilebilir (algoritma yoğun). |

**Öneri:** Her ekranı `widgets/` alt klasörüne böl (örn. `tournament/detail/_fixture_tab.dart`, `_standings_tab.dart`, `_two_legged_tie_card.dart`).

### 6.2 DRY İhlalleri

| Tekrar | Konum | Öneri |
|---|---|---|
| `createdAt` null-güvenli sıralama bloğu | `tournament_repository.dart:317`, `wheel_repository.dart:61`, `notification_repository.dart:35`, `social_repository.dart:305` (4+ kez birebir) | `extension SortByCreatedAt` veya `int compareByDateDesc(DateTime? a, DateTime? b)` yardımcısı. |
| `_memberStatsDelta` / `memberDelta` | `social_repository.dart:225` (Dart) ↔ `index.ts:303` (TS) | Aynı mantık iki dilde; Dart sürümü artık ölü olabilir. |
| `computeStandings`, fixture üreticiler, tiebreaker | Dart ↔ TS tam kopya | Tek doğruluk kaynağı (sunucu denormalize) hedefle. |
| `_knockoutRoundName` / `knockoutRoundName` | Dart ↔ TS | Sabit eşleme tablosu. |
| `_formatLabel` (format → Türkçe etiket) | Birden çok ekranda (V2'de işaretliydi) | `extension TournamentFormatLabel` tek yerde. |
| `intOrNull` / `str` parse yardımcıları | Dart modelleri ↔ TS `types.ts` | Kaçınılmaz (dil farkı) ama paritesi test edilmeli. |

### 6.3 SOLID İhlalleri

- **SRP:** `tournament_repository.dart` hem CRUD hem bildirim üretimi (`submitScoreForConfirmation` içinde notification yazıyor) yapıyor. Bildirim üretimi ayrılmalı.
- **SRP:** Ekran dosyaları (UI + iş mantığı + hesap) birden çok sorumluluk.
- **OCP:** Format/skorMod/faz `switch`'leri her yeni formatta birden çok dosyada değişiklik gerektiriyor (`fixture_generator`, `tournament.dart`, `index.ts`, `tournament_repository`). Strateji deseni (format → FixtureStrategy) ile genişlemeye açılmalı.
- **DIP:** Repository'ler `FirebaseFirestore`'a doğrudan bağlı (soyut arayüz yok) — test için mock gerekiyor; provider deseni bunu kısmen telafi ediyor.

### 6.4 Magic String / Number Kullanımı

Ham string literaller koleksiyon adları ve durumlar için her yere dağılmış:

| Tür | Örnekler | Önerilen |
|---|---|---|
| Koleksiyon adları | `'users'`, `'tournaments'`, `'notifications'`, `'friendGroups'`, `'wheels'`, `'matches'`, `'participants'`, `'usernames'`, `'friendships'`, `'feedback'` | `class FsCollections { static const users = 'users'; ... }` |
| Durumlar | `'waiting'`, `'active'`, `'completed'`, `'pending'`, `'awaitingConfirmation'`, `'disputed'` | `enum MatchStatus` / `enum TournamentStatus` |
| Format | `'league'`, `'knockout'`, `'groupKnockout'`, `'championsLeague'`, `'groupElimination'` | `enum TournamentFormat` |
| Faz | `'group'`, `'league'`, `'knockout'` | `enum Phase` |
| Bildirim tipi | `'friendRequest'`, `'matchConfirm'`, `'tournamentComplete'` | `enum NotificationType` (kısmen var) |
| Rozet id | `'champion'`, `'hat_trick_hero'`, `'goal_machine'`... | `class Badges` sabitleri (Dart **ve** TS senkron) |
| Sayılar | `qualifierCount clamp(2,8)` (`index.ts:438`), `1000` order base, `10` recent limit, `6` kod uzunluğu | İsimli sabitler |

### 6.5 İsimlendirme Tutarsızlıkları

- `scoreMode` (eski, ham) vs `scoreEntrySystem` (kanonik) — aynı kavram iki ad.
- `phase` vs `stage` (legacy) — model ikisini de okuyor.
- `homeUid`/`awayUid` (yeni) vs `homePlayerId`/`awayPlayerId` (rules'da legacy desteği) — veri tarihsel kalıntı.
- `participantIds` vs `participants` — ad benzerliği kafa karıştırıcı.

### 6.6 Dokümantasyon

- ✅ **Çok güçlü:** Türkçe doc-comment yoğunluğu örnek niteliğinde; her dosya/sınıf/karmaşık fonksiyon açıklamalı. CLAUDE.md kapsamlı.
- ⚠️ Eksik: API/mimari diyagram yok; Functions için README/test yok; ARB string'leri eksik (i18n yarım).

### 6.7 TypeScript Kod Kalitesi (`functions/`)

- ✅ Güçlü tipleme, `parseMatch`/`parseTournament` savunmacı parse, idempotent transaction'lar.
- ⚠️ `any` kullanımı: `parseTournament` içinde `rawParticipants.map((p: any) => ...)` (`types.ts:115`).
- ⚠️ Tek dosyada (`index.ts` 666 satır) tüm iş mantığı; `stats.ts`, `progression.ts`, `notifications.ts` olarak bölünmeli.
- ⚠️ Test yok; `eslint` predeploy'da çalışıyor (iyi) ama jest/mocha yok.
- ⚠️ `firebase-functions ^5.0.0` "outdated" uyarısı (CLAUDE.md'de belirtilmiş).

---

## 7. KLASÖR YAPISI VE MİMARİ ÖNERİSİ

### 7.1 Mevcut Yapı (Layer-based)

```
lib/
  core/{theme/, time_ago.dart, validators.dart}
  components/        # 4 ortak widget
  l10n/              # ARB + üretilen
  models/            # 10 model
  router/            # app_router, route_paths
  screens/           # 13 ekran klasörü (bazıları 800-2400 satır)
  services/          # 11 repository/provider
functions/src/       # index, types, standings, fixtures, achievements
```

### 7.2 Sorunlu Alanlar

- `screens/` dosyaları devasa; widget'lar dışa çıkarılmamış.
- `constants/`, `extensions/`, `mixins/`, `utils/` klasörleri yok → sabitler/yardımcılar dağınık.
- Domain mantığı (`computeStandings`) model dosyasında (`tournament.dart`); ayrı `domain/` katmanı yok.
- `services/` hem provider hem repository hem domain mantığı karışık.

### 7.3 Önerilen Yapı (Hibrit: feature-first + paylaşılan core)

```
lib/
  app/                       # main, CompetraApp, bootstrap
  core/
    constants/               # fs_collections.dart, app_durations.dart, badge_ids.dart
    enums/                   # tournament_format.dart, match_status.dart, phase.dart
    extensions/              # date_sort_x.dart, build_context_x.dart
    theme/  utils/  l10n/
  shared/widgets/            # nav bar, background, logo, text field
  features/
    auth/        {data/, presentation/, domain/}
    tournament/  {data/, presentation/widgets/, domain/fixtures, standings}
    social/      {data/, presentation/}
    wheel/  profile/  leaderboard/  notifications/  settings/
  router/
functions/src/
  triggers/   {on_match_written.ts, on_notification_created.ts}
  domain/     {standings.ts, fixtures.ts, achievements.ts, progression.ts}
  shared/     types.ts
```

### 7.4 Dosya Taşıma / Yeniden Adlandırma

- `tournament.dart` → model (`tournament.dart`) + `domain/standings.dart` (computeStandings/computeScorers).
- `tournament_detail_screen.dart` → `features/tournament/presentation/detail/` altında 6-8 widget dosyası.
- `services/*` → `features/<x>/data/<x>_repository.dart` + `<x>_providers.dart`.

### 7.5 Feature-based vs Layer-based

| Kriter | Layer (mevcut) | Feature (önerilen) |
|---|---|---|
| Küçük proje | ✅ Basit | Fazla yapı |
| Bu projenin boyutu (52 dosya, büyüyor) | ⚠️ Ekranlar şişti | ✅ Ölçeklenir |
| Yeni özellik ekleme | Dosyalar dağınık | ✅ Tek klasör |
| Takım büyümesi | Çakışma artar | ✅ İzole |

**Öneri:** Hibrit — `core/` + `shared/` ortak, geri kalan `features/`.

### 7.6 Barrel Export

Her feature için `tournament.dart` barrel'i (`export 'data/...'; export 'domain/...';`) ile import sadeleştirme. Dikkat: Flutter'da aşırı barrel tree-shaking'i bozabilir; ölçülü kullan.

### 7.7 Yardımcı Klasörler

- `constants/`: koleksiyon adları, süreler, limitler (§6.4).
- `extensions/`: `DateTime?` sıralama, `BuildContext` kısayolları, `AsyncValue` when-helper.
- `mixins/`: form doğrulama, dispose yönetimi.

---

## 8. FRONTEND GELİŞTİRME ÖNERİLERİ

| Öneri | Açıklama | Öncelik | Zorluk | Süre |
|---|---|---|---|---|
| UI bileşen kütüphanesi | `components/` yalnız 4 widget. `AppButton`, `AppCard`, `EmptyState`, `LoadingState`, `ErrorState`, `StatTile`, `PlayerAvatar` ortak bileşenleri çıkar. | Yüksek | Orta | 1 hf |
| Loading/Error/Empty tutarlılığı | Her ekran kendi `when()` kalıbını yazıyor. `AsyncValueWidget<T>` sarmalayıcı ile birleştir. | Yüksek | Kolay | 2 g |
| Erişilebilirlik (a11y) | `Semantics`, `tooltip`, kontrast, min dokunma alanı (48dp), `textScaleFactor` desteği eksik. | Yüksek | Orta | 1 hf |
| Responsive tasarım | Tablet/landscape düzeni yok; sabit padding. `LayoutBuilder`/`MediaQuery` ile kırılım. | Orta | Orta | 1 hf |
| Form validasyon iyileştirme | Skor/isim/kod alanları için `TextInputFormatter` + anlık doğrulama. | Orta | Kolay | 3 g |
| Skeleton loading | `shimmer` bağımlı ama her yerde kullanılmıyor; liste/kart skeleton'ları. | Orta | Kolay | 3 g |
| Animasyon/geçiş | `flutter_animate`/`rive`/`lottie` var; sayfa geçişleri (Hero, shared-axis) standartlaştır. | Düşük | Orta | 1 hf |
| Dark/Light tutarlılık | Varsayılan koyu; açık modda bazı gradient/gölge testleri eksik. | Orta | Kolay | 2 g |
| Navigation UX | Geri tuşu davranışı, deep link sonrası geri yığını, sekme çift-tıkla scroll-to-top. | Orta | Orta | 3 g |
| Gesture/haptic | `HapticFeedback` yalnız turnuva bitişinde; skor girişi/onayda da ekle. | Düşük | Kolay | 1 g |
| i18n string taşıma | ARB altyapısı var, string'ler hâlâ gömülü Türkçe. AppLocalizations'a taşı. | Yüksek | Orta | 1-2 hf |
| Pull-to-refresh | Akışlar canlı ama manuel yenileme jesti kullanıcı güveni için. | Düşük | Kolay | 1 g |

---

## 9. BACKEND GELİŞTİRME ÖNERİLERİ

| Öneri | Açıklama | Öncelik | Zorluk | Süre |
|---|---|---|---|---|
| **Bildirim üretimini Functions'a al** | `notifications` create kuralını `if false` yapıp tüm bildirimleri sunucuda üret (spoofing'i kapat). | Kritik | Orta | 3 g |
| **Callable: kullanıcı arama / davet kodu** | İstemci geniş okuma + anonim oturum yerine `onCall` fonksiyonu. | Yüksek | Orta | 3 g |
| **Callable: hesap silme temizliği** | Turnuva/grup artıklarını sunucuda temizle (`onUserDeleted` veya callable). | Yüksek | Orta | 2 g |
| **Scheduled: bildirim TTL temizliği** | Günlük cron ile 30 günden eski `notifications` sil. | Orta | Kolay | 1 g |
| **Scheduled: turnuva hatırlatma** | Bekleyen maçlar/lobiler için günlük hatırlatma push'u. | Orta | Orta | 3 g |
| **Denormalize standings belgesi** | `tournaments/{id}/standings` Functions tarafından yazılsın; istemci hesaplamasın (Dart↔TS tekilleştirme). | Yüksek | Zor | 1 hf |
| **`onMatchWritten` optimizasyonu** | Tam koleksiyon okumayı faz/tur sorgusuna indir (§5.2). | Yüksek | Orta | 2 g |
| **Skor düzeltme ters-uygulama** | Maç skoru değişirse eski istatistikleri geri al, yenisini uygula (grup dahil). | Orta | Zor | 1 hf |
| **Girdi doğrulama (sunucu)** | Skor aralığı, oyuncu sayısı, isim uzunluğu sınırları. | Yüksek | Kolay | 2 g |
| **Backup / DR** | Firestore zamanlı yedekleme (PITR), export bucket. | Yüksek | Kolay | 1 g |
| **Rate limiting / abuse** | App Check + maç yazım sıklık koruması (örn. son yazımdan beri min süre). | Yüksek | Orta | 3 g |
| **HTTP webhook** | Discord/Telegram entegrasyonu için maç sonucu webhook'u. | Düşük | Orta | 3 g |

**Callable vs HTTP:** Bu uygulamada **Callable** tercih edilmeli (otomatik auth context, App Check entegrasyonu, daha az boilerplate). HTTP yalnız harici webhook/3. parti entegrasyonda.

---

## 10. FİREBASE TARAFINDAKİ GELİŞTİRME ÖNERİLERİ

| Öneri | Açıklama | Öncelik | Maliyet Etkisi | Zorluk |
|---|---|---|---|---|
| **App Check** (Play Integrity / DeviceCheck) | Bot/sahte istemci koruması; Auth+Firestore+Functions+Storage'ı kapsar. En yüksek getirili güvenlik adımı. | Kritik | Düşük | Orta |
| **Emulator Suite** | Firestore+Functions+Auth emülatörü ile yerel test + rules testi; DNS/deploy sorununu da kısmen bypass eder. | Kritik | Yok | Kolay |
| **Phone Auth + Apple Sign-In** | Apple Sign-In iOS yayını için **zorunlu** (Google varken). Phone Auth Türkiye pazarı için değerli. | Yüksek | Orta (SMS) | Orta |
| **Magic Link (email link)** | Şifresiz giriş; sentetik e-posta sorununu da hafifletir. | Orta | Düşük | Orta |
| **Remote Config** | Feature flag (yeni format/monetizasyon), turnuva limitleri, bakım modu, A/B test. | Yüksek | Düşük | Kolay |
| **Storage: Resize Images Extension** | Avatar thumbnail üretimi; bant genişliği maliyeti ↓. | Orta | Negatif (tasarruf) | Kolay |
| **Performance Monitoring** | Ekran render, ağ izleme; gerçek kullanıcı metrikleri. | Orta | Düşük | Kolay |
| **Analytics + BigQuery export** | Funnel, retention, özellik kullanımı; BI temeli. | Yüksek | Düşük | Orta |
| **Dynamic Links → App Links/Universal Links** | Dynamic Links kullanımdan kalkıyor; davet için App Links (Android) + Universal Links (iOS) kur. | Yüksek | Yok | Orta |
| **TTL Policies** | `notifications.expiresAt` ile otomatik silme (maliyet + KVKK). | Orta | Negatif | Kolay |
| **Offline persistence** | `cloud_firestore` offline cache açık varsayılan; çakışma/optimistic UI iyileştir. | Orta | Yok | Kolay |
| **Multi-region** | Şu an `europe-west3` tek bölge; kritik kullanıcı tabanı büyürse okuma replikası/çoklu bölge stratejisi. | Düşük | Yüksek | Zor |
| **Firebase Hosting (web)** | Flutter web build + davet landing page (kod paylaşımı için). | Düşük | Düşük | Orta |

---

## 11. YENİ ÖZELLİK ÖNERİLERİ (25+)

> Her özellik: açıklama, user story, iş değeri, teknik özet, bağımlılık, zorluk, süre, öncelik, kategori.

### Sosyal

**1. Maç Sohbeti / Yorum (Trash Talk)**
US: "Bir oyuncu olarak rakibimle maç öncesi/sonrası atışabilmek isterim." Değer: etkileşim/retention. Teknik: `matches/{id}/messages` alt koleksiyon + push. Bağımlılık: bildirim altyapısı. Zorluk: Orta. Süre: 1 hf. Öncelik: Yüksek.

**2. Aktivite Akışı (Feed)**
US: "Arkadaşlarımın kazandığı maçları/şampiyonlukları akışta görmek isterim." Değer: viral döngü. Teknik: `feed` koleksiyonu, Functions fan-out. Bağımlılık: arkadaşlık. Zorluk: Orta. Süre: 1 hf. Öncelik: Yüksek.

**3. Profil Karşılaştırma / H2H Geçmişi**
US: "Bir arkadaşımla aramdaki tüm maç geçmişini görmek isterim." Değer: rekabet. Teknik: collectionGroup `matches` çift uid sorgusu (denormalize edilmeli). Zorluk: Orta. Süre: 4 g. Öncelik: Orta. Kategori: Sosyal/Rekabet.

**4. Arkadaş Grubu Sezonları**
US: "Grubumda aylık/sezonluk sıralama isterim." Değer: süreklilik. Teknik: grup istatistiklerine sezon boyutu. Bağımlılık: grup istatistikleri. Zorluk: Orta. Süre: 1 hf. Öncelik: Orta.

### Rekabet

**5. ELO / MMR Derecelendirme**
US: "Genel beceri puanım olsun." Değer: ciddi rekabet, eşleştirme temeli. Teknik: maç sonrası ELO güncelleme (Functions). Bağımlılık: stats. Zorluk: Orta. Süre: 4 g. Öncelik: Yüksek. Kategori: Rekabet.

**6. Sezonluk Global Lig + Ödüller**
US: "Aylık global sezonda derece alıp rozet kazanmak isterim." Değer: retention. Teknik: scheduled sezon kapanışı + ödül dağıtımı. Bağımlılık: leaderboard, scheduled fn. Zorluk: Zor. Süre: 2 hf. Öncelik: Orta.

**7. Günlük/Haftalık Görevler (Challenges)**
US: "Her gün tamamlayacağım görevler olsun (3 maç oyna, 5 gol at)." Değer: günlük aktif kullanıcı. Teknik: `challenges` + scheduled reset. Zorluk: Orta. Süre: 1 hf. Öncelik: Yüksek. Kategori: Rekabet/UX.

**8. Başarım Vitrini + Paylaşılabilir Kart**
US: "Rozetlerimi sosyal medyada paylaşmak isterim." Değer: viral. Teknik: `share_service` zaten var, görsel kart üret. Bağımlılık: share_service. Zorluk: Kolay. Süre: 3 g. Öncelik: Orta.

**9. Canlı Maç Skoru (Real-time)**
US: "Maç oynanırken skoru canlı gireyim, izleyiciler görsün." Değer: heyecan. Teknik: `matches` zaten canlı; "izleyici" modu UI. Zorluk: Kolay. Süre: 3 g. Öncelik: Düşük.

### Organizasyon

**10. Çoklu Tur / Lig+Playoff Hibrit Formatlar**
US: "Lig sonrası playoff isterim." Değer: format zenginliği. Teknik: format motoru genişlet (strateji deseni). Zorluk: Zor. Süre: 2 hf. Öncelik: Orta.

**11. Maç Programı / Takvim + Hatırlatıcı**
US: "Maçlarıma tarih atayıp hatırlatma alayım." Değer: organizasyon. Teknik: maça `scheduledAt`, scheduled push. Bağımlılık: scheduled fn. Zorluk: Orta. Süre: 1 hf. Öncelik: Yüksek. Kategori: Organizasyon.

**12. Takım/Oyuncu Havuzu (Kadro)**
US: "Turnuvada herkese çarktan takım atansın." Değer: çark entegrasyonu. Teknik: wheel + tournament birleştir. Bağımlılık: wheel. Zorluk: Orta. Süre: 4 g. Öncelik: Orta.

**13. Turnuva Şablonları**
US: "Sık kullandığım ayarları şablon olarak kaydedeyim." Değer: hız. Teknik: `templates` koleksiyonu. Zorluk: Kolay. Süre: 2 g. Öncelik: Düşük.

**14. Yönetici Yetki Devri / Çoklu Admin**
US: "Turnuvayı yönetmek için yardımcı admin atayayım." Değer: büyük turnuva yönetimi. Teknik: `adminIds[]` + rules. Zorluk: Orta. Süre: 3 g. Öncelik: Orta.

**15. Maç Fotoğrafı / Kanıt Ekleme**
US: "Skoru girerken ekran görüntüsü ekleyeyim (itiraz çözümü)." Değer: güven. Teknik: Storage + maç belgesi. Bağımlılık: storage kuralları. Zorluk: Orta. Süre: 4 g. Öncelik: Orta.

### Monetizasyon

**16. Premium (Competra Pro)**
US: "Sınırsız turnuva, gelişmiş istatistik, özel temalar isterim." Değer: gelir. Teknik: `in_app_purchase` + Remote Config flag. Bağımlılık: Remote Config. Zorluk: Zor. Süre: 2 hf. Öncelik: Yüksek. Kategori: Monetizasyon.

**17. Özel Tema / Avatar Çerçeveleri (Kozmetik)**
US: "Profilimi özelleştirmek için kozmetik satın alayım." Değer: mikro-gelir. Teknik: IAP + kozmetik envanteri. Zorluk: Orta. Süre: 1 hf. Öncelik: Orta.

**18. Sponsorlu Turnuvalar / Markalı Çark**
US: "Bir marka turnuva sponsoru olsun." Değer: B2B gelir. Teknik: turnuvaya sponsor meta + banner. Zorluk: Orta. Süre: 1 hf. Öncelik: Düşük.

### Teknik / UX

**19. Çevrimdışı Mod + Senkronizasyon**
US: "İnternetsiz skor girip sonra senkronlayayım." Değer: kullanılabilirlik. Teknik: Firestore offline + çakışma çözümü. Zorluk: Orta. Süre: 1 hf. Öncelik: Orta.

**20. Widget (Ana Ekran) — Sıradaki Maç**
US: "Telefon ana ekranımda sıradaki maçı göreyim." Değer: yapışkanlık. Teknik: `home_widget` paketi. Zorluk: Orta. Süre: 1 hf. Öncelik: Düşük.

**21. Maç Tahmin / Bahis (Sanal Puan)**
US: "Arkadaşlarımın maçları için tahmin yapıp sanal puan kazanayım." Değer: etkileşim. Teknik: `predictions` + Functions skorlama. Zorluk: Zor. Süre: 2 hf. Öncelik: Orta. Kategori: Rekabet/Sosyal.

**22. Sesli/Görsel Maç Özeti (Wrapped genişletme)**
US: "Turnuva sonunda Spotify-Wrapped tarzı özet isterim." Değer: paylaşım. Teknik: `tournament_wrapped_screen` zaten var, genişlet. Bağımlılık: wrapped. Zorluk: Orta. Süre: 4 g. Öncelik: Düşük.

**23. Push Tercih Yönetimi**
US: "Hangi bildirimleri alacağımı seçeyim." Değer: kullanıcı kontrolü/KVKK. Teknik: `users.notificationPrefs` + Functions kontrolü. Zorluk: Kolay. Süre: 2 g. Öncelik: Yüksek. Kategori: UX.

**24. QR Kod ile Katılma**
US: "Davet kodunu QR olarak gösterip taratayım." Değer: kolay katılım. Teknik: `qr_flutter` + tarayıcı. Bağımlılık: deep link. Zorluk: Kolay. Süre: 2 g. Öncelik: Orta.

**25. İstatistik Grafik Panosu (Dashboard)**
US: "Gol/galibiyet trendimi grafiklerle göreyim." Değer: engagement. Teknik: `fl_chart` zaten var, genişlet. Zorluk: Orta. Süre: 4 g. Öncelik: Orta.

**26. Çok Dilli Tam Destek (EN + diğer)**
US: "Uygulamayı İngilizce kullanayım." Değer: pazar genişlemesi. Teknik: i18n string taşıma (altyapı hazır). Zorluk: Orta. Süre: 1-2 hf. Öncelik: Yüksek. Kategori: UX/Teknik.

**27. Turnuva Arşivi & Tekrar Oynat**
US: "Geçmiş turnuvaları arşivde tutup tekrar başlatayım." Değer: süreklilik. Teknik: status `archived` + clone. Zorluk: Kolay. Süre: 3 g. Öncelik: Düşük.

---

## 12. EK API VE SERVİS ÖNERİLERİ

| Kategori | Servis | Maliyet | Zorluk | Değer | Entegrasyon |
|---|---|---|---|---|---|
| Spor verisi | **API-Football / Football-Data.org** | Orta ($) | Orta | Gerçek lig/takım verisi, çark presetlerini canlı tut | 1 hf |
| Oyun verisi | EA Sports FC (resmi API yok) → topluluk veri setleri | Düşük | Zor | Takım reytingleri, oyuncu kartları | 1-2 hf |
| Sosyal medya | **share_plus (var) + paylaşılabilir görsel kart** | Yok | Kolay | Viral büyüme | 3 g |
| Ödeme | **RevenueCat** (IAP soyutlama) | %1 gelir | Orta | Premium/abonelik yönetimi (iOS+Android tek SDK) | 1 hf |
| Analytics/BI | **Firebase Analytics → BigQuery → Looker Studio** | Düşük | Orta | Funnel, retention, gelir paneli | 1 hf |
| Email | **SendGrid / Resend** (Functions'tan) | Düşük | Kolay | Hoş geldin, şifre sıfırlama, özet e-postaları | 3 g |
| SMS/OTP | **Firebase Phone Auth** (veya Twilio) | Orta | Orta | Telefon doğrulama, TR pazarı | 4 g |
| CDN | **Firebase Hosting CDN / Cloudflare** | Düşük | Kolay | Avatar/asset dağıtımı | 2 g |
| AI/ML | **Anthropic Claude API** (Opus/Haiku) | Kullanım bazlı | Orta | Maç tahmini özeti, turnuva eşleştirme optimizasyonu, otomatik "wrapped" anlatı metni, akıllı moderasyon (trash-talk filtresi) | 1 hf |
| AI/ML | **Gemini (Firebase AI Logic)** | Kullanım bazlı | Kolay | Firebase yerel entegrasyon; içerik üretimi | 4 g |
| Hata izleme | **Crashlytics (var) + Sentry (opsiyonel)** | Düşük | Kolay | Daha derin breadcrumb/performans | 2 g |
| Push gelişmiş | **OneSignal (alternatif)** | Düşük | Orta | Segment/kampanya push (FCM üstüne) | 4 g |

**AI/ML somut fırsatlar:** (1) Turnuva sonu doğal dil özeti (Claude Haiku ile ucuz). (2) Dengeli grup/eşleşme önerisi (ELO bazlı optimizasyon). (3) Trash-talk moderasyonu. (4) "Bir sonraki rakibin..." tahmin metinleri.

---

## 13. MONETİZASYON STRATEJİLERİ

| Strateji | Açıklama | Tahmini Gelir | Kullanıcı Etkisi | Zorluk |
|---|---|---|---|---|
| **Freemium (Competra Pro)** | Ücretsiz: 3 aktif turnuva, temel istatistik. Pro: sınırsız turnuva, gelişmiş istatistik/grafik, ELO geçmişi, özel temalar, reklamsız. ~₺49/ay veya ₺299/yıl. | Orta-Yüksek | Düşük (ücretsiz çekirdek korunur) | Zor |
| **Reklam (AdMob)** | Geçiş reklamı (turnuva oluşturma sonrası), ödüllü reklam (ekstra çark çevirme/turnuva slotu). | Düşük-Orta | Orta (denge gerekir) | Orta |
| **Kozmetik IAP** | Avatar çerçeveleri, profil temaları, özel rozet renkleri, çark skinleri. | Düşük | Çok düşük | Orta |
| **Sponsorlu içerik** | Markalı turnuva/çark (yerel kafe, e-spor markası). | Orta (B2B) | Düşük | Orta |
| **B2B (kafe/kulüp)** | PlayStation kafe/üniversite kulüpleri için "Competra Business": ekran modu, çoklu turnuva yönetimi, marka. ~₺500/ay/mekan. | Yüksek (niş) | Yok (ayrı segment) | Zor |
| **Abonelik (sezon geçişi)** | "Battle Pass" tarzı sezonluk ödül yolu. | Orta | Pozitif (engagement) | Zor |

**Öneri sırası:** (1) AdMob ödüllü reklam (hızlı, düşük risk) → (2) Pro freemium (RevenueCat) → (3) B2B kafe paketi (en yüksek niş gelir). Reklamı **agresif kullanma**; arkadaş-grubu sosyal uygulamada deneyim kritik.

---

## 14. TEST STRATEJİSİ (DETAYLI)

**Mevcut durum:** Yalnızca varsayılan `test/widget_test.dart`. Coverage ~%0. **En büyük teknik borç.**

### 14.1 Birim Test Öncelikleri (en değerli 20)

| # | Hedef | Neden kritik |
|---|---|---|
| 1-3 | `computeStandings` — FIFA/UEFA/Hybrid tiebreaker | Şampiyon belirleme; en karmaşık mantık |
| 4 | 3+ oyuncu eşitliği mini-tablo özyineleme | Kenar durum, hata olasılığı yüksek |
| 5 | `computeScorers` gol krallığı | Sıralama doğruluğu |
| 6-7 | `generateLeagueFixtures` round-robin tekrarsızlık | Herkes-herkesle garantisi |
| 8-9 | `generateKnockoutFixtures` bye dağıtımı (tek/çift sayı) | Bracket bütünlüğü |
| 10 | `generateKnockoutFromGroups` çapraz eşleşme (2/3/4 grup) | Eşleşme deseni |
| 11-12 | `generateKnockoutFromSeeds` çift maçlı (leg 1/2) | ŞL mantığı |
| 13 | `generateNextKnockoutRound` twoLegged | Tur ilerletme |
| 14 | `TournamentMatch.fromDoc` legacy `stage`→`phase` | Geriye uyum |
| 15 | `Tournament._normalizeScoreEntry` legacy eşleme | Veri uyumu |
| 16 | `_derivePhase` türetme | Faz tutarlılığı |
| 17-18 | **TS↔Dart parite testi** (aynı girdi → aynı standings) | İki port sapma riski |
| 19 | `deriveAchievementUpdate` rozet/unvan | Ödül doğruluğu |
| 20 | `resolveTieWinner` away-goals | Çift maç kazananı |

### 14.2 Widget Testleri

- `EmptyState`/`ErrorState`/`LoadingState` render.
- Login form validasyon.
- Turnuva detay sekme geçişi.
- Skor giriş dialog akışı (mod bazlı buton görünürlüğü).

### 14.3 Integration Test

- Kayıt → turnuva oluştur → katıl → başlat → skor gir → tablo güncellenir (emülatör ile).
- Davet kodu/deep link ile katılma.

### 14.4 Cloud Functions Test

- `firebase-functions-test` + Jest: `applyMatchStats` idempotentlik (`statsApplied` çift sayım yok), `advanceKnockout` tur ilerletme, `finalizeTournament` şampiyon.

### 14.5 Emülatör + Rules Test

- `@firebase/rules-unit-testing`: her koleksiyon için pozitif/negatif yetki testleri (özellikle notification spoofing, users self-write, match allowlist).

### 14.6 E2E / Performans / Güvenlik

- **E2E:** `patrol` veya `integration_test` (kritik kullanıcı yolu).
- **Performans:** büyük turnuva (20 oyuncu lig) ile rebuild/okuma profili.
- **Güvenlik:** §4.8 senaryolarını otomatize et (rules testleri).

### 14.7 Öncelik Matrisi

| Sıra | Tür | Değer/Maliyet |
|---|---|---|
| 1 | Birim (standings/fixtures) | Çok yüksek / Düşük |
| 2 | Rules testleri (emülatör) | Yüksek / Düşük |
| 3 | Functions testleri | Yüksek / Orta |
| 4 | Widget testleri | Orta / Düşük |
| 5 | Integration/E2E | Orta / Yüksek |

---

## 15. DEVOPS VE YAYINA HAZIRLIK

### 15.1 Mevcut Durum

- ✅ Release imzalama `key.properties` üzerinden (VCS dışı), debug fallback.
- ✅ Crashlytics + Gradle eklentisi.
- ✅ `firebase.json` predeploy: `lint` + `build`.
- ❌ CI/CD yok. ❌ Emülatör yok. ❌ Otomatik versiyon yok. ⚠️ DNS/IPv6 deploy sorunu (CLAUDE.md).

### 15.2 GitHub Actions Pipeline (öneri)

```yaml
name: ci
on:
  pull_request:
  push:
    branches: [main]
jobs:
  flutter:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with: { flutter-version: '3.35.1', channel: stable }
      - run: flutter pub get
      - run: flutter analyze
      - run: flutter test --coverage
      - uses: codecov/codecov-action@v4
  functions:
    runs-on: ubuntu-latest
    defaults: { run: { working-directory: functions } }
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '22' }
      - run: npm ci
      - run: npm run lint
      - run: npm run build
      - run: npm test --if-present
  rules-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '22' }
      - run: npm i -g firebase-tools
      - run: firebase emulators:exec --only firestore "npm --prefix functions run test:rules"
```

**Deploy job (manuel onaylı):** `firebase deploy --only functions,firestore:rules,firestore:indexes` (DNS sorunu için Cloud Shell veya self-hosted runner alternatifi).

### 15.3 Diğer

- **Otomatik versiyon:** `pubspec.yaml` build-number'ı `github.run_number` ile (`--build-number`).
- **Play Store:** internal testing track + `r0adkll/upload-google-play` action ile otomatik AAB yükleme.
- **App Store:** iOS yapılandırması eksik (Info.plist push/background notları, APNs key, Apple Sign-In). Mac + Xcode gerekli.
- **Monitoring/alerting:** Crashlytics velocity alert, Functions hata oranı için Cloud Monitoring alarmı, bütçe alarmı.
- **Rollback:** Functions sürümlenmiş; `firebase functions:rollback` veya önceki tag deploy. Rules için git geçmişi.
- **Beta:** Firebase App Distribution (Android/iOS) veya Play internal track.

---

## 16. ÖLÇEKLENEBİLİRLİK ANALİZİ

### 16.1 Yük Davranışı

| Kullanıcı | Davranış | Darboğaz |
|---|---|---|
| **1K** | Sorunsuz. Firestore/Functions varsayılanları yeterli. | Yok |
| **10K** | Çoğu akış iyi. Liderlik tablosu (pagination yok), `collectionGroup('members')`/`matches` sorguları ısınır. | Leaderboard, recent matches |
| **100K** | `onMatchWritten` tam koleksiyon okuması + collectionGroup taramaları maliyet/gecikme. Pagination yokluğu UI'ı bozar. Cold start görünür. | Functions okuma, leaderboard, fan-out |

### 16.2 Maliyet Projeksiyonu (kaba)

Varsayım: aktif kullanıcı günde ~10 maç işlemi, ~30 okuma.

| Kullanıcı | Aylık okuma | Aylık yazma | Firestore tahmini | Functions çağrı |
|---|---|---|---|---|
| 1K | ~9M | ~1M | ~$5-10 | <2M (ücretsiz kota içi) |
| 10K | ~90M | ~10M | ~$50-90 | ~20M (~$5-15) |
| 100K | ~900M | ~100M | ~$500-900 | ~200M (~$50-150) |

`onMatchWritten`'ın tam-koleksiyon okuması düzeltilmezse 100K'da okuma maliyeti **2-5x** artabilir.

### 16.3 Darboğazlar ve Çözümler

- **Hot document:** popüler turnuva belgesine eşzamanlı katılım (`participantIds arrayUnion`) — Firestore belge başına ~1 yazma/sn sınırı. Çözüm: katılımı alt-koleksiyona dağıt.
- **Leaderboard:** sıralı `users` sorgusu + pagination; çok yüksek ölçekte materyalize "top-100" belgesi (scheduled).
- **Fan-out (feed/bildirim):** çok arkadaşlı kullanıcıda yazma patlaması — kuyruk (Pub/Sub) ile asenkron.

### 16.4 Sharding / Caching / Migration

- **Caching:** sık okunan sabit veriler (lig presetleri zaten istemcide). Sunucu tarafı için Memorystore (Redis) yalnız 100K+ ve gerçek ihtiyaçta.
- **CDN:** Storage avatarları için CDN + thumbnail.
- **Migration:** legacy alanlar (`scoreMode`, `stage`, `homePlayerId`) için bir kerelik backfill Function; sonra modelden legacy yolları kaldır.

---

## 17. KULLANICI DENEYİMİ (UX) DERİN ANALİZİ

### 17.1 Kullanıcı Akışı

Splash → (ilk açılış) Onboarding → Login/Guest → Home (5 sekme) → Turnuva oluştur/katıl → Detay (Fikstür/Tablo/İstatistik) → Skor gir → Wrapped. Akış **mantıklı ve akıcı**.

**Pain point'ler:**
- Misafir kullanıcı çoğu sosyal özelliği kullanamıyor ama uyarı geç geliyor (`guest_warning_screen` var ama akışa entegrasyonu kısmi).
- Bildirimden onay/itiraz sahte (§3.7) — kullanıcı kafa karışıklığı.
- Davet kodu girişi manuel; QR yok.
- Skor düzeltme sonrası grup istatistiği güncellenmiyor (§3.10) — sessiz tutarsızlık.

### 17.2 Onboarding

- ✅ `onboarding_screen.dart` (283 satır) + `completedKey` ile tek seferlik. İyi.
- ⚠️ Değer önerisini hızlı iletmeli; "ilk turnuvanı 60 saniyede kur" tarzı eylem odaklı.

### 17.3 Retention Mekanizmaları

- ✅ Push, rozet/unvan, wrapped, global sıralama, çark.
- ❌ Günlük görev, streak, sezon, hatırlatma push'u yok (§11/7,11).

### 17.4 Gamification

- Güçlü temel: badges, titles (priority), champion, hat-trick. ELO/sezon eklenirse **çok güçlü**.

### 17.5 Persona / Segment

1. **Kafe/PlayStation grubu** (ana) — yüz yüze turnuva yöneticisi.
2. **Uzak arkadaş grubu** — online skor girişi.
3. **Rekabetçi** — ELO/sıralama avcısı.
4. **Organizatör** — düzenli lig kuran.

### 17.6 Rekabetçi Analiz

- **Toornament / Challonge:** güçlü bracket, zayıf sosyal/mobil. Competra'nın avantajı: sosyal + mobil-öncelikli + Türkçe + çark/eğlence.
- **Discord botları:** teknik kullanıcı; Competra daha erişilebilir.
- **Farklılaştırıcı:** arkadaş grupları + gamification + yerel (TR) odak.

### 17.7 ASO

- "turnuva", "lig", "FIFA turnuva", "PlayStation turnuva", "fikstür" anahtar kelimeleri. Ekran görüntüleri: wrapped, tablo, çark. Türkçe lokal ASO güçlü potansiyel.

---

## 18. TEKNİK BORÇ (TECHNICAL DEBT) ANALİZİ

| Borç | Etki | Giderme Maliyeti | Risk |
|---|---|---|---|
| Test yokluğu | Regresyon görünmez; refactor riskli | Yüksek (sürekli) | Yüksek |
| Dart↔TS mantık çift bakımı | Sapma → istemci/sunucu farklı şampiyon | Yüksek | Yüksek |
| `tournament_detail_screen` 2405 satır | Bakım/rebuild | Orta | Orta |
| Magic string'ler | Yazım hatası → sessiz bug | Orta | Orta |
| Ölü kod (`achievement_service`, istemci grup-stats) | Kafa karışıklığı | Düşük | Düşük |
| Legacy alanlar (`scoreMode`/`stage`/`homePlayerId`) | Çift okuma yolu | Orta | Düşük |
| i18n yarım (string'ler gömülü) | Çoklu dil bloklu | Orta | Düşük |
| Notification create geniş kuralı | Güvenlik | Düşük | Yüksek |
| Anonim-oturum giriş hilesi | Kırılganlık | Orta | Orta |
| iOS yapılandırması eksik | iOS yayını bloklu | Orta | Orta |
| DNS/deploy sorunu | Operasyonel sürtünme | Düşük | Orta |
| `firebase-functions ^5` eski | Gelecek breaking | Düşük | Düşük |

### Refactoring Road Map (sprint bazlı)

- **Sprint 1:** Test altyapısı + standings/fixtures birim testleri + rules testleri. Magic string sabitleri.
- **Sprint 2:** Notification üretimini Functions'a al; users self-write allowlist; App Check.
- **Sprint 3:** `tournament_detail` ve `create_tournament` widget bölme; ortak `AsyncValueWidget`.
- **Sprint 4:** Denormalize standings (Dart↔TS tekilleştirme); `onMatchWritten` okuma optimizasyonu.
- **Sprint 5:** i18n string taşıma; legacy alan backfill + temizlik.

---

## 19. ÖNCELİKLİ YOL HARİTASI

### Faz 1 — Kritik Düzeltmeler (0-2 hafta)

| Madde | Neden kritik | Süre |
|---|---|---|
| `notifications.create` kuralını kapat, üretimi Functions'a al | Spoofing/phishing yüzeyi (FCM push'a dönüşüyor) | 3 g |
| `users` self-write alan allowlist'i | İstatistik şişirme | 1 g |
| Maç skoru mod-bazlı kısıt (winnerEntry/doubleEntry onay atlama) | Skor manipülasyonu | 2 g |
| App Check etkinleştir | Sahte istemci/bot/kota koruması | 2 g |
| `_emailForUsername` → Callable | Anonim-oturum kırılganlığı | 2 g |
| `joinByInviteCode` status kontrolü | Hayalet katılımcı | 0.5 g |
| Notification ekranı sahte butonları düzelt/kaldır | UX güveni | 1 g |
| Storage boyut/içerik-tip kuralı | Maliyet saldırısı | 0.5 g |
| Temel birim testleri (standings/fixtures) + CI | Regresyon koruması | 4 g |

### Faz 2 — Temel İyileştirmeler (2-6 hafta)

| Madde | Beklenen fayda | Süre |
|---|---|---|
| Emulator Suite + rules/functions testleri | Güvenli iterasyon | 1 hf |
| Denormalize standings (sunucu) | Dart↔TS tekilleştirme, performans | 1 hf |
| `onMatchWritten` okuma optimizasyonu | Maliyet/gecikme ↓ | 2 g |
| Magic string → enum/const | Hata azaltma | 3 g |
| `tournament_detail`/`create_tournament` widget bölme | Bakım/rebuild | 1 hf |
| Pagination (leaderboard/notifications/recent) | Ölçek | 4 g |
| i18n string taşıma (TR+EN) | Pazar genişlemesi | 1-2 hf |
| Hesap silme artık temizliği (Functions) | KVKK/veri bütünlüğü | 2 g |
| Apple Sign-In + iOS yapılandırma | iOS yayını | 1 hf (Mac) |

### Faz 3 — Yeni Özellikler (6-12 hafta)

| Madde | İş değeri | Süre |
|---|---|---|
| ELO/MMR derecelendirme | Rekabet derinliği | 4 g |
| Günlük görevler + streak | Günlük aktif kullanıcı | 1 hf |
| Maç sohbeti / aktivite akışı | Etkileşim/viral | 1-2 hf |
| Maç takvimi + hatırlatma push | Organizasyon/retention | 1 hf |
| Premium (RevenueCat) + Remote Config flag | Gelir | 2 hf |
| QR ile katılma + App Links | Kolay katılım | 4 g |
| Paylaşılabilir başarım kartı | Viral büyüme | 3 g |

### Faz 4 — Ölçekleme ve Optimizasyon (3-6 ay)

| Madde | Ölçek etkisi | Süre |
|---|---|---|
| Materyalize liderlik (scheduled top-100) | 10K-100K okuma ↓ | 1 hf |
| Fan-out kuyruğu (Pub/Sub) feed/bildirim | Yazma patlaması yönetimi | 1 hf |
| Storage thumbnail + CDN | Bant genişliği ↓ | 4 g |
| Legacy alan backfill + model temizliği | Bakım ↓ | 1 hf |
| BigQuery export + BI panosu | Veri-odaklı karar | 1 hf |
| Çoklu admin / format motoru (strateji deseni) | Genişleyebilirlik | 2 hf |

---

## 20. KAPANIŞ DEĞERLENDİRMESİ

### 20.1 Güçlü Yanlar (10+)

1. **Cloud Functions ile sağlam istemci/sunucu ayrımı** — hassas yazımlar admin SDK'da, idempotent.
2. **Olağanüstü iç dokümantasyon** — Türkçe doc-comment yoğunluğu örnek nitelikte.
3. **Tutarlı mimari** — repository + Riverpod provider deseni her domainde aynı.
4. **Gelişmiş tiebreaker motoru** — FIFA/UEFA/Hybrid, özyinelemeli mini-tablo, deterministik kura.
5. **Dört turnuva formatı** + çift maçlı (ŞL away-goals) eleme.
6. **Tamamen tema tabanlı UI** — hard-coded renk yok, açık/koyu mod.
7. **Uçtan uca FCM push** — token yönetimi, yönlendirme, geçersiz token temizliği.
8. **Zengin gamification** — rozet, unvan, wrapped, çark, global sıralama.
9. **Güvenlik kurallarının düşünülmüşlüğü** — `joiningSelfOnly`, allowlist, `statsApplied` koruması, write-only feedback.
10. **i18n + Crashlytics + deep link + Google/Guest auth** altyapıları kurulu.
11. **Sosyal katman** — arkadaşlık + arkadaş grupları + grup-içi istatistik.
12. **Idempotentlik disiplini** — transaction + durum koruması ile çift sayım/çift ilerletme engelli.

### 20.2 Zayıf Yanlar / Acil Eylem

1. 🔴 **Hiç test yok** — en büyük risk; iki dilli mantık sapması görünmez.
2. 🔴 **Notification create spoofing** + **users self-write** güvenlik açıkları.
3. 🔴 **App Check / rate-limiting yok** — bot/maliyet/abuse yüzeyi.
4. 🟠 **Anonim-oturum giriş hilesi** kırılgan.
5. 🟠 **Skor onay akışı bildirimden sahte**; mod-bazlı kısıt eksik.
6. 🟡 **Devasa ekran dosyaları** + magic string + Dart↔TS çift bakım.
7. 🟡 **Pagination yokluğu** — ölçekte UI/maliyet sorunu.
8. 🟡 **iOS yayını eksik**; i18n yarım.

### 20.3 Rekabetçi Avantajlar

Mobil-öncelikli + sosyal (arkadaş grupları) + Türkçe yerelleştirme + eğlence katmanı (çark, wrapped, rozet). Toornament/Challonge'un eksik bıraktığı **arkadaş-grubu sosyal turnuva** nişini hedefliyor.

### 20.4 Pazar Potansiyeli

PlayStation/FIFA kafe kültürü ve arkadaş turnuvaları TR'de güçlü. B2B (kafe paketi) niş ama yüksek değerli. Doğru ASO + viral davet (QR/App Links) + retention (görev/sezon) ile organik büyüme potansiyeli yüksek.

### 20.5 Geliştirici / Takım Önerileri

- **Şu an:** 1 güçlü full-stack Flutter+Firebase geliştirici işi iyi yürütüyor (kod kalitesi bunu gösteriyor).
- **Büyüme için:** (1) **QA/test mühendisi** (en kritik boşluk), (2) yarı zamanlı **güvenlik gözden geçirmesi** (rules + App Check + pentest), (3) ölçek aşamasında **backend/DevOps** desteği.
- **Outsourcing adayları:** iOS yapılandırma/yayın (kısa iş), ASO/pazarlama, tasarım (responsive/a11y).

### 20.6 6 Aylık Vizyon

- **Ay 1-2:** Güvenlik sertleştirme + test altyapısı + CI/CD → güvenli yayın temeli. Android beta (App Distribution/internal track).
- **Ay 2-3:** iOS yayını (Apple Sign-In dahil), i18n (TR+EN), pagination, denormalize standings.
- **Ay 3-4:** ELO + günlük görev + maç sohbeti → retention motoru. Analytics/BI.
- **Ay 4-5:** Premium (freemium) + AdMob ödüllü + Remote Config → ilk gelir.
- **Ay 5-6:** Materyalize liderlik + fan-out + thumbnail/CDN → 10K+ kullanıcıya ölçek. B2B kafe pilotu.

**Sonuç:** Competra, sağlam mühendislik temeli ve net ürün vizyonu olan, **beta'ya hazır (~%75 MVP)** bir uygulamadır. Yayın öncesi kritik yol; **güvenlik sertleştirme + test + iOS** üçlüsüdür. Bu üçlü tamamlandığında pazara çıkışa hazırdır.

---

*Rapor sonu — COMPETRA_ANALIZ_V3.md*
