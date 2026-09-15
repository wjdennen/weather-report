import { fillCircle, unionShape, drawLine, drawText, drawTextCentered, measureText } from './draw.js';

export const WIDTH = 400;
export const HEIGHT = 300;

// Palette indices used throughout the renderer. Pure primaries so that
// whatever quantizer the device (or its firmware) applies on top of this
// PNG has an unambiguous nearest color to land on.
export const BLACK = 0;
export const WHITE = 1;
export const RED = 2;
export const YELLOW = 3;

export const PALETTE = [
  [0, 0, 0], // BLACK
  [255, 255, 255], // WHITE
  [255, 0, 0], // RED
  [255, 255, 0], // YELLOW
];

function drawCloud(buf, cx, cy, scale, color) {
  unionShape(
    buf,
    WIDTH,
    HEIGHT,
    cx,
    cy,
    [
      { dx: -scale * 1.1, dy: scale * 0.3, r: scale * 0.9 },
      { dx: 0, dy: -scale * 0.25, r: scale * 1.15 },
      { dx: scale * 1.05, dy: scale * 0.35, r: scale * 0.85 },
    ],
    { x: -scale * 1.6, y: scale * 0.25, w: scale * 3.2, h: scale * 0.75 },
    color,
  );
}

function drawSun(buf, cx, cy, scale) {
  fillCircle(buf, WIDTH, HEIGHT, cx, cy, scale * 1.1, YELLOW);
  for (let i = 0; i < 8; i++) {
    const angle = (i * Math.PI) / 4;
    const x1 = cx + Math.cos(angle) * scale * 1.35;
    const y1 = cy + Math.sin(angle) * scale * 1.35;
    const x2 = cx + Math.cos(angle) * scale * 1.9;
    const y2 = cy + Math.sin(angle) * scale * 1.9;
    drawLine(buf, WIDTH, HEIGHT, x1, y1, x2, y2, BLACK, 2);
  }
}

function drawRainDrops(buf, cx, cy, scale) {
  for (let i = -1; i <= 1; i++) {
    const x = cx + i * scale * 0.7;
    const y = cy + scale * 0.9;
    drawLine(buf, WIDTH, HEIGHT, x, y, x - scale * 0.25, y + scale * 0.6, BLACK, 2);
  }
}

function drawSnowMarks(buf, cx, cy, scale) {
  for (let i = -1; i <= 1; i++) {
    const x = cx + i * scale * 0.7;
    const y = cy + scale * 1.1;
    const r = scale * 0.22;
    drawLine(buf, WIDTH, HEIGHT, x - r, y, x + r, y, BLACK, 2);
    drawLine(buf, WIDTH, HEIGHT, x, y - r, x, y + r, BLACK, 2);
    drawLine(buf, WIDTH, HEIGHT, x - r, y - r, x + r, y + r, BLACK, 2);
    drawLine(buf, WIDTH, HEIGHT, x - r, y + r, x + r, y - r, BLACK, 2);
  }
}

function drawLightningBolt(buf, cx, cy, scale) {
  const x = cx;
  const y = cy + scale * 0.7;
  drawLine(buf, WIDTH, HEIGHT, x + scale * 0.3, y, x - scale * 0.15, y + scale * 0.55, RED, 3);
  drawLine(buf, WIDTH, HEIGHT, x - scale * 0.15, y + scale * 0.55, x + scale * 0.2, y + scale * 0.55, RED, 3);
  drawLine(buf, WIDTH, HEIGHT, x + scale * 0.2, y + scale * 0.55, x - scale * 0.3, y + scale * 1.15, RED, 3);
}

function drawFogLines(buf, cx, cy, scale) {
  for (let i = -1; i <= 1; i++) {
    const y = cy + i * scale * 0.5;
    drawLine(buf, WIDTH, HEIGHT, cx - scale * 1.5, y, cx + scale * 1.5, y, BLACK, 3);
  }
}

function drawIcon(buf, icon, cx, cy, scale) {
  switch (icon) {
    case 'sun':
      drawSun(buf, cx, cy, scale);
      break;
    case 'partly':
      drawSun(buf, cx - scale * 0.5, cy - scale * 0.3, scale * 0.75);
      drawCloud(buf, cx + scale * 0.3, cy + scale * 0.4, scale * 0.9, BLACK);
      break;
    case 'cloud':
      drawCloud(buf, cx, cy, scale, BLACK);
      break;
    case 'fog':
      drawCloud(buf, cx, cy - scale * 0.3, scale * 0.8, BLACK);
      drawFogLines(buf, cx, cy + scale * 0.7, scale);
      break;
    case 'rain':
      drawCloud(buf, cx, cy, scale, BLACK);
      drawRainDrops(buf, cx, cy, scale);
      break;
    case 'snow':
      drawCloud(buf, cx, cy, scale, BLACK);
      drawSnowMarks(buf, cx, cy, scale);
      break;
    case 'storm':
      drawCloud(buf, cx, cy, scale, BLACK);
      drawLightningBolt(buf, cx, cy, scale);
      break;
    default:
      drawCloud(buf, cx, cy, scale, BLACK);
  }
}

// summary: { tempF, feelsLikeF, hiF, loF, condition: {icon,label}, name, updatedLabel }
export function renderWeatherFramebuffer(summary) {
  const buf = new Uint8Array(WIDTH * HEIGHT).fill(WHITE);

  drawIcon(buf, summary.condition.icon, 95, 110, 55);

  const tempText = `${summary.tempF}°`;
  drawText(buf, WIDTH, HEIGHT, 190, 55, tempText, BLACK, 7);

  drawTextCentered(buf, WIDTH, HEIGHT, 200, 150, summary.condition.label, BLACK, 3);

  const hiLoText = `H:${summary.hiF}°  L:${summary.loF}°`;
  drawTextCentered(buf, WIDTH, HEIGHT, 200, 190, hiLoText, BLACK, 2);

  const feelsText = `FEELS LIKE ${summary.feelsLikeF}°`;
  drawTextCentered(buf, WIDTH, HEIGHT, 200, 215, feelsText, BLACK, 2);

  drawLine(buf, WIDTH, HEIGHT, 20, 250, WIDTH - 20, 250, BLACK, 1);

  if (summary.name) {
    drawText(buf, WIDTH, HEIGHT, 20, 265, summary.name.toUpperCase(), BLACK, 2);
  }
  if (summary.updatedLabel) {
    const w = measureText(summary.updatedLabel, 2);
    drawText(buf, WIDTH, HEIGHT, WIDTH - 20 - w, 265, summary.updatedLabel, BLACK, 2);
  }

  return { width: WIDTH, height: HEIGHT, indices: buf };
}
