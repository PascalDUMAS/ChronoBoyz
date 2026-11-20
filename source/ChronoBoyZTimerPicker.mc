import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.System;
import Toybox.Application; // Ajouté pour accéder au stockage

class ChronoBoyZTimerPicker extends WatchUi.View {

    private var _view as ChronoBoyZView;
    private var _minutes as Number = 1;
    private var _seconds as Number = 40;
    private var _isEditingMinutes as Boolean = true;

    private var _minLeft as Number = 0;
    private var _minRight as Number = 0;
    private var _secLeft as Number = 0;
    private var _secRight as Number = 0;
    private var _posY as Number = 0;
    private var _rowHeight as Number = 90;

    function initialize(view as ChronoBoyZView) {
        View.initialize();
        _view = view;

        // Récupération de la dernière valeur configurée pour initialiser l'affichage du picker
        try {
            var savedDuration = Application.Storage.getValue("countdownDuration");
            if (savedDuration != null && savedDuration instanceof Number) {
                var totalSecs = savedDuration / 1000;
                _minutes = totalSecs / 60;
                _seconds = totalSecs % 60;
            }
        } catch (ex) { System.println("ChronoBoyZ ERR [ChronoBoyZTimerPicker.initialize]: " + ex.getErrorMessage()); ex.printStackTrace();
            // Utilise les valeurs par défaut (1:40) en cas d'erreur
        }
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        if (dc == null) { return; }

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var screenWidth = dc.getWidth();
        var screenHeight = dc.getHeight();

        // 1. Titre
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            screenWidth / 2, 
            (screenHeight * 0.08).toNumber(), 
            Graphics.FONT_SMALL, 
            "REGLER TIMER", 
            Graphics.TEXT_JUSTIFY_CENTER
        );

        // 2. Affichage Minutes / Secondes
        var minStr = _minutes.format("%02d");
        var secStr = _seconds.format("%02d");
        var separatorStr = ":";

        var font = Graphics.FONT_LARGE; 
        var minWidth = 40;
        var colonWidth = 20;
        var secWidth = 40;
        
        if (dc has :getTextWidthInPixels) {
            try {
                minWidth = dc.getTextWidthInPixels(minStr, font);
                colonWidth = dc.getTextWidthInPixels(separatorStr, font);
                secWidth = dc.getTextWidthInPixels(secStr, font);
            } catch (ex) { System.println("ChronoBoyZ ERR [ChronoBoyZTimerPicker.onUpdate]: " + ex.getErrorMessage()); ex.printStackTrace();
                minWidth = 40;
                colonWidth = 20;
                secWidth = 40;
            }
        }

        var totalWidth = minWidth + colonWidth + secWidth;
        var startX = (screenWidth - totalWidth) / 2;
        var posY = (screenHeight * 0.30).toNumber();

        _minLeft = startX;
        _minRight = startX + minWidth;
        _secLeft = startX + minWidth + colonWidth;
        _secRight = _secLeft + secWidth;
        _posY = posY;

        // --- Minutes ---
        if (_isEditingMinutes) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        } else {
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        }
        dc.drawText(startX, posY, font, minStr, Graphics.TEXT_JUSTIFY_LEFT);

        // --- Séparateur ---
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(startX + minWidth, posY, font, separatorStr, Graphics.TEXT_JUSTIFY_LEFT);

        // --- Secondes ---
        if (!_isEditingMinutes) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        } else {
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        }
        dc.drawText(startX + minWidth + colonWidth, posY, font, secStr, Graphics.TEXT_JUSTIFY_LEFT);

        // 3. Guide visuel des gestes tactiles
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        var activeFieldText = _isEditingMinutes ? "Up/Down:+/- Min" : "UP/Down:+/- Sec";
        dc.drawText(
            screenWidth / 2, 
            (screenHeight * 0.62).toNumber(), 
            Graphics.FONT_XTINY, 
            activeFieldText, 
            Graphics.TEXT_JUSTIFY_CENTER
        );

        dc.drawText(
            screenWidth / 2, 
            (screenHeight * 0.86).toNumber(), 
            Graphics.FONT_XTINY, 
            "Start", 
            Graphics.TEXT_JUSTIFY_CENTER
        );
    }
    
    public function increment() as Void {
        if (_isEditingMinutes) {
            _minutes = (_minutes + 1) % 100;
        } else {
            _seconds = (_seconds + 1) % 60;
        }
        WatchUi.requestUpdate();
    }

    public function decrement() as Void {
        if (_isEditingMinutes) {
            _minutes = (_minutes - 1 + 100) % 100;
        } else {
            _seconds = (_seconds - 1 + 60) % 60;
        }
        WatchUi.requestUpdate();
    }

    public function nextStep() as Boolean {
        if (_isEditingMinutes) {
            _isEditingMinutes = false; 
            WatchUi.requestUpdate();
            return false; 
        } else {
            var totalMs = ((_minutes * 60) + _seconds) * 1000;
            if (totalMs > 0 && _view != null) {
                _view.setCountdownDuration(totalMs);
            }
            return true; 
        }
    }

    public function handleTap(x as Number, y as Number) as Boolean {
        if ((y >= _posY) && (y <= (_posY + _rowHeight))) {
            if ((x >= _minLeft) && (x <= _minRight)) {
                _isEditingMinutes = true;
                WatchUi.requestUpdate();
                return true;
            } else if ((x >= _secLeft) && (x <= _secRight)) {
                _isEditingMinutes = false;
                WatchUi.requestUpdate();
                return true;
            }
        }
        return nextStep();
    }

    public function handleSwipe(direction as WatchUi.SwipeDirection) as Boolean {
        if (direction == WatchUi.SWIPE_UP) {
            increment();
            return true;
        } else if (direction == WatchUi.SWIPE_DOWN) {
            decrement();
            return true;
        } else if (direction == WatchUi.SWIPE_LEFT || direction == WatchUi.SWIPE_RIGHT) {
            _isEditingMinutes = !_isEditingMinutes;
            WatchUi.requestUpdate();
            return true;
        }
        return false;
    }
}

class ChronoBoyZTimerPickerDelegate extends WatchUi.BehaviorDelegate {
    private var _pickerView as ChronoBoyZTimerPicker;

    function initialize(pickerView as ChronoBoyZTimerPicker) {
        BehaviorDelegate.initialize();
        _pickerView = pickerView;
    }

    function onKey(keyEvent as WatchUi.KeyEvent) as Boolean {
        var key = keyEvent.getKey();

        if (key == WatchUi.KEY_ENTER || key == WatchUi.KEY_START) {
            var finished = _pickerView.nextStep();
            if (finished) {
                WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            }
            return true;
        }

        if (key == WatchUi.KEY_UP || key == WatchUi.KEY_LAP) {
            _pickerView.increment();
            return true;
        }

        if (key == WatchUi.KEY_DOWN) {
            _pickerView.decrement();
            return true;
        }

        return false;
    }

    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        var coords = evt.getCoordinates();
        if (coords != null && coords.size() >= 2) {
            var finished = _pickerView.handleTap(coords[0], coords[1]);
            if (finished) {
                WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            }
            return true;
        }
        return false;
    }

    function onHold(evt as WatchUi.ClickEvent) as Boolean { 
        return false; 
    }

    function onSwipe(evt as WatchUi.SwipeEvent) as Boolean {
        return _pickerView.handleSwipe(evt.getDirection());
    }
}
