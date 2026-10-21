import { cacheGet, cacheSet } from './cache.js';
import { BROWSER_UA, getJson, getText, request, sleep } from './net.js';

// Bu anahtarlar uygulamada zaten istemci kodundaydı; burada merkezîleştiriyoruz.
// İstersen .env üzerinden değiştir.
const DEFAULT_RAPID_KEYS = [
  'adc4b7af04mshadb5aab86d5eff7p1946e8jsn61fbc4deba81',
  'f890c11bc2msh5d052433c7ad0d5p15925djsn5a5f8b7a00a3',
  '550292b6c2msh6f03553b10bc495p15d293jsn1a8ef5f8e47f',
];

const RAPID_KEYS = (process.env.RAPIDAPI_KEYS || DEFAULT_RAPID_KEYS.join(','))
  .split(',')
  .map((key) => key.trim())
  .filter(Boolean);
const RAPID_HOST = process.env.RAPIDAPI_HOST || 'youtube-mp36.p.rapidapi.com';
const MP3_API_KEY = process.env.MP3_API_KEY || 'sk-24354e1074e69575b4f39796';
const MP3_API_BASE = (process.env.MP3_API_BASE || 'https://mp3-apisi.onrender.com').replace(/\/$/, '');

const INVIDIOUS_INSTANCES = [
  'https://invidious.f5.si',
  'https://invidious.protokolla.fi',
  'https://iv.melmac.space',
];

let keyCursor = 0;

function formatDuration(seconds) {
  if (!Number.isFinite(seconds) || seconds <= 0) return '0:00';
  const m = Math.floor(seconds / 60);
  const s = Math.floor(seconds % 60);
  return `${m}:${String(s).padStart(2, '0')}`;
}

function rapidHeaders(key) {
  return {
    'x-rapidapi-key': key,
    'x-rapidapi-host': RAPID_HOST,
    Accept: 'application/json',
  };
}

async function rapidLookup(videoId, key) {
  const url = `https://${RAPID_HOST}/dl?id=${encodeURIComponent(videoId)}`;
  const res = await request(url, { headers: rapidHeaders(key), timeout: 12_000 });
  if (res.status === 429 || res.status === 403 || res.status === 401) return { limited: true };
  if (!res.ok) return null;
  const data = await res.json();
  if (data?.status === 'ok' && data.link) {
    const durationSeconds = Number(data.duration) || 0;
    return { url: String(data.link), durationSeconds, dur: formatDuration(durationSeconds) };
  }
  if (data?.status === 'processing') {
    for (let i = 0; i < 4; i++) {
      await sleep(2500);
      const retry = await request(url, { headers: rapidHeaders(key), timeout: 12_000 });
      if (!retry.ok) continue;
      const retryData = await retry.json();
      if (retryData?.status === 'ok' && retryData.link) {
        const durationSeconds = Number(retryData.duration) || 0;
        return {
          url: String(retryData.link),
          durationSeconds,
          dur: formatDuration(durationSeconds),
        };
      }
    }
  }
  return null;
}

async function resolveWithRapid(videoId) {
  if (!videoId || !RAPID_KEYS.length) return null;
  for (let attempt = 0; attempt < RAPID_KEYS.length; attempt++) {
    const index = (keyCursor + attempt) % RAPID_KEYS.length;
    try {
      const result = await rapidLookup(videoId, RAPID_KEYS[index]);
      if (result?.limited) {
        keyCursor = (keyCursor + 1) % RAPID_KEYS.length;
        continue;
      }
      if (result?.url) return { ...result, source: 'rapidapi' };
    } catch (error) {
      console.warn('[audio] rapidapi hatası:', error.message);
    }
  }
  return null;
}

async function resolveWithMp3Api(artist, title) {
  const query = [artist, title].filter(Boolean).join(' ').trim();
  if (!query) return null;

  try {
    const startUrl =
      `${MP3_API_BASE}/api/v1/instant?` +
      new URLSearchParams({ q: query, key: MP3_API_KEY, kalite: '320' });
    const start = await getJson(startUrl, { timeout: 20_000 });
    if (!start?.ok || !start.job_id) return null;

    const jobId = String(start.job_id);
    for (let i = 0; i < 35; i++) {
      await sleep(1000);
      const statusUrl = `${MP3_API_BASE}/api/v1/status/${encodeURIComponent(jobId)}?` +
        new URLSearchParams({ key: MP3_API_KEY });
      const status = await getJson(statusUrl, { timeout: 8000 }).catch(() => null);
      if (!status) continue;

      const state = String(status.durum || '');
      if (state === 'hata') return null;
      if (state !== 'bitti') continue;

      const fileUrl = String(status.dosya_url || '');
      if (!fileUrl) return null;
      const fileName = fileUrl.split('/').pop();
      const url = new URL(`${MP3_API_BASE}/api/v1/file/${encodeURIComponent(fileName)}`);
      url.searchParams.set('key', MP3_API_KEY);

      const durationSeconds =
        Number(status.sure) || Number(status.duration) || Number(status.saniye) || 0;
      return {
        url: url.toString(),
        durationSeconds,
        dur: formatDuration(durationSeconds),
        source: 'mp3-apisi',
      };
    }
  } catch (error) {
    console.warn('[audio] mp3-apisi hatası:', error.message);
  }
  return null;
}

/** videoId yoksa YouTube'da arar (Invidious + HTML yedeği). */
export async function findVideoId(query) {
  if (!query) return null;
  const cacheKey = `videoId:${query.toLowerCase()}`;
  const cached = cacheGet(cacheKey);
  if (cached !== undefined) return cached;

  for (const instance of INVIDIOUS_INSTANCES) {
    try {
      const url = `${instance}/api/v1/search?` +
        new URLSearchParams({ q: query, type: 'video' });
      const data = await getJson(url, { timeout: 4500 });
      const id = Array.isArray(data) ? data.find((item) => item?.videoId)?.videoId : null;
      if (id) {
        cacheSet(cacheKey, id, 24 * 60 * 60 * 1000);
        return id;
      }
    } catch {
      // sıradaki instance
    }
  }

  try {
    const html = await getText(
      `https://www.youtube.com/results?search_query=${encodeURIComponent(query)}`,
      { timeout: 7000, headers: { 'Accept-Language': 'tr,en;q=0.8', 'User-Agent': BROWSER_UA } },
    );
    const match = html.match(/"videoId":"([a-zA-Z0-9_-]{11})"/);
    if (match) {
      cacheSet(cacheKey, match[1], 24 * 60 * 60 * 1000);
      return match[1];
    }
  } catch {
    // YouTube engelledi
  }

  cacheSet(cacheKey, null, 30 * 60 * 1000);
  return null;
}

/**
 * Şarkı için doğrudan MP3 linki.
 * Sıra: RapidAPI → mp3-apisi → (videoId'li ise tekrar RapidAPI)
 */
export async function resolveAudio({ videoId, artist, title }) {
  const query = [artist, title].filter(Boolean).join(' ').trim();
  const cacheKey = `audio:${videoId || query.toLowerCase()}`;
  const cached = cacheGet(cacheKey);
  if (cached !== undefined) return cached;

  let resolvedVideoId = videoId || null;
  if (!resolvedVideoId && query) {
    resolvedVideoId = await findVideoId(query);
  }

  let result = await resolveWithRapid(resolvedVideoId);
  if (!result) result = await resolveWithMp3Api(artist, title);

  if (!result) {
    cacheSet(cacheKey, null, 60 * 1000);
    return null;
  }

  const payload = {
    ok: true,
    videoId: resolvedVideoId,
    durationSeconds: result.durationSeconds || 0,
    dur: result.dur,
    source: result.source,
    url: result.url,
  };
  cacheSet(cacheKey, payload, 2 * 60 * 60 * 1000);
  return payload;
}
