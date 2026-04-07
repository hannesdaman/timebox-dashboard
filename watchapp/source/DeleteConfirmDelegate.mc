import Toybox.WatchUi;

class DeleteConfirmView {

    static function show(index, name, durationSeconds, label) {
        var menu = new WatchUi.Menu2({ :title => "Delete " + name + "?" });
        menu.addItem(new WatchUi.MenuItem("Yes", "Delete this project", :confirm_yes, null));
        menu.addItem(new WatchUi.MenuItem("No", "Keep this project", :confirm_no, null));
        WatchUi.pushView(
            menu,
            new DeleteConfirmDelegate(index, durationSeconds, label),
            WatchUi.SLIDE_UP
        );
    }
}

class DeleteConfirmDelegate extends WatchUi.Menu2InputDelegate {

    private var _index;
    private var _durationSeconds;
    private var _label;

    function initialize(index, durationSeconds, label) {
        Menu2InputDelegate.initialize();
        _index = index;
        _durationSeconds = durationSeconds;
        _label = label;
    }

    function onSelect(item) {
        var id = item.getId();

        if (id == :confirm_no) {
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            return;
        }

        var projects = getProjects();
        if (_index >= 0 && _index < projects.size() && projects.size() > 1) {
            var updated = [];
            for (var i = 0; i < projects.size(); i++) {
                if (i != _index) {
                    updated.add(projects[i]);
                }
            }
            saveProjects(updated);
        }

        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        ProjectListView.replace(_durationSeconds, _label);
    }

    function onBack() {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}
