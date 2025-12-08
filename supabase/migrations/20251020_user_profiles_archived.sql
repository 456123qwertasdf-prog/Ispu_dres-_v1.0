-- Create archive table for user profiles
create table if not exists public.user_profiles_archived (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique,
  role text not null default 'citizen',
  name text,
  phone text,
  student_number text,
  is_active boolean not null default false,
  created_at timestamptz,
  archived_at timestamptz not null default now()
);

comment on table public.user_profiles_archived is 'Archived user profiles moved out of active user_profiles';

create index if not exists idx_user_profiles_archived_user_id on public.user_profiles_archived(user_id);
create index if not exists idx_user_profiles_archived_archived_at on public.user_profiles_archived(archived_at desc);


