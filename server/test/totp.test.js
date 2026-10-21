import assert from 'node:assert/strict';
import test from 'node:test';
import { generateTotp, secretKeyFromList } from '../src/totp.js';

test('RFC 6238 test vektörü (T=59, SHA-1)', () => {
  const secret = Buffer.from('12345678901234567890', 'utf8');
  assert.equal(generateTotp(secret, 59_000), '287082');
  assert.equal(generateTotp(secret, 59_000, { digits: 8 }), '94287082');
});

test('TOTP 30 saniyede bir değişir', () => {
  const secret = Buffer.from('12345678901234567890', 'utf8');
  const first = generateTotp(secret, 1_700_000_000_000);
  const second = generateTotp(secret, 1_700_000_000_000 + 30_000);
  assert.notEqual(first, second);
  assert.match(first, /^\d{6}$/);
});

test('sır listesi XOR ile anahtara çevrilir', () => {
  const key = secretKeyFromList([1, 2, 3]);
  assert.deepEqual(key, Buffer.from('888', 'utf8'));
});
