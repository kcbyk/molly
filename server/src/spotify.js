import { cacheGet, cacheSet } from './cache.js';
import { BROWSER_UA, HttpError, getJson, getText, request } from './net.js';
import { decodeCanvasResponse, encodeCanvasRequest } from './protobuf.js';
import { generateTotp, secretKeyFromList } from './totp.js';

const SPOTIFY_API = 'https://api.spotify.com/v1';
const SPOTIFY_ACCOUNTS = 'https://accounts.spotify.com/api/token';
const SECRETS_URL =
  'https://raw.githubusercontent.com/xyloflake/spot-secrets-go/main/secrets/secretDict.json';

const CLIENT_ID = process.env.SPOTIFY_CLIENT_ID || '';
const CLIENT_SECRET = process.env.SPOTIFY_CLIENT_SECRET || '';
const SP_DC = process.env.SPOTIFY_SP_DC || '';
const REFRESH_TOKEN = process.env.SPOTIFY_REFRESH_TOKEN || '';

export const spotifyConfigured = Boolean(CLIENT_ID && CLIENT_SECRET);
export const canvasCookieConfigured = Boolean(SP_DC);
export const spotifyUserConfigured = Boolean(
  CLIENT_ID && CLIENT_SECRET && REFRESH_TOKEN,
);

// ──────────────────────────────────────────────────────────────
//  Resmi Web API (client credentials) — arama + 640px kapak
// ──────────────────────────────────────────────────────────────

async function getClientToken() {
  if (!spotifyConfigured) return null;
  const cached = cacheGet('spotify:cc-token');
  if (cached) return cached;

  const basic = Buffer.from(`${CLIENT_ID}:${CLIENT_SECRET}`).toString('base64');
  try {
    const res = await request(SPOTIFY_ACCOUNTS, {
      method: 'POST',
      headers: {
        Authorization: `Basic ${basic}`,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: 'grant_type=client_credentials',
      timeout: 9000,
    });
    if (!res.ok) {
      console.warn(`[spotify] client token ${res.status}`);
      return null;
    }
    const data = await res.json();
    if (!data.access_token) return null;
    const ttl = Math.max(60_000, (data.expires_in || 3600) * 1000 - 120_000);
    cacheSet('spotify:cc-token', data.access_token, ttl);
    return data.access_token;
  } catch (error) {
    console.warn('[spotify] client token hatası:', error.message);
    return null;
  }
}

/**
 * Refresh token varsa kullanıcı adına access token alır.
 * Client credentials'a göre avantajı: bazı uç noktalar (canvas/Pathfinder)
 * yalnızca kullanıcı tokeniyle yanıt verir. Yoksa null döner.
 */
async function getUserToken() {
  if (!spotifyUserConfigured) return null;
  const cached = cacheGet('spotify:user-token');
  if (cached) return cached;
  const blocked = cacheGet('spotify:user-token-failed');
  if (blocked) return null;

  const basic = Buffer.from(`${CLIENT_ID}:${CLIENT_SECRET}`).toString('base64');
  try {
    const res = await request(SPOTIFY_ACCOUNTS, {
      method: 'POST',
      headers: {
        Authorization: `Basic ${basic}`,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: `grant_type=refresh_token&refresh_token=${encodeURIComponent(REFRESH_TOKEN)}`,
      timeout: 9000,
    });
    if (!res.ok) {
      console.warn(`[spotify] refresh token ${res.status}`);
      // 400/401 = token iptal/yanlış; 5 dk boyunca tekrar denemeyelim.
      if (res.status === 400 || res.status === 401) {
        cacheSet('spotify:user-token-failed', true, 5 * 60 * 1000);
      }
      return null;
    }
    const data = await res.json();
    if (!data.access_token) return null;
    const ttl = Math.max(60_000, (data.expires_in || 3600) * 1000 - 120_000);
    cacheSet('spotify:user-token', data.access_token, ttl);
    return data.access_token;
  } catch (error) {
    console.warn('[spotify] refresh token hatası:', error.message);
    return null;
  }
}

/** Resmi Web API: kullanıcı tokeni varsa o, yoksa client credentials. */
async function getSpotifyToken() {
  return (await getUserToken()) || (await getClientToken());
}

function normalizeTrack(track, { withSpotifyId = true } = {}) {
  if (!track) return null;
  const images = track.album?.images || [];
  const coverUrl = images.find((i) => i.width >= 600)?.url || images[0]?.url || null;
  return {
    id: withSpotifyId ? track.id : `spotify_${track.id}`,
    title: track.name || 'Bilinmeyen Şarkı',
    artist: (track.artists || []).map((a) => a.name).filter(Boolean).join(', ') || 'Bilinmeyen Sanatçı',
    coverUrl,
    durationSeconds: Math.round((track.duration_ms || 0) / 1000) || 0,
    spotifyTrackId: track.id || null,
    source: 'spotify',
    previewUrl: track.preview_url || null,
  };
}

export async function spotifySearch(query, limit = 15) {
  if (!spotifyConfigured) return null;
  const token = await getSpotifyToken();
  if (!token) return null;

  const key = `spotify:search:${query.toLowerCase()}:${limit}`;
  const cached = cacheGet(key);
  if (cached) return cached;

  try {
    const url = `${SPOTIFY_API}/search?type=track&limit=${limit}&market=TR&q=${encodeURIComponent(query)}`;
    const data = await getJson(url, {
      headers: { Authorization: `Bearer ${token}` },
      timeout: 8000,
    });
    const results = (data.tracks?.items || []).map((item) => normalizeTrack(item)).filter(Boolean);
    if (results.length) cacheSet(key, results, 10 * 60 * 1000);
    return results;
  } catch (error) {
    console.warn('[spotify] arama hatası:', error.message);
    return null;
  }
}

export async function spotifyTrack(trackId) {
  if (!spotifyConfigured || !trackId) return null;
  const key = `spotify:track:${trackId}`;
  const cached = cacheGet(key);
  if (cached) return cached;

  const token = await getSpotifyToken();
  if (!token) return null;
  try {
    const data = await getJson(`${SPOTIFY_API}/tracks/${encodeURIComponent(trackId)}?market=TR`, {
      headers: { Authorization: `Bearer ${token}` },
      timeout: 8000,
    });
    const result = normalizeTrack(data);
    if (result) cacheSet(key, result, 6 * 60 * 60 * 1000);
    return result;
  } catch (error) {
    console.warn('[spotify] track hatası:', error.message);
    return null;
  }
}

/** Anahtar gerektirmeyen kapak kaynağı: oEmbed. */
export async function spotifyOembed(trackId) {
  if (!trackId) return null;
  const key = `spotify:oembed:${trackId}`;
  const cached = cacheGet(key);
  if (cached !== undefined) return cached;

  try {
    const pageUrl = `https://open.spotify.com/track/${encodeURIComponent(trackId)}`;
    const data = await getJson(`https://open.spotify.com/oembed?url=${encodeURIComponent(pageUrl)}`, {
      timeout: 7000,
    });
    const result = {
      title: data.title || null,
      coverUrl: data.thumbnail_url || null,
    };
    cacheSet(key, result, 24 * 60 * 60 * 1000);
    return result;
  } catch (error) {
    cacheSet(key, null, 30 * 60 * 1000);
    return null;
  }
}

// ──────────────────────────────────────────────────────────────
//  Canvas — sp_dc çerezi + TOTP + protobuf
// ──────────────────────────────────────────────────────────────

let secretsCache = null; // { version, key, fetchedAt }

async function getTotpSecret() {
  if (secretsCache && Date.now() - secretsCache.fetchedAt < 60 * 60 * 1000) return secretsCache;
  if (cacheGet('canvas:secrets-failed')) return null;

  try {
    const res = await request(SECRETS_URL, { timeout: 8000 });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const dict = await res.json();
    const versions = Object.keys(dict)
      .map((n) => Number(n))
      .filter((n) => Number.isFinite(n));
    if (!versions.length) throw new Error('sözlük boş');
    const version = String(Math.max(...versions));
    const key = secretKeyFromList(dict[version]);
    if (!key) throw new Error('anahtar çözülemedi');
    secretsCache = { version, key, fetchedAt: Date.now() };
    console.log(`[canvas] TOTP sürümü ${version} yüklendi`);
    return secretsCache;
  } catch (error) {
    console.warn('[canvas] TOTP sırları alınamadı:', error.message);
    cacheSet('canvas:secrets-failed', true, 10 * 60 * 1000);
    return null;
  }
}

async function getSpotifyServerTime() {
  const headers = {
    Origin: 'https://open.spotify.com/',
    Referer: 'https://open.spotify.com/',
  };
  if (SP_DC) headers.Cookie = `sp_dc=${SP_DC}`;

  try {
    const res = await request('https://open.spotify.com/api/server-time', {
      headers,
      timeout: 5000,
    });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const data = await res.json();
    const seconds = Number(data.serverTime);
    if (!Number.isFinite(seconds)) throw new Error('geçersiz serverTime');
    return seconds;
  } catch {
    return Date.now() / 1000;
  }
}

async function fetchInternalToken() {
  // Çerez olmadan da anonim token denenebilir; olmazsa 10 dk boyunca
  // tekrar denemeyip doğrudan kapak fotoğrafına düşeriz.
  const blocked = cacheGet('spotify:canvas-token-blocked');
  if (blocked) return null;

  const cached = cacheGet('spotify:canvas-token');
  if (cached) return cached;

  const secrets = await getTotpSecret();
  if (!secrets) return null;

  const serverTimeSeconds = await getSpotifyServerTime();
  const variants = [
    // 1) doğru yaklaşım: sunucu zamanı (ms) ile TOTP
    generateTotp(secrets.key, serverTimeSeconds * 1000),
    // 2) yaygın kullanılan eski yaklaşım (bazı token sürümlerinde çalışıyor)
    generateTotp(secrets.key, Math.floor((serverTimeSeconds * 1000) / 30)),
  ];

  for (const totpServer of variants) {
    const params = new URLSearchParams({
      reason: 'init',
      productType: 'mobile-web-player',
      totp: generateTotp(secrets.key, Date.now()),
      totpVer: secrets.version,
      totpServer,
    });

    try {
      const tokenHeaders = {
        Origin: 'https://open.spotify.com/',
        Referer: 'https://open.spotify.com/',
      };
      if (SP_DC) tokenHeaders.Cookie = `sp_dc=${SP_DC}`;

      const res = await request(`https://open.spotify.com/api/token?${params}`, {
        headers: tokenHeaders,
        timeout: 9000,
      });
      if (!res.ok) {
        console.warn(`[canvas] token ${res.status}`);
        continue;
      }
      const data = await res.json();
      if (!data.accessToken) continue;
      const expiresAt = Number(data.accessTokenExpirationTimestampMs) || Date.now() + 30 * 60 * 1000;
      const ttl = Math.max(60_000, expiresAt - Date.now() - 60_000);
      cacheSet('spotify:canvas-token', data.accessToken, ttl);
      return data.accessToken;
    } catch (error) {
      console.warn('[canvas] token hatası:', error.message);
    }
  }

  cacheSet('spotify:canvas-token-blocked', true, 10 * 60 * 1000);
  return null;
}

/** Internal canvaz-cache endpoint'i — protobuf alışverişi. */
async function fetchCanvasInternal(trackId) {
  const token = await fetchInternalToken();
  if (!token) return null;

  try {
    const body = encodeCanvasRequest(`spotify:track:${trackId}`);
    const res = await request('https://spclient.wg.spotify.com/canvaz-cache/v0/canvases', {
      method: 'POST',
      headers: {
        Accept: 'application/protobuf',
        'Content-Type': 'application/x-www-form-urlencoded',
        'Accept-Language': 'en',
        'User-Agent': 'Spotify/9.0.34.593 iOS/18.4 (iPhone15,3)',
        Authorization: `Bearer ${token}`,
      },
      body,
      timeout: 9000,
    });
    if (!res.ok) {
      console.warn(`[canvas] canvaz-cache ${res.status}`);
      return null;
    }
    const buffer = Buffer.from(await res.arrayBuffer());
    if (!buffer.length) return null;
    const parsed = decodeCanvasResponse(buffer);
    return parsed.canvasesList.length ? parsed.canvasesList : null;
  } catch (error) {
    console.warn('[canvas] protobuf isteği hatası:', error.message);
    return null;
  }
}

/** Çerez gerektirmeyen yedek: public track sayfasını tara. */
async function scrapeCanvas(trackId) {
  try {
    const html = await getText(`https://open.spotify.com/track/${encodeURIComponent(trackId)}`, {
      timeout: 8000,
      headers: SP_DC ? { Cookie: `sp_dc=${SP_DC}` } : {},
    });
    const normalized = html.replace(/\\u002F/gi, '/').replace(/\\\//g, '/');
    const match = normalized.match(/https:\/\/canvaz\.scdn\.co\/[^"'\\\s]+?\.cnvs\.mp4/);
    if (!match) return null;
    return [
      {
        id: match[0].split('/').pop().replace('.cnvs.mp4', ''),
        canvasUrl: match[0],
        trackUri: `spotify:track:${trackId}`,
        artist: null,
      },
    ];
  } catch {
    return null;
  }
}

/**
 * Resmi kullanıcı tokeniyle canvas denemesi.
 * Internal uç nokta gibi her zaman çalışmaz; ilk başarısızlıkta 15 dk susar.
 */
async function canvasViaOfficialToken(trackId) {
  if (!spotifyUserConfigured) return null;
  if (cacheGet('canvas:official-blocked')) return null;

  const token = await getUserToken();
  if (!token) return null;

  try {
    const res = await request(
      'https://spclient.wg.spotify.com/canvaz-cache/v0/canvases?market=from_token',
      {
        method: 'POST',
        headers: {
          Accept: 'application/protobuf',
          'Content-Type': 'application/x-www-form-urlencoded',
          'App-Platform': 'WebPlayer',
          Authorization: `Bearer ${token}`,
        },
        body: encodeCanvasRequest(`spotify:track:${trackId}`),
        timeout: 8000,
      },
    );
    if (!res.ok) {
      cacheSet('canvas:official-blocked', true, 15 * 60 * 1000);
      return null;
    }
    const buffer = Buffer.from(await res.arrayBuffer());
    if (!buffer.length) return null;
    const parsed = decodeCanvasResponse(buffer);
    return parsed.canvasesList.length ? parsed.canvasesList : null;
  } catch {
    cacheSet('canvas:official-blocked', true, 15 * 60 * 1000);
    return null;
  }
}

/** Track için canvas listesi. SP_DC yoksa/başarısızsa null döner. */
export async function spotifyCanvas(trackId) {
  if (!trackId) return null;
  const key = `spotify:canvas:${trackId}`;
  const cached = cacheGet(key);
  if (cached !== undefined) return cached;

  const internal = await fetchCanvasInternal(trackId);
  if (internal) {
    cacheSet(key, internal, 6 * 60 * 60 * 1000);
    return internal;
  }

  const official = await canvasViaOfficialToken(trackId);
  if (official) {
    cacheSet(key, official, 6 * 60 * 60 * 1000);
    return official;
  }

  const scraped = await scrapeCanvas(trackId);
  if (scraped) {
    cacheSet(key, scraped, 2 * 60 * 60 * 1000);
    return scraped;
  }

  // Canvas'ı olmayan şarkılar için 1 saat negatif cache (her seferinde Spotify'ı yormayalım)
  cacheSet(key, null, 60 * 60 * 1000);
  return null;
}

export const spotifyUserAgent = BROWSER_UA;
export const spotifyHttpError = HttpError;
