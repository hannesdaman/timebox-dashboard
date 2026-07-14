import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Timer;
import Toybox.Lang;
import Toybox.Application.Storage;
import Toybox.Time;
import Toybox.System;

class TimerView extends WatchUi.View {

    private var _totalSeconds;
    private var _label;
    private var _tag;

    // The countdown is anchored to the monotonic millisecond clock instead of
    // decrementing once per tick: late or skipped timer callbacks then cost no
    // accuracy, and pause/resume keeps sub-second progress. _remainingMs is
    // authoritative while paused; while running the remaining time is
    // (_endMs - System.getTimer()). Number math wraps like a 32-bit int, so
    // the subtraction stays correct across getTimer() rollover (~25 days).
    private var _remainingMs;
    private var _endMs = 0;
    private var _running = false;

    // Wall-clock epoch seconds when the running countdown will finish; lets a
    // session that completed while the app was closed be logged on the day it
    // actually ended, not the day the app was reopened.
    private var _endWallEpoch = 0;

    private var _tickTimer;
    private var _vibeTimer;
    private var _vibeChunksLeft = 0;
    private var _vibeLevel = VIBE_LEVEL_MODEST;

    private var _logged = false;
    private var _todayMinutesAtFinish = 0;
    private var _lastDrawnSeconds = -1;

    private var _resumeOnShow = true;
    // Guards the timer_saved_at catch-up: only a view restored from storage
    // or re-shown after our own onHide may consume it. A fresh timer must
    // never apply a stale saved_at left behind by an earlier timer.
    private var _applySavedElapsedOnShow = false;
    private var _rootRestoredLaunch = false;
    private var _discardOnHide = false;

    function initialize(totalSeconds, label, tag) {
        WatchUi.View.initialize();
        if (!(totalSeconds instanceof Lang.Number) && !(totalSeconds instanceof Lang.Long)) {
            totalSeconds = 25 * 60;
        }
        _totalSeconds = totalSeconds.toNumber();
        if (_totalSeconds <= 0) {
            _totalSeconds = 25 * 60;
        }
        _remainingMs = _totalSeconds * 1000;
        _label = label;
        _tag = tag;
        _tickTimer = new Timer.Timer();
        _vibeTimer = new Timer.Timer();
    }

    function restoreState(remaining, total, label, wasRunning) {
        _totalSeconds = total.toNumber();
        _label = label;
        _remainingMs = remaining.toNumber() * 1000;
        _resumeOnShow = (wasRunning == true);
        _applySavedElapsedOnShow = true;
        _running = false;
        _logged = false;
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

    function isRunning() {
        return _running;
    }

    function isFinished() {
        return (!_running && _remainingMs <= 0);
    }

    function toggle() {
        if (isFinished()) { return; }
        if (_running) { pauseTimer(); } else { startTimer(); }
        WatchUi.requestUpdate();
    }

    function restart() {
        var wasRunning = _running;
        pauseTimer();
        stopVibeChain();
        _logged = false;
        _remainingMs = _totalSeconds * 1000;
        if (wasRunning) {
            startTimer();
        }
        WatchUi.requestUpdate();
    }

    function onShow() {
        if (!_running && _remainingMs > 0 && _resumeOnShow) {
            var savedAt = _applySavedElapsedOnShow ? Storage.getValue("timer_saved_at") : null;
            if ((savedAt instanceof Lang.Number) || (savedAt instanceof Lang.Long)) {
                var remainingSecs = remainingSecondsNow();
                var deadline = savedAt.toNumber() + remainingSecs;
                var elapsed = Time.now().value() - savedAt.toNumber();
                if (elapsed > 0) {
                    if (elapsed >= remainingSecs) {
                        _remainingMs = 0;
                        // The countdown expired while hidden; attribute the
                        // session to the moment it actually ended.
                        _endWallEpoch = deadline;
                    } else {
                        _remainingMs -= elapsed * 1000;
                    }
                }
            }
            if (_remainingMs > 0) {
                startTimer();
            } else {
                finishSession();
            }
        }
        _resumeOnShow = false;
        _applySavedElapsedOnShow = false;
        WatchUi.requestUpdate();
    }

    function onHide() {
        if (_discardOnHide) {
            _discardOnHide = false;
            clearSavedState();
            pauseTimer();
            stopVibeChain();
            return;
        }

        var wasRunning = _running;
        pauseTimer();
        stopVibeChain();

        // Save state so we can resume later
        if (_remainingMs > 0) {
            _resumeOnShow = wasRunning;
            _applySavedElapsedOnShow = true;
            Storage.setValue("timer_remaining", remainingSecondsNow());
            Storage.setValue("timer_total", _totalSeconds);
            Storage.setValue("timer_label", _label);
            Storage.setValue("timer_tag", _tag);
            Storage.setValue("timer_saved_at", Time.now().value());
            Storage.setValue("timer_was_running", wasRunning);
        } else {
            clearSavedState();
        }
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
        if (remainingNum <= 0 || totalNum <= 0 || remainingNum > totalNum) { return false; }

        if (wasRunning == true) {
            var savedAt = Storage.getValue("timer_saved_at");
            if (savedAt != null && !(savedAt instanceof Lang.Number) && !(savedAt instanceof Lang.Long)) {
                return false;
            }
        }

        return true;
    }

    private function remainingMsNow() as Lang.Number {
        if (_running) {
            var ms = _endMs - System.getTimer();
            return (ms > 0) ? ms : 0;
        }
        return _remainingMs;
    }

    // Countdown style: show the ceiling so the full duration is visible for
    // the first second and 0:00 appears exactly at completion.
    private function remainingSecondsNow() as Lang.Number {
        var ms = remainingMsNow();
        return ((ms + 999) / 1000).toNumber();
    }

    private function startTimer() {
        if (_running || _remainingMs <= 0) { return; }
        _endMs = System.getTimer() + _remainingMs;
        _endWallEpoch = Time.now().value() + remainingSecondsNow();
        _running = true;
        _tickTimer.start(method(:onTick), 1000, true);
    }

    private function pauseTimer() {
        if (_running) {
            var ms = _endMs - System.getTimer();
            _remainingMs = (ms > 0) ? ms : 0;
        }
        _running = false;
        _tickTimer.stop();
    }

    function onTick() {
        if (!_running) { return; }

        if (remainingMsNow() <= 0) {
            finishSession();
            return;
        }

        var seconds = remainingSecondsNow();
        if (seconds != _lastDrawnSeconds) {
            WatchUi.requestUpdate();
        }
    }

    // Runs exactly once per completed countdown: stops ticking, starts the
    // vibration, records the session, and kicks off cloud sync.
    private function finishSession() {
        pauseTimer();
        _remainingMs = 0;

        if (_logged) {
            WatchUi.requestUpdate();
            return;
        }
        _logged = true;

        startFinishVibe();

        try {
            var endEpoch = _endWallEpoch;
            var nowEpoch = Time.now().value();
            if (endEpoch <= 0 || endEpoch > nowEpoch) {
                endEpoch = nowEpoch;
            }

            var durationMinutes = (_totalSeconds / 60).toNumber();
            var store = new SessionStore();
            store.logSessionAt(durationMinutes, _tag, endEpoch);
            clearSavedState();
            _todayMinutesAtFinish = store.getTodayMinutes();
            getApp().syncPendingSessions();
        } catch (e instanceof Lang.Exception) {
            // A storage/sync hiccup must never crash the finish screen.
            // Leave a breadcrumb we can read back instead of showing "IQ!".
            Storage.setValue("last_finish_error", e.getErrorMessage());
        }

        WatchUi.requestUpdate();
    }

    private function startFinishVibe() {
        _vibeLevel = getVibeLevel();
        _vibeChunksLeft = vibeChunkCount(_vibeLevel);
        playNextVibeChunk();
    }

    function onVibeChunkDue() {
        playNextVibeChunk();
    }

    private function playNextVibeChunk() {
        if (_vibeChunksLeft <= 0) { return; }
        _vibeChunksLeft -= 1;
        playVibeChunk(_vibeLevel);
        if (_vibeChunksLeft > 0) {
            _vibeTimer.start(method(:onVibeChunkDue), vibeChunkDurationMs() + vibeChunkGapMs(), false);
        }
    }

    private function stopVibeChain() {
        _vibeChunksLeft = 0;
        _vibeTimer.stop();
    }

    function onUpdate(dc) {
        dc.clear();

        var w = dc.getWidth();
        var h = dc.getHeight();

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);

        if (isFinished()) {
            drawFinishScreen(dc, w, h);
        } else {
            drawCountdown(dc, w, h);
        }
    }

    private function drawFinishScreen(dc, w, h) {
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

        dc.drawText(
            w / 2, (h * 0.72).toNumber(),
            Graphics.FONT_XTINY, "Today: " + _todayMinutesAtFinish + " min",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );

        dc.drawText(
            w / 2, (h * 0.85).toNumber(),
            Graphics.FONT_XTINY, "BACK to menu",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }

    private function drawCountdown(dc, w, h) {
        dc.drawText(
            w / 2, (h * 0.18).toNumber(),
            Graphics.FONT_SMALL, _tag,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );

        var seconds = remainingSecondsNow();
        _lastDrawnSeconds = seconds;

        var mm = (seconds / 60).toNumber();
        var ss = (seconds % 60).toNumber();
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
