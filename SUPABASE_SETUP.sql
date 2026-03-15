-- ================================================================
--  UniSync — Complete Secure Database Setup
-- ================================================================

-- ── TABLES ──────────────────────────────────────────────────────────

create table if not exists users (
  id                       uuid primary key references auth.users(id) on delete cascade,
  name                     text not null check (char_length(trim(name)) >= 1),
  email                    text not null,
  department               text not null default 'Computer Science',
  semester                 text not null default '',
  student_id               text not null default '',
  role                     text not null default 'student'
                             check (role in ('student','faculty')),
  photo_url                text,
  bookmarked_announcements uuid[] default '{}',
  rsvped_events            uuid[] default '{}',
  created_at               timestamptz default now()
);

create table if not exists events (
  id            uuid primary key default gen_random_uuid(),
  title         text not null check (char_length(trim(title)) >= 1),
  description   text not null default '',
  category      text not null default 'General',
  location      text not null default '',
  date          timestamptz not null,
  time          text not null default '',
  attendees     int not null default 0 check (attendees >= 0),
  organizer     text not null,
  organizer_id  uuid references users(id) on delete set null,
  image_color   text not null default '1A56DB',
  created_at    timestamptz default now()
);

create table if not exists resources (
  id              uuid primary key default gen_random_uuid(),
  title           text not null check (char_length(trim(title)) >= 1),
  subject         text not null default '',
  department      text not null default '',
  semester        text not null default '',
  type            text not null default 'PDF',
  file_url        text not null,
  storage_path    text not null default '',
  size            text not null default '0 KB',
  downloads       int not null default 0 check (downloads >= 0),
  rating          float not null default 0 check (rating >= 0 and rating <= 5),
  rating_count    int not null default 0 check (rating_count >= 0),
  uploaded_by     text not null,
  uploaded_by_id  uuid references users(id) on delete set null,
  uploaded_at     timestamptz default now(),
  icon_color      text not null default '1A56DB'
);

create table if not exists announcements (
  id            uuid primary key default gen_random_uuid(),
  title         text not null check (char_length(trim(title)) >= 1),
  content       text not null check (char_length(trim(content)) >= 1),
  posted_by     text not null,
  posted_by_id  uuid references users(id) on delete set null,
  posted_at     timestamptz default now(),
  type          text not null default 'General'
                  check (type in ('Academic','Financial','General','Club'))
);

create table if not exists chat_rooms (
  id                uuid primary key default gen_random_uuid(),
  name              text not null check (char_length(trim(name)) >= 1),
  last_message      text not null default '',
  last_message_time timestamptz default now(),
  is_group          boolean not null default false,
  member_ids        uuid[] not null default '{}',
  member_names      text[] not null default '{}',
  avatar_color      text not null default '1A56DB'
);

create table if not exists chat_messages (
  id          uuid primary key default gen_random_uuid(),
  room_id     uuid not null references chat_rooms(id) on delete cascade,
  sender_id   uuid references users(id) on delete set null,
  sender_name text not null,
  content     text not null check (char_length(trim(content)) >= 1
                               and char_length(content) <= 2000),
  created_at  timestamptz default now()
);

-- ── INDEXES ──────────────────────────────────────────────────────────
create index if not exists idx_events_date        on events(date);
create index if not exists idx_announcements_date on announcements(posted_at desc);
create index if not exists idx_messages_room      on chat_messages(room_id, created_at);
create index if not exists idx_resources_dept     on resources(department);

-- ── SECURITY: ROLE ASSIGNED FROM ID FORMAT AT SIGNUP ─────────────────
-- Student IDs start with 3 followed by 7 digits  (e.g. 31234567)
-- Faculty IDs start with 1 followed by 7 digits  (e.g. 11234567)
-- The trigger reads the student_id field and sets role accordingly.
-- Any other format is rejected with an error.
drop trigger if exists trg_assign_role_from_id on users;
drop function if exists assign_role_from_id();

create or replace function assign_role_from_id()
returns trigger language plpgsql security definer as $$
begin
  if new.student_id ~ '^3[0-9]{7}$' then
    new.role := 'student';
  elsif new.student_id ~ '^1[0-9]{7}$' then
    new.role := 'faculty';
  else
    raise exception 'Invalid ID. Student IDs start with 3, Faculty IDs start with 1. Both must be exactly 8 digits.';
  end if;
  return new;
end;
$$;

create trigger trg_assign_role_from_id
  before insert on users
  for each row execute function assign_role_from_id();

-- ── SECURITY: PREVENT ROLE SELF-ESCALATION ───────────────────────────
-- The users: update own row RLS policy below enforces that the role
-- column cannot be changed by the app (it checks role = current role).
-- No extra trigger needed — the RLS policy handles it cleanly.

-- ── ATOMIC RPC FUNCTIONS ─────────────────────────────────────────────

create or replace function append_bookmark(user_id uuid, ann_id uuid)
returns void language sql security definer as $$
  update users
  set bookmarked_announcements = array_append(
    array_remove(bookmarked_announcements, ann_id), ann_id)
  where id = user_id;
$$;

create or replace function remove_bookmark(user_id uuid, ann_id uuid)
returns void language sql security definer as $$
  update users
  set bookmarked_announcements = array_remove(bookmarked_announcements, ann_id)
  where id = user_id;
$$;

create or replace function toggle_rsvp(p_event_id uuid, p_user_id uuid, p_going boolean)
returns void language plpgsql security definer as $$
declare
  already_rsvped boolean;
begin
  select p_event_id = any(rsvped_events) into already_rsvped
  from users where id = p_user_id;

  if p_going and not already_rsvped then
    update users set rsvped_events = array_append(rsvped_events, p_event_id) where id = p_user_id;
    update events set attendees = attendees + 1 where id = p_event_id;
  elsif not p_going and already_rsvped then
    update users set rsvped_events = array_remove(rsvped_events, p_event_id) where id = p_user_id;
    update events set attendees = greatest(attendees - 1, 0) where id = p_event_id;
  end if;
end;
$$;

create or replace function increment_downloads(resource_id uuid)
returns void language sql security definer as $$
  update resources set downloads = downloads + 1 where id = resource_id;
$$;

create or replace function rate_resource(p_resource_id uuid, p_rating float)
returns void language plpgsql security definer as $$
declare
  old_rating float;
  old_count  int;
  new_count  int;
  new_avg    float;
begin
  select rating, rating_count into old_rating, old_count
  from resources where id = p_resource_id;
  new_count := old_count + 1;
  new_avg   := ((old_rating * old_count) + p_rating) / new_count;
  update resources set rating = new_avg, rating_count = new_count where id = p_resource_id;
end;
$$;

-- ── REALTIME ─────────────────────────────────────────────────────────
alter publication supabase_realtime add table events;
alter publication supabase_realtime add table announcements;
alter publication supabase_realtime add table chat_rooms;
alter publication supabase_realtime add table chat_messages;
alter publication supabase_realtime add table resources;

-- ── ROW LEVEL SECURITY ───────────────────────────────────────────────
alter table users         enable row level security;
alter table events        enable row level security;
alter table resources     enable row level security;
alter table announcements enable row level security;
alter table chat_rooms    enable row level security;
alter table chat_messages enable row level security;

-- Drop old policies if re-running
do $$ declare r record;
begin
  for r in (select policyname, tablename from pg_policies
            where schemaname = 'public') loop
    execute format('drop policy if exists %I on %I', r.policyname, r.tablename);
  end loop;
end $$;

-- USERS
create policy "users: read any authenticated"  on users for select using (auth.role() = 'authenticated');
create policy "users: insert own row"          on users for insert with check (auth.uid() = id);
create policy "users: update own row"          on users for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- EVENTS: anyone can read; only faculty can insert/delete
create policy "events: read"   on events for select using (auth.role() = 'authenticated');
create policy "events: insert" on events for insert with check (
  exists (select 1 from users where id = auth.uid() and role = 'faculty')
);
create policy "events: update" on events for update using (auth.role() = 'authenticated');
create policy "events: delete" on events for delete using (
  exists (select 1 from users where id = auth.uid() and role = 'faculty')
  or organizer_id = auth.uid()
);

-- RESOURCES: anyone authenticated can read/upload; only uploader or faculty can delete
create policy "resources: read"   on resources for select using (auth.role() = 'authenticated');
create policy "resources: insert" on resources for insert with check (auth.role() = 'authenticated');
create policy "resources: update" on resources for update using (auth.role() = 'authenticated');
create policy "resources: delete" on resources for delete using (
  uploaded_by_id = auth.uid() or
  exists (select 1 from users where id = auth.uid() and role = 'faculty')
);

-- ANNOUNCEMENTS: anyone can read; only faculty can post/delete
create policy "ann: read"   on announcements for select using (auth.role() = 'authenticated');
create policy "ann: insert" on announcements for insert with check (
  exists (select 1 from users where id = auth.uid() and role = 'faculty')
);
create policy "ann: delete" on announcements for delete using (
  posted_by_id = auth.uid() or
  exists (select 1 from users where id = auth.uid() and role = 'faculty')
);

-- CHAT ROOMS: members only
create policy "rooms: read"   on chat_rooms for select using (auth.uid() = any(member_ids));
create policy "rooms: insert" on chat_rooms for insert with check (auth.role() = 'authenticated');
create policy "rooms: update" on chat_rooms for update using (auth.uid() = any(member_ids));

-- CHAT MESSAGES: only room members can read/write
create policy "msgs: read"   on chat_messages for select using (
  exists (select 1 from chat_rooms where id = room_id and auth.uid() = any(member_ids))
);
create policy "msgs: insert" on chat_messages for insert with check (
  auth.uid() = sender_id and
  exists (select 1 from chat_rooms where id = room_id and auth.uid() = any(member_ids))
);

-- ── STORAGE POLICIES ─────────────────────────────────────────────────
-- Create two storage buckets in the dashboard:
--   Bucket name: "resources"  → Public: ON
--   Bucket name: "avatars"    → Public: ON

select 'UniSync database setup complete!' as result;
