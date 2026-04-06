import Toybox.WatchUi;

class watchappMenuDelegate extends WatchUi.MenuInputDelegate {

    function initialize() {
        MenuInputDelegate.initialize();
    }

    function onMenuItem(item) {
        if (item == :item_1) {
            pushTagMenu(25 * 60, "25 min");
        } else if (item == :item_2) {
            pushTagMenu(50 * 60, "50 min");
        } else if (item == :item_3) {
            pushTagMenu(90 * 60, "90 min");
        } else if (item == :item_4) {
            var picker = new CustomPickerView();
            WatchUi.pushView(picker, new CustomPickerDelegate(picker), WatchUi.SLIDE_UP);
        } else if (item == :item_5) {
            var stats = new StatsView();
            WatchUi.pushView(stats, new StatsDelegate(stats), WatchUi.SLIDE_UP);
        }
    }

    private function pushTagMenu(durationSeconds, label) {
        var projects = getProjects();
        var menu = new WatchUi.Menu2({:title => "Project"});
        for (var i = 0; i < projects.size(); i++) {
            menu.addItem(new WatchUi.MenuItem(projects[i], null, i, null));
        }
        WatchUi.pushView(menu, new TagMenuDelegate(durationSeconds, label, projects), WatchUi.SLIDE_UP);
    }
}
