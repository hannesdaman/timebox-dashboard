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
        // Always go to menu first
        WatchUi.switchToView(new Rez.Menus.MainMenu(), new watchappMenuDelegate(), WatchUi.SLIDE_UP);

        // If there's a saved session, push timer on top of menu
        if (TimerView.hasSavedState()) {
            var remaining = Storage.getValue("timer_remaining");
            var total = Storage.getValue("timer_total");
            var label = Storage.getValue("timer_label");
            var wasRunning = Storage.getValue("timer_was_running");

            if (remaining != null && total != null && label != null) {
                if (wasRunning == null) { wasRunning = false; }
                var tag = Storage.getValue("timer_tag");
                if (tag == null) { tag = "Study"; }
                var v = new TimerView(total, label, tag);
                v.restoreState(remaining, total, label, wasRunning);
                WatchUi.pushView(v, new TimerDelegate(v), WatchUi.SLIDE_UP);
            }
        }
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        View.onUpdate(dc);
    }

    function onHide() as Void {
    }
}
