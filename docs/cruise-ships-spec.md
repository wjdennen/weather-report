# Cruise Ships in Port (Newport, RI)

Status: **built** for the web app and the iPhone app. Not in the iOS or macOS widgets.

## What it does

Within 20 miles of Newport (`CRUISE_PORT` / `CRUISE_MAX_MI` in `public/index.html`), the Home screen gets a "Cruise Ships" card after Tides: today plus the next four days, grouped by day. Ships calling today get an "In port today" tag; cancelled calls are struck through and labelled. Each row shows the cruise line, and tapping expands it to passenger capacity (double occupancy) and the ports of call on that cruise with Newport highlighted. Newport arrival/departure times appear on the row where known. No card outside the radius, when nothing is scheduled in the window, or if the file fails to load.

## Data

`public/cruise-newport.json` is a snapshot, transcribed by hand from the Newport Harbormaster's "2026 Cruise Ship Schedule, Perrotti Park" PDF published on [Discover Newport](https://www.discovernewport.org/industry/cruise-ship-schedule/). The web client just fetches that static file: no Worker route, scraping, KV or cron. The iPhone app bundles a copy and also tries `https://weather.dennen.dev/cruise-newport.json`, using whichever has the newer `updated` date.

`scripts/check-cruise.sh` compares the PDF link on Discover Newport's page with `pdfUrl` in the JSON (the filename changes with each update) and says whether a re-import is needed. It's run by hand.

## Lines, passengers and itineraries

Hand-compiled on 2026-10-07 from cruise line and travel agent sailing listings (Princess, Silversea, Norwegian, Ponant, Seabourn and others via agent pages). Stored in the same JSON: a `ships` table (`line`, `passengers`) and an optional `itinerary` per call. 19 of the 23 upcoming calls have one; four (Silver Shadow 10/12, Seabourn Ovation 10/18, Victory II 10/23, Viking Mars 10/24) don't. A few itineraries list ports in order without a date for every stop. Sources disagreed in places (e.g. Seabourn Ovation's Oct 22 stop was Rockland in one listing and Bar Harbor in another), so treat details as indicative. Itineraries are per sailing, so they must be redone each season.

## Why not CruiseMapper

CruiseMapper has better data (arrival/departure times, cruise lines) but its Terms of Use (section 4) prohibit scraping and automated collection without written consent. A working Worker scraper was built and tested, then removed. If CruiseMapper grants permission, times could be added; draft request in the project history/chat.

## Permission request to CruiseMapper

Bill emailed CruiseMapper (2026-10-07) asking for written consent under Section 4 of their terms. No reply yet; the app does not use CruiseMapper data. What the sent email offered, which is the scope any approval would cover:

- Fetch only the Newport page, plus the next month's page when the date range crosses a month boundary.
- Cache for **at least 24 hours**.
- Identify requests as `weather-report/1.0 (+https://github.com/wjdennen)`.
- Show only ship name, cruise line and arrival/departure times for the next five days.
- Credit CruiseMapper.com with a visible link back; stop immediately on request.
- Disclosed: hobby project, no ads/accounts/revenue, used by Bill and his wife, shared with a few friends.

If they say yes, the removed Worker scraper design (edge cache, stale fallback, per-month fetch) can be rebuilt with these limits. Note the email describes the card generically with Newport only as the example, and says "that one page", so confirm with them before adding any other port.

## Known limits

- The official schedule has dates and ship names only; times, lines, capacities and itineraries are hand-compiled from other listings and may be wrong or incomplete.
- Perrotti Park only. The Fort Adams (South Alofsin Pier) schedule hadn't been released; those small ships (e.g. American Cruise Lines) are missing.
- Snapshot goes stale until re-imported; ships also change plans after publication.
- I did not find Discover Newport terms of use; `robots.txt` allows crawling (2 s delay) and the PDF credits the Harbormaster. The data is a public schedule shown with credit.
- Newport is hard-wired (web and iPhone constants must match: 41.4901, -71.3128, 20 miles, 5 days); other ports would need their own file and radius.
