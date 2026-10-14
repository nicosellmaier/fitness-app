# Form

Eigene iOS-App, die Whoop, Strava, Runna, MyFitnessPal und Finanzguru ersetzt. Alle Messwerte kommen von der Apple Watch über Apple Health, alles bleibt auf dem iPhone.

## Funktionen

**Heute**
- Erholungs-Score aus HRV, Ruhepuls, Schlaf und Atemfrequenz, Tagesbelastung mit Zielbereich
- Training des Tages aus dem Plan, mit einem Tipp auf die Watch geschickt
- Kalorien und Eiweiß des Tages, Hinweise bei Verletzung oder Krankheit

**Schlaf**
- Phasen (Tief, Kern, REM, Wach), Effizienz, Puls und Nachtwerte, Schlaf-Score
- Schlafbedarf für heute Nacht aus Grundbedarf, Belastung und Schlafschuld, empfohlene Schlafenszeit mit Erinnerung
- Regelmäßigkeit über die Woche

**Training**
- *Plan*: Trainingsplan aus Ziel, Datum und Zielzeit (5 km bis Ultra). Phasen, Wochenumfang, Paces nach Daniels-Form-Wert. Passt sich täglich an: erledigte und verpasste Läufe, Leistung (Paces werden schneller oder langsamer), Erholung (harte Einheit wird getauscht oder entschärft), Verletzung und Krankheit. Einheiten mit Intervallen und Pace-Warnungen gehen per WorkoutKit an die Trainings-App der Watch.
- *Kraft*: Routinen, Satz-Logging mit Vorschlag nach doppelter Progression, Satzpause mit Live Activity und Dynamic Island, Bestwerte, Verlauf pro Übung, Speichern in Apple Health
- *Aktivitäten*: alle Workouts, automatisch als Ausdauer oder Kraft erkannt. Lauf-Detail wie bei Strava: Route auf der Karte, Splits, Höhenprofil, Herzfrequenz-Zonen, Laufdynamik

**Verletzung und Krankheit**
- Körperstelle, Seite und Stärke angeben: Kraftübungen, die die Stelle belasten, werden automatisch ersetzt
- Lauf-Verletzung: Laufen wird zu lockerem Laufen oder Alternativtraining
- Krankheit: Training pausiert, danach sanfter Wiedereinstieg

**Ernährung**
- Kalorienziel aus Grundumsatz, aktiver Energie der Watch, geplantem Lauf und Ziel (Abnehmen, Halten, Aufbau)
- Barcode-Scanner und Suche über Open Food Facts, Grundnahrungsmittel, eigene Lebensmittel, zuletzt gegessen, Mahlzeit von gestern übernehmen
- Wochenübersicht

**Gesundheit**
- Trends für HRV, Ruhepuls, VO2max, Atemfrequenz, Recovery-Verlauf, Frühwarnung bei erhöhtem Ruhepuls und Temperatur

**Finanzen**
- bindet die bestehende Finanz-Web-App ein

**Widgets**
- Erholung (klein, Sperrbildschirm rund, rechteckig, Zeile), Heute (mittel), Trainingswoche (groß)
- Satzpause als Live Activity im Dynamic Island mit +30 s und Überspringen

## Aufbau
- `Form/` App (SwiftUI, iOS 17)
- `FormWidgets/` Widget-Erweiterung mit Live Activity
- `Shared/` Code, den App und Widgets teilen (Farben, Widget-Daten, Live-Activity-Typen)
- Daten liegen als JSON in der App Group `group.de.nicosellmaier.form`

## Build
Das Xcode-Projekt wird mit [XcodeGen](https://github.com/yonaskolb/XcodeGen) aus `project.yml` erzeugt.

- `build.yml`: baut bei jedem Push unsigniert
- `screenshots.yml`: Screenshots im Simulator mit Beispieldaten (Commit-Nachricht mit `[shots]` oder manuell)
- `release.yml`: signiert und lädt zu TestFlight hoch, Einrichtung in [docs/TESTFLIGHT.md](docs/TESTFLIGHT.md)
