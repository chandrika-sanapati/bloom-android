create index if not exists plant_profiles_scientific_name_idx
  on public.plant_profiles (lower(scientific_name));
create index if not exists plant_profile_aliases_profile_id_idx
  on public.plant_profile_aliases (profile_id);
create index if not exists plants_collection_id_idx on public.plants (collection_id);
create index if not exists plants_profile_id_idx on public.plants (plant_profile_id);
create index if not exists watering_records_plant_recorded_idx
  on public.watering_records (plant_id, recorded_at desc);
create index if not exists soil_care_events_plant_occurred_idx
  on public.soil_care_events (plant_id, occurred_on desc);
