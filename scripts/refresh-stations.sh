#!/bin/sh
# Downloads the latest NOAA tide station list and updates public/stations.json.
# Run from the repo root: ./scripts/refresh-stations.sh
set -e
cd "$(dirname "$0")/.."

echo "Fetching NOAA station list..."
curl -sf "https://api.tidesandcurrents.noaa.gov/mdapi/prod/webapi/stations.json?expand=details&type=tidepredictions" \
  | python3 -c "
import json, sys
d = json.load(sys.stdin)
out = [[s['id'], s['name'], s.get('state',''), float(s['lat']), float(s['lng'])] for s in d['stations']]
print(json.dumps(out))
" > public/stations.json

COUNT=$(python3 -c "import json; print(len(json.load(open('public/stations.json'))))")
echo "Done. $COUNT stations written to public/stations.json"
echo "Commit and push — no SW cache bump needed."
