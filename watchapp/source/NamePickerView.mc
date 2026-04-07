import Toybox.WatchUi;

class NamePickerView {

    static function showForAdd(durationSeconds, label) {
        show(:add_project, -1, null, durationSeconds, label);
    }

    static function showForRename(index, currentName, durationSeconds, label) {
        show(:rename_project, index, currentName, durationSeconds, label);
    }

    static function show(mode, index, currentName, durationSeconds, label) {
        var title = "Add project";
        if (mode == :rename_project) {
            title = "Rename project";
        }

        var menu = new WatchUi.Menu2({ :title => title });
        var presets = getGenericProjectOptions();

        for (var i = 0; i < presets.size(); i++) {
            var hint = "Use this name";
            if (currentName != null && presets[i].equals(currentName)) {
                hint = "Current name";
            }
            menu.addItem(new WatchUi.MenuItem(presets[i], hint, i, null));
        }

        menu.addItem(new WatchUi.MenuItem("Add custom", "Type your own name", :custom_name, null));
        WatchUi.pushView(
            menu,
            new NamePickerDelegate(mode, index, currentName, durationSeconds, label),
            WatchUi.SLIDE_UP
        );
    }
}
