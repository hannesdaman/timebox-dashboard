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

    // Missing created_at: nothing to compare against, the stored day wins.
    var noCreated = { "session_date" => "2026-07-10", "created_at" => null };
    Test.assertEqualMessage(store.effectiveDateKeyForRemoteRow(noCreated), 20260710, "stored day without created_at");

    // PostgREST's UTC form with microseconds; 00:30 local is a cutoff miss.
    var microUtc = { "session_date" => "2026-07-13", "created_at" => "2026-07-12T22:30:00.123456+00:00" };
    Test.assertEqualMessage(store.effectiveDateKeyForRemoteRow(microUtc), 20260712, "microsecond UTC stamp rolls back");

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

(:test)
function testProjectListCap(logger as Test.Logger) as Lang.Boolean {
    var many = [];
    for (var i = 0; i < PROJECT_MAX_COUNT + 5; i++) {
        many.add("Project " + i);
    }
    var capped = normalizeProjectList(many);
    Test.assertEqualMessage(capped.size(), PROJECT_MAX_COUNT, "stored list capped");
    Test.assertEqualMessage(capped[0], "Project 0", "order kept");

    var dupes = normalizeProjectList(["coding", "Coding", " CODING ", "Book"]);
    Test.assertEqualMessage(dupes.size(), 2, "case and space dupes merged");

    var saved = Storage.getValue("projects");
    Storage.deleteValue("projects");

    for (var i = 0; i < PROJECT_MAX_COUNT; i++) {
        applyProjectNameChange("Project " + i, :add_project, -1, null);
    }
    Test.assertEqualMessage(getProjects().size(), PROJECT_MAX_COUNT, "adds up to the cap");
    applyProjectNameChange("One too many", :add_project, -1, null);
    Test.assertEqualMessage(getProjects().size(), PROJECT_MAX_COUNT, "add past cap rejected");
    Test.assertMessage(!projectArrayContains(getProjects(), "One too many"), "rejected name not stored");

    if (saved != null) {
        Storage.setValue("projects", saved);
    } else {
        Storage.deleteValue("projects");
    }
    return true;
}

(:test)
function testReconcileStripsOnlyWindow(logger as Test.Logger) as Lang.Boolean {
    var touched = ["mins", "boxes", "known_tags", "mins_Probe", "boxes_Probe",
                   "mins_Fresh", "boxes_Fresh", "session_ledger", "ledger_hydrated",
                   "pending_sessions"];
    var saved = {};
    for (var i = 0; i < touched.size(); i++) {
        saved.put(touched[i], Storage.getValue(touched[i]));
    }

    var store = new SessionStore();
    var now = Toybox.Time.now().value();
    var oldKey = store.dayKeyForEpoch(now - 90 * 86400);
    var windowKey = store.dayKeyForEpoch(now - 5 * 86400);
    var todayKey = store.todayKey();
    var aheadKey = store.dayKeyForEpoch(now + 2 * 86400);
    // Past the time-based range; a service-role insert could date a row here.
    var farKey = store.dayKeyForEpoch(now + 10 * 86400);
    var farDate = "" + (farKey / 10000) + "-" + ((farKey / 100) % 100).format("%02d") + "-" + (farKey % 100).format("%02d");
    var farRow = { "id" => 1, "session_date" => farDate, "created_at" => farDate + "T12:00:00+00:00", "duration" => 20, "tag" => "Probe" };

    Storage.setValue("mins", { oldKey => 40, windowKey => 25, todayKey => 50, aheadKey => 10, farKey => 99 });
    Storage.setValue("boxes", { oldKey => 2, windowKey => 1, todayKey => 2, aheadKey => 1 });
    Storage.setValue("mins_Probe", { oldKey => 40, windowKey => 25, todayKey => 50 });
    Storage.setValue("boxes_Probe", { oldKey => 2, windowKey => 1, todayKey => 2 });
    Storage.setValue("known_tags", ["Probe"]);
    Storage.deleteValue("pending_sessions");
    Storage.deleteValue("mins_Fresh");
    Storage.deleteValue("boxes_Fresh");
    // Still-unsynced sessions today: the window is rebuilt from rows + pending.
    store.queuePendingSession("t-1", 30, todayKey, "Probe", now);
    store.queuePendingSession("t-2", 15, todayKey, "Fresh", now);

    store.reconcileRecentWithRemote([farRow]);

    var mins = Storage.getValue("mins");
    var tagMins = Storage.getValue("mins_Probe");
    Test.assertEqualMessage(mins[oldKey], 40, "history before window kept");
    Test.assertEqualMessage(tagMins[oldKey], 40, "project history before window kept");
    Test.assertMessage(!mins.hasKey(windowKey), "window day cleared");
    Test.assertMessage(!tagMins.hasKey(windowKey), "project window day cleared");
    Test.assertMessage(!mins.hasKey(aheadKey), "near-future day cleared");
    Test.assertEqualMessage(mins[farKey], 20, "far-future row counted once, not stacked");
    Test.assertEqualMessage(mins[todayKey], 45, "today rebuilt from pending");
    Test.assertEqualMessage(tagMins[todayKey], 30, "project today rebuilt from pending");
    Test.assertEqualMessage(Storage.getValue("mins_Fresh")[todayKey], 15, "new project aggregated");
    Test.assertEqualMessage(Storage.getValue("boxes")[todayKey], 2, "today boxes rebuilt");
    var known = Storage.getValue("known_tags");
    Test.assertEqualMessage(known.size(), 2, "known tags deduped");
    Test.assertEqualMessage(known[1], "Fresh", "new project registered once");

    for (var i = 0; i < touched.size(); i++) {
        var value = saved[touched[i]];
        if (value != null) {
            Storage.setValue(touched[i], value);
        } else {
            Storage.deleteValue(touched[i]);
        }
    }
    return true;
}
