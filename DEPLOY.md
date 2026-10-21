# Kalan 2 adım (toplam ~3 dakika)

Kod tarafı bitti ve `main`'e girdi. Aşağıdaki iki işi **GitHub/Render arayüzünden
elle** yapmak gerekiyor; ikisi de bir kez yapılır.

---

## 1) Sunucuyu Render'a kur (2 dk)

Tek tıkla blueprint:

**https://render.com/deploy?repo=https://github.com/kcbyk/molly**

- Render hesabına giriş yap, depoyu yetkilendir.
- Blueprint depodaki `render.yaml`'ı okur: servis adı `molly-api`,
  kök klasör `server`, başlatma `npm start`, sağlık kontrolü `/api/health`.
- Sorduğu ortam değişkenleri:

| Değişken | Değer |
| --- | --- |
| `SPOTIFY_CLIENT_ID` | Spotify Developer Dashboard → uygulaman → Client ID |
| `SPOTIFY_CLIENT_SECRET` | aynı yer → Client secret |
| `SPOTIFY_SP_DC` | *(opsiyonel)* open.spotify.com → DevTools → Application → Cookies → `sp_dc` |
| `SPOTIFY_REFRESH_TOKEN` | *(opsiyonel)* `AQ…` ile başlayan token |
| `RAPIDAPI_KEYS` | *(boş bırakılabilir — uygulamadaki 3 anahtar kullanılır)* |

- **Deploy** de. Bitince servis adresi `https://molly-api-xxxx.onrender.com`
  şeklinde olur. Kontrol: `<adres>/api/health` → `{"ok":true,...}`
- Adresi bir yere not et; aşağıdaki APK derlemesinde kullanacaksın.

> `render.yaml` şablonunda link yoksa: Render paneli → **New → Blueprint** →
> `kcbyk/molly` seç. Aynı şey.

---

## 2) APK'yı üret (1 dk)

İki dosya `.github/workflows/` altına eklenecek. GitHub bağlantısı `workflows`
yetkisi olmadan yazamadığı için bu adım elle:

1. **https://github.com/kcbyk/molly/new/main?filename=.github/workflows/build-apk.yml**
2. Bu depodaki `ci/build-apk.yml` dosyasının **tüm içeriğini** kopyalayıp yapıştır.
3. **Commit changes**.
4. Aynısını `deploy-render.yml` için yap (opsiyonel; Render'ı otomatik güncellemek
   istersen gerekli):
   **https://github.com/kcbyk/molly/new/main?filename=.github/workflows/deploy-render.yml**

Sonra:

5. **https://github.com/kcbyk/molly/settings/variables/actions** →
   **New repository variable** → ad `API_BASE`, değer: 1. adımdaki Render adresi.
   *(Bu olmadan APK `localhost:3000`'e bakar ve telefonda ağa çıkamaz.)*
6. **https://github.com/kcbyk/molly/actions/workflows/build-apk.yml** →
   **Run workflow** → **Run workflow**.
7. ~8 dakika sonra o çalıştırmanın sayfasında **Artifacts → molly-apk** →
   `Molly-1.0.0-arm64-v8a.apk` indir. Modern telefonlar için bu yeterli;
   her cihazda çalışan tek dosya istersen `Molly-1.0.0-universal.apk`.

---

## Alternatif: telefondan hızlı kurulum

APK'yı telefona kopyala → **Ayarlar → Güvenlik → Bilinmeyen kaynaklar**'ı aç →
dosyaya dokun → kur. İlk açılışta internet izni istenirse onayla.

## Sorun çıkarsa

| Belirti | Çözüm |
| --- | --- |
| Uygulama açılıyor ama şarkı gelmiyor | `API_BASE` yanlış ya da Render uyuyor (ücretsiz plan 15 dk sonra uyur, ilk istek 30-60 sn) |
| Canvas yok, kapak var | `SPOTIFY_SP_DC` eklenmemiş → normal, canvas Spotify çerezine bağlı |
| APK derlemesi patlıyor | Actions logundaki ilk kırmızı satır; `flutter analyze` uyarıları bilgilendirici, hata değil |
| `server` klasörü main'de eskisi gibi görünüyor | Önbellek; birkaç dakika bekle veya sayfayı yenile |
