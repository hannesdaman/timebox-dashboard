import Toybox.WatchUi;
import Toybox.Lang;

class SettingsMenu {

    static function push() as Void {
        var menu = new WatchUi.Menu2({ :title => "Settings" });
        menu.addItem(new WatchUi.MenuItem("Vibration", vibeLevelName(getVibeLevel()), :vibration, null));
        menu.addItem(new WatchUi.MenuItem("Timers", "Add or remove presets", :timers, null));
        WatchUi.pushView(menu, new SettingsMenuDelegate(), WatchUi.SLIDE_UP);
    }
}

class SettingsMenuDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item) {
        var id = item.getId();

        if (id == :vibration) {
            VibeLevelMenu.push(item);
            return;
        }
        if (id == :timers) {
            PresetListMenu.push();
            return;
        }
    }

}

class VibeLevelMenu {

    static function push(parentItem) as Void {
        var current = getVibeLevel();
        var menu = new WatchUi.Menu2({ :title => "Vibration" });
        for (var level = VIBE_LEVEL_MODEST; level <= VIBE_LEVEL_EXTREME; level++) {
            var hint = (level == current) ? "Current" : null;
            menu.addItem(new WatchUi.MenuItem(vibeLevelName(level), hint, level, null));
        }
        WatchUi.pushView(menu, new VibeLevelDelegate(parentItem), WatchUi.SLIDE_UP);
    }
}

class VibeLevelDelegate extends WatchUi.Menu2InputDelegate {

    private var _parentItem;

    function initialize(parentItem) {
        Menu2InputDelegate.initialize();
        _parentItem = parentItem;
    }

    function onSelect(item) {
        var level = item.getId() as Lang.Number;
        setVibeLevel(level);
        if (_parentItem != null) {
            _parentItem.setSubLabel(vibeLevelName(level));
        }
        // one chunk as a strength preview
        playVibeChunk(level);
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    }

}

class PresetListMenu {

    static function push() as Void {
        WatchUi.pushView(build(null), new PresetListDelegate(), WatchUi.SLIDE_UP);
    }

    static function replaceCurrent(message) as Void {
        WatchUi.switchToView(build(message), new PresetListDelegate(), WatchUi.SLIDE_IMMEDIATE);
    }

    static function build(message) {
        var title = (message != null) ? message : "Timers";
        var menu = new WatchUi.Menu2({ :title => title });

        var presets = getTimerPresets();
        for (var i = 0; i < presets.size(); i++) {
            menu.addItem(new WatchUi.MenuItem("" + presets[i] + " min", "Select to delete", i, null));
        }
        if (presets.size() < PRESET_MAX_COUNT) {
            menu.addItem(new WatchUi.MenuItem("+ Add timer", "5-120 minutes", :add_preset, null));
        }
        return menu;
    }
}

class PresetListDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item) {
        var id = item.getId();

        if (id == :add_preset) {
            var picker = new CustomPickerView();
            WatchUi.pushView(picker, new PresetAddDelegate(picker), WatchUi.SLIDE_UP);
            return;
        }

        var index = id as Lang.Number;
        var presets = getTimerPresets();
        if (index < 0 || index >= presets.size()) { return; }

        if (presets.size() <= 1) {
            PresetListMenu.replaceCurrent("Keep at least 1");
            return;
        }

        var menu = new WatchUi.Menu2({ :title => "Delete " + presets[index] + " min?" });
        menu.addItem(new WatchUi.MenuItem("Yes", "Remove this timer", :confirm_yes, null));
        menu.addItem(new WatchUi.MenuItem("No", "Keep it", :confirm_no, null));
        WatchUi.pushView(menu, new PresetDeleteDelegate(index), WatchUi.SLIDE_UP);
    }
}

class PresetDeleteDelegate extends WatchUi.Menu2InputDelegate {

    private var _index;

    function initialize(index) {
        Menu2InputDelegate.initialize();
        _index = index;
    }

    function onSelect(item) {
        if (item.getId() == :confirm_yes) {
            removeTimerPresetAt(_index);
        }
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        PresetListMenu.replaceCurrent(null);
    }
}

// Reuses CustomPickerView (minute picker) to append a preset instead of
// starting a timer.
class PresetAddDelegate extends WatchUi.BehaviorDelegate {

    private var _view;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onPreviousPage() {
        _view.increment();
        return true;
    }

    function onNextPage() {
        _view.decrement();
        return true;
    }

    function onSelect() {
        var added = addTimerPreset(_view.getMinutes());
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        PresetListMenu.replaceCurrent(added ? null : "Already added");
        return true;
    }

    function onBack() {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }
}
