import Toybox.WatchUi;
import Toybox.Graphics;

class CustomPickerView extends WatchUi.View {

    private var _minutes = 25;

    function initialize() {
        View.initialize();
    }

    function getMinutes() {
        return _minutes;
    }

    function increment() {
        if (_minutes < 120) {
            _minutes += 5;
            WatchUi.requestUpdate();
        }
    }

    function decrement() {
        if (_minutes > 5) {
            _minutes -= 5;
            WatchUi.requestUpdate();
        }
    }

    function onUpdate(dc) {
        dc.clear();

        var w = dc.getWidth();
        var h = dc.getHeight();

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);

        dc.drawText(
            w / 2, (h * 0.20).toNumber(),
            Graphics.FONT_SMALL, "Set Minutes",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );

        dc.drawText(
            w / 2, (h * 0.48).toNumber(),
            Graphics.FONT_NUMBER_HOT, "" + _minutes,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );

        dc.drawText(
            w / 2, (h * 0.75).toNumber(),
            Graphics.FONT_XTINY, "UP +5 / DOWN -5",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );

        dc.drawText(
            w / 2, (h * 0.85).toNumber(),
            Graphics.FONT_XTINY, "START to begin",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }
}
