// Proxy for the Sunsethue API (https://sunsethue.com/dev-api) so the API key stays server-side.
// Only /api/* reaches this Worker (see run_worker_first in wrangler.toml); everything else is
// served straight from ./public. The key is the SUNSETHUE_KEY secret:
//   production: npx wrangler secret put SUNSETHUE_KEY
//   local dev:  SUNSETHUE_KEY=... in .dev.vars (gitignored)

const UPSTREAM = 'https://api.sunsethue.com/event';
const CACHE_SECONDS = 3 * 3600;      // Sunsethue refreshes its forecasts every 6 hours
const ERROR_CACHE_SECONDS = 300;     // back off briefly after a failure (e.g. daily quota hit)

function json(body, status = 200, cacheSeconds = 0) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      'Content-Type': 'application/json',
      'Cache-Control': cacheSeconds ? `public, max-age=${cacheSeconds}` : 'no-store',
    },
  });
}

// Quality-relevant fields only; the rest of the upstream payload is dropped.
function trim(upstream) {
  const d = upstream.data || {};
  return {
    type: d.type,
    quality: d.quality,
    quality_text: d.quality_text,
    cloud_cover: d.cloud_cover,
    direction: d.direction,
    time: d.time,
    golden_hour: d.magics?.golden_hour,
    blue_hour: d.magics?.blue_hour,
    model_data: d.model_data,
  };
}

async function handleSunset(request, env, ctx) {
  const url = new URL(request.url);
  const lat = Number(url.searchParams.get('lat'));
  const lon = Number(url.searchParams.get('lon'));
  const date = url.searchParams.get('date') || '';
  const type = url.searchParams.get('type') === 'sunrise' ? 'sunrise' : 'sunset';

  if (!Number.isFinite(lat) || !Number.isFinite(lon) || Math.abs(lat) > 90 || Math.abs(lon) > 180) {
    return json({ error: 'bad lat/lon' }, 400);
  }
  // Only dates the API can forecast (today..+3 days, with a day of slack for time zones).
  const parsed = /^\d{4}-\d{2}-\d{2}$/.test(date) ? Date.parse(date + 'T12:00:00Z') : NaN;
  const days = (parsed - Date.now()) / 86400000;
  if (!Number.isFinite(days) || days < -1.5 || days > 4) return json({ error: 'bad date' }, 400);
  if (!env.SUNSETHUE_KEY) return json({ error: 'not configured' }, 503);

  // Round to 0.1° (~7 mi): the model grid is coarser than that, and it lets nearby requests share one cached call.
  const rlat = lat.toFixed(1), rlon = lon.toFixed(1);
  const cacheKey = new Request(`https://cache.invalid/sunset?lat=${rlat}&lon=${rlon}&date=${date}&type=${type}`);
  const cache = caches.default;
  const hit = await cache.match(cacheKey);
  if (hit) return hit;

  let res;
  try {
    res = await fetch(`${UPSTREAM}?latitude=${rlat}&longitude=${rlon}&date=${date}&type=${type}`, {
      headers: { 'x-api-key': env.SUNSETHUE_KEY },
    });
  } catch {
    return json({ error: 'upstream unreachable' }, 502);
  }
  if (!res.ok) {
    const out = json({ error: 'upstream error', status: res.status }, 502, ERROR_CACHE_SECONDS);
    ctx.waitUntil(cache.put(cacheKey, out.clone()));
    return out;
  }
  let body;
  try { body = trim(await res.json()); } catch { return json({ error: 'bad upstream response' }, 502); }
  if (typeof body.quality !== 'number') return json({ error: 'no data' }, 502);

  const out = json(body, 200, CACHE_SECONDS);
  ctx.waitUntil(cache.put(cacheKey, out.clone()));
  return out;
}

export default {
  async fetch(request, env, ctx) {
    const { pathname } = new URL(request.url);
    if (request.method === 'GET' && pathname === '/api/sunset') return handleSunset(request, env, ctx);
    return json({ error: 'not found' }, 404);
  },
};
