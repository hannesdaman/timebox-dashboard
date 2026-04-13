import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Timer;
import Toybox.Attention;
import Toybox.Lang;
import Toybox.Application.Storage;
import Toybox.Time;

class TimerView extends WatchUi.View {

    private var _totalSeconds;
    private var _remainingSeconds;
    private var _label;
    private var _tag;
    private var _tickTimer;
    private var _running = false;
    private var _logged = false;
    private var _resumeOnShow = true;
    private var _rootRestoredLaunch = false;
    private var _discardOnHide = false;

    function initialize(totalSeconds, label, tag) {
        WatchUi.View.initialize();
        _totalSeconds = totalSeconds;
        _remainingSeconds = totalSeconds;
        _label = label;
        _tag = tag;
        _tickTimer = new Timer.Timer();
    }

    function restoreState(remaining, total, label, wasRunning) {
        _totalSeconds = total;
        _label = label;
        _remainingSeconds = remaining;
        _resumeOnShow = (wasRunning == true);
        _running = false;
    }

    function markRootRestoredLaunch() {
        _rootRestoredLaunch = true;
    }

    function shouldBackToMenu() as Lang.Boolean {
        return _rootRestoredLaunch;
    }

    function discardSavedTimer() as Void {
        _discardOnHide = true;
        _rootRestoredLaunch = false;
        clearSavedState();
    }

    function wasRestoredRunning() {
        var wr = Storage.getValue("timer_was_running");
        return (wr != null && wr == true);
    }

    function isRunning() {
        return _running;
    }

    function toggle() {
        if (_remainingSeconds <= 0 && !_running) { return; }
        if (_running) { stopTimer(); } else { startTimer(); }
        WatchUi.requestUpdate();
    }

    function restart() {
        var wasRunning = _running;
        stopTimer();
        _logged = false;
        _remainingSeconds = _totalSeconds;
        if (wasRunning) {
            startTimer();
        }
        WatchUi.requestUpdate();
    }

    function isFinished() {
        return (_remainingSeconds <= 0 && !_running);
    }

    function onShow() {
        if (_remainingSeconds > 0 && !_running && _resumeOnShow) {
            var savedAt = Storage.getValue("timer_saved_at");
            if ((savedAt instanceof Lang.Number) || (savedAt instanceof Lang.Long)) {
                var elapsed = Time.now().value() - savedAt.toNumber();
                if (elapsed > 0) {
                    _remainingSeconds -= elapsed;
                    if (_remainingSeconds < 0) {
                        _remainingSeconds = 0;
                    }
                }
            }
            startTimer();
        }
        _resumeOnShow = false;
        WatchUi.requestUpdate();
    }

    function onHide() {
        if (_discardOnHide) {
            _discardOnHide = false;
            clearSavedState();
            stopTimer();
            return;
        }

        // Save state so we can resume later
        if (_remainingSeconds > 0) {
            _resumeOnShow = _running;
            Storage.setValue("timer_remaining", _remainingSeconds);
            Storage.setValue("timer_total", _totalSeconds);
            Storage.setValue("timer_label", _label);
            Storage.setValue("timer_tag", _tag);
            Storage.setValue("timer_saved_at", Time.now().value());
            Storage.setValue("timer_was_running", _running);
        } else {
            clearSavedState();
        }
        stopTimer();
    }

    static function clearSavedState() {
        Storage.deleteValue("timer_remaining");
        Storage.deleteValue("timer_total");
        Storage.deleteValue("timer_label");
        Storage.deleteValue("timer_tag");
        Storage.deleteValue("timer_saved_at");
        Storage.deleteValue("timer_was_running");
    }

    static function hasSavedState() {
        return (Storage.getValue("timer_remaining") != null);
    }

    static function hasRestorableState() {
        var remaining = Storage.getValue("timer_remaining");
        var total = Storage.getValue("timer_total");
        var label = Storage.getValue("timer_label");
        var wasRunning = Storage.getValue("timer_was_running");
        var tag = Storage.getValue("timer_tag");

        var remainingOk = (remaining instanceof Lang.Number) || (remaining instanceof Lang.Long);
        var totalOk = (total instanceof Lang.Number) || (total instanceof Lang.Long);
        if (!remainingOk || !totalOk) { return false; }
        if (!(label instanceof Lang.String)) { return false; }
        if (wasRunning != null && !(wasRunning instanceof Lang.Boolean)) { return false; }
        if (tag != null && !(tag instanceof Lang.String)) { return false; }

        var remainingNum = remaining.toNumber();
        var totalNum = total.toNumber();
        if (remainingNum < 0 || totalNum <= 0 || remainingNum > totalNum) { return false; }

        if (wasRunning == true) {
            var savedAt = Storage.getValue("timer_saved_at");
            if (savedAt != null && !(savedAt instanceof Lang.Number) && !(savedAt instanceof Lang.Long)) {
                return false;
            }
        }

        return true;
    }

    private function startTimer() {
        if (_running) { return; }
        _running = true;
        _tickTimer.start(method(:onTick), 1000, true);
    }

    private function stopTimer() {
        _running = false;
        _tickTimer.stop();
    }

    private function buzzFinish() {
        if (Attention has :vibrate) {
            var vibeData = [
                new Attention.VibeProfile(50, 300),
                new Attention.VibeProfile(0, 150),
                new Attention.VibeProfile(50, 300),
                new Attention.VibeProfile(0, 150),
                new Attention.VibeProfile(50, 300),
                new Attention.VibeProfile(0, 150),
                new Attention.VibeProfile(50, 300)
            ];
            Attention.vibrate(vibeData);
        }
    }

    function onTick() {
        if (_remainingSeconds <= 0) {
            stopTimer();
            WatchUi.requestUpdate();
            return;
        }

        _remainingSeconds -= 1;

        if (_remainingSeconds <= 0) {
            stopTimer();
        }

        WatchUi.requestUpdate();
    }

    function onUpdate(dc) {
        dc.clear();

        var w = dc.getWidth();
        var h = dc.getHeight();

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);

        if (_remainingSeconds <= 0 && !_running) {

            if (!_logged) {
                _logged = true;
                buzzFinish();
                var durationMinutes = (_totalSeconds / 60).toNumber();
                var store = new SessionStore();
                store.logSession(durationMinutes, _tag);
                clearSavedState();

                // Sync to cloud
                getApp().syncSession(durationMinutes, store.todayKey(), _tag);
            }

            var durationMin = (_totalSeconds / 60).toNumber();

            dc.drawText(
                w / 2, (h * 0.22).toNumber(),
                Graphics.FONT_SMALL, "* * *",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );

            dc.drawText(
                w / 2, (h * 0.38).toNumber(),
                Graphics.FONT_MEDIUM, "WELL DONE!",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );

            dc.drawText(
                w / 2, (h * 0.55).toNumber(),
                Graphics.FONT_SMALL, "+" + durationMin + " min",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );

            var store2 = new SessionStore();
            var todayTotal = store2.getTodayMinutes();

            dc.drawText(
                w / 2, (h * 0.72).toNumber(),
                Graphics.FONT_XTINY, "Today: " + todayTotal + " min",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );

            dc.drawText(
                w / 2, (h * 0.85).toNumber(),
                Graphics.FONT_XTINY, "BACK to menu",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );

        } else {
            dc.drawText(
                w / 2, (h * 0.18).toNumber(),
                Graphics.FONT_SMALL, _tag,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );

            var mm = (_remainingSeconds / 60).toNumber();
            var ss = (_remainingSeconds % 60).toNumber();
            var ssStr = (ss < 10) ? ("0" + ss) : ("" + ss);
            var timeStr = ("" + mm) + ":" + ssStr;

            dc.drawText(
                w / 2, (h * 0.43).toNumber(),
                Graphics.FONT_NUMBER_HOT, timeStr,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );

            var statusStr = _running ? "Running" : "Paused";
            dc.drawText(
                w / 2, (h * 0.65).toNumber(),
                Graphics.FONT_XTINY, statusStr,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );

            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);

            dc.drawText(
                (w * 0.80).toNumber(), (h * 0.23).toNumber(),
                Graphics.FONT_XTINY, "START",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );

            dc.drawText(
                (w * 0.78).toNumber(), (h * 0.72).toNumber(),
                Graphics.FONT_XTINY, "BACK",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );

            dc.drawText(
                (w * 0.22).toNumber(), (h * 0.72).toNumber(),
                Graphics.FONT_XTINY, "RESET",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
        }
    }
}
