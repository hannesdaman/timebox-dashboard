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
    private var _deadlineSeconds = null;
    private var _running = false;
    private var _logged = false;
    private var _resumeOnShow = true;
    private var _rootRestoredLaunch = false;
    private var _discardOnHide = false;
    private var _timeStr = "";
    private var _statusStr = "Paused";
    private var _doneDurationStr = "";
    private var _todayTotal = 0;
    private var _layoutWidth = null;
    private var _layoutHeight = null;
    private var _centerX = 0;
    private var _doneStarsY = 0;
    private var _doneTitleY = 0;
    private var _doneDurationY = 0;
    private var _doneTodayY = 0;
    private var _doneBackY = 0;
    private var _timerTagY = 0;
    private var _timerTimeY = 0;
    private var _timerStatusY = 0;
    private var _timerStartX = 0;
    private var _timerStartY = 0;
    private var _timerBackX = 0;
    private var _timerBackY = 0;
    private var _timerResetX = 0;
    private var _timerResetY = 0;

    function initialize(totalSeconds, label, tag) {
        WatchUi.View.initialize();
        _totalSeconds = totalSeconds;
        _remainingSeconds = totalSeconds;
        _label = label;
        _tag = tag;
        _tickTimer = new Timer.Timer();
        updateCachedTimeText();
        updateCachedDurationText();
    }

    function restoreState(remaining, total, label, wasRunning) {
        _totalSeconds = total;
        _label = label;
        _remainingSeconds = remaining;
        _resumeOnShow = (wasRunning == true);
        _running = false;
        _deadlineSeconds = null;
        _statusStr = "Paused";
        updateCachedTimeText();
        updateCachedDurationText();

        if (_resumeOnShow) {
            applyRestoredRunningState();
        }
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
        getApp().setTimerActive(false);
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
        if (_running) {
            stopTimer();
            persistTimerState();
        } else {
            startTimer();
        }
        WatchUi.requestUpdate();
    }

    function restart() {
        var wasRunning = _running;
        stopTimer();
        _logged = false;
        _todayTotal = 0;
        _remainingSeconds = _totalSeconds;
        updateCachedTimeText();
        if (wasRunning) {
            startTimer();
        } else {
            persistTimerState();
            getApp().setTimerActive(true);
        }
        WatchUi.requestUpdate();
    }

    function isFinished() {
        return (_remainingSeconds <= 0 && !_running);
    }

    function onShow() {
        if (_remainingSeconds > 0) {
            getApp().setTimerActive(true);
        }

        if (_remainingSeconds > 0 && !_running && _resumeOnShow) {
            applyRestoredRunningState();
            if (_remainingSeconds > 0) {
                startTimer();
            }
        }
        _resumeOnShow = false;
        WatchUi.requestUpdate();
    }

    function onHide() {
        if (_discardOnHide) {
            _discardOnHide = false;
            clearSavedState();
            stopTimer();
            getApp().setTimerActive(false);
            return;
        }

        updateRemainingFromClock();

        if (_remainingSeconds <= 0) {
            completeTimer();
            return;
        }

        // Save state so we can resume later
        if (_remainingSeconds > 0) {
            _resumeOnShow = _running;
            persistTimerState();
            getApp().setTimerActive(true);
        } else {
            clearSavedState();
            getApp().setTimerActive(false);
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
        Storage.deleteValue("timer_deadline");
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

            var deadline = Storage.getValue("timer_deadline");
            if (deadline != null && !(deadline instanceof Lang.Number) && !(deadline instanceof Lang.Long)) {
                return false;
            }
        }

        return true;
    }

    private function startTimer() {
        if (_running) { return; }
        if (_remainingSeconds <= 0) {
            completeTimer();
            return;
        }

        var now = Time.now().value();
        if ((_deadlineSeconds == null) || (_deadlineSeconds <= now)) {
            _deadlineSeconds = now + _remainingSeconds;
        } else {
            _remainingSeconds = _deadlineSeconds - now;
            updateCachedTimeText();
        }

        _running = true;
        _statusStr = "Running";
        getApp().setTimerActive(true);
        persistTimerState();
        _tickTimer.start(method(:onTick), 1000, true);
    }

    private function stopTimer() {
        updateRemainingFromClock();
        _running = false;
        _deadlineSeconds = null;
        _statusStr = "Paused";
        _tickTimer.stop();
    }

    private function updateRemainingFromClock() as Void {
        if (!_running || _deadlineSeconds == null) { return; }

        var remaining = _deadlineSeconds - Time.now().value();
        if (remaining < 0) {
            remaining = 0;
        }

        if (remaining != _remainingSeconds) {
            _remainingSeconds = remaining;
            updateCachedTimeText();
        }
    }

    private function applyRestoredRunningState() as Void {
        var now = Time.now().value();
        var deadline = Storage.getValue("timer_deadline");

        if ((deadline instanceof Lang.Number) || (deadline instanceof Lang.Long)) {
            _deadlineSeconds = deadline.toNumber();
            _remainingSeconds = _deadlineSeconds - now;
        } else {
            var savedAt = Storage.getValue("timer_saved_at");
            if ((savedAt instanceof Lang.Number) || (savedAt instanceof Lang.Long)) {
                var elapsed = now - savedAt.toNumber();
                if (elapsed > 0) {
                    _remainingSeconds -= elapsed;
                }
            }
        }

        if (_remainingSeconds <= 0) {
            _remainingSeconds = 0;
            updateCachedTimeText();
            _resumeOnShow = false;
            completeTimer();
            return;
        }

        updateCachedTimeText();
    }

    private function persistTimerState() as Void {
        if (_remainingSeconds <= 0) {
            clearSavedState();
            return;
        }

        Storage.setValue("timer_remaining", _remainingSeconds);
        Storage.setValue("timer_total", _totalSeconds);
        Storage.setValue("timer_label", _label);
        Storage.setValue("timer_tag", _tag);
        Storage.setValue("timer_saved_at", Time.now().value());
        Storage.setValue("timer_was_running", _running);

        if (_running && _deadlineSeconds != null) {
            Storage.setValue("timer_deadline", _deadlineSeconds);
        } else {
            Storage.deleteValue("timer_deadline");
        }
    }

    private function completeTimer() as Void {
        if (_logged) { return; }

        _tickTimer.stop();
        _running = false;
        _deadlineSeconds = null;
        _statusStr = "Paused";
        _remainingSeconds = 0;
        updateCachedTimeText();

        _logged = true;
        buzzFinish();

        var durationMinutes = (_totalSeconds / 60).toNumber();
        var store = new SessionStore();
        store.logSession(durationMinutes, _tag);
        _todayTotal = store.getTodayMinutes();
        clearSavedState();

        // Sync to cloud
        var app = getApp();
        app.syncSession(durationMinutes, store.todayKey(), _tag);
        app.setTimerActive(false);
        app.refreshStatsFromCloud();
    }

    private function updateCachedTimeText() as Void {
        var mm = (_remainingSeconds / 60).toNumber();
        var ss = (_remainingSeconds % 60).toNumber();
        var ssStr = (ss < 10) ? ("0" + ss) : ("" + ss);
        _timeStr = ("" + mm) + ":" + ssStr;
    }

    private function updateCachedDurationText() as Void {
        var durationMin = (_totalSeconds / 60).toNumber();
        _doneDurationStr = "+" + durationMin + " min";
    }

    private function cacheLayout(dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        if (_layoutWidth == w && _layoutHeight == h) { return; }

        _layoutWidth = w;
        _layoutHeight = h;
        _centerX = w / 2;

        _doneStarsY = (h * 0.22).toNumber();
        _doneTitleY = (h * 0.38).toNumber();
        _doneDurationY = (h * 0.55).toNumber();
        _doneTodayY = (h * 0.72).toNumber();
        _doneBackY = (h * 0.85).toNumber();

        _timerTagY = (h * 0.18).toNumber();
        _timerTimeY = (h * 0.43).toNumber();
        _timerStatusY = (h * 0.65).toNumber();
        _timerStartX = (w * 0.80).toNumber();
        _timerStartY = (h * 0.23).toNumber();
        _timerBackX = (w * 0.78).toNumber();
        _timerBackY = (h * 0.72).toNumber();
        _timerResetX = (w * 0.22).toNumber();
        _timerResetY = _timerBackY;
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
        if (!_running) {
            return;
        }

        updateRemainingFromClock();

        if (_remainingSeconds <= 0) {
            completeTimer();
            WatchUi.requestUpdate();
            return;
        }

        WatchUi.requestUpdate();
    }

    function onUpdate(dc) {
        dc.clear();
        cacheLayout(dc);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);

        if (_remainingSeconds <= 0 && !_running) {
            dc.drawText(
                _centerX, _doneStarsY,
                Graphics.FONT_SMALL, "* * *",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );

            dc.drawText(
                _centerX, _doneTitleY,
                Graphics.FONT_MEDIUM, "WELL DONE!",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );

            dc.drawText(
                _centerX, _doneDurationY,
                Graphics.FONT_SMALL, _doneDurationStr,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );

            dc.drawText(
                _centerX, _doneTodayY,
                Graphics.FONT_XTINY, "Today: " + _todayTotal + " min",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );

            dc.drawText(
                _centerX, _doneBackY,
                Graphics.FONT_XTINY, "BACK to menu",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );

        } else {
            dc.drawText(
                _centerX, _timerTagY,
                Graphics.FONT_SMALL, _tag,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );

            dc.drawText(
                _centerX, _timerTimeY,
                Graphics.FONT_NUMBER_HOT, _timeStr,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );

            dc.drawText(
                _centerX, _timerStatusY,
                Graphics.FONT_XTINY, _statusStr,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );

            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);

            dc.drawText(
                _timerStartX, _timerStartY,
                Graphics.FONT_XTINY, "START",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );

            dc.drawText(
                _timerBackX, _timerBackY,
                Graphics.FONT_XTINY, "BACK",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );

            dc.drawText(
                _timerResetX, _timerResetY,
                Graphics.FONT_XTINY, "RESET",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
        }
    }
}
