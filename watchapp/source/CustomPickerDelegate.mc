import Toybox.WatchUi;

class CustomPickerDelegate extends WatchUi.BehaviorDelegate {

    private var _view;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    // UP button on fenix 7 = increment minutes
    function onPreviousPage() {
        _view.increment();
        return true;
    }

    // DOWN button on fenix 7 = decrement minutes
    function onNextPage() {
        _view.decrement();
        return true;
    }

    // START/STOP = show tag picker, then launch timer with chosen minutes + tag
    function onSelect() {
        var mins = _view.getMinutes();
        var label = "" + mins + " min";
        var projects = getProjects();
        var menu = new WatchUi.Menu2({:title => "Project"});
        for (var i = 0; i < projects.size(); i++) {
            menu.addItem(new WatchUi.MenuItem(projects[i], null, i, null));
        }
        WatchUi.switchToView(menu, new TagMenuDelegate(mins * 60, label, projects), WatchUi.SLIDE_UP);
        return true;
    }

    // BACK = return to menu without starting
    function onBack() {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }
}
