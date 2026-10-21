# Otomatik derleme / dağıtım dosyaları

Bu klasördeki iki dosya **GitHub Actions** iş akışıdır. Buradan çalışmazlar;
`.github/workflows/` altına taşınmaları gerekir. (Ajanın GitHub bağlantısı
`workflows` yetkisine sahip olmadığı için doğrudan oraya konulamadı.)

## Kurulum (tek seferlik, ~2 dakika)

1. GitHub'da depoyu aç → **Add file → Upload files**.
2. Bu klasördeki `build-apk.yml` ve `deploy-render.yml` dosyalarını sürükle.
3. Dosya yolunu **`.github/workflows/`** olarak yaz (GitHub yolu korur, gerekirse
   sürüklerken klasör oluştur). Commit'le.
   - Alternatif: her dosya için **Add file → Create new file** → başlığa
     `.github/workflows/build-apk.yml` yaz → içeriği yapıştır.

## Sırlar (Settings → Secrets and variables → Actions)

| Ad | Zorunlu | Nereden |
| --- | --- | --- |
| `RENDER_API_KEY` | Render'a otomatik dağıtım için | Render → Account Settings → API Keys |
| `SPOTIFY_CLIENT_ID` | Arama/kapak için | Spotify Developer Dashboard |
| `SPOTIFY_CLIENT_SECRET` | Arama/kapak için | Spotify Developer Dashboard |
| `SPOTIFY_SP_DC` | Canvas'ın tüm şarkılarda çalışması için | open.spotify.com çerezi |
| `SPOTIFY_REFRESH_TOKEN` | Opsiyonel (alternatif canvas yolu) | OAuth akışı |
| `RAPIDAPI_KEYS` | Opsiyonel | Boşsa uygulamadaki 3 anahtar kullanılır |

## Değişkenler (Variables sekmesi)

| Ad | Örnek | Ne işe yarar |
| --- | --- | --- |
| `API_BASE` | `https://molly-api-xxxx.onrender.com` | APK'nın bağlanacağı sunucu |
| `DEPLOY_BRANCH` | `main` | Render'ın derleyeceği dal |
| `RENDER_PLAN` | `free` | `free`, `starter`… |
| `RENDER_REGION` | `frankfurt` | En yakın bölge |

> `API_BASE` boşsa APK `localhost:3000`'e bakar; telefonda çalışmaz.

## Kullanım

- **APK:** Actions → **APK Üret** → Run workflow. Bitince
  `molly-apk` artifact'ından `Molly-1.0.0-arm64-v8a.apk` indir.
- **Sunucu:** Actions → **Render'a Dağıt** → Run workflow. İlk çalıştırmada
  Render servisi yoksa oluşturulur, env'ler yazılır, dağıtım tetiklenir ve
  adres özet ekranına basılır.
