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
        ResetTodayConfirmView.show(_view);
        return true;
    }

    function onBack() {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }
}

class ResetTodayConfirmView {

    static function show(statsView) {
        var menu = new WatchUi.Menu2({ :title => "Reset today?" });
        menu.addItem(new WatchUi.MenuItem("Yes", "Erase all logged sessions from today", :confirm_yes, null));
        menu.addItem(new WatchUi.MenuItem("No", "Keep today's logged sessions", :confirm_no, null));
        WatchUi.pushView(menu, new ResetTodayConfirmDelegate(statsView), WatchUi.SLIDE_UP);
    }
}

class ResetTodayConfirmDelegate extends WatchUi.Menu2InputDelegate {

    private var _view;

    function initialize(statsView) {
        Menu2InputDelegate.initialize();
        _view = statsView;
    }

    function onSelect(item) {
        var id = item.getId();

        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);

        if (id == :confirm_yes) {
            _view.resetToday();
        }
    }

    function onBack() {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}
