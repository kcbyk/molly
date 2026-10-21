import { itunesSearch } from './itunes.js';
import { spotifySearch } from './spotify.js';

/**
 * Arama sırası:
 *   1. Spotify (client credentials varsa) → 640px kapak + gerçek track id (canvas için)
 *   2. iTunes (anahtarsız) → 600px kapak
 *   3. Boş sonuç → istemci kendi yedeklerine (Invidious) düşer
 */
export async function searchSongs(query, limit = 15) {
  const spotify = await spotifySearch(query, limit);
  if (spotify?.length) {
    return { source: 'spotify', results: spotify };
  }

  const itunes = await itunesSearch(query, limit);
  if (itunes?.length) {
    return { source: 'itunes', results: itunes };
  }

  return { source: 'none', results: [] };
}
