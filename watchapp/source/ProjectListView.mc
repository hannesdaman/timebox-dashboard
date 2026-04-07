import Toybox.WatchUi;

class ProjectListView {

    static function show(durationSeconds, label) {
        var menu = buildMenu();
        WatchUi.pushView(menu, new ProjectListDelegate(durationSeconds, label), WatchUi.SLIDE_UP);
    }

    static function replace(durationSeconds, label) {
        var menu = buildMenu();
        WatchUi.switchToView(menu, new ProjectListDelegate(durationSeconds, label), WatchUi.SLIDE_IMMEDIATE);
    }

    static function buildMenu() {
        var menu = new WatchUi.Menu2({ :title => "Projects" });
        var projects = getProjects();

        for (var i = 0; i < projects.size(); i++) {
            menu.addItem(new WatchUi.MenuItem(projects[i], "Rename or delete", i, null));
        }

        if (projects.size() < 5) {
            menu.addItem(new WatchUi.MenuItem("+ Add project", "Choose or type a name", :add_project, null));
        }

        return menu;
    }
}
