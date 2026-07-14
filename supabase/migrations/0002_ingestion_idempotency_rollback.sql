-- ============================================================================
-- ROLLBACK for 0002_ingestion_idempotency.sql
-- ============================================================================
-- Drops the additive index and column. Deletes no rows. Any client_id values
-- written after 0002 was applied are lost on rollback, but no session row is
-- removed and no historical field changes.
-- ============================================================================

begin;

drop index if exists public.sessions_client_id_uidx;

alter table public.sessions
  drop column if exists client_id;

commit;
