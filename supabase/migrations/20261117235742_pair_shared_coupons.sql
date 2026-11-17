create table if not exists public.pair_coupon_states (
  pair_id uuid not null references public.pairs(id) on delete cascade,
  coupon_id text not null check (char_length(coupon_id) between 1 and 80),
  coupon_type text not null check (
    coupon_type in ('oneTime', 'monthly', 'daily')
  ),
  period_key text check (
    period_key is null or period_key ~ '^[0-9]{4}-[0-9]{2}$'
  ),
  last_activated_at timestamptz not null default now(),
  activated_by uuid not null references auth.users(id) on delete cascade,
  updated_at timestamptz not null default now(),
  primary key (pair_id, coupon_id)
);

alter table public.pair_coupon_states enable row level security;
drop policy if exists pair_coupon_states_member_read
  on public.pair_coupon_states;
create policy pair_coupon_states_member_read on public.pair_coupon_states
  for select to authenticated
  using (public.is_pair_member(pair_id));
revoke all on public.pair_coupon_states from public, anon, authenticated;
grant select on public.pair_coupon_states to authenticated;

create or replace function public.activate_pair_coupon(
  p_pair_id uuid,
  p_coupon_id text,
  p_coupon_type text,
  p_period_key text
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_existing public.pair_coupon_states;
  v_now timestamptz := pg_catalog.clock_timestamp();
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if p_pair_id is null or not public.is_pair_member(p_pair_id) then
    raise exception 'not_pair_member';
  end if;
  if p_coupon_id is null or char_length(p_coupon_id) not between 1 and 80 then
    raise exception 'invalid_coupon';
  end if;
  if p_coupon_type is null
     or p_coupon_type not in ('oneTime', 'monthly', 'daily') then
    raise exception 'invalid_coupon_type';
  end if;
  if p_coupon_type = 'daily'
     and p_coupon_id !~ '^daily-[0-9]{4}-[0-9]{2}-[0-9]{2}$' then
    raise exception 'invalid_coupon';
  end if;
  if p_coupon_type = 'monthly'
     and (p_period_key is null or p_period_key !~ '^[0-9]{4}-[0-9]{2}$') then
    raise exception 'invalid_coupon_period';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      p_pair_id::text || ':' || p_coupon_id,
      0
    )
  );
  select * into v_existing
  from public.pair_coupon_states
  where pair_id = p_pair_id and coupon_id = p_coupon_id
  for update;

  if found and v_existing.coupon_type <> p_coupon_type then
    raise exception 'coupon_type_mismatch';
  end if;
  if p_coupon_type in ('oneTime', 'daily') and found then
    return false;
  end if;
  if p_coupon_type = 'monthly'
     and found
     and v_existing.period_key = p_period_key then
    return false;
  end if;

  insert into public.pair_coupon_states (
    pair_id, coupon_id, coupon_type, period_key,
    last_activated_at, activated_by, updated_at
  )
  values (
    p_pair_id, p_coupon_id, p_coupon_type,
    case when p_coupon_type = 'monthly' then p_period_key else null end,
    v_now, auth.uid(), v_now
  )
  on conflict (pair_id, coupon_id) do update
  set period_key = excluded.period_key,
      last_activated_at = excluded.last_activated_at,
      activated_by = excluded.activated_by,
      updated_at = excluded.updated_at;
  return true;
end;
$$;

revoke all on function public.activate_pair_coupon(uuid, text, text, text)
  from public, anon;
grant execute on function public.activate_pair_coupon(uuid, text, text, text)
  to authenticated;

do $$
begin
  if not exists (
    select 1 from pg_catalog.pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'pair_coupon_states'
  ) then
    alter publication supabase_realtime
      add table public.pair_coupon_states;
  end if;
end
$$;
