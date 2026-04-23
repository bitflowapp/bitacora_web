-- Bit Flow Phase 1: backend persistence for row review + row evidence links.

create table if not exists public.sheet_row_reviews (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  sheet_local_id text not null,
  row_id text not null,
  status text not null default 'sin_revision'
    check (status in ('sin_revision', 'observada', 'corregida', 'aprobada')),
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  approved_by uuid references auth.users(id) on delete set null,
  approved_at timestamptz,
  observed_at timestamptz,
  corrected_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (project_id, sheet_local_id, row_id)
);

create index if not exists sheet_row_reviews_project_idx
  on public.sheet_row_reviews(project_id);

create index if not exists sheet_row_reviews_sheet_local_idx
  on public.sheet_row_reviews(sheet_local_id);

create index if not exists sheet_row_reviews_row_idx
  on public.sheet_row_reviews(row_id);

create index if not exists sheet_row_reviews_status_idx
  on public.sheet_row_reviews(status);

drop trigger if exists touch_sheet_row_reviews_updated_at
  on public.sheet_row_reviews;
create trigger touch_sheet_row_reviews_updated_at
before update on public.sheet_row_reviews
for each row execute function public.touch_updated_at();

alter table public.sheet_row_reviews enable row level security;

drop policy if exists "workspace members can manage sheet row reviews"
  on public.sheet_row_reviews;
create policy "workspace members can manage sheet row reviews"
on public.sheet_row_reviews
for all
using (
  exists (
    select 1
    from public.projects p
    where p.id = sheet_row_reviews.project_id
      and public.is_workspace_member(p.workspace_id)
  )
)
with check (
  exists (
    select 1
    from public.projects p
    where p.id = sheet_row_reviews.project_id
      and public.is_workspace_member(p.workspace_id)
  )
);

create table if not exists public.sheet_row_evidence_links (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  sheet_local_id text not null,
  row_id text not null,
  evidence_ref text not null,
  evidence_kind text not null default 'archivo',
  evidence_label text not null default '',
  evidence_mime text not null default '',
  source_cell_key text not null default '',
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (project_id, sheet_local_id, row_id, evidence_ref)
);

create index if not exists sheet_row_evidence_links_project_idx
  on public.sheet_row_evidence_links(project_id);

create index if not exists sheet_row_evidence_links_sheet_local_idx
  on public.sheet_row_evidence_links(sheet_local_id);

create index if not exists sheet_row_evidence_links_row_idx
  on public.sheet_row_evidence_links(row_id);

drop trigger if exists touch_sheet_row_evidence_links_updated_at
  on public.sheet_row_evidence_links;
create trigger touch_sheet_row_evidence_links_updated_at
before update on public.sheet_row_evidence_links
for each row execute function public.touch_updated_at();

alter table public.sheet_row_evidence_links enable row level security;

drop policy if exists "workspace members can manage sheet row evidence links"
  on public.sheet_row_evidence_links;
create policy "workspace members can manage sheet row evidence links"
on public.sheet_row_evidence_links
for all
using (
  exists (
    select 1
    from public.projects p
    where p.id = sheet_row_evidence_links.project_id
      and public.is_workspace_member(p.workspace_id)
  )
)
with check (
  exists (
    select 1
    from public.projects p
    where p.id = sheet_row_evidence_links.project_id
      and public.is_workspace_member(p.workspace_id)
  )
);
