import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.System;

class ChronoBoyZMenu extends WatchUi.Menu2 {
    function initialize() {
        Menu2.initialize({:title => "Options"});
        addItem(new WatchUi.MenuItem("Reset Total", "Remet chrono & timer à 0", "reset_all", {}));
        addItem(new WatchUi.MenuItem("Regler Timer", "Choisir minutes/secondes", "config_timer", {}));
        addItem(new WatchUi.MenuItem("A propos", "Version de l'appli", "about_app", {})); // <--- Ajout ici
    }
}

class ChronoBoyZMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _view as ChronoBoyZView;

    function initialize(view as ChronoBoyZView) {
        Menu2InputDelegate.initialize();
        _view = view;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id instanceof String) {
            if (id.equals("reset_all")) {
                _view.resetAll();
                WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            } else if (id.equals("config_timer")) {
                WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
                var pickerView = new ChronoBoyZTimerPicker(_view);
                var pickerDelegate = new ChronoBoyZTimerPickerDelegate(pickerView);
                WatchUi.pushView(pickerView, pickerDelegate, WatchUi.SLIDE_IMMEDIATE);
            } else if (id.equals("about_app")) {
                // Ouvre l'écran "À propos"
                WatchUi.pushView(new ChronoBoyZAboutView(), new ChronoBoyZAboutDelegate(), WatchUi.SLIDE_IMMEDIATE);
            }
        }
    }
}
