// Pure ingestion validator — the single source of truth for what the
// log-session Edge Function accepts. Plain ESM JS with no Deno/Node APIs so it
// can be imported by both index.ts (Deno runtime) and validate.test.mjs (Node).
export function validateSession(input) {
    if (typeof input !== 'object' || input === null) return { ok: false, error: 'body must be an object' };
    const b = input;

    const duration = Number(b.duration);
    if (!Number.isFinite(duration) || !Number.isInteger(duration) || duration < 1 || duration > 1440) {
        return { ok: false, error: 'duration must be an integer 1..1440' };
    }
    if (typeof b.session_date !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(b.session_date)) {
        return { ok: false, error: 'session_date must be YYYY-MM-DD' };
    }
    const d = new Date(b.session_date + 'T12:00:00Z');
    if (isNaN(d.getTime())) return { ok: false, error: 'session_date is not a real date' };
    const year = Number(b.session_date.slice(0, 4));
    if (year < 2020 || year > 2100) return { ok: false, error: 'session_date out of range' };

    let tag = null;
    if (b.tag != null) {
        if (typeof b.tag !== 'string') return { ok: false, error: 'tag must be a string' };
        if (b.tag.length > 60) return { ok: false, error: 'tag too long' };
        tag = b.tag;
    }

    let created_at;
    if (b.created_at != null) {
        if (typeof b.created_at !== 'string' || isNaN(Date.parse(b.created_at))) {
            return { ok: false, error: 'created_at must be an ISO timestamp' };
        }
        created_at = b.created_at;
    }

    let client_id;
    if (b.client_id != null) {
        if (typeof b.client_id !== 'string' || b.client_id.length > 80) {
            return { ok: false, error: 'client_id must be a string <= 80 chars' };
        }
        client_id = b.client_id;
    }

    const value = { duration, session_date: b.session_date, tag };
    if (created_at) value.created_at = created_at;
    if (client_id) value.client_id = client_id;
    return { ok: true, value };
}
