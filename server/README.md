# Molly Server

Molly uygulamasının **bağımlılıksız** (npm paketi gerektirmeyen) küçük API'si.
Node 18.17+ yeterli; `npm install` bile gerekmez.

```
server/
├── index.js          HTTP sunucusu (CORS + statik + /api)
├── src/
│   ├── env.js        .env okuyucu (bağımlılıksız)
│   ├── api.js        endpoint yönlendirme
│   ├── search.js     Spotify → iTunes arama
│   ├── itunes.js     anahtarsız arama + 600px kapak
│   ├── spotify.js    resmi API + canvas (sp_dc/TOTP/protobuf)
│   ├── canvas.js     canvas + kapak çözümleme, toplu istek
│   ├── audio.js      RapidAPI → mp3-apisi MP3 çözümleme
│   ├── protobuf.js   canvas protobuf encode/decode
│   ├── totp.js       RFC 6238 TOTP
│   ├── cache.js      TTL'li bellek cache
│   ├── net.js        fetch yardımcıları
│   ├── static.js     Flutter web derlemesini servis eder
│   └── landing.js    derleme yokken gösterilen durum sayfası
└── test/             node:test birim testleri
```

## Çalıştırma

```bash
cd server
cp .env.example .env     # istersen doldur
npm start                # http://localhost:3000
```

`npm run dev` → dosya değişince otomatik yeniden başlar.

Kontrol:

```bash
curl http://localhost:3000/api/health
cd server && npm test     # 7 birim testi
```

## Endpoint'ler

| Endpoint | Açıklama |
| --- | --- |
| `GET /api/health` | Durum + özellik bayrakları + cache istatistiği |
| `GET /api/search?q=&limit=` | Şarkı arama (Spotify → iTunes) |
| `GET /api/canvas?trackId=` veya `?query=` | Canvas MP4 + kapak |
| `POST /api/canvas/batch` | `{items:[{id,trackId?,query?,artist?,title?}]}` → tek istekte toplu çözümleme |
| `GET /api/audio?videoId=` veya `artist=&title=` | Dinlenebilir MP3 linki |
| `GET /api/config` | Sürüm + özellikler |

Örnek canvas cevabı (eski `canvasesList` istemcileriyle uyumlu):

```json
{
  "trackId": "3ajYmPDtB3P7JTPQ64Dr7P",
  "coverUrl": "https://i.scdn.co/image/ab67616d0000...",
  "canvasesList": [
    { "canvasUrl": "https://canvaz.scdn.co/upload/...cnvs.mp4", "id": "..." }
  ],
  "data": { "canvasesList": [], "coverUrl": "..." }
}
```

## Ortam değişkenleri

| Değişken | Ne için |
| --- | --- |
| `PORT`, `HOST` | Varsayılan `3000`, `0.0.0.0` |
| `SPOTIFY_CLIENT_ID`, `SPOTIFY_CLIENT_SECRET` | Resmi arama + 640px kapak + canvas için gerçek track id |
| `SPOTIFY_SP_DC` | **Canvas'ın tüm şarkılarda çalışması için** gerekli Spotify çerezi |
| `RAPIDAPI_KEYS` | Virgülle ayrılmış anahtarlar (boşsa uygulamadaki 3 anahtar) |
| `RAPIDAPI_HOST` | Varsayılan `youtube-mp36.p.rapidapi.com` |
| `MP3_API_KEY`, `MP3_API_BASE` | mp3-apisi yedeği |
| `WEB_DIR` | Flutter web derlemesi (varsayılan `../build/web`) |

### `SP_DC` nasıl alınır?

1. Tarayıcıda `open.spotify.com`'a giriş yap.
2. DevTools → Application → Cookies → `open.spotify.com` → `sp_dc`.
3. Değeri `.env` içine yapıştır.

> Canvas, Spotify'ın **özel** uç noktasını kullanır (`spclient.wg.spotify.com`)
> ve süresi dolan TOTP sırlarını GitHub'daki topluluk sözlüğünden yeniler.
> Çerez yoksa veya Spotify akışı değişirse sunucu sessizce kapak fotoğrafına
> düşer; uygulama bozulmaz. Ticari/uzun ömürlü bir garanti değildir.

## Yayınlama

### Render / Railway / Fly.io

- **Root directory:** `server`
- **Build command:** `npm install` (bağımlılık yok, boş geçebilir)
- **Start command:** `npm start`
- Env: en az `SPOTIFY_SP_DC` + `SPOTIFY_CLIENT_ID`/`SECRET` (önerilir)

Flutter web'i ayrı bir statik hostingde yayınlıyorsan derlerken API adresini ver
(`SUNUCU-ADRESIN` yer tutucudur; kendi dağıtım adresini yaz):

```bash
flutter build web --dart-define=API_BASE=https://SUNUCU-ADRESIN.onrender.com
```

Depo kökündeki `render.yaml` Render Blueprint'idir: Render panelinde
**New → Blueprint** deyip depoyu seçmek yeterli. `rootDir: server`,
`start: npm start`, sağlık kontrolü `/api/health`.

> Ücretsiz Render planı 15 dk trafik olmayınca uyur; sonraki ilk istek
> 30-60 sn sürebilir. "Kuş gibi hafif" hedefi için ya ücretli plan ya da
> Railway/Fly.io/VPS gibi uyumayan bir yer önerilir.

### Tek servis (API + web)

```bash
flutter build web
cd server && npm start          # ../build/web otomatik servis edilir
```

Bu durumda Flutter aynı origin'den konuşur; `API_BASE` vermeye gerek yoktur.
Derleme yoksa `/` adresinde Türkçe durum sayfası görünür.

## Notlar

- Cache bellektedir; süreç yeniden başlayınca boşalır (kalıcı DB yok).
- Canvas protokolü tersine mühendisliktir; kod kopyalanmadı, tel formatı
  (protobuf şeması) yeniden uygulandı. Spotify şartlarına uygun kullanım
  sorumluluğu size aittir.
- API'de kimlik doğrulama yok. Herkese açık dağıtıyorsan bir ön proxy ile
  sınırlamak isteyebilirsin.
