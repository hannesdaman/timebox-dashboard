import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Communications;
import Toybox.System;
import Toybox.Application.Storage;

class watchappApp extends Application.AppBase {

    var SUPABASE_URL = "https://gujufwafdradmmehtafx.supabase.co/rest/v1/sessions";
    var SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd1anVmd2FmZHJhZG1tZWh0YWZ4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzUxMjE5NDYsImV4cCI6MjA5MDY5Nzk0Nn0.cd9vSriuByxKNaWQhLNWfaiBgEjabrn_9zN6LNlPvrM";

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
    }

    function onStop(state as Dictionary?) as Void {
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
        var dateStr = formatDateKey(dateKey);

        var payload = {
            "duration" => durationMinutes,
            "session_date" => dateStr,
            "tag" => tag
        };

        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_POST,
            :headers => {
                "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON,
                "apikey" => SUPABASE_KEY,
                "Authorization" => "Bearer " + SUPABASE_KEY,
                "Prefer" => "return=minimal"
            },
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };

        Communications.makeWebRequest(SUPABASE_URL, payload, options, method(:onSyncResponse));
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

    function onSyncResponse(responseCode as Lang.Number, data as Lang.Dictionary or Lang.String or Null) as Void {
        if (responseCode == 201 || responseCode == 200) {
            System.println("Sync OK");
        } else {
            System.println("Sync FAILED: " + responseCode);
        }
    }

    function onDeleteResponse(responseCode as Lang.Number, data as Lang.Dictionary or Lang.String or Null) as Void {
        if (responseCode == 204 || responseCode == 200) {
            System.println("Delete sync OK");
        } else {
            System.println("Delete sync FAILED: " + responseCode);
        }
    }
}

function getApp() as watchappApp {
    return Application.getApp() as watchappApp;
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
