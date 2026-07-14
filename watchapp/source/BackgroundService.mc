import Toybox.Background;
import Toybox.System;
import Toybox.Lang;

// Runs while the app is closed. Scheduled by watchappApp.onStop for the
// moment a running countdown expires; asks the system to launch the app so
// the completion screen and vibration appear (mirroring the native Timer
// app popping up). The system shows a confirmation dialog; Connect IQ apps
// cannot force-launch without it.
(:background)
class TimeBoxBackgroundService extends System.ServiceDelegate {

    function initialize() {
        ServiceDelegate.initialize();
    }

    function onTemporalEvent() as Void {
        try {
            Background.requestApplicationWake("TimeBox: timer done!");
        } catch (e instanceof Lang.Exception) {
            // Never let the wake request keep Background.exit from running.
        }
        Background.exit(null);
    }
}
