# momnts

**Live sports, logged.** · *Admit one — you were there.*

A personal sports attendance tracker — Letterboxd meets the MLB Ballpark app meets a stadium passport. momnts is the collection of every game you were actually *there* for: log the matchup, keep a commemorative ticket stub, cross venues off the map, and track the players you've seen live. It's a keepsake, not a stats dashboard.

## What's inside

- **Game log** — log games via the ESPN schedule picker or by hand, each as a commemorative ticket stub
- **Stadium quest** — a US map trophy case of every venue you've visited, with a bucket list and per-league completion
- **Players seen live** — auto-imported from box scores, with seen-live leaderboards
- **My records** — your personal win/loss across every game you've attended
- **Moments** — the historic, the rare, the unforgettable
- **Share to PNG** — export any ticket stub as a portrait image

## Architecture

The entire app is **one self-contained file: `index.html`** — HTML, CSS, and JS inline, no build step, no framework, no dependencies to install. The only external runtime pieces are Google Fonts, D3.js (for the map), and ESPN's public JSON APIs, all loaded at runtime. State persists in the browser's `localStorage`; a JSON export/import is the backup mechanism.

## Running it locally

Serve the folder over http (so ESPN logos/headshots and PNG export work — `file://` is blocked by Safari's cross-origin rules):

```bash
python3 -m http.server 8000
```

Then open <http://localhost:8000/> (or `index.html` directly).

## Development

See [`CLAUDE.md`](CLAUDE.md) for the full build guide — architecture constraints, the data model, ESPN API notes, the brand system, and the verification steps to run after every change.
