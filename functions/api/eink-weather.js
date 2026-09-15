// GET /api/eink-weather?lat=..&lon=..&name=Optional+Label
//
// Renders current conditions as a 400x300 4-color (black/white/red/yellow)
// indexed PNG, matching the ZECTRIX NOTE4C e-paper devkit's native 2bpp BWRY
// panel format. Intended to be polled directly by the device firmware or by
// a bridge script that pushes the bytes to the device's local upload API.
import { fetchWeatherSummary } from '../../lib/eink/weather.js';
import { classifyWmo } from '../../lib/eink/wmo.js';
import { renderWeatherFramebuffer, PALETTE } from '../../lib/eink/render.js';
import { encodeIndexedPng } from '../../lib/eink/png.js';

export async function onRequestGet({ request }) {
  const url = new URL(request.url);
  const lat = parseFloat(url.searchParams.get('lat'));
  const lon = parseFloat(url.searchParams.get('lon'));
  const name = url.searchParams.get('name') || '';

  if (Number.isNaN(lat) || Number.isNaN(lon)) {
    return new Response('Missing or invalid required query params: lat, lon', { status: 400 });
  }

  let summary;
  try {
    summary = await fetchWeatherSummary(lat, lon);
  } catch (err) {
    return new Response(`Weather fetch failed: ${err.message}`, { status: 502 });
  }

  const condition = classifyWmo(summary.code);
  const updatedLabel = new Date().toLocaleTimeString('en-US', {
    hour: 'numeric',
    minute: '2-digit',
    timeZone: summary.timezone,
  });

  const { width, height, indices } = renderWeatherFramebuffer({
    ...summary,
    condition,
    name,
    updatedLabel,
  });

  const png = await encodeIndexedPng(width, height, PALETTE, indices);

  return new Response(png, {
    headers: {
      'content-type': 'image/png',
      'cache-control': 'public, max-age=600',
    },
  });
}
