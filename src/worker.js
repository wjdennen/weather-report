// Worker entry point for weather-report. This project is deployed as a
// Worker with static assets (not classic Cloudflare Pages), so custom
// routes live here rather than in a functions/ directory — the assets
// config in wrangler.toml serves everything under public/ directly, and
// only requests that don't match a static file reach this fetch handler.
import { fetchWeatherSummary } from '../lib/eink/weather.js';
import { classifyWmo } from '../lib/eink/wmo.js';
import { renderWeatherFramebuffer, PALETTE } from '../lib/eink/render.js';
import { encodeIndexedPng } from '../lib/eink/png.js';

export default {
  async fetch(request) {
    const url = new URL(request.url);

    if (url.pathname === '/api/eink-weather') {
      return handleEinkWeather(url);
    }

    return new Response('Not found', { status: 404 });
  },
};

async function handleEinkWeather(url) {
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
