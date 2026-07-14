-- ============================================================================
-- ROLLBACK for 0001_rls_containment.sql
-- ============================================================================
-- Restores the pre-migration authorization state: RLS disabled, no TimeBox
-- policies. This returns anon to full CRUD (the original, insecure state) and
-- is provided only so the change is fully reversible. It deletes no data.
--
-- APPLY:
--   psql "$DATABASE_URL" -f supabase/migrations/0001_rls_containment_rollback.sql
-- ============================================================================

begin;

drop policy if exists timebox_anon_select on public.sessions;
drop policy if exists timebox_anon_insert on public.sessions;
drop policy if exists timebox_anon_delete_recent on public.sessions;

-- Disabling RLS returns to the original behavior where table grants alone
-- govern access (anon had full CRUD).
alter table public.sessions disable row level security;

commit;
