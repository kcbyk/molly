// Spotify Canvas protobuf tel formatı (spclient.wg.spotify.com/canvaz-cache/v0/canvases).
// Sadece ihtiyacımız olan alanlar; harici protobuf kütüphanesi gerekmez.
//
//   message CanvasRequest { message Track { string track_uri = 1; } repeated Track tracks = 1; }
//   message CanvasResponse {
//     message Canvas {
//       string id = 1; string canvas_url = 2; string track_uri = 5;
//       Artist artist = 6; string other_id = 9; string canvas_uri = 11;
//     }
//     repeated Canvas canvases = 1;
//   }

function varint(value) {
  let n = BigInt(value);
  const out = [];
  do {
    let byte = Number(n & 0x7fn);
    n >>= 7n;
    if (n > 0n) byte |= 0x80;
    out.push(byte);
  } while (n > 0n);
  return Buffer.from(out);
}

function tag(field, wire) {
  return varint(field * 8 + wire);
}

export function encodeString(field, value) {
  if (value == null) return Buffer.alloc(0);
  const data = Buffer.from(String(value), 'utf8');
  return Buffer.concat([tag(field, 2), varint(data.length), data]);
}

export function encodeMessage(field, payload) {
  return Buffer.concat([tag(field, 2), varint(payload.length), payload]);
}

export function encodeCanvasRequest(trackUri) {
  const track = encodeString(1, trackUri);
  return encodeMessage(1, track);
}

function readVarint(buf, offset) {
  let result = 0n;
  let shift = 0n;
  let i = offset;
  while (i < buf.length) {
    const byte = buf[i++];
    result |= BigInt(byte & 0x7f) << shift;
    if ((byte & 0x80) === 0) return [result, i];
    shift += 7n;
  }
  throw new Error('protobuf: eksik varint');
}

function readFields(buf) {
  const fields = new Map();
  let i = 0;
  while (i < buf.length) {
    let key;
    [key, i] = readVarint(buf, i);
    const keyNum = Number(key);
    const field = Math.floor(keyNum / 8);
    const wire = keyNum & 7;
    let value;
    if (wire === 0) {
      [value, i] = readVarint(buf, i);
      value = Number(value);
    } else if (wire === 2) {
      let len;
      [len, i] = readVarint(buf, i);
      value = buf.subarray(i, i + Number(len));
      i += Number(len);
    } else if (wire === 1) {
      value = buf.subarray(i, i + 8);
      i += 8;
    } else if (wire === 5) {
      value = buf.subarray(i, i + 4);
      i += 4;
    } else {
      throw new Error(`protobuf: bilinmeyen wire tipi ${wire}`);
    }
    if (!fields.has(field)) fields.set(field, []);
    fields.get(field).push(value);
  }
  return fields;
}

function asString(fields, field) {
  const list = fields.get(field);
  if (!list || !list.length) return '';
  const item = list[0];
  return Buffer.isBuffer(item) ? item.toString('utf8') : String(item);
}

export function decodeCanvasResponse(buffer) {
  const root = readFields(Buffer.from(buffer));
  const canvases = (root.get(1) || [])
    .filter((item) => Buffer.isBuffer(item))
    .map((item) => {
      const fields = readFields(item);
      const artistBuffer = (fields.get(6) || []).find((v) => Buffer.isBuffer(v));
      let artist = null;
      if (artistBuffer) {
        const artistFields = readFields(artistBuffer);
        artist = {
          artistUri: asString(artistFields, 1),
          artistName: asString(artistFields, 2),
          artistImgUrl: asString(artistFields, 3),
        };
      }
      return {
        id: asString(fields, 1),
        canvasUrl: asString(fields, 2),
        trackUri: asString(fields, 5),
        artist,
        otherId: asString(fields, 9) || null,
        canvasUri: asString(fields, 11) || null,
      };
    })
    .filter((canvas) => canvas.canvasUrl);

  return { canvasesList: canvases };
}

/** Canvas id'sinden canvaz.scdn.co adresi (bazı cevaplarda URL boş gelir). */
export function canvasUrlFromId(id) {
  if (!id || !/^[a-f0-9]{16,}$/i.test(id)) return null;
  return `https://canvaz.scdn.co/upload/spotify:canvas:${id}`;
}
