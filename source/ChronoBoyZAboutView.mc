import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;

class ChronoBoyZAboutView extends WatchUi.View {

    function initialize() {
        View.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        if (dc == null) { return; }

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var screenWidth = dc.getWidth();
        var screenHeight = dc.getHeight();
        var centerX = screenWidth / 2;

        // 1. Titre
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            centerX, 
            (screenHeight * 0.12).toNumber(), 
            Graphics.FONT_MEDIUM, 
            "A PROPOS", 
            Graphics.TEXT_JUSTIFY_CENTER
        );

        // 2. Nom de l'application
        dc.drawText(
            centerX, 
            (screenHeight * 0.35).toNumber(), 
            Graphics.FONT_SMALL, 
            "ChronoBoyZ", 
            Graphics.TEXT_JUSTIFY_CENTER
        );

        // 3. Génération dynamique de la version basée sur la date et l'heure actuelles
        var versionString = "v26.11.20-1219";
        // Vous mettez à jour cette ligne manuellement lors de vos sessions de dev/build

        

        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            centerX, 
            (screenHeight * 0.50).toNumber(), 
            Graphics.FONT_XTINY, 
            versionString, 
            Graphics.TEXT_JUSTIFY_CENTER
        );

        // 4. Instructions pour quitter
        dc.drawText(
            centerX, 
            (screenHeight * 0.80).toNumber(), 
            Graphics.FONT_XTINY, 
            "Appuyer sur Back", 
            Graphics.TEXT_JUSTIFY_CENTER
        );
    }
}

class ChronoBoyZAboutDelegate extends WatchUi.BehaviorDelegate {
    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        return true;
    }

    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        return true;
    }
}
