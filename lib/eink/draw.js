// Pixel-buffer drawing primitives for the e-ink weather renderer.
// The buffer is a flat Uint8Array of palette indices, one byte per pixel.

import { GLYPH_WIDTH, GLYPH_HEIGHT, glyphFor } from './font5x7.js';

export function setPixel(buf, width, height, x, y, color) {
  x = Math.round(x);
  y = Math.round(y);
  if (x < 0 || y < 0 || x >= width || y >= height) return;
  buf[y * width + x] = color;
}

export function fillRect(buf, width, height, x0, y0, w, h, color) {
  for (let y = y0; y < y0 + h; y++) {
    for (let x = x0; x < x0 + w; x++) {
      setPixel(buf, width, height, x, y, color);
    }
  }
}

export function fillCircle(buf, width, height, cx, cy, r, color) {
  const r2 = r * r;
  for (let y = Math.floor(cy - r); y <= Math.ceil(cy + r); y++) {
    for (let x = Math.floor(cx - r); x <= Math.ceil(cx + r); x++) {
      const dx = x - cx;
      const dy = y - cy;
      if (dx * dx + dy * dy <= r2) setPixel(buf, width, height, x, y, color);
    }
  }
}

// True if (x, y) falls inside any of the given circles {dx, dy, r} (relative
// to cx, cy) or inside the given rect {x, y, w, h}. Used to draw a cloud as
// one seamless silhouette instead of overlapping filled shapes.
export function unionShape(buf, width, height, cx, cy, circles, rect, color) {
  const minX = Math.floor(cx - 200);
  const maxX = Math.ceil(cx + 200);
  const minY = Math.floor(cy - 200);
  const maxY = Math.ceil(cy + 200);
  for (let y = Math.max(0, minY); y <= Math.min(height - 1, maxY); y++) {
    for (let x = Math.max(0, minX); x <= Math.min(width - 1, maxX); x++) {
      let inside = false;
      for (const c of circles) {
        const dx = x - (cx + c.dx);
        const dy = y - (cy + c.dy);
        if (dx * dx + dy * dy <= c.r * c.r) {
          inside = true;
          break;
        }
      }
      if (!inside && rect) {
        const rx = cx + rect.x;
        const ry = cy + rect.y;
        if (x >= rx && x < rx + rect.w && y >= ry && y < ry + rect.h) inside = true;
      }
      if (inside) buf[y * width + x] = color;
    }
  }
}

export function drawLine(buf, width, height, x0, y0, x1, y1, color, thickness = 1) {
  x0 = Math.round(x0);
  y0 = Math.round(y0);
  x1 = Math.round(x1);
  y1 = Math.round(y1);
  const dx = Math.abs(x1 - x0);
  const dy = -Math.abs(y1 - y0);
  const sx = x0 < x1 ? 1 : -1;
  const sy = y0 < y1 ? 1 : -1;
  let err = dx + dy;
  const half = Math.floor(thickness / 2);
  for (;;) {
    for (let ox = -half; ox <= half; ox++) {
      for (let oy = -half; oy <= half; oy++) {
        setPixel(buf, width, height, x0 + ox, y0 + oy, color);
      }
    }
    if (x0 === x1 && y0 === y1) break;
    const e2 = 2 * err;
    if (e2 >= dy) {
      err += dy;
      x0 += sx;
    }
    if (e2 <= dx) {
      err += dx;
      y0 += sy;
    }
  }
}

export function drawChar(buf, width, height, x, y, char, color, scale) {
  const rows = glyphFor(char.toUpperCase());
  for (let row = 0; row < GLYPH_HEIGHT; row++) {
    for (let col = 0; col < GLYPH_WIDTH; col++) {
      if (rows[row][col] !== '#') continue;
      fillRect(buf, width, height, x + col * scale, y + row * scale, scale, scale, color);
    }
  }
}

const CHAR_ADVANCE = GLYPH_WIDTH + 1; // 1-column gap between glyphs

export function measureText(text, scale) {
  if (text.length === 0) return 0;
  return text.length * CHAR_ADVANCE * scale - scale;
}

export function drawText(buf, width, height, x, y, text, color, scale) {
  let cursor = x;
  for (const char of text) {
    drawChar(buf, width, height, cursor, y, char, color, scale);
    cursor += CHAR_ADVANCE * scale;
  }
}

export function drawTextCentered(buf, width, height, centerX, y, text, color, scale) {
  const textWidth = measureText(text, scale);
  drawText(buf, width, height, centerX - textWidth / 2, y, text, color, scale);
}
