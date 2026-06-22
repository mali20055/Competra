# COMPETRA — Detaylı Proje Analiz Raporu

> Hazırlanma tarihi: 14 Haziran 2026
> Kapsam: 4 doküman (Proje / Frontend / Backend / Sıralama Sistemi) + tüm `lib/` Dart kaynak kodu (~9.700 satır, 38 dosya) + `pubspec.yaml`, `firebase_options.dart`, `android/app/build.gradle.kts`, `firebase.json`, Firestore şema ve güvenlik durumu.
> Yöntem: Dokümanlarda planlanan özellikler ile kodda gerçekten uygulanmış olanlar bire bir karşılaştırılmıştır.

---

## 0. Yönetici Özeti (TL;DR)

Competra, **görsel ve mimari iskeleti çok iyi kurulmuş**, ancak **iş mantığının (backend davranışının) büyük kısmı henüz uygulanmamış** bir Flutter projesidir. UI katmanı profesyonele yakın: tutarlı tema, animasyonlar, boş/yükleme/hata durumları çoğu ekranda mevcut. Buna karşılık:

- **Firestore güvenlik kuralları HİÇ yok** (dosya da yok, `firebase.json`'da da yok) → veritabanı tamamen açık/savunmasız. **En kritik sorun budur.**
- **İstatistikler hiçbir zaman kaydedilmiyor** → profil, gol krallığı global istatistikleri, rozetler, unvanlar hep boş/sıfır kalıyor.
- **Skor giriş sistemi (3 mod) hiç uygulanmamış** → herkes her maçı serbestçe düzenleyebiliyor; onay/itiraz akışı yok.
- **Eleme / Grup+Eleme / Şampiyonlar Ligi formatları yarım** → sadece ilk tur üretiliyor, sonraki turlar oluşmuyor; turnuva asla "tamamlandı"ya geçmiyor.
- **Turnuva Wrapped, unvan sistemi, arkadaş grubu sıralaması, profil düzenleme, gerçek paylaşım (share), bildirim üretimi** → tamamen eksik.

**Mağazaya çıkış için hazır değil.** Tahmini olarak mevcut durum, planlanan ürünün yaklaşık **%35-40'ı** seviyesindedir (görselde %70, backend mantığında %20).

---

## 1. YAPILAN İŞLER

### 1.1 Tamamlanan / Çalışan Özellikler

| Özellik | Durum | Not |
|---|---|---|
| Splash ekranı | ✅ | Animasyonlu logo, pulse, loading dots |
| Giriş / Kayıt (kullanıcı adı + şifre) | ✅ | `AuthService.register/signIn` çalışıyor |
| Google ile giriş | ✅ | `signInWithGoogle` + `_ensureUserDocument` |
| Misafir (anonim) giriş | ✅ | `signInAnonymously` |
| Şifre sıfırlama | ✅ | Gerçek e-posta varsa çalışıyor |
| Kullanıcı adı benzersizlik kontrolü | ✅ | `usernames/{key}` belgesi ile |
| Misafir uyarı ekranı | ✅ | Avantaj listesi, animasyonlu |
| Ana panel (Home) | ✅ | Aktif turnuvalar canlı listeleniyor |
| Turnuvalarım (Leagues) | ✅ | Aktif/Tamamlanan/Tümü filtre |
| Turnuva oluşturma (3 adımlı sihirbaz) | ✅ | Format + skor modu + tiebreaker seçimi |
| Davet koduyla katılma | ✅ | 6 haneli kod, `joinByInviteCode` |
| Bekleme lobisi | ✅ | Katılımcı listesi, admin "Başlat" butonu |
| Fikstür üretimi (Lig) | ✅ | Round-robin tam ve doğru |
| Puan tablosu hesaplama | ✅ | 3 tiebreaker modu, mini-tablo, head-to-head — **çok iyi** |
| Gol krallığı hesaplama | ✅ | `computeScorers` |
| Skor girme (temel) | ⚠️ | Çalışıyor ama mod/onay yok (bkz. 2.2) |
| Çark (wheel) | ✅ | CustomPainter çizim, dönüş animasyonu, kaydetme/silme, lig presetleri |
| Sosyal: kullanıcı arama + istek gönderme/kabul/red | ✅ | `friendships` koleksiyonu |
| Ayarlar: tema değiştir + çıkış | ⚠️ | Çalışıyor ama tema kalıcı değil |
| Profil görüntüleme | ⚠️ | Gösteriliyor ama veriler hep boş (bkz. 2.2) |
| Bildirimler ekranı | ⚠️ | Var ama hiçbir bildirim üretilmiyor + ekrana erişim yolu yok |

### 1.2 Teknik Altyapı Durumu

**Güçlü yönler:**
- **Mimari katmanlama temiz:** `models/`, `services/` (repository + provider), `screens/`, `components/`, `core/` ayrımı net.
- **Riverpod** ile bağımlılık enjeksiyonu tutarlı (`firebaseAuthProvider`, `firestoreProvider`, repository provider'ları, `StreamProvider`'lar).
- **go_router** + `StatefulShellRoute.indexedStack` ile sekme durumu korunan bottom-nav.
- **Tema sistemi disiplinli:** Tüm renkler `ColorScheme`/`Theme.of(context)` üzerinden; hard-code renk neredeyse yok (`AppColors` yalnızca tema üretiminde kullanılıyor).
- **Sıralama/averaj motoru** (`computeStandings`) dokümandaki FIFA/UEFA/Karma modlarını, 3+ oyuncu eşitliğinde mini-tablo mantığını özyinelemeli olarak doğru biçimde uygular — projenin en olgun parçası.
- Release imzalama `key.properties` üzerinden hazırlanmış (gradle).

**Bağımlılıklar (pubspec):** firebase_core/auth/firestore/storage, riverpod, go_router, google_fonts, flutter_animate, lottie, rive, confetti, shimmer, share_plus, cached_network_image, google_sign_in. **Ancak** `lottie`, `rive`, `confetti`, `shimmer`, `share_plus`, `cached_network_image`, `firebase_storage` paketlerinin **hiçbiri kodda kullanılmıyor** (ölü bağımlılık — bkz. 2.1 / 5).

### 1.3 Ekran ve Navigasyon Durumu

- 14 route tanımlı (`route_paths.dart`), hepsi router'a bağlı.
- 5 sekmeli bottom-nav: Home, Leagues, Wheel, Social, Profile.
- Tam ekran akışlar (kabuk dışı): create/join tournament, tournament detail, notifications, settings.
- Fiziksel geri tuşu yönetimi (`PopScope`) düşünülmüş.
- **Navigasyon boşlukları:**
  - **Bildirimler ekranına UI'dan erişim yok** — route var ama hiçbir ekranda ona giden buton/zil ikonu yok (Home AppBar'da yalnızca tıklanamayan avatar var). Ekran fiilen ulaşılamaz.
  - **Başka kullanıcının profilini görüntüleme ekranı yok** — doküman "profiller diğer kullanıcılar tarafından görüntülenebilir" diyor; sosyaldeki arkadaşa tıklayınca **kendi** profiline gidiliyor (`profileName`).
  - Splash, oturum durumunu kontrol etmeden her zaman `/login`'e yönlendiriyor (TODO ile işaretli).

---

## 2. EKSİK VE YARIM KALAN İŞLER

### 2.1 Dokümanda Planlanıp Kodlanmayan Özellikler

| Planlanan (Doküman) | Durum | Açıklama |
|---|---|---|
| **Turnuva Wrapped** (esprili sonuç kartı) | ❌ Yok | Kodda hiçbir iz yok. Spotify-Wrapped esinli ana özellik. |
| **Unvan sistemi** (Kral, Avcı, Gol Makinesi…) | ❌ Yok | `activeTitle` okunuyor ama hiç yazılmıyor; atama mantığı yok. |
| **Rozet sistemi** (otomatik kazanım) | ❌ Yok | Profilde katalog gösteriliyor ama hiç rozet verilmiyor (`badges` hep boş). |
| **Profil düzenleme** (foto, kapak, bio, favori takım) | ❌ Yok | Storage'a yükleme kodu hiç yok; alanlar hiç set edilmiyor. |
| **Arkadaş grubu & grup içi sıralama** | ❌ Yok | `friendGroups` koleksiyonu, modeli, ekranı tamamen eksik. |
| **Gerçek WhatsApp/sosyal paylaşım** | ❌ Yok | `share_plus` var ama kullanılmıyor; sadece panoya kopyalama (`Clipboard`). |
| **Deep link / davet linki** (`competra://join/KOD`) | ❌ Yok | `inviteLink` üretilmiyor; AndroidManifest'te intent-filter yok. |
| **Misafir → kalıcı hesap dönüştürme** (`linkWithCredential`) | ❌ Yok | Doküman 2.2 zorunlu kılıyor; misafir verisi kurtarılamaz. |
| **Head-to-head ekranı** (iki oyuncu geçmişi) | ❌ Yok | Hesaplama h2h için var ama oyuncu-bazlı geçmiş ekranı yok. |
| **Turnuva notu görüntüleme** | ⚠️ Kısmi | `note` kaydediliyor ama detay ekranında hiçbir yerde gösterilmiyor. |
| **Skeleton loader (shimmer)** | ❌ Yok | Doküman istiyor; yalnızca `CircularProgressIndicator` var. |
| **Konfeti / şampiyon kutlaması** | ❌ Yok | `confetti` paketi kullanılmıyor. |
| **Lottie / Rive animasyonları** | ❌ Yok | Paketler var, kullanım yok, asset tanımı yok. |
| **ThemeMode.system (otomatik tema)** | ❌ Yok | Yalnızca manuel dark/light; sistem teması seçeneği yok. |
| **Tema kalıcılığı** | ❌ Yok | Bellekte tutuluyor; uygulama yeniden açılınca dark'a dönüyor. |
| **Geri bildirim (feedback) gönderme** | ❌ Yok | `feedback` koleksiyonu, ekranı yok. |
| **Bildirim üretimi** | ❌ Yok | `notifications` okunuyor ama hiçbir akış yazmıyor (hep boş). |

### 2.2 Yarım Kalan İş Mantığı (en kritik teknik borçlar)

1. **İstatistik güncelleme yok (kritik).** Doküman 4.4: bir maç `completed` olunca `participants`, `users` ve `friendGroups/members` belgeleri transaction/batch ile güncellenir. Kodda `updateMatchScore` yalnızca maç belgesine `homeScore/awayScore/played` yazıyor; **hiçbir oyuncu veya kullanıcı istatistiği güncellenmiyor.** Sonuç: profil ekranı her zaman 0 maç / %0 galibiyet / 0 gol / 0 şampiyonluk gösterir; rozet/unvan asla tetiklenmez. Turnuva içi puan tablosu yalnızca anlık maç verisinden hesaplandığı için çalışır, ama kalıcı/global istatistik yoktur.

2. **Skor giriş sistemi (3 mod) uygulanmamış (kritik).** Oluşturmada `scoreMode` (bothPlayers/winnerEnters/adminOnly) seçtiriliyor ve kaydediliyor, ama **hiçbir yerde okunmuyor/uygulanmıyor.** `_ScoreEntryDialog` herkese, her maçı (taraf olmasa bile) doğrudan düzenleme izni verir. Doküman 4.3'teki `awaitingConfirmation`/`disputed`/onay/itiraz akışı, `enteredBy`/`confirmedBy`/`enteredHomeScore` alanları, admin uyuşmazlık çözümü — hiçbiri yok.

3. **Eleme bracket'i ilerlemiyor (kritik).** `generateKnockoutFixtures` yalnızca **açılış turunu** üretir. Kazananları bir sonraki tura taşıyan, yeni eşleşme yazan **hiçbir kod yok.** Yani Eleme turnuvası ilk turdan sonra **takılır**, şampiyon belirlenmez.

4. **Grup+Eleme ve Şampiyonlar Ligi yarım (kritik).** Yalnızca grup/lig fazı maçları üretiliyor. `generateKnockoutFromGroups` fonksiyonu **yazılmış ama hiç çağrılmıyor**; grup sonrası eleme aşamasına geçiş, CL lig→eleme geçişi yok.

5. **Turnuva asla tamamlanmıyor.** `status` hiçbir yerde `completed` yapılmıyor; `completedAt`, şampiyon tespiti yok. Sonuç: "Tamamlanan" filtresi ve profildeki "Geçmiş Turnuvalar" her zaman boş; Wrapped tetiklenemez.

6. **`lastSeen`/`lastActive` hiç güncellenmiyor.** Arkadaş kartlarında "son aktiflik" ve `activeTitle` boş; `summaries` yalnızca `username` içeriyor.

### 2.3 Bağlantısız / TODO Bırakılan Yerler

- `splash_screen.dart:30` — **tek açık TODO:** oturum durumuna göre yönlendirme yapılmamış.
- `notifications_screen.dart` — `_MatchConfirmActions` yorumda "gerçek onay akışı skor sistemiyle birlikte eklenecek" diyerek **stub** bırakılmış (her iki buton da yalnızca okundu işaretliyor).
- `generateKnockoutFromGroups` — yazılmış, **çağrılmayan ölü kod**.
- `firebase_storage`, `share_plus`, `confetti`, `shimmer`, `lottie`, `rive`, `cached_network_image` — bağlanmamış (import edilmeyen) bağımlılıklar.
- `Backend.txt`, `Proje.txt`, `Frontend.txt`, `Frontend_rec.txt` (boş), `stitch_competra_tournament_manager/` — repoda duran çalışma artıkları.

---

## 3. KRİTİK HATALAR VE RİSKLER

### 3.1 Güvenlik Açıkları (ÖNCELİK 1)

> **🔴 EN KRİTİK BULGU: Firestore güvenlik kuralları hiç yok.**
> Projede `firestore.rules`, `storage.rules` veya `firestore.indexes.json` **dosyası yok**; `firebase.json` yalnızca FlutterFire yapılandırması içeriyor, `firestore`/`storage` bölümü içermiyor. Dokümanın 5. bölümünde kural şablonu verilmiş ama **hiç uygulanmamış/deploy edilmemiş.**

**Sonuçları:**
- Veritabanı büyük olasılıkla **test modunda (tamamen açık)** veya tamamen kilitli. Açıksa: kimliği doğrulanmış (hatta **anonim**) herhangi biri **tüm `users`, `tournaments`, `friendships`, `wheels` belgelerini okuyabilir, değiştirebilir ve silebilir.**
- **Veri kazıma (scraping):** `users` ve `usernames` belgelerinde **e-posta saklanıyor** → tüm kullanıcı adı↔e-posta eşlemesi sızdırılabilir (gizlilik/KVKK riski).
- **Sahtecilik:** Bir kullanıcı başkasının adına arkadaşlık oluşturabilir, başkasının turnuva skorunu/istatistiğini değiştirebilir, davet kodunu bilmeden tüm turnuvaları sorgulayabilir.
- **Veri kaybı:** Kötü niyetli/yanlış istemci herhangi bir belgeyi silebilir; geri alma yok.

**Diğer güvenlik notları:**
- Firebase Storage için de kural yok (profil/kapak yüklemesi eklenince doğrudan açık olur).
- `firebase_options.dart` ve `google-services.json` içindeki API anahtarları istemci uygulamaları için normaldir (gizli değildir) — ancak **güvenlik kuralı olmadığında** tam erişim demektir.
- Sentetik `<ad>@competra.internal` e-posta şeması kullanıcı adı sayımına (enumeration) açık.

### 3.2 Kullanıcıyı Doğrudan Etkileyen Bug'lar

| # | Bug | Etki |
|---|---|---|
| 1 | Eleme/Grup/CL ilk turdan sonra ilerlemiyor | Turnuva ortada kalır, şampiyon çıkmaz |
| 2 | Profil istatistikleri hep 0 | "Hesap aç, istatistik kazan" vaadi boşa düşer |
| 3 | Herkes her maç skorunu düzenleyebiliyor | Adil olmayan/yanlış sonuçlar, suistimal |
| 4 | Bildirimler ekranına erişim yok + bildirim üretilmiyor | Sosyal/maç onay döngüsü çalışmaz |
| 5 | Arkadaşa tıklayınca kendi profili açılıyor | Yanlış navigasyon, kafa karışıklığı |
| 6 | Tema yeniden başlatınca sıfırlanıyor | Kullanıcı tercihi kaybolur |
| 7 | Aktif/başlamış turnuvaya katılım engellenmemiş | Fikstüre dahil olmayan "hayalet" katılımcı |
| 8 | Misafir verisi hesaba taşınamıyor | Misafirin tüm turnuvaları kalıcı hesapta kaybolur |
| 9 | Google `signInWithGoogle` `google_sign_in: ^6.x` API'siyle (`.signIn()`) yazılmış | Sürüm/derleme uyumu kontrol edilmeli (6.x'te imza farklı olabilir) |

### 3.3 Firestore Güvenlik Kuralları Durumu

**Özet: YOK. Üretime çıkış için mutlak engelleyici.** Doküman 5.1'deki şablon dahi henüz `firestore.rules` dosyasına dökülmemiş. Bu, hem güvenlik hem veri bütünlüğü açısından projenin 1 numaralı borcudur.

### 3.4 Veri Kaybı Riskleri

- Güvenlik kuralı yokluğu → her belge silinebilir.
- İstatistik güncellemeleri transaction/batch ile yapılmadığından (henüz hiç yapılmadığından) ileride eklendiğinde **kısmi yazım** riski doğacaktır — doküman bunu transaction ile çözmeyi şart koşuyor.
- Misafir hesabı kapatıldığında verinin tamamı kaybolur (link akışı yok).
- Denormalize alanlar (katılımcı `username`) kullanıcı adı değişince güncellenmez (zaten kullanıcı adı değiştirme özelliği de yok).

---

## 4. BACKEND ANALİZİ

### 4.1 Firestore Şeması Doğru Uygulanmış mı? — **Hayır, büyük sapmalar var**

Doküman ile kod arasındaki şema farkları:

| Doküman | Kod | Değerlendirme |
|---|---|---|
| `tournaments/{id}/participants/{uid}` **alt koleksiyon** + tam istatistik | Ana belgede `participants: [{uid,username}]` + `participantIds: []` **dizi** | ❌ Tasarımdan sapma; istatistik alanları yok |
| `adminId` | `ownerId` | ⚠️ İsim farkı |
| `scoreEntrySystem` | `scoreMode` | ⚠️ İsim farkı |
| `matches` zengin model: `status, phase, enteredBy, enteredHomeScore, confirmedBy, playedAt…` | Sade model: `round, order, home/awayUid, home/awayName, home/awayScore, played, isBye, stage, group` | ❌ Onay/durum alanları yok |
| `inviteLink` | yok | ❌ |
| `participantCount, currentRound, totalRounds, wrappedGenerated, completedAt` | yok | ❌ |
| `users/{uid}/stats` alt koleksiyonu | yok (`UserProfile` `stats` map'ten okuyor ama hiç yazılmıyor) | ❌ |
| `users` zengin profil (titles, badges, totalMatches…) | yalnızca `username, usernameLower, email, isAnonymous, createdAt` yazılıyor | ❌ |
| `groups` alt koleksiyonu (grup fazı) | yok | ❌ |
| `friendGroups` + `members` | yok | ❌ |
| `feedback` | yok | ❌ |
| `usernames/{username}` | var (`uid, username, email`) | ✅ (fazladan email) |
| `wheels` (`lastUsedAt` dahil) | var (`lastUsedAt` yok) | ⚠️ Yakın |
| `notifications` | okunuyor, hiç yazılmıyor | ⚠️ |

### 4.2 Eksik Koleksiyonlar / Alanlar

- **Tamamen eksik koleksiyonlar:** `friendGroups` (+`members`), `feedback`, `users/{uid}/stats`, `tournaments/{id}/groups`, `tournaments/{id}/participants` (alt koleksiyon olarak).
- **Hiç yazılmayan koleksiyon:** `notifications`.
- **Eksik ana alanlar:** `inviteLink`, `participantCount`, `currentRound`, `totalRounds`, `wrappedGenerated`, `completedAt`, ayrıca tüm `users` istatistik/profil alanları.

### 4.3 Performans Sorunları

- **Genel ölçek küçük olduğu için kritik darboğaz yok**, ancak:
  - `friendsProvider` ve `incomingRequestsProvider` belgeleri çekip **istemcide filtreliyor** (`status` için sunucu filtresi yok) → gereksiz okuma. Composite index'ten kaçınmak için bilinçli yapılmış ama maliyetli.
  - `myTournamentsStreamProvider` `arrayContains` + **istemci-taraflı sıralama** (index'ten kaçınmak için) → makul.
  - **Sayfalama (pagination) hiçbir yerde yok** — turnuvalar, bildirimler, arama sonuçları sınırsız/tek seferde. Bildirimler büyürse sorun olur.
  - Puan tablosu/gol krallığı her maç snapshot'ında baştan hesaplanıyor — küçük turnuvalar için sorun değil.
- **Index durumu:** Doküman 6.2'de gereken composite index'ler (status+createdAt, friendships users+status, wheels ownerId+createdAt, feedback createdAt) listelenmiş; kod bunlardan **bilinçli kaçınıyor** (tek-alan sorgu + istemci sıralama). Dolayısıyla `firestore.indexes.json` yok ve şimdilik gerekmiyor — ama bu, okuma maliyetini istemciye kaydırıyor.

### 4.4 Güvenlik Kuralları Yeterli mi? — **Hayır (mevcut değil)**

Bkz. 3.1 / 3.3. Hiç kural yok. Bu, backend tarafının en acil işidir.

---

## 5. FRONTEND ANALİZİ

### 5.1 UI/UX Tutarlılığı

- **Güçlü:** Tema disiplini örnek niteliğinde — tüm ekranlar `Theme.of(context).colorScheme` kullanıyor, hard-code renk yok. Kart/rozet/buton stilleri ekranlar arası tutarlı. Bileşen ayrımı temiz.
- **Zayıf:**
  - `_formatLabel` fonksiyonu 3 ekranda **kopyalanmış** (home, leagues, tournament_detail), üstelik farklı çıktılarla (büyük harf "LİG" vs "Lig").
  - `_EmptyState`, `_Avatar`, baş harf (`_initials`) ve hata-snackbar mantığı birçok ekranda tekrar yazılmış.
  - Sıralama dokümanı 4.5'in istediği **averaj türü badge'i, eşit-puan vurgu çizgisi ve tooltip modal'ı** puan tablosunda yok (mod hesapta kullanılıyor ama UI'da hiç gösterilmiyor).

### 5.2 Animasyon ve Geçişler

- ✅ `flutter_animate` ile splash, login, guest-warning, home, leagues, notifications, social'da kademeli (staggered) fade/slide animasyonları var; create-tournament adım göstergesi ve checkmark animasyonları hoş; çark dönüşü ease-out ile gerçekçi.
- ❌ Dokümanın vaat ettiği **konfeti (şampiyon), Lottie/Rive zengin animasyonları, sayfa-geçiş özel efektleri, skeleton loader** yok. `confetti/lottie/rive/shimmer` paketleri yüklü ama kullanılmıyor.

### 5.3 Dark / Light Mod Tam Çalışıyor mu? — **Kısmen**

- ✅ İki tema da tam tanımlı (`AppTheme.light/dark`), tüm bileşenler temaya bağlı, anahtarla anında geçiş yapıyor.
- ❌ **Kalıcı değil** (bellekte; yeniden başlatınca dark'a döner — `shared_preferences` yok).
- ❌ `ThemeMode.system` (sistem temasına otomatik uyum) seçeneği yok; doküman bunu istiyor.

### 5.4 Boş Durum ve Hata Durumları

- ✅ **Çok iyi kapsanmış:** Home, Leagues, Wheel, Social, Profile, Notifications ve turnuva sekmeleri (Fikstür/Puan/İstatistik) için özel boş-durum widget'ları var. Stream tüketen ekranların çoğunda `.when(error: …)` ile hata kartı/mesajı var.
- ⚠️ Hata mesajları genel ("yüklenemedi"); ağ/izin ayrımı yok. Loglama/telemetri yok.

### 5.5 Loading State'ler Yeterli mi? — **Fonksiyonel ama düşük kalite**

- ✅ Tüm async işlemlerde (`CircularProgressIndicator`) ve buton içi spinner'lar var.
- ❌ Dokümanın istediği **skeleton/shimmer** yok; yükleme deneyimi "pürüzsüz" değil, spinner ağırlıklı. Home'da özel `_LoadingCard`, diğerlerinde çıplak spinner → tutarsızlık.

---

## 6. PROFESYONELLİK DEĞERLENDİRMESİ

### 6.1 Kategori Bazlı Puanlama (1–10)

| Kategori | Puan | Gerekçe |
|---|---:|---|
| Mimari & kod organizasyonu | **8/10** | Temiz katmanlama, Riverpod/repository deseni tutarlı |
| UI tasarımı & tema | **8/10** | Tutarlı, disiplinli tema; eksik: skeleton/zengin animasyon |
| Animasyon & mikro-etkileşim | **6/10** | İyi temel; konfeti/Lottie/Rive vaadi karşılanmamış |
| Boş/hata/yükleme durumları | **7/10** | Kapsamlı boş durumlar; loading kalitesi düşük |
| Backend / veri modeli | **3/10** | Şema sapması, istatistik yazımı yok, koleksiyonlar eksik |
| İş mantığı bütünlüğü | **3/10** | Skor modu, bracket ilerleme, tamamlama, wrapped eksik |
| **Güvenlik** | **1/10** | Firestore kuralları hiç yok — kritik |
| Özellik tamlığı (dokümana göre) | **3/10** | Ana özelliklerin yarısı yarım/eksik |
| Test & kalite güvencesi | **2/10** | Yalnızca 2 widget testi; mantık testsiz |
| Üretime hazırlık (release) | **2/10** | Kural yok, INTERNET izni şüpheli, ölü bağımlılıklar |
| **GENEL ORTALAMA** | **≈ 4.3/10** | Sağlam iskelet, eksik motor |

### 6.2 Gerçek Bir Uygulama Mağazasına Çıkmak İçin Ne Eksik?

1. **Firestore + Storage güvenlik kuralları** (zorunlu, mağaza/gizlilik açısından şart).
2. **İstatistik yazımı + turnuva tamamlama + bracket ilerleme** (ürünün çekirdek değeri).
3. **Skor giriş sistemi (onay/itiraz akışı).**
4. **Android `INTERNET` izninin ana manifeste eklenmesi** — `AndroidManifest.xml`'de yok; release build'de Firebase ağ erişimi kırılabilir (debug manifest otomatik ekler, release etmez). **Release engelleyici olabilir; doğrulanmalı.**
5. Uygulama ikonu/adı (`android:label="competra"` küçük harf, varsayılan ikon), gizlilik politikası, KVKK/aydınlatma metni, hesap silme akışı (mağaza zorunlulukları).
6. Crash reporting (Crashlytics) + temel analytics.
7. Profil düzenleme, gerçek paylaşım, bildirim üretimi, Wrapped (ürün vaadi).

### 6.3 Son Kullanıcı Deneyimi Değerlendirmesi

İlk açılış–kayıt–turnuva oluştur–lobi–lig fikstürü–skor gir–puan tablosu akışı **demo olarak akıcı ve görsel olarak tatmin edici.** Ancak gerçek kullanımda kullanıcı kısa sürede duvara toslar: profil hep boş, rozet/unvan gelmez, eleme turnuvası yarıda kalır, "tamamlanan" hiç olmaz, bildirim gelmez, paylaşım gerçek değildir. Yani **"vitrin" hazır, "mağaza" boş.** Mevcut haliyle bir iç demo/PoC seviyesindedir; son kullanıcıya sunulamaz.

---

## 7. ÖNCELİKLİ GELİŞTİRME ÖNERİLERİ

> Süre tahminleri 1 orta-kıdemli Flutter geliştiricisi içindir. Zorluk: ⭐ kolay – ⭐⭐⭐⭐⭐ çok zor.

### 7.1 KRİTİK (hemen yapılmalı)

| Öneri | Süre | Zorluk |
|---|---|---|
| `firestore.rules` + `storage.rules` yaz, `firebase.json`'a ekle, deploy et (doküman 5.1 şablonu + güncel şemaya uyarla) | 1–2 gün | ⭐⭐⭐ |
| Maç tamamlanınca istatistik güncelleme (participants + users) — **transaction/batch** ile | 2–3 gün | ⭐⭐⭐⭐ |
| Skor giriş sistemi 3 modunun (çift onay / kazanan girer / sadece admin) gerçek akışı + maç `status` alanları | 4–6 gün | ⭐⭐⭐⭐⭐ |
| Eleme bracket ilerlemesi (kazananı sonraki tura taşı, yeni tur üret) | 3–4 gün | ⭐⭐⭐⭐ |
| Turnuva tamamlama + şampiyon tespiti + `status=completed` | 2 gün | ⭐⭐⭐ |
| Android `INTERNET` iznini ana manifeste ekle (release doğrulaması) | 1 saat | ⭐ |

### 7.2 ÖNEMLİ (kısa vadede)

| Öneri | Süre | Zorluk |
|---|---|---|
| Grup+Eleme ve Şampiyonlar Ligi aşama geçişleri (`generateKnockoutFromGroups` bağla) | 3–4 gün | ⭐⭐⭐⭐ |
| Profil düzenleme + Storage'a foto/kapak yükleme (`cached_network_image` ile gösterim) | 3 gün | ⭐⭐⭐ |
| Bildirim üretimi (arkadaşlık isteği, maç onayı, davet) + ekrana erişim (zil ikonu) | 2–3 gün | ⭐⭐⭐ |
| Misafir → kalıcı hesap (`linkWithCredential`) | 1–2 gün | ⭐⭐⭐ |
| Rozet & unvan otomatik atama (istatistik güncellemesine bağlı) | 2–3 gün | ⭐⭐⭐ |
| Tema kalıcılığı + `ThemeMode.system` (`shared_preferences`) | 0.5 gün | ⭐⭐ |
| Gerçek paylaşım (`share_plus`) + davet linki/deep link | 1–2 gün | ⭐⭐⭐ |
| Başka kullanıcının profilini görüntüleme ekranı + route | 1 gün | ⭐⭐ |
| Splash'ta oturum-bazlı yönlendirme + router `redirect` guard | 0.5 gün | ⭐⭐ |
| Başlamış turnuvaya katılımı engelle (`status` kontrolü) | 2 saat | ⭐ |

### 7.3 İYİLEŞTİRME (uzun vadede)

| Öneri | Süre | Zorluk |
|---|---|---|
| Turnuva Wrapped (esprili sonuç kartı + paylaşılabilir görsel) | 4–6 gün | ⭐⭐⭐⭐ |
| Arkadaş grubu & grup içi sıralama (`friendGroups`) | 4–5 gün | ⭐⭐⭐⭐ |
| Skeleton/shimmer yükleme, konfeti, Lottie/Rive animasyonları | 3–4 gün | ⭐⭐⭐ |
| Head-to-head geçmiş ekranı | 2 gün | ⭐⭐ |
| Geri bildirim (feedback) ekranı | 1 gün | ⭐⭐ |
| Crashlytics + Analytics + sayfalama | 2–3 gün | ⭐⭐⭐ |
| Unit test (fixture_generator, computeStandings) + repo testleri | 3–4 gün | ⭐⭐⭐ |
| Cloud Functions'a istatistik/bracket mantığı taşıma (güvenlik + tutarlılık) | 5–7 gün | ⭐⭐⭐⭐⭐ |

---

## 8. PROFESYONEL SEVİYEYE ÇIKARMAK İÇİN YOL HARİTASI

### Adım Adım (öncelik sırasıyla)

**Faz 0 — Güvenlik & Release Engelleyiciler (1 hafta)**
1. Firestore + Storage güvenlik kurallarını yaz/deploy et.
2. `INTERNET` iznini ana manifeste ekle, release build'i fiziksel cihazda doğrula.
3. `email`'i `usernames`/`users` belgelerinden ayır veya kuralla koru (gizlilik).

**Faz 1 — Çekirdek İş Mantığını Tamamla (2–3 hafta)**
4. Maç tamamlama → istatistik yazımı (transaction).
5. Skor giriş sistemi 3 modunun gerçek akışı + maç durum alanları.
6. Eleme bracket ilerlemesi + turnuva tamamlama + şampiyon.
7. Grup+Eleme / Şampiyonlar Ligi aşama geçişleri.

**Faz 2 — Profil & Sosyal Döngü (1–2 hafta)**
8. Profil düzenleme + Storage yükleme.
9. Rozet & unvan otomatik atama.
10. Bildirim üretimi + erişim + maç onay döngüsünü bildirimle bağla.
11. Misafir → kalıcı hesap dönüşümü.
12. Diğer kullanıcı profili ekranı, başka kullanıcının profili.

**Faz 3 — Cila & Ürün Vaadi (1–2 hafta)**
13. Turnuva Wrapped.
14. Gerçek paylaşım + deep link.
15. Skeleton loader, konfeti, Lottie/Rive; tema kalıcılığı + system.
16. Arkadaş grubu sıralaması.

**Faz 4 — Üretim Sertleştirme (1 hafta)**
17. Crashlytics + Analytics, sayfalama, hata mesajı iyileştirme.
18. Unit/integration testleri, CI.
19. Mağaza varlıkları: ikon, ekran görüntüleri, gizlilik politikası, hesap silme, sürümleme.

**Tahmini toplam:** ~7–9 hafta (tek geliştirici).

### Teknik Borç (Technical Debt) Değerlendirmesi

| Borç | Şiddet | Aciliyet |
|---|---|---|
| Güvenlik kuralı yokluğu | 🔴 Çok yüksek | Hemen |
| İstatistik yazımı/transaction eksikliği | 🔴 Yüksek | Hemen |
| Şema-doküman sapması (participants dizi vs alt koleksiyon) | 🟠 Orta-yüksek | Faz 1'de karara bağla (dokümanı mı, kodu mu izleyeceksin?) |
| Skor modu/bracket ilerleme eksikliği | 🔴 Yüksek | Faz 1 |
| Kod tekrarı (`_formatLabel`, `_EmptyState`, snackbar) | 🟡 Düşük | Faz 3 refactor |
| Ölü bağımlılıklar | 🟡 Düşük | Kullan ya da kaldır |
| Test yokluğu | 🟠 Orta | Faz 4 |
| İstemci-taraflı mantık (Functions yok) | 🟠 Orta | Uzun vade |

**Not:** En büyük mimari karar — `participants`'ın **dizi** (mevcut kod) mı yoksa **alt koleksiyon** (doküman) mı olacağıdır. İstatistik ve güvenlik kuralları bu karara doğrudan bağlı olduğundan Faz 1'den önce netleştirilmelidir. Önerilen: çok büyük turnuvalar hedeflenmiyorsa dizi yaklaşımı sürdürülüp istatistikler maç tamamlamada hesaplanabilir; ancak per-katılımcı yazım ve kural granülerliği için alt koleksiyon daha sağlamdır.

---

## 9. KOD KALİTESİ

### 9.1 Kod Tekrarı

- **Var, orta düzeyde.** En belirginleri:
  - `_formatLabel` → 3 dosyada kopya (üstelik tutarsız çıktı).
  - `_EmptyState` → en az 5 ekranda neredeyse aynı widget yeniden tanımlı.
  - `_Avatar` / `_initials` baş-harf mantığı → social ve profile'da ayrı ayrı.
  - Hata snackbar deseni (`scheme.error` + `onError`) → ~8 yerde tekrar.
- **Öneri:** `core/widgets/` altında ortak `AppEmptyState`, `AppErrorSnackBar`, `formatLabel(format)` util'i, `InitialsAvatar` çıkarılmalı.

### 9.2 Mimari Tutarlılık

- **Yüksek.** Tüm veri erişimi repository + provider üzerinden; ekranlar Firebase'e doğrudan dokunmuyor (tek istisna: settings çıkış için `firebaseAuthProvider`'ı doğrudan kullanıyor — kabul edilebilir). Model `fromDoc`/`toMap` desenleri tutarlı, null-güvenli ve varsayılan-dolu. İsimlendirme ve Türkçe doküman yorumları nitelikli.
- Tutarsızlık: doküman alan adları (`adminId`, `scoreEntrySystem`) ile kod (`ownerId`, `scoreMode`) eşleşmiyor; bu, ileride doküman/kod senkronizasyonu için risk.

### 9.3 Test Coverage Durumu — **Çok düşük**

- Yalnızca `test/widget_test.dart` (2 widget testi: splash→login akışı, misafir uyarı akışı).
- **En kritik ve test edilmesi en kolay saf-mantık** (`fixture_generator.dart`, `computeStandings`/`computeScorers`) **hiç test edilmemiş.** Bunlar dış bağımlılıksız, deterministik fonksiyonlar — yüksek getirili test fırsatı.
- Repository/servis testi yok. Tahmini satır kapsamı **%5'in altında.**

### 9.4 Hata Yönetimi Yeterliliği — **Orta**

- ✅ `AuthService` Firebase hata kodlarını Türkçe kullanıcı mesajlarına çeviriyor (`_mapError`) — örnek niteliğinde.
- ✅ Ekranlarda `try/catch` + kullanıcı dostu snackbar + `mounted` kontrolleri tutarlı.
- ⚠️ Çoğu yerde `catch (_)` ile **hata yutuluyor**; loglama/crash reporting yok → üretimde teşhis zor.
- ⚠️ Hata ayrıntısı kullanıcıya/lara genelleniyor (ağ mı, izin mi, sunucu mu belirsiz).
- ⚠️ Optimistic update'ler (ör. `_sentTo.add` sonra hata) geri alınıyor — iyi; ama genel bir hata altyapısı (ör. `Result` tipi / merkezi error handler) yok.

---

## 10. SONUÇ

Competra, **mimari ve görsel açıdan güçlü bir temel** üzerine kurulmuş; tema disiplini, katmanlı yapı, boş/hata durumları ve özellikle sıralama/averaj motoru profesyonel kalitededir. Ne var ki ürünün **çekirdek iş mantığının büyük bölümü (istatistik kalıcılığı, skor onay sistemi, eleme ilerlemesi, turnuva tamamlama, wrapped, unvan/rozet, gerçek sosyal döngü) henüz uygulanmamış** ve **en kritik olarak Firestore güvenlik kuralları hiç mevcut değildir.**

**Önceliklendirme net:** önce güvenlik kuralları ve release engelleyiciler (Faz 0), ardından çekirdek turnuva mantığı (Faz 1). Bu iki faz tamamlanmadan uygulama ne güvenli ne de işlevsel olarak "gerçek bir ürün"dür. Tahmini 7–9 haftalık odaklı çalışmayla mağazaya çıkabilecek profesyonel seviyeye ulaşması mümkündür.

*— Competra Analiz Raporu sonu —*
