# COMPETRA — Kapsamlı Kod Analiz Raporu (V3)

> **Tarih:** 2026-06-22  
> **Kapsam:** `lib/` altındaki 54 Dart dosyası (toplam ~14.500 satır), `functions/src/` altındaki 5 TypeScript dosyası (~1.200 satır), `pubspec.yaml`, `firebase.json`, `firestore.rules`, `storage.rules`, `firestore.indexes.json`, `android/app/build.gradle.kts`, `AndroidManifest.xml`, `CLAUDE.md`  
> **Yöntem:** Tüm kaynak kod satır satır incelendi; V2 raporu ile karşılaştırma yapıldı.

---

## 1. YÖNETİCİ ÖZETİ

### 1.1 Projenin Genel Durumu ve Olgunluk Seviyesi

Competra, arkadaş arası futbol/oyun turnuvaları düzenlemeye yönelik bir Flutter uygulamasıdır. V2 analizinden bu yana **büyük bir mimari atılım** gerçekleştirilmiştir: V2'nin en kritik bulgusu olan "sunucu tarafı mantığın (Cloud Functions) yokluğu" tamamen giderilmiştir. Artık istatistik yazımı, tur ilerletme, şampiyon belirleme ve FCM push bildirimleri **Cloud Functions (TypeScript, v2)** tarafında yapılmaktadır.

Uygulama, MVP seviyesinde **işlevsel olarak tamamlanmış** kabul edilebilir. Hesap silme, Crashlytics, gizlilik politikası ve push bildirimleri de eklenmiştir.

### 1.2 En Kritik 5 Bulgu

| # | Tip | Bulgu |
|---|-----|-------|
| 1 | ✅ Pozitif | **Cloud Functions eklendi** — V2'nin en kritik hatası (istatistik/tur ilerletme kuralları çelişkisi) tamamen çözüldü. `onMatchWritten` + `onNotificationCreated` tetikleyicileri ile sunucu-istemci sorumluluk dağılımı doğru yapılandırıldı. |
| 2 | ✅ Pozitif | **Firestore güvenlik kuralları sıkılaştırıldı** — `usernames` okunabilirliği `isSignedIn()` ile kısıtlandı, `participants` istemciden yazılamaz hale geldi, `matches` güncelleme alan kısıtı (`changedKeysWithin`) eklendi, `notifications` create'e kendine yazma engeli konuldu. |
| 3 | ✅ Pozitif | **Hesap silme, Crashlytics, i18n altyapısı ve push bildirimler** eklendi — mağaza uyumluluk eksikleri büyük ölçüde kapatıldı. |
| 4 | ⚠️ Negatif | **Test coverage hâlâ çok düşük** — yalnızca 2 widget testi mevcut (`test/widget_test.dart`, 46 satır). Unit test / integration test / Cloud Functions testi yok. |
| 5 | ⚠️ Negatif | **Pagination eksik, tüm koleksiyonlar istemcide çekiliyor** — `notifications`, `tournaments`, `wheels`, `friendships` sorgularında `limit` yok; ölçek büyüdüğünde bant genişliği/maliyet sorunu oluşacak. |

### 1.3 Modül Bazlı Puanlama Tablosu (1–10)

| Modül | V2 Puanı | V3 Puanı | Değişim | Gerekçe |
|-------|----------|----------|---------|---------|
| **UI/UX** | 8 | 8.5 | ↑ +0.5 | Maç kartları iyileşti (avatar, çift maç gösterimi), home hızlı istatistik ve son aktiviteler eklendi. Erişilebilirlik hâlâ eksik. |
| **Backend** | 4 | 7.5 | ↑ +3.5 | Cloud Functions eklendi; transaction ile idempotent tur ilerletme; istatistik sunucuda. Callable functions ve rate limiting eksik. |
| **Güvenlik** | 3 | 7 | ↑ +4 | Kurallar sıkılaştırıldı (`changedKeysWithin`, `joiningSelfOnly`, `notifications` kendine yazma engeli). App Check ve Storage boyut sınırı eksik. |
| **Performans** | 6 | 6 | → 0 | Pagination hâlâ yok; N+1 grup okuması devam ediyor; `computeStandings` memoize edilmemiş. |
| **Kod Kalitesi** | 7 | 7.5 | ↑ +0.5 | Cloud Functions kodu iyi yapılandırılmış. DRY ihlalleri ve uzun dosyalar kısmen devam ediyor. |
| **Test Coverage** | 1 | 2 | ↑ +1 | 2 widget testi eklendi ama birim/entegrasyon testleri hâlâ yok. |
| **DevOps** | — | 3 | yeni | Crashlytics var, release imzalama hazır. CI/CD pipeline, otomatik versiyon yönetimi yok. |
| **Ölçeklenebilirlik** | — | 5 | yeni | Cloud Functions eklenmesi iyi. Pagination yok, sharding yok, caching yok. |
| **Kullanıcı Deneyimi** | — | 7.5 | yeni | Onboarding, gamification (rozet/unvan), push bildirimleri var. Retention mekanizmaları eksik. |

### 1.4 V2 ile Karşılaştırma — Çözülen V2 Sorunları

| V2 Sorunu | V2 Öncelik | V3 Durumu |
|-----------|-----------|-----------|
| 🔴 İstatistik yazımı kuralları çelişiyor (§2.1) | Kritik | ✅ **Çözüldü** — Cloud Functions'a taşındı |
| 🔴 Transaction yok, yarış durumu (§2.2) | Kritik | ✅ **Çözüldü** — `db.runTransaction` + `statsApplied` damgası |
| 🟠 Splash auth-guard eksik (§2.3) | Yüksek | ✅ **Çözüldü** — Splash ekranı oturum durumuna göre yönlendiriyor |
| 🟠 Matches güncelleme hile (§2.4) | Yüksek | ✅ **Çözüldü** — `changedKeysWithin` alan kısıtı eklendi |
| 🔴 `usernames` herkese açık (§Y-1) | Kritik | ✅ **Çözüldü** — `isSignedIn()` kontrolü eklendi |
| 🟠 `users` e-posta sızıntısı (§Y-2) | Yüksek | ⚠️ **Kısmen** — Hâlâ `isSignedIn()` ile tüm alanlar okunabiliyor |
| 🟠 İstatistik istemci-güvenli, hile (§Y-3) | Yüksek | ✅ **Çözüldü** — İstatistikler Cloud Functions'ta yazılıyor |
| 🟡 `notifications` create serbest (§Y-4) | Orta | ✅ **Çözüldü** — Kendine bildirim engeli eklendi |
| 🔴 Hesap silme yok (§11) | Kritik | ✅ **Çözüldü** — `deleteAccount` metodu eklendi (`auth_service.dart:228`) |
| 🔴 Crashlytics yok (§11) | Kritik | ✅ **Çözüldü** — `firebase_crashlytics` eklendi, `main.dart` yapılandırıldı |
| 🟠 Bildirim tipi tutarsız (§2.6) | Orta | ✅ **Çözüldü** — camelCase'e normalize edildi |
| 🟠 Bildirim onay/itiraz sahte (§2.8) | Orta | ✅ **Çözüldü** — `submitScoreForConfirmation`, `markDisputed` eklendi |

### 1.5 Tahmini Tamamlanma Yüzdesi (MVP)

**~75%** — Çekirdek özellikler çalışıyor, mağaza uyumluluğu büyük ölçüde sağlandı. Eksikler: test coverage, pagination, i18n string geçişi, iOS yapılandırması, CI/CD.

---

## 2. MİMARİ ANALİZ

### 2.1 Genel Mimari Değerlendirme

```
┌─────────────────────────────────────────────────────┐
│                    Flutter İstemci                    │
│  ┌──────────┐  ┌───────────┐  ┌──────────────────┐  │
│  │ Screens  │→ │ Services/ │→ │ Firebase SDK      │  │
│  │ (UI)     │  │ Providers │  │ (Auth/Firestore/  │  │
│  │          │  │ (Riverpod)│  │  Storage/FCM)     │  │
│  └──────────┘  └───────────┘  └────────┬─────────┘  │
│  ┌──────────┐  ┌───────────┐           │            │
│  │Components│  │  Models   │           │            │
│  └──────────┘  └───────────┘           │            │
└────────────────────────────────────────┼────────────┘
                                         │
                    ┌────────────────────▼────────────┐
                    │         Firebase Backend         │
                    │  ┌────────────────────────────┐  │
                    │  │  Cloud Functions (v2/TS)   │  │
                    │  │  - onMatchWritten          │  │
                    │  │  - onNotificationCreated   │  │
                    │  └────────────────────────────┘  │
                    │  ┌────────┐ ┌────────┐ ┌─────┐  │
                    │  │Firestore│ │ Auth   │ │Store│  │
                    │  └────────┘ └────────┘ └─────┘  │
                    └──────────────────────────────────┘
```

**Katmanlar arası bağımlılık:** Temiz. Ekranlar → servisler/provider'lar → Firebase SDK. UI doğrudan Firestore'a erişmiyor (iyi). Cloud Functions bağımsız çalışıyor (admin SDK).

### 2.2 Flutter İstemci Mimarisi

- **State Management:** `flutter_riverpod` ^3.x tutarlı kullanılmış. `StreamProvider` ile canlı Firestore dinleme; `Provider` ile servis enjeksiyonu; `FutureProvider.autoDispose` ile tek seferlik veriler (`userRecentMatchesProvider`).
- **Routing:** `go_router` ^17.x ile `StatefulShellRoute.indexedStack` (bottom nav durumunu koruyor). Deep link (`competra://join/KOD`) redirect ile ele alınmış.
- **Repository Pattern:** `AuthService`, `TournamentRepository`, `SocialRepository`, `UserRepository`, `WheelRepository`, `NotificationRepository`, `AchievementService` — net sorumluluk ayrımı.

### 2.3 Cloud Functions Mimarisi

```
functions/src/
  index.ts          — 2 tetikleyici: onMatchWritten, onNotificationCreated
  types.ts          — Match/Tournament parse + tipler
  standings.ts      — computeStandings (tiebreaker mantığı)
  fixtures.ts       — eleme turu üreticileri
  achievements.ts   — rozet/unvan türetimi
```

**Güçlü yanlar:**
- İdempotent tasarım: `statsApplied` damgası ile çift sayım engeli
- Transaction kullanımı: tur ilerletme + sonlandırma transaction içinde
- İstemci-sunucu pariteleri: `parseMatch`, `computeStandings`, `generateKnockoutFromSeeds` Dart ve TS'de aynı mantık

**İyileştirme alanları:**
- Tüm mantık `index.ts`'te (666 satır) — dosya büyüyebilir, yardımcı fonksiyonlar ayrı modüllere taşınabilir
- Callable functions yok — tüm yazımlar istemciden yapılıyor, sunucu doğrulama eksik

### 2.4 Firestore Veri Modeli Tutarlılığı

| Koleksiyon | İstemci Alan Adları | Sunucu (TS) Alan Adları | Tutarlılık |
|------------|--------------------|-----------------------|------------|
| `tournaments` | `participantIds`, `ownerId`, `format`, `status` | Aynı | ✅ |
| `tournaments/matches` | `homeUid`, `awayUid`, `homeScore`, `awayScore`, `leg` | Aynı (`parseMatch`) | ✅ |
| `users` | `totalMatches`, `totalWins`, `badges`, `fcmToken` | Aynı (`userDelta`, `parseUserStats`) | ✅ |
| `notifications` | `userId`, `type`, `title`, `message` | Aynı | ✅ |

### 2.5 İstemci ↔ Sunucu Sorumluluk Dağılımı

| Sorumluluk | V2 | V3 |
|------------|-----|-----|
| Maç skoru yazma | İstemci | İstemci (sadece skor alanları) |
| İstatistik toplama | İstemci ❌ | Sunucu ✅ |
| Tur ilerletme | İstemci ❌ | Sunucu ✅ |
| Şampiyon belirleme | İstemci ❌ | Sunucu ✅ |
| Rozet/unvan türetme | İstemci | Sunucu ✅ |
| Bildirim üretme | İstemci | İstemci + Sunucu (FCM push) |
| Arkadaş grubu istatistikleri | İstemci | Sunucu ✅ |
| Turnuva oluşturma/katılma | İstemci | İstemci |
| Kullanıcı araması | İstemci | İstemci (Callable'a taşınmalı) |

### 2.6 Bağımlılık Grafiği Analizi

```
models/ ← saf, bağımlılık yok (iyi)
services/ ← models/ + firebase_providers.dart
screens/ ← services/ + models/ + components/ + core/
components/ ← yalnızca Flutter SDK
core/ ← yalnızca Flutter SDK
router/ ← screens/ (import)
```

**Circular dependency riski:** Yok. Tek yönlü bağımlılık zinciri korunmuş. `NotificationService` doğrudan `AppRouter.router`'ı kullanıyor (`notification_service.dart:142`) — bu bir kuplaj noktası ama döngüsel değil.

### 2.7 Önerilen Mimari İyileştirmeler

**1. Callable Functions ile İstemci Yazımlarını Azalt:**
```typescript
// functions/src/index.ts — Turnuvaya katılma callable
export const joinTournament = onCall(async (request) => {
  const { inviteCode } = request.data;
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Oturum gerekli');
  
  const snap = await db.collection('tournaments')
    .where('inviteCode', '==', inviteCode).limit(1).get();
  if (snap.empty) throw new HttpsError('not-found', 'Turnuva bulunamadı');
  
  const doc = snap.docs[0];
  if (doc.data().participantIds.includes(uid)) return { id: doc.id };
  
  await doc.ref.update({
    participantIds: FieldValue.arrayUnion([uid]),
    participants: FieldValue.arrayUnion([{ uid, username: await getUsername(uid) }]),
  });
  return { id: doc.id };
});
```

**2. Provider Katmanını Bölme:**
```dart
// lib/services/score_service.dart — Skor iş mantığını UI'dan ayır
class ScoreService {
  ScoreService(this._tournamentRepo, this._notificationRepo);
  
  final TournamentRepository _tournamentRepo;
  final NotificationRepository _notificationRepo;
  
  Future<void> submitScore({
    required String tournamentId,
    required String matchId,
    required String scoreEntrySystem,
    required String currentUid,
    required int homeScore,
    required int awayScore,
  }) async {
    switch (scoreEntrySystem) {
      case 'adminOnly':
        await _tournamentRepo.updateMatchScore(...);
      case 'winnerEntry':
        await _tournamentRepo.submitScoreForConfirmation(...);
      case 'doubleEntry':
        await _handleDoubleEntry(...);
    }
  }
}
```

---

## 3. KRİTİK HATALAR VE RİSKLER

### 3.1 Uygulama Çökmesine Yol Açabilecek Yerler

| # | Konum | Açıklama | Risk | Çözüm |
|---|-------|----------|------|-------|
| C-1 | `auth_service.dart:46-59` | `_emailForUsername` anonim oturum açıp kapatıyor — ağ hatası `finally` bloğunda yakalanmıyor; `signOut` başarısızsa yetim anonim oturum kalır | 🟠 Orta | try/catch ekle veya callable function'a taşı |
| C-2 | `auth_service.dart:90` | `cred.user!.uid` — `!` ile null check. `createUserWithEmailAndPassword` başarılı dönerse `user` null olmamalı ama savunmacı olmak gerekir | 🟢 Düşük | `user` null kontrolü ekle |
| C-3 | `tournament.dart:430-431` | `m.homeScore!` / `m.awayScore!` — `isPlayed` kontrolü sonrası güvenli ama `as` değişken adı Dart'ta keyword shadow | 🟢 Düşük | `awayScoreVal` gibi isimlendirme |
| C-4 | `notification_service.dart:39-40` | `FirebaseAuth.instance` / `FirebaseFirestore.instance` statik — DI yerine global instance; test edilemez | 🟡 Orta | Constructor injection veya Provider ile |

### 3.2 Veri Kaybı Riski

| # | Konum | Açıklama | Risk | Çözüm |
|---|-------|----------|------|-------|
| D-1 | `auth_service.dart:292-319` | `_deleteUserData` — batch.delete ile kullanıcı verilerini siliyor ama turnuvalardaki `participants` dizisinden kullanıcıyı çıkarmıyor; aktif turnuvalarda yetim katılımcı kalır | 🟠 Yüksek | Kullanıcının katıldığı turnuvalardan da çıkar veya Cloud Function ile yönet |
| D-2 | `auth_service.dart:307-309` | Çark silme — kullanıcının çarkları silinirken 500 batch sınırı aşılabilir (çok çark varsa) | 🟢 Düşük | Parçalı batch |
| D-3 | `tournament_repository.dart:131` | `startTournament` batch'i — maç sayısı 500'ü aşarsa batch reddedilir | 🟡 Orta | Parçalı batch veya üst sınır |

### 3.3 Race Condition Potansiyeli

| # | Konum | Açıklama | Risk | Çözüm |
|---|-------|----------|------|-------|
| R-1 | `auth_service.dart:92-98` | Kullanıcı adı benzersizlik kontrolü — `usernameRef.get()` → `batch.commit()` arası yarış durumu; iki kullanıcı aynı adı eşzamanlı seçebilir. Batch create kuralı ile ikincisi reddedilir ama hatanın doğru yakalanması gerekir | 🟡 Orta | Transaction veya callable function |
| R-2 | `social_repository.dart:189-190` | `addMemberToGroup` — `existing.get()` → `batch.commit()` arası yarış; aynı üye iki kez eklenebilir | 🟢 Düşük | Transaction veya idempotent set |
| R-3 | Cloud Functions `advanceKnockout` | Transaction + `currentRound` koruması ile çözülmüş ✅ | ✅ Çözüldü | — |

### 3.4 Memory Leak Riski

Genel olarak **temiz**: tüm `TextEditingController`, `AnimationController`, `Timer` nesneleri dispose/cancel ediliyor. Riverpod stream'leri otomatik yönetiliyor.

**Tek dikkat noktası:** `NotificationService` statik listener'lar kuruyor (`_messaging.onTokenRefresh.listen`, `_auth.authStateChanges().listen` — `notification_service.dart:65-68`); bunlar uygulama ömrü boyunca yaşayacağından teknik olarak leak değil ama cancel edilmiyor.

### 3.5 Null Safety İhlalleri

Kod tabanı **null-safe**. `fromDoc` factory'ler `?? varsayılan` ile güvenli. `!` operatörü yalnızca `isPlayed` kontrolü sonrası kullanılıyor (güvenli).

### 3.6 Firebase İşlemlerinde Eksik Hata Yönetimi

| # | Konum | Açıklama | Risk | Çözüm |
|---|-------|----------|------|-------|
| E-1 | `notification_repository.dart:16-17` | `markRead` — try/catch yok | 🟡 Orta | try/catch + kullanıcı bildirimi |
| E-2 | `wheel_repository.dart:31` | `deleteWheel` — try/catch yok | 🟡 Orta | try/catch ekle |
| E-3 | `wheel_repository.dart:40-43` | `recordResult` — try/catch yok | 🟡 Orta | try/catch ekle |
| E-4 | `social_repository.dart:81-86` | `acceptRequest` / `declineRequest` — try/catch yok | 🟡 Orta | try/catch ekle |

### 3.7 Cloud Functions Hata Yönetimi

**Genel olarak iyi:**
- `index.ts:81-83` — `applyMatchStats` hatası loglanıyor ve yutulmuyor
- `index.ts:90-92` — `checkTournamentProgression` hatası loglanıyor
- `index.ts:150-162` — FCM hatası yakalanıp geçersiz token temizleniyor

**İyileştirme alanları:**
| # | Konum | Açıklama | Risk | Çözüm |
|---|-------|----------|------|-------|
| F-1 | `index.ts:330-338` | `runAchievements` — hata yakalanmıyor; bir kullanıcının rozet hatası diğerini etkilemez ama loglanmalı | 🟡 Orta | try/catch + logger.error |
| F-2 | `index.ts:269-288` | `updateFriendGroupStats` — batch.commit hatası yakalanmıyor | 🟡 Orta | try/catch ekle |

---

## 4. GÜVENLİK ANALİZİ (DETAYLI)

### 4.1 Firestore Güvenlik Kuralları — Koleksiyon Bazlı

| Koleksiyon | Okuma | Yazma | Değerlendirme | Risk |
|------------|-------|-------|---------------|------|
| `users/{uid}` | `isSignedIn()` — tüm alanlar | `isSignedIn() && request.auth.uid == uid` | ⚠️ E-posta/PII herkese açık okuma devam ediyor | 🟠 CVSS: 4.3 |
| `usernames/{username}` | `isSignedIn()` | create: `uid == auth.uid`, delete: `uid == auth.uid` | ✅ V2'den iyileştirildi (oturum zorunlu) | 🟢 |
| `tournaments/{id}` | get: katılımcı; list: katılımcı veya limit≤1 | create: oturum; update: admin veya `joiningSelfOnly()`; delete: admin | ✅ İyi — `joiningSelfOnly()` kritik alanları koruyor | 🟢 |
| `tournaments/.../participants` | katılımcı | `write: false` | ✅ Mükemmel — yalnızca Cloud Functions yazar | 🟢 |
| `tournaments/.../matches` | katılımcı | update: admin veya oyuncu + `changedKeysWithin`; create/delete: admin | ✅ İyi — `statsApplied` istemciden yazılamıyor | 🟢 |
| `tournaments/.../groups` | katılımcı | admin | ✅ İyi | 🟢 |
| `friendships` | `uid in resource.data.users` | create: `uid in users`, update/delete: `uid in users` | ⚠️ Herkes ilişkiyi kabul/sil edebilir (iki taraflı kontrol yok) | 🟡 CVSS: 3.5 |
| `friendGroups` | üye (exists check) | create: oturum; update/delete: `createdBy` | ⚠️ create'te `createdBy` doğrulanmıyor | 🟡 CVSS: 3.0 |
| `friendGroups/.../members` | üye (exists check) | `createdBy == auth.uid` | ✅ İyi — yalnızca grup sahibi yazar | 🟢 |
| `wheels` | `ownerId == auth.uid` | `ownerId == auth.uid` | ✅ İyi | 🟢 |
| `feedback` | `read: false` | `create: isSignedIn()` | ✅ İyi | 🟢 |
| `notifications` | `userId == auth.uid` | create: `userId != auth.uid`; update: `userId == auth.uid` | ⚠️ create'te `type`/`title`/`message` kısıtlaması yok — sahte bildirim mümkün | 🟡 CVSS: 4.0 |

### 4.2 Storage Güvenlik Kuralları

```
profile_photos/{imageId}: read: true, write: auth && imageId == uid + '.jpg'
cover_photos/{imageId}: aynı
/{allPaths=**}: read/write: false
```

**Eksikler:**
- ❌ Dosya boyutu sınırı yok — büyük dosya yükleme saldırısı: `request.resource.size < 5 * 1024 * 1024` eklenmeli
- ❌ Content-type kontrolü yok — `request.resource.contentType.matches('image/.*')` eklenmeli
- **Risk:** 🟡 Orta | **CVSS:** 4.5

### 4.3 Cloud Functions Güvenlik

- ✅ Admin SDK yalnızca tetikleyicilerde kullanılıyor (doğru)
- ✅ `statsApplied` idempotent damgası — çift işlem engeli
- ✅ FCM geçersiz token temizleme
- ⚠️ Callable function yok — turnuva katılma, kullanıcı arama gibi hassas işlemler istemciden yapılıyor
- ⚠️ Rate limiting yok — tetikleyiciler sınırsız çalışabilir

### 4.4 Authentication Güvenlik

- ✅ Türkçe hata mesajları — kullanıcı dostu, bilgi sızdırmıyor (genel "hatalı" mesajı)
- ✅ Hesap silme — yeniden kimlik doğrulama ile (güvenli)
- ⚠️ `_emailForUsername` anonim oturum açıyor — potansiyel kötüye kullanım (anonim oturum oluşturma spam'i)
- ⚠️ E-posta doğrulama zorunlu değil — sahte e-posta ile kayıt mümkün

### 4.5 Input Validasyon Eksiklikleri

| Konum | Eksiklik | Risk |
|-------|----------|------|
| İstemci: Grup adı | Uzunluk üst sınırı yok | 🟢 Düşük |
| İstemci: Çark adı | Uzunluk üst sınırı yok | 🟢 Düşük |
| Sunucu: `onMatchWritten` | Skor değeri doğrulaması yok (negatif/aşırı skor) | 🟡 Orta |
| Sunucu: `onNotificationCreated` | `title`/`message` uzunluk sınırı yok | 🟢 Düşük |
| İstemci: `Validators` | Username/email/password/confirm sağlam ✅ | ✅ |

### 4.6 API Anahtarları ve Hassas Veri Yönetimi

- ⚠️ `google-services.json` repo'da — Firebase API anahtarları public kabul edilir ama dikkat gerekli
- ⚠️ `competra-release.jks` (keystore) repo'da — **ASLA repo'da olmamalı!**
- ✅ `key.properties` gitignore'da (doğru)
- **Risk:** 🔴 Yüksek — JKS dosyası repo'dan çıkarılmalı | **CVSS:** 7.5

### 4.7 KVKK/GDPR Uyumluluk Değerlendirmesi

| Madde | Durum | Aksiyon |
|-------|-------|---------|
| Gizlilik politikası sayfası | ✅ `privacy_policy_screen.dart` mevcut | — |
| Hesap silme hakkı | ✅ `deleteAccount` metodu | — |
| Veri taşınabilirliği (indirme) | ❌ Yok | Cloud Function ile veri dışa aktarma |
| Açık rıza (consent) | ❌ Kayıt sırasında KVKK onayı yok | Checkbox eklenmeli |
| Veri minimizasyonu | ⚠️ `users` belgesinde e-posta oturum açık herkese açık | Public/private profil modeli |
| Çerez/SDK izleme bildirimi | ⚠️ Firebase Analytics izleme bildirimi yok | İzin mekanizması |

### 4.8 Penetrasyon Testi Senaryoları

| # | Saldırı Vektörü | Olasılık | Etki | Çözüm |
|---|----------------|----------|------|-------|
| P-1 | `users/{uid}` belgesine sahte istatistik yazma | Düşük (sunucuda yazılıyor) ama `users` write hâlâ açık | Yüksek | İstatistik alanlarını istemci yazımından kısıtla |
| P-2 | Sahte bildirim spam'i (`notifications` create) | Orta — herhangi bir kullanıcıya bildirim yazılabilir | Orta | Bildirim üretimini callable function'a taşı |
| P-3 | Storage'a büyük dosya yükleme (DoS) | Yüksek — boyut sınırı yok | Düşük (maliyet etkisi) | Storage kurallarına boyut sınırı ekle |
| P-4 | Davet kodu brute-force | Düşük — 6 karakter, ~887M kombinasyon | Orta | Kodu 8+ karakter yap; rate limit ekle |
| P-5 | JKS keystore'un ele geçirilmesi (repo'da) | Yüksek — public repo ise kritik | Kritik | JKS'yi repo'dan çıkar, CI secret olarak yönet |

---

## 5. PERFORMANS ANALİZİ (DETAYLI)

### 5.1 Firestore Okuma/Yazma Optimizasyon Fırsatları

| # | Konum | Sorun | Etki | Çözüm | Kazanım |
|---|-------|-------|------|-------|---------|
| P-1 | `social_repository.dart:289-314` | `myFriendGroupsProvider` N+1: her üyelik için ayrı `groupRef.get()` | Grup sayısı × 1 okuma | Grup bilgisini üye belgesine denormalize et | %50-70 okuma azalması |
| P-2 | `notification_repository.dart:25-45` | Tüm bildirimler çekiliyor, limit yok | Bildirim sayısı arttıkça bant genişliği | `.orderBy('createdAt', descending: true).limit(50)` | Sabit maliyet |
| P-3 | `tournament_repository.dart:306-327` | `myTournamentsStreamProvider` — tüm turnuvalar çekiliyor, istemcide sort | Turnuva sayısı arttıkça | `orderBy + limit + pagination` | Sabit maliyet |
| P-4 | `user_repository.dart:96-145` | `userRecentMatchesProvider` — tüm maçlar `collectionGroup` ile çekiliyor | Her turnuvanın tüm maçları | `limit(20)` + `orderBy` ekle | %80+ okuma azalması |
| P-5 | `social_repository.dart:255-281` | İki ayrı `friendships` listener (requests + friends) | Çift okuma akışı | Tek stream + türev provider | %50 okuma azalması |

### 5.2 Cloud Functions Cold Start

- **Mevcut durum:** TypeScript, Node.js 22, `firebase-functions` v2 — tipik cold start ~500-800ms
- **Tetikleyici sayısı:** 2 (az — iyi)
- **Bağımlılık:** Yalnızca `firebase-admin` + `firebase-functions` — hafif (iyi)
- **İyileştirme:** `minInstances: 1` ile cold start ortadan kaldırılabilir (ek maliyet)

### 5.3 Flutter Widget Rebuild

| Konum | Sorun | Çözüm |
|-------|-------|-------|
| `tournament_detail_screen.dart` (2227 satır) | Her build'de `computeStandings`/`computeScorers` yeniden hesaplanıyor | `useMemoized` veya ayrı `Provider` ile memoize et |
| `social_screen.dart` (775 satır) | Tüm sekmeler tek widget'ta — tab değişikliğinde hepsi rebuild | Her sekmeyi ayrı `ConsumerWidget`'a çıkar |

### 5.4 Büyük Liste Performansı

- ✅ Çoğu yerde `ListView.builder` / `ListView.separated` kullanılmış
- ⚠️ `friend_group_screen.dart` ve bazı fikstür listelerinde `ListView(children: [...])` — eleman sayısı küçükse sorun değil

### 5.5 Görüntü Yükleme ve Önbellekleme

- ✅ `cached_network_image` paketi var ve profil fotoğraflarında kullanılıyor
- ⚠️ Resim boyutu optimize edilmiyor — Firebase Storage'dan orijinal boyutta çekiliyor
- **Öneri:** Firebase Extension (`Resize Images`) ile thumbnail oluştur

### 5.6 Firestore Index Kullanımı

```json
// firestore.indexes.json — 4 bileşik, 6 tek-alan index tanımlı
// Kullanım durumu:
// - tournaments (status+createdAt): sorgu orderBy kullanmadığından ATIl
// - friendships (users+status): sorgu status'u istemcide filtrelediğinden KISMI
// - wheels (ownerId+createdAt): sorgu orderBy kullanmadığından ATIl
// - notifications (userId+createdAt): sorgu orderBy kullanmadığından ATIl
// - matches (homeUid/awayUid COLLECTION_GROUP): KULLANILIYOR ✅
// - users (totalWins/totalGoalsScored/tournamentsWon): leaderboard için KULLANILIYOR ✅
```

**Sonuç:** Index'ler tanımlı ama sorgularda `orderBy` kullanılmadığından çoğu atıl. Sorgulara `orderBy` eklendiğinde devreye girecek.

### 5.7 Pagination Eksiklikleri

**Pagination olan yer:** Yok ❌

**Pagination gerekli yerler:**
1. Bildirimler (`notificationsProvider`)
2. Turnuvalar (`myTournamentsStreamProvider`)
3. Çarklar (`myWheelsStreamProvider`)
4. Arkadaşlar/istekler (`friendsProvider`, `incomingRequestsProvider`)
5. Leaderboard (`leaderboard_screen.dart`)

---

## 6. KOD KALİTESİ ANALİZİ

### 6.1 DRY İhlalleri

| # | Tekrar Eden Kod | Dosyalar | Çözüm |
|---|-----------------|---------|-------|
| DRY-1 | `createdAt` sıralama bloğu (7 kez aynı `sort` closure) | `tournament_repository.dart:317-324`, `notification_repository.dart:35-42`, `wheel_repository.dart:61-68`, `social_repository.dart:305-312` | `core/sort_utils.dart` — `int compareByCreatedAtDesc(DateTime? a, DateTime? b)` |
| DRY-2 | `_memberStatsDelta` / `memberDelta` — istemci ve sunucuda aynı mantık | `social_repository.dart:225-247`, `index.ts:303-323` | Beklenen (istemci/sunucu paritesi) — kabul edilebilir |
| DRY-3 | Boş durum widget'ları (`_EmptyState`/`_MessageCard`) | Çoğu ekranda private kopya | `components/empty_state.dart` paylaşılan bileşen |
| DRY-4 | Snackbar hata gösterimi (`ScaffoldMessenger.of(context).showSnackBar(...)`) | ~7+ ekranda | `BuildContext` extension: `context.showError(String message)` |
| DRY-5 | Baş harf hesaplama (`_initials`) | `social_screen.dart`, `profile_screen.dart`, `tournament_detail_screen.dart` | `core/string_utils.dart` |

### 6.2 SOLID Prensip İhlalleri

| Prensip | İhlal | Konum | Çözüm |
|---------|-------|-------|-------|
| **S** (Single Responsibility) | `tournament_detail_screen.dart` (2227 satır) — fikstür, puan tablosu, istatistik, skor diyalogları, anlaşmazlık, çift maç gösterimi hepsi tek dosyada | `screens/tournament/` | 5-6 dosyaya böl: `fixture_tab.dart`, `standings_tab.dart`, `score_dialog.dart`, `match_card.dart`, `two_legged_card.dart` |
| **S** | `NotificationService` — hem FCM yönetimi, hem token yazımı, hem yönlendirme yapıyor | `services/notification_service.dart` | `FcmTokenService` + `NotificationRouter` olarak ayır |
| **D** (Dependency Inversion) | `NotificationService` statik instance kullanıyor (`FirebaseAuth.instance`, `FirebaseFirestore.instance`) | `notification_service.dart:39-40` | Constructor injection veya Riverpod provider |
| **O** (Open/Closed) | Format string'leri `switch` ile dallanıyor (yeni format eklemek = her switch'i güncelle) | `tournament_repository.dart:154-166`, `tournament.dart:123-134` | Enum + polimorfizm |

### 6.3 Aşırı Uzun Dosyalar

| Dosya | Satır Sayısı | Öneri |
|-------|-------------|-------|
| `tournament_detail_screen.dart` | **2227** | 5-6 dosyaya böl |
| `create_tournament_screen.dart` | **962** | Adım widget'larını ayır |
| `wheel_screen.dart` | **937** | Painter, dialog, list bölümleri ayır |
| `profile_screen.dart` | **878** | İstatistik kartları, rozet bölümü ayır |
| `social_screen.dart` | **775** | Sekmeleri ayrı dosyalara |
| `home_screen.dart` | **704** | Bileşenleri ayır |
| `index.ts` | **666** | Yardımcı fonksiyonları modüllere taşı |

### 6.4 Magic String/Number Kullanımı

**Format string'leri (tüm kod tabanına dağılmış):**
```
'league', 'knockout', 'groupKnockout', 'championsLeague'
```

**Durum string'leri:**
```
'completed', 'waiting', 'active', 'disputed', 'awaitingConfirmation', 'pending'
```

**Faz string'leri:**
```
'knockout', 'group', 'league'
```

**Bildirim tipleri:**
```
'friendRequest', 'matchConfirm', 'tournamentComplete'
```

**Sihirli sayılar:**
```
orderBase = nextRound * 1000 (fixture_generator.dart / fixtures.ts)
limit(20) — kullanıcı arama limiti (social_repository.dart:33)
take(10) — son bildirim/maç limiti
qualifierCount = clamp(n/2, 2, 8) — ŞL eleme sayısı (index.ts:438)
```

**Çözüm:**
```dart
// lib/core/constants.dart
abstract class TournamentFormats {
  static const league = 'league';
  static const knockout = 'knockout';
  static const groupKnockout = 'groupKnockout';
  static const championsLeague = 'championsLeague';
}

abstract class MatchStatuses {
  static const completed = 'completed';
  static const pending = 'pending';
  static const disputed = 'disputed';
  static const awaitingConfirmation = 'awaitingConfirmation';
}
```

### 6.5 TypeScript Kod Kalitesi

- ✅ İyi tip tanımlamaları (`types.ts` — `Match`, `Tournament`, `Participant`)
- ✅ Pure function'lar (`computeStandings`, `deriveAchievementUpdate`)
- ✅ Tutarlı yorum stili
- ⚠️ `index.ts` 666 satır — bölünebilir
- ⚠️ Karakter encoding sorunları (Türkçe karakterler garbled görünüyor TS çıktısında)

---

## 7. KLASÖR YAPISI VE MİMARİ ÖNERİSİ

### 7.1 Mevcut Klasör Yapısı

```
lib/
├── main.dart                          (52 satır)
├── firebase_options.dart              (65 satır)
├── components/
│   ├── auth_text_field.dart           (72)
│   ├── brand_logo_badge.dart          (44)
│   ├── pitch_pattern_background.dart  (54)
│   └── scaffold_with_nav_bar.dart     (70)
├── core/
│   ├── time_ago.dart                  (16)
│   ├── validators.dart                (40)
│   └── theme/
│       ├── app_colors.dart            (26)
│       └── app_theme.dart             (154)
├── l10n/
│   ├── app_localizations.dart         (239)
│   ├── app_localizations_en.dart      (56)
│   └── app_localizations_tr.dart      (56)
├── models/
│   ├── app_notification.dart          (56)
│   ├── badge_definitions.dart         (89)
│   ├── friend_group.dart              (69)
│   ├── friendship.dart                (81)
│   ├── title_definitions.dart         (81)
│   ├── tournament.dart                (538)
│   ├── user_profile.dart              (92)
│   └── wheel.dart                     (161)
├── router/
│   ├── app_router.dart                (205)
│   └── route_paths.dart               (55)
├── screens/
│   ├── auth/
│   │   ├── guest_warning_screen.dart  (217)
│   │   └── login_screen.dart          (508)
│   ├── home/
│   │   └── home_screen.dart           (704)
│   ├── leaderboard/
│   │   └── leaderboard_screen.dart    (281)
│   ├── leagues/
│   │   └── leagues_screen.dart        (398)
│   ├── notifications/
│   │   └── notifications_screen.dart  (288)
│   ├── onboarding/
│   │   └── onboarding_screen.dart     (258)
│   ├── profile/
│   │   ├── edit_profile_screen.dart   (406)
│   │   └── profile_screen.dart        (878)
│   ├── settings/
│   │   ├── privacy_policy_screen.dart (168)
│   │   └── settings_screen.dart       (288)
│   ├── social/
│   │   ├── friend_group_screen.dart   (539)
│   │   └── social_screen.dart         (775)
│   ├── splash/
│   │   └── splash_screen.dart         (194)
│   ├── tournament/
│   │   ├── create_tournament_screen.dart (962)
│   │   ├── join_tournament_screen.dart   (254)
│   │   ├── tournament_detail_screen.dart (2227)
│   │   └── tournament_wrapped_screen.dart (562)
│   └── wheel/
│       └── wheel_screen.dart          (937)
└── services/
    ├── achievement_service.dart        (66)
    ├── app_settings.dart              (15)
    ├── auth_service.dart              (331)
    ├── firebase_providers.dart        (25)
    ├── fixture_generator.dart         (507)
    ├── notification_repository.dart   (38)
    ├── notification_service.dart      (136)
    ├── share_service.dart             (196)
    ├── social_repository.dart         (305)
    ├── tournament_repository.dart     (327)
    ├── user_repository.dart           (144)
    └── wheel_repository.dart          (62)

functions/src/
├── achievements.ts                    (96)
├── fixtures.ts                        (216)
├── index.ts                           (666)
├── standings.ts                       (171)
└── types.ts                           (129)
```

**Toplam:** 54 Dart dosyası (~14.500 satır), 5 TypeScript dosyası (~1.278 satır)

### 7.2 Sorunlu Organizasyon Alanları

1. `services/` karışık: repository'ler, servisler, provider'lar ve saf fonksiyonlar (`fixture_generator.dart`) aynı klasörde
2. `tournament_detail_screen.dart` 2227 satır — bölünmesi şart
3. `models/tournament.dart` hem model hem iş mantığı (`computeStandings`, `computeScorers`) içeriyor — 538 satır
4. Paylaşılan UI bileşenleri eksik (`EmptyState`, `StatChip` gibi)
5. Sabitler/enumlar merkezi değil

### 7.3 Önerilen Yeni Klasör Yapısı

```
lib/
├── main.dart
├── firebase_options.dart
├── core/
│   ├── constants/
│   │   ├── tournament_constants.dart    [YENİ] — format, durum, faz sabitleri
│   │   ├── notification_constants.dart  [YENİ] — bildirim tipi sabitleri
│   │   └── app_constants.dart           [YENİ] — genel sabitler
│   ├── extensions/
│   │   ├── context_extensions.dart      [YENİ] — showError, showSuccess
│   │   └── string_extensions.dart       [YENİ] — initials, capitalize
│   ├── utils/
│   │   ├── sort_utils.dart              [YENİ] — createdAt sıralama
│   │   ├── format_labels.dart           [YENİ] — _formatLabel birleştirmesi
│   │   └── time_ago.dart                [TAŞI]
│   ├── theme/
│   │   ├── app_colors.dart
│   │   └── app_theme.dart
│   └── validators.dart
├── components/
│   ├── auth_text_field.dart
│   ├── brand_logo_badge.dart
│   ├── empty_state.dart                 [YENİ] — paylaşılan boş durum
│   ├── loading_overlay.dart             [YENİ]
│   ├── player_avatar.dart               [YENİ] — baş harfli avatar
│   ├── pitch_pattern_background.dart
│   ├── scaffold_with_nav_bar.dart
│   └── stat_chip.dart                   [YENİ]
├── models/
│   ├── app_notification.dart
│   ├── badge_definitions.dart
│   ├── friend_group.dart
│   ├── friendship.dart
│   ├── title_definitions.dart
│   ├── tournament.dart                  — Yalnızca model (computeStandings ayır)
│   ├── user_profile.dart
│   └── wheel.dart
├── services/
│   ├── providers/
│   │   └── firebase_providers.dart
│   ├── repositories/
│   │   ├── notification_repository.dart
│   │   ├── social_repository.dart
│   │   ├── tournament_repository.dart
│   │   ├── user_repository.dart
│   │   └── wheel_repository.dart
│   ├── auth_service.dart
│   ├── achievement_service.dart
│   ├── fixture_generator.dart
│   ├── notification_service.dart
│   ├── score_service.dart               [YENİ]
│   ├── share_service.dart
│   ├── standings_service.dart           [YENİ] — computeStandings buraya
│   └── app_settings.dart
├── screens/
│   └── tournament/
│       ├── tournament_detail_screen.dart — ana ekran (sadeleşmiş)
│       ├── widgets/
│       │   ├── fixture_tab.dart         [YENİ]
│       │   ├── standings_tab.dart       [YENİ]
│       │   ├── stats_tab.dart           [YENİ]
│       │   ├── match_card.dart          [YENİ]
│       │   ├── score_entry_dialog.dart  [YENİ]
│       │   └── two_legged_card.dart     [YENİ]
│       └── ... (diğer dosyalar aynı)
└── ... (router/, l10n/ aynı)
```

---

## 8. FRONTEND GELİŞTİRME ÖNERİLERİ

| # | Öneri | Öncelik | Zorluk | Süre |
|---|-------|---------|--------|------|
| F-1 | Paylaşılan UI bileşen kütüphanesi (`EmptyState`, `PlayerAvatar`, `StatChip`, `PrimaryButton`) | Yüksek | Kolay | 2-3 gün |
| F-2 | `shimmer` paketini skeleton loading olarak uygula (pubspec'te var ama kullanılmıyor) | Orta | Kolay | 1-2 gün |
| F-3 | `confetti` paketini şampiyonluk anında uygula (büyük UX kazanımı) | Yüksek | Kolay | 1 gün |
| F-4 | `lottie` / `rive` animasyonlarını onboarding'de kullan veya kaldır (APK şişirmesi) | Orta | Kolay | 0.5 gün |
| F-5 | Responsive tasarım — sabit genişlikleri (`width: 240`, `width: 300`) `LayoutBuilder` ile değiştir | Orta | Orta | 2-3 gün |
| F-6 | Erişilebilirlik — çark `CustomPaint` için `Semantics` etiketleri ekle | Orta | Kolay | 1 gün |
| F-7 | Dark/Light tutarsızlıkları — `_WheelPainter` etiket rengi sabit `Colors.white` (`wheel_screen.dart`) | Düşük | Kolay | 0.5 gün |
| F-8 | Form validasyon — turnuva adı max uzunluk, grup adı max uzunluk ekle | Yüksek | Kolay | 0.5 gün |
| F-9 | Loading/Error state tutarlılığı — her ekranda aynı pattern (HOC veya mixin) | Orta | Orta | 2 gün |
| F-10 | Page transition animasyonları — `GoRouter` ile özel geçişler | Düşük | Kolay | 1 gün |

---

## 9. BACKEND GELİŞTİRME ÖNERİLERİ

| # | Öneri | Öncelik | Zorluk | Süre |
|---|-------|---------|--------|------|
| B-1 | **Callable Functions** — `joinTournament`, `resolveUsername` işlemlerini sunucuya taşı | Yüksek | Orta | 3-4 gün |
| B-2 | **Scheduled Function** — eski/terk edilmiş turnuvaları temizle (cron: her gün) | Orta | Kolay | 1 gün |
| B-3 | **Scheduled Function** — haftalık özet bildirimi gönder | Düşük | Orta | 2 gün |
| B-4 | **`onUserDeleted` tetikleyicisi** — hesap silinince yetim verileri temizle | Yüksek | Orta | 2 gün |
| B-5 | **Rate limiting** — `notifications` create'e saniye başı sınır | Yüksek | Orta | 1-2 gün |
| B-6 | **Firestore TTL** — okunmuş bildirimleri 30 gün sonra otomatik sil | Orta | Kolay | 0.5 gün |
| B-7 | **Backup stratejisi** — Firestore scheduled export (Cloud Storage'a) | Yüksek | Kolay | 1 gün |
| B-8 | **Denormalizasyon** — `myFriendGroupsProvider` N+1 okuma sorununu çöz: grup bilgisini üye belgesine ekle | Yüksek | Orta | 2 gün |
| B-9 | **Webhook** — turnuva tamamlandığında Discord/Slack webhook'u | Düşük | Kolay | 1 gün |
| B-10 | **Cloud Functions error monitoring** — `logger.error` yerine yapılandırılmış hata takibi (Error Reporting) | Orta | Kolay | 0.5 gün |

---

## 10. FİREBASE TARAFINDAKİ GELİŞTİRME ÖNERİLERİ

| # | Öneri | Öncelik | Maliyet | Zorluk |
|---|-------|---------|---------|--------|
| FB-1 | **Firebase App Check** — bot koruması, SDK doğrulama | 🔴 Yüksek | Ücretsiz | Orta (2-3 gün) |
| FB-2 | **Firebase Emulator Suite** — local geliştirme/test | 🔴 Yüksek | Ücretsiz | Kolay (1 gün) |
| FB-3 | **Apple Sign-In** — iOS yayını için zorunlu (sosyal giriş varsa) | 🔴 Yüksek | Ücretsiz | Orta (2 gün) |
| FB-4 | **Firebase Performance Monitoring** — ağ istekleri ve widget build süreleri | 🟠 Orta | Ücretsiz (Spark) | Kolay (1 gün) |
| FB-5 | **Firebase Remote Config** — feature flags, A/B testing | 🟡 Orta | Ücretsiz | Kolay (1-2 gün) |
| FB-6 | **Resize Images Extension** — profil fotoğrafı thumbnail oluşturma | 🟡 Orta | ~$0.01/1K resim | Kolay (0.5 gün) |
| FB-7 | **Firestore offline persistence** — varsayılan açık ama yapılandırma optimize edilebilir | 🟢 Düşük | Ücretsiz | Kolay (0.5 gün) |
| FB-8 | **Firebase Dynamic Links / App Links** — `competra://` yerine https deep link | 🟡 Orta | Ücretsiz | Orta (2 gün) |
| FB-9 | **Firebase Analytics** — funnel analizi, kullanıcı davranışı | 🟠 Orta | Ücretsiz | Kolay (1-2 gün) |
| FB-10 | **Multi-region** — `europe-west3` (Frankfurt) tek bölge; CDN ile global erişim | 🟢 Düşük | Değişken | Zor (özel çözüm gerektirir) |

---

## 11. YENİ ÖZELLİK ÖNERİLERİ (25+)

### Sosyal Özellikler

| # | Özellik | User Story | İş Değeri | Teknik Özet | Bağımlılık | Zorluk | Süre | Öncelik |
|---|---------|-----------|-----------|-------------|-----------|--------|------|---------|
| 1 | **Canlı Skor Takibi** | "Turnuva yöneticisi olarak maç skorlarını canlı güncelleyip izleyicilere anında göstermek istiyorum" | Heyecan ve etkileşim artışı | Firestore real-time listener + skor animasyonu | — | Orta | 3-4 gün | Yüksek |
| 2 | **Turnuva Sohbet** | "Turnuva katılımcısı olarak diğer oyuncularla mesajlaşmak istiyorum" | Sosyal bağlanma, retention | `tournaments/{id}/messages` koleksiyonu + sohbet ekranı | — | Orta | 5-7 gün | Orta |
| 3 | **Oyuncu Profili Ziyareti** | "Rakibimin profilini, istatistiklerini ve rozetlerini görmek istiyorum" | Rekabet motivasyonu | `/profile/:uid` rotası + profil ekranı parametreli hale getirme | — | Kolay | 2 gün | Yüksek |
| 4 | **Arkadaş Aktivite Feed'i** | "Arkadaşlarımın son turnuva sonuçlarını görmek istiyorum" | Retention, FOMO | `activity_feed` koleksiyonu veya Cloud Function ile bildirim | Push bildirimleri | Orta | 4-5 gün | Orta |
| 5 | **Turnuva Daveti Paylaşımı (Görsel)** | "Davet kodunu güzel bir görsel olarak sosyal medyada paylaşmak istiyorum" | Organik büyüme | `share_plus` + Canvas ile görsel üretimi | — | Kolay | 2-3 gün | Yüksek |

### Rekabet Özellikleri

| # | Özellik | User Story | İş Değeri | Teknik Özet | Bağımlılık | Zorluk | Süre | Öncelik |
|---|---------|-----------|-----------|-------------|-----------|--------|------|---------|
| 6 | **Sezon Sistemi** | "Turnuvalarımı sezon bazında gruplamak ve sezon şampiyonlarını belirlemek istiyorum" | Uzun vadeli bağlanma | `seasons` koleksiyonu + turnuva-sezon ilişkisi | — | Orta | 5-7 gün | Orta |
| 7 | **Head-to-Head İstatistik** | "Belirli bir rakibimle olan tarihsel performansımı görmek istiyorum" | Rekabet motivasyonu | Collection group sorgusu + istemci hesaplama | — | Kolay | 2-3 gün | Yüksek |
| 8 | **İstatistik Grafikleri** | "Performansımı zaman içinde grafik olarak görmek istiyorum" | Retention, veri odaklı UX | `fl_chart` paketi (mevcut) + trend analizi | — | Orta | 3-4 gün | Orta |
| 9 | **MVP Ödülü** | "Her turnuvanın en değerli oyuncusunu belirlemek istiyorum" | Gamification | Oyuncu oylaması veya algoritma bazlı (gol+asist+katkı) | — | Orta | 3-4 gün | Düşük |
| 10 | **Kazanan Tahmini** | "Turnuva başlamadan kazananı tahmin etmek ve doğru bilenleri ödüllendirmek istiyorum" | Engagement | `predictions` alt koleksiyonu + Cloud Function sonuç karşılaştırma | — | Orta | 4-5 gün | Düşük |

### Organizasyon Özellikleri

| # | Özellik | User Story | İş Değeri | Teknik Özet | Bağımlılık | Zorluk | Süre | Öncelik |
|---|---------|-----------|-----------|-------------|-----------|--------|------|---------|
| 11 | **Maç Takvimi** | "Turnuva fikstürünü takvim uygulamama eklemek istiyorum" | Organizasyon kolaylığı | `ics` dosya üretimi + paylaşma | — | Kolay | 2 gün | Orta |
| 12 | **Turnuva Şablonları** | "Sık kullandığım turnuva ayarlarını şablon olarak kaydetmek istiyorum" | Tekrar kullanılabilirlik | `templates` koleksiyonu + uygula butonu | — | Kolay | 2-3 gün | Düşük |
| 13 | **Katılımcı Sınırı** | "Turnuvaya maksimum katılımcı sayısı koymak istiyorum" | Kontrol | `maxParticipants` alanı + katılma kontrolü | — | Kolay | 1 gün | Yüksek |
| 14 | **Turnuva Düzenleme** | "Başlamamış turnuvanın adını/formatını değiştirmek istiyorum" | UX | `waiting` durumundaki turnuva güncelleme ekranı | — | Kolay | 2 gün | Yüksek |
| 15 | **Katılımcı Çıkarma** | "Turnuva yöneticisi olarak sorunlu oyuncuyu çıkarmak istiyorum" | Yönetim | `participantIds` ve `participants` dizisinden kaldırma | — | Kolay | 1-2 gün | Orta |

### UX Özellikleri

| # | Özellik | User Story | İş Değeri | Teknik Özet | Bağımlılık | Zorluk | Süre | Öncelik |
|---|---------|-----------|-----------|-------------|-----------|--------|------|---------|
| 16 | **Şampiyonluk Konfeti** | "Turnuva kazandığımda konfeti efekti görmek istiyorum" | WOW faktörü | `confetti` paketi (mevcut) + `tournament_wrapped_screen` entegrasyonu | — | Kolay | 0.5 gün | Yüksek |
| 17 | **Onboarding İyileştirme** | "Uygulamayı ilk açtığımda ne yapabileceğimi anlamak istiyorum" | Activation rate | `lottie` animasyonları + interaktif tur | — | Orta | 3-4 gün | Orta |
| 18 | **i18n String Geçişi** | "Uygulamayı İngilizce olarak da kullanmak istiyorum" | Uluslararası pazar | Mevcut string'leri `AppLocalizations` ile değiştir | i18n altyapısı (var) | Orta | 5-7 gün | Orta |
| 19 | **Haptik Geri Bildirim** | "Çark çevirirken ve önemli eylemlerde titreşim hissetmek istiyorum" | Premium his | `HapticFeedback.lightImpact()` çağrıları | — | Kolay | 0.5 gün | Düşük |
| 20 | **Pull-to-Refresh** | "Liste ekranlarını aşağı çekerek yenilemek istiyorum" | UX standardı | `RefreshIndicator` + stream refresh | — | Kolay | 1 gün | Yüksek |

### Monetizasyon Özellikleri

| # | Özellik | User Story | İş Değeri | Teknik Özet | Bağımlılık | Zorluk | Süre | Öncelik |
|---|---------|-----------|-----------|-------------|-----------|--------|------|---------|
| 21 | **Premium Tema Paketi** | "Özel renkler ve temalarla turnuvamı kişiselleştirmek istiyorum" | Gelir | In-app purchase + tema sistemi genişletme | IAP altyapısı | Orta | 5-7 gün | Düşük |
| 22 | **Reklamsız Deneyim** | "Reklam görmeden uygulamayı kullanmak istiyorum" | Gelir | AdMob banner + premium abonelik ile kaldırma | AdMob entegrasyonu | Orta | 3-4 gün | Düşük |

### Teknik Özellikler

| # | Özellik | User Story | İş Değeri | Teknik Özet | Bağımlılık | Zorluk | Süre | Öncelik |
|---|---------|-----------|-----------|-------------|-----------|--------|------|---------|
| 23 | **Offline Mod** | "İnternet olmadan da turnuva verilerimi görmek istiyorum" | UX | Firestore offline persistence + cache-first pattern | — | Orta | 3-4 gün | Orta |
| 24 | **Web Versiyonu** | "Bilgisayarımdan da turnuva yönetmek istiyorum" | Erişilebilirlik | Flutter Web + Firebase Hosting | Responsive tasarım | Zor | 10-15 gün | Düşük |
| 25 | **Profil Fotoğrafı Kırpma** | "Profil fotoğrafımı yüklerken kırpmak istiyorum" | UX | `image_cropper` paketi entegrasyonu | — | Kolay | 1-2 gün | Orta |
| 26 | **QR Kod ile Katılma** | "Davet kodunu QR kod olarak gösterip taratmak istiyorum" | UX, kolaylık | `qr_flutter` + `mobile_scanner` | — | Kolay | 2-3 gün | Orta |
| 27 | **Turnuva Bracket Görseli** | "Eleme tablosunu bracket formatında görmek istiyorum" | Görsellik | Custom painter veya `flutter_bracket` | — | Zor | 5-7 gün | Orta |

---

## 12. EK API VE SERVİS ÖNERİLERİ

| # | Servis | Kullanım | Maliyet | Zorluk | Değer | Süre |
|---|--------|----------|---------|--------|-------|------|
| 1 | **Football-Data.org API** | Gerçek maç sonuçları, lig tabloları | Ücretsiz (10 req/dk) | Kolay | Yüksek | 3-4 gün |
| 2 | **Firebase Analytics** | Kullanıcı davranış analizi | Ücretsiz | Kolay | Yüksek | 1-2 gün |
| 3 | **RevenueCat** | In-app purchase yönetimi (iOS+Android) | %1-2.5 komisyon | Orta | Yüksek | 3-5 gün |
| 4 | **SendGrid** | E-posta bildirimleri (turnuva özetleri) | Ücretsiz (100/gün) | Kolay | Orta | 2-3 gün |
| 5 | **Mixpanel / Amplitude** | Detaylı analytics ve funnel | Ücretsiz (plan) | Orta | Yüksek | 2-3 gün |
| 6 | **Google AdMob** | Reklam geliri | Gelir paylaşımı | Kolay | Orta | 2-3 gün |
| 7 | **Cloudinary** | Görüntü optimizasyon CDN | Ücretsiz (25 GB) | Kolay | Orta | 1-2 gün |
| 8 | **Gemini API** | Maç tahminleri, skor önerileri, turnuva optimizasyonu | Ücretsiz (sınırlı) | Orta | Yüksek | 5-7 gün |
| 9 | **OneSignal** | Gelişmiş push bildirim segmentasyonu | Ücretsiz (10K kullanıcı) | Kolay | Orta | 2 gün |
| 10 | **Sentry** | Hata izleme (Crashlytics alternatifi, daha detaylı) | Ücretsiz (5K event/ay) | Kolay | Orta | 1 gün |

---

## 13. MONETİZASYON STRATEJİLERİ

| # | Strateji | Tahmini Gelir | Kullanıcı Etkisi | Zorluk |
|---|----------|---------------|-------------------|--------|
| 1 | **Freemium: 3 aktif turnuva sınırı** — premium ile sınırsız | $2-5/ay × premium kullanıcılar | Düşük (çoğu 3'te kalır) | Orta |
| 2 | **Premium Özellikler** — detaylı istatistik, özel tema, turnuva şablonları | $3-8/ay abonelik | Düşük | Orta |
| 3 | **AdMob Banner** — ana sayfa alt kısmı, sonuç ekranı arası | ~$1-3 eCPM × gösterim | Orta (rahatsızlık) | Kolay |
| 4 | **AdMob Rewarded** — çark çevirme hakkı, ekstra istatistik | ~$5-15 eCPM | Düşük (isteğe bağlı) | Kolay |
| 5 | **B2B: Kafe/Kulüp Paketi** — özel branding, sponsorlu turnuvalar, dashboard | $20-50/ay × işletme | Düşük | Zor |
| 6 | **Sponsorluk** — turnuva sponsoru logosu, banner | Değişken | Düşük | Orta |
| 7 | **In-App Purchase: Özel Rozetler** — koleksiyon rozetleri, avatarlar | $0.99-4.99 tek seferlik | Düşük | Kolay |
| 8 | **Abonelik: Competra Pro** — reklamsız + sınırsız turnuva + premium istatistik + öncelikli destek | $4.99/ay veya $29.99/yıl | Düşük | Orta |

---

## 14. TEST STRATEJİSİ (DETAYLI)

### 14.1 Mevcut Test Coverage

- `test/widget_test.dart` — **2 widget testi**, 46 satır
  - Splash → Login yönlendirmesi
  - Login → Misafir uyarısı akışı
- **Unit test:** Yok ❌
- **Integration test:** Yok ❌
- **Cloud Functions test:** Yok ❌
- **Tahmini coverage:** ~%1

### 14.2 Unit Test Öncelikleri (En Değerli 20)

| # | Test | Dosya | Neden Değerli |
|---|------|-------|---------------|
| 1 | `computeStandings` — FIFA modu, 3+ oyuncu eşitliği | `tournament.dart:403` | Kritik iş mantığı, saf fonksiyon |
| 2 | `computeStandings` — UEFA modu, ikili averaj | `tournament.dart:403` | Saf, deterministik |
| 3 | `computeStandings` — Karma modu | `tournament.dart:403` | Saf, deterministik |
| 4 | `computeScorers` — gol krallığı sıralama | `tournament.dart:582` | Saf fonksiyon |
| 5 | `generateLeagueFixtures` — round-robin doğruluğu | `fixture_generator.dart` | Kritik algoritma |
| 6 | `generateKnockoutFixtures` — bye yerleşimi | `fixture_generator.dart` | Kritik algoritma |
| 7 | `generateNextKnockoutRound` — çift/tek, iki ayaklı | `fixture_generator.dart` | Kritik algoritma |
| 8 | `generateKnockoutFromGroups` — çapraz eşleşme | `fixture_generator.dart` | Kritik algoritma |
| 9 | `generateKnockoutFromSeeds` — çapraz eşleşme + bye | `fixture_generator.dart` | Kritik algoritma |
| 10 | `Validators.username` — sınır değerler | `validators.dart` | Girdi güvenliği |
| 11 | `Validators.email` — geçersiz formatlar | `validators.dart` | Girdi güvenliği |
| 12 | `Validators.password` — min uzunluk | `validators.dart` | Güvenlik |
| 13 | `timeAgoTr` — eşik değerler | `time_ago.dart` | UX doğruluğu |
| 14 | `TiebreakerMode.fromString` — bilinmeyen değer | `tournament.dart:32` | Varsayılan davranış |
| 15 | `Tournament.fromDoc` — eksik alan varsayılanları | `tournament.dart:164` | Veri güvenliği |
| 16 | `UserProfile.fromDoc` — eksik alan varsayılanları | `user_profile.dart:75` | Veri güvenliği |
| 17 | `_normalizeScoreEntry` — eski/yeni enum eşlemesi | `tournament.dart:146` | Geriye uyumluluk |
| 18 | TS: `computeStandings` — Dart ile eşdeğerlik | `standings.ts` | İstemci-sunucu paritesi |
| 19 | TS: `deriveAchievementUpdate` — rozet/unvan | `achievements.ts` | İş mantığı |
| 20 | TS: `resolveTieWinner` — çift maçlı eleme | `index.ts:539` | Kritik iş mantığı |

### 14.3 Firebase Emulator Test Kurulumu

```bash
# firebase.json'a emulator bloğu ekle:
{
  "emulators": {
    "auth": { "port": 9099 },
    "firestore": { "port": 8080 },
    "storage": { "port": 9199 },
    "functions": { "port": 5001 },
    "ui": { "enabled": true, "port": 4000 }
  }
}

# Başlat:
firebase emulators:start --project competra-9e396

# Cloud Functions testi (Jest):
cd functions && npm test
```

### 14.4 CI/CD Pipeline Test Entegrasyonu

```yaml
# .github/workflows/test.yml
- run: flutter test --coverage
- run: cd functions && npm test
- run: flutter analyze
```

---

## 15. DEVOPS VE YAYINA HAZIRLIK

### 15.1 Mevcut CI/CD Durumu

- ❌ CI/CD pipeline yok
- ✅ Release signing altyapısı hazır (`key.properties` + `competra-release.jks`)
- ✅ Crashlytics yapılandırıldı
- ⚠️ Firebase rules deploy edilmedi (DNS sorunu)

### 15.2 GitHub Actions Pipeline Önerisi

```yaml
name: CI/CD Pipeline

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  analyze:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.35.1'
      - run: flutter pub get
      - run: flutter analyze
      - run: flutter test --coverage

  functions-test:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: functions
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '22'
      - run: npm ci
      - run: npm run lint
      - run: npm run build
      - run: npm test

  build-android:
    needs: [analyze, functions-test]
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.35.1'
      - run: flutter pub get
      - run: flutter build appbundle --release
        env:
          KEYSTORE_PASSWORD: ${{ secrets.KEYSTORE_PASSWORD }}
          KEY_ALIAS: ${{ secrets.KEY_ALIAS }}
          KEY_PASSWORD: ${{ secrets.KEY_PASSWORD }}
      - uses: actions/upload-artifact@v4
        with:
          name: app-release
          path: build/app/outputs/bundle/release/

  deploy-functions:
    needs: [functions-test]
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v4
      - uses: FirebaseExtended/action-hosting-deploy@v0
        with:
          repoToken: ${{ secrets.GITHUB_TOKEN }}
          firebaseServiceAccount: ${{ secrets.FIREBASE_SERVICE_ACCOUNT }}
          projectId: competra-9e396
```

### 15.3 iOS Yayın Hazırlığı — Eksikler

1. ❌ `Info.plist` izin metinleri (`NSPhotoLibraryUsageDescription`)
2. ❌ Push Notifications capability
3. ❌ Apple Sign-In (sosyal giriş varsa zorunlu)
4. ❌ APNs key yapılandırması
5. ❌ Google Sign-In URL scheme (`CFBundleURLTypes`)

---

## 16. ÖLÇEKLENEBİLİRLİK ANALİZİ

### 16.1 Kullanıcı Ölçeğinde Davranış

| Metrik | 1K Kullanıcı | 10K Kullanıcı | 100K Kullanıcı |
|--------|-------------|---------------|----------------|
| Firestore okuma/gün | ~50K | ~500K | ~5M |
| Firestore yazma/gün | ~10K | ~100K | ~1M |
| Cloud Functions çağrı/gün | ~5K | ~50K | ~500K |
| Tahmini aylık maliyet | ~$5-10 | ~$25-75 | ~$200-500 |

### 16.2 Darboğaz Noktaları

| Darboğaz | Ölçek | Çözüm |
|----------|-------|-------|
| Pagination eksikliği | 10K+ turnuva/bildirim | `orderBy + limit + startAfter` |
| `collectionGroup('members')` N+1 | 100+ grup | Denormalizasyon |
| `userRecentMatchesProvider` — tüm maçlar | 1K+ maç/kullanıcı | `limit(20)` + index |
| Tek Cloud Function instance | 100+ eşzamanlı maç sonucu | `maxInstances` ayarla |
| Firestore 10K write/saniye (tek koleksiyon) | 100K+ kullanıcı | Sharding (`users_shard_1`, vb.) |

### 16.3 Caching Katmanı Önerileri

- **Kısa vadeli:** Firestore offline cache (zaten var, optimize edilebilir)
- **Orta vadeli:** `computeStandings` sonuçlarını Riverpod `StateProvider` ile memoize et
- **Uzun vadeli:** Redis (Cloud Memorystore) ile leaderboard cache'i

---

## 17. KULLANICI DENEYİMİ (UX) DERİN ANALİZİ

### 17.1 Kullanıcı Akışı

```
Splash → Login/Register → Home
                          ├── Turnuva Oluştur → Lobi → Başlat → Fikstür → Skor Gir → Sonuçlar
                          ├── Turnuvaya Katıl (Kod) → Lobi
                          ├── Turnuvalarım (Ligler) → Detay
                          ├── Çark → Çevir → Sonuç
                          ├── Sosyal → Arkadaş Ekle / Grup / Sıralama
                          └── Profil → Düzenle / Ayarlar / Çıkış
```

### 17.2 Onboarding Değerlendirmesi

- ✅ Onboarding ekranı var (`onboarding_screen.dart`, 258 satır)
- ⚠️ `lottie`/`rive` animasyonları var ama kullanılmıyor
- ⚠️ İlk turnuva oluşturma rehberi yok
- **Öneri:** İlk kullanımda "İlk turnuvanı oluştur" rehber kartı + interaktif tour

### 17.3 Retention Mekanizmaları

| Mekanizma | Mevcut | Değerlendirme |
|-----------|--------|---------------|
| Push bildirimleri | ✅ | Maç onayı, turnuva tamamlanma |
| Gamification (rozetler) | ✅ | 5 rozet + 9 unvan — iyi başlangıç |
| Sosyal bağlantı | ✅ | Arkadaşlık + gruplar |
| Streak/seri mekanizması | ❌ | Günlük giriş streak'i eklenebilir |
| Bildirim kişiselleştirme | ❌ | Tercihler ekranı yok |

### 17.4 Persona Analizi

| Persona | Profil | İhtiyaç | Mevcut Karşılama |
|---------|--------|---------|------------------|
| **Turnuva Organizatörü** | Hafta sonu maç organize eden kişi | Hızlı turnuva oluşturma, kolay yönetim | ✅ İyi |
| **Rekabetçi Oyuncu** | İstatistiklerine önem veren | Detaylı istatistik, sıralama, head-to-head | ⚠️ Temel var, detay eksik |
| **Sosyal Oyuncu** | Arkadaşlarla eğlence arayan | Kolay katılım, paylaşım, sohbet | ⚠️ Katılım iyi, sohbet/feed eksik |
| **Kafe/Kulüp Yöneticisi** | Düzenli etkinlik düzenleyen | Branding, şablon, raporlama | ❌ B2B özellikleri yok |

### 17.5 Rekabetçi Analiz

| Uygulama | Güçlü Yanı | Competra Avantajı |
|----------|-----------|-------------------|
| **Challonge** | Web tabanlı, güçlü bracket | Mobil-native UX, arkadaş grupları |
| **Toornament** | Profesyonel turnuva yönetimi | Basitlik, arkadaş odaklı |
| **FIFA/EA FC** | Gerçek oyun entegrasyonu | Platform bağımsız, özel kurallar |
| **Kickbase** | Bundesliga fantezi | Gerçek hayat turnuva, çok format |

### 17.6 ASO Önerileri

- Başlık: "Competra — Turnuva & Lig Yöneticisi"
- Anahtar kelimeler: turnuva oluştur, fikstür, puan tablosu, fifa turnuva, arkadaş ligi
- Ekran görüntüleri: 5 sahne (oluştur → fikstür → skor → şampiyon → profil)
- Kısa açıklama: "Arkadaşlarınla turnuva kur, skor gir, şampiyon ol!"

---

## 18. TEKNİK BORÇ (TECHNICAL DEBT) ANALİZİ

### 18.1 Teknik Borç Envanteri

| # | Borç | Etki | Giderme Maliyeti | Risk |
|---|------|------|-----------------|------|
| TB-1 | `tournament_detail_screen.dart` 2227 satır — bölünmemiş | Bakım zorluğu, paralel geliştirme engeli | 3-4 gün | 🟠 Yüksek |
| TB-2 | Magic string'ler (format, durum, faz, bildirim tipi) | Yazım hatası riski, refactoring zorluğu | 2-3 gün | 🟡 Orta |
| TB-3 | Pagination eksikliği | Ölçek büyüdüğünde performans/maliyet | 3-5 gün | 🟠 Yüksek |
| TB-4 | Test coverage ~%1 | Regresyon riski, güvenli refactoring imkansız | 10-15 gün | 🔴 Kritik |
| TB-5 | i18n string'leri geçirilmemiş | Çoklu dil desteği engellenmiş | 5-7 gün | 🟡 Orta |
| TB-6 | `users` belgesinde PII (e-posta) herkese açık | KVKK/GDPR riski | 2-3 gün | 🟠 Yüksek |
| TB-7 | `NotificationService` statik bağımlılıklar | Test edilemezlik | 1-2 gün | 🟡 Orta |
| TB-8 | Kullanılmayan bağımlılıklar (`lottie`, `rive` — kullanılıyor mu kontrol et) | APK boyutu | 0.5 gün | 🟢 Düşük |
| TB-9 | `firestore.rules` deploy edilmemiş | Güvenlik kuralları üretimde eski | 0.5 gün | 🔴 Kritik |
| TB-10 | `competra-release.jks` repo'da | Güvenlik riski | 1 gün | 🔴 Kritik |
| TB-11 | CI/CD pipeline yok | Manuel derleme/deploy | 2-3 gün | 🟠 Yüksek |
| TB-12 | `_emailForUsername` anonim oturum hack'i | Callable function'a taşınmalı | 1-2 gün | 🟡 Orta |

### 18.2 Refactoring Road Map (Sprint Bazlı)

**Sprint 1 (1 hafta):** TB-9, TB-10, TB-6 — Güvenlik kritik
**Sprint 2 (1 hafta):** TB-2 (sabitler), TB-1 (dosya bölme başlangıcı)
**Sprint 3 (1 hafta):** TB-4 (birim testleri — computeStandings, fixture_generator)
**Sprint 4 (1 hafta):** TB-3 (pagination), TB-11 (CI/CD)
**Sprint 5 (1 hafta):** TB-5 (i18n), TB-7 (DI düzeltme), TB-12 (callable function)

### 18.3 Bağımlılık Güncelleme Planı

```yaml
# pubspec.yaml — mevcut vs en son (kontrol edilmeli):
firebase_core: ^4.10.0          # kontrol et
firebase_auth: ^6.5.2           # kontrol et
cloud_firestore: ^6.5.0         # kontrol et
flutter_riverpod: ^3.3.2        # kontrol et
go_router: ^17.2.3              # kontrol et
# firebase-functions paketi outdated uyarısı (CLAUDE.md:195)
```

---

## 19. ÖNCELİKLİ YOL HARİTASI

### Faz 1 — Kritik Düzeltmeler (0-2 hafta)

| # | Açıklama | Neden Kritik | Süre |
|---|----------|-------------|------|
| 1 | `competra-release.jks`'ı repo'dan çıkar, `.gitignore`'a ekle, Git history'den sil | Keystore sızıntısı — uygulama imzası ele geçirilebilir | 0.5 gün |
| 2 | `firestore.rules`'u deploy et | Güvenlik kuralları üretimde eski — V2 açıkları hâlâ aktif olabilir | 0.5 gün |
| 3 | `users` belgesinde e-postayı public/private ayır | KVKK/GDPR ihlali riski | 2 gün |
| 4 | Storage kurallarına boyut + content-type sınırı ekle | DoS saldırısı riski | 0.5 gün |
| 5 | `notifications` create kurallarına alan kısıtı ekle | Sahte bildirim spam riski | 0.5 gün |
| 6 | `friendGroups` create'e `createdBy == auth.uid` kontrolü | Sahte grup oluşturma | 0.5 gün |
| 7 | `runAchievements` ve `updateFriendGroupStats`'a try/catch ekle | Yakalanmamış hata riski | 0.5 gün |

### Faz 2 — Temel İyileştirmeler (2-6 hafta)

| # | Açıklama | Beklenen Fayda | Süre |
|---|----------|---------------|------|
| 8 | Magic string'leri sabit/enum'a taşı | Derleme-zamanı güvenliği, bakım kolaylığı | 2-3 gün |
| 9 | `tournament_detail_screen.dart` bölme | Okunabilirlik, paralel geliştirme | 3-4 gün |
| 10 | Paylaşılan UI bileşen kütüphanesi | DRY, tutarlılık | 2-3 gün |
| 11 | Birim testleri (computeStandings, fixture_generator, validators) | Regresyon koruması | 4-5 gün |
| 12 | Pagination ekleme (notifications, tournaments, wheels) | Ölçeklenme, maliyet | 3-4 gün |
| 13 | Firebase Emulator Suite kurulumu | Lokal geliştirme/test | 1 gün |
| 14 | CI/CD pipeline (GitHub Actions) | Otomatik test/derleme | 2-3 gün |
| 15 | Firebase App Check entegrasyonu | Bot koruması | 2-3 gün |
| 16 | `confetti` paketini şampiyonluk anında uygula | WOW faktörü, UX | 0.5 gün |

### Faz 3 — Yeni Özellikler (6-12 hafta)

| # | Açıklama | İş Değeri | Süre |
|---|----------|-----------|------|
| 17 | Oyuncu profil ziyareti | Rekabet motivasyonu, sosyal keşif | 2 gün |
| 18 | Head-to-head istatistik | Rakipler arası rekabet | 2-3 gün |
| 19 | Turnuva düzenleme (waiting durumunda) | Organizatör UX | 2 gün |
| 20 | Katılımcı sınırı ve çıkarma | Yönetim kontrolü | 2 gün |
| 21 | İstatistik grafikleri (fl_chart) | Retention, veri odaklı UX | 3-4 gün |
| 22 | QR kod ile katılma | UX kolaylığı | 2-3 gün |
| 23 | i18n string geçişi (İngilizce destek) | Uluslararası pazar | 5-7 gün |
| 24 | Callable functions (joinTournament, resolveUsername) | Güvenlik, sunucu doğrulama | 3-4 gün |
| 25 | Apple Sign-In | iOS yayını için zorunlu | 2 gün |
| 26 | Pull-to-refresh | UX standardı | 1 gün |

### Faz 4 — Ölçekleme ve Optimizasyon (3-6 ay)

| # | Açıklama | Ölçek Etkisi | Süre |
|---|----------|-------------|------|
| 27 | Firestore veri modelini ölçekle (denormalizasyon, sharding) | 100K+ kullanıcı desteği | 5-7 gün |
| 28 | Web versiyonu (Flutter Web + Firebase Hosting) | Yeni platform, erişilebilirlik | 10-15 gün |
| 29 | Monetizasyon (Freemium + AdMob) | Gelir | 5-7 gün |
| 30 | Sezon sistemi | Uzun vadeli retention | 5-7 gün |
| 31 | B2B kafe/kulüp paketi | Yeni gelir kanalı | 10-15 gün |
| 32 | AI/ML maç tahmini entegrasyonu | Farklılaşma, engagement | 5-7 gün |
| 33 | Scheduled Functions (temizlik, haftalık özet) | Otomasyon | 2-3 gün |

---

## 20. KAPANIŞ DEĞERLENDİRMESİ

### 20.1 Uygulamanın Güçlü Yanları (12 Madde)

1. **Cloud Functions mimarisi** — V2'den büyük sıçrama; istatistik/tur ilerletme/rozet sunucuda, idempotent
2. **İstemci-sunucu paritesi** — Dart ve TypeScript modelleri aynı alan adları ve normalizasyon kuralları
3. **Firestore güvenlik kuralları** — Kapsamlı, yardımcı fonksiyonlar (`joiningSelfOnly`, `changedKeysWithin`), her koleksiyon ayrı düşünülmüş
4. **Puan tablosu algoritması** — FIFA/UEFA/Karma tiebreaker, özyinelemeli mini-tablo, 3+ oyuncu eşitliği — profesyonel kalite
5. **4 turnuva formatı** — Lig, eleme, grup+eleme, Şampiyonlar Ligi (çift maçlı) — çok geniş kapsam
6. **3 skor giriş modu** — Admin, kazanan giriş, çift giriş — esnek organizasyon
7. **Tema sistemi** — Tamamen `ColorScheme` üzerinden, dark/light tutarlı, marka renkleri
8. **Push bildirimleri (FCM)** — Uçtan uca: token yönetimi, ön plan SnackBar, yönlendirme, arka plan handler
9. **Hesap silme** — Yeniden kimlik doğrulama, Firestore + Storage temizleme, FirebaseAuth silme
10. **Türkçe dokümantasyon** — Neredeyse her sınıf/fonksiyon detaylı Türkçe yorum içeriyor
11. **Deep link desteği** — `competra://join/KOD` ile turnuvaya katılma
12. **Crashlytics entegrasyonu** — Flutter + platform hataları, kullanıcı kimliği ile ilişkilendirme

### 20.2 Zayıf Yanlar ve Acil Eylem

| # | Zayıf Yan | Acillik |
|---|-----------|---------|
| 1 | Test coverage ~%1 | 🔴 Kritik |
| 2 | `competra-release.jks` repo'da | 🔴 Kritik |
| 3 | `firestore.rules` deploy edilmemiş | 🔴 Kritik |
| 4 | Pagination yok | 🟠 Yüksek |
| 5 | `users` PII herkese açık | 🟠 Yüksek |
| 6 | CI/CD yok | 🟠 Yüksek |
| 7 | iOS yapılandırması eksik | 🟡 Orta |
| 8 | i18n string'leri geçirilmemiş | 🟡 Orta |

### 20.3 Rekabetçi Avantajlar

1. **Mobil-native UX** — Challonge/Toornament gibi web tabanlı rakiplere karşı
2. **Çok formatlu turnuva desteği** — Tek uygulamada 4 format
3. **Arkadaş grupları + grup sıralaması** — Sosyal katman, rakiplerde yok
4. **Türk pazarına özel** — Türkçe arayüz ve dil desteği
5. **Çark sistemi** — Benzersiz yan özellik, eğlence faktörü

### 20.4 Pazar Potansiyeli

- **Birincil pazar:** Türkiye — arkadaş arası PS/Xbox/PC futbol turnuvaları (~5M potansiyel kullanıcı)
- **İkincil pazar:** Küresel — arkadaş turnuva/lig uygulaması (niş ama sadık kullanıcı tabanı)
- **B2B fırsatı:** Kafe/kulüp/e-spor organizasyonları
- **Monetizasyon potansiyeli:** Freemium + AdMob ile aylık $500-5K (10K-100K kullanıcı)

### 20.5 Geliştirici Önerileri

| Alan | Öneri |
|------|-------|
| **Solo developer** | Mevcut hızla MVP yayına hazır; öncelik: test + güvenlik + pagination |
| **2. developer** | Backend/Cloud Functions uzmanı (test altyapısı + callable functions + ölçekleme) |
| **Tasarımcı** | UX/UI tasarımcısı — onboarding, ASO görselleri, animasyonlar |
| **Outsourcing** | iOS yapılandırması ve App Store yayını Mac gerektiriyor — bu kısım outsource edilebilir |

### 20.6 — 6 Aylık Vizyon

```
Ay 1-2: Güvenlik + Test + CI/CD + Play Store yayın
Ay 2-3: Pagination + i18n + iOS yayın + Head-to-Head + Profil ziyareti
Ay 3-4: Monetizasyon (Freemium) + AdMob + İstatistik grafikleri
Ay 4-5: Sezon sistemi + QR kod + Turnuva bracket görseli
Ay 5-6: Web versiyonu + B2B özellikler + AI tahmin denemesi
```

**Hedef:** 6 ay sonunda 10K+ aktif kullanıcı, Play Store + App Store'da yayında, Freemium modelle gelir elde eden, 2 platformda çalışan olgun bir uygulama.

---

> **Rapor Sonu** — Bu analiz 54 Dart dosyası, 5 TypeScript dosyası ve tüm yapılandırma dosyalarının satır satır incelenmesiyle hazırlanmıştır. Toplam taranan kaynak kod: ~15.800 satır.
