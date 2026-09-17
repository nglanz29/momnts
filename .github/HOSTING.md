# Private repo + public site (free)

Goal: keep momntsapp.com publicly reachable while the source repo is private,
without paying for GitHub Pro. GitHub Pages cannot serve from a private repo on
the Free plan, so hosting moves to **Cloudflare Pages**, which deploys from a
private GitHub repo on its free tier.

## What this does and does not protect

**It does not hide the app's code.** momnts is a client-side single-file app —
every visitor's browser downloads the whole thing to run it. View Source gets
someone the complete app on any host, at any price. That is how the web works
and no hosting change alters it.

**What it does protect:** the dev docs, the commit history, the issues, and the
roadmap — the process, not the product. That's the genuinely useful part: a
copier can read the UI either way, but CLAUDE.md hands them every architectural
decision and every mistake already paid for.

The real moat stays what it always was: the users and their logged games in
Supabase, the brand and domain, and how fast the next thing ships.

## Already done in the repo

- `LICENSE` — explicit all-rights-reserved. No open-source license is granted;
  viewing source in a browser conveys no rights.
- `_config.yml` — stops **GitHub Pages** publishing `CLAUDE.md` / `README.md`.
- `_redirects` — Cloudflare equivalent (404s the dev docs), plus a proper
  `200` rewrite for `/app/*` SPA deep links.
- `_headers` — `frame-ancestors 'self'` + `X-Frame-Options` so nobody can
  iframe momnts into their own site, plus `nosniff`, `Referrer-Policy`,
  `Permissions-Policy`.
- Copyright notices strengthened to "all rights reserved" on the landing page,
  FAQ, and both app footers.

`_redirects` and `_headers` are ignored by GitHub Pages, so they sit inert
until Cloudflare takes over. Nothing here breaks the current site.

## Steps

### 1. Verify the leak is closed (do this first, it's the urgent one)

Before anything else, check whether the build guide is currently public:

    curl -sI https://momntsapp.com/CLAUDE.md | head -1

A `200` means it is exposed right now. Merging `_config.yml` and letting Pages
rebuild should turn that into a `404`. Re-check before moving on.

### 2. Stand up Cloudflare Pages

1. Cloudflare dashboard → **Workers & Pages** → **Create** → **Pages** →
   **Connect to Git**, authorize GitHub, pick `nglanz29/momnts`.
2. Build settings: **framework preset = None**, **build command = empty**,
   **output directory = `/`**. There is no build step; the repo root is the site.
3. Deploy, then confirm the `*.pages.dev` preview URL works — landing page, FAQ,
   `/app/`, and a deep link like `/app/game-log` (should load with no redirect
   flash, since `_redirects` serves it `200`).

### 3. Point the domain at Cloudflare

1. In the Pages project → **Custom domains** → add `momntsapp.com` (and `www`).
2. Follow the DNS instructions. If the domain's nameservers aren't already on
   Cloudflare, moving them there is the simplest path.
3. Wait for the certificate to issue, then load `https://momntsapp.com`.

**Do not skip the verification below before turning GitHub Pages off** — if the
cutover is wrong, the site goes down.

### 4. Verify on the real domain

    curl -sI https://momntsapp.com/            | head -1   # 200
    curl -sI https://momntsapp.com/faq.html    | head -1   # 200
    curl -sI https://momntsapp.com/app/        | head -1   # 200
    curl -sI https://momntsapp.com/app/game-log| head -1   # 200 (not 404)
    curl -sI https://momntsapp.com/CLAUDE.md   | head -1   # 404
    curl -s  https://momntsapp.com/robots.txt             # Disallow: /app/

Then log into the app in a browser and confirm Supabase auth still works —
the Supabase project has an allowlist of redirect URLs and the origin is
unchanged, so it should, but confirm rather than assume.

### 5. Turn off GitHub Pages, then flip the repo private

Only once step 4 passes:

1. Repo **Settings → Pages** → set Source to **None**.
2. Repo **Settings → General → Danger Zone → Change visibility → Private**.

### 6. After going private

- **Actions still work.** Private repos on the Free plan get 2,000 Actions
  minutes/month; the daily Supabase keepalive uses roughly 10, so it keeps
  running.
- The `CNAME` file becomes vestigial (it's GitHub Pages-specific). Harmless to
  keep, and worth keeping if Pages might ever come back.
- Cloudflare redeploys on every push to `main`, same as Pages did.

## Still worth doing

The RLS audit. The Supabase anon key is public by design and always will be —
it ships in the client. That is only safe if row-level security is correct on
every table (`profiles`, `follows`, `mutes`, `blocks`, `reports`,
`notifications`, `app_state`, `tag_requests`, `profile_showcase`). A missing or
loose policy means anyone with that key — which is everyone — can read or
modify other users' data. That is a far bigger risk than someone cloning the UI.
