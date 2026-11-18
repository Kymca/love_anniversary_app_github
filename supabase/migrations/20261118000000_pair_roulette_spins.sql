create table if not exists public.pair_roulette_spins (
  pair_id uuid primary key references public.pairs(id) on delete cascade,
  spin_id uuid not null,
  category text not null check (category in ('food', 'movie', 'activity')),
  choice_key text not null check (char_length(choice_key) between 1 and 120),
  choice text not null check (char_length(btrim(choice)) between 1 and 80),
  started_at timestamptz not null
);

alter table public.pair_roulette_spins enable row level security;
drop policy if exists pair_roulette_spins_member_read
  on public.pair_roulette_spins;
create policy pair_roulette_spins_member_read on public.pair_roulette_spins
  for select to authenticated
  using (public.is_pair_member(pair_id));
revoke all on public.pair_roulette_spins from public, anon, authenticated;
grant select on public.pair_roulette_spins to authenticated;

create or replace function public.start_pair_roulette_spin(
  p_pair_id uuid,
  p_category text,
  p_choice text,
  p_choice_key text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_spin_id uuid := pg_catalog.gen_random_uuid();
  v_started_at timestamptz := pg_catalog.clock_timestamp();
  v_spin jsonb;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if p_pair_id is null or not public.is_pair_member(p_pair_id) then
    raise exception 'not_pair_member';
  end if;
  if p_category is null or p_category not in ('food', 'movie', 'activity') then
    raise exception 'invalid_roulette_category';
  end if;
  if p_choice is null or char_length(btrim(p_choice)) not between 1 and 80
     or p_choice_key is null
     or char_length(p_choice_key) not between 1 and 120 then
    raise exception 'invalid_roulette_choice';
  end if;

  insert into public.pair_roulette_spins as current_spin (
    pair_id, spin_id, category, choice_key, choice, started_at
  )
  values (
    p_pair_id, v_spin_id, p_category, p_choice_key, btrim(p_choice), v_started_at
  )
  on conflict (pair_id) do update
  set spin_id = excluded.spin_id,
      category = excluded.category,
      choice_key = excluded.choice_key,
      choice = excluded.choice,
      started_at = excluded.started_at
  where current_spin.started_at <= v_started_at - interval '4 seconds'
  returning pg_catalog.jsonb_build_object(
    'spin_id', current_spin.spin_id,
    'category', current_spin.category,
    'choice_key', current_spin.choice_key,
    'choice', current_spin.choice,
    'started_at', current_spin.started_at
  )
  into v_spin;

  return v_spin;
end;
$$;

revoke all on function public.start_pair_roulette_spin(uuid, text, text, text)
  from public, anon;
grant execute on function public.start_pair_roulette_spin(uuid, text, text, text)
  to authenticated;

do $$
begin
  if not exists (
    select 1 from pg_catalog.pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'pair_roulette_spins'
  ) then
    alter publication supabase_realtime
      add table public.pair_roulette_spins;
  end if;
end
$$;
