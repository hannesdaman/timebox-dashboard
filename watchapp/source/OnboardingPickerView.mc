import Toybox.WatchUi;
import Toybox.Lang;

class OnboardingPickerView {

    static function show(selectedProjects, message) {
        var selected = normalizeProjectList(copyProjects(selectedProjects));
        gOnboardingSelected = selected;

        var title = "Pick projects (" + selected.size() + "/5)";
        if (message != null) {
            title = message;
        }

        var menu = new WatchUi.Menu2({ :title => title });
        var presets = getGenericProjectOptions();

        for (var i = 0; i < presets.size(); i++) {
            var name = presets[i];
            var label = "[ ] " + name;
            var hint = "Tap to add";

            if (projectArrayContains(selected, name)) {
                label = "[x] " + name;
                hint = "Tap to remove";
            }

            menu.addItem(new WatchUi.MenuItem(label, hint, i, null));
        }

        // Show custom projects (not in presets) so the user can see them
        for (var i = 0; i < selected.size(); i++) {
            if (!projectArrayContains(presets, selected[i])) {
                menu.addItem(new WatchUi.MenuItem("[x] " + selected[i], "Tap to remove", selected[i], null));
            }
        }

        if (selected.size() < 5) {
            menu.addItem(new WatchUi.MenuItem("Add custom", "Type your own name", :add_custom, null));
        } else {
            menu.addItem(new WatchUi.MenuItem("Add custom", "Max 5 projects reached", :add_custom, null));
        }

        var saveHint = "Pick at least 1 project";
        if (selected.size() > 0) {
            saveHint = "Save " + selected.size() + " project(s)";
        }

        menu.addItem(new WatchUi.MenuItem("Save projects", saveHint, :save_projects, null));
        WatchUi.switchToView(menu, new OnboardingPickerDelegate(selected), WatchUi.SLIDE_UP);
    }
}
