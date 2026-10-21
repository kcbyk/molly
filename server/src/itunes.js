import { cacheGet, cacheSet } from './cache.js';
import { getJson } from './net.js';

/**
 * Anahtarsız arama/kapak kaynağı. Spotify credentials yoksa devreye girer.
 * iTunes 100x100 kapak verir; URL'deki boyutu 600x600'e yükseltiyoruz.
 */
export function itunesArtwork(url100) {
  if (!url100) return null;
  return url100.replace(/\/\d+x\d+bb\.(jpg|png)$/i, '/600x600bb.$1');
}

export function normalizeItunesTrack(item) {
  if (!item) return null;
  return {
    id: `itunes_${item.trackId}`,
    title: item.trackName || item.collectionName || 'Bilinmeyen Şarkı',
    artist: item.artistName || 'Bilinmeyen Sanatçı',
    coverUrl: itunesArtwork(item.artworkUrl100),
    durationSeconds: Math.round((item.trackTimeMillis || 0) / 1000) || 0,
    spotifyTrackId: null,
    source: 'itunes',
    previewUrl: item.previewUrl || null,
  };
}

export async function itunesSearch(query, limit = 15) {
  const key = `itunes:${query.toLowerCase()}:${limit}`;
  const cached = cacheGet(key);
  if (cached) return cached;

  const buildUrl = (country) =>
    'https://itunes.apple.com/search?' +
    new URLSearchParams({
      term: query,
      media: 'music',
      entity: 'song',
      limit: String(limit),
      ...(country ? { country } : {}),
    });

  for (const country of ['TR', null]) {
    try {
      const data = await getJson(buildUrl(country), { timeout: 8000 });
      const results = (data.results || [])
        .filter((item) => item.kind === 'song' || item.wrapperType === 'track')
        .map(normalizeItunesTrack)
        .filter(Boolean);
      if (results.length) {
        cacheSet(key, results, 15 * 60 * 1000);
        return results;
      }
    } catch (error) {
      console.warn('[itunes] arama hatası:', error.message);
    }
  }

  cacheSet(key, null, 5 * 60 * 1000);
  return null;
}
