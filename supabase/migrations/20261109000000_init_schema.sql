create schema if not exists private;

create type public.user_role as enum ('admin', 'teacher', 'student');
create type public.problem_format as enum ('multiple_choice', 'short_answer');
create type public.problem_status as enum ('draft', 'review', 'published', 'archived');
create type public.report_status as enum ('open', 'resolved', 'dismissed');

create table public.users (
  id uuid primary key references auth.users (id) on delete cascade,
  email text,
  role public.user_role not null default 'student',
  name text,
  created_at timestamptz not null default now()
);

create table public.curriculum (
  id uuid primary key default gen_random_uuid(),
  subject text not null,
  unit text not null,
  subunit text,
  achievement_code text,
  sort_order integer not null default 0,
  unique nulls not distinct (subject, unit, subunit)
);

create table public.problems (
  id uuid primary key default gen_random_uuid(),
  curriculum_id uuid not null references public.curriculum (id) on delete restrict,
  format public.problem_format not null,
  difficulty smallint not null check (difficulty between 1 and 5),
  points smallint not null check (points in (2, 3, 4)),
  stem text not null,
  choices text[] not null default '{}',
  images text[] not null default '{}',
  graph_spec jsonb,
  source text not null,
  status public.problem_status not null default 'draft',
  version integer not null default 1,
  author_id uuid references public.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint problems_choices_match_format check (
    status = 'draft'
    or (format = 'multiple_choice' and cardinality(choices) = 5)
    or (format = 'short_answer' and cardinality(choices) = 0)
  )
);

-- RLS is row-level, so answer and solution live apart from the published row students can read.
create table public.problem_answers (
  problem_id uuid primary key references public.problems (id) on delete cascade,
  answer text not null,
  solution text not null default ''
);

create table public.problem_tags (
  problem_id uuid not null references public.problems (id) on delete cascade,
  tag text not null,
  primary key (problem_id, tag)
);

create table public.problem_versions (
  id uuid primary key default gen_random_uuid(),
  problem_id uuid not null references public.problems (id) on delete cascade,
  snapshot jsonb not null,
  edited_by uuid references public.users (id) on delete set null,
  edited_at timestamptz not null default now()
);

create table public.exams (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  owner_id uuid not null references public.users (id) on delete cascade,
  preset text,
  time_limit_min integer check (time_limit_min > 0),
  created_at timestamptz not null default now()
);

create table public.exam_items (
  exam_id uuid not null references public.exams (id) on delete cascade,
  problem_id uuid not null references public.problems (id) on delete restrict,
  order_no integer not null,
  points smallint not null check (points in (2, 3, 4)),
  primary key (exam_id, problem_id),
  -- Deferred so a drag reorder can swap positions within one transaction.
  unique (exam_id, order_no) deferrable initially deferred
);

create table public.attempts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  problem_id uuid not null references public.problems (id) on delete restrict,
  response text not null,
  is_correct boolean not null,
  time_spent_sec integer check (time_spent_sec >= 0),
  exam_id uuid references public.exams (id) on delete set null,
  created_at timestamptz not null default now()
);

create table public.wrong_notes (
  user_id uuid not null references public.users (id) on delete cascade,
  problem_id uuid not null references public.problems (id) on delete cascade,
  memo text not null default '',
  resolved boolean not null default false,
  updated_at timestamptz not null default now(),
  primary key (user_id, problem_id)
);

create table public.bookmarks (
  user_id uuid not null references public.users (id) on delete cascade,
  problem_id uuid not null references public.problems (id) on delete cascade,
  primary key (user_id, problem_id)
);

create table public.reports (
  id uuid primary key default gen_random_uuid(),
  problem_id uuid not null references public.problems (id) on delete cascade,
  user_id uuid not null references public.users (id) on delete cascade,
  message text not null,
  status public.report_status not null default 'open',
  created_at timestamptz not null default now()
);

create index problems_status_curriculum_idx on public.problems (status, curriculum_id);
create index problems_curriculum_idx on public.problems (curriculum_id);
create index problems_author_idx on public.problems (author_id);
create index problem_tags_tag_idx on public.problem_tags (tag);
create index problem_versions_problem_idx on public.problem_versions (problem_id, edited_at desc);
create index problem_versions_edited_by_idx on public.problem_versions (edited_by);
create index exams_owner_idx on public.exams (owner_id);
create index exam_items_problem_idx on public.exam_items (problem_id);
create index attempts_user_created_idx on public.attempts (user_id, created_at desc);
create index attempts_problem_idx on public.attempts (problem_id);
create index attempts_exam_idx on public.attempts (exam_id);
create index wrong_notes_problem_idx on public.wrong_notes (problem_id);
create index bookmarks_problem_idx on public.bookmarks (problem_id);
create index reports_problem_idx on public.reports (problem_id);
create index reports_user_idx on public.reports (user_id);

create function private.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.users
    where id = (select auth.uid()) and role = 'admin'
  );
$$;

create function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.users (id, email, name)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data ->> 'name', new.raw_user_meta_data ->> 'full_name')
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function private.handle_new_user();

create function private.protect_user_columns()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if current_user = 'authenticated' and not private.is_admin() and (
    new.id is distinct from old.id
    or new.role is distinct from old.role
    or new.email is distinct from old.email
    or new.created_at is distinct from old.created_at
  ) then
    raise exception 'only admins can change this column' using errcode = '42501';
  end if;
  return new;
end;
$$;

create trigger protect_user_columns
  before update on public.users
  for each row execute function private.protect_user_columns();

create function private.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger set_problems_updated_at
  before update on public.problems
  for each row execute function private.set_updated_at();

create trigger set_wrong_notes_updated_at
  before update on public.wrong_notes
  for each row execute function private.set_updated_at();

revoke all on schema private from public;
revoke execute on all functions in schema private from public;
grant usage on schema private to authenticated, service_role;
grant execute on function private.is_admin() to authenticated, service_role;

revoke all on all tables in schema public from anon, authenticated;
grant all on all tables in schema public to service_role;
grant select on public.curriculum to anon;
grant select, insert, update, delete on public.curriculum to authenticated;
grant select, update on public.users to authenticated;
grant select, insert, update, delete on
  public.problems,
  public.problem_answers,
  public.problem_tags,
  public.problem_versions,
  public.exams,
  public.exam_items,
  public.wrong_notes,
  public.bookmarks,
  public.reports
to authenticated;
grant select on public.attempts to authenticated;

alter table public.users enable row level security;
alter table public.curriculum enable row level security;
alter table public.problems enable row level security;
alter table public.problem_answers enable row level security;
alter table public.problem_tags enable row level security;
alter table public.problem_versions enable row level security;
alter table public.exams enable row level security;
alter table public.exam_items enable row level security;
alter table public.attempts enable row level security;
alter table public.wrong_notes enable row level security;
alter table public.bookmarks enable row level security;
alter table public.reports enable row level security;

create policy users_select on public.users for select to authenticated
  using (id = (select auth.uid()) or (select private.is_admin()));
create policy users_update on public.users for update to authenticated
  using (id = (select auth.uid()) or (select private.is_admin()))
  with check (id = (select auth.uid()) or (select private.is_admin()));

create policy curriculum_select on public.curriculum for select to anon, authenticated
  using (true);
create policy curriculum_admin_insert on public.curriculum for insert to authenticated
  with check ((select private.is_admin()));
create policy curriculum_admin_update on public.curriculum for update to authenticated
  using ((select private.is_admin())) with check ((select private.is_admin()));
create policy curriculum_admin_delete on public.curriculum for delete to authenticated
  using ((select private.is_admin()));

create policy problems_select on public.problems for select to authenticated
  using (status = 'published' or (select private.is_admin()));
create policy problems_admin_insert on public.problems for insert to authenticated
  with check ((select private.is_admin()));
create policy problems_admin_update on public.problems for update to authenticated
  using ((select private.is_admin())) with check ((select private.is_admin()));
create policy problems_admin_delete on public.problems for delete to authenticated
  using ((select private.is_admin()));

create policy problem_answers_admin on public.problem_answers for all to authenticated
  using ((select private.is_admin())) with check ((select private.is_admin()));

create policy problem_tags_select on public.problem_tags for select to authenticated
  using (exists (select 1 from public.problems p where p.id = problem_id));
create policy problem_tags_admin_insert on public.problem_tags for insert to authenticated
  with check ((select private.is_admin()));
create policy problem_tags_admin_update on public.problem_tags for update to authenticated
  using ((select private.is_admin())) with check ((select private.is_admin()));
create policy problem_tags_admin_delete on public.problem_tags for delete to authenticated
  using ((select private.is_admin()));

create policy problem_versions_admin on public.problem_versions for all to authenticated
  using ((select private.is_admin())) with check ((select private.is_admin()));

create policy exams_owner on public.exams for all to authenticated
  using (owner_id = (select auth.uid()) or (select private.is_admin()))
  with check (owner_id = (select auth.uid()) or (select private.is_admin()));

create policy exam_items_select on public.exam_items for select to authenticated
  using (exists (select 1 from public.exams e where e.id = exam_id));
create policy exam_items_insert on public.exam_items for insert to authenticated
  with check (
    exists (select 1 from public.exams e where e.id = exam_id)
    and exists (select 1 from public.problems p where p.id = problem_id)
  );
create policy exam_items_update on public.exam_items for update to authenticated
  using (exists (select 1 from public.exams e where e.id = exam_id))
  with check (
    exists (select 1 from public.exams e where e.id = exam_id)
    and exists (select 1 from public.problems p where p.id = problem_id)
  );
create policy exam_items_delete on public.exam_items for delete to authenticated
  using (exists (select 1 from public.exams e where e.id = exam_id));

-- No client insert policy: is_correct must come from server-side grading, not the student.
create policy attempts_select on public.attempts for select to authenticated
  using (user_id = (select auth.uid()) or (select private.is_admin()));

create policy wrong_notes_owner on public.wrong_notes for all to authenticated
  using (user_id = (select auth.uid()))
  with check (
    user_id = (select auth.uid())
    and exists (select 1 from public.problems p where p.id = problem_id)
  );

create policy bookmarks_owner on public.bookmarks for all to authenticated
  using (user_id = (select auth.uid()))
  with check (
    user_id = (select auth.uid())
    and exists (select 1 from public.problems p where p.id = problem_id)
  );

create policy reports_select on public.reports for select to authenticated
  using (user_id = (select auth.uid()) or (select private.is_admin()));
create policy reports_insert on public.reports for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and status = 'open'
    and exists (select 1 from public.problems p where p.id = problem_id)
  );
create policy reports_admin_update on public.reports for update to authenticated
  using ((select private.is_admin())) with check ((select private.is_admin()));
create policy reports_admin_delete on public.reports for delete to authenticated
  using ((select private.is_admin()));
