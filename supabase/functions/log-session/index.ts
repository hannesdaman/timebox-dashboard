// ============================================================================
// TimeBox — log-session Edge Function (Phase 2 validated ingestion)
// ============================================================================
// The single privileged write path. The service-role key lives ONLY in this
// function's server environment (never in the dashboard or watch binary). The
// browser/watch call this endpoint with the public anon key just to pass the
// gateway; the actual INSERT is performed here with the service role after
// validation and idempotency checks.
//
// This does not weaken RLS: once the new watch build and dashboard post here,
// anon INSERT can be revoked entirely (migration 0003, not written yet — see
// SECURITY.md rollout). Until then this coexists with the 0001 anon-insert
// policy.
//
// Deploy (after approval):
//   supabase functions deploy log-session --no-verify-jwt
//   supabase secrets set SB_URL=... SB_SERVICE_ROLE_KEY=...   # server-only
// Local test:
//   supabase functions serve log-session --env-file supabase/functions/.env.local
//   curl -i localhost:54321/functions/v1/log-session -H 'content-type: application/json' \
//        -d '{"session_date":"2026-07-14","duration":25,"tag":"Studying","client_id":"t-1"}'
// ============================================================================

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
// Shared pure validator — unit-tested under Node via validate.test.mjs.
import { validateSession } from './validate.mjs';

const CORS = {
  'Access-Control-Allow-Origin': '*', // tighten to the dashboard origin in prod
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, 'content-type': 'application/json' },
  });
}

// Naive per-instance rate limit. Edge instances are ephemeral and horizontally
// scaled, so this is best-effort abuse resistance, NOT a hard guarantee — real
// rate limiting belongs at the gateway/WAF. Documented as such in SECURITY.md.
const HITS = new Map<string, number[]>();
const WINDOW_MS = 60_000;
const MAX_PER_WINDOW = 60;
function rateLimited(key: string, now: number): boolean {
  const hits = (HITS.get(key) ?? []).filter((t) => now - t < WINDOW_MS);
  hits.push(now);
  HITS.set(key, hits);
  return hits.length > MAX_PER_WINDOW;
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response(null, { headers: CORS });
  if (req.method !== 'POST') return json(405, { error: 'POST only' });

  const now = Date.now();
  const ip = req.headers.get('x-forwarded-for') ?? 'unknown';
  if (rateLimited(ip, now)) return json(429, { error: 'rate limit exceeded, retry shortly' });

  let body: unknown;
  try { body = await req.json(); } catch { return json(400, { error: 'invalid JSON' }); }

  const v = validateSession(body);
  if (!v.ok) return json(422, { error: v.error });

  const url = Deno.env.get('SB_URL');
  const serviceKey = Deno.env.get('SB_SERVICE_ROLE_KEY');
  if (!url || !serviceKey) return json(500, { error: 'server not configured' });

  const admin = createClient(url, serviceKey, { auth: { persistSession: false } });

  // Idempotency: if client_id is provided and already stored, return the
  // existing row instead of inserting a duplicate (offline-queue retries).
  const payload = v.value;
  if (payload.client_id) {
    const existing = await admin.from('sessions').select('*').eq('client_id', payload.client_id).limit(1);
    if (!existing.error && existing.data && existing.data.length > 0) {
      return json(200, { status: 'duplicate', row: existing.data[0] });
    }
  }

  const ins = await admin.from('sessions').insert(payload).select().limit(1);
  if (ins.error) {
    // Unique-violation race on client_id -> treat as success (already stored).
    if ((ins.error as { code?: string }).code === '23505' && payload.client_id) {
      const row = await admin.from('sessions').select('*').eq('client_id', payload.client_id).limit(1);
      if (!row.error && row.data && row.data.length) return json(200, { status: 'duplicate', row: row.data[0] });
    }
    return json(500, { error: 'insert failed' });
  }
  return json(201, { status: 'created', row: ins.data?.[0] ?? null });
});
