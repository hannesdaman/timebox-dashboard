import Toybox.WatchUi;
import Toybox.Lang;

// Main menu built from the stored presets so the user can add/remove timers.
// Items rebuild on show only when the preset list changed, so focus position
// survives normal back-navigation.
class MainMenu extends WatchUi.Menu2 {

    private var _signature = "";

    function initialize() {
        Menu2.initialize({ :title => "TimeBox" });
        rebuild();
    }

    static function switchTo(transition) as Void {
        WatchUi.switchToView(new MainMenu(), new MainMenuDelegate(), transition);
    }

    function onShow() {
        Menu2.onShow();
        rebuild();
    }

    private function rebuild() as Void {
        var presets = getTimerPresets();

        var signature = "";
        for (var i = 0; i < presets.size(); i++) {
            signature += "" + presets[i] + "|";
        }
        if (signature.equals(_signature)) { return; }
        _signature = signature;

        while (getItem(0) != null) {
            deleteItem(0);
        }

        for (var i = 0; i < presets.size(); i++) {
            addItem(new WatchUi.MenuItem("" + presets[i] + " min", null, presets[i], null));
        }
        addItem(new WatchUi.MenuItem("Custom", "Pick any duration", :custom_timer, null));

        var testItem = debugPresetMenuItem();
        if (testItem != null) {
            addItem(testItem);
        }

        addItem(new WatchUi.MenuItem("Stats", null, :stats, null));
        addItem(new WatchUi.MenuItem("Settings", "Vibration & timers", :settings, null));
    }
}

// Short test timer for exercising completion quickly; the (:debug) variant is
// stripped from release builds, so sideload the release .prg for daily use.
(:debug)
function debugPresetMenuItem() {
    return new WatchUi.MenuItem("15 sec", "Debug builds only", :debug_preset, null);
}

(:release)
function debugPresetMenuItem() {
    return null;
}

class MainMenuDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item) {
        var id = item.getId();

        if (id == :custom_timer) {
            var picker = new CustomPickerView();
            WatchUi.pushView(picker, new CustomPickerDelegate(picker), WatchUi.SLIDE_UP);
            return;
        }
        if (id == :stats) {
            var stats = new StatsView();
            WatchUi.pushView(stats, new StatsDelegate(stats), WatchUi.SLIDE_UP);
            return;
        }
        if (id == :settings) {
            SettingsMenu.push();
            return;
        }
        if (id == :debug_preset) {
            showProjectSelectionMenu(15, "15 sec", false);
            return;
        }

        if (id instanceof Lang.Number) {
            var minutes = id as Lang.Number;
            showProjectSelectionMenu(minutes * 60, "" + minutes + " min", false);
        }
    }
}
