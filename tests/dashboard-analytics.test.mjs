// Fixture-based tests for the dashboard's canonical analytics layer.
// Run: TZ=Europe/Stockholm node --test tests/
// The analytics <script id="tb-analytics"> block is extracted from index.html
// and evaluated in isolation — no network, no Supabase, no DOM.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import vm from 'node:vm';

const root = dirname(dirname(fileURLToPath(import.meta.url)));
const html = readFileSync(join(root, 'index.html'), 'utf8');
const match = html.match(/<script id="tb-analytics">([\s\S]*?)<\/script>/);
assert.ok(match, 'tb-analytics script block must exist in index.html');

const sandbox = { module: { exports: {} }, window: undefined };
vm.createContext(sandbox);
vm.runInContext(match[1], sandbox);
const TB = sandbox.module.exports;
assert.ok(TB && typeof TB.computeAnalytics === 'function', 'TB module exports computeAnalytics');

// helpers -------------------------------------------------------------
let nextId = 1;
function s(day, duration, tag = 'Studying', createdAt = null) {
    return { id: nextId++, session_date: day, created_at: createdAt, duration, tag };
}
function compute(rows, { tag = 'All', goal = 0, now } = {}) {
    const norm = TB.normalize(rows);
    return TB.computeAnalytics(norm.sessions, tag, goal, now);
}
// A fixed "now": Wednesday 2026-07-15 14:00 local (logical day = same).
const NOW = new Date('2026-07-15T14:00:00');

// ---------------------------------------------------------------------
test('02:30 cutoff: logical today flips at the boundary', () => {
    assert.equal(TB.logicalToday(new Date('2026-07-15T02:29:00')), '2026-07-14');
    assert.equal(TB.logicalToday(new Date('2026-07-15T02:30:00')), '2026-07-15');
    assert.equal(TB.logicalToday(new Date('2026-07-15T00:00:00')), '2026-07-14');
    assert.equal(TB.logicalToday(new Date('2026-07-15T23:59:00')), '2026-07-15');
});

test('effectiveDay: stored date wins; legacy cutoff-miss rolls back; created_at fallback', () => {
    // backdated manual entry keeps its stored day
    assert.equal(TB.effectiveDay({ session_date: '2026-07-10', created_at: '2026-07-12T20:00:00+02:00' }), '2026-07-10');
    // legacy row: stored = raw calendar day of a 00:30 log -> previous day
    assert.equal(TB.effectiveDay({ session_date: '2026-07-13', created_at: '2026-07-13T00:30:00+02:00' }), '2026-07-12');
    // no stored date -> rolled created_at
    assert.equal(TB.effectiveDay({ session_date: null, created_at: '2026-07-13T01:00:00+02:00' }), '2026-07-12');
    assert.equal(TB.effectiveDay({ session_date: null, created_at: '2026-07-13T12:00:00+02:00' }), '2026-07-13');
});

test('normalize: malformed rows are excluded with reasons, never silently dropped', () => {
    const norm = TB.normalize([
        s('2026-07-14', 25),
        { id: 999, session_date: null, created_at: null, duration: 25, tag: 'X' },
        s('2026-07-14', 0),
        s('2026-07-14', -5),
        s('2026-07-14', 5000),
        { id: 1000, session_date: '2026-07-14', duration: 30, tag: null }
    ]);
    assert.equal(norm.sessions.length, 2); // the valid one + null-tag row
    assert.equal(norm.sessions.find(x => x.id === 1000).tag, 'Uncategorized');
    assert.equal(norm.excluded.length, 4);
});

test('week boundaries: Monday start, year boundary, ISO weeks', () => {
    assert.equal(TB.weekStart('2026-07-15'), '2026-07-13'); // Wed -> Mon
    assert.equal(TB.weekStart('2026-07-13'), '2026-07-13'); // Mon -> itself
    assert.equal(TB.weekStart('2026-07-19'), '2026-07-13'); // Sun -> prev Mon
    assert.equal(TB.weekStart('2026-01-01'), '2025-12-29'); // year boundary
    assert.equal(TB.isoWeek('2026-01-01'), 1);
    assert.equal(TB.isoWeek('2025-12-29'), 1);  // ISO: week of 2026-01-01
    assert.equal(TB.isoWeek('2025-12-28'), 52); // Sunday of prior ISO week
    assert.equal(TB.isoWeek('2026-07-15'), 29);
});

test('DST transitions do not corrupt day arithmetic (Europe/Stockholm)', () => {
    // DST starts 2026-03-29, ends 2026-10-25
    assert.equal(TB.addDays('2026-03-28', 1), '2026-03-29');
    assert.equal(TB.addDays('2026-03-29', 1), '2026-03-30');
    assert.equal(TB.dayDiff('2026-03-28', '2026-03-30'), 2);
    assert.equal(TB.addDays('2026-10-24', 2), '2026-10-26');
    assert.equal(TB.dayDiff('2026-10-24', '2026-10-26'), 2);
    assert.equal(TB.weekStart('2026-03-29'), '2026-03-23');
});

test('today/week totals and same-days comparison', () => {
    const rows = [
        s('2026-07-15', 60), s('2026-07-15', 30),   // today (Wed)
        s('2026-07-13', 100),                        // Mon this week
        s('2026-07-08', 120), s('2026-07-06', 50),   // last week Wed + Mon
        s('2026-07-11', 500)                         // last week Sat (outside Mon..Wed span)
    ];
    const a = compute(rows, { now: NOW });
    assert.equal(a.todayMin, 90);
    assert.equal(a.todaySessions, 2);
    assert.equal(a.week.minutes, 190);
    assert.equal(a.week.lastWeekSameDays, 170); // Mon 50 + Wed 120, Sat excluded
    assert.equal(a.week.deltaVsLastWeekSameDays, 20);
});

test('goal & pace: expected-by-now, ahead/behind, required pace, projection', () => {
    const rows = [s('2026-07-13', 240), s('2026-07-14', 240), s('2026-07-15', 120)];
    const goal = 1200; // 20h weekly goal
    const a = compute(rows, { goal, now: NOW });
    // Wed 14:00 logical fraction: shifted 11:30 -> 0.479...; elapsed = (2 + 0.479)/7
    assert.ok(Math.abs(a.week.elapsedFrac - (2 + 11.5 / 24) / 7) < 1e-9);
    assert.ok(Math.abs(a.week.expectedByNow - goal * a.week.elapsedFrac) < 1e-9);
    assert.equal(a.week.minutes, 600);
    assert.ok(a.week.aheadMin > 0); // 600 vs ~425 expected
    assert.equal(a.week.remainingToGoal, 600);
    assert.ok(a.week.requiredPerDay > 0 && a.week.requiredPerDay < 600);
    // projection = current + dailyAvg28 * remainingDays
    const expectedProj = a.week.minutes + a.rolling.dailyAvg28 * a.week.remainingDays;
    assert.ok(Math.abs(a.week.projected - expectedProj) < 1e-9);
});

test('partial current week is never compared as a complete week (goal history)', () => {
    const rows = [s('2026-07-15', 600), s('2026-07-08', 300), s('2026-07-01', 800)];
    const a = compute(rows, { goal: 600, now: NOW });
    // prevWeeks[0] is last week (complete), current week is not in prevWeeks
    assert.equal(a.prevWeeks[0].weekStart, '2026-07-06');
    assert.equal(a.prevWeeks[0].minutes, 300);
    assert.equal(a.prevWeeks[1].minutes, 800);
    // goal-hit counting only spans weeks with history
    assert.equal(a.goalHitTotal, 2);
    assert.equal(a.goalHitCount, 1);
});

test('streaks: current, best, gap; today-optional grace', () => {
    const rows = [s('2026-07-15', 30), s('2026-07-14', 30), s('2026-07-13', 30), s('2026-07-10', 30)];
    const a = compute(rows, { now: NOW });
    assert.equal(a.consistency.streak, 3);
    assert.equal(a.consistency.bestStreak, 3);
    // no session today: streak counts back from yesterday
    const b = compute([s('2026-07-14', 30), s('2026-07-13', 30)], { now: NOW });
    assert.equal(b.consistency.streak, 2);
    const c = compute([s('2026-06-20', 30)], { now: NOW });
    assert.equal(c.consistency.streak, 0);
});

test('rolling 28d window: calendar-day average includes zero days', () => {
    const rows = [s('2026-07-15', 280)];
    const a = compute(rows, { now: NOW });
    assert.equal(a.rolling.min28, 280);
    assert.ok(Math.abs(a.rolling.dailyAvg28 - 10) < 1e-9); // 280/28
    assert.equal(a.rolling.active28, 1);
    assert.equal(a.rolling.active7, 1);
});

test('median vs mean session; focus depth threshold at 45 minutes', () => {
    const rows = [s('2026-07-15', 10), s('2026-07-14', 20), s('2026-07-13', 90)];
    const a = compute(rows, { now: NOW });
    assert.equal(a.sessions28.medianDur, 20);
    assert.equal(a.sessions28.meanDur, 40);
    assert.ok(Math.abs(a.sessions28.focusShare - 90 / 120) < 1e-9);
    assert.equal(TB.median([]), 0);
    assert.equal(TB.median([25, 50]), 38); // even count -> rounded midpoint
});

test('categories: share, prior-28d share delta, per-category stats; filter-independent', () => {
    const rows = [
        s('2026-07-15', 60, 'A'), s('2026-07-14', 60, 'A'), s('2026-07-13', 120, 'B'),
        // prior 28d window (2026-05-20..2026-06-17): A dominates
        s('2026-06-10', 200, 'A'), s('2026-06-11', 40, 'B')
    ];
    const a = compute(rows, { tag: 'B', goal: 0, now: NOW });
    // category table always spans all tags even when filtered to B
    assert.equal(a.categories.length, 2);
    const A = a.categories.find(c => c.tag === 'A'), B = a.categories.find(c => c.tag === 'B');
    assert.equal(A.minutes, 120); assert.equal(B.minutes, 120);
    assert.ok(Math.abs(A.share - 0.5) < 1e-9);
    // A prior share 200/240, now 0.5 -> negative delta; B mirrors positive
    assert.ok(A.deltaShare < 0 && B.deltaShare > 0);
    assert.equal(A.activeDays, 2);
    assert.equal(B.medianSession, 120);
});

test('category filter applies to metrics: week/today/records', () => {
    const rows = [s('2026-07-15', 60, 'A'), s('2026-07-15', 30, 'B'), s('2026-07-06', 300, 'B')];
    const all = compute(rows, { now: NOW });
    const onlyB = compute(rows, { tag: 'B', now: NOW });
    assert.equal(all.todayMin, 90);
    assert.equal(onlyB.todayMin, 30);
    assert.equal(onlyB.records.bestDay.minutes, 300);
    assert.equal(onlyB.totalSessions, 2);
});

test('records carry dates; longest session tracked', () => {
    const rows = [s('2026-05-01', 90), s('2026-05-01', 200), s('2026-06-15', 250)];
    const a = compute(rows, { now: NOW });
    assert.equal(a.records.bestDay.day, '2026-05-01');
    assert.equal(a.records.bestDay.minutes, 290);
    assert.equal(a.records.longestSession.minutes, 250);
    assert.equal(a.records.longestSession.day, '2026-06-15');
    assert.equal(a.records.bestWeek.weekStart, TB.weekStart('2026-05-01'));
});

test('empty dataset and single-session dataset degrade gracefully', () => {
    const empty = compute([], { goal: 600, now: NOW });
    assert.equal(empty.totalSessions, 0);
    assert.equal(empty.week.minutes, 0);
    assert.equal(empty.consistency.streak, 0);
    assert.equal(empty.records.bestDay.minutes, 0);
    assert.equal(TB.cumulativeSeries(empty).length, 0);
    const one = compute([s('2026-07-15', 50)], { now: NOW });
    assert.equal(one.totalSessions, 1);
    assert.equal(TB.cumulativeSeries(one).length, 1);
});

test('daily/weekly/cumulative series: uniform axes, rolling windows, partial marking', () => {
    const rows = [s('2026-07-15', 70), s('2026-07-09', 140)];
    const a = compute(rows, { now: NOW });
    const daily = TB.dailySeries(a, 28);
    assert.equal(daily.points.length, 28);
    assert.equal(daily.points[27].key, '2026-07-15');
    assert.equal(daily.points[27].isToday, true);
    assert.equal(daily.rolling[5], null); // needs full 7-day trailing window
    assert.ok(Math.abs(daily.rolling[27] - 210 / 7) < 1e-9); // Jul 9 + Jul 15 both inside the trailing 7 days
    const weekly = TB.weeklySeries(a, 8);
    assert.equal(weekly.points.length, 8);
    assert.equal(weekly.points[7].isCurrent, true);
    const cum = TB.cumulativeSeries(a);
    assert.equal(cum.length, TB.dayDiff('2026-07-09', '2026-07-15') + 1); // calendar-uniform
    assert.ok(Math.abs(cum[cum.length - 1].hours - 210 / 60) < 1e-9);
});

test('weekday rhythm uses complete weeks only', () => {
    // Session today (Wed) must NOT leak into the rhythm (current week incomplete)
    const rows = [s('2026-07-15', 999), s('2026-07-08', 80), s('2026-07-01', 80)];
    const a = compute(rows, { now: NOW });
    const wedAvg = a.weekdayAvg[2];
    assert.ok(Math.abs(wedAvg - 160 / 8) < 1e-9);
    assert.equal(a.weekdayAvg[0], 0);
});

test('CSV: header, ordering, quoting, filename with range and filter', () => {
    const norm = TB.normalize([
        s('2026-07-14', 25, 'A "quoted"'),
        s('2026-07-01', 50, 'B')
    ]);
    const csv = TB.buildCsv(norm.sessions);
    const lines = csv.split('\n');
    assert.equal(lines[0], 'id,logical_day,stored_session_date,created_at_utc,duration_min,category');
    assert.ok(lines[1].includes('"2026-07-01"')); // sorted ascending
    assert.ok(lines[2].includes('"A ""quoted"""')); // proper escaping
    assert.equal(TB.csvFilename(norm.sessions, 'All', '2026-07-15'), 'timebox_sessions_2026-07-01_to_2026-07-14_all.csv');
    assert.equal(TB.csvFilename(norm.sessions, 'Aff project', '2026-07-15'), 'timebox_sessions_2026-07-01_to_2026-07-14_aff-project.csv');
    assert.equal(TB.csvFilename([], 'All', '2026-07-15'), 'timebox_sessions_2026-07-15_to_2026-07-15_all.csv');
});

test('pagination: walks >1000 rows across pages by keyset, stable order', async () => {
    // 2500 rows, ids 1..2500; server returns pages of 1000 filtered by id>lastId
    const all = Array.from({ length: 2500 }, (_, i) => ({ id: i + 1, session_date: '2026-07-01', duration: 25, tag: 'X' }));
    let calls = 0;
    const fetchPage = async (lastId) => { calls++; return all.filter(r => r.id > lastId).slice(0, 1000); };
    const out = await TB.pageWalk(fetchPage, 1000);
    assert.equal(out.length, 2500);
    assert.equal(out[0].id, 1);
    assert.equal(out[2499].id, 2500);
    assert.equal(calls, 3); // 1000 + 1000 + 500
});

test('pagination: dedupes if a row overlaps two pages (concurrent insert shift)', async () => {
    // Page 1 returns ids 1..1000; page 2 accidentally re-includes id 1000
    const pages = [
        Array.from({ length: 1000 }, (_, i) => ({ id: i + 1, duration: 25, session_date: '2026-07-01', tag: 'X' })),
        [{ id: 1000, duration: 25, session_date: '2026-07-01', tag: 'X' }, { id: 1001, duration: 25, session_date: '2026-07-01', tag: 'X' }]
    ];
    let call = 0;
    const out = await TB.pageWalk(async () => pages[call++], 1000);
    const ids = out.map(r => r.id);
    assert.equal(new Set(ids).size, ids.length, 'no duplicate ids');
    assert.equal(out.length, 1001);
});

test('pagination: an intermediate page failure rejects (no silent partial)', async () => {
    let call = 0;
    const fetchPage = async (lastId) => {
        if (call++ === 1) throw new Error('HTTP 500 on page 2');
        return Array.from({ length: 1000 }, (_, i) => ({ id: i + 1, duration: 25, session_date: '2026-07-01', tag: 'X' }));
    };
    await assert.rejects(() => TB.pageWalk(fetchPage, 1000), /HTTP 500/);
});

test('pagination: terminates on a short final page and on empty data', async () => {
    const out = await TB.pageWalk(async (lastId) => lastId === 0 ? [{ id: 1, duration: 25, session_date: '2026-07-01', tag: 'X' }] : [], 1000);
    assert.equal(out.length, 1);
    const empty = await TB.pageWalk(async () => [], 1000);
    assert.equal(empty.length, 0);
});

test('CSV: escapes commas and newlines in category names', () => {
    const norm = TB.normalize([
        { id: 1, session_date: '2026-07-01', created_at: null, duration: 25, tag: 'A, with comma' },
        { id: 2, session_date: '2026-07-02', created_at: null, duration: 30, tag: 'line1\nline2' }
    ]);
    const lines = TB.buildCsv(norm.sessions).split('\n');
    // the newline inside a quoted field means the physical line count > record count
    assert.ok(TB.buildCsv(norm.sessions).includes('"A, with comma"'));
    assert.ok(TB.buildCsv(norm.sessions).includes('"line1\nline2"'));
    assert.equal(lines[0], 'id,logical_day,stored_session_date,created_at_utc,duration_min,category');
});

test('formatting: consistent units and rounding', () => {
    assert.equal(TB.fmtHM(0), '0m');
    assert.equal(TB.fmtHM(59), '59m');
    assert.equal(TB.fmtHM(60), '1h');
    assert.equal(TB.fmtHM(234), '3h 54m');
    assert.equal(TB.fmtH1(235), '3.9h');
    assert.equal(TB.fmtSigned(30), '+30m');
    assert.equal(TB.fmtSigned(-90), '−1h 30m');
});
