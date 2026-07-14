import Toybox.Lang;
import Toybox.Test;
import Toybox.Application.Storage;

// Run with: monkeyc --unit-test ... && monkeydo <prg> <device> -t

(:test)
function testIsoUtcTimestamp(logger as Test.Logger) as Lang.Boolean {
    Test.assertEqualMessage(isoUtcTimestamp(0), "1970-01-01T00:00:00Z", "epoch 0");
    Test.assertEqualMessage(isoUtcTimestamp(86399), "1970-01-01T23:59:59Z", "day end");
    Test.assertEqualMessage(isoUtcTimestamp(86400), "1970-01-02T00:00:00Z", "day start");
    return true;
}

(:test)
function testDayKeyInvariants(logger as Test.Logger) as Lang.Boolean {
    var store = new SessionStore();
    var epoch = 1767225600; // 2026-01-01T00:00:00Z

    var key = store.dayKeyForEpoch(epoch);
    var year = key / 10000;
    var month = (key % 10000) / 100;
    var day = key % 100;
    Test.assertMessage(year >= 2025 && year <= 2026, "plausible year");
    Test.assertMessage(month >= 1 && month <= 12, "plausible month");
    Test.assertMessage(day >= 1 && day <= 31, "plausible day");

    // one day later must be a different, larger key
    var nextKey = store.dayKeyForEpoch(epoch + 86400);
    Test.assertMessage(nextKey > key, "next day sorts after");

    // now matches todayKey (same rollover shift)
    Test.assertEqualMessage(store.dayKeyForEpoch(Toybox.Time.now().value()), store.todayKey(), "today parity");
    return true;
}

(:test)
function testPresetNormalization(logger as Test.Logger) as Lang.Boolean {
    var normalized = normalizeTimerPresets([90, 25, 25, 999, 50, 4]);
    Test.assertEqualMessage(normalized.size(), 3, "drops dupes and out-of-range");
    Test.assertEqualMessage(normalized[0], 25, "sorted first");
    Test.assertEqualMessage(normalized[1], 50, "sorted middle");
    Test.assertEqualMessage(normalized[2], 90, "sorted last");

    Test.assertEqualMessage(normalizeTimerPresets(null).size(), 0, "null tolerated");
    Test.assertEqualMessage(normalizeTimerPresets("junk").size(), 0, "junk tolerated");
    return true;
}

(:test)
function testPresetAddRemove(logger as Test.Logger) as Lang.Boolean {
    var saved = Storage.getValue("timer_presets");

    Storage.deleteValue("timer_presets");
    var defaults = getTimerPresets();
    Test.assertEqualMessage(defaults.size(), 3, "defaults present");
    Test.assertEqualMessage(defaults[0], 25, "default 25");

    Test.assertMessage(addTimerPreset(45), "add 45 ok");
    Test.assertMessage(!addTimerPreset(45), "dup rejected");
    Test.assertMessage(!addTimerPreset(2), "below range rejected");
    Test.assertEqualMessage(getTimerPresets().size(), 4, "four presets now");

    Test.assertMessage(removeTimerPresetAt(1), "remove ok");
    Test.assertEqualMessage(getTimerPresets().size(), 3, "back to three");

    Storage.deleteValue("timer_presets");
    var single = normalizeTimerPresets([30]);
    Storage.setValue("timer_presets", single);
    Test.assertMessage(!removeTimerPresetAt(0), "cannot remove last");

    if (saved != null) {
        Storage.setValue("timer_presets", saved);
    } else {
        Storage.deleteValue("timer_presets");
    }
    return true;
}

(:test)
function testRemoteRowDayAttribution(logger as Test.Logger) as Lang.Boolean {
    var store = new SessionStore();

    // Backdated manual dashboard entry: stored day differs from created_at's
    // calendar day, so the stored day must win (was re-dated before the fix).
    var backdated = {
        "session_date" => "2026-07-10",
        "created_at" => "2026-07-12T20:00:00+00:00"
    };
    Test.assertEqualMessage(store.effectiveDateKeyForRemoteRow(backdated), 20260710, "backdated keeps stored day");

    // Legacy cutoff-miss row (local CEST): stored date equals created_at's
    // raw calendar day while 02:30 rollover says the previous day.
    var legacyMiss = {
        "session_date" => "2026-07-13",
        "created_at" => "2026-07-13T00:30:00+02:00"
    };
    Test.assertEqualMessage(store.effectiveDateKeyForRemoteRow(legacyMiss), 20260712, "legacy cutoff miss rolls back");

    // No stored date: fall back to rollover-adjusted created_at.
    var noStored = { "session_date" => null, "created_at" => "2026-07-13T12:00:00+02:00" };
    Test.assertEqualMessage(store.effectiveDateKeyForRemoteRow(noStored), 20260713, "created_at fallback");

    return true;
}

(:test)
function testVibeLevelContract(logger as Test.Logger) as Lang.Boolean {
    Test.assertEqualMessage(vibeChunkCount(VIBE_LEVEL_MODEST), 1, "modest 1x");
    Test.assertEqualMessage(vibeChunkCount(VIBE_LEVEL_NORMAL), 2, "normal 2x");
    Test.assertEqualMessage(vibeChunkCount(VIBE_LEVEL_INTENSE), 4, "intense 4x");
    Test.assertEqualMessage(vibeChunkCount(VIBE_LEVEL_EXTREME), 8, "extreme 8x");
    Test.assertEqualMessage(vibeChunkDurationMs(), 1650, "chunk matches original pattern");

    var saved = Storage.getValue("vibe_level");
    Storage.deleteValue("vibe_level");
    Test.assertEqualMessage(getVibeLevel(), VIBE_LEVEL_MODEST, "default modest");
    setVibeLevel(VIBE_LEVEL_EXTREME);
    Test.assertEqualMessage(getVibeLevel(), VIBE_LEVEL_EXTREME, "persists");
    setVibeLevel(99);
    Test.assertEqualMessage(getVibeLevel(), VIBE_LEVEL_EXTREME, "invalid ignored");

    if (saved != null) {
        Storage.setValue("vibe_level", saved);
    } else {
        Storage.deleteValue("vibe_level");
    }
    return true;
}
