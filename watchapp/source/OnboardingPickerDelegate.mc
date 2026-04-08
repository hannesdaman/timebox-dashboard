import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.Timer;

// Shared onboarding selection state — survives even if switchToView
// fails during TextPicker auto-dismiss animation on real hardware.
var gOnboardingSelected = [] as Lang.Array;

class OnboardingPickerDelegate extends WatchUi.Menu2InputDelegate {

    function initialize(selectedProjects) {
        Menu2InputDelegate.initialize();
        gOnboardingSelected = normalizeProjectList(copyProjects(selectedProjects));
    }

    function onSelect(item) {
        var id = item.getId();

        if (id == :add_custom) {
            if (gOnboardingSelected.size() >= 5) {
                OnboardingPickerView.show(gOnboardingSelected, "Max 5 projects");
                return;
            }

            WatchUi.pushView(
                new WatchUi.TextPicker(""),
                new OnboardingCustomTextDelegate(),
                WatchUi.SLIDE_UP
            );
            return;
        }

        if (id == :save_projects) {
            if (gOnboardingSelected.size() == 0) {
                OnboardingPickerView.show(gOnboardingSelected, "Pick at least 1");
                return;
            }

            saveProjects(gOnboardingSelected);
            markSetupDone();
            WatchUi.switchToView(new SetupDoneView(), new SetupDoneDelegate(), WatchUi.SLIDE_UP);
            return;
        }

        // Custom project tap — id is a String
        if (id instanceof Lang.String) {
            var remaining = [];
            for (var i = 0; i < gOnboardingSelected.size(); i++) {
                if (!gOnboardingSelected[i].equals(id)) {
                    remaining.add(gOnboardingSelected[i]);
                }
            }
            gOnboardingSelected = remaining;
            OnboardingPickerView.show(gOnboardingSelected, null);
            return;
        }

        // Preset toggle
        var presetIndex = id as Lang.Number;
        var presets = getGenericProjectOptions();
        if (presetIndex < 0 || presetIndex >= presets.size()) { return; }

        var updated = copyProjects(gOnboardingSelected);
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

    // Timer must be stored as instance var to prevent GC before it fires
    private var _refreshTimer;

    function initialize() {
        TextPickerDelegate.initialize();
    }

    function onTextEntered(text, changed) {
        var normalized = normalizeProjectName(text);

        if (normalized != null && gOnboardingSelected.size() < 5 && !projectArrayContains(gOnboardingSelected, normalized)) {
            gOnboardingSelected.add(normalized);
        }

        // Defer view switch so TextPicker auto-dismiss animation completes first
        _refreshTimer = new Timer.Timer();
        _refreshTimer.start(method(:refreshOnboarding), 300, false);
        return true;
    }

    function onCancel() {
        _refreshTimer = new Timer.Timer();
        _refreshTimer.start(method(:refreshOnboarding), 300, false);
        return true;
    }

    function refreshOnboarding() as Void {
        OnboardingPickerView.show(gOnboardingSelected, null);
    }
}
