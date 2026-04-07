import Toybox.WatchUi;
import Toybox.Graphics;

class WelcomeView extends WatchUi.View {

    function initialize() {
        View.initialize();
    }

    function onUpdate(dc) {
        dc.clear();

        var w = dc.getWidth();
        var h = dc.getHeight();

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);

        dc.drawText(
            w / 2, (h * 0.16).toNumber(),
            Graphics.FONT_XTINY, "Welcome to",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );

        dc.drawText(
            w / 2, (h * 0.27).toNumber(),
            Graphics.FONT_TINY, "TimeBox",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );

        dc.drawText(
            w / 2, (h * 0.41).toNumber(),
            Graphics.FONT_XTINY, "Created by HZ, Apr -26 :)",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );

        dc.drawText(
            w / 2, (h * 0.56).toNumber(),
            Graphics.FONT_XTINY, "Next step: add your projects",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);

        dc.drawText(
            w / 2, (h * 0.82).toNumber(),
            Graphics.FONT_XTINY, "START to continue",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }
}

class WelcomeDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onSelect() {
        OnboardingPickerView.show([], null);
        return true;
    }

    function onBack() {
        return true;
    }
}

class SetupDoneView extends WatchUi.View {

    function initialize() {
        View.initialize();
    }

    function onUpdate(dc) {
        dc.clear();

        var w = dc.getWidth();
        var h = dc.getHeight();

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);

        dc.drawText(
            w / 2, (h * 0.22).toNumber(),
            Graphics.FONT_SMALL, "Projects saved!",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );

        dc.drawText(
            w / 2, (h * 0.42).toNumber(),
            Graphics.FONT_XTINY, "You are ready to focus.",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );

        dc.drawText(
            w / 2, (h * 0.54).toNumber(),
            Graphics.FONT_XTINY, "You can edit them later.",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );

        dc.drawText(
            w / 2, (h * 0.66).toNumber(),
            Graphics.FONT_XTINY, "Use EDIT PROJECTS anytime.",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);

        dc.drawText(
            w / 2, (h * 0.84).toNumber(),
            Graphics.FONT_XTINY, "START to continue",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }
}

class SetupDoneDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onSelect() {
        WatchUi.switchToView(new Rez.Menus.MainMenu(), new watchappMenuDelegate(), WatchUi.SLIDE_UP);
        return true;
    }

    function onBack() {
        WatchUi.switchToView(new Rez.Menus.MainMenu(), new watchappMenuDelegate(), WatchUi.SLIDE_UP);
        return true;
    }
}
