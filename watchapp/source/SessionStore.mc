import Toybox.Application.Storage;
import Toybox.Time;
import Toybox.Time.Gregorian;

class SessionStore {

    function initialize() {}

    function todayKey() {
        var info = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        return info.year * 10000 + info.month * 100 + info.day;
    }

    function logSession(durationMinutes, tag) {
        var key = todayKey();

        var mins = Storage.getValue("mins");
        if (mins == null) { mins = {}; }
        var existing = 0;
        if (mins.hasKey(key)) { existing = mins[key]; }
        mins.put(key, existing + durationMinutes);
        Storage.setValue("mins", mins);

        var boxes = Storage.getValue("boxes");
        if (boxes == null) { boxes = {}; }
        var existingB = 0;
        if (boxes.hasKey(key)) { existingB = boxes[key]; }
        boxes.put(key, existingB + 1);
        Storage.setValue("boxes", boxes);

        // Per-tag storage
        var tagMinsKey = "mins_" + tag;
        var tagMins = Storage.getValue(tagMinsKey);
        if (tagMins == null) { tagMins = {}; }
        var existingT = 0;
        if (tagMins.hasKey(key)) { existingT = tagMins[key]; }
        tagMins.put(key, existingT + durationMinutes);
        Storage.setValue(tagMinsKey, tagMins);

        var tagBoxesKey = "boxes_" + tag;
        var tagBoxes = Storage.getValue(tagBoxesKey);
        if (tagBoxes == null) { tagBoxes = {}; }
        var existingTB = 0;
        if (tagBoxes.hasKey(key)) { existingTB = tagBoxes[key]; }
        tagBoxes.put(key, existingTB + 1);
        Storage.setValue(tagBoxesKey, tagBoxes);

        // Track known tags so clearToday can iterate them
        var knownTags = Storage.getValue("known_tags");
        if (knownTags == null) { knownTags = []; }
        var found = false;
        for (var i = 0; i < knownTags.size(); i++) {
            if (knownTags[i].equals(tag)) { found = true; break; }
        }
        if (!found) {
            knownTags.add(tag);
            Storage.setValue("known_tags", knownTags);
        }

        // Save last session for undo
        Storage.setValue("last_dur", durationMinutes);
        Storage.setValue("last_day", key);
        Storage.setValue("last_tag", tag);

        pruneOld(mins, "mins");
        pruneOld(boxes, "boxes");
        pruneOld(tagMins, tagMinsKey);
        pruneOld(tagBoxes, tagBoxesKey);
    }

    function undoLast() {
        var dur = Storage.getValue("last_dur");
        var dayKey = Storage.getValue("last_day");
        var tag = Storage.getValue("last_tag");
        if (dur == null || dayKey == null) { return 0; }

        var mins = Storage.getValue("mins");
        if (mins != null && mins.hasKey(dayKey)) {
            var val = mins[dayKey] - dur;
            if (val <= 0) { mins.remove(dayKey); } else { mins.put(dayKey, val); }
            Storage.setValue("mins", mins);
        }

        var boxes = Storage.getValue("boxes");
        if (boxes != null && boxes.hasKey(dayKey)) {
            var val2 = boxes[dayKey] - 1;
            if (val2 <= 0) { boxes.remove(dayKey); } else { boxes.put(dayKey, val2); }
            Storage.setValue("boxes", boxes);
        }

        // Undo per-tag storage
        if (tag != null) {
            var tagMinsKey = "mins_" + tag;
            var tagMins = Storage.getValue(tagMinsKey);
            if (tagMins != null && tagMins.hasKey(dayKey)) {
                var val3 = tagMins[dayKey] - dur;
                if (val3 <= 0) { tagMins.remove(dayKey); } else { tagMins.put(dayKey, val3); }
                Storage.setValue(tagMinsKey, tagMins);
            }

            var tagBoxesKey = "boxes_" + tag;
            var tagBoxes = Storage.getValue(tagBoxesKey);
            if (tagBoxes != null && tagBoxes.hasKey(dayKey)) {
                var val4 = tagBoxes[dayKey] - 1;
                if (val4 <= 0) { tagBoxes.remove(dayKey); } else { tagBoxes.put(dayKey, val4); }
                Storage.setValue(tagBoxesKey, tagBoxes);
            }
        }

        // Clear undo so it can't be double-undone
        var undone = dur;
        Storage.deleteValue("last_dur");
        Storage.deleteValue("last_day");
        Storage.deleteValue("last_tag");

        return undone;
    }

    function getLastSessionDuration() {
        var dur = Storage.getValue("last_dur");
        if (dur == null) { return 0; }
        return dur;
    }

    function clearToday() {
        var key = todayKey();

        var mins = Storage.getValue("mins");
        if (mins != null && mins.hasKey(key)) {
            mins.remove(key);
            Storage.setValue("mins", mins);
        }

        var boxes = Storage.getValue("boxes");
        if (boxes != null && boxes.hasKey(key)) {
            boxes.remove(key);
            Storage.setValue("boxes", boxes);
        }

        var knownTags = Storage.getValue("known_tags");
        if (knownTags == null) { return; }

        for (var i = 0; i < knownTags.size(); i++) {
            var tagMinsKey = "mins_" + knownTags[i];
            var tagMins = Storage.getValue(tagMinsKey);
            if (tagMins != null && tagMins.hasKey(key)) {
                tagMins.remove(key);
                Storage.setValue(tagMinsKey, tagMins);
            }

            var tagBoxesKey = "boxes_" + knownTags[i];
            var tagBoxes = Storage.getValue(tagBoxesKey);
            if (tagBoxes != null && tagBoxes.hasKey(key)) {
                tagBoxes.remove(key);
                Storage.setValue(tagBoxesKey, tagBoxes);
            }
        }
    }

    function getTodayMinutes() {
        var mins = Storage.getValue("mins");
        if (mins == null) { return 0; }
        var key = todayKey();
        if (mins.hasKey(key)) { return mins[key]; }
        return 0;
    }

    function getTodayBoxes() {
        var boxes = Storage.getValue("boxes");
        if (boxes == null) { return 0; }
        var key = todayKey();
        if (boxes.hasKey(key)) { return boxes[key]; }
        return 0;
    }

    function getWeekMinutes() { return sumPeriod("mins", :week); }
    function getMonthMinutes() { return sumPeriod("mins", :month); }
    function getYearMinutes() { return sumPeriod("mins", :year); }

    function getTodayMinutesForTag(tag) {
        var mins = Storage.getValue("mins_" + tag);
        if (mins == null) { return 0; }
        var key = todayKey();
        if (mins.hasKey(key)) { return mins[key]; }
        return 0;
    }

    function getTodayBoxesForTag(tag) {
        var boxes = Storage.getValue("boxes_" + tag);
        if (boxes == null) { return 0; }
        var key = todayKey();
        if (boxes.hasKey(key)) { return boxes[key]; }
        return 0;
    }

    function getWeekMinutesForTag(tag) { return sumPeriod("mins_" + tag, :week); }
    function getMonthMinutesForTag(tag) { return sumPeriod("mins_" + tag, :month); }
    function getYearMinutesForTag(tag) { return sumPeriod("mins_" + tag, :year); }

    function renameTag(oldTag, newTag) {
        if (oldTag == null || newTag == null || oldTag.equals(newTag)) { return; }

        mergeTagData("mins_" + oldTag, "mins_" + newTag);
        mergeTagData("boxes_" + oldTag, "boxes_" + newTag);

        var knownTags = Storage.getValue("known_tags");
        if (knownTags == null) { knownTags = []; }

        var updatedTags = [];
        for (var i = 0; i < knownTags.size(); i++) {
            var tag = knownTags[i];
            if (tag.equals(oldTag)) {
                if (!arrayContains(updatedTags, newTag)) {
                    updatedTags.add(newTag);
                }
            } else if (!arrayContains(updatedTags, tag)) {
                updatedTags.add(tag);
            }
        }
        if (!arrayContains(updatedTags, newTag)) {
            updatedTags.add(newTag);
        }
        Storage.setValue("known_tags", updatedTags);

        var lastTag = Storage.getValue("last_tag");
        if (lastTag != null && lastTag.equals(oldTag)) {
            Storage.setValue("last_tag", newTag);
        }

        var timerTag = Storage.getValue("timer_tag");
        if (timerTag != null && timerTag.equals(oldTag)) {
            Storage.setValue("timer_tag", newTag);
        }
    }

    private function sumPeriod(storageKey, period) {
        var data = Storage.getValue(storageKey);
        if (data == null) { return 0; }

        var now = Time.now();
        var info = Gregorian.info(now, Time.FORMAT_SHORT);

        var total = 0;
        var keys = data.keys();

        if (period == :week) {
            var dow = info.day_of_week;
            var daysSinceMonday = (dow + 5) % 7;
            var weekKeys = {};
            for (var i = 0; i <= daysSinceMonday; i++) {
                var d = new Time.Moment(now.value() - i * 86400);
                var di = Gregorian.info(d, Time.FORMAT_SHORT);
                var dk = di.year * 10000 + di.month * 100 + di.day;
                weekKeys.put(dk, true);
            }
            for (var j = 0; j < keys.size(); j++) {
                if (weekKeys.hasKey(keys[j])) {
                    total += data[keys[j]];
                }
            }
        } else if (period == :month) {
            var prefix = info.year * 100 + info.month;
            for (var j = 0; j < keys.size(); j++) {
                var k = keys[j];
                var kPrefix = (k / 100).toNumber();
                if (kPrefix == prefix) { total += data[k]; }
            }
        } else if (period == :year) {
            var yr = info.year;
            for (var j = 0; j < keys.size(); j++) {
                var k = keys[j];
                var kYear = (k / 10000).toNumber();
                if (kYear == yr) { total += data[k]; }
            }
        }

        return total;
    }

    private function pruneOld(data, storageKey) {
        var now = Time.now();
        var cutoff = new Time.Moment(now.value() - 400 * 86400);
        var cutInfo = Gregorian.info(cutoff, Time.FORMAT_SHORT);
        var cutKey = cutInfo.year * 10000 + cutInfo.month * 100 + cutInfo.day;

        var keys = data.keys();
        var changed = false;
        for (var i = 0; i < keys.size(); i++) {
            if (keys[i] < cutKey) {
                data.remove(keys[i]);
                changed = true;
            }
        }
        if (changed) {
            Storage.setValue(storageKey, data);
        }
    }

    private function mergeTagData(oldKey, newKey) {
        var oldData = Storage.getValue(oldKey);
        if (oldData == null) { return; }

        var newData = Storage.getValue(newKey);
        if (newData == null) { newData = {}; }

        var keys = oldData.keys();
        for (var i = 0; i < keys.size(); i++) {
            var key = keys[i];
            var current = 0;
            if (newData.hasKey(key)) { current = newData[key]; }
            newData.put(key, current + oldData[key]);
        }

        Storage.setValue(newKey, newData);
        Storage.deleteValue(oldKey);
    }

    private function arrayContains(values, target) {
        for (var i = 0; i < values.size(); i++) {
            if (values[i].equals(target)) { return true; }
        }
        return false;
    }
}
