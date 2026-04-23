-- Bit Flow Phase 1 corporate base.
-- Minimal backend model for authenticated field teams.

create extension if not exists pgcrypto;

do $$
begin
  if not exists (select 1 from pg_type where typname = 'bitflow_role') then
    create type public.bitflow_role as enum (
      'tecnico',
      'supervisor',
      'coordinador',
      'admin'
    );
  end if;
end $$;

create table if not exists public.workspaces (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  legal_name text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.workspace_memberships (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role public.bitflow_role not null default 'tecnico',
  status text not null default 'active'
    check (status in ('active', 'invited', 'disabled')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (workspace_id, user_id)
);

create table if not exists public.projects (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  name text not null,
  code text,
  description text,
  field_scope text,
  status text not null default 'active'
    check (status in ('planning', 'active', 'paused', 'closed')),
  starts_on date,
  ends_on date,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.project_members (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role public.bitflow_role not null default 'tecnico',
  created_at timestamptz not null default now(),
  unique (project_id, user_id)
);

create index if not exists workspace_memberships_user_idx
  on public.workspace_memberships(user_id, status);

create index if not exists projects_workspace_idx
  on public.projects(workspace_id, status);

create index if not exists project_members_user_idx
  on public.project_members(user_id);

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists touch_workspaces_updated_at on public.workspaces;
create trigger touch_workspaces_updated_at
before update on public.workspaces
for each row execute function public.touch_updated_at();

drop trigger if exists touch_workspace_memberships_updated_at
  on public.workspace_memberships;
create trigger touch_workspace_memberships_updated_at
before update on public.workspace_memberships
for each row execute function public.touch_updated_at();

drop trigger if exists touch_projects_updated_at on public.projects;
create trigger touch_projects_updated_at
before update on public.projects
for each row execute function public.touch_updated_at();

create or replace function public.is_workspace_member(target_workspace_id uuid)
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.workspace_memberships wm
    where wm.workspace_id = target_workspace_id
      and wm.user_id = auth.uid()
      and wm.status = 'active'
  );
$$;

create or replace function public.has_workspace_role(
  target_workspace_id uuid,
  allowed_roles public.bitflow_role[]
)
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.workspace_memberships wm
    where wm.workspace_id = target_workspace_id
      and wm.user_id = auth.uid()
      and wm.status = 'active'
      and wm.role = any(allowed_roles)
  );
$$;

alter table public.workspaces enable row level security;
alter table public.workspace_memberships enable row level security;
alter table public.projects enable row level security;
alter table public.project_members enable row level security;

drop policy if exists "workspace members can read workspaces"
  on public.workspaces;
create policy "workspace members can read workspaces"
on public.workspaces
for select
using (public.is_workspace_member(id));

drop policy if exists "workspace admins can update workspaces"
  on public.workspaces;
create policy "workspace admins can update workspaces"
on public.workspaces
for update
using (public.has_workspace_role(id, array['admin']::public.bitflow_role[]))
with check (public.has_workspace_role(id, array['admin']::public.bitflow_role[]));

drop policy if exists "members can read workspace memberships"
  on public.workspace_memberships;
create policy "members can read workspace memberships"
on public.workspace_memberships
for select
using (public.is_workspace_member(workspace_id));

drop policy if exists "admins manage workspace memberships"
  on public.workspace_memberships;
create policy "admins manage workspace memberships"
on public.workspace_memberships
for all
using (
  public.has_workspace_role(workspace_id, array['admin']::public.bitflow_role[])
)
with check (
  public.has_workspace_role(workspace_id, array['admin']::public.bitflow_role[])
);

drop policy if exists "workspace members can read projects"
  on public.projects;
create policy "workspace members can read projects"
on public.projects
for select
using (public.is_workspace_member(workspace_id));

drop policy if exists "coordinators manage projects"
  on public.projects;
create policy "coordinators manage projects"
on public.projects
for all
using (
  public.has_workspace_role(
    workspace_id,
    array['coordinador', 'admin']::public.bitflow_role[]
  )
)
with check (
  public.has_workspace_role(
    workspace_id,
    array['coordinador', 'admin']::public.bitflow_role[]
  )
);

drop policy if exists "workspace members can read project members"
  on public.project_members;
create policy "workspace members can read project members"
on public.project_members
for select
using (
  exists (
    select 1
    from public.projects p
    where p.id = project_members.project_id
      and public.is_workspace_member(p.workspace_id)
  )
);

drop policy if exists "coordinators manage project members"
  on public.project_members;
create policy "coordinators manage project members"
on public.project_members
for all
using (
  exists (
    select 1
    from public.projects p
    where p.id = project_members.project_id
      and public.has_workspace_role(
        p.workspace_id,
        array['coordinador', 'admin']::public.bitflow_role[]
      )
  )
)
with check (
  exists (
    select 1
    from public.projects p
    where p.id = project_members.project_id
      and public.has_workspace_role(
        p.workspace_id,
        array['coordinador', 'admin']::public.bitflow_role[]
      )
  )
);
