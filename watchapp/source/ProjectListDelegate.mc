import Toybox.WatchUi;
import Toybox.Lang;

class ProjectListDelegate extends WatchUi.Menu2InputDelegate {

    private var _durationSeconds;
    private var _label;

    function initialize(durationSeconds, label) {
        Menu2InputDelegate.initialize();
        _durationSeconds = durationSeconds;
        _label = label;
    }

    function onSelect(item) {
        var id = item.getId();

        if (id == :add_project) {
            NamePickerView.showForAdd(_durationSeconds, _label);
            return;
        }

        var index = id as Lang.Number;
        var projects = getProjects();
        if (index < 0 || index >= projects.size()) { return; }

        var actionMenu = new WatchUi.Menu2({ :title => projects[index] });
        actionMenu.addItem(new WatchUi.MenuItem("Rename", "Choose a new name", :rename_project, null));
        actionMenu.addItem(new WatchUi.MenuItem("Delete", "Remove this project", :delete_project, null));
        WatchUi.pushView(
            actionMenu,
            new ProjectActionDelegate(index, projects[index], _durationSeconds, _label),
            WatchUi.SLIDE_UP
        );
    }

    function onBack() {
        if (_durationSeconds != null && _label != null) {
            showProjectSelectionMenu(_durationSeconds, _label, true);
        } else {
            WatchUi.popView(WatchUi.SLIDE_DOWN);
        }
    }
}

class ProjectActionDelegate extends WatchUi.Menu2InputDelegate {

    private var _index;
    private var _name;
    private var _durationSeconds;
    private var _label;

    function initialize(index, name, durationSeconds, label) {
        Menu2InputDelegate.initialize();
        _index = index;
        _name = name;
        _durationSeconds = durationSeconds;
        _label = label;
    }

    function onSelect(item) {
        var id = item.getId();

        if (id == :rename_project) {
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            NamePickerView.showForRename(_index, _name, _durationSeconds, _label);
            return;
        }

        if (id == :delete_project) {
            if (getProjects().size() <= 1) {
                WatchUi.popView(WatchUi.SLIDE_DOWN);
                return;
            }

            DeleteConfirmView.show(_index, _name, _durationSeconds, _label);
            return;
        }
    }
}
