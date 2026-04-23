-- Bit Flow Phase 1: row comments thread + internal notifications.

-- ── row_comments ────────────────────────────────────────────────────────────
-- Hilo de comentarios por fila. parent_id = null → comentario raiz.
-- parent_id != null → respuesta (max 1 nivel en fase 1).

create table if not exists public.row_comments (
  id            uuid primary key default gen_random_uuid(),
  project_id    uuid not null references public.projects(id) on delete cascade,
  sheet_local_id text not null,
  row_id        text not null,
  parent_id     uuid references public.row_comments(id) on delete cascade,
  author_id     uuid references auth.users(id) on delete set null,
  author_label  text not null default '',
  comment_type  text not null default 'nota'
    check (comment_type in ('observacion', 'respuesta', 'nota', 'resolucion')),
  body          text not null,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create index if not exists row_comments_row_idx
  on public.row_comments(project_id, sheet_local_id, row_id);

create index if not exists row_comments_parent_idx
  on public.row_comments(parent_id)
  where parent_id is not null;

drop trigger if exists touch_row_comments_updated_at on public.row_comments;
create trigger touch_row_comments_updated_at
before update on public.row_comments
for each row execute function public.touch_updated_at();

alter table public.row_comments enable row level security;

drop policy if exists "workspace members read row comments" on public.row_comments;
create policy "workspace members read row comments"
on public.row_comments for select
using (
  exists (
    select 1 from public.projects p
    where p.id = row_comments.project_id
      and public.is_workspace_member(p.workspace_id)
  )
);

drop policy if exists "workspace members insert row comments" on public.row_comments;
create policy "workspace members insert row comments"
on public.row_comments for insert
with check (
  author_id = auth.uid()
  and exists (
    select 1 from public.projects p
    where p.id = row_comments.project_id
      and public.is_workspace_member(p.workspace_id)
  )
);

-- ── user_notifications ───────────────────────────────────────────────────────
-- Notificaciones internas consultables. Sin push externo en fase 1.
-- read_at = null → no leida.

create table if not exists public.user_notifications (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references auth.users(id) on delete cascade,
  notif_type     text not null
    check (notif_type in (
      'fila_observada',
      'fila_corregida',
      'fila_aprobada',
      'comentario_nuevo'
    )),
  project_id     uuid references public.projects(id) on delete cascade,
  sheet_local_id text,
  row_id         text,
  actor_id       uuid references auth.users(id) on delete set null,
  actor_label    text not null default '',
  body           text not null default '',
  read_at        timestamptz,
  created_at     timestamptz not null default now()
);

create index if not exists user_notifications_user_unread_idx
  on public.user_notifications(user_id, created_at desc)
  where read_at is null;

create index if not exists user_notifications_project_idx
  on public.user_notifications(project_id)
  where project_id is not null;

alter table public.user_notifications enable row level security;

drop policy if exists "users read own notifications" on public.user_notifications;
create policy "users read own notifications"
on public.user_notifications for select
using (user_id = auth.uid());

-- Cualquier miembro del workspace puede crear notificaciones
-- para otros miembros del mismo workspace.
drop policy if exists "workspace members create notifications" on public.user_notifications;
create policy "workspace members create notifications"
on public.user_notifications for insert
with check (
  project_id is null
  or exists (
    select 1 from public.projects p
    where p.id = user_notifications.project_id
      and public.is_workspace_member(p.workspace_id)
  )
);

drop policy if exists "users mark own notifications read" on public.user_notifications;
create policy "users mark own notifications read"
on public.user_notifications for update
using  (user_id = auth.uid())
with check (user_id = auth.uid());
