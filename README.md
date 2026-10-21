# Molly 🎵

Flutter ile yazılmış, Spotify tarzı koyu temalı müzik oynatıcı.
Web, Android, iOS ve Windows hedeflerini destekler.

## Neler var?

- **Keşfet / Kütüphane / Beğenilen** sekmeleri — artık **sağa/sola kaydırarak**
  da geçilebilir (üstteki arama çubuğu ve alt menü sabit kalır).
- **Spotify Canvas** desteği: şarkı çalarken arka planda döngüde oynayan sessiz
  video (`canvaz.scdn.co`). Canvas yoksa kapaktan üretilen akıllı gradyan.
- Tam ekran oynatıcıda **sağa/sola kaydırma → önceki/sonraki şarkı**.
- Şarkı arama, beğenme, indirme, karıştırma, tekrar, sürüklenebilir ilerleme
  çubuğu, mini oynatıcı, paylaşım menüsü.
- **Molly Sunucusu** ile arama, kapak, canvas ve MP3 çözümleme tek yerde.

## Mimari

```
Flutter uygulaması ──HTTP──> server/ (Node, bağımlılıksız)
   │                          ├── /api/search  → Spotify (varsa) → iTunes
   ├── audioplayers           ├── /api/canvas  → sp_dc + TOTP + protobuf → canvaz.scdn.co
   ├── palette_generator      ├── /api/audio   → RapidAPI → mp3-apisi
   └── flutter_svg            └── statik: build/web (tek servis kurulumu)
```

Sunucu erişilemezse uygulama eskisi gibi **yerel yedeklerle** çalışmaya devam
eder (Invidious arama, RapidAPI, mp3-apisi, hazır kapaklar).

## Hızlı başlangıç

### 1) Sunucu

```bash
cd server
cp .env.example .env      # SPOTIFY_SP_DC / CLIENT_ID-SECRET opsiyonel
npm start                 # http://localhost:3000
```

Detaylar: [`server/README.md`](server/README.md)

### 2) Uygulama

```bash
flutter pub get

# Web (Flutter dev sunucusu farklı portta olduğu için API adresini ver)
flutter run -d chrome --dart-define=API_BASE=http://localhost:3000

# Android / masaüstü: varsayılan zaten http://localhost:3000
flutter run
```

Android **emülatöründe** `localhost` bilgisayarı göstermez:

```bash
flutter run --dart-define=API_BASE=http://10.0.2.2:3000
```

Gerçek cihazda bilgisayarın LAN IP'sini kullan (`http://192.168.x.x:3000`).

### 3) Üretim

```bash
# Web uygulaması (API ayrı bir adreste)
# SUNUCU-ADRESIN yerine kendi dağıtım adresini yaz (ör. Render'da
# https://molly-api-xxxx.onrender.com). Repodaki adres örnek/yer tutucudur.
flutter build web --dart-define=API_BASE=https://SUNUCU-ADRESIN.onrender.com

# ya da tek servis: derleme sunucudan servis edilir
flutter build web && cd server && npm start
```

`API_BASE` verilmezse web'de uygulamanın açıldığı origin, native'de
`http://localhost:3000` kullanılır.

## Neden sunucu?

Tarayıcıdan Spotify'ın canvas/kapak uçlarına doğrudan gitmek CORS ve gizli
anahtar yüzünden çalışmıyordu; eski kod `http://localhost:3000` bekliyordu ama
repoda sunucu yoktu. Ayrıca:

- RapidAPI anahtarları artık istemci paketinde değil, sunucuda.
- Arama için 3 Invidious denemesi (15 sn'ye kadar) yerine tek hızlı istek.
- Tüm şarkıların kapak/canvas'ı **tek toplu istekte** çözülüyor.
- Sonuçlar TTL'li cache'te; aynı şarkı ikinci kez ağa çıkmıyor.

## Performans notları

- Canvas videosu yalnızca oynatıcı açıkken DOM'da; kapanınca tamamen kaldırılıyor
  (önceden kapalıyken bile arka planda oynuyordu).
- Tam ekran oynatıcı ağacı kapalıyken hiç kurulmuyor.
- Kapak renkleri (`PaletteCache`) ana ekran ve oynatıcı arasında paylaşılıyor;
  aynı kapak iki kez analiz edilmiyor.
- Kapaklar ekrandaki boyuta göre decode ediliyor (`cacheWidth`).
- Sayfalar `AutomaticKeepAlive` ile scroll konumunu koruyor.
- `dart:io` bağımlılığı koşullu import'a taşındı → **web derlemesi artık çalışır**.

## Dosya yapısı

```
lib/
├── config/api_config.dart          sunucu adresi + eski API anahtarları (yedek)
├── models/song.dart                Song modeli + hazır liste
├── screens/music_home_screen.dart  sekmeler, PageView swipe, oynatma durumu
├── services/
│   ├── music_api_service.dart      sunucu + yedekler (arama/canvas/MP3)
│   ├── palette_cache.dart          kapak rengi cache'i
│   ├── local_file_store*.dart      platforma göre indirme
│   └── audio_player_service.dart   audioplayers sarmalayıcı
└── widgets/                        oynatıcı, canvas, satırlar, ikonlar
server/                             Node API (detay: server/README.md)
```

## Test

```bash
cd server && npm test
flutter test        # Flutter SDK kurulu ortamda
```

## Lisans notu

Canvas çözümleme Spotify'ın belgelenmemiş uçlarını kullanır. Kod bağımsız
yazıldı; protobuf şeması kamuya açık topluluk kaynaklarından doğrulandı.
Spotify kullanım şartlarına uyum sizin sorumluluğunuzdadır.
