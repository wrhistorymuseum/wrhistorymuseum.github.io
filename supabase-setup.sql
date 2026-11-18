-- =====================================================================
-- Western Region History Museum — one-time Supabase setup
-- Project: wlyfawqpsozcclwztmpv (the museum passport's project)
--
-- THE SWITCH FOR THE SHARED GUEST BOOK:
-- Run this once in the Supabase dashboard (SQL Editor → New query →
-- paste → Run). Until it is run, the museum's guest book saves each
-- signature on the visitor's own device and shows the signatures kept
-- there. Once it is run, signatures are shared: every visitor sees
-- the same wall, on every device.
--
-- The passport's own tables (passport_walkers, passport_stamps)
-- already exist and are not touched here.
-- =====================================================================

create table if not exists public.guestbook (
  id          bigint generated always as identity primary key,
  name        text not null,
  chapter     text not null,
  year_joined text,
  created_at  timestamptz not null default now()
);

-- A signature may carry a message, left with the guest book entry.
-- (For a guestbook table created before the message field existed,
-- this line adds the column; it is safe to run either way.)
alter table public.guestbook add column if not exists message text;

alter table public.guestbook enable row level security;

-- The wall is public reading: any visitor may read the signatures.
drop policy if exists "Guest book is readable by everyone" on public.guestbook;
create policy "Guest book is readable by everyone"
  on public.guestbook
  for select
  using (true);

-- Signing is public writing: any visitor may add her signature.
-- (No update or delete policy is created, so signatures cannot be
-- edited or removed through the public key.)
drop policy if exists "Anyone may sign the guest book" on public.guestbook;
create policy "Anyone may sign the guest book"
  on public.guestbook
  for insert
  with check (true);

-- =====================================================================
-- Founders Month (pass 3): the Chapter Quiz Board and the Chapter
-- Check-In map. These two tables ride along in the same one-time
-- setup — run them with the rest of this file. Same pattern as the
-- guest book: public reading, public writing, and no
-- update or delete, so a score or a check-in cannot be edited or
-- removed through the public key. Until they exist, the board and
-- the map keep each visitor's records on her own device.
-- =====================================================================

create table if not exists public.chapter_quiz (
  id         bigint generated always as identity primary key,
  chapter    text not null,
  score      integer not null,
  total      integer not null,
  created_at timestamptz not null default now()
);

alter table public.chapter_quiz enable row level security;

-- The standings are public reading: any visitor may read the board.
drop policy if exists "Chapter quiz board is readable by everyone" on public.chapter_quiz;
create policy "Chapter quiz board is readable by everyone"
  on public.chapter_quiz
  for select
  using (true);

-- A finished quiz is public writing: the quiz page may record a score.
drop policy if exists "Anyone may record a chapter quiz score" on public.chapter_quiz;
create policy "Anyone may record a chapter quiz score"
  on public.chapter_quiz
  for insert
  with check (true);

create table if not exists public.chapter_checkins (
  id         bigint generated always as identity primary key,
  chapter    text not null,
  state      text not null,
  created_at timestamptz not null default now()
);

alter table public.chapter_checkins enable row level security;

-- The map is public reading: any visitor may read the check-ins.
drop policy if exists "Chapter check-ins are readable by everyone" on public.chapter_checkins;
create policy "Chapter check-ins are readable by everyone"
  on public.chapter_checkins
  for select
  using (true);

-- Checking in is public writing: any visitor may add her chapter.
drop policy if exists "Anyone may check in a chapter" on public.chapter_checkins;
create policy "Anyone may check in a chapter"
  on public.chapter_checkins
  for insert
  with check (true);


-- =====================================================================
-- Share with the Museum (pass 6): the on-page share form.
-- PUBLISH-TIME STEP: run this section once in the same SQL Editor,
-- with the rest of this file, when the updated museum is published.
-- It creates the private storage bucket the form uploads to and the
-- submissions table the form writes. Submissions are for History &
-- Archives review only: the public key may add a submission and
-- upload a file, and may NOT read either back — no select policy is
-- created for the table, and the bucket is not public.
-- =====================================================================

insert into storage.buckets (id, name, public)
values ('museum-submissions', 'museum-submissions', false)
on conflict (id) do nothing;

-- A share may carry one file: the form may upload it to the bucket.
-- (No select, update, or delete policy is created for the bucket's
-- objects, so a shared file cannot be read, changed, or removed
-- through the public key.)
drop policy if exists "Museum submissions: anyone may upload a shared file" on storage.objects;
create policy "Museum submissions: anyone may upload a shared file"
  on storage.objects
  for insert
  with check (bucket_id = 'museum-submissions');

create table if not exists public.museum_submissions (
  id          bigint generated always as identity primary key,
  name        text,
  chapter     text,
  kind        text,
  description text,
  file_path   text,
  created_at  timestamptz not null default now()
);

alter table public.museum_submissions enable row level security;

-- Sharing is public writing: the form may add a submission.
-- (No select policy is created, so submissions cannot be read
-- through the public key; History & Archives reviews them in the
-- Supabase dashboard.)
drop policy if exists "Anyone may share with the museum" on public.museum_submissions;
create policy "Anyone may share with the museum"
  on public.museum_submissions
  for insert
  with check (true);
