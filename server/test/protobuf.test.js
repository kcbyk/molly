import assert from 'node:assert/strict';
import test from 'node:test';
import {
  decodeCanvasResponse,
  encodeCanvasRequest,
  encodeMessage,
  encodeString,
} from '../src/protobuf.js';

test('canvas isteği geçerli protobuf üretir', () => {
  const uri = 'spotify:track:3OHfY25tqY28d16oZczHc8';
  const buffer = encodeCanvasRequest(uri);
  // field 1 (tracks), wire 2 → 0x0a
  assert.equal(buffer[0], 0x0a);
  assert.ok(buffer.includes(Buffer.from(uri, 'utf8')));
});

test('canvaz cache cevabı çözümlenir', () => {
  const artist = Buffer.concat([
    encodeString(1, 'spotify:artist:7tYKF4w9nC0nq9CsPZTHyP'),
    encodeString(2, 'SZA'),
    encodeString(3, 'https://i.scdn.co/image/artist'),
  ]);

  const canvas = Buffer.concat([
    encodeString(1, '32b57cbf354b453a95eee32bb04d4e42'),
    encodeString(
      2,
      'https://canvaz.scdn.co/upload/licensor/5bSw7fRotCnRCcO9br14W5/video/32b57cbf354b453a95eee32bb04d4e42.cnvs.mp4',
    ),
    encodeString(5, 'spotify:track:3OHfY25tqY28d16oZczHc8'),
    encodeMessage(6, artist),
    encodeString(9, '2c441fceb502eaa25f26bcd5b1ccfc0d'),
    encodeString(11, 'spotify:canvas:1xGyujDyxbx4eTPD4nKLw6'),
  ]);

  const response = Buffer.concat([encodeMessage(1, canvas)]);
  const parsed = decodeCanvasResponse(response);

  assert.equal(parsed.canvasesList.length, 1);
  const first = parsed.canvasesList[0];
  assert.equal(first.id, '32b57cbf354b453a95eee32bb04d4e42');
  assert.match(first.canvasUrl, /\.cnvs\.mp4$/);
  assert.equal(first.trackUri, 'spotify:track:3OHfY25tqY28d16oZczHc8');
  assert.equal(first.artist.artistName, 'SZA');
  assert.equal(first.canvasUri, 'spotify:canvas:1xGyujDyxbx4eTPD4nKLw6');
});

test('canvas içermeyen cevap boş liste döner', () => {
  assert.deepEqual(decodeCanvasResponse(Buffer.alloc(0)), { canvasesList: [] });
});

test('bilinmeyen alanlar atlanır', () => {
  const canvas = Buffer.concat([
    encodeString(2, 'https://canvaz.scdn.co/x.cnvs.mp4'),
    encodeString(77, 'yok say'),
    encodeString(1, 'id1'),
  ]);
  const parsed = decodeCanvasResponse(Buffer.concat([encodeMessage(1, canvas)]));
  assert.equal(parsed.canvasesList[0].id, 'id1');
  assert.equal(parsed.canvasesList[0].canvasUrl, 'https://canvaz.scdn.co/x.cnvs.mp4');
});
