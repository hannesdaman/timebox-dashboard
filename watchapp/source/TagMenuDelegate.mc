import Toybox.WatchUi;
import Toybox.Lang;

class TagMenuDelegate extends WatchUi.Menu2InputDelegate {

    private var _durationSeconds;
    private var _label;
    private var _projects;

    function initialize(durationSeconds, label, projects) {
        Menu2InputDelegate.initialize();
        _durationSeconds = durationSeconds;
        _label = label;
        _projects = projects;
    }

    function onSelect(item) {
        var id = item.getId();
        if (id == :edit_projects) {
            ProjectListView.replace(_durationSeconds, _label);
            return;
        }

        var idx = id as Lang.Number;
        if (idx < 0 || idx >= _projects.size()) { return; }
        var tag = _projects[idx];
        var v = new TimerView(_durationSeconds, _label, tag);
        WatchUi.switchToView(v, new TimerDelegate(v), WatchUi.SLIDE_UP);
    }
}
