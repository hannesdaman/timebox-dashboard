import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;

class SessionStore {

    function initialize() {}

    function todayKey() {
        var info = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        return info.year * 10000 + info.month * 100 + info.day;
    }

    function syncCutoffKey() {
        var cutoff = new Time.Moment(Time.now().value() - 400 * 86400);
        var info = Gregorian.info(cutoff, Time.FORMAT_SHORT);
        return info.year * 10000 + info.month * 100 + info.day;
    }

    function logSession(durationMinutes, tag) {
        var key = todayKey();
        var localId = appendSessionToLedger(durationMinutes, key, tag);
        applySessionToAggregates(key, durationMinutes, tag);
        queuePendingSession(localId, durationMinutes, key, tag);

        // Save last session for undo
        Storage.setValue("last_dur", durationMinutes);
        Storage.setValue("last_day", key);
        Storage.setValue("last_tag", tag);
        Storage.setValue("last_local_id", localId);
        Storage.deleteValue("last_remote_id");

        pruneOld(Storage.getValue("mins"), "mins");
        pruneOld(Storage.getValue("boxes"), "boxes");

        var tagMinsKey = "mins_" + tag;
        var tagBoxesKey = "boxes_" + tag;
        pruneOld(Storage.getValue(tagMinsKey), tagMinsKey);
        pruneOld(Storage.getValue(tagBoxesKey), tagBoxesKey);
    }

    function undoLast() {
        var info = undoLastRecord();
        if (info == null) { return 0; }
        return info["duration"];
    }

    function undoLastRecord() {
        var dur = Storage.getValue("last_dur");
        var dayKey = Storage.getValue("last_day");
        var tag = Storage.getValue("last_tag");
        var localId = Storage.getValue("last_local_id");
        var remoteId = Storage.getValue("last_remote_id");
        if (dur == null || dayKey == null) { return null; }

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

        if (localId != null) {
            removePendingSessionByLocalId(localId);
            removeSessionFromLedgerByLocalId(localId);
        }

        var undone = {
            "duration" => dur,
            "date_key" => dayKey,
            "tag" => tag,
            "local_id" => localId,
            "remote_id" => remoteId
        };
        clearUndoState();
        return undone;
    }

    function getLastSessionDuration() {
        var dur = Storage.getValue("last_dur");
        if (dur == null) { return 0; }
        return dur;
    }

    function clearToday() {
        var key = todayKey();
        clearDayFromAggregates(key);
        removePendingSessionsForDay(key);
        removeSessionsFromLedgerForDay(key);

        var lastDay = Storage.getValue("last_day");
        if (lastDay != null && lastDay == key) {
            clearUndoState();
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

        var pending = getPendingSessions();
        var pendingChanged = false;
        for (var j = 0; j < pending.size(); j++) {
            if (pending[j]["tag"] != null && pending[j]["tag"].equals(oldTag)) {
                pending[j]["tag"] = newTag;
                pendingChanged = true;
            }
        }
        if (pendingChanged) {
            Storage.setValue("pending_sessions", pending);
        }

        var sessions = getSessionLedger();
        var ledgerChanged = false;
        for (var k = 0; k < sessions.size(); k++) {
            if (sessions[k]["tag"] != null && sessions[k]["tag"].equals(oldTag)) {
                sessions[k]["tag"] = newTag;
                ledgerChanged = true;
            }
        }
        if (ledgerChanged) {
            saveSessionLedger(sessions);
        }
    }

    function getPendingSessions() as Lang.Array {
        var pending = Storage.getValue("pending_sessions");
        if (pending == null || !(pending instanceof Lang.Array)) {
            return [];
        }
        return pending;
    }

    function peekPendingSession() {
        var pending = getPendingSessions();
        if (pending.size() == 0) { return null; }
        return pending[0];
    }

    function queuePendingSession(localId, durationMinutes, dayKey, tag) as Void {
        var pending = getPendingSessions();
        pending.add({
            "local_id" => localId,
            "date_key" => dayKey,
            "duration" => durationMinutes,
            "tag" => tag
        });
        Storage.setValue("pending_sessions", pending);
    }

    function removePendingSessionByLocalId(localId) as Void {
        if (localId == null) { return; }

        var pending = getPendingSessions();
        if (pending.size() == 0) { return; }

        var updated = [];
        var changed = false;
        for (var i = 0; i < pending.size(); i++) {
            if (pending[i]["local_id"] != null && pending[i]["local_id"].equals(localId)) {
                changed = true;
            } else {
                updated.add(pending[i]);
            }
        }

        if (changed) {
            Storage.setValue("pending_sessions", updated);
        }
    }

    function setLastRemoteIdForLocalId(localId, remoteId) as Void {
        var lastLocalId = Storage.getValue("last_local_id");
        if (lastLocalId != null && lastLocalId.equals(localId)) {
            Storage.setValue("last_remote_id", remoteId);
        }

        var sessions = getSessionLedger();
        var changed = false;
        for (var i = 0; i < sessions.size(); i++) {
            if (sessions[i]["local_id"] != null && sessions[i]["local_id"].equals(localId)) {
                sessions[i]["remote_id"] = remoteId;
                changed = true;
                break;
            }
        }
        if (changed) {
            saveSessionLedger(sessions);
        }
    }

    function reconcileRecentWithRemote(rows) as Void {
        var cutoffKey = syncCutoffKey();
        var merged = [];

        if (rows != null && rows instanceof Lang.Array) {
            for (var i = 0; i < rows.size(); i++) {
                var session = remoteRowToLedgerSession(rows[i], cutoffKey);
                if (session != null) {
                    merged.add(session);
                }
            }
        }

        var pending = getPendingSessions();
        for (var j = 0; j < pending.size(); j++) {
            var pendingDay = pending[j]["date_key"];
            if (pendingDay != null && pendingDay >= cutoffKey) {
                merged.add({
                    "local_id" => pending[j]["local_id"],
                    "remote_id" => null,
                    "date_key" => pendingDay,
                    "duration" => pending[j]["duration"],
                    "tag" => pending[j]["tag"]
                });
            }
        }

        saveSessionLedger(merged);
        Storage.setValue("ledger_hydrated", true);
        rebuildAggregatesFromLedger(merged);
    }

    function getSessionLedger() as Lang.Array {
        var sessions = Storage.getValue("session_ledger");
        if (sessions == null || !(sessions instanceof Lang.Array)) {
            return [];
        }
        return sessions;
    }

    function saveSessionLedger(sessions) as Void {
        var trimmed = [];
        var cutoffKey = syncCutoffKey();

        if (sessions instanceof Lang.Array) {
            for (var i = 0; i < sessions.size(); i++) {
                var session = normalizeLedgerSession(sessions[i], cutoffKey);
                if (session != null) {
                    trimmed.add(session);
                }
            }
        }

        Storage.setValue("session_ledger", trimmed);
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
        if (data == null) { return; }

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

    private function applySessionToAggregates(dayKey, durationMinutes, tag) as Void {
        var mins = Storage.getValue("mins");
        if (mins == null) { mins = {}; }
        var existing = 0;
        if (mins.hasKey(dayKey)) { existing = mins[dayKey]; }
        mins.put(dayKey, existing + durationMinutes);
        Storage.setValue("mins", mins);

        var boxes = Storage.getValue("boxes");
        if (boxes == null) { boxes = {}; }
        var existingB = 0;
        if (boxes.hasKey(dayKey)) { existingB = boxes[dayKey]; }
        boxes.put(dayKey, existingB + 1);
        Storage.setValue("boxes", boxes);

        var tagMinsKey = "mins_" + tag;
        var tagMins = Storage.getValue(tagMinsKey);
        if (tagMins == null) { tagMins = {}; }
        var existingT = 0;
        if (tagMins.hasKey(dayKey)) { existingT = tagMins[dayKey]; }
        tagMins.put(dayKey, existingT + durationMinutes);
        Storage.setValue(tagMinsKey, tagMins);

        var tagBoxesKey = "boxes_" + tag;
        var tagBoxes = Storage.getValue(tagBoxesKey);
        if (tagBoxes == null) { tagBoxes = {}; }
        var existingTB = 0;
        if (tagBoxes.hasKey(dayKey)) { existingTB = tagBoxes[dayKey]; }
        tagBoxes.put(dayKey, existingTB + 1);
        Storage.setValue(tagBoxesKey, tagBoxes);

        ensureKnownTag(tag);
    }

    private function clearDayFromAggregates(dayKey) as Void {
        var mins = Storage.getValue("mins");
        if (mins != null && mins.hasKey(dayKey)) {
            mins.remove(dayKey);
            Storage.setValue("mins", mins);
        }

        var boxes = Storage.getValue("boxes");
        if (boxes != null && boxes.hasKey(dayKey)) {
            boxes.remove(dayKey);
            Storage.setValue("boxes", boxes);
        }

        var knownTags = Storage.getValue("known_tags");
        if (knownTags == null) { return; }

        for (var i = 0; i < knownTags.size(); i++) {
            var tagMinsKey = "mins_" + knownTags[i];
            var tagMins = Storage.getValue(tagMinsKey);
            if (tagMins != null && tagMins.hasKey(dayKey)) {
                tagMins.remove(dayKey);
                Storage.setValue(tagMinsKey, tagMins);
            }

            var tagBoxesKey = "boxes_" + knownTags[i];
            var tagBoxes = Storage.getValue(tagBoxesKey);
            if (tagBoxes != null && tagBoxes.hasKey(dayKey)) {
                tagBoxes.remove(dayKey);
                Storage.setValue(tagBoxesKey, tagBoxes);
            }
        }
    }

    private function applyPendingSessionsForDay(dayKey) as Void {
        var pending = getPendingSessions();
        for (var i = 0; i < pending.size(); i++) {
            if (pending[i]["date_key"] == dayKey) {
                applySessionToAggregates(dayKey, pending[i]["duration"], pending[i]["tag"]);
            }
        }
    }

    private function removePendingSessionsForDay(dayKey) as Void {
        var pending = getPendingSessions();
        if (pending.size() == 0) { return; }

        var updated = [];
        var changed = false;
        for (var i = 0; i < pending.size(); i++) {
            if (pending[i]["date_key"] == dayKey) {
                changed = true;
            } else {
                updated.add(pending[i]);
            }
        }

        if (changed) {
            Storage.setValue("pending_sessions", updated);
        }
    }

    private function ensureKnownTag(tag) as Void {
        var knownTags = Storage.getValue("known_tags");
        if (knownTags == null) { knownTags = []; }
        if (!arrayContains(knownTags, tag)) {
            knownTags.add(tag);
            Storage.setValue("known_tags", knownTags);
        }
    }

    private function appendSessionToLedger(durationMinutes, dayKey, tag) as Lang.String {
        var localId = nextLocalSessionId();
        var sessions = getSessionLedger();
        sessions.add({
            "local_id" => localId,
            "remote_id" => null,
            "date_key" => dayKey,
            "duration" => durationMinutes,
            "tag" => tag
        });
        saveSessionLedger(sessions);
        return localId;
    }

    private function removeSessionFromLedgerByLocalId(localId) as Void {
        if (localId == null) { return; }

        var sessions = getSessionLedger();
        if (sessions.size() == 0) { return; }

        var updated = [];
        var changed = false;
        for (var i = 0; i < sessions.size(); i++) {
            if (sessions[i]["local_id"] != null && sessions[i]["local_id"].equals(localId)) {
                changed = true;
            } else {
                updated.add(sessions[i]);
            }
        }

        if (changed) {
            saveSessionLedger(updated);
        }
    }

    private function removeSessionsFromLedgerForDay(dayKey) as Void {
        var sessions = getSessionLedger();
        if (sessions.size() == 0) { return; }

        var updated = [];
        var changed = false;
        for (var i = 0; i < sessions.size(); i++) {
            if (sessions[i]["date_key"] == dayKey) {
                changed = true;
            } else {
                updated.add(sessions[i]);
            }
        }

        if (changed) {
            saveSessionLedger(updated);
        }
    }

    private function rebuildAggregatesFromLedger(sessions) as Void {
        clearAllAggregates();

        for (var i = 0; i < sessions.size(); i++) {
            applySessionToAggregates(sessions[i]["date_key"], sessions[i]["duration"], sessions[i]["tag"]);
        }
    }

    private function clearAllAggregates() as Void {
        Storage.setValue("mins", {});
        Storage.setValue("boxes", {});

        var knownTags = Storage.getValue("known_tags");
        if (knownTags == null) { knownTags = []; }

        for (var i = 0; i < knownTags.size(); i++) {
            Storage.setValue("mins_" + knownTags[i], {});
            Storage.setValue("boxes_" + knownTags[i], {});
        }

        Storage.setValue("known_tags", []);
    }

    private function normalizeLedgerSession(session, cutoffKey) {
        if (!(session instanceof Lang.Dictionary)) { return null; }

        var dayKey = session["date_key"];
        var duration = session["duration"];
        var tag = session["tag"];

        if (!((dayKey instanceof Lang.Number) || (dayKey instanceof Lang.Long))) { return null; }
        if (!((duration instanceof Lang.Number) || (duration instanceof Lang.Long))) { return null; }
        if (!(tag instanceof Lang.String)) { return null; }

        var normalizedDay = dayKey.toNumber();
        if (normalizedDay < cutoffKey) { return null; }

        return {
            "local_id" => session["local_id"],
            "remote_id" => session["remote_id"],
            "date_key" => normalizedDay,
            "duration" => duration.toNumber(),
            "tag" => tag
        };
    }

    private function remoteRowToLedgerSession(row, cutoffKey) {
        if (!(row instanceof Lang.Dictionary)) { return null; }

        var remoteId = row["id"];
        var dayKey = parseDateString(row["session_date"]);
        var duration = row["duration"];
        var tag = row["tag"];

        if (dayKey < cutoffKey) { return null; }
        if (!((remoteId instanceof Lang.Number) || (remoteId instanceof Lang.Long))) { return null; }
        if (!((duration instanceof Lang.Number) || (duration instanceof Lang.Long))) { return null; }
        if (!(tag instanceof Lang.String)) { tag = "Studying"; }

        return {
            "local_id" => null,
            "remote_id" => remoteId,
            "date_key" => dayKey,
            "duration" => duration.toNumber(),
            "tag" => tag
        };
    }

    private function nextLocalSessionId() as Lang.String {
        var counter = Storage.getValue("session_seq");
        if (!(counter instanceof Lang.Number) && !(counter instanceof Lang.Long)) {
            counter = 0;
        }
        counter += 1;
        Storage.setValue("session_seq", counter);
        return "" + Time.now().value() + "-" + counter;
    }

    private function parseDateString(value) {
        if (!(value instanceof Lang.String) || value.length() < 10) { return 0; }
        var year = value.substring(0, 4).toNumber();
        var month = value.substring(5, 7).toNumber();
        var day = value.substring(8, 10).toNumber();
        return year * 10000 + month * 100 + day;
    }

    private function clearUndoState() as Void {
        Storage.deleteValue("last_dur");
        Storage.deleteValue("last_day");
        Storage.deleteValue("last_tag");
        Storage.deleteValue("last_local_id");
        Storage.deleteValue("last_remote_id");
    }
}
