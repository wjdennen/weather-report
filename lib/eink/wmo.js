// Condensed version of the WMO weather-code table used in public/index.html,
// trimmed to just what the e-ink renderer needs: an icon family and a short
// all-caps label that fits a 400px-wide display.

const TABLE = {
  0: { icon: 'sun', label: 'CLEAR' },
  1: { icon: 'sun', label: 'MOSTLY CLEAR' },
  2: { icon: 'partly', label: 'PARTLY CLOUDY' },
  3: { icon: 'cloud', label: 'CLOUDY' },
  45: { icon: 'fog', label: 'FOG' },
  48: { icon: 'fog', label: 'FOG' },
  51: { icon: 'rain', label: 'DRIZZLE' },
  53: { icon: 'rain', label: 'DRIZZLE' },
  55: { icon: 'rain', label: 'DRIZZLE' },
  56: { icon: 'rain', label: 'FREEZING DRIZZLE' },
  57: { icon: 'rain', label: 'FREEZING DRIZZLE' },
  61: { icon: 'rain', label: 'RAIN' },
  63: { icon: 'rain', label: 'RAIN' },
  65: { icon: 'rain', label: 'HEAVY RAIN' },
  66: { icon: 'rain', label: 'FREEZING RAIN' },
  67: { icon: 'rain', label: 'FREEZING RAIN' },
  71: { icon: 'snow', label: 'SNOW' },
  73: { icon: 'snow', label: 'SNOW' },
  75: { icon: 'snow', label: 'HEAVY SNOW' },
  77: { icon: 'snow', label: 'SNOW GRAINS' },
  80: { icon: 'rain', label: 'SHOWERS' },
  81: { icon: 'rain', label: 'SHOWERS' },
  82: { icon: 'rain', label: 'HEAVY SHOWERS' },
  85: { icon: 'snow', label: 'SNOW SHOWERS' },
  86: { icon: 'snow', label: 'SNOW SHOWERS' },
  95: { icon: 'storm', label: 'THUNDERSTORM' },
  96: { icon: 'storm', label: 'THUNDERSTORM' },
  99: { icon: 'storm', label: 'THUNDERSTORM' },
};

export function classifyWmo(code) {
  return TABLE[code] || { icon: 'cloud', label: 'UNKNOWN' };
}
