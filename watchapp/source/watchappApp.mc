import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Communications;
import Toybox.Timer;
import Toybox.Application.Storage;
import Toybox.PersistedContent;

class watchappApp extends Application.AppBase {

    var SUPABASE_URL = "https://gujufwafdradmmehtafx.supabase.co/rest/v1/sessions";
    var SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd1anVmd2FmZHJhZG1tZWh0YWZ4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzUxMjE5NDYsImV4cCI6MjA5MDY5Nzk0Nn0.cd9vSriuByxKNaWQhLNWfaiBgEjabrn_9zN6LNlPvrM";
    var _syncingLocalId = null;
    var _refreshingStats = false;
    var _refreshStatsQueued = false;
    var _syncRetryTimer = null;
    var _syncRetryDelays = null;
    var _syncRetryIndex = 0;
    var _timerActive = false;
    var _deleteAfterSyncLocalIds = null;

    function initialize() {
        AppBase.initialize();
        _syncRetryTimer = new Timer.Timer();
        _syncRetryDelays = [30000, 60000, 120000, 300000, 600000];
        _deleteAfterSyncLocalIds = [];
    }

    function onStart(state as Dictionary?) as Void {
        syncPendingSessions();
    }

    function onStop(state as Dictionary?) as Void {
        if (_syncRetryTimer != null) {
            _syncRetryTimer.stop();
        }
    }

    function onSettingsChanged() as Void {
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        if (isFirstLaunch()) {
            return [ new WelcomeView(), new WelcomeDelegate() ];
        }

        if (TimerView.hasSavedState()) {
            if (TimerView.hasRestorableState()) {
                var remaining = Storage.getValue("timer_remaining");
                var total = Storage.getValue("timer_total");
                var label = Storage.getValue("timer_label");
                var wasRunning = Storage.getValue("timer_was_running");
                var tag = Storage.getValue("timer_tag");

                if (wasRunning == null) { wasRunning = false; }
                if (tag == null) { tag = "Studying"; }

                try {
                    var timerView = new TimerView(total, label, tag);
                    timerView.markRootRestoredLaunch();
                    timerView.restoreState(remaining, total, label, wasRunning);
                    return [ timerView, new TimerDelegate(timerView) ];
                } catch(e instanceof Lang.Exception) {
                    TimerView.clearSavedState();
                }
            } else {
                TimerView.clearSavedState();
            }
        }

        return [ new Rez.Menus.MainMenu(), new watchappMenuDelegate() ];
    }

    function syncSession(durationMinutes, dateKey, tag) {
        syncPendingSessions();
    }

    function syncPendingSessions() as Void {
        cancelSyncRetry();
        if (_syncingLocalId != null) { return; }

        var store = new SessionStore();
        var nextPending = store.peekPendingSession();
        if (nextPending == null) {
            resetSyncRetryBackoff();
            return;
        }

        _syncingLocalId = nextPending["local_id"];

        var payload = {
            "duration" => nextPending["duration"],
            "session_date" => formatDateKey(nextPending["date_key"]),
            "tag" => nextPending["tag"]
        };

        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_POST,
            :headers => {
                "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON,
                "apikey" => SUPABASE_KEY,
                "Authorization" => "Bearer " + SUPABASE_KEY,
                "Prefer" => "return=representation"
            },
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };

        Communications.makeWebRequest(SUPABASE_URL, payload, options, method(:onPendingSyncResponse));
    }

    function deleteSessionsForDate(dateKey) {
        var dateStr = formatDateKey(dateKey);
        var url = SUPABASE_URL + "?session_date=eq." + dateStr;

        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_DELETE,
            :headers => {
                "apikey" => SUPABASE_KEY,
                "Authorization" => "Bearer " + SUPABASE_KEY,
                "Prefer" => "return=minimal"
            },
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };

        Communications.makeWebRequest(url, null, options, method(:onDeleteResponse));
    }

    function deleteSessionById(remoteId) as Void {
        if (!(remoteId instanceof Lang.Number) && !(remoteId instanceof Lang.Long)) { return; }

        var url = SUPABASE_URL + "?id=eq." + remoteId;
        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_DELETE,
            :headers => {
                "apikey" => SUPABASE_KEY,
                "Authorization" => "Bearer " + SUPABASE_KEY,
                "Prefer" => "return=minimal"
            },
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };

        Communications.makeWebRequest(url, null, options, method(:onDeleteByIdResponse));
    }

    function deleteSessionForUndo(localId, remoteId) as Void {
        if ((remoteId instanceof Lang.Number) || (remoteId instanceof Lang.Long)) {
            deleteSessionById(remoteId);
        } else {
            queueDeleteForInFlightLocalId(localId);
        }
    }

    function queueRemovedSessionsForInFlightDelete(sessions) as Void {
        if (!(sessions instanceof Lang.Array)) { return; }

        for (var i = 0; i < sessions.size(); i++) {
            if (sessions[i] instanceof Lang.Dictionary) {
                queueDeleteForInFlightLocalId(sessions[i]["local_id"]);
            }
        }
    }

    function setTimerActive(active as Lang.Boolean) as Void {
        _timerActive = active;
        if (!_timerActive && _refreshStatsQueued) {
            refreshStatsFromCloud();
        }
    }

    function isTimerActive() as Lang.Boolean {
        return _timerActive || TimerView.hasRestorableState();
    }

    function refreshStatsFromCloud() as Void {
        if (isTimerActive()) {
            _refreshStatsQueued = true;
            return;
        }

        if (_refreshingStats) {
            _refreshStatsQueued = true;
            return;
        }

        var store = new SessionStore();
        if (store.peekPendingSession() != null) {
            _refreshStatsQueued = true;
            if (_syncingLocalId == null) {
                syncPendingSessions();
            }
            return;
        }

        _refreshStatsQueued = false;
        _refreshingStats = true;

        var cutoff = formatDateKey(store.statsRefreshCutoffKey());
        var url = SUPABASE_URL + "?select=id,session_date,created_at,duration,tag&session_date=gte." + cutoff + "&order=session_date.desc,id.desc&limit=200";
        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_GET,
            :headers => {
                "apikey" => SUPABASE_KEY,
                "Authorization" => "Bearer " + SUPABASE_KEY
            },
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };

        Communications.makeWebRequest(url, null, options, method(:onStatsRefreshResponse));
    }

    function onPendingSyncResponse(responseCode as Lang.Number, data as Lang.Dictionary or Lang.String or PersistedContent.Iterator or Null) as Void {
        var completedLocalId = _syncingLocalId;
        _syncingLocalId = null;

        if (responseCode == 201 || responseCode == 200) {
            resetSyncRetryBackoff();
            var store = new SessionStore();
            var rows = responseRows(data);
            var remoteId = null;
            if (rows.size() > 0) {
                var firstRow = rows[0];
                if (firstRow instanceof Lang.Dictionary && firstRow.hasKey("id")) {
                    remoteId = firstRow["id"];
                    if (!isQueuedDeleteLocalId(completedLocalId)) {
                        store.setLastRemoteIdForLocalId(completedLocalId, remoteId);
                    }
                }
            }

            store.removePendingSessionByLocalId(completedLocalId);
            if (removeQueuedDeleteLocalId(completedLocalId) && remoteId != null) {
                deleteSessionById(remoteId);
            }

            if (store.peekPendingSession() != null) {
                syncPendingSessions();
            } else if (_refreshingStats) {
                _refreshStatsQueued = true;
            } else if (_refreshStatsQueued) {
                refreshStatsFromCloud();
            }
        } else {
            removeQueuedDeleteLocalId(completedLocalId);
            var retryStore = new SessionStore();
            if (retryStore.peekPendingSession() != null) {
                scheduleSyncRetry();
            } else {
                resetSyncRetryBackoff();
            }
        }
    }

    function onDeleteResponse(responseCode as Lang.Number, data as Lang.Dictionary or Lang.String or Null) as Void {
        if (responseCode == 204 || responseCode == 200) {
            resetSyncRetryBackoff();
        }
    }

    function onDeleteByIdResponse(responseCode as Lang.Number, data as Lang.Dictionary or Lang.String or Null) as Void {
        if (responseCode == 204 || responseCode == 200) {
            resetSyncRetryBackoff();
        }
    }

    function onStatsRefreshResponse(responseCode as Lang.Number, data as Lang.Dictionary or Lang.String or PersistedContent.Iterator or Null) as Void {
        _refreshingStats = false;

        if (responseCode == 200) {
            resetSyncRetryBackoff();
            if (canInterpretRows(data)) {
                var store = new SessionStore();
                store.reconcileRecentWithRemote(responseRows(data));
                WatchUi.requestUpdate();
            }
        }

        if (_refreshStatsQueued) {
            refreshStatsFromCloud();
        }
    }

    private function scheduleSyncRetry() as Void {
        if (_syncRetryTimer == null) {
            _syncRetryTimer = new Timer.Timer();
        }

        var delay = _syncRetryDelays[_syncRetryIndex];
        if (_syncRetryIndex < _syncRetryDelays.size() - 1) {
            _syncRetryIndex += 1;
        }
        _syncRetryTimer.start(method(:onSyncRetryTimer), delay, false);
    }

    private function cancelSyncRetry() as Void {
        if (_syncRetryTimer != null) {
            _syncRetryTimer.stop();
        }
    }

    function onSyncRetryTimer() as Void {
        syncPendingSessions();
    }

    function resetSyncRetryBackoff() as Void {
        _syncRetryIndex = 0;
    }

    private function queueDeleteForInFlightLocalId(localId) as Void {
        if (localId == null || _syncingLocalId == null) { return; }
        if (!_syncingLocalId.equals(localId)) { return; }
        if (isQueuedDeleteLocalId(localId)) { return; }
        _deleteAfterSyncLocalIds.add(localId);
    }

    private function isQueuedDeleteLocalId(localId) as Lang.Boolean {
        if (localId == null || _deleteAfterSyncLocalIds == null) { return false; }

        for (var i = 0; i < _deleteAfterSyncLocalIds.size(); i++) {
            if (_deleteAfterSyncLocalIds[i].equals(localId)) {
                return true;
            }
        }
        return false;
    }

    private function removeQueuedDeleteLocalId(localId) as Lang.Boolean {
        if (localId == null || _deleteAfterSyncLocalIds == null) { return false; }

        var updated = [];
        var removed = false;
        for (var i = 0; i < _deleteAfterSyncLocalIds.size(); i++) {
            if (_deleteAfterSyncLocalIds[i].equals(localId)) {
                removed = true;
            } else {
                updated.add(_deleteAfterSyncLocalIds[i]);
            }
        }
        _deleteAfterSyncLocalIds = updated;
        return removed;
    }
}

function getApp() as watchappApp {
    return Application.getApp() as watchappApp;
}

function responseRows(data) as Lang.Array {
    var rows = [];

    if (data == null) { return rows; }

    if (data instanceof Lang.Array) {
        for (var i = 0; i < data.size(); i++) {
            rows.add(data[i]);
        }
        return rows;
    }

    if (data has :next) {
        var nextRow = data.next();
        while (nextRow != null) {
            rows.add(nextRow);
            nextRow = data.next();
        }
        return rows;
    }

    if (data instanceof Lang.Dictionary) {
        rows.add(data);
    }

    return rows;
}

function canInterpretRows(data) as Lang.Boolean {
    if (data == null) { return true; }
    if (data instanceof Lang.Array) { return true; }
    if (data instanceof Lang.Dictionary) { return true; }
    if (data has :next) { return true; }
    return false;
}

function getGenericProjectOptions() as Lang.Array {
    return [
        "Studying",
        "Reading",
        "Writing",
        "Coding",
        "Research",
        "Exercise",
        "Planning",
        "Language",
        "Music",
        "Work"
    ];
}

function normalizeProjectName(name) as Lang.String or Null {
    if (!(name instanceof Lang.String)) { return null; }

    var trimmed = trimProjectName(name as Lang.String);
    if (trimmed.length() == 0) { return null; }

    var first = trimmed.substring(0, 1).toUpper();
    if (trimmed.length() == 1) { return first; }

    return first + trimmed.substring(1, trimmed.length()).toLower();
}

function trimProjectName(value as Lang.String) as Lang.String {
    var start = 0;
    var finish = value.length();

    while (start < finish && isProjectWhitespace(value.substring(start, start + 1))) {
        start += 1;
    }

    while (finish > start && isProjectWhitespace(value.substring(finish - 1, finish))) {
        finish -= 1;
    }

    return value.substring(start, finish);
}

function isProjectWhitespace(character as Lang.String) as Lang.Boolean {
    return character.equals(" ") ||
        character.equals("\t") ||
        character.equals("\n") ||
        character.equals("\r");
}

function copyProjects(projects) as Lang.Array {
    var copy = [];
    if (!(projects instanceof Lang.Array)) { return copy; }

    for (var i = 0; i < projects.size(); i++) {
        copy.add(projects[i]);
    }

    return copy;
}

function projectArrayContains(projects, name) as Lang.Boolean {
    if (!(projects instanceof Lang.Array) || !(name instanceof Lang.String)) { return false; }

    for (var i = 0; i < projects.size(); i++) {
        if (projects[i] instanceof Lang.String && projects[i].equals(name)) {
            return true;
        }
    }

    return false;
}

function projectArrayContainsExcept(projects, name, skipIndex) as Lang.Boolean {
    if (!(projects instanceof Lang.Array) || !(name instanceof Lang.String)) { return false; }

    for (var i = 0; i < projects.size(); i++) {
        if (i == skipIndex) { continue; }
        if (projects[i] instanceof Lang.String && projects[i].equals(name)) {
            return true;
        }
    }

    return false;
}

function normalizeProjectList(projects) as Lang.Array {
    var normalized = [];
    if (!(projects instanceof Lang.Array)) { return normalized; }

    for (var i = 0; i < projects.size(); i++) {
        var project = normalizeProjectName(projects[i]);
        if (project != null && !projectArrayContains(normalized, project)) {
            normalized.add(project);
            if (normalized.size() >= 5) {
                break;
            }
        }
    }

    return normalized;
}

function getProjects() as Lang.Array {
    return normalizeProjectList(Storage.getValue("projects"));
}

function saveProjects(projects) as Void {
    Storage.setValue("projects", normalizeProjectList(projects));
}

function isFirstLaunch() as Lang.Boolean {
    return (Storage.getValue("setup_done") == null && getProjects().size() == 0);
}

function markSetupDone() as Void {
    Storage.setValue("setup_done", true);
}

function showProjectSelectionMenu(durationSeconds, label, replaceCurrent as Lang.Boolean) as Void {
    var projects = getProjects();
    var menu = new WatchUi.Menu2({ :title => "Project" });

    for (var i = 0; i < projects.size(); i++) {
        menu.addItem(new WatchUi.MenuItem(projects[i], null, i, null));
    }

    menu.addItem(new WatchUi.MenuItem("EDIT PROJECTS", "Add, rename or delete", :edit_projects, null));

    if (replaceCurrent) {
        WatchUi.switchToView(menu, new TagMenuDelegate(durationSeconds, label, projects), WatchUi.SLIDE_IMMEDIATE);
    } else {
        WatchUi.pushView(menu, new TagMenuDelegate(durationSeconds, label, projects), WatchUi.SLIDE_UP);
    }
}
