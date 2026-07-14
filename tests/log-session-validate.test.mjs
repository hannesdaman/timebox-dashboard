// Unit tests for the log-session Edge Function's input validator.
// Imports the shared pure module used by the deployed function, so these tests
// exercise the exact acceptance logic. No network, no Supabase, no writes.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { validateSession } from '../supabase/functions/log-session/validate.mjs';

test('accepts a well-formed session', () => {
    const r = validateSession({ session_date: '2026-07-14', duration: 25, tag: 'Studying' });
    assert.equal(r.ok, true);
    assert.deepEqual(r.value, { duration: 25, session_date: '2026-07-14', tag: 'Studying' });
});

test('accepts optional created_at and client_id and passes them through', () => {
    const r = validateSession({ session_date: '2026-07-14', duration: 90, client_id: 'w-123', created_at: '2026-07-14T20:00:00Z' });
    assert.equal(r.ok, true);
    assert.equal(r.value.client_id, 'w-123');
    assert.equal(r.value.created_at, '2026-07-14T20:00:00Z');
    assert.equal(r.value.tag, null); // absent tag -> null (DB default applies)
});

test('rejects non-object bodies', () => {
    for (const b of [null, undefined, 42, 'x', []]) {
        // arrays are objects but have no duration -> also rejected
        assert.equal(validateSession(b).ok, false);
    }
});

test('rejects out-of-range and non-integer durations', () => {
    assert.equal(validateSession({ session_date: '2026-07-14', duration: 0 }).ok, false);
    assert.equal(validateSession({ session_date: '2026-07-14', duration: -5 }).ok, false);
    assert.equal(validateSession({ session_date: '2026-07-14', duration: 5000 }).ok, false);
    assert.equal(validateSession({ session_date: '2026-07-14', duration: 25.5 }).ok, false);
    assert.equal(validateSession({ session_date: '2026-07-14', duration: 'NaN' }).ok, false);
    assert.equal(validateSession({ session_date: '2026-07-14' }).ok, false); // missing
});

test('rejects malformed or out-of-range dates', () => {
    assert.equal(validateSession({ session_date: '2026-7-4', duration: 25 }).ok, false);
    assert.equal(validateSession({ session_date: '2026-13-40', duration: 25 }).ok, false);
    assert.equal(validateSession({ session_date: '1999-01-01', duration: 25 }).ok, false);
    assert.equal(validateSession({ session_date: 20260714, duration: 25 }).ok, false);
});

test('rejects oversized tag and client_id, and non-string tag', () => {
    assert.equal(validateSession({ session_date: '2026-07-14', duration: 25, tag: 'x'.repeat(61) }).ok, false);
    assert.equal(validateSession({ session_date: '2026-07-14', duration: 25, tag: 123 }).ok, false);
    assert.equal(validateSession({ session_date: '2026-07-14', duration: 25, client_id: 'x'.repeat(81) }).ok, false);
});

test('rejects malformed created_at', () => {
    assert.equal(validateSession({ session_date: '2026-07-14', duration: 25, created_at: 'not-a-date' }).ok, false);
});

test('does not echo unexpected fields (no injection of arbitrary columns)', () => {
    const r = validateSession({ session_date: '2026-07-14', duration: 25, tag: 'A', id: 999, user_id: 'evil', is_admin: true });
    assert.equal(r.ok, true);
    assert.deepEqual(Object.keys(r.value).sort(), ['duration', 'session_date', 'tag']);
});
