-- =====================================================================
-- Western Region History Museum — Phase 2: the admin panel's back end
-- Project: wlyfawqpsozcclwztmpv (the museum's own Supabase project)
--
-- WHAT THIS DOES
-- Gives the museum's admin panel (the admin/ page of the museum site)
-- everything it needs, and nothing more:
--   1. A session column on the usage log, so the panel can report how
--      long a visit lasted (the museum already sends a session id
--      with every event once this column exists; until it does, the
--      extra field is simply ignored by the log's insert).
--   2. An admins list. The panel's front door is an email + password
--      sign-in; only emails on this list get in. The first admin is
--      seeded below; more are added from the panel's Admins screen.
--   3. An activity log: every change made from the panel is written
--      here (who, what, when), and the panel's Activity screen reads
--      it back.
--   4. Review state on share submissions (status: new / approved /
--      on hold / rejected), plus the panel's right to read and update
--      them and to view the files visitors shared.
--   5. Panel rights, all keyed to the admins list: write museum
--      content, read the usage log, manage the uploads bucket, read
--      member accounts and passport stamps, switch a member account
--      off or on, and remove a guest book signature.
--   6. The master chapter list (the conference app's official list of
--      50 Active chapters) as a chapters table the panel reads.
--
-- HOW TO RUN
-- Run AFTER phase1-supabase.sql, phase1-supabase-timeline.sql, and
-- phase1-supabase-aurora-seed.sql. Supabase dashboard -> SQL Editor
-- -> New query -> paste -> Run. Idempotent: safe to run again.
--
-- SECURITY SHAPE
-- Nothing here widens what a visitor can do. Every new right is
-- limited to signed-in accounts whose email is on the admins list,
-- checked by public.wr_is_admin(). The panel never holds a service
-- key; it signs in as a person and the rules below do the rest.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Usage log: session column (visit length in the panel's numbers)
-- ---------------------------------------------------------------------
alter table public.museum_usage add column if not exists session_id text;

-- (Defensive: the draft/publish column arrives with
-- phase1-supabase-timeline.sql; this line makes this file safe even
-- if it is run before that one.)
alter table public.museum_content add column if not exists status text not null default 'published';

-- ---------------------------------------------------------------------
-- 2. The admins list + the is-admin check
-- ---------------------------------------------------------------------
create table if not exists public.admins (
  email      text primary key,
  name       text,
  created_at timestamptz not null default now()
);

alter table public.admins enable row level security;

-- The check every Phase 2 rule uses. Security definer so the rules
-- can read the admins list without recursing into its own policies.
create or replace function public.wr_is_admin()
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1 from public.admins a
    where a.email = (auth.jwt() ->> 'email')
  );
$$;

grant execute on function public.wr_is_admin() to authenticated;

-- A signed-in person may read her own admins row (the panel's gate
-- check) and any admin may read the whole list.
drop policy if exists "Admins: read own row or any admin reads all" on public.admins;
create policy "Admins: read own row or any admin reads all"
  on public.admins
  for select
  to authenticated
  using (email = (auth.jwt() ->> 'email') or public.wr_is_admin());

-- Only an admin may add an admin.
drop policy if exists "Admins: admins may add" on public.admins;
create policy "Admins: admins may add"
  on public.admins
  for insert
  to authenticated
  with check (public.wr_is_admin());

-- Only an admin may change an admin's name.
drop policy if exists "Admins: admins may update" on public.admins;
create policy "Admins: admins may update"
  on public.admins
  for update
  to authenticated
  using (public.wr_is_admin())
  with check (public.wr_is_admin());

-- Only an admin may remove an admin. (The panel itself refuses to
-- remove the last admin on the list.)
drop policy if exists "Admins: admins may remove" on public.admins;
create policy "Admins: admins may remove"
  on public.admins
  for delete
  to authenticated
  using (public.wr_is_admin());

-- The first admin. She signs in at the panel with this email; the
-- panel's "Email me a sign-in link instead" path lets her in the
-- first time, and she sets her password inside the panel. Add every
-- other admin from the panel's Admins screen, not from here.
insert into public.admins (email, name)
values ('epistoleus@westernsgrho.org', 'Patience Walton')
on conflict (email) do nothing;

-- ---------------------------------------------------------------------
-- 3. The activity log (the panel writes a line for every change)
-- ---------------------------------------------------------------------
create table if not exists public.activity_log (
  id          bigint generated always as identity primary key,
  admin_email text,
  action      text,
  detail      text,
  created_at  timestamptz not null default now()
);

alter table public.activity_log enable row level security;

drop policy if exists "Activity log: admins may write" on public.activity_log;
create policy "Activity log: admins may write"
  on public.activity_log
  for insert
  to authenticated
  with check (public.wr_is_admin());

drop policy if exists "Activity log: admins may read" on public.activity_log;
create policy "Activity log: admins may read"
  on public.activity_log
  for select
  to authenticated
  using (public.wr_is_admin());

-- ---------------------------------------------------------------------
-- 4. Museum content: admins may write (visitors keep read-only)
-- ---------------------------------------------------------------------
drop policy if exists "Museum content: admins may add" on public.museum_content;
create policy "Museum content: admins may add"
  on public.museum_content
  for insert
  to authenticated
  with check (public.wr_is_admin());

drop policy if exists "Museum content: admins may change" on public.museum_content;
create policy "Museum content: admins may change"
  on public.museum_content
  for update
  to authenticated
  using (public.wr_is_admin())
  with check (public.wr_is_admin());

drop policy if exists "Museum content: admins may remove" on public.museum_content;
create policy "Museum content: admins may remove"
  on public.museum_content
  for delete
  to authenticated
  using (public.wr_is_admin());

-- ---------------------------------------------------------------------
-- 5. Usage log: admins may read the numbers (visitors may only add)
-- ---------------------------------------------------------------------
drop policy if exists "Museum usage: admins may read" on public.museum_usage;
create policy "Museum usage: admins may read"
  on public.museum_usage
  for select
  to authenticated
  using (public.wr_is_admin());

-- ---------------------------------------------------------------------
-- 6. Share submissions: review state + the panel's review rights
-- ---------------------------------------------------------------------
alter table public.museum_submissions add column if not exists status text not null default 'new';
alter table public.museum_submissions add column if not exists reviewed_by text;
alter table public.museum_submissions add column if not exists reviewed_at timestamptz;

drop policy if exists "Museum submissions: admins may read" on public.museum_submissions;
create policy "Museum submissions: admins may read"
  on public.museum_submissions
  for select
  to authenticated
  using (public.wr_is_admin());

drop policy if exists "Museum submissions: admins may update" on public.museum_submissions;
create policy "Museum submissions: admins may update"
  on public.museum_submissions
  for update
  to authenticated
  using (public.wr_is_admin())
  with check (public.wr_is_admin());

-- The files visitors shared sit in the private museum-submissions
-- bucket: an admin may view them (the panel opens a signed link) and
-- remove one. Visitor uploading is unchanged.
drop policy if exists "Museum submissions: admins may view shared files" on storage.objects;
create policy "Museum submissions: admins may view shared files"
  on storage.objects
  for select
  to authenticated
  using (bucket_id = 'museum-submissions' and public.wr_is_admin());

drop policy if exists "Museum submissions: admins may remove shared files" on storage.objects;
create policy "Museum submissions: admins may remove shared files"
  on storage.objects
  for delete
  to authenticated
  using (bucket_id = 'museum-submissions' and public.wr_is_admin());

-- ---------------------------------------------------------------------
-- 7. The uploads bucket: the panel's photo and recording shelf.
-- Panel uploads must be reachable by museum visitors (a story's
-- photo or recording is stored here and the museum plays it from
-- its link), so the bucket is public to read; only admins may put
-- files in, change them, or take them out.
-- ---------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('museum-uploads', 'museum-uploads', true)
on conflict (id) do update set public = true;

drop policy if exists "Museum uploads: everyone may view" on storage.objects;
create policy "Museum uploads: everyone may view"
  on storage.objects
  for select
  using (bucket_id = 'museum-uploads');

drop policy if exists "Museum uploads: admins may add" on storage.objects;
create policy "Museum uploads: admins may add"
  on storage.objects
  for insert
  to authenticated
  with check (bucket_id = 'museum-uploads' and public.wr_is_admin());

drop policy if exists "Museum uploads: admins may change" on storage.objects;
create policy "Museum uploads: admins may change"
  on storage.objects
  for update
  to authenticated
  using (bucket_id = 'museum-uploads' and public.wr_is_admin())
  with check (bucket_id = 'museum-uploads' and public.wr_is_admin());

drop policy if exists "Museum uploads: admins may remove" on storage.objects;
create policy "Museum uploads: admins may remove"
  on storage.objects
  for delete
  to authenticated
  using (bucket_id = 'museum-uploads' and public.wr_is_admin());

-- ---------------------------------------------------------------------
-- 8. Member accounts: the panel's Members screen reads passport
-- holders and stamps, and can switch an account off or back on.
-- The deactivated flag is the panel's switch; the museum itself
-- does not read it yet, so switching an account off today records
-- the decision and the panel shows it — enforcement inside the
-- museum is a later wiring step, named here so it is not assumed.
-- ---------------------------------------------------------------------
alter table public.passport_walkers add column if not exists deactivated boolean not null default false;

drop policy if exists "Passport holders: admins may read" on public.passport_walkers;
create policy "Passport holders: admins may read"
  on public.passport_walkers
  for select
  to authenticated
  using (public.wr_is_admin());

drop policy if exists "Passport holders: admins may update" on public.passport_walkers;
create policy "Passport holders: admins may update"
  on public.passport_walkers
  for update
  to authenticated
  using (public.wr_is_admin())
  with check (public.wr_is_admin());

drop policy if exists "Passport stamps: admins may read" on public.passport_stamps;
create policy "Passport stamps: admins may read"
  on public.passport_stamps
  for select
  to authenticated
  using (public.wr_is_admin());

-- Guest book: an admin may read every signature and remove one
-- (the wall itself stays public reading, signing stays public).
drop policy if exists "Guest book: admins may remove a signature" on public.guestbook;
create policy "Guest book: admins may remove a signature"
  on public.guestbook
  for delete
  to authenticated
  using (public.wr_is_admin());

-- ---------------------------------------------------------------------
-- 9. The master chapter list — the conference app's official list
-- of 50 Active chapters (name, city, kind), so a chapter is spelled
-- one way everywhere. Seeded from the Western Region chapter lists
-- held with the 2028 conference chapter data (Graduate and
-- Undergraduate lists, Status = Active only). One name is carried
-- exactly as the source list prints it: Xi Alpha Sigma, "Tokoyo
-- Japan" — fix the source list first, then correct it here.
-- ---------------------------------------------------------------------
create table if not exists public.chapters (
  name text primary key,
  city text,
  type text
);

alter table public.chapters enable row level security;

drop policy if exists "Chapters are readable by everyone" on public.chapters;
create policy "Chapters are readable by everyone"
  on public.chapters
  for select
  using (true);

drop policy if exists "Chapters: admins may add" on public.chapters;
create policy "Chapters: admins may add"
  on public.chapters
  for insert
  to authenticated
  with check (public.wr_is_admin());

drop policy if exists "Chapters: admins may change" on public.chapters;
create policy "Chapters: admins may change"
  on public.chapters
  for update
  to authenticated
  using (public.wr_is_admin())
  with check (public.wr_is_admin());

drop policy if exists "Chapters: admins may remove" on public.chapters;
create policy "Chapters: admins may remove"
  on public.chapters
  for delete
  to authenticated
  using (public.wr_is_admin());

insert into public.chapters (name, city, type) values
  ('Beta Eta Sigma', 'Portland OR', 'Graduate'),
  ('Beta Mu Sigma', 'Phoenix AZ', 'Graduate'),
  ('Beta Nu Sigma', 'San Diego CA', 'Graduate'),
  ('Beta Rho Sigma', 'Denver CO', 'Graduate'),
  ('Beta Theta Sigma', 'Bay Area CA', 'Graduate'),
  ('Delta Psi Sigma', 'Seattle WA', 'Graduate'),
  ('Delta Zeta Sigma', 'Compton CA', 'Graduate'),
  ('Epsilon Chi Sigma', 'Lancaster CA', 'Graduate'),
  ('Eta Alpha Sigma', 'Sacramento CA', 'Graduate'),
  ('Eta Beta Sigma', 'Albuquerque NM', 'Graduate'),
  ('Eta Chi Sigma', 'Las Vegas NV', 'Graduate'),
  ('Gamma Alpha Sigma', 'Bakersfield CA', 'Graduate'),
  ('Gamma Tau Sigma', 'Long Beach CA', 'Graduate'),
  ('Iota Beta Sigma', 'Silicon Valley CA', 'Graduate'),
  ('Kappa Eta Sigma', 'Tempe AZ', 'Graduate'),
  ('Kappa Nu Sigma', 'San Fernando Valley CA', 'Graduate'),
  ('Kappa Sigma Sigma', 'Flagstaff AZ', 'Graduate'),
  ('Lambda Alpha Sigma', 'Tucson AZ', 'Graduate'),
  ('Lambda Gamma Sigma', 'Pomona CA', 'Graduate'),
  ('Lambda Mu Sigma', 'Honolulu HI', 'Graduate'),
  ('Lambda Rho Sigma', 'Santa Monica CA', 'Graduate'),
  ('Mu Chi Sigma', 'Stockton CA', 'Graduate'),
  ('Mu Phi Sigma', 'Dubai UAE', 'Graduate'),
  ('Mu Rho Sigma', 'Henderson NV', 'Graduate'),
  ('Nu Delta Sigma', 'San Bernardino CA', 'Graduate'),
  ('Sigma Sigma', 'Los Angeles CA', 'Graduate'),
  ('Theta Epsilon Sigma', 'Culver City CA', 'Graduate'),
  ('Theta Pi Sigma', 'Murrieta CA', 'Graduate'),
  ('Theta Upsilon Sigma', 'Inglewood CA', 'Graduate'),
  ('Theta Zeta Sigma', 'Aurora CO', 'Graduate'),
  ('Zeta Phi Sigma', 'Tacoma WA', 'Graduate'),
  ('Xi Alpha Sigma', 'Tokoyo Japan', 'Graduate'),
  ('Beta Pi', 'Tempe AZ', 'Undergraduate'),
  ('Beta Psi', 'Berkeley CA', 'Undergraduate'),
  ('Delta Gamma', 'San Diego CA', 'Undergraduate'),
  ('Epsilon Phi', 'Northridge CA', 'Undergraduate'),
  ('Eta Delta', 'San Diego CA', 'Undergraduate'),
  ('Mu Alpha', 'Los Angeles CA', 'Undergraduate'),
  ('Nu Eta', 'Las Vegas NV', 'Undergraduate'),
  ('Nu Upsilon', 'Tucson AZ', 'Undergraduate'),
  ('Omicron Mu', 'Fullerton CA', 'Undergraduate'),
  ('Omicron Rho', 'Carson CA', 'Undergraduate'),
  ('Pi Phi', 'San Francisco CA', 'Undergraduate'),
  ('Pi Rho', 'Pomona CA', 'Undergraduate'),
  ('Rho Eta', 'Los Angeles CA', 'Undergraduate'),
  ('Tau Nu', 'La Verne CA', 'Undergraduate'),
  ('Theta Epsilon', 'Los Angeles CA', 'Undergraduate'),
  ('Xi Epsilon', 'Sacramento CA', 'Undergraduate'),
  ('Xi Eta', 'Albuquerque NM', 'Undergraduate'),
  ('Xi Rho', 'Riverside CA', 'Undergraduate')
on conflict (name) do update set city = excluded.city, type = excluded.type;
