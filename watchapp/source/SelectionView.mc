import Toybox.Graphics;
import Toybox.WatchUi;

class SelectionView extends WatchUi.View {

    var _text;

    function initialize(text) {
        WatchUi.View.initialize();
        _text = text;
    }
    
    function onUpdate(dc as Graphics.Dc) as Void {
        dc.clear();

        var w = dc.getWidth();
        var h = dc.getHeight();

        dc.drawText(
            w / 2,
            h / 2,
            Graphics.FONT_XTINY,
            _text,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }
}

