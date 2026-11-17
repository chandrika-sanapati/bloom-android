create table if not exists public.plant_profiles (
  id text primary key,
  common_name text not null,
  scientific_name text not null,
  asset_key text not null,
  min_interval_days integer not null check (min_interval_days > 0),
  max_interval_days integer not null check (max_interval_days >= min_interval_days),
  starting_interval_days integer not null check (
    starting_interval_days between min_interval_days and max_interval_days
  ),
  care_cue text not null,
  light_requirement text not null,
  light_placement text not null,
  light_source_url text not null,
  light_version integer not null default 1 check (light_version > 0),
  content_version integer not null default 1 check (content_version > 0),
  review_status text not null default 'reviewed' check (review_status in ('reviewed', 'unreviewed')),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.plant_profile_aliases (
  profile_id text not null references public.plant_profiles(id) on delete cascade,
  alias text not null,
  normalized_alias text primary key,
  created_at timestamptz not null default now()
);

alter table public.plant_profiles enable row level security;
alter table public.plant_profile_aliases enable row level security;

drop policy if exists "profiles are readable by authenticated users" on public.plant_profiles;
create policy "profiles are readable by authenticated users"
  on public.plant_profiles for select to authenticated using (active = true);

drop policy if exists "aliases are readable by authenticated users" on public.plant_profile_aliases;
create policy "aliases are readable by authenticated users"
  on public.plant_profile_aliases for select to authenticated using (true);
