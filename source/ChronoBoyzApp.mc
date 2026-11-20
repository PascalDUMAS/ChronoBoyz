import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.System;

class ChronoBoyZApp extends Application.AppBase {

    private var _mainView as ChronoBoyZView? = null;

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
    }

    function onStop(state as Dictionary?) as Void {
        var view = _mainView;
        if (view != null) {
            try {
                view.cleanup();
            } catch (ex) { System.println("ChronoBoyZ ERR [ChronoBoyzApp.onStop]: " + ex.getErrorMessage()); ex.printStackTrace();
            }
        }
        _mainView = null;
    }

    function getInitialView() {
       
       
        var initialMs = 100000; // Valeur de repli sécurisée obligatoire
        
        try {
            var savedDuration = Application.Storage.getValue("countdownDuration");
            // Test anti-null et anti-mauvais type
            if (savedDuration != null && savedDuration instanceof Number) {
                initialMs = savedDuration;
            }
        } catch (ex) { System.println("ChronoBoyZ ERR [ChronoBoyzApp.getInitialView]: " + ex.getErrorMessage()); ex.printStackTrace();
            initialMs = 100000;
        }

        var view = new ChronoBoyZView(initialMs);
        _mainView = view;
        var delegate = new ChronoBoyZDelegate(view);
        return [view, delegate];
    }
    
}
