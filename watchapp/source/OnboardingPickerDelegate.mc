import Toybox.WatchUi;
import Toybox.Lang;

class OnboardingPickerDelegate extends WatchUi.Menu2InputDelegate {

    private var _selected;

    function initialize(selectedProjects) {
        Menu2InputDelegate.initialize();
        _selected = normalizeProjectList(copyProjects(selectedProjects));
    }

    function onSelect(item) {
        var id = item.getId();

        if (id == :add_custom) {
            if (_selected.size() >= 5) {
                OnboardingPickerView.show(_selected, "Max 5 projects");
                return;
            }

            WatchUi.pushView(
                new WatchUi.TextPicker(""),
                new OnboardingCustomTextDelegate(_selected),
                WatchUi.SLIDE_UP
            );
            return;
        }

        if (id == :save_projects) {
            if (_selected.size() == 0) {
                OnboardingPickerView.show(_selected, "Pick at least 1");
                return;
            }

            saveProjects(_selected);
            markSetupDone();
            WatchUi.switchToView(new SetupDoneView(), new SetupDoneDelegate(), WatchUi.SLIDE_UP);
            return;
        }

        var presetIndex = id as Lang.Number;
        var presets = getGenericProjectOptions();
        if (presetIndex < 0 || presetIndex >= presets.size()) { return; }

        var updated = copyProjects(_selected);
        var presetName = presets[presetIndex];

        if (projectArrayContains(updated, presetName)) {
            var remaining = [];
            for (var i = 0; i < updated.size(); i++) {
                if (!updated[i].equals(presetName)) {
                    remaining.add(updated[i]);
                }
            }
            updated = remaining;
        } else if (updated.size() < 5) {
            updated.add(presetName);
        }

        OnboardingPickerView.show(updated, null);
    }

    function onBack() {
        WatchUi.switchToView(new WelcomeView(), new WelcomeDelegate(), WatchUi.SLIDE_DOWN);
    }
}

class OnboardingCustomTextDelegate extends WatchUi.TextPickerDelegate {

    private var _selected;

    function initialize(selectedProjects) {
        TextPickerDelegate.initialize();
        _selected = normalizeProjectList(copyProjects(selectedProjects));
    }

    function onTextEntered(text, changed) {
        var updated = copyProjects(_selected);
        var normalized = normalizeProjectName(text);

        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);

        if (normalized != null && updated.size() < 5 && !projectArrayContains(updated, normalized)) {
            updated.add(normalized);
        }

        OnboardingPickerView.show(updated, null);
        return true;
    }

    function onCancel() {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        OnboardingPickerView.show(_selected, null);
        return true;
    }
}
