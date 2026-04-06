import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Communications;
import Toybox.System;

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

    function getInitialView() as [Views] or [Views, InputDelegates] {
        return [ new watchappView(), new watchappDelegate() ];
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

    function onSyncResponse(responseCode as Lang.Number, data as Lang.Dictionary or Lang.String or Null) as Void {
        if (responseCode == 201 || responseCode == 200) {
            System.println("Sync OK");
        } else {
            System.println("Sync FAILED: " + responseCode);
        }
    }
}

function getApp() as watchappApp {
    return Application.getApp() as watchappApp;
}

// Returns the list of active project names from app settings.
// Empty slots are skipped. Falls back to ["Study"] if nothing is configured.
function getProjects() as Lang.Array {
    var projects = [];
    var keys = ["project1", "project2", "project3", "project4", "project5"];
    for (var i = 0; i < keys.size(); i++) {
        try {
            var p = Application.Properties.getValue(keys[i]);
            if (p instanceof Lang.String && !(p as Lang.String).equals("")) {
                projects.add(p);
            }
        } catch(e instanceof Lang.Exception) {}
    }
    if (projects.size() == 0) {
        projects.add("Study");
    }
    return projects;
}
