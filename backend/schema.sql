-- ─────────────────────────────────────────────────────────────
-- TogetherIRL Database Schema
-- Run this in Supabase Dashboard → SQL Editor
-- ─────────────────────────────────────────────────────────────

-- ── 1. PROFILES ───────────────────────────────────────────────
-- Extends Supabase auth.users with app-specific profile data.
-- A row is created automatically when a user signs up (see trigger below).
create table if not exists profiles (
  id                      uuid primary key references auth.users(id) on delete cascade,
  display_name            text,
  avatar_url              text,
  bio                     text,
  dietary_restrictions    text[]  default '{}',
  max_travel_distance_km  integer default 10,
  updated_at              timestamptz default now()
);

-- Auto-create a profile row when a new user signs up
create or replace function handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into profiles (id, display_name, avatar_url)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'display_name', split_part(new.email, '@', 1)),
    new.raw_user_meta_data->>'avatar_url'
  );
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure handle_new_user();


-- ── 2. GROUPS ─────────────────────────────────────────────────
create table if not exists groups (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  description text,
  emoji       text default '🎉',
  created_by  uuid references auth.users(id) on delete set null,
  created_at  timestamptz default now()
);


-- ── 3. GROUP MEMBERS ──────────────────────────────────────────
create table if not exists group_members (
  group_id   uuid references groups(id) on delete cascade,
  user_id    uuid references auth.users(id) on delete cascade,
  role       text not null default 'member' check (role in ('admin', 'member')),
  status     text not null default 'active' check (status in ('active', 'left', 'removed')),
  joined_at  timestamptz default now(),
  primary key (group_id, user_id)
);


-- ── 4. GROUP INVITES ──────────────────────────────────────────
create table if not exists group_invites (
  id               uuid primary key default gen_random_uuid(),
  group_id         uuid references groups(id) on delete cascade,
  invited_user_id  uuid references auth.users(id) on delete cascade,
  invited_by       uuid references auth.users(id) on delete set null,
  status           text not null default 'pending' check (status in ('pending', 'accepted', 'declined')),
  expires_at       timestamptz not null,
  created_at       timestamptz default now()
);


-- ── 5. HANGOUT PLANS ──────────────────────────────────────────
create table if not exists hangout_plans (
  id          uuid primary key default gen_random_uuid(),
  group_id    uuid references groups(id) on delete cascade,
  created_by  uuid references auth.users(id) on delete set null,
  title       text not null default 'Hangout',
  status      text not null default 'collecting_preferences'
                check (status in ('collecting_preferences', 'planning', 'confirmed', 'completed')),
  planned_for timestamptz,
  created_at  timestamptz default now(),
  updated_at  timestamptz default now()
);


-- ── 6. HANGOUT PREFERENCES ────────────────────────────────────
-- One row per user per hangout. Upserted each time they update.
create table if not exists hangout_preferences (
  hangout_plan_id         uuid references hangout_plans(id) on delete cascade,
  user_id                 uuid references auth.users(id) on delete cascade,
  budget_range            text check (budget_range in ('$', '$$', '$$$')),
  activity_types          text[] default '{}',
  food_preferences        text[] default '{}',
  available_from          timestamptz,
  available_until         timestamptz,
  max_travel_distance_km  integer,
  notes                   text,
  updated_at              timestamptz default now(),
  primary key (hangout_plan_id, user_id)
);


-- ── 7. VIEWS ──────────────────────────────────────────────────

-- Who has/hasn't submitted preferences for a hangout
create or replace view hangout_response_status as
select
  gm.group_id,
  hp.id as hangout_plan_id,
  gm.user_id,
  p.display_name,
  p.avatar_url,
  case when pref.user_id is not null then true else false end as has_submitted
from hangout_plans hp
join group_members gm on gm.group_id = hp.group_id and gm.status = 'active'
join profiles p on p.id = gm.user_id
left join hangout_preferences pref
  on pref.hangout_plan_id = hp.id and pref.user_id = gm.user_id;


-- All preferences for a hangout merged with permanent dietary restrictions
create or replace view hangout_member_constraints as
select
  pref.hangout_plan_id,
  pref.user_id,
  p.display_name,
  p.avatar_url,
  pref.budget_range,
  pref.activity_types,
  pref.food_preferences,
  pref.available_from,
  pref.available_until,
  pref.max_travel_distance_km,
  pref.notes,
  -- Merge per-hangout dietary notes with the permanent profile restrictions
  array_cat(
    pref.food_preferences,
    coalesce(p.dietary_restrictions, '{}')
  ) as all_dietary_constraints
from hangout_preferences pref
join profiles p on p.id = pref.user_id;


-- ── 8. ROW LEVEL SECURITY ─────────────────────────────────────
-- The Dart backend uses the service role key which bypasses RLS.
-- Enabling RLS here ensures direct client access is locked down.
alter table profiles          enable row level security;
alter table groups            enable row level security;
alter table group_members     enable row level security;
alter table group_invites     enable row level security;
alter table hangout_plans     enable row level security;
alter table hangout_preferences enable row level security;


-- ── 9. INDEXES ────────────────────────────────────────────────
create index if not exists idx_group_members_user    on group_members(user_id);
create index if not exists idx_group_members_group   on group_members(group_id);
create index if not exists idx_group_invites_user    on group_invites(invited_user_id);
create index if not exists idx_hangout_plans_group   on hangout_plans(group_id);
create index if not exists idx_hangout_prefs_plan    on hangout_preferences(hangout_plan_id);
