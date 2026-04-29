import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.System;
import Toybox.Graphics;
import Toybox.Application.Storage;

class watchappView extends WatchUi.View {

    function initialize() {
        View.initialize();
    }

    function onLayout(dc as Dc) as Void {
        setLayout(Rez.Layouts.MainLayout(dc));
    }

    function onShow() as Void {
        // Real devices can retain stale object-store values across installs.
        // If resume state is malformed, clear it instead of crashing on launch.
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
                    var v = new TimerView(total, label, tag);
                    v.restoreState(remaining, total, label, wasRunning);
                    WatchUi.switchToView(v, new TimerDelegate(v), WatchUi.SLIDE_UP);
                    return;
                } catch(e instanceof Lang.Exception) {
                    TimerView.clearSavedState();
                }
            } else {
                TimerView.clearSavedState();
            }
        }

        WatchUi.switchToView(new Rez.Menus.MainMenu(), new watchappMenuDelegate(), WatchUi.SLIDE_UP);
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        View.onUpdate(dc);
    }

    function onHide() as Void {
    }
}
