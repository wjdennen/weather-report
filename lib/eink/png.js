// Minimal indexed-color PNG encoder for a 4-color (2-bit) palette image,
// built entirely on Web-standard APIs (CompressionStream), so this repo
// doesn't need a build step or npm dependency to produce the e-ink image.
// PNG's IDAT stream is zlib/RFC1950, which is exactly what
// CompressionStream('deflate') produces.

const SIGNATURE = new Uint8Array([137, 80, 78, 71, 13, 10, 26, 10]);

const CRC_TABLE = (() => {
  const table = new Uint32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) {
      c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    }
    table[n] = c >>> 0;
  }
  return table;
})();

function crc32(bytes) {
  let crc = 0xffffffff;
  for (let i = 0; i < bytes.length; i++) {
    crc = CRC_TABLE[(crc ^ bytes[i]) & 0xff] ^ (crc >>> 8);
  }
  return (crc ^ 0xffffffff) >>> 0;
}

function writeUint32BE(value) {
  return new Uint8Array([(value >>> 24) & 0xff, (value >>> 16) & 0xff, (value >>> 8) & 0xff, value & 0xff]);
}

function concatBytes(arrays) {
  const total = arrays.reduce((sum, a) => sum + a.length, 0);
  const out = new Uint8Array(total);
  let offset = 0;
  for (const a of arrays) {
    out.set(a, offset);
    offset += a.length;
  }
  return out;
}

function chunk(type, data) {
  const typeBytes = new TextEncoder().encode(type);
  const body = concatBytes([typeBytes, data]);
  return concatBytes([writeUint32BE(data.length), typeBytes, data, writeUint32BE(crc32(body))]);
}

async function deflate(data) {
  const cs = new CompressionStream('deflate');
  const writer = cs.writable.getWriter();
  writer.write(data);
  writer.close();
  const chunks = [];
  const reader = cs.readable.getReader();
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    chunks.push(value);
  }
  return concatBytes(chunks);
}

// Packs palette indices (0-3) into 2-bit-per-pixel scanlines, MSB-first as
// required by the PNG spec, each row prefixed with a filter-type byte (0).
function packScanlines(width, height, indices) {
  const rowBytes = Math.ceil((width * 2) / 8);
  const raw = new Uint8Array((rowBytes + 1) * height);
  let out = 0;
  for (let y = 0; y < height; y++) {
    raw[out++] = 0; // filter: none
    for (let x = 0; x < width; ) {
      let byte = 0;
      for (let i = 0; i < 4 && x < width; i++, x++) {
        const v = indices[y * width + x] & 0x3;
        byte |= v << (6 - i * 2);
      }
      raw[out++] = byte;
    }
  }
  return raw;
}

// palette: array of [r,g,b] (up to 4 entries). indices: Uint8Array of length
// width*height with values 0..palette.length-1.
export async function encodeIndexedPng(width, height, palette, indices) {
  const ihdr = concatBytes([
    writeUint32BE(width),
    writeUint32BE(height),
    new Uint8Array([2, 3, 0, 0, 0]), // bitDepth=2, colorType=3 (indexed), compression/filter/interlace=0
  ]);

  const plte = new Uint8Array(palette.length * 3);
  palette.forEach(([r, g, b], i) => {
    plte[i * 3] = r;
    plte[i * 3 + 1] = g;
    plte[i * 3 + 2] = b;
  });

  const raw = packScanlines(width, height, indices);
  const compressed = await deflate(raw);

  return concatBytes([
    SIGNATURE,
    chunk('IHDR', ihdr),
    chunk('PLTE', plte),
    chunk('IDAT', compressed),
    chunk('IEND', new Uint8Array(0)),
  ]);
}
