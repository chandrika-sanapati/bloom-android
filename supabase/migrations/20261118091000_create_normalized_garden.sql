create table if not exists public.plant_collections (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users(id) on delete cascade,
  revision bigint not null default 0,
  preferences jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.plants (
  id text primary key,
  collection_id uuid not null references public.plant_collections(id) on delete cascade,
  plant_profile_id text references public.plant_profiles(id) on delete set null,
  display_name text,
  discovery_source text not null default 'catalog',
  light_placement jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.watering_schedules (
  plant_id text primary key references public.plants(id) on delete cascade,
  interval_days integer not null,
  next_check_at timestamptz not null,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  time_source text not null
);

create table if not exists public.watering_records (
  id text primary key,
  plant_id text not null references public.plants(id) on delete cascade,
  scheduled_for timestamptz not null,
  recorded_at timestamptz not null,
  outcome text not null,
  soil text not null
);

create table if not exists public.soil_care_events (
  id text primary key,
  plant_id text not null references public.plants(id) on delete cascade,
  occurred_on date not null,
  recorded_at timestamptz not null,
  actions jsonb not null,
  product text,
  notes text,
  mix_contains_feed boolean
);

alter table public.plant_collections enable row level security;
alter table public.plants enable row level security;
alter table public.watering_schedules enable row level security;
alter table public.watering_records enable row level security;
alter table public.soil_care_events enable row level security;

create policy "users own their collection" on public.plant_collections
  for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "users own their plants" on public.plants
  for all to authenticated using (exists (
    select 1 from public.plant_collections c where c.id = collection_id and c.user_id = auth.uid()
  )) with check (exists (
    select 1 from public.plant_collections c where c.id = collection_id and c.user_id = auth.uid()
  ));

create policy "users own their schedules" on public.watering_schedules
  for all to authenticated using (exists (
    select 1 from public.plants p join public.plant_collections c on c.id = p.collection_id
    where p.id = plant_id and c.user_id = auth.uid()
  )) with check (exists (
    select 1 from public.plants p join public.plant_collections c on c.id = p.collection_id
    where p.id = plant_id and c.user_id = auth.uid()
  ));

create policy "users own their watering records" on public.watering_records
  for all to authenticated using (exists (
    select 1 from public.plants p join public.plant_collections c on c.id = p.collection_id
    where p.id = plant_id and c.user_id = auth.uid()
  )) with check (exists (
    select 1 from public.plants p join public.plant_collections c on c.id = p.collection_id
    where p.id = plant_id and c.user_id = auth.uid()
  ));

create policy "users own their soil events" on public.soil_care_events
  for all to authenticated using (exists (
    select 1 from public.plants p join public.plant_collections c on c.id = p.collection_id
    where p.id = plant_id and c.user_id = auth.uid()
  )) with check (exists (
    select 1 from public.plants p join public.plant_collections c on c.id = p.collection_id
    where p.id = plant_id and c.user_id = auth.uid()
  ));

create or replace function public.sync_plant_collection(
  p_expected_revision bigint,
  p_payload jsonb
) returns table(applied boolean, revision bigint)
language plpgsql security definer set search_path = public
as $$
declare
  collection public.plant_collections;
begin
  select * into collection from public.plant_collections where user_id = auth.uid() for update;
  if collection.id is not null and p_expected_revision is distinct from collection.revision then
    return query select false, collection.revision;
    return;
  end if;

  if collection.id is null then
    insert into public.plant_collections(user_id, revision, preferences)
    values (auth.uid(), 1, coalesce(p_payload->'preferences', '{}'::jsonb))
    returning * into collection;
  else
    update public.plant_collections
    set revision = collection.revision + 1,
        preferences = coalesce(p_payload->'preferences', '{}'::jsonb),
        updated_at = now()
    where id = collection.id
    returning * into collection;
  end if;

  delete from public.plants where collection_id = collection.id;

  insert into public.plants(id, collection_id, plant_profile_id, display_name, light_placement)
  select p->>'id', collection.id, p->>'plantTypeId', p->>'displayName', p->'lightPlacement'
  from jsonb_array_elements(coalesce(p_payload->'plants', '[]'::jsonb)) p;

  insert into public.watering_schedules(plant_id, interval_days, next_check_at, created_at, updated_at, time_source)
  select s->>'plantId', (s->>'intervalDays')::integer, (s->>'nextCheckAt')::timestamptz,
         (s->>'createdAt')::timestamptz, (s->>'updatedAt')::timestamptz, s->>'timeSource'
  from jsonb_array_elements(coalesce(p_payload->'schedules', '[]'::jsonb)) s;

  insert into public.watering_records(id, plant_id, scheduled_for, recorded_at, outcome, soil)
  select r->>'id', r->>'plantId', (r->>'scheduledFor')::timestamptz,
         (r->>'recordedAt')::timestamptz, r->>'outcome', r->>'soil'
  from jsonb_array_elements(coalesce(p_payload->'records', '[]'::jsonb)) r;

  insert into public.soil_care_events(id, plant_id, occurred_on, recorded_at, actions, product, notes, mix_contains_feed)
  select e->>'id', e->>'plantId', (e->>'occurredOn')::date, (e->>'recordedAt')::timestamptz,
         e->'actions', e->>'product', e->>'notes', (e->>'mixContainsFeed')::boolean
  from jsonb_array_elements(coalesce(p_payload->'soilCare', '[]'::jsonb)) e;

  return query select true, collection.revision;
end;
$$;

revoke all on function public.sync_plant_collection(bigint, jsonb) from public;
grant execute on function public.sync_plant_collection(bigint, jsonb) to authenticated;
