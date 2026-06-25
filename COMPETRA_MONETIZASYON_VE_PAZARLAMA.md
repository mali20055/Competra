# COMPETRA — Monetizasyon ve Pazarlama Kararları
> **Tarih:** Haziran 2026  
> **Durum:** Karar verildi, uygulanmayı bekliyor

---

## 1. ÜRÜN POZİSYONU (Ne Değiliz, Ne Olacağız)

### Şu An Neyiz?
Küçük arkadaş gruplarının (internet kafeleri, halı sahalar, oyun grupları) kendi aralarında turnuva organize etmesini kolaylaştıran **mobil öncelikli Türkçe uygulama**.

### Ne Değiliz?
- Challonge, Toornament, Start.gg gibi global/kurumsal turnuva platformu DEĞİLİZ
- Birbirini tanımayan insanların global turnuvalar yaptığı platform DEĞİLİZ (henüz)
- Büyük e-spor organizasyonları için DEĞİLİZ

### İleride Ne Olabiliriz?
Uygulama olgunlaştıkça birbirini tanımayan insanların global turnuvalar yapabileceği platforma evrilebilir. Bu durumda kayıt ücreti komisyonu gibi modeller de gündeme gelebilir. **Ama bu şu an için değil.**

---

## 2. MONETİZASYON STRATEJİSİ

### ⏰ Faz 1 — İlk 6 Ay (Büyüme Öncelikli)
**Hiçbir monetizasyon yok.**

Sebep: Uygulama yeni, kullanıcı tabanı yok. Önce insanların alışması, sevmesi, arkadaşlarına önermesi lazım. Para kazanmaya çalışmak bu aşamada kullanıcı kaybettirir.

---

### 💰 Faz 2 — 6-12 Ay (İlk Gelir)

#### A) Ödüllü Reklam (AdMob Rewarded Video)
**KARAR: Evet, sadece ödüllü format.**

Nasıl çalışacak:
- **Çark hakkı:** Günde 3 ücretsiz çevirme. Daha fazlası için 30 sn reklam izle.
- **Ekstra turnuva slotu:** 3'ten fazla aktif turnuva açmak için reklam izle.
- **Detaylı istatistik:** H2H geçmişi veya detaylı grafik için reklam izle (ileride).

**Neden sadece ödüllü?**
- Kullanıcı gönüllü izler, rahatsız etmez
- %90+ tamamlanma oranı (zorunlu reklamda %30-40)
- Arkadaş grubu uygulamasında banner/geçiş reklamı deneyimi bozar

**Banner ve geçiş reklamı KULLANILMAYACAK.**

#### Türkiye için Gerçekçi AdMob Gelir Tahmini

| Kullanıcı (DAU) | Tahmini Aylık Gelir |
|---|---|
| 1.000 | ₺1.000-2.000 |
| 5.000 | ₺4.000-8.000 |
| 10.000 | ₺8.000-15.000 |

*Not: Türkiye Tier 2 ülke — eCPM $3-8 arası (ödüllü video). ABD/AB gibi Tier 1 ülkeler 3-4x daha yüksek gelir üretiyor.*

---

### 🎨 Faz 3 — 12-18 Ay (Kozmetik IAP)

#### B) Kozmetik In-App Purchase
**KARAR: Evet, oyun dengesini etkilemeyen kozmetikler.**

**Ne satılacak:**
- Profil çerçeveleri (şampiyon alev, altın yıldız, gümüş kupa vb.)
- Turnuva temaları (özel renk + ikon seti)
- Özel rozet renk paketleri
- Şampiyonluk konfeti animasyonları (wrapped ekranında)

**Ne SATILMAYACAK:**
- Oyuna avantaj sağlayan hiçbir şey
- İstatistik manipülasyonu
- Ekstra rozet/unvan (bunlar kazanılır)

**Fiyat aralığı:**
- Tek kozmetik: ₺14.99
- Küçük paket (3 kozmetik): ₺34.99
- Büyük paket (5 kozmetik): ₺49.99
- Yıllık "Şampiyon Paketi": ₺99.99

**Teknik altyapı:** RevenueCat (iOS+Android IAP yönetimi)

---

### 🏆 Faz 4 — 18+ Ay (Freemium Pro)

#### C) Competra Pro Abonelik
**KARAR: Evet, ama ücretsiz kullanıcıya çok geniş hak ver.**

**Ücretsiz kullanıcı hakları (geniş tutulacak):**
- Sınırsız turnuva oluşturma (başlangıçta sınır yok)
- Temel istatistikler
- Tüm turnuva formatları
- Arkadaş özellikleri
- 1 varsayılan tema

**Competra Pro (₺49/ay veya ₺299/yıl):**
- Reklamsız deneyim (ödüllü reklamları da kapatır)
- Gelişmiş istatistikler + ELO geçmişi
- Tüm kozmetikler dahil
- Özel temalar
- Öncelikli destek

> **Not:** Freemium sınırları ASLA kullanıcıyı zorlaştıracak şekilde olmayacak.
> Kullanıcı uygulamayı ücretsiz rahatça kullanabilmeli.
> Pro sadece "daha fazlası" için.

---

### ❌ Şu An İçin Reddedilen Modeller

| Model | Neden Reddedildi |
|---|---|
| Kayıt ücreti komisyonu | Tanıdık arkadaşlar niye para ödesin? Mantıksız. Global platforma evrilince değerlendirilebilir. |
| Banner/geçiş reklamı | Kullanıcı deneyimini bozar, geliri düşük |
| B2B kafe/kulüp paketi | Uygulama henüz tanınmıyor. İleride değerlendirilebilir. |
| Sponsor turnuvalar | Henüz kitle yok. İleride değerlendirilebilir. |

---

## 3. PAZARLAMA STRATEJİSİ

### Hedef Kitle
- **Birincil:** 16-28 yaş, Türkiye'de arkadaşlarıyla PlayStation/PC/FIFA oynayan gruplar
- **İkincil:** Halı saha grupları, masa oyunu grupları, okul/üniversite grupları
- **B2B (ileride):** Kafe sahipleri, kulüp organizatörleri

---

### Ana Büyüme Motoru: Viral Döngü

Her turnuva daveti → yeni kullanıcı getiriyor.
Bu zaten uygulamanın içinde var. Bunu besle:

**"Arkadaşını davet et, ikiniz de 1 ay Pro kazan"** kampanyası
(Pro aktif olduğunda)

---

### Sosyal Medya Kanalları

| Platform | İçerik Türü | Öncelik |
|---|---|---|
| **TikTok/Instagram Reels** | Turnuva wrapped videoları, çark çevirme, şampiyonluk anları | 🔴 En yüksek |
| **WhatsApp** | Davet linkleri zaten buradan gidiyor | 🔴 En yüksek |
| **Instagram** | Kullanıcı wrapped paylaşımlarını repost et | 🟠 Yüksek |
| **YouTube** | "Competra ile turnuva kur" tutorial | 🟡 Orta |
| **Twitter/X** | Gaming topluluğu | 🟢 Düşük |

---

### İçerik Stratejisi

**Ne paylaşılacak:**
- Gerçek kullanıcıların wrapped ekran görüntüleri/videoları
- "60 saniyede turnuva kur" kısa video
- Çark çevirme anı videoları
- Şampiyonluk kutlama anları (confetti)

**Ne paylaşılmayacak:**
- Özellik listesi ("10 özelliğimiz var")
- Teknik içerik
- Sürekli promosyon içeriği

> **Kural:** İçerik uygulamanın kendisini değil, **kullanıcı deneyimini** anlatmalı.
> "Bu uygulamayla ne yaşıyorum?" sorusuna cevap ver.

---

### ASO (App Store Optimizasyonu)

**Uygulama başlığı:** "Competra - Turnuva & Lig Yöneticisi"

**Anahtar kelimeler:**
- turnuva oluştur
- fifa turnuva
- arkadaş ligi
- fikstür
- puan tablosu
- halı saha ligi
- playstation turnuva

**İlk ekran görüntüsü:** Wrapped ekranı veya şampiyonluk anı
(Özellik değil, duygu sat)

**Kısa açıklama:** "Arkadaşlarınla turnuva kur, skor gir, şampiyon ol!"

---

### Influencer / İçerik Üretici İş Birlikleri

**Hedef:** 10K-100K takipçili mikro influencer'lar (mega influencer değil)
- Gaming YouTube/TikTok içerik üreticileri
- FIFA/eFootball içerik üreticileri
- Halı saha vlog'cıları

**Model:** Ücretsiz Pro hesap + affiliate link
(Para ödemeden önce organik büyüme hedefle)

---

### Topluluk Büyütme

- Discord sunucusu kur (Competra kullanıcıları için)
- "Competra Kullanıcıları" WhatsApp/Telegram grubu
- Reddit Türkiye gaming subredditlerinde paylaşım

---

## 4. GELİR YOLU ÖZETİ

```
Şimdi        →  Büyü, para kazanma
6. ay        →  Ödüllü reklam (çark/slot için)
12. ay       →  Kozmetik IAP başlat
18. ay       →  Competra Pro abonelik
İleride      →  B2B kafe paketi, global turnuva modeli
```

---

## 5. TEMEL İLKELER

1. **Önce kullanıcı deneyimi, sonra para.** Agresif monetizasyon kullanıcı kaçırır.
2. **Ücretsiz kullanıcı da tam kullanıcı.** Uygulama ücretsiz rahatça kullanılabilmeli.
3. **Reklam gönüllü olmalı.** Ödüllü video dışında reklam yok.
4. **Kozmetik adaletli.** Para verenler avantaj almaz, sadece güzel görünür.
5. **Viral büyüme organik.** Her wrapped paylaşımı ücretsiz reklam.
6. **Türkiye önce, global sonra.** Önce Türkiye'de güçlen, sonra genişle.

---

*Son güncelleme: Haziran 2026*
