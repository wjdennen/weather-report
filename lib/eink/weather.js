// Server-side weather fetch for the e-ink renderer. Same data source and
// field choices as public/index.html's fetchWeather(), trimmed to only what
// the 400x300 display shows, and with no DOM/browser dependency.

const OPEN_METEO = 'https://api.open-meteo.com/v1/forecast';

export async function fetchWeatherSummary(lat, lon) {
  const params = new URLSearchParams({
    latitude: lat.toFixed(4),
    longitude: lon.toFixed(4),
    current: 'temperature_2m,apparent_temperature,weather_code,is_day',
    daily: 'temperature_2m_max,temperature_2m_min',
    temperature_unit: 'fahrenheit',
    timezone: 'auto',
    forecast_days: '1',
  });

  const res = await fetch(`${OPEN_METEO}?${params}`);
  if (!res.ok) {
    throw new Error(`Open-Meteo request failed: ${res.status}`);
  }
  const data = await res.json();

  return {
    tempF: Math.round(data.current.temperature_2m),
    feelsLikeF: Math.round(data.current.apparent_temperature),
    code: data.current.weather_code,
    isDay: data.current.is_day === 1,
    hiF: Math.round(data.daily.temperature_2m_max[0]),
    loF: Math.round(data.daily.temperature_2m_min[0]),
    timezone: data.timezone,
  };
}
