import Toybox.WatchUi;
import Toybox.Lang;

class NamePickerDelegate extends WatchUi.Menu2InputDelegate {

    private var _mode;
    private var _index;
    private var _currentName;
    private var _durationSeconds;
    private var _label;

    function initialize(mode, index, currentName, durationSeconds, label) {
        Menu2InputDelegate.initialize();
        _mode = mode;
        _index = index;
        _currentName = currentName;
        _durationSeconds = durationSeconds;
        _label = label;
    }

    function onSelect(item) {
        var id = item.getId();

        if (id == :custom_name) {
            var initialText = "";
            if (_currentName != null) {
                initialText = _currentName;
            }

            WatchUi.pushView(
                new WatchUi.TextPicker(initialText),
                new ProjectCustomTextDelegate(_mode, _index, _currentName, _durationSeconds, _label),
                WatchUi.SLIDE_UP
            );
            return;
        }

        var presetIndex = id as Lang.Number;
        var presets = getGenericProjectOptions();
        if (presetIndex < 0 || presetIndex >= presets.size()) { return; }

        applyProjectNameChange(presets[presetIndex], _mode, _index, _currentName);
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        ProjectListView.replace(_durationSeconds, _label);
    }

    function onBack() {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}

class ProjectCustomTextDelegate extends WatchUi.TextPickerDelegate {

    private var _mode;
    private var _index;
    private var _currentName;
    private var _durationSeconds;
    private var _label;

    function initialize(mode, index, currentName, durationSeconds, label) {
        TextPickerDelegate.initialize();
        _mode = mode;
        _index = index;
        _currentName = currentName;
        _durationSeconds = durationSeconds;
        _label = label;
    }

    function onTextEntered(text, changed) {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);

        applyProjectNameChange(text, _mode, _index, _currentName);
        ProjectListView.replace(_durationSeconds, _label);
        return true;
    }

    function onCancel() {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        return true;
    }
}

function applyProjectNameChange(name, mode, index, currentName) as Void {
    var normalized = normalizeProjectName(name);
    if (normalized == null) { return; }

    var projects = getProjects();

    if (mode == :add_project) {
        if (projects.size() >= 5 || projectArrayContains(projects, normalized)) { return; }
        projects.add(normalized);
        saveProjects(projects);
        return;
    }

    if (mode == :rename_project) {
        if (index < 0 || index >= projects.size()) { return; }
        if (projectArrayContainsExcept(projects, normalized, index)) { return; }

        var oldName = projects[index];
        projects[index] = normalized;
        saveProjects(projects);

        if (!oldName.equals(normalized)) {
            var store = new SessionStore();
            store.renameTag(oldName, normalized);
        }
    }
}
