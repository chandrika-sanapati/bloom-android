create table if not exists public.gardens (
  user_id uuid primary key references auth.users(id) on delete cascade,
  schema_version integer not null default 1,
  payload jsonb not null,
  revision bigint not null default 0,
  updated_at timestamptz not null default now()
);

alter table public.gardens enable row level security;

drop policy if exists "users can read their own garden" on public.gardens;
create policy "users can read their own garden"
  on public.gardens for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "users can insert their own garden" on public.gardens;
create policy "users can insert their own garden"
  on public.gardens for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "users can update their own garden" on public.gardens;
create policy "users can update their own garden"
  on public.gardens for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
