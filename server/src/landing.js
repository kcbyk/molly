function badge(ok, text) {
  const color = ok ? '#B8F34B' : '#FF6B8A';
  return `<span class="badge" style="color:${color};border-color:${color}33;background:${color}14">${text}</span>`;
}

export function renderLanding(features = {}) {
  const spotify = Boolean(features.spotifySearch);
  const canvas = features.canvas === 'full';
  const rows = [
    ['GET /api/health', 'Sunucu durumu ve özellik bayrakları'],
    ['GET /api/search?q=...', 'Spotify (varsa) → iTunes arama, kapak + süre'],
    ['GET /api/canvas?trackId=... | ?query=...', 'Spotify Canvas MP4 adresi + 640px kapak'],
    ['POST /api/canvas/batch', 'Liste için tek istekte toplu canvas/kapak'],
    ['GET /api/audio?videoId=... | artist=&title=', 'Dinlenebilir MP3 linki (RapidAPI + yedek)'],
  ];

  return `<!doctype html>
<html lang="tr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Molly API</title>
<style>
  :root { color-scheme: dark; }
  * { box-sizing: border-box; }
  body {
    margin: 0; min-height: 100vh; font-family: ui-sans-serif, system-ui, -apple-system, "Segoe UI", Roboto, sans-serif;
    background: radial-gradient(1200px 600px at 20% -10%, #2a2140 0%, #08080c 55%), #08080c; color: #f4f4f6;
    display: flex; align-items: center; justify-content: center; padding: 32px 18px;
  }
  .card { width: min(760px, 100%); background: rgba(255,255,255,.035); border: 1px solid rgba(255,255,255,.09);
    border-radius: 28px; padding: 30px; box-shadow: 0 30px 80px rgba(0,0,0,.5); }
  .dot { display:inline-block; width:9px; height:9px; border-radius:50%; background:#B8F34B; margin-right:8px;
    box-shadow: 0 0 14px #B8F34B; }
  h1 { margin: 0 0 6px; font-size: 30px; letter-spacing: -0.8px; }
  p { color: #9a9aa8; line-height: 1.6; margin: 8px 0; font-size: 14px; }
  .badges { display: flex; flex-wrap: wrap; gap: 8px; margin: 18px 0 22px; }
  .badge { font-size: 11px; font-weight: 700; padding: 5px 10px; border: 1px solid; border-radius: 999px; }
  table { width: 100%; border-collapse: collapse; font-size: 13px; }
  td { padding: 11px 4px; border-bottom: 1px solid rgba(255,255,255,.07); vertical-align: top; }
  td:first-child { font-family: ui-monospace, SFMono-Regular, Menlo, monospace; color: #d9d9e3; white-space: nowrap; padding-right: 16px; }
  td:last-child { color: #9a9aa8; }
  .hint { margin-top: 22px; padding: 14px 16px; border-radius: 16px; background: rgba(184,243,75,.06);
    border: 1px solid rgba(184,243,75,.16); color: #cfd6bf; font-size: 12.5px; line-height: 1.6; }
  code { background: rgba(255,255,255,.07); padding: 2px 6px; border-radius: 6px; font-size: 12px; }
</style>
</head>
<body>
  <main class="card">
    <h1><span class="dot"></span>Molly API çalışıyor</h1>
    <p>Flutter web derlemesi henüz sunucuda yok. <code>flutter build web</code> çıktısını
      <code>build/web</code> klasörüne koyduğunda uygulama bu adresten servis edilir.</p>

    <div class="badges">
      ${badge(true, 'Sunucu ayakta')}
      ${badge(spotify, spotify ? 'Spotify arama: açık' : 'Spotify arama: iTunes yedeği')}
      ${badge(canvas, canvas ? 'Canvas: sp_dc bağlı' : 'Canvas: çerezsiz / sınırlı')}
      ${badge(true, 'MP3 çözümleme: açık')}
    </div>

    <table>
      ${rows.map(([endpoint, desc]) => `<tr><td>${endpoint}</td><td>${desc}</td></tr>`).join('')}
    </table>

    <div class="hint">
      <strong>İpucu:</strong> Canvas'ın tüm şarkılarda çalışması için <code>server/.env</code> içine
      <code>SPOTIFY_SP_DC</code> ekle. Arama/kapakların Spotify kataloğundan gelmesi için
      <code>SPOTIFY_CLIENT_ID</code> ve <code>SPOTIFY_CLIENT_SECRET</code> yeterli.
      Ayrıntılar: <code>server/README.md</code>
    </div>
  </main>
</body>
</html>`;
}
