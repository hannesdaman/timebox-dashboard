import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Timer;

class StatsView extends WatchUi.View {

    private var _store;
    private var _message = null;
    private var _messageTimer;
    private var _tags;
    private var _tagIndex = 0;

    function initialize() {
        View.initialize();
        _store = new SessionStore();
        _messageTimer = new Timer.Timer();
        getApp().syncPendingSessions();
        getApp().refreshStatsFromCloud();
        // Build ["All", project1, project2, ...] from on-watch project storage
        _tags = ["All"];
        var projects = getProjects();
        for (var i = 0; i < projects.size(); i++) {
            _tags.add(projects[i]);
        }
    }

    function cycleTag() {
        _tagIndex = (_tagIndex + 1) % _tags.size();
        WatchUi.requestUpdate();
    }

    function activeTag() {
        return _tags[_tagIndex];
    }

    function resetToday() {
        var today = _store.todayKey();
        _store.clearToday();
        getApp().deleteSessionsForDate(today);
        _message = "Today reset!";
        WatchUi.requestUpdate();
        _messageTimer.start(method(:onMessageTimeout), 2000, false);
    }

    function undoLast() {
        var info = _store.undoLastRecord();
        if (info == null) {
            _message = "Nothing to undo";
        } else {
            _message = "-" + info["duration"] + " min removed";
            if (info["remote_id"] != null) {
                getApp().deleteSessionById(info["remote_id"]);
            }
        }
        WatchUi.requestUpdate();
        _messageTimer.start(method(:onMessageTimeout), 2000, false);
    }

    function onMessageTimeout() {
        _message = null;
        WatchUi.requestUpdate();
    }

    function onUpdate(dc) {
        dc.clear();

        var w = dc.getWidth();
        var h = dc.getHeight();

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);

        if (_message != null) {
            dc.drawText(
                w / 2, (h * 0.45).toNumber(),
                Graphics.FONT_MEDIUM, _message,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
            return;
        }

        var tag = activeTag();
        dc.drawText(
            w / 2, (h * 0.10).toNumber(),
            Graphics.FONT_SMALL, "Stats: " + tag,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );

        var today;
        var todayBoxes;
        var week;
        var month;
        var year;

        if (tag.equals("All")) {
            today = _store.getTodayMinutes();
            todayBoxes = _store.getTodayBoxes();
            week = _store.getWeekMinutes();
            month = _store.getMonthMinutes();
            year = _store.getYearMinutes();
        } else {
            today = _store.getTodayMinutesForTag(tag);
            todayBoxes = _store.getTodayBoxesForTag(tag);
            week = _store.getWeekMinutesForTag(tag);
            month = _store.getMonthMinutesForTag(tag);
            year = _store.getYearMinutesForTag(tag);
        }

        dc.drawText(
            w / 2, (h * 0.28).toNumber(),
            Graphics.FONT_XTINY, "Today: " + today + " min (" + todayBoxes + ")",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );

        dc.drawText(
            w / 2, (h * 0.40).toNumber(),
            Graphics.FONT_XTINY, "Week: " + week + " min",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );

        dc.drawText(
            w / 2, (h * 0.52).toNumber(),
            Graphics.FONT_XTINY, "Month: " + month + " min",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );

        dc.drawText(
            w / 2, (h * 0.64).toNumber(),
            Graphics.FONT_XTINY, "Year: " + year + " min",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);

        dc.drawText(
            w / 2, (h * 0.78).toNumber(),
            Graphics.FONT_XTINY, "SELECT=Filter  UP=Undo",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );

        dc.drawText(
            w / 2, (h * 0.88).toNumber(),
            Graphics.FONT_XTINY, "DOWN = Reset today",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }
}
