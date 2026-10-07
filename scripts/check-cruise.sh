#!/bin/sh
# Checks whether Newport's cruise schedule (public/cruise-newport.json) is still the latest one
# Discover Newport has published. The landing page links to a PDF whose filename changes with each
# update; if that link differs from `pdfUrl` in the JSON, the schedule has been revised.
# Exit status: 0 = current, 1 = changed (re-import), 2 = couldn't check.
set -u
cd "$(dirname "$0")/.."

PAGE="https://www.discovernewport.org/industry/cruise-ship-schedule/"
HTML=$(curl -sL -A "weather-report/1.0 (+https://github.com/wjdennen)" "$PAGE") || { echo "Couldn't fetch $PAGE"; exit 2; }
LATEST=$(printf '%s' "$HTML" | grep -o 'https://assets\.simpleviewinc\.com[^"]*cruise_ship[^"]*\.pdf' | sort -u)
STORED=$(grep -o '"pdfUrl": *"[^"]*"' public/cruise-newport.json | sed 's/.*: *"//; s/"$//')

if [ -z "$LATEST" ]; then
  echo "No schedule PDF link found on $PAGE (page may have changed)."; exit 2
fi
if [ "$(printf '%s\n' "$LATEST" | wc -l | tr -d ' ')" -gt 1 ]; then
  echo "Several schedule PDFs are linked (e.g. a South Alofsin Pier schedule may have been added):"
  printf '%s\n' "$LATEST"; echo "Stored: $STORED"; exit 1
fi
if [ "$LATEST" = "$STORED" ]; then
  echo "Up to date (stored schedule: $(grep -o '"updated": *"[^"]*"' public/cruise-newport.json | sed 's/.*: *"//; s/"$//'))."; exit 0
fi
echo "A newer Newport cruise schedule has been published:"
echo "  $LATEST"
echo "Stored: $STORED"
echo "Re-import it into public/cruise-newport.json."
exit 1
