import Toybox.WatchUi;

class StatsDelegate extends WatchUi.BehaviorDelegate {

    private var _view;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    // SELECT = cycle project filter
    function onSelect() {
        _view.cycleTag();
        return true;
    }

    // UP = undo last session
    function onPreviousPage() {
        _view.undoLast();
        return true;
    }

    // DOWN = reset today
    function onNextPage() {
        _view.resetToday();
        return true;
    }

    function onBack() {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }
}
