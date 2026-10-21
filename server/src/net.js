// Dış istekler için küçük yardımcılar: zaman aşımı, UA, JSON/metin okuma.

export const BROWSER_UA =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 ' +
  '(KHTML, like Gecko) Chrome/127.0.0.0 Safari/537.36';

export class HttpError extends Error {
  constructor(status, message, body) {
    super(message);
    this.status = status;
    this.body = body;
  }
}

export async function request(url, options = {}) {
  const {
    method = 'GET',
    headers = {},
    body,
    timeout = 9000,
    redirect = 'follow',
  } = options;

  const res = await fetch(url, {
    method,
    headers: { 'User-Agent': BROWSER_UA, 'Accept-Language': 'tr,en;q=0.8', ...headers },
    body,
    redirect,
    signal: AbortSignal.timeout(timeout),
  });
  return res;
}

export async function getJson(url, options = {}) {
  const res = await request(url, options);
  const text = await res.text();
  if (!res.ok) {
    throw new HttpError(res.status, `GET ${url} → ${res.status}`, text.slice(0, 400));
  }
  try {
    return JSON.parse(text);
  } catch {
    throw new HttpError(res.status, `GET ${url} → geçersiz JSON`, text.slice(0, 400));
  }
}

export async function getText(url, options = {}) {
  const res = await request(url, options);
  const text = await res.text();
  if (!res.ok) {
    throw new HttpError(res.status, `GET ${url} → ${res.status}`, text.slice(0, 400));
  }
  return text;
}

export function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/** Aynı anda en fazla `limit` iş çalıştıran basit map. */
export async function mapLimit(items, limit, fn) {
  const results = new Array(items.length);
  let next = 0;
  const workers = new Array(Math.min(limit, items.length)).fill(0).map(async () => {
    while (true) {
      const index = next++;
      if (index >= items.length) return;
      try {
        results[index] = await fn(items[index], index);
      } catch (error) {
        results[index] = { error: String(error?.message || error) };
      }
    }
  });
  await Promise.all(workers);
  return results;
}
