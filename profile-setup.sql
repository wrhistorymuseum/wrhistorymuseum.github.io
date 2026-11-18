-- ============================================================
-- Western Region History Museum — profile photos setup
-- Run once in the Supabase SQL editor (project western-region-passport).
-- Safe to run more than once: every statement is idempotent.
--
-- What this does:
--   1. Adds a photo_url column to passport_walkers, where the museum
--      saves the public address of a walker's profile photo.
--   2. Creates the public storage bucket "profile-photos" that holds
--      the (small, on-device resized) profile photos.
--   3. Storage policies: anyone may read a photo, anyone may add one.
--      Photos are small and public by design — a profile photo is
--      shown beside a walker's name in the museum, so there is no
--      private photo to protect. Update/delete are intentionally NOT
--      opened up: the museum only ever adds a new photo file and
--      points photo_url at it, so no update or delete policy is
--      needed for visitors. (Per-file "owner" rules are not
--      enforceable for anonymous uploads, which is another reason to
--      keep this to read + insert only.)
--
-- The museum's passport_walkers write path does not change: the
-- signed-in upsert (museum + passport page) already carries the
-- walker's own row, and the photo_url value rides along in that same
-- upsert. The walker's own-row policies from admin-phase2-setup.sql
-- (insert/update where auth.uid() = user_id) already cover saving
-- photo_url, so no new table policy is required here.
-- ============================================================

-- 1. photo_url on passport_walkers --------------------------------
alter table public.passport_walkers
  add column if not exists photo_url text;

-- 2. Public bucket for profile photos ------------------------------
insert into storage.buckets (id, name, public)
values ('profile-photos', 'profile-photos', true)
on conflict (id) do nothing;

-- 3. Storage policies ----------------------------------------------
-- Public read: anyone can view a profile photo.
drop policy if exists "profile photos public read" on storage.objects;
create policy "profile photos public read" on storage.objects
  for select using (bucket_id = 'profile-photos');

-- Public insert: a signed-in walker can add her (resized) photo.
-- The museum uploads under her own user id as the first folder, but
-- the policy stays simple on purpose; see the note at the top.
drop policy if exists "profile photos public insert" on storage.objects;
create policy "profile photos public insert" on storage.objects
  for insert with check (bucket_id = 'profile-photos');
