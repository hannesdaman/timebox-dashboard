import Toybox.Application.Storage;
import Toybox.Lang;

// User-editable timer presets (minutes) shown on the main menu.
// Managed under Settings > Timers; kept sorted, unique, and bounded.

const PRESET_MIN_MINUTES = 5;
const PRESET_MAX_MINUTES = 120;
const PRESET_MAX_COUNT = 6;

function getTimerPresets() as Lang.Array {
    var presets = normalizeTimerPresets(Storage.getValue("timer_presets"));
    if (presets.size() == 0) {
        return [25, 50, 90];
    }
    return presets;
}

function addTimerPreset(minutes) as Lang.Boolean {
    if (!(minutes instanceof Lang.Number)) { return false; }
    if (minutes < PRESET_MIN_MINUTES || minutes > PRESET_MAX_MINUTES) { return false; }

    var presets = getTimerPresets();
    if (presets.size() >= PRESET_MAX_COUNT) { return false; }
    if (timerPresetIndexOf(presets, minutes) != -1) { return false; }

    presets.add(minutes);
    Storage.setValue("timer_presets", normalizeTimerPresets(presets));
    return true;
}

function removeTimerPresetAt(index) as Lang.Boolean {
    var presets = getTimerPresets();
    if (presets.size() <= 1) { return false; }
    if (!(index instanceof Lang.Number) || index < 0 || index >= presets.size()) { return false; }

    var updated = [];
    for (var i = 0; i < presets.size(); i++) {
        if (i != index) {
            updated.add(presets[i]);
        }
    }
    Storage.setValue("timer_presets", normalizeTimerPresets(updated));
    return true;
}

function timerPresetIndexOf(presets, minutes) as Lang.Number {
    for (var i = 0; i < presets.size(); i++) {
        if (presets[i] == minutes) { return i; }
    }
    return -1;
}

function normalizeTimerPresets(presets) as Lang.Array {
    var valid = [];
    if (presets instanceof Lang.Array) {
        for (var i = 0; i < presets.size(); i++) {
            var minutes = presets[i];
            if (!(minutes instanceof Lang.Number)) { continue; }
            if (minutes < PRESET_MIN_MINUTES || minutes > PRESET_MAX_MINUTES) { continue; }
            if (timerPresetIndexOf(valid, minutes) != -1) { continue; }
            valid.add(minutes);
            if (valid.size() >= PRESET_MAX_COUNT) { break; }
        }
    }

    // selection sort; the list holds at most 6 entries
    for (var i = 0; i < valid.size(); i++) {
        var smallest = i;
        for (var j = i + 1; j < valid.size(); j++) {
            if (valid[j] < valid[smallest]) { smallest = j; }
        }
        if (smallest != i) {
            var tmp = valid[i];
            valid[i] = valid[smallest];
            valid[smallest] = tmp;
        }
    }

    return valid;
}
