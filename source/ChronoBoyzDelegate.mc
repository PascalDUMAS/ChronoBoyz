import Toybox.WatchUi;
import Toybox.System;
import Toybox.Lang;

class ChronoBoyZDelegate extends WatchUi.BehaviorDelegate {

    private var _view as ChronoBoyZView;

    function initialize(view as ChronoBoyZView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    // Désactivation totale du tactile
    function onTap(evt as WatchUi.ClickEvent) as Boolean { return true; }
    function onHold(evt as WatchUi.ClickEvent) as Boolean { return true; }
    function onSwipe(evt as WatchUi.SwipeEvent) as Boolean { return true; }

    // Gestion des boutons physiques
    function onKey(keyEvent as WatchUi.KeyEvent) as Boolean {
        var key = keyEvent.getKey();
        
        // Bouton Start/Stop (Entrée)
        if (key == WatchUi.KEY_ENTER || key == WatchUi.KEY_START) {
            _view.toggleChrono();
            return true;
        }
        
        return false;
    }

    // Intercepte le bouton Retour (BACK) pour proposer l'enregistrement
    function onBack() as Boolean {
        if (_view.hasActiveSessionOrData()) {
            var menu = new WatchUi.Menu2({:title => "Fin de session"});
            menu.addItem(new WatchUi.MenuItem("Enregistrer et quitter", "Sauvegarder l'activite", "save_activity", {}));
            menu.addItem(new WatchUi.MenuItem("Quitter sans sauver", "Fermer l'appli", "quit_direct", {}));

            WatchUi.pushView(menu, new ChronoBoyZSaveMenuDelegate(_view), WatchUi.SLIDE_IMMEDIATE);
            return true;
        }
        return false; // Quitte directement si aucune donnée n'a été enregistrée
    }

    // Appui long (généralement associé au bouton UP/Menu sur les montres Garmin)
    function onMenu() as Boolean {
        if (!_view.isRunning()) {
            WatchUi.pushView(new ChronoBoyZMenu(), new ChronoBoyZMenuDelegate(_view), WatchUi.SLIDE_IMMEDIATE);
            return true;
        }
        return false; // Bloqué si le chrono est en cours
    }
}

// Délégué pour gérer les choix du menu de sauvegarde/quitter
class ChronoBoyZSaveMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _view as ChronoBoyZView;

    function initialize(view as ChronoBoyZView) {
        Menu2InputDelegate.initialize();
        _view = view;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id instanceof String) {
            if (id.equals("save_activity")) {
                _view.saveSession();
                System.exit();
            } else if (id.equals("discard_activity")) {
                _view.discardSession();
                System.exit();
            } else if (id.equals("quit_direct")) {
                // Nettoie et supprime la session active avant de fermer l'application
                _view.discardSession();
                System.exit();
            }
        }
    }
}
