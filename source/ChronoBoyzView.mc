import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Math;
import Toybox.Lang;
import Toybox.System;
import Toybox.Application;
import Toybox.Activity;
import Toybox.ActivityRecording;
import Toybox.Attention;
import Toybox.SensorLogging;
import Toybox.Timer;

class ChronoBoyZView extends WatchUi.View {

    private var _initialCountdownMs as Number = 100000;
    private var _accumulatedElapsedMs as Number = 0;
    private var _startTime as Number = 0;
    private var _isRunning as Boolean = false;
    private var _session as ActivityRecording.Session? = null;
    private var _lastCycleIndex as Number = 0;
    private var _halfwayVibedCycle as Number = -1; // Suivi pour la vibration de la moitié
    private var _wakeTimer as Timer.Timer? = null; // Timer unique de rafraîchissement de l'écran (100 ms en marche, 1 s à l'arrêt)
    private var _vibeTimer as Timer.Timer? = null;
    private var _pendingVibes as Number = 0;
    private var _chronoEverStarted as Boolean = false;

    // Cache de la fréquence cardiaque (Activity.getActivityInfo() crée un objet à chaque appel)
    private var _hrString as String = "-- bpm";
    private var _lastHrMs as Number = 0;
    private var _hrInitialized as Boolean = false;

    function initialize(initialCountdownMs as Number) {
        View.initialize();

        _initialCountdownMs = initialCountdownMs;
        try {
            var savedDuration = Application.Storage.getValue("countdownDuration");
            if (savedDuration != null && savedDuration instanceof Number) {
                _initialCountdownMs = savedDuration as Number;
            }
        } catch (ex) { System.println("ChronoBoyZ ERR [ChronoBoyzView.initialize]: " + ex.getErrorMessage()); ex.printStackTrace();
            _initialCountdownMs = initialCountdownMs;
        }

        // Garde-fou : une durée nulle provoquerait une division par zéro dans onUpdate
        if (_initialCountdownMs <= 0) {
            _initialCountdownMs = 100000;
        }

        logMem("startup");
    }

    // Crée une session uniquement au premier Start (ou si la création précédente a échoué).
    private function createRecordingSession() as Void {
        var existingSession = _session;
        if (existingSession != null) { return; }

        try {
            var logger = new SensorLogging.SensorLogger({
                :accelerometer => {:enabled => true},
                :magnetometer => {:enabled => true},
                :gyroscope => {:enabled => true}
            });

            var s = ActivityRecording.createSession({
                :name => "ChronoBoyZ",
                :sport => Activity.SPORT_GENERIC,
                :sensorLogger => logger
            });
            _session = s;
            s.start();
        } catch (ex) { System.println("ChronoBoyZ ERR [ChronoBoyzView.createRecordingSession]: " + ex.getErrorMessage()); ex.printStackTrace();
            if (_session != null) {
                try { _session.discard(); } catch (cleanupEx) { System.println("ChronoBoyZ ERR [ChronoBoyzView.createRecordingSession.cleanup]: " + cleanupEx.getErrorMessage()); cleanupEx.printStackTrace(); }
            }
            _session = null;
        }
    }

    private function logMem(tag as String) as Void {
        try {
            var stats = System.getSystemStats();
            System.println("MEM [" + tag + "] used=" + stats.usedMemory.toString() +
                " free=" + stats.freeMemory.toString() + " total=" + stats.totalMemory.toString());
        } catch (ex) { System.println("ChronoBoyZ ERR [ChronoBoyzView.logMem]: " + ex.getErrorMessage()); ex.printStackTrace();
        }
    }

    // --- Timer de rafraîchissement (remplace le requestUpdate() en boucle dans onUpdate) ---
    private function startRefreshTimer() as Void {
        var t = _wakeTimer;
        if (t == null) {
            t = new Timer.Timer();
            _wakeTimer = t;
        }

        var period = 1000; // à l'arrêt : horloge et fréquence cardiaque, 1 fois par seconde
        if (_isRunning) {
            period = 100;  // en marche : centièmes affichés, 10 rafraîchissements par seconde
        }

        try {
            t.stop();
            t.start(method(:onWakeTimer), period, true);
        } catch (ex) { System.println("ChronoBoyZ ERR [ChronoBoyzView.startRefreshTimer]: " + ex.getErrorMessage()); ex.printStackTrace();
            // Le callback suivant pourra recréer/reprendre le rafraîchissement.
        }
    }

    private function stopRefreshTimer() as Void {
        var t = _wakeTimer;
        if (t != null) {
            try { t.stop(); } catch (ex) { System.println("ChronoBoyZ ERR [ChronoBoyzView.stopRefreshTimer]: " + ex.getErrorMessage()); ex.printStackTrace(); }
        }
    }

    public function onShow() as Void {
        startRefreshTimer();
    }

    public function onHide() as Void {
        try {
            stopRefreshTimer();
        } catch (ex) { System.println("ChronoBoyZ ERR [ChronoBoyzView.onHide]: " + ex.getErrorMessage()); ex.printStackTrace();
            // Le masquage de l’écran ne doit pas échouer sur un timer déjà arrêté.
        }
        try {
            var vt = _vibeTimer;
            if (vt != null) { vt.stop(); }
            _pendingVibes = 0;
        } catch (ex) { System.println("ChronoBoyZ ERR [ChronoBoyzView.onHide]: " + ex.getErrorMessage()); ex.printStackTrace();
            // Arrêt best-effort du timer de vibrations.
        }
    }

    public function onWakeTimer() as Void {
        try {
        WatchUi.requestUpdate();
    
        } catch (ex) { System.println("ChronoBoyZ ERR [ChronoBoyzView.onWakeTimer]: " + ex.getErrorMessage()); ex.printStackTrace();
            // Évite qu’une erreur ponctuelle interrompe le callback.
        }
    }

    public function setCountdownDuration(durationMs as Number) as Void {
        if (durationMs <= 0) { return; }

        _initialCountdownMs = durationMs;
        _accumulatedElapsedMs = 0;
        _startTime = System.getTimer();
        _isRunning = false;
        _lastCycleIndex = 0;
        _halfwayVibedCycle = -1;
        
        try {
            Application.Storage.setValue("countdownDuration", durationMs);
        } catch (ex) { System.println("ChronoBoyZ ERR [ChronoBoyzView.setCountdownDuration]: " + ex.getErrorMessage()); ex.printStackTrace();}
        
        WatchUi.requestUpdate();
    }

    public function toggleChrono() as Void {
        var now = System.getTimer();
        if (_isRunning) {
            _accumulatedElapsedMs += (now - _startTime);
            _isRunning = false;

            var sStop = _session;
            if (sStop != null) {
                try {
                    if (sStop.isRecording()) { sStop.stop(); }
                } catch (ex) { System.println("ChronoBoyZ ERR [ChronoBoyzView.toggleChrono]: " + ex.getErrorMessage()); ex.printStackTrace(); }
            }
            logMem("stop");
        } else {
            _startTime = now;
            _chronoEverStarted = true;

            // Démarrer/enclencher le logger uniquement au premier Start.
            if (_session == null) { createRecordingSession(); }
            var sStart = _session;
            if (sStart != null) {
                try {
                    if (!sStart.isRecording()) { sStart.start(); }
                } catch (ex) { System.println("ChronoBoyZ ERR [ChronoBoyzView.toggleChrono]: " + ex.getErrorMessage()); ex.printStackTrace();
                    // La session d’enregistrement est facultative pour le chronomètre.
                }
            }
            _isRunning = true;
            logMem("start");
        }

        startRefreshTimer(); // ajuste la cadence (100 ms en marche / 1 s à l'arrêt)
        WatchUi.requestUpdate();
    }

    public function resetAll() as Void {
        _accumulatedElapsedMs = 0;
        _startTime = System.getTimer();
        _isRunning = false;
        _lastCycleIndex = 0;
        _halfwayVibedCycle = -1;
        _chronoEverStarted = false;

        var s = _session;
        if (s != null) {
            try {
                if (s.isRecording()) { s.stop(); }
            } catch (ex) { System.println("ChronoBoyZ ERR [ChronoBoyzView.resetAll]: " + ex.getErrorMessage()); ex.printStackTrace(); }
            try { s.discard(); } catch (ex) { System.println("ChronoBoyZ ERR [ChronoBoyzView.resetAll]: " + ex.getErrorMessage()); ex.printStackTrace(); }
        }
        _session = null;
        var vt = _vibeTimer;
        if (vt != null) {
            try { vt.stop(); } catch (ex) { System.println("ChronoBoyZ ERR [ChronoBoyzView.resetAll]: " + ex.getErrorMessage()); ex.printStackTrace(); }
        }
        _pendingVibes = 0;

        // Le reset invalide toute activité en cours ; la prochaine session sera créée au Start.
        logMem("reset");
        WatchUi.requestUpdate();
    }

    public function isRunning() as Boolean {
        return _isRunning;
    }

    // Méthode de vibration paramétrisée (nombre de répétitions)
    private function triggerVibration(count as Number) as Void {
        if (!(Attention has :vibrate)) { return; }

        // 4 répétitions maximum par appel (8 profils max pour Attention.vibrate)
        var now = count;
        var rest = 0;
        if (count > 4) {
            now = 4;
            rest = count - 4;
        }

        var vibeProfile = [] as Array<Attention.VibeProfile>;
        for (var i = 0; i < now; i++) {
            vibeProfile.add(new Attention.VibeProfile(100, 300));
            vibeProfile.add(new Attention.VibeProfile(0, 100));
        }
        try {
            Attention.vibrate(vibeProfile);
        } catch (ex) { System.println("ChronoBoyZ ERR [ChronoBoyzView.triggerVibration]: " + ex.getErrorMessage()); ex.printStackTrace();
        }

        // S'il en reste, on les joue après la fin de cette série
        if (rest > 0) {
            _pendingVibes = rest;
            var vt = _vibeTimer;
            if (vt == null) {
                vt = new Timer.Timer();
                _vibeTimer = vt;
            }
            try {
                vt.stop();
                // durée de la série (now x 400 ms) + petite pause de 200 ms
                vt.start(method(:onPendingVibration), now * 400 + 200, false);
            } catch (ex) { System.println("ChronoBoyZ ERR [ChronoBoyzView.triggerVibration]: " + ex.getErrorMessage()); ex.printStackTrace();
                _pendingVibes = 0;
            }
        }
    }

    public function onPendingVibration() as Void {
        try {
        var n = _pendingVibes;
        _pendingVibes = 0;
        if (n > 0) {
            triggerVibration(n);
        }
    
        } catch (ex) { System.println("ChronoBoyZ ERR [ChronoBoyzView.onPendingVibration]: " + ex.getErrorMessage()); ex.printStackTrace();
            // Évite qu’une erreur ponctuelle interrompe le callback.
        }
    }

    private function formatLoopingCountdown(currentElapsed as Number) as String {
        var elapsedInCycle = currentElapsed % _initialCountdownMs;
        var remainingMs = _initialCountdownMs - elapsedInCycle;
        if (remainingMs < 0) { remainingMs = 0; }
        
        var totalSecs = remainingMs / 1000;
        var mins = totalSecs / 60;
        var secs = totalSecs % 60;
        
        return mins.format("%02d") + ":" + secs.format("%02d");
    }

    private function formatTotalChrono(currentElapsed as Number) as String {
        var totalSecs = currentElapsed / 1000;
        var mins = (totalSecs / 60) % 60;
        var secs = totalSecs % 60;
        var centis = (currentElapsed % 1000) / 10;
        var hours = totalSecs / 3600;

        if (hours > 0) {
            return hours.format("%d") + ":" + mins.format("%02d") + ":" + secs.format("%02d");
        }
        return mins.format("%02d") + ":" + secs.format("%02d") + "." + centis.format("%02d");
    }

    public function hasActiveSessionOrData() as Boolean {
        var s = _session;
        return (s != null || _accumulatedElapsedMs > 0);
    }

    public function saveSession() as Void {
        stopTimersForCleanup();
        var s = _session;
        if (s != null) {
            try {
                if (s.isRecording()) { s.stop(); }
            } catch (ex) { System.println("ChronoBoyZ ERR [ChronoBoyzView.saveSession]: " + ex.getErrorMessage()); ex.printStackTrace(); }
            try { s.save(); } catch (ex) { System.println("ChronoBoyZ ERR [ChronoBoyzView.saveSession]: " + ex.getErrorMessage()); ex.printStackTrace(); }
        }
        _session = null;
        _chronoEverStarted = false;
        resetAllDataOnly();
    }

    public function discardSession() as Void {
        stopTimersForCleanup();
        var s = _session;
        if (s != null) {
            try {
                if (s.isRecording()) { s.stop(); }
            } catch (ex) { System.println("ChronoBoyZ ERR [ChronoBoyzView.discardSession]: " + ex.getErrorMessage()); ex.printStackTrace(); }
            try { s.discard(); } catch (ex) { System.println("ChronoBoyZ ERR [ChronoBoyzView.discardSession]: " + ex.getErrorMessage()); ex.printStackTrace(); }
        }
        _session = null;
        _chronoEverStarted = false;
        resetAllDataOnly();
    }

    private function stopTimersForCleanup() as Void {
        stopRefreshTimer();
        var vt = _vibeTimer;
        if (vt != null) {
            try { vt.stop(); } catch (ex) { System.println("ChronoBoyZ ERR [ChronoBoyzView.stopTimersForCleanup]: " + ex.getErrorMessage()); ex.printStackTrace(); }
        }
        _pendingVibes = 0;
    }

    public function cleanup() as Void {
        stopTimersForCleanup();
        var s = _session;
        if (s != null) {
            try {
                if (s.isRecording()) { s.stop(); }
            } catch (ex) { System.println("ChronoBoyZ ERR [ChronoBoyzView.cleanup]: " + ex.getErrorMessage()); ex.printStackTrace(); }
            if (_chronoEverStarted) {
                try { s.save(); } catch (ex) { System.println("ChronoBoyZ ERR [ChronoBoyzView.cleanup]: " + ex.getErrorMessage()); ex.printStackTrace(); }
            } else {
                try { s.discard(); } catch (ex) { System.println("ChronoBoyZ ERR [ChronoBoyzView.cleanup]: " + ex.getErrorMessage()); ex.printStackTrace(); }
            }
        }
        _session = null;
        _isRunning = false;
        _chronoEverStarted = false;
    }

    private function resetAllDataOnly() as Void {
        _accumulatedElapsedMs = 0;
        _startTime = System.getTimer();
        _isRunning = false;
        _lastCycleIndex = 0;
        _halfwayVibedCycle = -1;
        WatchUi.requestUpdate();
    }

    // Fréquence cardiaque, rafraîchie au maximum une fois par seconde
    private function getCurrentHeartRate(nowMs as Number) as String {
        if (!_hrInitialized || (nowMs - _lastHrMs) >= 1000 || nowMs < _lastHrMs) {
            _hrInitialized = true;
            _lastHrMs = nowMs;

            var hr = "--";
            try {
                var activityInfo = Activity.getActivityInfo();
                if (activityInfo != null && activityInfo.currentHeartRate != null) {
                    hr = activityInfo.currentHeartRate.toString();
                }
            } catch (ex) { System.println("ChronoBoyZ ERR [ChronoBoyzView.getCurrentHeartRate]: " + ex.getErrorMessage()); ex.printStackTrace();
                // La fréquence cardiaque reste indisponible jusqu’à la prochaine lecture.
            }
            _hrString = hr + " bpm";
        }
        return _hrString;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        try {

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var screenWidth = dc.getWidth();
        var screenHeight = dc.getHeight();
        var centerX = screenWidth / 2;
        var centerY = screenHeight / 2;
        var radius = (screenWidth / 2) - 10;

        var nowMs = System.getTimer();

        // Le rafraîchissement est assuré par _wakeTimer : on ne rappelle plus requestUpdate() ici
        var currentSessionElapsed = _accumulatedElapsedMs;
        if (_isRunning) {
            currentSessionElapsed += nowMs - _startTime;
        }
        
        var currentCycleIndex = currentSessionElapsed / _initialCountdownMs;
        if (!_isRunning && currentSessionElapsed == 0) {
            currentCycleIndex = 0;
            _lastCycleIndex = 0;
            _halfwayVibedCycle = -1;
        }

        // 1. Détection de la fin de boucle (vibrations)
        if (_isRunning && currentCycleIndex > _lastCycleIndex) {
            _lastCycleIndex = currentCycleIndex;
            triggerVibration(6); 
        }

        var elapsedInCycle = currentSessionElapsed % _initialCountdownMs;
        var remainingMs = _initialCountdownMs - elapsedInCycle;
        if (remainingMs < 0) { remainingMs = 0; }

        var progress = 0.0;
        if (remainingMs == 0) {
            progress = 1.0;
        } else {
            progress = elapsedInCycle.toFloat() / _initialCountdownMs.toFloat();
        }
        
        // 2. Détection de la moitié de la boucle
        if (_isRunning && progress >= 0.5 && _halfwayVibedCycle < currentCycleIndex) {
            _halfwayVibedCycle = currentCycleIndex;
            triggerVibration(2); // 2 vibrations à la moitié
        }

        dc.setPenWidth(10);
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(centerX, centerY, radius);

        if (progress > 0.0) {
            var halfAngle = 90 - (0.5 * 360).toNumber();
            if (halfAngle < 0) { halfAngle += 360; }

            var currentAngle = 90 - (progress * 360).toNumber();
            if (currentAngle < 0) { currentAngle += 360; }

            if (progress < 0.5) {
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
                dc.drawArc(centerX, centerY, radius, Graphics.ARC_CLOCKWISE, 90, currentAngle);
            } else {
                // laisse le demi cercle blanc
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
                dc.drawArc(centerX, centerY, radius, Graphics.ARC_CLOCKWISE, 90, halfAngle);
                if (currentAngle < halfAngle) {
                    dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
                    dc.drawArc(centerX, centerY, radius, Graphics.ARC_CLOCKWISE, halfAngle, currentAngle);
                }
            }
        }

        var clockTime = System.getClockTime();
        var timeString = Lang.format("$1$:$2$", [clockTime.hour.format("%02d"), clockTime.min.format("%02d")]);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, (screenHeight * 0.10).toNumber(), Graphics.FONT_SMALL, timeString, Graphics.TEXT_JUSTIFY_CENTER);

        var totalChronoStr = formatTotalChrono(currentSessionElapsed);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, (screenHeight * 0.25).toNumber(), Graphics.FONT_LARGE, totalChronoStr, Graphics.TEXT_JUSTIFY_CENTER);

        var roundsStr = currentCycleIndex.format("%d");
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX + 80, (screenHeight * 0.45).toNumber(), Graphics.FONT_XTINY, roundsStr, Graphics.TEXT_JUSTIFY_CENTER);

        var hrString = getCurrentHeartRate(nowMs);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, (screenHeight * 0.72).toNumber(), Graphics.FONT_LARGE, hrString, Graphics.TEXT_JUSTIFY_CENTER);

        var countdownString = formatLoopingCountdown(currentSessionElapsed);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            centerX, 
            centerY - 10, 
            Graphics.FONT_LARGE, 
            countdownString, 
            Graphics.TEXT_JUSTIFY_CENTER
        );
    
        } catch (ex) { System.println("ChronoBoyZ ERR [ChronoBoyzView.onUpdate]: " + ex.getErrorMessage()); ex.printStackTrace();
            // Évite qu’une erreur ponctuelle interrompe l’interface.
        }
    }
}
