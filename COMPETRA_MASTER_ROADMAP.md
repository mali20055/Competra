# COMPETRA — 10/10 Yol Haritası
## 3 Yapay Zeka Raporu Sentezi + Seçilen Yeni Özellikler

> **Tarih:** 22 Haziran 2026  
> **Kaynak:** Claude V3 + Cursor V3 + Antigravity V3 Analiz Raporları  
> **Hedef:** Her boyutta 10/10 uygulama

---

## 📊 MEVCUT DURUM (3 Rapor Ortalması)

| Modül | Mevcut Puan | Hedef | Fark |
|---|---|---|---|
| UI/UX | 8.2/10 | 10/10 | +1.8 |
| Backend | 7.2/10 | 10/10 | +2.8 |
| Güvenlik | 6.0/10 | 10/10 | +4.0 |
| Performans | 6.0/10 | 10/10 | +4.0 |
| Kod Kalitesi | 7.3/10 | 10/10 | +2.7 |
| Test Coverage | 1.5/10 | 10/10 | +8.5 |
| DevOps | 3.3/10 | 10/10 | +6.7 |
| Ölçeklenebilirlik | 5.7/10 | 10/10 | +4.3 |
| Kullanıcı Deneyimi | 7.3/10 | 10/10 | +2.7 |

**Genel Ortalama:** ~6.0/10 → Hedef: 10/10

---

## 🔴 3 RAPORUN ORTAK KRİTİK BULGULARI

Üç yapay zeka da şu sorunlarda HEMFİKİR:

1. **Test coverage ~%1** — En büyük teknik risk
2. **`users` write kuralı çok geniş** — İstatistik şişirme mümkün
3. **Pagination yok** — Ölçekte kırılır
4. **`_emailForUsername` anonim oturum hack'i** — Kırılgan
5. **Bildirimler gerçek akışa bağlı değil** — Sahte butonlar
6. **`tournament_detail_screen` 2200+ satır** — Bakım imkansız
7. **Magic string'ler** — Her yere dağılmış
8. **CI/CD yok** — Manuel ve riskli
9. **Firebase App Check yok** — Bot koruması yok
10. **iOS yapılandırması eksik** — App Store bloklu
11. **i18n string'leri taşınmamış** — Altyapı var, içerik yok
12. **Storage boyut/içerik-tip sınırı yok** — DoS riski
13. **`onMatchWritten` tüm maçları okuyor** — Ölçekte pahalı
14. **Firebase Analytics yok** — Kör uçuş
15. **`competra-release.jks` repo'da** — Güvenlik riski (Antigravity)

---

## 🎯 SEÇİLEN YENİ ÖZELLİKLER

### Antigravity'den Seçilenler (22 özellik):
1. Oyuncu Profili Ziyareti
2. Arkadaş Aktivite Feed'i
3. Sezon Sistemi
4. Head-to-Head İstatistik
5. İstatistik Grafikleri (geliştirilmiş)
6. MVP Ödülü
7. Kazanan Tahmini
8. Turnuva Şablonları
9. Turnuva Düzenleme
10. Katılımcı Çıkarma
11. Şampiyonluk Konfeti (iyileştirme)
12. Onboarding İyileştirme
13. i18n String Geçişi (tam)
14. Haptik Geri Bildirim (geliştirilmiş)
15. Pull-to-Refresh
16. Premium Tema Paketi
17. Reklamsız Deneyim
18. Offline Mod
19. Web Versiyonu
20. Profil Fotoğrafı Kırpma
21. QR Kod ile Katılma
22. Turnuva Bracket Görseli

### Claude'dan Seçilenler (16 özellik):
1. Profil Karşılaştırma / H2H Geçmişi
2. Arkadaş Grubu Sezonları
3. ELO / MMR Derecelendirme
4. Sezonluk Global Lig + Ödüller
5. Başarım Vitrini + Paylaşılabilir Kart
6. Takım/Oyuncu Havuzu (Kadro)
7. Turnuva Şablonları (üst küme ile)
8. Yönetici Yetki Devri / Çoklu Admin
9. Premium (Competra Pro)
10. Özel Tema / Avatar Çerçeveleri
11. Çevrimdışı Mod + Senkronizasyon
12. Sesli/Görsel Maç Özeti (Wrapped genişletme)
13. Push Tercih Yönetimi
14. QR Kod ile Katılma (üst küme ile)
15. İstatistik Grafik Panosu (Dashboard)
16. Çok Dilli Tam Destek

**Toplam Benzersiz Özellik:** ~30 (çakışanlar birleştirildi)

---

## 🗺️ MASTER YOL HARİTASI

---

## FAZ 0 — KRİTİK GÜVENLİK (Hafta 1-2)
> **Hedef:** Yayına engel güvenlik açıklarını kapat

### Prompt G1 — Güvenlik Kuralları + Keystore
```
Öncelik: KRİTİK
Tahmini süre: 2-3 gün
```

**İçerik:**
- `competra-release.jks`'ı repo'dan çıkar, `.gitignore`'a ekle
- `users/{uid}` write kuralına alan allowlist ekle:
  - Sadece: `username, usernameLower, bio, favoriteTeam, photoUrl, coverUrl, fcmToken, fcmTokenUpdatedAt`
  - İstatistik alanları istemciden yazılamaz hale getirilmeli
- Storage kurallarına boyut (5MB) ve content-type (`image/*`) sınırı
- `notifications.create`'e alan kısıtı (senderId doğrulama)
- `friendGroups.create`'e `createdBy == auth.uid` kontrolü
- `joinByInviteCode`'a `status == 'waiting'` kontrolü
- `firestore.rules` deploy

### Prompt G2 — Hata Yönetimi + Bildirim Akışı
```
Öncelik: KRİTİK
Tahmini süre: 2-3 gün
```

**İçerik:**
- `markRead`, `deleteWheel`, `recordResult`, `acceptRequest` fonksiyonlarına try/catch
- `runAchievements`, `updateFriendGroupStats` CF'e try/catch + logger.error
- `notifications_screen.dart`'taki sahte butonları gerçek akışa bağla:
  - matchConfirm bildirimine → turnuva detayına yönlendir
  - tournamentComplete bildirimine → wrapped ekranına yönlendir
  - Onay/itiraz butonlarını gerçek `submitScoreForConfirmation`/`markDisputed`'a bağla
- `AppNotification` modeline `tournamentId`, `matchId`, `senderId` alanları ekle

---

## FAZ 1 — KOD KALİTESİ + ALTYAPI (Hafta 2-5)
> **Hedef:** Bakım kolaylığı, test edilebilirlik, CI/CD

### Prompt K1 — Sabitler + Ölü Kod Temizliği
```
Öncelik: YÜKSEK
Tahmini süre: 2-3 gün
```

**İçerik:**
- `lib/core/constants/` klasörü oluştur:
  - `tournament_constants.dart` (format, status, phase)
  - `notification_constants.dart` (tipler)
  - `app_constants.dart` (limitler, süreler)
- Magic string'leri sabitlerle değiştir (tüm dosyalarda)
- `achievement_service.dart` istemci tarafı çağrılarını kaldır (CF yapıyor)
- `social_repository.dart` istemci `updateFriendGroupStats` çağrısını kaldır
- `tournament.dart`'tan `computeStandings` ve `computeScorers`'ı ayrı `services/standings_service.dart`'a çıkar

### Prompt K2 — Ortak UI Bileşenleri + Tournament Detail Bölme
```
Öncelik: YÜKSEK
Tahmini süre: 3-4 gün
```

**İçerik:**
- `lib/components/` genişlet:
  - `empty_state.dart` (paylaşılan EmptyState)
  - `player_avatar.dart` (baş harfli CircleAvatar)
  - `stat_chip.dart` (istatistik rozeti)
  - `loading_overlay.dart`
  - `primary_button.dart`
- `BuildContext` extension: `context.showError()`, `context.showSuccess()`
- `core/utils/sort_utils.dart`: `compareByCreatedAtDesc` yardımcısı
- `core/utils/format_labels.dart`: `_formatLabel` birleştirmesi
- `tournament_detail_screen.dart` bölme:
  - `screens/tournament/widgets/fixture_tab.dart`
  - `screens/tournament/widgets/standings_tab.dart`
  - `screens/tournament/widgets/stats_tab.dart`
  - `screens/tournament/widgets/match_card.dart`
  - `screens/tournament/widgets/score_entry_dialog.dart`
  - `screens/tournament/widgets/two_legged_card.dart`
  - `screens/tournament/widgets/dispute_resolution_dialog.dart`

### Prompt K3 — CI/CD + Firebase Emulator
```
Öncelik: YÜKSEK
Tahmini süre: 2-3 gün
```

**İçerik:**
- `.github/workflows/ci.yml` oluştur:
  - Flutter: pub get → analyze → test → build appbundle
  - Functions: npm ci → lint → tsc → test
  - Deploy: functions + rules + indexes (main branch'te)
- `firebase.json`'a emulator bloğu ekle (auth:9099, firestore:8080, functions:5001)
- `functions/` için Jest test altyapısı kur (`npm install --save-dev jest @types/jest`)
- `.firebaserc` oluştur (proje config)
- GitHub Secrets dokümantasyonu: KEYSTORE_PASSWORD, KEY_ALIAS, FIREBASE_SERVICE_ACCOUNT

### Prompt K4 — Temel Unit Testler
```
Öncelik: KRİTİK
Tahmini süre: 4-5 gün
```

**İçerik:**
- `test/` klasörü yapısı kur:
  - `test/domain/standings_test.dart`
  - `test/domain/fixtures_test.dart`
  - `test/domain/validators_test.dart`
  - `test/models/tournament_model_test.dart`
- `computeStandings` testleri (FIFA/UEFA/Karma, 3+ oyuncu, tiebreaker)
- `computeScorers` testleri
- `generateLeagueFixtures` testleri (round-robin doğruluğu)
- `generateKnockoutFixtures` testleri (bye dağıtımı)
- `generateNextKnockoutRound` testleri
- `Validators` testleri (sınır değerler)
- `timeAgoTr` testleri
- `functions/tests/standings.test.ts` (Dart↔TS parite)
- `functions/tests/fixtures.test.ts`
- Firestore rules testleri (`@firebase/rules-unit-testing`)

---

## FAZ 2 — PERFORMANS + ANALYTICS (Hafta 5-7)
> **Hedef:** Ölçeklenebilir, ölçülebilir uygulama

### Prompt P1 — Pagination + Query Optimizasyonu
```
Öncelik: YÜKSEK
Tahmini süre: 3-4 gün
```

**İçerik:**
- `notificationsProvider`: `orderBy('createdAt', descending: true).limit(30)`
- `myTournamentsStreamProvider`: `orderBy('createdAt', descending: true).limit(20)`
- `myWheelsStreamProvider`: `limit(20)`
- `leaderboard_screen`: `limit(50)` + "Daha fazla yükle" butonu
- `userRecentMatchesProvider`: `.limit(20)` ekle
- Cloud Functions `onMatchWritten`: tüm maçlar yerine `where('roundNumber', '==', currentRound)` + `where('phase', '==', currentPhase)` sorgusu
- `social_repository` N+1: grup bilgisini üye belgesine denormalize et (`groupName`, `groupCreatedBy`)
- Mevcut index'lere `orderBy` ekle (sorgularda kullanılsın)

### Prompt P2 — Firebase Analytics + App Check + Performance
```
Öncelik: YÜKSEK
Tahmini süre: 2-3 gün
```

**İçerik:**
- `firebase_analytics` paketi ekle + `main.dart`'ta başlat
- Temel event'ler: `tournament_created`, `tournament_joined`, `match_score_entered`, `share_result`, `wheel_spin`
- Firebase App Check entegrasyonu (Play Integrity for Android)
- `firebase_performance` paketi ekle
- Cold start optimizasyonu: CF'e `minInstances: 1` ekle (kritik fonksiyon)
- `shimmer` paketini skeleton loading olarak uygula (tournament list, leaderboard)
- `CachedNetworkImage` kullanımını standartlaştır

---

## FAZ 3 — KOLAY YENİ ÖZELLİKLER (Hafta 7-10)
> **Hedef:** Hızlı kazanımlar, kullanıcı memnuniyeti

### Prompt Y1 — Pull-to-Refresh + Haptic + Confetti + QR
```
Öncelik: ORTA
Tahmini süre: 3-4 gün
```

**İçerik:**
- `RefreshIndicator` ile Pull-to-Refresh: leagues_screen, home_screen, social_screen, leaderboard
- `HapticFeedback` iyileştirmeleri: skor onayı, arkadaş isteği, rozet kazanımı
- `confetti` paketini `tournament_wrapped_screen`'de düzgün uygula (şu an eksik)
- `qr_flutter` paketi ekle + turnuva detayında QR kod modal
- `mobile_scanner` paketi ekle + katılma ekranında QR tarayıcı
- QR kodu davet link/kodu ile oluştur

### Prompt Y2 — Profil Fotoğrafı Kırpma + Oyuncu Profili Ziyareti
```
Öncelik: ORTA
Tahmini süre: 3-4 gün
```

**İçerik:**
- `image_cropper` paketi ekle
- Profil/kapak fotoğrafı seçilince kırpma ekranı aç
- `/profile/:uid` route'u ekle (başkasının profilini görme)
- `UserProfile` ekranını parametrik hale getir
- Kendi profilin: düzenleme butonu görünür
- Başkasının profili: "Arkadaş Ekle" / "Mesaj" butonu
- Rozet, unvan, istatistik göster
- Turnuva geçmişini listele (sadece tamamlananlar)

### Prompt Y3 — Turnuva Düzenleme + Katılımcı Çıkarma + Şablonlar
```
Öncelik: ORTA
Tahmini süre: 3-4 gün
```

**İçerik:**
- Turnuva `waiting` durumundayken düzenleme ekranı:
  - Ad, not, skor giriş modu değiştirilebilsin
  - Format değiştirilemez (fikstür bozulur)
- Admin için katılımcı listesinde "Çıkar" butonu (onay dialogu ile)
  - `participantIds` ve `participants` dizisinden kaldır
  - Başlamış turnuvada çıkarma engellenir
- Turnuva şablonları:
  - `templates` Firestore koleksiyonu
  - "Şablon olarak kaydet" butonu (turnuva oluşturma sonrası)
  - Yeni turnuva oluştururken "Şablondan başla" seçeneği
  - Şablon: format, oyuncu sayısı, skor modu, tiebreaker

### Prompt Y4 — Push Tercih Yönetimi + Onboarding İyileştirme
```
Öncelik: ORTA
Tahmini süre: 2-3 gün
```

**İçerik:**
- `settings_screen.dart`'a bildirim tercihleri bölümü:
  - Maç onayı bildirimleri (açık/kapalı)
  - Turnuva tamamlanma (açık/kapalı)
  - Arkadaşlık istekleri (açık/kapalı)
  - `users/{uid}.notificationPrefs` Firestore'a kaydet
- CF `onNotificationCreated`'da tercih kontrolü
- `onboarding_screen.dart` iyileştirme:
  - `lottie` animasyonları ekle (her slayta)
  - "İlk turnuvanı şimdi oluştur" aksiyonlu CTA
  - Misafir için özel onboarding akışı

---

## FAZ 4 — ORTA BÜYÜK ÖZELLİKLER (Hafta 10-16)
> **Hedef:** Rekabet derinliği, sosyal bağlanma

### Prompt B1 — Head-to-Head + İstatistik Dashboard
```
Öncelik: YÜKSEK
Tahmini süre: 4-5 gün
```

**İçerik:**
- Profil ekranında "H2H" butonu
- `/h2h/:uid1/:uid2` route'u
- `collectionGroup('matches')` ile iki oyuncu arasındaki tüm maçlar
- H2H ekranı: toplam maç, galibiyet/beraberlik/mağlubiyet, toplam gol, son 5 maç
- Profil ekranı istatistik dashboard genişletme:
  - Form grafiği (fl_chart - zaten var, iyileştir)
  - Gol trendi (aylık gol ortalaması)
  - Turnuva formatı dağılımı (pie chart)
  - En çok oynandığı format
  - Galibiyet serisi (en uzun)

### Prompt B2 — ELO / MMR Derecelendirme
```
Öncelik: YÜKSEK
Tahmini süre: 4-5 gün
```

**İçerik:**
- `users/{uid}.eloRating` alanı (başlangıç: 1000)
- Cloud Functions `onMatchWritten`'a ELO hesaplama:
  - K-faktörü: 32 (standart)
  - Beklenen skor: `1/(1+10^((Rb-Ra)/400))`
  - ELO değişimi: `K * (sonuç - beklenen)`
  - Sadece tamamlanan maçlarda güncelle
- Profil ekranında ELO göster + "Ranking" rozeti
- Global liderboard'da ELO filtresi ekle
- ELO geçmişi grafiği (son 20 maç)
- Firestore index: `users.eloRating DESC`

### Prompt B3 — Arkadaş Aktivite Feed'i
```
Öncelik: ORTA
Tahmini süre: 4-5 gün
```

**İçerik:**
- `activity_feed/{uid}` Firestore koleksiyonu (per-user feed)
- Cloud Functions'ta fan-out:
  - Turnuva tamamlanınca → tüm arkadaşların feed'ine yaz
  - Rozet kazanılınca → arkadaşların feed'ine yaz
  - ELO rekor kırılınca → arkadaşların feed'ine yaz
- `home_screen.dart` "Arkadaş Aktivitesi" bölümünü gerçek feed'e bağla
- Feed kartı: avatar + isim + aktivite + zaman

### Prompt B4 — Başarım Vitrini + Paylaşılabilir Kart
```
Öncelik: ORTA
Tahmini süre: 3-4 gün
```

**İçerik:**
- Profil ekranında "Vitrin" bölümü: 3 rozet sergileme (kullanıcı seçer)
- `users/{uid}.showcaseBadges: [id1, id2, id3]` Firestore alanı
- Rozet seçim modal (drag-drop sıralama)
- Paylaşılabilir başarım kartı (RepaintBoundary):
  - Kullanıcı adı + ELO + toplam galibiyet + en iyi rozet
  - Competra watermark
  - share_plus ile paylaş

### Prompt B5 — Çoklu Admin + Takım/Oyuncu Havuzu
```
Öncelik: ORTA
Tahmini süre: 4-5 gün
```

**İçerik:**
- `tournaments/{id}.adminIds: [uid1, uid2]` alanı
- Admin "Yardımcı Yönetici Ekle" butonu (katılımcılar arasından seçim)
- Firestore rules: `isTournamentAdmin` fonksiyonu `adminIds` dizisini de kontrol etsin
- Takım/Oyuncu Havuzu (Kadro):
  - `tournaments/{id}.roster: [{uid, teamName, teamColor}]` alanı
  - Lobi ekranında her katılımcıya takım rengi atama
  - Çark'tan gelen takım → otomatik atama
  - Maç kartında takım adı göster

---

## FAZ 5 — SEZON SİSTEMİ (Hafta 16-20)
> **Hedef:** Uzun vadeli retention

### Prompt S1 — Sezon Altyapısı
```
Öncelik: ORTA
Tahmini süre: 5-6 gün
```

**İçerik:**
- `seasons/{seasonId}` Firestore koleksiyonu:
  - `startDate`, `endDate`, `name`, `isActive`
- `users/{uid}.seasonStats.{seasonId}` iç içe map
- Cloud Functions Scheduled Function:
  - Her ayın 1'inde yeni sezon aç
  - Geçen sezonun şampiyonlarına özel rozet ver
- `leaderboard_screen`'e "Bu Sezon" / "Tüm Zamanlar" filtresi
- Sezon geri sayım sayacı (ana sayfa)

### Prompt S2 — Arkadaş Grubu Sezonları + Sezonluk Global Lig
```
Öncelik: ORTA
Tahmini süre: 4-5 gün
```

**İçerik:**
- `friendGroups/{groupId}/seasons/{seasonId}/stats` alt koleksiyonu
- Grup sıralama ekranında sezon filtreleme
- Sezon sonu grup ödülü: "Grup Şampiyonu" rozeti
- Global sezonluk lig:
  - Her sezon sonunda top 10 → özel "Sezon Efsanesi" unvanı
  - Wrapped genişletme: sezon özeti ekranı

### Prompt S3 — MVP Ödülü + Kazanan Tahmini
```
Öncelik: DÜŞÜK
Tahmini süre: 4-5 gün
```

**İçerik:**
- MVP Ödülü:
  - Turnuva tamamlanınca katılımcılar 24 saat boyunca oy kullanabilir
  - `tournaments/{id}/votes/{uid}` alt koleksiyonu
  - En çok oy alan → MVP rozeti
  - Veya algoritma: gol + galibiyet katkısı
- Kazanan Tahmini:
  - Turnuva başlamadan tahmin yapabilme
  - `tournaments/{id}/predictions/{uid}.winner` 
  - Doğru tahmin → "Kahin" rozeti

---

## FAZ 6 — WRAPPED GENİŞLETME (Hafta 20-22)
> **Hedef:** Viral paylaşım

### Prompt W1 — Wrapped 2.0
```
Öncelik: ORTA
Tahmini süre: 4-5 gün
```

**İçerik:**
- Mevcut `tournament_wrapped_screen.dart` büyük revizyon:
  - Slayt 1: Şampiyon (mevcut + confetti iyileştirmesi)
  - Slayt 2: Gol Krallığı (mevcut)
  - Slayt 3: **MVP Ödülü** (yeni)
  - Slayt 4: En Dramatik Maç (mevcut)
  - Slayt 5: **ELO Değişimleri** (yeni - kim en çok kazandı/kaybetti)
  - Slayt 6: Demir Duvar (mevcut)
  - Slayt 7: **Turnuva Zaman Çizelgesi** (yeni - kaç gün sürdü, hangi gün kaç maç)
  - Slayt 8: Özet İstatistikler (mevcut + genişlet)
- Her slayta paylaşım butonu
- "Tüm Wrapped'ı Paylaş" → animasyonlu video/GIF (Reel-style)

---

## FAZ 7 — MONETİZASYON (Hafta 22-28)
> **Hedef:** Gelir kanalları

### Prompt M1 — Freemium + Premium Altyapısı
```
Öncelik: YÜKSEK
Tahmini süre: 5-6 gün
```

**İçerik:**
- `RevenueCat` paketi ekle (iOS + Android IAP soyutlaması)
- `users/{uid}.isPremium: bool` alanı
- Remote Config ile premium sınırlar:
  - Ücretsiz: 3 aktif turnuva, temel istatistik
  - Premium: Sınırsız turnuva, tüm istatistikler, özel tema, ELO geçmişi, reklamsız
- `premium_paywall_screen.dart` oluştur
- Premium kontrolü gereken yerlere gate ekle
- Competra Pro: ₺49.99/ay veya ₺299.99/yıl

### Prompt M2 — Özel Tema + Kozmetik
```
Öncelik: ORTA
Tahmini süre: 4-5 gün
```

**İçerik:**
- Tema paketi sistemi:
  - "Field & Glory" (mevcut, varsayılan)
  - "Night Arena" (mor/siyah)
  - "Gold Trophy" (altın/koyu)
  - "Ocean League" (mavi/yeşil)
- `users/{uid}.activeTheme` alanı
- Tema önizleme ekranı
- Premium için özel temalar kilidi
- Avatar çerçeveleri (rozet kazanımı ile açılır)
- IAP: tema paketi ₺29.99 tek seferlik

### Prompt M3 — AdMob Entegrasyonu
```
Öncelik: ORTA
Tahmini süre: 3-4 gün
```

**İçerik:**
- `google_mobile_ads` paketi ekle
- Ödüllü reklam: çark çevirme (günde 3 ücretsiz, sonrası reklam izle)
- Banner reklam: turnuva listesi sayfasında (premium kullanıcılarda yok)
- Geçiş reklamı: turnuva tamamlanınca (wrapped öncesi, premium yoksa)
- GDPR uyumlu UMP (User Messaging Platform) entegrasyonu

---

## FAZ 8 — İ18N TAM GEÇİŞ (Hafta 28-30)
> **Hedef:** Uluslararası pazar

### Prompt I1 — i18n Tam Migrasyon
```
Öncelik: YÜKSEK
Tahmini süre: 5-7 gün
```

**İçerik:**
- Tüm Türkçe hard-coded string'leri `AppLocalizations`'a taşı
- `app_tr.arb` ve `app_en.arb` dosyalarını tamamla (tüm string'ler)
- `app_es.arb` (İspanyolca - Latam potansiyeli)
- Dil seçimi: settings_screen'e dil tercihi ekle
- `users/{uid}.language` Firestore'a kaydet
- Tarih/saat formatları locale'e göre
- RTL dil desteği altyapısı (ilerisi için)

---

## FAZ 9 — OFFLİNE MOD + WEB (Hafta 30-36)
> **Hedef:** Her koşulda çalışan uygulama

### Prompt O1 — Offline Mod
```
Öncelik: ORTA
Tahmini süre: 4-5 gün
```

**İçerik:**
- Firestore offline persistence'ı optimize et (cache size ayarı)
- Offline skor girişi:
  - İnternet yokken skor girince local'e kaydet
  - İnternet gelince otomatik sync
  - `pending_scores` Hive/SQLite local store
- Offline banner: "Çevrimdışı - veriler kaydedilecek"
- Conflict resolution: sunucu kazanır (last-write-wins)
- `connectivity_plus` paketi ile bağlantı takibi

### Prompt O2 — Turnuva Bracket Görseli
```
Öncelik: ORTA
Tahmini süre: 5-7 gün
```

**İçerik:**
- Özel `BracketPainter` (CustomPainter):
  - Eleme turnuvası için bracket ağacı
  - Her maç: iki oyuncu + skor
  - Tamamlanan maçlar vurgulanmış
  - Kazanan sola ilerliyor
- `tournament_detail_screen`'e "Bracket" sekmesi ekle
- Bracket'ı paylaşılabilir görsel olarak export et

### Prompt O3 — Web Versiyonu
```
Öncelik: DÜŞÜK
Tahmini süre: 10-15 gün
```

**İçerik:**
- `flutter build web` optimize et
- Firebase Hosting deploy
- Responsive layout (desktop, tablet, mobile)
- Web: turnuva izleme/takip odaklı
- SEO: turnuva public sayfaları
- Landing page: `competra.app`
- PWA desteği

---

## 📋 PROMPT ÖZET LİSTESİ (Sıralı)

| Sıra | Prompt | Faz | Tahmini Süre | Öncelik |
|---|---|---|---|---|
| 1 | G1 — Güvenlik Kuralları + Keystore | 0 | 2-3 gün | 🔴 KRİTİK |
| 2 | G2 — Hata Yönetimi + Bildirim Akışı | 0 | 2-3 gün | 🔴 KRİTİK |
| 3 | K1 — Sabitler + Ölü Kod | 1 | 2-3 gün | 🟠 YÜKSEK |
| 4 | K2 — Ortak UI + Detail Bölme | 1 | 3-4 gün | 🟠 YÜKSEK |
| 5 | K3 — CI/CD + Emulator | 1 | 2-3 gün | 🟠 YÜKSEK |
| 6 | K4 — Temel Unit Testler | 1 | 4-5 gün | 🔴 KRİTİK |
| 7 | P1 — Pagination + Query Optimizasyon | 2 | 3-4 gün | 🟠 YÜKSEK |
| 8 | P2 — Analytics + App Check + Perf | 2 | 2-3 gün | 🟠 YÜKSEK |
| 9 | Y1 — Pull-to-Refresh + Haptic + Confetti + QR | 3 | 3-4 gün | 🟡 ORTA |
| 10 | Y2 — Profil Kırpma + Oyuncu Profil Ziyareti | 3 | 3-4 gün | 🟡 ORTA |
| 11 | Y3 — Turnuva Düzenleme + Katılımcı Çıkarma + Şablonlar | 3 | 3-4 gün | 🟡 ORTA |
| 12 | Y4 — Push Tercihleri + Onboarding İyileştirme | 3 | 2-3 gün | 🟡 ORTA |
| 13 | B1 — Head-to-Head + İstatistik Dashboard | 4 | 4-5 gün | 🟠 YÜKSEK |
| 14 | B2 — ELO / MMR Derecelendirme | 4 | 4-5 gün | 🟠 YÜKSEK |
| 15 | B3 — Arkadaş Aktivite Feed'i | 4 | 4-5 gün | 🟡 ORTA |
| 16 | B4 — Başarım Vitrini + Paylaşılabilir Kart | 4 | 3-4 gün | 🟡 ORTA |
| 17 | B5 — Çoklu Admin + Takım Havuzu | 4 | 4-5 gün | 🟡 ORTA |
| 18 | S1 — Sezon Altyapısı | 5 | 5-6 gün | 🟡 ORTA |
| 19 | S2 — Grup Sezonları + Global Sezonluk Lig | 5 | 4-5 gün | 🟡 ORTA |
| 20 | S3 — MVP Ödülü + Kazanan Tahmini | 5 | 4-5 gün | 🟢 DÜŞÜK |
| 21 | W1 — Wrapped 2.0 | 6 | 4-5 gün | 🟡 ORTA |
| 22 | M1 — Freemium + Premium Altyapısı | 7 | 5-6 gün | 🟠 YÜKSEK |
| 23 | M2 — Özel Tema + Kozmetik | 7 | 4-5 gün | 🟡 ORTA |
| 24 | M3 — AdMob Entegrasyonu | 7 | 3-4 gün | 🟡 ORTA |
| 25 | I1 — i18n Tam Migrasyon | 8 | 5-7 gün | 🟠 YÜKSEK |
| 26 | O1 — Offline Mod | 9 | 4-5 gün | 🟡 ORTA |
| 27 | O2 — Turnuva Bracket Görseli | 9 | 5-7 gün | 🟡 ORTA |
| 28 | O3 — Web Versiyonu | 9 | 10-15 gün | 🟢 DÜŞÜK |

**Toplam tahmini süre:** ~110-140 gün (22-28 hafta)

---

## 🎯 10/10 HEDEF PUANLAMA

| Modül | Mevcut | Faz 0-1 sonrası | Faz 2-4 sonrası | Faz 5-9 sonrası (10/10 hedef) |
|---|---|---|---|---|
| UI/UX | 8.2 | 8.5 | 9.0 | **10/10** |
| Backend | 7.2 | 8.0 | 9.0 | **10/10** |
| Güvenlik | 6.0 | 8.5 | 9.5 | **10/10** |
| Performans | 6.0 | 7.5 | 9.0 | **10/10** |
| Kod Kalitesi | 7.3 | 8.5 | 9.0 | **10/10** |
| Test Coverage | 1.5 | 5.0 | 7.0 | **10/10** |
| DevOps | 3.3 | 7.0 | 8.5 | **10/10** |
| Ölçeklenebilirlik | 5.7 | 7.0 | 8.5 | **10/10** |
| Kullanıcı Deneyimi | 7.3 | 8.0 | 9.0 | **10/10** |

---

## 🚀 ŞİMDİ BAŞLAYALIM

**İlk prompt:** G1 — Güvenlik Kuralları + Keystore

Hazır olduğunda söyle, promptu detaylıca yazayım.

---

*Rapor sonu — COMPETRA_MASTER_ROADMAP.md*
