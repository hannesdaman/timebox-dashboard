import Toybox.WatchUi;

class TimerDelegate extends WatchUi.BehaviorDelegate {

    var _view;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    // START/STOP = pause/resume
    function onSelect() {
        _view.toggle();
        return true;
    }

    // DOWN = reset timer (blocked after completion)
    function onNextPage() {
        if (!_view.isFinished()) {
            _view.restart();
        }
        return true;
    }

    // BACK = exit app (session is auto-saved in onHide)
    // On WELL DONE screen, state is already cleared
    function onBack() {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }
}
