create table if not exists private.ai_limit_profiles (
  code text primary key,
  display_name text not null,
  description text,
  user_minute_limit integer not null check (user_minute_limit >= 0),
  user_daily_limit integer not null check (user_daily_limit >= 0),
  user_monthly_limit integer not null check (user_monthly_limit >= 0),
  ip_minute_limit integer not null check (ip_minute_limit >= 0),
  text_request_units integer not null check (text_request_units >= 0),
  image_request_units integer not null check (image_request_units >= 0),
  is_default boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table private.ai_limit_profiles enable row level security;
alter table private.ai_limit_profiles force row level security;

create unique index if not exists ai_limit_profiles_single_default_idx
  on private.ai_limit_profiles (is_default)
  where is_default;

create table if not exists private.user_ai_limit_assignments (
  user_id uuid primary key references public.users(id) on delete cascade,
  profile_code text not null references private.ai_limit_profiles(code) on update cascade on delete restrict,
  assignment_source text not null default 'manual',
  assigned_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table private.user_ai_limit_assignments enable row level security;
alter table private.user_ai_limit_assignments force row level security;

create index if not exists user_ai_limit_assignments_profile_code_idx
  on private.user_ai_limit_assignments (profile_code);

alter table private.user_rate_limits
  add column if not exists last_profile_code text;

insert into private.ai_limit_profiles (
  code,
  display_name,
  description,
  user_minute_limit,
  user_daily_limit,
  user_monthly_limit,
  ip_minute_limit,
  text_request_units,
  image_request_units,
  is_default
)
values
  (
    'free_trial',
    'Free Trial',
    'Restricted trial profile for limited evaluation.',
    8,
    40,
    120,
    24,
    1,
    6,
    false
  ),
  (
    'paid_standard',
    'Paid Standard',
    'Default paid plan limits for normal subscribers.',
    12,
    120,
    1200,
    36,
    1,
    6,
    true
  ),
  (
    'internal_unlimited',
    'Internal Unlimited',
    'High-trust profile for internal testing and support.',
    240,
    20000,
    500000,
    240,
    1,
    6,
    false
  )
on conflict (code) do nothing;

insert into private.user_ai_limit_assignments (
  user_id,
  profile_code,
  assignment_source
)
select
  u.id,
  p.code,
  'backfill_default'
from public.users u
cross join lateral (
  select code
  from private.ai_limit_profiles
  where is_default and is_active
  order by code
  limit 1
) p
on conflict (user_id) do nothing;

insert into private.user_rate_limits (
  user_id,
  minute_reset_at,
  daily_reset_at,
  monthly_reset_at
)
select
  u.id,
  date_trunc('minute', timezone('utc', now())),
  date_trunc('day', timezone('utc', now())),
  date_trunc('month', timezone('utc', now()))
from public.users u
where not exists (
  select 1
  from private.user_rate_limits r
  where r.user_id = u.id
);

create or replace function public.assign_ai_limit_profile(
  p_user_id uuid,
  p_profile_code text,
  p_assignment_source text default 'manual'
)
returns void
language plpgsql
security definer
set search_path = private, public, extensions, pg_catalog
as $$
begin
  if p_user_id is null then
    raise exception 'p_user_id is required';
  end if;

  if p_profile_code is null or btrim(p_profile_code) = '' then
    raise exception 'p_profile_code is required';
  end if;

  if not exists (
    select 1
    from private.ai_limit_profiles
    where code = p_profile_code
      and is_active
  ) then
    raise exception 'Unknown or inactive AI limit profile: %', p_profile_code;
  end if;

  insert into private.user_ai_limit_assignments (
    user_id,
    profile_code,
    assignment_source
  )
  values (
    p_user_id,
    p_profile_code,
    coalesce(nullif(btrim(p_assignment_source), ''), 'manual')
  )
  on conflict (user_id) do update
    set profile_code = excluded.profile_code,
        assignment_source = excluded.assignment_source,
        updated_at = timezone('utc', now());

  insert into private.user_rate_limits (
    user_id,
    minute_reset_at,
    daily_reset_at,
    monthly_reset_at
  )
  values (
    p_user_id,
    date_trunc('minute', timezone('utc', now())),
    date_trunc('day', timezone('utc', now())),
    date_trunc('month', timezone('utc', now()))
  )
  on conflict (user_id) do nothing;
end;
$$;

revoke all on function public.assign_ai_limit_profile(uuid, text, text) from public, anon, authenticated;
grant execute on function public.assign_ai_limit_profile(uuid, text, text) to service_role;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  default_profile_code text;
begin
  insert into public.users (id, email, display_name)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'name')
  )
  on conflict (id) do update
    set email = excluded.email,
        display_name = coalesce(public.users.display_name, excluded.display_name);

  select code
  into default_profile_code
  from private.ai_limit_profiles
  where is_default and is_active
  order by code
  limit 1;

  if default_profile_code is null then
    raise exception 'No default AI limit profile configured';
  end if;

  insert into private.user_ai_limit_assignments (
    user_id,
    profile_code,
    assignment_source
  )
  values (
    new.id,
    default_profile_code,
    'auth_user_created'
  )
  on conflict (user_id) do nothing;

  insert into private.user_rate_limits (
    user_id,
    minute_reset_at,
    daily_reset_at,
    monthly_reset_at
  )
  values (
    new.id,
    date_trunc('minute', timezone('utc', now())),
    date_trunc('day', timezone('utc', now())),
    date_trunc('month', timezone('utc', now()))
  )
  on conflict (user_id) do nothing;

  return new;
end;
$$;

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
  limit_profile private.ai_limit_profiles%rowtype;
  user_minute_limit integer;
  user_daily_limit integer;
  user_monthly_limit integer;
  ip_minute_limit integer;
  retry_target timestamptz;
begin
  if p_user_id is null then
    raise exception 'p_user_id is required';
  end if;

  select p.*
  into limit_profile
  from private.user_ai_limit_assignments a
  join private.ai_limit_profiles p
    on p.code = a.profile_code
  where a.user_id = p_user_id
    and p.is_active
  limit 1;

  if not found then
    select *
    into limit_profile
    from private.ai_limit_profiles
    where is_default and is_active
    order by code
    limit 1;

    if not found then
      raise exception 'No active AI limit profile configured';
    end if;

    insert into private.user_ai_limit_assignments (
      user_id,
      profile_code,
      assignment_source
    )
    values (
      p_user_id,
      limit_profile.code,
      'quota_fallback_default'
    )
    on conflict (user_id) do nothing;
  end if;

  user_minute_limit := limit_profile.user_minute_limit;
  user_daily_limit := limit_profile.user_daily_limit;
  user_monthly_limit := limit_profile.user_monthly_limit;
  ip_minute_limit := limit_profile.ip_minute_limit;

  request_units := case p_request_kind
    when 'text' then limit_profile.text_request_units
    when 'image' then limit_profile.image_request_units
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
    monthly_reset_at,
    last_profile_code
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
    month_anchor,
    limit_profile.code
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
        last_profile_code = limit_profile.code,
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
      last_profile_code = limit_profile.code,
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
      last_profile_code = limit_profile.code,
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
      last_profile_code = limit_profile.code,
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
    last_profile_code = limit_profile.code,
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
