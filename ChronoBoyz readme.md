# Projet ChronoBoyZ - Garmin Watch & Capteurs (Accéléromètre, Magnétomètre, Gyroscope)

Ce projet est une application Garmin (développée en Monkey C pour les montres compatibles comme la Forerunner 265) couplée à un script d'analyse en Python. Elle permet de gérer un chronomètre/timer sportif tout en enregistrant les données brutes des capteurs inertiels (accéléromètre, magnétomètre, gyroscope) dans un fichier d'activité `.FIT` pour un traitement ultérieur.

---

## 📂 Structure du Projet

Le projet s'articule autour des composants suivants :

* **`ChronoBoyzApp.mc`** : Point d'entrée de l'application et gestion du cycle de vie (démarrage, arrêt, récupération des préférences de durée).
* **`ChronoBoyzView.mc`** : Vue principale de l'application. Gère l'affichage graphique (compte à rebours, cercle de progression, chronomètre total, fréquence cardiaque), la logique de déclenchement des vibrations, et **l'enregistrement des capteurs** (écouteurs en temps réel et logger de session FIT).
* **`ChronoBoyzDelegate.mc`** : Gestion des interactions matérielles (désactivation du tactile, écoute des boutons physiques Start/Stop et Menu).
* **`ChronoBoyzTimerPicker.mc`** : Interface personnalisée pour le réglage dynamique du timer (minutes/secondes) via les boutons ou les gestes.
* **`ChronoBoyzMenu.mc`** : Gestion du menu d'options (Reset, Configuration du Timer).
* **`export_sensor02.py`** : Script Python d'extraction et d'export des données de capteurs depuis les fichiers d'activité `.FIT` de Garmin vers un format tabulaire (TSV/CSV).

---

## ⚙️ Fonctionnalités Techniques

1. **Chronométrage et Compte à rebours en boucle** : Affichage du temps écoulé, des tours/cycles et du temps restant avec alertes par vibration.
2. **Enregistrement multi-capteurs (IMU)** :
   * **Accéléromètre** : Suivi des mouvements linéaires et des variations de vitesse.
   * **Magnétomètre (Compas)** : Suivi de l'orientation et du cap magnétique (Nord).
   * **Gyroscope** : Suivi précis des vitesses de rotation et des mouvements de l'axe du poignet.
3. **Journalisation FIT (`SensorLogging`)** : Les données des trois capteurs sont enregistrées de manière synchrone dans la session sportive pour être exportées et analysées.

---

## 🛠️ Utilisation du Script d'Export Python

Le script `export_sensor02.py` permet d'extraire les séries temporelles de l'accéléromètre, du magnétomètre et du gyroscope à partir d'un fichier `.FIT` généré par la montre.

### Prérequis
* Python 3.x
* La bibliothèque Garmin FIT SDK :
  ```bash
  pip install garmin-fit-sdk