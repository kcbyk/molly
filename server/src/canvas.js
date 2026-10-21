import { cacheGet, cacheSet } from './cache.js';
import { mapLimit } from './net.js';
import { itunesSearch } from './itunes.js';
import { spotifyCanvas, spotifyOembed, spotifySearch, spotifyTrack } from './spotify.js';

/**
 * Tek bir şarkı için canvas + kapak çözer.
 * - trackId varsa doğrudan onu kullanır.
 * - yoksa query ile Spotify'da arar (credentials varsa), sonra iTunes kapağına düşer.
 */
export async function resolveCanvas({ trackId, query }) {
  const cleanId = (trackId || '').trim() || null;
  const cleanQuery = (query || '').trim();
  const key = cleanId ? `resolve:id:${cleanId}` : `resolve:q:${cleanQuery.toLowerCase()}`;
  if (!cleanId && !cleanQuery) return null;

  const cached = cacheGet(key);
  if (cached !== undefined) return cached;

  let spotifyId = cleanId;
  let coverUrl = null;
  let meta = null;

  if (spotifyId) {
    meta = await spotifyTrack(spotifyId).catch(() => null);
    coverUrl = meta?.coverUrl || null;
    if (!coverUrl) {
      const oembed = await spotifyOembed(spotifyId);
      coverUrl = oembed?.coverUrl || null;
    }
  } else if (cleanQuery) {
    const search = await spotifySearch(cleanQuery, 1);
    if (search?.length) {
      spotifyId = search[0].spotifyTrackId;
      coverUrl = search[0].coverUrl;
      meta = search[0];
    }
    if (!coverUrl) {
      const itunes = await itunesSearch(cleanQuery, 1);
      if (itunes?.length) coverUrl = itunes[0].coverUrl;
    }
  }

  let canvasesList = [];
  if (spotifyId) {
    canvasesList = (await spotifyCanvas(spotifyId)) || [];
  }

  const result = {
    trackId: spotifyId,
    coverUrl,
    canvasesList,
    title: meta?.title || null,
    artist: meta?.artist || null,
    durationSeconds: meta?.durationSeconds || null,
  };

  cacheSet(key, result, 30 * 60 * 1000);
  return result;
}

/** Ana ekrandaki şarkı listesi için tek istekte toplu çözümleme. */
export async function resolveCanvasBatch(items, { concurrency = 4 } = {}) {
  const results = await mapLimit(items, concurrency, async (item) => {
    const resolved = await resolveCanvas({
      trackId: item.trackId || item.spotifyTrackId,
      query: item.query || [item.artist, item.title].filter(Boolean).join(' '),
    });
    return {
      id: item.id,
      trackId: resolved?.trackId || null,
      coverUrl: resolved?.coverUrl || null,
      canvasUrl: resolved?.canvasesList?.[0]?.canvasUrl || null,
    };
  });

  return results.map((entry) =>
    entry && entry.error ? { id: null, coverUrl: null, canvasUrl: null, error: entry.error } : entry,
  );
}
