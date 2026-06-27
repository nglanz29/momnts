# MOMNTS — Build Guide for Claude Code

This file is the source of truth for working on Momnts. Read it fully before editing.

## What Momnts is
A personal sports attendance tracker — "Letterboxd meets MLB Ballpark meets stadium tracker." It's the collection of every game the user was actually *there* for: log the matchup, keep a commemorative ticket stub, track venues crossed off and players seen live. Tagline: "Live sports, logged." / "Admit one · you were there." It's a keepsake, not a stats dashboard — emotional payoff matters as much as data.

## The single most important architectural constraint
**The entire app is ONE self-contained HTML file: `index.html`** (~4,600 lines). HTML + CSS + JS all inline, one `<script>` block. No build step, no bundler, no framework, no external JS/CSS files, no npm dependencies. The only external runtime dependencies are:
- Google Fonts (Space Mono, JetBrains Mono, Barlow Condensed) via `<link>`
- D3.js (CDN) for the US map
- ESPN's public JSON APIs (called client-side at runtime)
- Brand logo PNGs are **embedded as base64 data URIs** (the `MOMNTS_LOGO` const + favicon) precisely to preserve the single-file constraint.

Do not split this into multiple files or introduce a framework unless explicitly told to. If a change tempts you toward a build step, stop and flag it instead.

## How to run / test
Open `index.html` directly in a browser (`file://`) or serve it (`python3 -m http.server`). No install. State persists in `localStorage`. Note: on `file://`, Safari blocks ESPN's cross-origin CDN (logos, headshots, canvas PNG export taint). Serving over http (localhost or hosting) fixes that. The user tests in Chrome and Safari on macOS.

## CRITICAL BUILD RULES (the app has broken in production from violating these)
After EVERY change to the JS, verify before claiming it works:

1. **Parse check is authoritative.** Extract the inline `<script>` block and confirm it parses (e.g. `node -e "new Function(require('fs').readFileSync('index.html','utf8').match(/<script>(?![^>]*src)([\s\S]*?)<\/script>/g).sort((a,b)=>b.length-a.length)[0].replace(/<\/?script[^>]*>/g,''))"`). A syntax error anywhere kills the whole app ("nothing is clickable").
2. **ZERO optional chaining (`?.`).** It breaks older iOS Safari, a target platform. Use `&&` chains: `obj && obj.prop && obj.prop.x`. Grep for `?.` after editing — must be 0.
3. **No complex inline `onerror`** with nested escaped quotes — they've caused parse breaks. Use a simple `this.style.x` or the named helper `avatarFallback(this)` for image fallbacks.
4. **No duplicate function declarations**, and watch for orphaned/double braces (`}}`) after edits.
5. **Network egress may be blocked** in some sandboxes — you can't always curl ESPN. Debug API response shapes from console output the user pastes, not assumptions.
6. Full check sequence: parse → grep `?.` (=0) → grep bad `onerror` (=0) → confirm the feature is present → done.

## Data model (hard-won foundation — do not regress)
Games use a **canonical model**. Each game stores explicit:
`homeTeam, awayTeam, homeLogo, awayLogo, homeScore, awayScore, myTeam` (the team the user attended *for*), plus legacy compat fields (`team, opponent, homeAway, scoreUs, scoreThem, result, teamLogo`), plus `companions, photo, players[], seat, notes, isPlayoff, pinId, eventId, date, league, venue, id`.

- `canonicalGame(g)` re-derives canonical fields from source every call (no cached early-return). Handles pin-based home/away correction and favorite-team perspective.
- `computeMyResult(g)` returns W/L/T **always from `myTeam`'s perspective**, via canonical scores. NEVER reintroduce perspective-dependent W/L logic — it was the root cause of many early bugs.
- A migration runs on load to backfill canonical fields on older games.
- **localStorage**: all keys are prefixed `gd_` via the `LS` helper (`LS.save('games', …)` → `gd_games`). Keys: `user, favs, games, visited, checklist, players, moments, enabledLeagues, bucketList`. `resetApp()` clears them all.

## ESPN API notes (all verified against real responses)
- Schedule: `site.api.espn.com/apis/site/v2/sports/{sport}/teams/{id}/schedule?season={yr}&seasontype={2=reg|3=post}`
- Box score: `…/summary?event={eventId}`
- Athlete search: `…/apis/common/v3/sports/{sport}/athletes?search={q}`
- Headshots via `espnShot(sport, id)` → `a.espncdn.com/i/headshots/{sport}/players/full/{id}.png`
- **Box-score stats are positional arrays.** Some leagues send `name:"undefined"`, so the stat group type is detected from the *keys* array, not the name. Verified index maps exist for NBA/MLB/NFL/NHL — reuse them, don't re-derive. (NBA: pts=1, reb=5, ast=6, stl=8, blk=9. MLB batting: ab=1,r=2,h=3,rbi=4,hr=5; pitching: ip=0,er=3,k=5.)

## Team color system (subtle gotcha)
`TEAM_COLORS` is keyed by `{abbr}_{league}` (e.g. `kc_nfl`, `kc_mlb`) for EVERY team. This is intentional: bare `abbr` keys caused cross-league collisions (Chiefs were showing Royals blue because `kc` was defined twice and JS keeps the last). `teamColorsFor(logoUrl, league)` tries `abbr_league` first, then bare, then a neutral fallback. Keep all keys league-suffixed.

## BRAND SYSTEM (enforce on all visual work — Momnts Brand System v1.0)
Centralized in CSS variables at `:root`. Never hardcode brand colors inline; use the vars.
- **Colors:** `--ink:#0D0E10` (backgrounds/surfaces) · `--signal:#1FB574` (THE brand — logo, links, wins, highlights, active states; use with restraint) · `--paper:#EEF0EE` (text on dark) · `--pine:#0F3B2E` (secondary surfaces / card depth). Also `--bg/--bg2/--bg3/--bg4` (dark surface ramp).
- **Per-league colors stay as-is** (MLB red, NFL blue, etc.) — those are the leagues' own brands, not the app accent. The `.lmlb` badge red and MLB toggle red are intentional.
- **Type:** `--font-display` = Space Mono (display / wordmark / scores). `--font-ui` = JetBrains Mono (UI / labels / body). `--font` is also set to JetBrains Mono so all body copy inherits the brand font. Both are monospace so scores/dates/seats align in tabular columns. `--font-sans` exists as an unused fallback.
- **Wordmark:** lowercase "momnts" + ticket-stub icon, rendered from the embedded `MOMNTS_LOGO` PNG.
- **Casing rule:** everything lowercase EXCEPT league names (NFL/MLB/NBA/NHL), team names, and player names (proper-cased). Tracked-caps section labels (e.g. RECENT GAMES, via CSS `text-transform`) are an intentional style and stay uppercase.
- **Active nav:** signal green text with a left rule.

## Feature inventory (all implemented & working)
- Onboarding (name + favorite teams) + getting-started checklist
- Game logging: ESPN schedule picker + manual entry
- Commemorative ticket stubs (team-colored gradient, both logos, score in a dark tear-off counterfoil, deterministic real-barcode of varied-width bars)
- Photos & companions per game; photo layers behind the stub gradient
- Game detail modal with **share-to-PNG** (canvas-rendered 1080×1350 portrait stub: gradient, both logos, score, W/L pill, top-performers row with headshots, league logo, lowercase "momnts" mark)
- Stadium quest: D3 US map as a trophy case, with **collision-resolution declustering** so clustered metros (LA/NYC/Bay) don't hide logos; completion ring + per-league count cards that **both scope to the leagues you've toggled on**; bucket list; clicking a *visited* pin opens a venue modal (list games there / log new), clicking an unvisited pin goes straight to logging
- Players seen: ESPN box-score auto-import; **"seen-live leaders" leaderboards** per league (e.g. NFL passing/receiving/rushing yards & TDs; NBA pts/reb/ast; MLB hits/HR/RBI/K; NHL goals/assists/saves) ranked from aggregate totals, top 3 each; compact roster strip below; **player detail modal** (headshot, seen-live totals, game-by-game) on click; favorite/remove live in that modal
- My records: W/L overall, by team, by league, home/away, most-seen opponents
- Milestones, streaks & fan story (delight layer) with unlock toasts
- Moments: manual creation modal + auto playoff moments (auto ones are delete-protected)
- Data backup: JSON export + import (validates `_app:'momnts'`), in My Teams → Data & backup
- Game-log search (team/venue/opponent/companions/notes) + sort (newest/oldest/team A–Z)

## Known dead code
`playerCardHtml`, `playerProminence`, `posPriority` are leftover from the previous players-page layout (replaced by the leaderboard direction). They're valid but unused — safe to delete if tidying, but verify nothing references them first.

## Roadmap / what's next
1. **Ship to GitHub Pages** — fixes the cross-origin logo/headshot PNG-export limitation and makes the JSON backup a real safety net. (Until hosted, the user treats local data as disposable.)
2. Multi-user accounts + **Supabase** backend.
3. Possible: fuzzy logging ("Bengals 2022 playoffs" → autofill), richer year-in-review.

## Working style expected
- Diagnose root cause before editing; state it, then fix.
- Make the change, run the verification sequence above, then report what changed and why — concisely.
- Proactively flag brand/UX inconsistencies even when not asked.
- Preserve settled decisions; don't re-litigate (single-file constraint, team-colored stubs over a house style, canonical perspective-independent W/L, backup deferred until hosting, league-suffixed color keys).
