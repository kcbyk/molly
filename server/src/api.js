import { resolveAudio } from './audio.js';
import { resolveCanvas, resolveCanvasBatch } from './canvas.js';
import { cacheStats } from './cache.js';
import { searchSongs } from './search.js';
import {
  canvasCookieConfigured,
  spotifyConfigured,
  spotifyUserConfigured,
} from './spotify.js';

const STARTED_AT = Date.now();
const VERSION = '1.0.0';
const MAX_BODY = 64 * 1024;

export function featureFlags() {
  return {
    spotifySearch: spotifyConfigured,
    spotifyUserToken: spotifyUserConfigured,
    canvas: canvasCookieConfigured ? 'full' : 'best-effort',
    itunes: true,
    audio: true,
  };
}

function json(res, status, payload) {
  const body = JSON.stringify(payload);
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Content-Length': Buffer.byteLength(body),
    'Cache-Control': 'no-store',
  });
  res.end(body);
}

function text(res, status, message) {
  res.writeHead(status, { 'Content-Type': 'text/plain; charset=utf-8' });
  res.end(message);
}

async function readJsonBody(req) {
  let size = 0;
  const chunks = [];
  for await (const chunk of req) {
    size += chunk.length;
    if (size > MAX_BODY) throw new Error('istek gövdesi çok büyük');
    chunks.push(chunk);
  }
  if (!chunks.length) return {};
  const raw = Buffer.concat(chunks).toString('utf8');
  try {
    return JSON.parse(raw);
  } catch {
    throw new Error('geçersiz JSON');
  }
}

function clean(value, max = 160) {
  return String(value ?? '').trim().slice(0, max);
}

export async function handleApi(req, res, url) {
  const path = url.pathname.replace(/\/+$/, '');

  try {
    if (path === '/api/health') {
      json(res, 200, {
        ok: true,
        service: 'molly-server',
        version: VERSION,
        uptimeSeconds: Math.round((Date.now() - STARTED_AT) / 1000),
        features: featureFlags(),
        cache: cacheStats(),
      });
      return;
    }

    if (path === '/api/search') {
      if (req.method !== 'GET') return text(res, 405, 'GET kullan');
      const query = clean(url.searchParams.get('q'), 120);
      if (!query) return json(res, 400, { error: 'q parametresi gerekli' });
      const limit = Math.min(30, Math.max(1, Number(url.searchParams.get('limit')) || 15));
      const { source, results } = await searchSongs(query, limit);
      json(res, 200, { query, source, results });
      return;
    }

    if (path === '/api/canvas') {
      if (req.method !== 'GET') return text(res, 405, 'GET kullan');
      const trackId = clean(url.searchParams.get('trackId'), 64);
      const query = clean(url.searchParams.get('query'), 160);
      if (!trackId && !query) {
        return json(res, 400, { error: 'trackId veya query parametresi gerekli' });
      }

      const resolved = await resolveCanvas({ trackId, query });
      const body = {
        trackId: resolved?.trackId || null,
        coverUrl: resolved?.coverUrl || null,
        canvasesList: resolved?.canvasesList || [],
        title: resolved?.title || null,
        artist: resolved?.artist || null,
        // Eski Paxsenix istemcileriyle uyumluluk
        data: {
          canvasesList: resolved?.canvasesList || [],
          coverUrl: resolved?.coverUrl || null,
        },
      };
      json(res, 200, body);
      return;
    }

    if (path === '/api/canvas/batch') {
      if (req.method !== 'POST') return text(res, 405, 'POST kullan');
      const body = await readJsonBody(req);
      const items = Array.isArray(body.items) ? body.items.slice(0, 24) : [];
      if (!items.length) return json(res, 400, { error: 'items dizisi gerekli' });

      const normalized = items.map((item, index) => ({
        id: clean(item?.id ?? index, 80),
        trackId: clean(item?.trackId ?? item?.spotifyTrackId, 64) || null,
        query: clean(item?.query, 160) || null,
        artist: clean(item?.artist, 80) || null,
        title: clean(item?.title, 120) || null,
      }));

      const results = await resolveCanvasBatch(normalized);
      json(res, 200, { results });
      return;
    }

    if (path === '/api/audio') {
      if (req.method !== 'GET') return text(res, 405, 'GET kullan');
      const videoId = clean(url.searchParams.get('videoId'), 32);
      const artist = clean(url.searchParams.get('artist'), 100);
      const title = clean(url.searchParams.get('title'), 140);
      if (!videoId && !title) {
        return json(res, 400, { error: 'videoId veya title parametresi gerekli' });
      }

      const result = await resolveAudio({ videoId, artist, title });
      if (!result) {
        json(res, 200, { ok: false, error: 'MP3 bulunamadı' });
        return;
      }
      json(res, 200, result);
      return;
    }

    if (path === '/api/config') {
      json(res, 200, {
        version: VERSION,
        features: featureFlags(),
        searchFallbacks: ['spotify', 'itunes'],
      });
      return;
    }

    json(res, 404, { error: 'Bilinmeyen endpoint', path });
  } catch (error) {
    console.error('[api]', error);
    json(res, 500, { error: 'Sunucu hatası', detail: String(error?.message || error) });
  }
}
