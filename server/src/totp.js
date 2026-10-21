import { createHmac } from 'node:crypto';

/**
 * RFC 6238 uyumlu 6 haneli TOTP (SHA-1, 30 sn).
 * Spotify'ın web token endpoint'i bu kodu istiyor.
 */
export function generateTotp(secretKey, timestampMs = Date.now(), { digits = 6, period = 30 } = {}) {
  const counter = BigInt(Math.floor(timestampMs / 1000 / period));
  const buffer = Buffer.alloc(8);
  buffer.writeBigUInt64BE(counter);

  const hmac = createHmac('sha1', secretKey).update(buffer).digest();
  const offset = hmac[hmac.length - 1] & 0x0f;
  const binary =
    ((hmac[offset] & 0x7f) << 24) |
    (hmac[offset + 1] << 16) |
    (hmac[offset + 2] << 8) |
    hmac[offset + 3];

  return String(binary % 10 ** digits).padStart(digits, '0');
}

/**
 * spot-secrets-go sözlüğündeki XOR'lanmış int dizisini HMAC anahtarına çevirir.
 * (Bu sadece bir veri dönüşümü; proje kodu kopyalanmadı.)
 */
export function secretKeyFromList(list) {
  if (!Array.isArray(list) || !list.length) return null;
  const text = list.map((value, index) => value ^ ((index % 33) + 9)).join('');
  return Buffer.from(text, 'utf8');
}
