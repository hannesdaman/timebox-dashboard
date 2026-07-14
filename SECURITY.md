# TimeBox — Security Architecture & Rollout

Status: **prepared locally, nothing applied remotely.** No migration, policy, or
function in this repo has been run against the live Supabase project. Applying
them requires the explicit approval step in **§7 Rollout**.

---

## 1. Current threat model (measured, not assumed)

Single table `public.sessions` in project `gujufwafdradmmehtafx`. The public
`anon` JWT ships in both the dashboard (`index.html`) and the Garmin watch
binary. Both clients talk directly to PostgREST (`/rest/v1/sessions`).

Authorization was probed **non-destructively** on 2026-07-14 using
zero-matching filters (`id=eq.-1`) and an empty-array insert, with an exact
row-count check immediately before and after (776 → 776, unchanged):

| Operation | Probe | Result | Meaning |
|-----------|-------|--------|---------|
| SELECT | `GET /sessions` | 200 | anyone can read all history |
| INSERT | `POST []` (inserts nothing) | 201 | anyone can inject rows |
| UPDATE | `PATCH ?id=eq.-1` | 204 | anyone can tamper any row |
| DELETE | `DELETE ?id=eq.-1` | 204 | anyone can delete any row |

**Conclusion:** RLS is effectively open for `anon` (either disabled or a
fully-permissive policy). The public key is not the defect — a public anon key
is normal. The defect is that **the database grants that key full CRUD**.

### Exploitability

- **Catastrophic, trivial:** `DELETE /rest/v1/sessions?id=gt.0` with the public
  key wipes all 776 rows in one request. No auth, no rate limit observed. This
  is the top risk. *(Not executed — proven only via the zero-match probe.)*
- **High:** `PATCH` can silently rewrite durations/dates/tags, corrupting every
  metric.
- **Medium:** `POST` can flood the table with junk, polluting analytics and
  eventually stressing the client-side aggregation.
- **Low/known:** all history is publicly readable. This is inherent to a
  public anon-key dashboard and is accepted for now (see Residual risks).

### What is NOT exposed
- No other tables exist (`projects`, `goals`, `presets`, `users`, `profiles`
  all return 404). Projects/goals/presets live on the watch (`Storage`) and in
  browser `localStorage`. Blast radius is one table.
- No `service_role` key is committed anywhere in the repo or embedded in the
  watch/dashboard (verified via `git grep`). Only the anon key appears.

---

## 2. Constraints that shape the design

1. **The currently deployed watch build depends on anon `INSERT`** (session
   sync) and anon `DELETE` (reset-today, undo-last), and reads via `SELECT`. It
   never issues `UPDATE`. Any change that blocks anon INSERT **locks the watch
   out of syncing** until a new build is sideloaded. Sequencing must not do
   that.
2. No destructive data migration. Fixes are RLS/policy only; zero rows touched.
3. Must stay maintainable by a solo developer — no heavy infra.
4. Never embed a `service_role` key in browser or watch code.

---

## 3. Why removing the dashboard Delete button is NOT the fix

The dashboard Delete button and `POST` form call the same public PostgREST
endpoint anyone can call with `curl`. Removing the button changes the attack
surface by **zero** — the endpoint is the vulnerability. The real fix is at the
database (RLS). The button is therefore left in place; once RLS (0001) is
applied, anon DELETE of anything older than 3 days fails **at the database**,
which is the enforcement that actually matters. A confirmation dialog only
prevents *accidental* self-deletion; it is not a security control.

---

## 4. Target architecture

Two phases. Phase 1 is small, reversible, and closes the catastrophic holes
without breaking the deployed watch. Phase 2 is the full lockdown and can follow
once a new watch build is validated on hardware.

### Phase 1 — RLS containment  (`migrations/0001_rls_containment.sql`)
- `SELECT`: unchanged (dashboard + watch read).
- `INSERT`: still anon, but `WITH CHECK` (duration 1–1440, valid recent
  `session_date`, tag ≤ 60 chars). Keeps the deployed watch + dashboard logging
  working; blocks absurd payloads.
- `DELETE`: anon allowed **only for rows `created_at >= now() - 3 days`**. The
  watch's reset-today/undo and dashboard "delete a mistake" keep working; the
  **historical archive becomes undeletable** by the public key. This alone
  removes the wipe-everything risk.
- `UPDATE`: **denied** (no policy). Nothing legitimately updates rows, so this
  is a pure gain — closes the tamper vector entirely.

Result after 0001: the two catastrophic vectors (mass delete, arbitrary
tamper) are gone; the deployed watch and dashboard are unaffected.

### Phase 2 — validated ingestion + full lockdown
- `functions/log-session/` — Edge Function; the **only** privileged writer.
  `service_role` key lives in the function's server env, never in a client. It
  validates input (shared `validate.mjs`, unit-tested), enforces idempotency via
  a client-supplied `client_id` (`migrations/0002`, additive column + partial
  unique index), and applies best-effort rate limiting.
- New watch build + dashboard POST through `log-session` instead of PostgREST.
- Then a future `0003` migration revokes anon `INSERT` and anon `DELETE`
  entirely; deletes move behind Supabase Auth (owner login) or the endpoint.
- Optionally, Supabase Auth gates the dashboard so history is no longer world-
  readable (closes the last residual read risk).

### Alternatives considered
- **Auth-only (RLS by `user_id`) now:** cleanest end state, but existing 776
  rows have no `user_id`; backfilling touches every row (violates the
  no-mutation rule) and it locks the deployed watch out immediately. Deferred to
  Phase 2 where it's staged safely.
- **Static secret in the client:** rejected — recoverable from JS/binary, i.e.
  obscurity, not security.
- **Do nothing but remove the button:** rejected — see §3.

---

## 5. Files (all local, none applied)

| File | Purpose | Applied? |
|------|---------|----------|
| `supabase/migrations/0001_rls_containment.sql` | Phase 1 RLS | **No** |
| `supabase/migrations/0001_rls_containment_rollback.sql` | revert 0001 | No |
| `supabase/migrations/0002_ingestion_idempotency.sql` | additive `client_id` | **No** |
| `supabase/migrations/0002_ingestion_idempotency_rollback.sql` | revert 0002 | No |
| `supabase/functions/log-session/index.ts` | validated ingestion | **Not deployed** |
| `supabase/functions/log-session/validate.mjs` | shared validator (tested) | n/a |

---

## 6. Environment / config required (Phase 2 only)

Set as Supabase **function secrets** (never in the repo, never in a client):

```
SB_URL=https://gujufwafdradmmehtafx.supabase.co
SB_SERVICE_ROLE_KEY=<service_role key from Supabase dashboard → API>
```

Phase 1 needs no new env or config.

---

## 7. Rollout (execute only on explicit approval)

Ordered so the watch is never locked out and no downtime occurs.

1. **Back up first.** Export the table and record the policy state:
   ```
   pg_dump "$DATABASE_URL" -t public.sessions --data-only -f sessions_backup_$(date +%F).sql
   psql "$DATABASE_URL" -c "select polname,cmd,qual,with_check from pg_policies where tablename='sessions'"
   psql "$DATABASE_URL" -c "select count(*) from public.sessions"   # expect 776+
   ```
2. **Apply Phase 1 RLS** (containment) — reversible, no data touched:
   ```
   psql "$DATABASE_URL" -f supabase/migrations/0001_rls_containment.sql
   ```
3. **Verify** (see §8). Confirm dashboard still reads, logging still works,
   old-row delete now fails, update now fails.
4. **Confirm the deployed watch still syncs** (log a session on the watch, watch
   for the row). Phase 1 keeps anon INSERT, so this must pass.
5. *(Phase 2, later)* Apply `0002`, deploy `log-session`, set secrets, test in
   isolation (§9 commands), sideload the new watch build that posts through the
   endpoint, verify sync, then apply `0003` to revoke anon INSERT/DELETE.

**Do not** apply `0003` / revoke anon INSERT until the new watch build is
confirmed working on hardware — that is the step that would lock out an old
watch.

## 8. Verification after Phase 1 (expected results)

```
KEY=<anon>; BASE=https://gujufwafdradmmehtafx.supabase.co/rest/v1
# read still works:
curl -s -o /dev/null -w '%{http_code}\n' "$BASE/sessions?select=id&limit=1" -H "apikey:$KEY" -H "Authorization:Bearer $KEY"   # 200
# update now denied:
curl -s -o /dev/null -w '%{http_code}\n' -X PATCH "$BASE/sessions?id=eq.-1" -H "apikey:$KEY" -H "Authorization:Bearer $KEY" -H 'content-type:application/json' -d '{"duration":1}'   # 401/403
# delete of an OLD row denied (use a real old id; expect 0 rows / 403). NON-DESTRUCTIVE only with a non-matching or old id you do NOT want gone:
#   prefer testing the policy shape in a branch/staging project, not prod.
# junk insert denied:
curl -s -o /dev/null -w '%{http_code}\n' -X POST "$BASE/sessions" -H "apikey:$KEY" -H "Authorization:Bearer $KEY" -H 'content-type:application/json' -d '{"duration":99999,"session_date":"2026-07-14"}'   # 403
```

## 9. Isolated testing (no production writes)

Use a Supabase **branch** or a throwaway local stack — never production:

```
supabase start                                   # local postgres + api
psql "$LOCAL_DB_URL" -f supabase/migrations/0001_rls_containment.sql
psql "$LOCAL_DB_URL" -f supabase/migrations/0002_ingestion_idempotency.sql
supabase functions serve log-session --env-file supabase/functions/.env.local
node --test tests/log-session-validate.test.mjs   # validator unit tests
```

## 10. Rollback

- **Dashboard code:** `git checkout -- index.html` (or revert the commit).
- **Watch code:** `git checkout -- watchapp/` then rebuild/sideload the prior
  `.prg`.
- **Phase 1 policies:** `psql "$DATABASE_URL" -f supabase/migrations/0001_rls_containment_rollback.sql`
  (returns anon to full CRUD — the original state).
- **Phase 2 schema:** `...0002_..._rollback.sql` (drops the additive column/index; no rows removed).
- **Edge Function:** `supabase functions delete log-session`.
- No rollback path deletes or rewrites any session row.

## 11. Residual risks (after Phase 1)

- **History remains world-readable** with the anon key. Closing this needs
  Supabase Auth (Phase 2) and would gate the dashboard behind login.
- **Anon INSERT is still open** (validated but unauthenticated); an abuser can
  still insert *valid-shaped* rows until Phase 2 moves writes behind the
  endpoint. Bounded by the `WITH CHECK`, not eliminated.
- **Delete of the last 3 days is still possible** by the public key (needed for
  the deployed watch). Fully closed in Phase 2.
- **Rate limiting** in the Edge Function is per-instance and best-effort; true
  limiting needs a gateway/WAF.
- The anon key itself is unchanged. Rotating it is orthogonal and would require
  updating both clients; not required by this plan.
