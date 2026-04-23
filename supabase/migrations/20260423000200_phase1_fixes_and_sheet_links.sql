-- Bit Flow Phase 1 fixes + project to local sheet references.

drop policy if exists "authenticated users can create workspaces"
  on public.workspaces;
create policy "authenticated users can create workspaces"
on public.workspaces
for insert
to authenticated
with check (created_by = auth.uid());

create or replace function public.add_workspace_creator_admin_membership()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.created_by is not null then
    insert into public.workspace_memberships (
      workspace_id,
      user_id,
      role,
      status
    )
    values (
      new.id,
      new.created_by,
      'admin',
      'active'
    )
    on conflict (workspace_id, user_id)
    do update set
      role = 'admin',
      status = 'active',
      updated_at = now();
  end if;
  return new;
end;
$$;

drop trigger if exists add_workspace_creator_admin_membership
  on public.workspaces;
create trigger add_workspace_creator_admin_membership
after insert on public.workspaces
for each row execute function public.add_workspace_creator_admin_membership();

drop policy if exists "members can read workspace memberships"
  on public.workspace_memberships;
create policy "members can read workspace memberships"
on public.workspace_memberships
for select
using (
  user_id = auth.uid()
  or public.is_workspace_member(workspace_id)
);

create table if not exists public.project_sheet_refs (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  sheet_local_id text not null,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  unique (project_id, sheet_local_id)
);

create index if not exists project_sheet_refs_project_idx
  on public.project_sheet_refs(project_id);

create index if not exists project_sheet_refs_sheet_local_idx
  on public.project_sheet_refs(sheet_local_id);

alter table public.project_sheet_refs enable row level security;

drop policy if exists "workspace members can read project sheet refs"
  on public.project_sheet_refs;
create policy "workspace members can read project sheet refs"
on public.project_sheet_refs
for select
using (
  exists (
    select 1
    from public.projects p
    where p.id = project_sheet_refs.project_id
      and public.is_workspace_member(p.workspace_id)
  )
);

drop policy if exists "coordinators can link project sheet refs"
  on public.project_sheet_refs;
create policy "coordinators can link project sheet refs"
on public.project_sheet_refs
for insert
with check (
  exists (
    select 1
    from public.projects p
    where p.id = project_sheet_refs.project_id
      and public.has_workspace_role(
        p.workspace_id,
        array['coordinador', 'admin']::public.bitflow_role[]
      )
  )
);

drop policy if exists "coordinators can unlink project sheet refs"
  on public.project_sheet_refs;
create policy "coordinators can unlink project sheet refs"
on public.project_sheet_refs
for delete
using (
  exists (
    select 1
    from public.projects p
    where p.id = project_sheet_refs.project_id
      and public.has_workspace_role(
        p.workspace_id,
        array['coordinador', 'admin']::public.bitflow_role[]
      )
  )
);
