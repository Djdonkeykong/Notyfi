create schema if not exists private;

do $$
begin
  if exists (
    select 1
    from information_schema.tables
    where table_schema = 'public'
      and table_name = 'user_rate_limits'
  ) and not exists (
    select 1
    from information_schema.tables
    where table_schema = 'private'
      and table_name = 'user_rate_limits'
  ) then
    alter table public.user_rate_limits set schema private;
  end if;
end
$$;

create table if not exists private.user_rate_limits (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references public.users(id) on delete cascade,
  ai_parses_today integer not null default 0,
  ai_parses_this_month integer not null default 0,
  daily_reset_at timestamptz not null default now(),
  monthly_reset_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table private.user_rate_limits
  add column if not exists ai_units_this_minute integer not null default 0;

alter table private.user_rate_limits
  add column if not exists ai_units_today integer not null default 0;

alter table private.user_rate_limits
  add column if not exists ai_units_this_month integer not null default 0;

alter table private.user_rate_limits
  add column if not exists minute_reset_at timestamptz not null default now();

alter table private.user_rate_limits
  add column if not exists last_request_at timestamptz;

alter table private.user_rate_limits
  add column if not exists last_request_kind text;

alter table private.user_rate_limits
  add column if not exists last_request_ip inet;

alter table private.user_rate_limits
  add column if not exists last_blocked_at timestamptz;

alter table private.user_rate_limits
  add column if not exists last_block_reason text;

update private.user_rate_limits
set
  ai_units_today = greatest(ai_units_today, ai_parses_today),
  ai_units_this_month = greatest(ai_units_this_month, ai_parses_this_month),
  minute_reset_at = coalesce(minute_reset_at, now()),
  daily_reset_at = coalesce(daily_reset_at, now()),
  monthly_reset_at = coalesce(monthly_reset_at, now()),
  updated_at = coalesce(updated_at, now()),
  created_at = coalesce(created_at, now());

create table if not exists private.ai_ip_rate_limits (
  ip inet primary key,
  ai_units_this_minute integer not null default 0,
  minute_reset_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

revoke all on schema private from public, anon, authenticated;
revoke all on all tables in schema private from public, anon, authenticated;

create or replace function public.consume_ai_parse_quota(
  p_user_id uuid,
  p_request_kind text,
  p_ip text default null
)
returns table (
  allowed boolean,
  retry_after_seconds integer,
  error_code text
)
language plpgsql
security definer
set search_path = private, public, extensions, pg_catalog
as $$
declare
  current_ts timestamptz := timezone('utc', now());
  minute_anchor timestamptz := date_trunc('minute', current_ts);
  day_anchor timestamptz := date_trunc('day', current_ts);
  month_anchor timestamptz := date_trunc('month', current_ts);
  request_units integer;
  parsed_ip inet;
  user_state private.user_rate_limits%rowtype;
  ip_state private.ai_ip_rate_limits%rowtype;
  user_minute_limit constant integer := 12;
  user_daily_limit constant integer := 120;
  user_monthly_limit constant integer := 1200;
  ip_minute_limit constant integer := 36;
  retry_target timestamptz;
begin
  if p_user_id is null then
    raise exception 'p_user_id is required';
  end if;

  request_units := case p_request_kind
    when 'text' then 1
    when 'image' then 6
    else null
  end;

  if request_units is null then
    raise exception 'Unsupported request kind: %', p_request_kind;
  end if;

  if p_ip is not null and btrim(p_ip) <> '' then
    begin
      parsed_ip := split_part(p_ip, ',', 1)::inet;
    exception
      when others then
        parsed_ip := null;
    end;
  end if;

  insert into private.user_rate_limits (
    user_id,
    ai_parses_today,
    ai_parses_this_month,
    ai_units_this_minute,
    ai_units_today,
    ai_units_this_month,
    minute_reset_at,
    daily_reset_at,
    monthly_reset_at
  )
  values (
    p_user_id,
    0,
    0,
    0,
    0,
    0,
    minute_anchor,
    day_anchor,
    month_anchor
  )
  on conflict (user_id) do nothing;

  select *
  into user_state
  from private.user_rate_limits
  where user_id = p_user_id
  for update;

  if user_state.minute_reset_at < minute_anchor then
    user_state.minute_reset_at := minute_anchor;
    user_state.ai_units_this_minute := 0;
  end if;

  if user_state.daily_reset_at < day_anchor then
    user_state.daily_reset_at := day_anchor;
    user_state.ai_parses_today := 0;
    user_state.ai_units_today := 0;
  end if;

  if user_state.monthly_reset_at < month_anchor then
    user_state.monthly_reset_at := month_anchor;
    user_state.ai_parses_this_month := 0;
    user_state.ai_units_this_month := 0;
  end if;

  if parsed_ip is not null then
    insert into private.ai_ip_rate_limits (
      ip,
      ai_units_this_minute,
      minute_reset_at
    )
    values (
      parsed_ip,
      0,
      minute_anchor
    )
    on conflict (ip) do nothing;

    select *
    into ip_state
    from private.ai_ip_rate_limits
    where ip = parsed_ip
    for update;

    if ip_state.minute_reset_at < minute_anchor then
      ip_state.minute_reset_at := minute_anchor;
      ip_state.ai_units_this_minute := 0;
    end if;

    if ip_state.ai_units_this_minute + request_units > ip_minute_limit then
      retry_target := minute_anchor + interval '1 minute';

      update private.user_rate_limits
      set
        minute_reset_at = user_state.minute_reset_at,
        ai_units_this_minute = user_state.ai_units_this_minute,
        daily_reset_at = user_state.daily_reset_at,
        ai_parses_today = user_state.ai_parses_today,
        ai_units_today = user_state.ai_units_today,
        monthly_reset_at = user_state.monthly_reset_at,
        ai_parses_this_month = user_state.ai_parses_this_month,
        ai_units_this_month = user_state.ai_units_this_month,
        last_blocked_at = current_ts,
        last_block_reason = 'rate_limit_exceeded',
        updated_at = current_ts
      where user_id = p_user_id;

      return query
      select
        false,
        greatest(1, ceil(extract(epoch from retry_target - current_ts))::integer),
        'rate_limit_exceeded'::text;
      return;
    end if;
  end if;

  if user_state.ai_units_this_minute + request_units > user_minute_limit then
    retry_target := minute_anchor + interval '1 minute';

    update private.user_rate_limits
    set
      minute_reset_at = user_state.minute_reset_at,
      ai_units_this_minute = user_state.ai_units_this_minute,
      daily_reset_at = user_state.daily_reset_at,
      ai_parses_today = user_state.ai_parses_today,
      ai_units_today = user_state.ai_units_today,
      monthly_reset_at = user_state.monthly_reset_at,
      ai_parses_this_month = user_state.ai_parses_this_month,
      ai_units_this_month = user_state.ai_units_this_month,
      last_blocked_at = current_ts,
      last_block_reason = 'rate_limit_exceeded',
      updated_at = current_ts
    where user_id = p_user_id;

    return query
    select
      false,
      greatest(1, ceil(extract(epoch from retry_target - current_ts))::integer),
      'rate_limit_exceeded'::text;
    return;
  end if;

  if user_state.ai_units_today + request_units > user_daily_limit then
    retry_target := day_anchor + interval '1 day';

    update private.user_rate_limits
    set
      minute_reset_at = user_state.minute_reset_at,
      ai_units_this_minute = user_state.ai_units_this_minute,
      daily_reset_at = user_state.daily_reset_at,
      ai_parses_today = user_state.ai_parses_today,
      ai_units_today = user_state.ai_units_today,
      monthly_reset_at = user_state.monthly_reset_at,
      ai_parses_this_month = user_state.ai_parses_this_month,
      ai_units_this_month = user_state.ai_units_this_month,
      last_blocked_at = current_ts,
      last_block_reason = 'rate_limit_exceeded',
      updated_at = current_ts
    where user_id = p_user_id;

    return query
    select
      false,
      greatest(60, ceil(extract(epoch from retry_target - current_ts))::integer),
      'rate_limit_exceeded'::text;
    return;
  end if;

  if user_state.ai_units_this_month + request_units > user_monthly_limit then
    retry_target := month_anchor + interval '1 month';

    update private.user_rate_limits
    set
      minute_reset_at = user_state.minute_reset_at,
      ai_units_this_minute = user_state.ai_units_this_minute,
      daily_reset_at = user_state.daily_reset_at,
      ai_parses_today = user_state.ai_parses_today,
      ai_units_today = user_state.ai_units_today,
      monthly_reset_at = user_state.monthly_reset_at,
      ai_parses_this_month = user_state.ai_parses_this_month,
      ai_units_this_month = user_state.ai_units_this_month,
      last_blocked_at = current_ts,
      last_block_reason = 'rate_limit_exceeded',
      updated_at = current_ts
    where user_id = p_user_id;

    return query
    select
      false,
      greatest(3600, ceil(extract(epoch from retry_target - current_ts))::integer),
      'rate_limit_exceeded'::text;
    return;
  end if;

  update private.user_rate_limits
  set
    minute_reset_at = user_state.minute_reset_at,
    ai_units_this_minute = user_state.ai_units_this_minute + request_units,
    daily_reset_at = user_state.daily_reset_at,
    ai_parses_today = user_state.ai_parses_today + 1,
    ai_units_today = user_state.ai_units_today + request_units,
    monthly_reset_at = user_state.monthly_reset_at,
    ai_parses_this_month = user_state.ai_parses_this_month + 1,
    ai_units_this_month = user_state.ai_units_this_month + request_units,
    last_request_at = current_ts,
    last_request_kind = p_request_kind,
    last_request_ip = parsed_ip,
    updated_at = current_ts
  where user_id = p_user_id;

  if parsed_ip is not null then
    update private.ai_ip_rate_limits
    set
      minute_reset_at = ip_state.minute_reset_at,
      ai_units_this_minute = ip_state.ai_units_this_minute + request_units,
      updated_at = current_ts
    where ip = parsed_ip;
  end if;

  return query
  select true, 0, null::text;
end;
$$;

revoke all on function public.consume_ai_parse_quota(uuid, text, text) from public, anon, authenticated;
grant execute on function public.consume_ai_parse_quota(uuid, text, text) to service_role;
