# Cruise Ships in Port (Newport, RI)

Status: **built (web app only)**. Not in the iPhone app or macOS widget.

## What it does

Within 20 miles of Newport (`CRUISE_PORT` / `CRUISE_MAX_MI` in `public/index.html`), the Home screen gets a "Cruise Ships" card after Tides: today plus the next four days, grouped by day. Ships calling today get an "In port today" tag; cancelled calls are struck through and labelled. No card outside the radius, when nothing is scheduled in the window, or if the file fails to load.

## Data

`public/cruise-newport.json` is a snapshot, transcribed by hand from the Newport Harbormaster's "2026 Cruise Ship Schedule, Perrotti Park" PDF published on [Discover Newport](https://www.discovernewport.org/industry/cruise-ship-schedule/). The client just fetches that static file: no Worker route, scraping, KV or cron.

`scripts/check-cruise.sh` compares the PDF link on Discover Newport's page with `pdfUrl` in the JSON (the filename changes with each update) and says whether a re-import is needed. It's run by hand.

## Why not CruiseMapper

CruiseMapper has better data (arrival/departure times, cruise lines) but its Terms of Use (section 4) prohibit scraping and automated collection without written consent. A working Worker scraper was built and tested, then removed. If CruiseMapper grants permission, times could be added; draft request in the project history/chat.

## Known limits

- Dates and ship names only: no times, cruise lines or passenger counts.
- Perrotti Park only. The Fort Adams (South Alofsin Pier) schedule hadn't been released; those small ships (e.g. American Cruise Lines) are missing.
- Snapshot goes stale until re-imported; ships also change plans after publication.
- I did not find Discover Newport terms of use; `robots.txt` allows crawling (2 s delay) and the PDF credits the Harbormaster. The data is a public schedule shown with credit.
- Newport is hard-wired; other ports would need their own file and radius.
