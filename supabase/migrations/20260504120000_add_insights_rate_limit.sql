alter table public.users
  add column if not exists insights_month text,
  add column if not exists insights_month_count integer not null default 0;
