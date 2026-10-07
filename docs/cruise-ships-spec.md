# Cruise Ships in Port (Newport, RI)

Status: **built (web app only)**. Not in the iPhone app or macOS widget.

## What it does

Within 20 miles of Newport (`CRUISE_PORT` / `CRUISE_MAX_MI` in `public/index.html`), the Home screen gets a "Cruise Ships" card after Tides: today plus the next four days, grouped by day. Ships calling today get an "In port today" tag; cancelled calls are struck through and labelled. No card outside the radius, when nothing is scheduled in the window, or if the file fails to load.

## Data

`public/cruise-newport.json` is a snapshot, transcribed by hand from the Newport Harbormaster's "2026 Cruise Ship Schedule, Perrotti Park" PDF published on [Discover Newport](https://www.discovernewport.org/industry/cruise-ship-schedule/). The client just fetches that static file: no Worker route, scraping, KV or cron.

`scripts/check-cruise.sh` compares the PDF link on Discover Newport's page with `pdfUrl` in the JSON (the filename changes with each update) and says whether a re-import is needed. It's run by hand.

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

- Dates and ship names only: no times, cruise lines or passenger counts.
- Perrotti Park only. The Fort Adams (South Alofsin Pier) schedule hadn't been released; those small ships (e.g. American Cruise Lines) are missing.
- Snapshot goes stale until re-imported; ships also change plans after publication.
- I did not find Discover Newport terms of use; `robots.txt` allows crawling (2 s delay) and the PDF credits the Harbormaster. The data is a public schedule shown with credit.
- Newport is hard-wired; other ports would need their own file and radius.
