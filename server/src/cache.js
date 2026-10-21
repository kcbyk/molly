// Küçük, bağımlılıksız TTL cache.
// Sunucu tek instance çalıştığı sürece yeterli; kalıcı depolama gerektirmez.

const store = new Map();
const MAX_ENTRIES = 1200;

export function cacheGet(key) {
  const hit = store.get(key);
  if (!hit) return undefined;
  if (hit.expiresAt <= Date.now()) {
    store.delete(key);
    return undefined;
  }
  return hit.value;
}

export function cacheSet(key, value, ttlMs) {
  if (store.size >= MAX_ENTRIES) {
    // En eski kayıtları at (Map insertion order)
    const drop = Math.ceil(MAX_ENTRIES * 0.2);
    let i = 0;
    for (const k of store.keys()) {
      store.delete(k);
      if (++i >= drop) break;
    }
  }
  store.set(key, { value, expiresAt: Date.now() + Math.max(1000, ttlMs) });
}

/** Değer cache'te varsa döner; yoksa üretir ve saklar. `null` de cache'lenir. */
export async function cached(key, ttlMs, producer) {
  const hit = cacheGet(key);
  if (hit !== undefined) return hit;
  const value = await producer();
  if (value !== undefined) cacheSet(key, value, ttlMs);
  return value ?? null;
}

export function cacheStats() {
  return { entries: store.size };
}
