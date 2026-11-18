-- ============================================================
-- Western Region History Museum — notifications (Updates) setup
-- Run once in the Supabase SQL editor (project western-region-passport).
-- Safe to run more than once: every statement is idempotent.
--
-- What this does:
--   Creates public.notifications, the rows behind the museum's
--   Updates sheet and the admin panel's "Send an update" form.
--   Anyone may READ updates (they are the museum's public news);
--   only admins (public.wr_is_admin(), from admin-phase2-setup.sql)
--   may insert, update, or delete them.
--
-- NOTE: the admin policies below call public.wr_is_admin(), which
-- admin-phase2-setup.sql creates. Run admin-phase2-setup.sql first
-- if it has not been run yet (it was run on Nov 18, 2026).
-- ============================================================

create table if not exists public.notifications (
  id bigint generated always as identity primary key,
  title text,
  body text,
  target text,
  kind text,
  created_at timestamptz not null default now()
);

alter table public.notifications enable row level security;

-- Anyone may read updates.
drop policy if exists "notifications public read" on public.notifications;
create policy "notifications public read" on public.notifications
  for select using (true);

-- Admins only: insert / update / delete.
drop policy if exists "notifications admin insert" on public.notifications;
create policy "notifications admin insert" on public.notifications
  for insert with check (public.wr_is_admin());

drop policy if exists "notifications admin update" on public.notifications;
create policy "notifications admin update" on public.notifications
  for update using (public.wr_is_admin()) with check (public.wr_is_admin());

drop policy if exists "notifications admin delete" on public.notifications;
create policy "notifications admin delete" on public.notifications
  for delete using (public.wr_is_admin());
