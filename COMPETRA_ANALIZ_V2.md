# COMPETRA — Kapsamlı Kod Analiz Raporu (V2)

> Tarih: 2026-06-16
> Kapsam: `lib/` altındaki tüm Dart dosyaları (43 dosya), `pubspec.yaml`, `firestore.rules`, `storage.rules`, `firestore.indexes.json`, `firebase.json`, `android/app/build.gradle.kts`, `AndroidManifest.xml`.
> Yöntem: Yalnızca mevcut kaynak kod incelendi (PDF/doküman hariç).

---

## 0. YÖNETİCİ ÖZETİ (TL;DR)

Competra; Flutter + Riverpod + Firebase (Auth/Firestore/Storage) üzerine kurulu, görsel olarak olgun, mimari olarak tutarlı bir turnuva/lig uygulamasıdır. UI kalitesi yüksek, kod iyi yorumlanmış (Türkçe), repository + provider deseni tutarlı uygulanmış.

**ANCAK** yayına engel teşkil eden **bir kritik mimari sorun** var:

> 🔴 **İstatistik yazımı güvenlik kurallarıyla çelişiyor.** Maç tamamlama (`updateMatchScore`) ve turnuva sonlandırma (`_finalizeTournament`) işlemleri, **her iki oyuncunun** `users/{uid}` belgesine ve `participants` alt koleksiyonuna yazıyor; fakat `firestore.rules` yalnızca kişinin **kendi** belgesine yazmasına izin veriyor (`allow write: if request.auth.uid == uid`). Sonuç: skor girişi/onayı yapan kullanıcı, rakibin belgesine yazamadığı için **tüm batch reddedilir** ve işlem başarısız olur. Bu, **tüm skor giriş modlarını ve turnuva sonlandırmayı fiilen bozar** (yalnızca tek kişilik/yapay senaryolarda çalışır).

Bu sorunun kökü, **sunucu tarafı mantığın (Cloud Functions) hiç olmaması** ve güvenlik açısından hassas tüm toplama işlemlerinin istemcide yapılmasıdır. Bu hem işlevsel (yukarıdaki blok) hem güvenlik (kullanıcı kendi istatistiğini istediği gibi şişirebilir) açısından temel bir tasarım eksiğidir.

İkincil kritik bulgular: `usernames` koleksiyonunun **herkese açık okunabilir** olması ve e-posta sızdırması (KVKK), `notifications` create kuralının aşırı serbest olması (spam/spoofing), splash ekranının oturum durumunu yok sayması.

### Modül Puanları (1-10)

| Modül | Puan | Gerekçe |
|---|---|---|
| **UI** | 8/10 | Tutarlı tema, animasyonlar, çoğu yerde boş/yükleme durumu. Erişilebilirlik ve bazı tekrar sorunları var. |
| **Backend (veri katmanı)** | 4/10 | Temiz repository'ler; ancak kural/işlem (transaction) çelişkileri, Cloud Functions yokluğu, istemci-güvenli toplama. |
| **Güvenlik** | 3/10 | Herkese açık e-posta okuma, serbest notification yazımı, istemci-güvenli istatistik, B/C modu kural ihlali. |
| **Performans** | 6/10 | Küçük ölçekte sorunsuz; N+1 grup okuması, tüm koleksiyon çekme, her rebuild'de yeniden hesaplama. |
| **Kod Kalitesi** | 7/10 | İyi yorumlanmış, tutarlı; DRY ihlalleri, çok uzun dosyalar/fonksiyonlar, magic string'ler. |
| **Test Coverage** | 1/10 | Hiç test yok (`test/` boş). |

---

## 1. MEVCUT DURUM DEĞERLENDİRMESİ

### 1.1 Tamamlanan özellikler ve kaliteleri

| Özellik | Durum | Kalite Notu |
|---|---|---|
| Kimlik doğrulama (kullanıcı adı+e-posta, Google, misafir) | ✅ | İyi. Türkçe hata eşleme (`auth_service.dart:191`). |
| Turnuva oluşturma (3 adımlı sihirbaz) | ✅ | Çok iyi UI (`create_tournament_screen.dart`). |
| 4 format (lig, eleme, grup+eleme, ŞL) fikstür üretimi | ✅ | Algoritmalar sağlam (`fixture_generator.dart`). |
| Tur ilerletme (eleme/grup/ŞL) | ⚠️ | Mantık var ama **transaction yok** (bkz. §2). |
| Skor giriş modları (admin/kazanan/çift) | 🔴 | Kod akışı doğru, **kurallar bozuyor** (bkz. §2.1). |
| Puan tablosu + tiebreaker (FIFA/UEFA/Karma) | ✅ | Etkileyici, özyinelemeli mini-tablo (`tournament.dart:333`). |
| Gol krallığı | ✅ | İstemci tarafı hesaplama. |
| Arkadaşlık sistemi | ✅ | İstek/kabul/red akışı tam. |
| Arkadaş grupları + sıralama | ✅ | Yeni eklendi, sağlam (`friend_group_screen.dart`). |
| Bildirimler | ⚠️ | Üretim var; ekrandaki onay/itiraz butonları **sahte** (`notifications_screen.dart:205` "Şimdilik..."). |
| Çark (takım seçici) | ✅ | CustomPainter ile güzel; lig ön ayarları. |
| Profil + rozet/unvan | ✅ | Otomatik türetme (`achievement_service.dart`). |
| Profil fotoğrafı (Storage) | ✅ | image_picker + Storage. |
| Tema (açık/koyu) | ✅ | Tamamen `ColorScheme` üzerinden. |
| Deep link (davet) | ✅ | `competra://join/KOD` (Android). |

### 1.2 Kod tabanının genel sağlığı

- **Olumlu:** `flutter analyze` temiz; tutarlı dosya organizasyonu (`models/`, `services/`, `screens/`, `core/`, `components/`, `router/`); yoğun ve açıklayıcı Türkçe doküman yorumları; renkler %100 tema üzerinden (hard-code renk yok denecek kadar az).
- **Olumsuz:** Test yok; Cloud Functions yok; bazı dosyalar aşırı uzun (`tournament_detail_screen.dart` **1994 satır**, `create_tournament_screen.dart` 1040 satır); `_formatLabel` 3 ayrı dosyada kopyalanmış; durum/format string'leri sabit (enum/const) değil ham string.

### 1.3 Mimari tutarlılık

- **State management:** Riverpod tutarlı. `StreamProvider` ile canlı Firestore dinleme; `Provider` ile servis enjeksiyonu (`firebase_providers.dart`). `family` provider'lar doğru kullanılmış.
- **Repository pattern:** `AuthService`, `UserRepository`, `TournamentRepository`, `SocialRepository`, `WheelRepository`, `NotificationRepository`, `AchievementService` — net sorumluluk ayrımı. UI doğrudan Firestore'a değil, repository'lere erişiyor (iyi).
- **Tutarsızlık:** İş mantığının bir kısmı (skor karşılaştırma, anlaşmazlık mesajı üretimi) UI içinde (`_ScoreEntryDialog._submit`, `tournament_detail_screen.dart:1181`). Bu, repository'ye taşınmalı (bkz. §7).

---

## 2. KRİTİK HATALAR VE RİSKLER

### 🔴 2.1 [KRİTİK] İstatistik yazımı güvenlik kurallarını ihlal ediyor — skor girişi/sonlandırma bozuk

**Konum:** `tournament_repository.dart:289` (`_applyMatchStats`), `:430+` (`_finalizeTournament`), `:162` (`updateMatchScore`); `firestore.rules:60-63` (users), `:107-113` (participants).

**Açıklama:** `_applyMatchStats` her maçta **iki** oyuncunun belgesine yazar:
```dart
final users = _firestore.collection('users');
batch.set(users.doc(homeUid), _userStatsDelta(...), SetOptions(merge: true));
batch.set(users.doc(awayUid), _userStatsDelta(...), SetOptions(merge: true)); // ← rakip
// + participants.doc(homeUid) / participants.doc(awayUid)
```
Ancak kurallar:
```
match /users/{uid} { allow write: if isSignedIn() && request.auth.uid == uid; }
match /participants/{participantUid} {
  allow create: if isSignedIn() && request.auth.uid == participantUid;
  allow update: if isTournamentAdmin(tournamentId);
}
```
Skoru giren/onaylayan kullanıcı **rakibin** `users/{uid}` belgesine yazamaz → **tüm batch reddedilir** → `updateMatchScore` exception fırlatır → kullanıcı "Skor kaydedilemedi" görür.

- **Mod A (adminOnly):** Admin, iki oyuncunun da belgesine yazar; admin genelde oyunculardan biri değilse **ikisi de** reddedilir.
- **Mod B (winnerEntry) / Mod C (doubleEntry):** Onaylayan oyuncu (admin değil) rakibin belgesine yazamaz → reddedilir.
- **Turnuva sonlandırma:** `_finalizeTournament` tüm katılımcıların `users/{uid}` belgesine `tournamentsPlayed` yazar; admin bile başkalarının belgesine yazamaz → sonlandırma batch'i reddedilir → turnuva asla `completed` olmaz.

**Etki:** Uygulamanın çekirdek döngüsü (skor gir → istatistik → şampiyon) gerçek çok-oyunculu kullanımda çalışmaz.

**Çözüm (önerilen sıra):**
1. **Cloud Functions** ekleyin: `onMatchWrite` tetikleyicisi ile istatistik toplama, tur ilerletme ve sonlandırmayı **sunucuda** (admin SDK ile) yapın. İstemci yalnızca maç skorunu yazar; kurallar yalnızca maç güncellemesine izin verir. Bu, hem bu hatayı hem de §3'teki istatistik sahteciliğini çözer.
2. (Geçici) İstatistik toplamayı tamamen kaldırıp, profil/puan tablosunu **maçlardan türetilmiş** (zaten `computeStandings`/`computeScorers` var) okuyun; `users` belgesindeki kümülatif alanları bir Function ile besleyin.

---

### 🔴 2.2 [KRİTİK] Tur ilerletme/sonlandırmada transaction yok → yarış durumu (duplicate tur / çift sayım)

**Konum:** `tournament_repository.dart:162` (`updateMatchScore`), `:441` (`checkTournamentCompletion`), `:476` (`_advanceKnockout`), `_advanceGroupKnockout`, `_advanceChampionsLeague`.

**Açıklama:** Akış "oku → karar ver → batch yaz" şeklinde, transaction içinde değil. İki oyuncu aynı turun son iki maçını **eşzamanlı** kaydederse:
- İkisi de "mevcut turun tüm maçları bitti" sonucuna varır → **iki kez** sonraki tur üretilir (duplicate maçlar) veya iki kez `_finalizeTournament` çağrılır.
- `updateMatchScore`'daki `alreadyCompleted` kontrolü (`:177`) transaction dışı okuduğundan, aynı maçın eşzamanlı iki güncellemesi istatistikleri **çift sayabilir**.

**Çözüm:** Kritik geçişleri `FirebaseFirestore.runTransaction` içine alın veya (tercihen) Cloud Function ile tek noktadan, idempotent şekilde yapın. Üretilen tur belgelerine deterministik ID (`round_{n}_match_{i}`) vererek `create` çakışmasını engelleyin.

---

### 🟠 2.3 [YÜKSEK] Splash oturum durumunu yok sayıyor

**Konum:** `splash_screen.dart:30-37`.
```dart
// TODO: Firebase Auth bağlandığında oturum durumuna göre yönlendir
_timer = Timer(_holdDuration, _goNext); // her zaman /login'e
```
**Açıklama:** Oturum açmış kullanıcı her açılışta `/login`'e atılıyor. `authStateProvider` mevcut ama kullanılmıyor.
**Çözüm:** `_goNext`'te `ref.read(authStateProvider)` / `currentUserProvider` değerine göre `home` ya da `login`'e yönlendir. (Splash `ConsumerStatefulWidget` olmalı.)

---

### 🟠 2.4 [YÜKSEK] `matches` güncelleme kuralı oyuncunun her alanı yazmasına izin veriyor (hile)

**Konum:** `firestore.rules:116-125`.
```
allow update: if isTournamentAdmin(...) || request.auth.uid == resource.data.homeUid || ...awayUid...
```
**Açıklama:** Kural yalnızca **kimliği** doğruluyor, **hangi alanların** değiştiğini değil. Bir oyuncu doğrudan `status: 'completed'`, istediği `homeScore/awayScore` yazıp onay/çift-giriş akışını **atlayabilir**. (İstemci akışı buna izin vermese de kötü niyetli istemci yazabilir.)
**Çözüm:** Modlara göre `request.resource.data` alan kısıtlaması ekleyin (ör. winnerEntry'de yalnızca `enteredBy/enteredHomeScore/enteredAwayScore/status:'awaitingConfirmation'` yazılabilsin) veya skor kesinleştirmeyi Cloud Function'a alın.

---

### 🟠 2.5 [YÜKSEK] Misafir (anonim) kullanıcı profil/grup özelliklerine erişiyor ama `users` belgesi yok

**Konum:** `user_repository.dart:62` (`UserProfile.guest`), `auth_service.dart:159` (`signInAsGuest`).
**Açıklama:** Misafir oturumda `users/{uid}` belgesi oluşturulmuyor (`register`/`_ensureUserDocument` çağrılmıyor). Misafir; arkadaş ekleme, grup oluşturma gibi `username`/profil gerektiren akışlara `'Oyuncu'`/`'Misafir'` varsayılanıyla girip tutarsız/yetim veriler üretebilir. Turnuvaya katılınca `participants`'a `'Misafir'` adıyla eklenir, `usernameLower` araması onları bulamaz.
**Çözüm:** Misafir için `users` belgesi oluşturun ya da misafiri sosyal/grup özelliklerinden net biçimde kısıtlayın (UI + kurallar).

### 🟡 2.6 [ORTA] `markDisputed` bildirim tipi tutarsız: `'match_confirm'`

**Konum:** `tournament_repository.dart:277` → `'type': 'match_confirm'`. Diğer yeni bildirimler camelCase (`matchConfirm`). Model her ikisini de tanıyor (`app_notification.dart:10`) ama tutarsızlık ileride karışıklık yaratır.
**Çözüm:** Tek bir kanona (`matchConfirm`) sabitleyin; tip string'lerini `const`/enum'a taşıyın.

### 🟡 2.7 [ORTA] `startTournament` 500 işlemlik batch sınırı

**Konum:** `tournament_repository.dart:127`. Çok katılımcılı lig/ŞL'de üretilen maç sayısı 500'ü aşarsa batch başarısız (kod yorumu da belirtiyor). Arkadaş ölçeğinde düşük risk.
**Çözüm:** Maç sayısını parçalı batch'lere bölün veya üst sınır uygulayın.

### 🟡 2.8 [ORTA] Bildirime dokununca turnuvaya gidemiyor (model alan eksiği)

**Konum:** `app_notification.dart:25` — model `tournamentId`/`matchId`/`senderId` alanlarını **parse etmiyor**; `notifications_screen.dart:165` matchConfirm/tournamentComplete dokunuşu bağlama (turnuva) gidemiyor; `_MatchConfirmActions` (satır 205) yalnızca `markRead` yapıyor (gerçek onay/itiraz yok).
**Çözüm:** Modele alanları ekleyip dokununca ilgili turnuvaya yönlendirin; onay/itiraz butonlarını gerçek akışa bağlayın.

### Null-safety / hata yönetimi notları
- **Null-safety:** Genel olarak iyi; `fromDoc`'lar `?? varsayılan` ile güvenli. `int.tryParse` ile skor girişi korunmuş (`tournament_detail_screen.dart:1162`).
- **Eksik hata yönetimi:** `notification_repository.markRead` (`:16`) ve `wheel_repository.deleteWheel` (`:31`) try/catch'siz; çağıran taraf bazen yutuyor. `userProfileProvider`/stream'lerde `.error` durumları ekranlarda genelde ele alınmış (iyi).

---

## 3. GÜVENLİK ANALİZİ

### 🔴 Y-1 [YÜKSEK] `usernames` herkese açık okunabilir → e-posta sızıntısı / enumerasyon (KVKK)

**Konum:** `firestore.rules:68-69` → `allow read: if true;`. Belge `{uid, username, email}` içeriyor (`auth_service.dart:79`).
**Risk:** **Kimlik doğrulaması olmayan** herkes tüm kullanıcı adlarını ve **e-postalarını** okuyabilir. KVKK/GDPR ihlali + hesap enumerasyonu.
**Çözüm:** `email`'i `usernames` belgesinden çıkarın; kullanıcı adı→e-posta çözümünü Cloud Function (callable) ile yapın. En azından `read`'i `isSignedIn()` ile sınırlayın ve e-postayı ayrı, okunamaz alana taşıyın.

### 🟠 Y-2 [YÜKSEK] `users` her oturumlu kullanıcı tarafından okunabilir → e-posta/PII sızıntısı

**Konum:** `firestore.rules:60-61` → `allow read: if isSignedIn();`. `users` belgesi `email` içeriyor.
**Risk:** Herhangi bir kullanıcı, başka kullanıcının e-postasını/PII'sini okuyabilir. `searchUsers` (`social_repository.dart:28`) yalnızca username/uid kullansa da kural tüm alanları açıyor.
**Çözüm:** Hassas alanları (`email`) ayrı bir özel alt-belgeye taşıyın veya istemcinin yalnızca herkese açık alanları (`username`, `photoUrl`, `activeTitle`) okuyabileceği bir "public profile" modeli kurun.

### 🟠 Y-3 [YÜKSEK] İstatistik/rozet istemci-güvenli → kolay hile

**Konum:** `firestore.rules:60-63` + `users` belgesine istemci yazımı.
**Risk:** Kullanıcı kendi `users/{uid}` belgesine `allow write: if request.auth.uid == uid` sayesinde **istediği** `totalWins`, `tournamentsWon`, `badges` değerlerini yazabilir. Liderlik/rozet sistemi güvenilmez.
**Çözüm:** İstatistik/rozet yazımını Cloud Functions'a alın; istemci yazımını kapatın (§2.1 ile aynı çözüm).

### 🟡 Y-4 [ORTA] `notifications` create aşırı serbest → spam/spoofing

**Konum:** `firestore.rules:206-209` → `allow create: if isSignedIn();`.
**Risk:** Herhangi bir kullanıcı, herhangi bir `userId`'ye, **rastgele** `title/message/type/senderId` ile bildirim yazabilir (spam, kimlik taklidi). `senderId` doğrulanmıyor.
**Çözüm:** Bildirim üretimini Function'a alın; ya da en azından `request.resource.data.senderId == request.auth.uid` ve tip/alan kısıtı zorunlu kılın.

### 🟡 Y-5 [ORTA] `friendGroups` create `createdBy`'ı doğrulamıyor

**Konum:** `firestore.rules:155` → `allow create: if isSignedIn();`.
**Risk:** Kullanıcı `createdBy`'ı başkası olarak ayarlayıp sahte grup oluşturabilir; `memberCount` keyfi olabilir.
**Çözüm:** `allow create: if isSignedIn() && request.resource.data.createdBy == request.auth.uid && request.resource.data.memberCount == 1;`

### 🟡 Y-6 [ORTA] `tournaments` davet-kodu enumerasyonu

**Konum:** `firestore.rules:89-92` → `request.query.limit <= 1` ile herhangi bir turnuva tekil sorgulanabilir. 6 karakterlik kod (alfabe 31) ~887M kombinasyon; brute-force teorik olarak mümkün ama maliyetli.
**Çözüm:** Kodu uzatın (8+) veya katılımı bir Function (callable) arkasına alın; oran sınırı uygulayın.

### Authentication akışı
- **Olumlu:** Hata kodları kullanıcı dostu Türkçeye çevrilmiş (`auth_service.dart:191`). Google iptali sessiz (`signInWithGoogle` → `false`).
- **İzlenecek:** Sentetik e-posta (`<ad>@competra.internal`) eski hesaplar için; bu hesaplar parola sıfırlayamaz (kod bunu zaten engelliyor, `:121`). Hesap silme akışı **yok** (mağaza zorunluluğu, bkz. §11).

### Input validasyonu
- `Validators` (username/email/password/confirm) sağlam. Turnuva adı min 3 (`create_tournament_screen.dart:99`).
- Skor girişi `digitsOnly` + `tryParse` + negatif kontrol (`tournament_detail_screen.dart:1164`). İyi.
- **Eksik:** Grup adı / çark adı uzunluk üst sınırı yok; biyografi 150 ile sınırlı (iyi). Takım adı tekrarı engelli (`wheel_screen.dart:652`).

### Storage kuralları
- `storage.rules` iyi: profil fotoğrafı yalnızca `{uid}.jpg` ve sahibi yazabilir; diğer her şey kapalı. **Boyut/içerik tipi sınırı yok** → kötü niyetli kullanıcı büyük dosya yükleyebilir.
- **Çözüm:** `allow write: if ... && request.resource.size < 5 * 1024 * 1024 && request.resource.contentType.matches('image/.*');`

---

## 4. PERFORMANS ANALİZİ

### 🟡 P-1 [ORTA] `myFriendGroupsProvider` N+1 okuma

**Konum:** `social_repository.dart` (`myFriendGroupsProvider`). `collectionGroup('members')` snapshot'ı → her üyelik için **ayrı** `groupRef.get()`. Üye olunan grup sayısı kadar ek okuma; her members değişiminde `asyncMap` yeniden çalışır.
**Etki:** Grup sayısı arttıkça okuma maliyeti ve gecikme.
**Çözüm:** Grubun temel bilgisini (`name`, `memberCount`) üye belgesine denormalize edin ya da grup üyeliğini kullanıcı belgesinde bir dizi olarak tutup tek sorguda çekin.

### 🟡 P-2 [ORTA] Tüm koleksiyonların istemcide çekilmesi + sıralanması (pagination yok)

**Konum:** `tournament_repository.dart:486` (myTournaments), `notification_repository.dart:25`, `social_repository.dart` (friends/requests), `wheel_repository.dart:39`. Hepsi tüm sonuçları çekip istemcide `sort` yapıyor.
**Etki:** Aktif kullanıcıda doküman sayısı büyüdükçe bant genişliği/bellek artar.
**Çözüm:** `orderBy` + `limit` + sayfalama (`startAfter`). İlgili index'ler kısmen mevcut (`firestore.indexes.json`).

### 🟡 P-3 [ORTA] Aynı koleksiyona iki ayrı listener

**Konum:** `social_repository.dart` — `incomingRequestsProvider` ve `friendsProvider` ikisi de `friendships` (arrayContains uid) dinliyor; ikisi de tüm belgeleri çekip istemcide filtreliyor. İki ayrı stream = iki okuma akışı.
**Çözüm:** Tek bir `friendships` stream'i + iki `Provider.select`/türev provider ile böl.

### 🟢 P-4 [DÜŞÜK] Her rebuild'de puan tablosu/gol krallığı yeniden hesaplanıyor

**Konum:** `tournament_detail_screen.dart:108-114` — `build` içinde `computeStandings`/`computeScorers`. Maç sayısı küçük olduğundan etki düşük; yine de `matches` değişmedikçe memoize edilebilir.

### 🟢 P-5 [DÜŞÜK] `_WheelPainter.shouldRepaint` referans karşılaştırması

**Konum:** `wheel_screen.dart:609` → `oldDelegate.teams != teams` (liste referansı). Genelde yeterli; ama her frame `AnimatedBuilder` zaten yeniden çiziyor (dönüş için gerekli).

### Bellek sızıntısı / dispose
- **İyi:** Tüm `TextEditingController`, `TabController`, `PageController`, `AnimationController`, `Timer` nesneleri `dispose`/`cancel` ediliyor (login, create_tournament, wheel, splash, edit_profile, score dialog). Riverpod stream'leri otomatik yönetiliyor.
- **Risk yok denecek kadar az** — bu konuda kod tabanı temiz.

### Liste performansı
- Yatay/dikey listelerde çoğunlukla `ListView.builder`/`ListView.separated` kullanılmış (iyi). Bazı yerlerde `ListView(children: [...])` + `for` (ör. `_FixtureTab`, `friend_group_screen`) — eleman sayısı küçükse sorun değil; çok uzun fikstürlerde `.builder`'a geçilebilir.

### Index değerlendirmesi
- `firestore.indexes.json` mevcut sorgularla uyumlu (tournaments status+createdAt, friendships users+status, wheels ownerId+createdAt, notifications userId+createdAt, members.uid collection-group). **Ancak** kodda `myTournaments` `orderBy` kullanmadığından (istemci sort) tournaments index'i atıl; `friendsProvider` status'u istemcide filtrelediğinden friendships bileşik index'i de tam kullanılmıyor. Index'ler "doğru ama kullanılmıyor".

---

## 5. KOD KALİTESİ ANALİZİ

### 5.1 Kod tekrarı (DRY ihlalleri)
- **`_formatLabel`** üç dosyada neredeyse birebir kopya: `home_screen.dart:494`, `leagues_screen.dart:418`, `tournament_detail_screen.dart:1917`. → Ortak `core/format_labels.dart` (veya `TournamentFormat` enum'una `label` getter) ile tekilleştirin.
- **`_EmptyState`/`_CenterMessage`/`_MessageCard`** benzer boş-durum widget'ları her ekranda yeniden tanımlanmış (social, leagues, wheel, friend_group, tournament_detail, profile). → Tek bir paylaşılan `EmptyState` bileşeni.
- **`_initials(...)`** mantığı en az 3 yerde (`social_screen`, `profile_screen`, `tournament_detail` ParticipantTile). → `core/string_utils.dart`.
- **`_userStatsDelta`/`_participantStatsDelta`/`_memberStatsDelta`** (`tournament_repository.dart`, `social_repository.dart`) çok benzer artış mantığı.
- **Snackbar hata gösterimi** (`_showError`) ~7 ekranda kopya. → `BuildContext` extension.
- **Sıralama (createdAt desc) bloğu** myTournaments/notifications/wheels/friendGroups'ta birebir aynı. → `core` yardımcı fonksiyon.

### 5.2 Aşırı uzun fonksiyonlar / dosyalar
- `tournament_detail_screen.dart` **1994 satır** — Fikstür/PuanTablosu/İstatistik sekmeleri, skor diyalogları, anlaşmazlık diyaloğu hepsi tek dosyada. → En az 4-5 dosyaya bölün.
- `_LobbyViewState.build` ~170 satır; `_MatchCard._buildAction` karmaşık dallanma (`:893-977`) — okunabilir ama büyük.
- `create_tournament_screen.dart` 1040 satır — adım widget'ları ayrı dosyalara çıkarılabilir.

### 5.3 Magic string / number
- Format string'leri (`'league'`, `'knockout'`, `'groupKnockout'`, `'championsLeague'`) ve durum/faz string'leri (`'completed'`, `'waiting'`, `'active'`, `'disputed'`, `'awaitingConfirmation'`, `'pending'`, `'group'`, `'knockout'`, `'league'`) tüm kod tabanına dağılmış ham string. → `enum` veya `abstract class ... { static const }` ile merkezi sabitler.
- Bildirim tipleri (`'friendRequest'`, `'matchConfirm'`, `'tournamentComplete'`, `'match_confirm'`) — hem camel hem snake; sabitlere taşıyın.
- Rozet/unvan id'leri string (`'champion'`, `'hat_trick_hero'`...) — `BadgeDefinitions` ile gevşek bağlı; bir enum ya da sabit sınıf ile bağlanabilir.
- Sihirli sayılar: `orderBase = nextRound * 1000` (`fixture_generator.dart`), `_holdDuration = 2600ms`, çark `5 tam tur` — açıklanmış ama sabit isimlendirme iyi olur.

### 5.4 Tutarsız isimlendirme
- Bildirim tipi camelCase vs snake_case (yukarıda).
- `round` (String etiket) vs `roundNumber` (int) — bilinçli ama kafa karıştırıcı; `roundLabel`/`roundNumber` daha net olurdu.
- `scoreMode` (eski) vs `scoreEntrySystem` (kanonik) — modelde normalize ediliyor ama iki alan birlikte yaşıyor.

### 5.5 Yorum
- **Genel olarak çok iyi**: neredeyse her sınıf/zor fonksiyon Türkçe doküman yorumuna sahip. Bu, kod tabanının en güçlü yanlarından biri.
- Eksik: bazı karmaşık UI dallanmaları (`_buildAction`) ve çark açı matematiği (`wheel_screen.dart:74-84`) ek satır-içi yorumdan faydalanır.

---

## 6. UI/UX ANALİZİ

- **Spacing/padding:** Çoğunlukla tutarlı (16/24 px). Ufak tutarsızlıklar: bazı kartlar 12, bazıları 16 padding; ekranlar arası bir `Spacing` sabit seti yok. → `core/spacing.dart` (xs/sm/md/lg) önerilir.
- **Loading state:** Çoğu ekranda var (`when(loading: ...)`). İyi. İyileştirme: `shimmer` paketi pubspec'te var ama **hiç kullanılmıyor** — skeleton yükleme ile algılanan hız artar.
- **Empty state:** Kapsam geniş (home, leagues, wheel, social, friend_group, profile, notifications). Çok iyi.
- **Hata mesajları:** Kullanıcı dostu ve Türkçe. Tutarlı kırmızı snackbar deseni.
- **Animasyon:** `flutter_animate` ile zarif staggered geçişler. Ancak pubspec'teki `lottie`, `rive`, `confetti` **kullanılmıyor** (şampiyonluk/kazanma anında konfeti büyük UX kazanımı olurdu — bkz. §8). Kullanılmayan ağır bağımlılıklar APK boyutunu şişirir.
- **Erişilebilirlik (a11y):** `Semantics`/`tooltip` kısmen var (IconButton tooltip'leri iyi). Eksikler: özel `CustomPaint` çark için semantik etiket yok; renk kontrastına bağlı durum göstergeleri (yalnızca renkle ayrım) renk körlüğü için ikon+metinle desteklenmeli (çoğu yerde destekli, iyi); dinamik font ölçeğine (textScaleFactor) karşı sabit yükseklikler (`SizedBox(height: 420)` `login_screen.dart:426`, `height: 168` kart) taşma riski.
- **Dark/Light uyumu:** Tema tamamen `ColorScheme` üzerinden; hard-code renk neredeyse yok. **İstisna:** `_WheelPainter` etiket rengi sabit `Colors.white` (`wheel_screen.dart:582`) ve dilim renkleri HSV — açık temada da çalışır ama tema-bağımsız; profil kapak degrade ve `Colors.black.withValues(0.45)` overlay (`edit_profile_screen.dart:183`) tema-bağımsız (kabul edilebilir).
- **Responsive:** Sabit genişlikler (`width: 240` kart, `width: 300` çark) küçük ekranlarda sıkışabilir; `LayoutBuilder`/`FractionallySizedBox` ile esnetilebilir.

---

## 7. MİMARİ İYİLEŞTİRME ÖNERİLERİ

1. **Cloud Functions katmanı (en kritik):** Skor kesinleştirme, istatistik toplama, tur ilerletme, sonlandırma, bildirim üretimi sunucuya alınmalı. Bu tek hamle §2.1, §2.2, §3-Y3, §3-Y4'ü çözer ve istemciyi inceltir.
2. **İş mantığını UI'dan ayır:** `_ScoreEntryDialog._submit` (`tournament_detail_screen.dart:1181`) içindeki mod seçimi/anlaşmazlık mesajı üretimi `TournamentRepository`'ye (veya bir `ScoreService`'e) taşınmalı (separation of concerns).
3. **Sabitler/enum merkezileştirme:** Format, durum, faz, bildirim tipi, rozet id'leri için tek kaynak. String tabanlı dallanmaları enum'a çevir.
4. **Model katmanı tamamlama:** `AppNotification`'a `tournamentId/matchId/senderId`; `FriendGroupMember`'a `joinedAt`; bir `MatchResult`/`ScoreEntry` değer nesnesi. Tüm modellere `toMap`/`copyWith` ve eşitlik (`equatable` veya `==`/`hashCode`).
5. **Repository tutarlılığı:** Tüm yazma metotları aynı hata sözleşmesini taşısın (tiplenmiş exception). `markRead`/`deleteWheel` gibi metotlara hata yolu netliği.
6. **Provider bağımlılıkları:** `TournamentRepository` 4 bağımlılık alıyor; büyüdükçe `ScoreService`, `StandingsService` gibi alt servislere bölünebilir. `riverpod_generator` ile tip güvenli provider üretimi düşünülebilir.
7. **Paylaşılan UI bileşen kütüphanesi:** `EmptyState`, `SectionTitle`, `StatChip`, `PrimaryButton`, `AppSnackbar` → `lib/components/` altında toplanmalı (şu an her ekranda private kopya).
8. **Routing:** `go_router` iyi kurulmuş; `redirect` ile auth-guard eklenip splash mantığı sadeleştirilebilir (oturum yoksa `/login`).

---

## 8. YENİ ÖZELLİK ÖNERİLERİ (15+)




---

## 9. REFACTOR ÖNERİLERİ

### Hemen (bu sprint)
1. **Cloud Functions'a geçiş (skor/istatistik/sonlandırma/bildirim).** *Neden:* §2.1/§2.2/§3 doğrudan çözülür — uygulamanın çalışması buna bağlı. *Nasıl:* `functions/` ekle, `onDocumentWritten('tournaments/{t}/matches/{m}')` ile istatistik+ilerletme; callable ile katılım/bildirim. *Fayda:* İşlevsel doğruluk + güvenlik + istemci sadeleşmesi.
2. **`_formatLabel` ve boş-durum/initials/snackbar tekilleştirme.** *Neden:* DRY, bakım. *Nasıl:* `core/` ve `components/` altında paylaşılan yardımcılar + `BuildContext` extension. *Fayda:* ~200+ satır azalır, tutarlılık.
3. **Sabit string'leri enum/const'a taşı (format, durum, faz, bildirim tipi).** *Nasıl:* `TournamentFormat`/`MatchStatus`/`TournamentPhase`/`NotificationType` enum'larını veri katmanında da kullan. *Fayda:* Derleme-zamanı güvenliği, yazım hatası riski biter.

### Orta vadeli
4. **`tournament_detail_screen.dart`'ı bölme** (fixture/standings/stats/dialog dosyaları). *Fayda:* Okunabilirlik, paralel geliştirme.
5. **İş mantığını UI'dan repository/servise taşı** (skor karşılaştırma, anlaşmazlık mesajı). *Fayda:* Test edilebilirlik (§10), SoC.
6. **Pagination + sorgu `orderBy`/`limit`.** *Fayda:* Ölçeklenme, maliyet.
7. **Modellere `==`/`hashCode`/`copyWith`** (veya `freezed`/`equatable`). *Fayda:* Riverpod `select` ile gereksiz rebuild azaltma, test kolaylığı.
8. **Kullanılmayan ağır bağımlılıkları (`lottie`, `rive`, `confetti`, `shimmer`) ya kullan ya kaldır.** *Fayda:* APK boyutu, bağımlılık hijyeni.

---

## 10. TEST STRATEJİSİ

> Şu an **hiç test yok** (`test/` boş). En yüksek değerli, en kolay başlangıç saf iş mantığıdır.

### Birim testleri (öncelikli — saf fonksiyonlar, Firebase gerektirmez)
- **`computeStandings` / tiebreaker** (`tournament.dart:333`): FIFA/UEFA/Karma senaryoları, 2/3 oyuncu eşitliği, bye dışlama, sıfır maç, negatif averaj. *En değerli ve en kolay — saf, deterministik.*
- **`computeScorers`** (gol krallığı).
- **`fixture_generator`**: `generateLeagueFixtures` (N×(N-1)/2), `generateKnockoutFixtures` (2'nin kuvveti/bye), `generateNextKnockoutRound` (çift/tek, bye), `generateKnockoutFromGroups` (2/3/4 grup desenleri — §GÖREV beklenen çıktıları), `generateKnockoutFromSeeds` (çapraz, ortadaki bye).
- **`Validators`** (username/email/password/confirm sınır değerleri).
- **`timeAgoTr`** (eşik değerler: dk/sa/gün/hafta/ay/yıl, negatif).
- **Model `fromDoc`'ları** (eksik alan → varsayılan; `phase` boşsa `stage`'e düşme; `currentPhase` türetme).

### Widget testleri
- **Boş durumlar** (turnuva yok, arkadaş yok, bildirim yok) doğru gösteriliyor mu.
- **`_ScoreEntryDialog`** geçersiz skorda hata, geçerli skorda doğru repository çağrısı (repository mock'lanır).
- **Grup sıralama tablosu** sıralama/madalya vurgusu (`friend_group_screen`).
- **Filtre çubuğu** (leagues) aktif/tamamlanan filtresi.

### Entegrasyon testleri (firebase emulator ile)
- Kayıt → giriş → turnuva oluştur → katıl → skor gir → tamamla uçtan uca akışı (kuralların geçtiğini doğrular — §2.1 düzeltmesinin regresyon testi).
- Güvenlik kuralları testi (`@firebase/rules-unit-testing`): "başka kullanıcının `users` belgesine yazılamaz", "başka `userId`'ye bildirim engeli", "usernames okuma kısıtı".

### En kolay + en değerli başlangıç
`fixture_generator` ve `computeStandings` birim testleri: saf, bağımlılıksız, kritik iş mantığı, regresyona en açık alanlar.

---

## 11. YAYINA HAZIRLIK DEĞERLENDİRMESİ

### Play Store (Android)
- 🔴 **İşlevsel blok:** §2.1 (skor/istatistik) çözülmeden yayınlanamaz.
- 🔴 **Hesap silme:** Hesap oluşturan uygulamalar için Play zorunlu — yok.
- 🔴 **Gizlilik politikası URL'i:** E-posta + foto + kullanıcı verisi topluyor; Data Safety formu + politika URL'i zorunlu — yok.
- 🟠 **Uygulama ikonu/etiket:** `android:label="competra"` (küçük harf), placeholder ikon olabilir — markalama gözden geçirilmeli.
- 🟠 **`applicationId`/`namespace = com.competra.app`:** Tamam. İmzalama `key.properties` ile şartlı (iyi); release imzası hazır değilse debug'a düşüyor (yayında gerçek keystore şart).
- 🟠 **READ_MEDIA_IMAGES:** Android 13+ için doğru; daha eski sürümlerde image_picker foto seçici davranışı doğrulanmalı.
- 🟢 INTERNET izni var.

### App Store (iOS)
- 🔴 **iOS yapılandırması eksik:** `firebase.json` iOS appId içeriyor ama `Info.plist` izin metinleri (`NSPhotoLibraryUsageDescription` — image_picker için zorunlu) ve Google Sign-In için `CFBundleURLTypes` (reversed client id) görünmüyor → çökme/ret riski.
- 🔴 Hesap silme + gizlilik politikası (Apple da zorunlu).
- 🟠 Google Sign-In iOS kurulumu (URL scheme) doğrulanmalı.

### Yasal (KVKK/GDPR)
- 🔴 Gizlilik politikası + aydınlatma metni yok.
- 🔴 §3-Y1/Y2: e-posta/PII sızıntısı kuralları düzeltilmeli.
- 🔴 Veri silme/indirme hakkı (hesap silme) yok.

### Crash reporting & analytics
- 🔴 **Yok.** `firebase_crashlytics` ve `firebase_analytics` ekli değil. Üretimde hata görünürlüğü sıfır. → Eklenmeli (Crashlytics + temel funnel analytics).

### Versiyon & release süreci
- `version: 1.0.0+1`. Release imzalama altyapısı var. CI/CD yok; otomatik build/test pipeline'ı (GitHub Actions) önerilir. ProGuard/R8 küçültme ayarları belirtilmemiş (varsayılan).

---

## 12. ÖNCELİKLİ YAPILACAKLAR LİSTESİ

### 🔴 KRİTİK (hemen — yayından önce mutlaka)
1. **İstatistik/skor/sonlandırma yazımını Cloud Functions'a taşı** (veya kuralları/akışı uyumla). §2.1. — **5-8 gün**
2. **Tur ilerletme/sonlandırmayı idempotent + transaction/Function yap.** §2.2. — **2-3 gün** (Functions ile birleşir)
3. **`usernames`/`users` e-posta sızıntısını kapat** (e-postayı ayır, okuma kısıtı). §3-Y1/Y2. — **1-2 gün**
4. **`notifications` create ve `friendGroups` create kurallarını sıkılaştır.** §3-Y4/Y5. — **0.5 gün**
5. **Splash auth-guard.** §2.3. — **0.5 gün**
6. **Hesap silme + gizlilik politikası + Crashlytics.** §11. — **3-4 gün**

### 🟡 ÖNEMLİ (1-2 hafta içinde)
7. **`matches` güncelleme kural-alan kısıtı (hile engeli).** §2.4. — **1 gün**
8. **Misafir kullanıcı tutarlılığı (users belgesi veya kısıtlama).** §2.5. — **1 gün**
9. **Bildirim onay/itiraz akışını gerçekle + model alanları + dokununca yönlendirme.** §2.8. — **1-2 gün**
10. **DRY tekilleştirme (`_formatLabel`, EmptyState, snackbar, initials) + sabit enum'lar.** §5/§9. — **2-3 gün**
11. **`tournament_detail_screen` bölme + iş mantığını servise taşıma.** §9. — **2-3 gün**
12. **Birim testleri (`fixture_generator`, `computeStandings`, `Validators`).** §10. — **2-3 gün**
13. **iOS yapılandırması (Info.plist izinleri, Google Sign-In URL scheme).** §11. — **1-2 gün**

### 🟢 İYİLEŞTİRME (uzun vadede)
14. **Pagination + sorgu optimizasyonu (orderBy/limit), N+1 grup okuması.** §4. — **2-3 gün**
15. **Push bildirim (FCM).** §8-#2. — **3-5 gün**
16. **Şampiyonluk konfeti + paylaşılabilir sonuç görseli (mevcut paketler).** §8-#1/#9. — **2-3 gün**
17. **Kullanılmayan bağımlılıkları temizle/kullan (lottie/rive/confetti/shimmer).** §6. — **0.5 gün**
18. **Çift maçlı eleme, global liderlik, head-to-head, istatistik grafikleri.** §8. — **toplam 10-15 gün**
19. **i18n, onboarding, çark haptik/ses.** §8. — **5-7 gün**
20. **CI/CD pipeline + widget/entegrasyon testleri.** §10/§11. — **3-5 gün**

---

### Kapanış Notu
Competra, **ürün-pazar uyumu denenebilecek kalitede bir önyüz** ve sağlam algoritmik çekirdeğe (fikstür, tiebreaker) sahip. En acil iş, **sunucu tarafı (Cloud Functions) eksikliğinin yarattığı işlevsel/güvenlik kırılganlığını** gidermektir; bu tek başına en yüksek getirili müdahaledir. Güvenlik kuralı düzeltmeleri ve mağaza uyum maddeleri (hesap silme, gizlilik, crash reporting) tamamlandığında uygulama yayına teknik olarak hazır hale gelir.
