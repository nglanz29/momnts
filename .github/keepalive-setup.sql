-- Supabase keepalive setup — run once in the Supabase SQL Editor.
--
-- Why this exists: the free tier auto-pauses a project after ~7 days of
-- inactivity. The keepalive workflow (.github/workflows/keepalive.yml) pings
-- the project on a schedule. A read alone may not reset Supabase's inactivity
-- timer, so the workflow performs a real WRITE against the table below.
--
-- Safety note: the anon key is public by design (it ships in the client app at
-- momntsapp.com/app/), so anything anon can do here must be harmless if a
-- stranger does it. This grants anon exactly two things — read row 1, and
-- update row 1's timestamp. No insert, no delete, no other rows. Worst case a
-- stranger sets a timestamp, which is what the workflow does anyway.

create table if not exists public.keepalive (
  id        int primary key,
  last_ping timestamptz not null default now()
);

-- The single row the workflow updates.
insert into public.keepalive (id, last_ping)
values (1, now())
on conflict (id) do nothing;

alter table public.keepalive enable row level security;

-- anon may read only row 1.
drop policy if exists keepalive_anon_select on public.keepalive;
create policy keepalive_anon_select on public.keepalive
  for select to anon
  using (id = 1);

-- anon may update only row 1, and may not move it to another id.
drop policy if exists keepalive_anon_update on public.keepalive;
create policy keepalive_anon_update on public.keepalive
  for update to anon
  using (id = 1)
  with check (id = 1);

-- Deliberately NO insert or delete policy: anon cannot add or remove rows,
-- so the table stays exactly one row and cannot be used to fill your database.
