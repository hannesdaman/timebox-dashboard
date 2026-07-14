-- ============================================================================
-- TimeBox — ingestion idempotency (Phase 2, additive)
-- ============================================================================
-- PURPOSE
--   Support the log-session Edge Function (privileged, service-role) as the
--   single validated write path for a NEW watch build and the dashboard. A
--   client-supplied idempotency key lets retries (offline queue, flaky
--   network) collapse to a single row instead of creating duplicates.
--
-- SAFETY
--   Purely additive:
--     * ADD COLUMN ... IF NOT EXISTS  (nullable, no default backfill)
--     * CREATE UNIQUE INDEX ... only over NON-NULL client_id values, so all
--       existing rows (client_id IS NULL) are unaffected and never collide.
--   No existing row is read for content, updated, moved, or deleted. No
--   primary key, timestamp, or historical value changes.
--
--   Row-count invariant: SELECT count(*) is identical before and after.
--
-- APPLY (after approval):
--   supabase db push   (or psql -f)
-- ROLLBACK:
--   0002_ingestion_idempotency_rollback.sql
-- ============================================================================

begin;

alter table public.sessions
  add column if not exists client_id text;

-- Partial unique index: uniqueness enforced ONLY where client_id is present.
-- Existing rows (NULL) are exempt; two NULLs never conflict.
create unique index if not exists sessions_client_id_uidx
  on public.sessions (client_id)
  where client_id is not null;

commit;
