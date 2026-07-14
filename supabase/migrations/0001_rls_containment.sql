-- ============================================================================
-- TimeBox — RLS containment (Phase 1)
-- ============================================================================
-- PURPOSE
--   The `anon` role currently has full CRUD on public.sessions: anyone holding
--   the public anon key (it ships in the dashboard and watch) can INSERT,
--   UPDATE, or DELETE any row, including `DELETE /sessions?id=gt.0` to wipe all
--   history. This migration closes UPDATE and mass-DELETE while KEEPING the
--   currently deployed watch build and the dashboard working.
--
-- COMPATIBILITY (why this does not break the deployed watch)
--   Deployed watch build performs, via the anon key:
--     * INSERT  (session sync)               -> still allowed, now validated
--     * DELETE  (reset-today, undo-last)     -> allowed ONLY for rows created
--                                               in the last 3 days (its use case)
--     * SELECT  (stats reconcile)            -> still allowed
--   Deployed watch NEVER performs UPDATE -> revoking anon UPDATE is zero-impact.
--   Dashboard performs SELECT / INSERT / DELETE with the same anon key and is
--   affected identically.
--
-- BLAST RADIUS
--   Object: public.sessions only (no other tables exist in this project).
--   No rows are read, written, moved, or deleted by this migration. It changes
--   only access-control metadata (RLS + policies). Fully reversible via
--   0001_rls_containment_rollback.sql.
--
-- APPLY (only after explicit approval — see SECURITY.md):
--   supabase db push          # against the linked project, or
--   psql "$DATABASE_URL" -f supabase/migrations/0001_rls_containment.sql
--
-- VERIFY AFTER APPLY (expected results in SECURITY.md §Verification):
--   anon DELETE ?id=gt.0            -> 0 rows / blocked for old rows
--   anon PATCH  ?id=eq.<x>          -> 401/403 (no policy)
--   anon POST   {duration:99999}    -> 403 (WITH CHECK)
--   anon GET                        -> 200 (unchanged)
-- ============================================================================

begin;

-- 1) Turn RLS on. With RLS enabled and no permissive policy for a command,
--    that command is denied for anon by default (deny-by-default).
alter table public.sessions enable row level security;

-- 2) Drop ALL existing policies on the table, not just prior TimeBox ones.
--    A table can carry pre-existing PERMISSIVE policies (Postgres OR-combines
--    permissive policies), so leaving even one "allow all" policy in place would
--    defeat the validation/deny rules below. Enumerating and dropping every
--    policy makes this migration both idempotent and actually enforcing.
--    (Applied to production 2026-07-14; verified rls_enabled=true with exactly
--    the three policies below and no UPDATE policy.)
do $$
declare p record;
begin
  for p in select policyname from pg_policies
           where schemaname = 'public' and tablename = 'sessions'
  loop
    execute format('drop policy if exists %I on public.sessions', p.policyname);
  end loop;
end $$;

-- 3) SELECT: unchanged. The dashboard is a personal read surface and the watch
--    reconcile reads recent rows. (Read-privacy is a Phase 2 concern; see
--    SECURITY.md residual risks.)
create policy timebox_anon_select
  on public.sessions
  for select
  to anon
  using (true);

-- 4) INSERT: still allowed for anon (deployed watch + dashboard both need it),
--    but validated so arbitrary garbage cannot be injected. Rate-limiting is
--    NOT expressible in RLS — that is the job of the Phase 2 ingestion
--    endpoint (supabase/functions/log-session).
create policy timebox_anon_insert
  on public.sessions
  for insert
  to anon
  with check (
        duration is not null
    and duration >= 1
    and duration <= 1440
    and session_date is not null
    and session_date >= date '2020-01-01'
    and session_date <= (current_date + 2)
    and (tag is null or char_length(tag) <= 60)
  );

-- 5) DELETE: narrowed to a rolling recent window. This preserves the deployed
--    watch's reset-today / undo-last (they act on today's rows) and the
--    dashboard's delete of a just-logged mistake, while making it impossible to
--    delete the historical archive. `created_at` is a server default timestamp
--    on every row.
create policy timebox_anon_delete_recent
  on public.sessions
  for delete
  to anon
  using (created_at >= (now() - interval '3 days'));

-- 6) UPDATE: intentionally NO policy -> denied for anon. Nothing in the watch
--    or dashboard updates rows, so this is a pure security gain.

commit;

-- Post-conditions (informational; run manually as a privileged user):
--   select relrowsecurity from pg_class where relname = 'sessions';   -- t
--   select polname, cmd from pg_policies where tablename = 'sessions';
