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
- *Laufplan-Vorlagen*: 0 auf 5 km (Gehen und Laufen im Wechsel, 8 Wochen), 5 km schneller, 10 km, Halbmarathon, Marathon
- *Kraftprogramme*: Einsteiger Ganzkörper, Zuhause mit Kurzhanteln, Beine & Po, Oberkörper/Unterkörper, Push/Pull/Beine, Läufer-Kraft, Kraft kompakt. Mit einem Tipp übernehmen.
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

**Gesundheit (alle Whoop-Funktionen, mit Apple-Watch-Daten)**
- Erholung aus RMSSD (aus den Schlag-zu-Schlag-Daten der Nacht), Ruhepuls, Schlaf, Atemfrequenz und Temperatur
- HRV-Trend: 7-Tage-Schnitt gegen persönlichen Normalbereich, steuert den Trainingsplan (HRV-gesteuertes Training)
- Belastung 0–21 aus dem Puls über den ganzen Tag (Banister-TRIMP) plus muskulärer Last aus dem Krafttraining
- Schlafregelmäßigkeit als Sleep Regularity Index
- Stress-Monitor 0–3 und Atemübungen (zyklisches Seufzen, Resonanzatmung, Box-Atmung)
- Gesundheitsmonitor: 5 Nachtwerte gegen deinen Bereich, Frühwarnung bei Infekten
- Form-Alter und Tempo des Alterns aus 9 Faktoren mit Hazard Ratios aus großen Studien
- Journal mit Auswertung, welches Verhalten deine Erholung verändert
- Wochenziele für Aktivität, Kraft, Schritte und Schlaf
- Jeder Messwert hat eine Detailseite: 7 Tage bis 1 Jahr, Diagramm zum Antippen, Schnitt, Höchst- und Tiefstwert, Trend, Wochentags-Muster, Erklärung und Tipps
- Tagesansicht für jeden Tag: woraus sich die Erholung zusammensetzt, Vitalwerte gegen deinen Schnitt, Schlaf, Belastung, Workouts, Essen, Journal

**Schlafplan (wie Rise)**
- Jeden Tag ideale Schlafens- und Weckzeit: Weckzeit aus erstem Kalendertermin, festen Weckzeiten oder Gewohnheit, Schlafenszeit aus Bedarf, Einschlafdauer und Schlaffenster der inneren Uhr
- Echter Wecker per AlarmKit (iOS 26), auf Wunsch automatisch jeden Abend
- Energiekurve des Tages (Zwei-Prozess-Modell) mit Morgenhoch, Nachmittagstief, Abendhoch
- Tagesplan mit Erinnerungen: Tageslicht, letzter Kaffee, Nickerchen, Ende harter Einheiten, letzte Mahlzeit, Runterfahren
- Schlafschuld über 14 Nächte, Chronotyp

**KI-Coach**
- Chat über die Claude API mit all deinen Daten als Kontext, Tagesbriefing, Gedächtnis
- Läuft über einen eigenen Cloudflare Worker, der API-Schlüssel kommt nie aufs iPhone ([Einrichtung](docs/KI-COACH.md))

Formeln, Studien und Grenzen: [docs/WISSENSCHAFT.md](docs/WISSENSCHAFT.md)

**Finanzen**
- bindet die bestehende Finanz-Web-App ein

**Widgets**
- Erholung (klein, Sperrbildschirm rund, rechteckig, Zeile), Heute (mittel), Trainingswoche (groß)
- Satzpause als Live Activity im Dynamic Island mit +30 s und Überspringen

### Neu
- **Struktur**: Heute (Kern), Training (Laufen und Kraft gleichberechtigt, Mobility, Verlauf), Ernährung, Körper (Kachelraster mit eigenen Seiten), Mehr (Coach, Wochenbericht, Einstellungen, Export, Backup)
- **Zyklus**: Phase aus Apple Health, Prognose, Erholung und Gesundheitsmonitor um den Lutealphasen-Effekt bereinigt, Plan entschärft vor der Periode, Coach kennt die Phase
- **iCloud-Backup**: jede Änderung landet in iCloud Drive, neues iPhone übernimmt die Daten automatisch
- **Wochen-, Monats- und Jahresbericht** mit Highlights, Belastung-gegen-Erholung, Schlafkonsistenz, Push montags
- **Erinnerungen**: Morgenbriefing, Journal, Essen, Trinken
- **Ernährung**: Wasser, Gewicht (auch nach Health), Rezepte, gespeicherte Mahlzeiten, Favoriten, Schnell-Eintrag, 30/90-Tage-Verlauf
- **Laufen**: Bestzeiten, RPE nach jeder Einheit, Schuh-Kilometer mit Warnung, Wettkampftag mit Zwischenzeiten und Pacing für die Watch, Steigerungen, Laufband-Modus, Plan pausieren
- **Kraft**: Supersätze, Notizen pro Übung, Satzpause nach Übungstyp, Sätze pro Muskelgruppe pro Woche, RPE
- **Mobility**: 6 Routinen mit Timer, Empfehlung passend zur Verletzung
- **Siri**: "Wie ist meine Erholung in Form", Schlafenszeit, Wasser und Gewicht eintragen, Training starten, Briefing
- **Export**: CSV für Tageswerte, Kraft, Workouts, Ernährung; PDF-Gesundheitsbericht; JSON-Backup

### Mehrere Nutzer
- Jede Person installiert die App über TestFlight auf ihrem eigenen iPhone. Die Daten bleiben auf dem jeweiligen Gerät.
- Beim ersten Start fragt die App Name, Körperdaten und Ziel ab. Der Finanzen-Tab lässt sich ausblenden.

## Aufbau
- `Form/` App (SwiftUI, iOS 17)
- `FormWidgets/` Widget-Erweiterung mit Live Activity
- `Shared/` Code, den App und Widgets teilen (Farben, Widget-Daten, Live-Activity-Typen)
- `coach-worker/` Cloudflare Worker für den KI-Coach
- Daten liegen als JSON in der App Group `group.de.nicosellmaier.form`

## Build
Das Xcode-Projekt wird mit [XcodeGen](https://github.com/yonaskolb/XcodeGen) aus `project.yml` erzeugt.

- `build.yml`: baut bei jedem Push unsigniert
- `screenshots.yml`: Screenshots im Simulator mit Beispieldaten (Commit-Nachricht mit `[shots]` oder manuell)
- `release.yml`: signiert und lädt zu TestFlight hoch, Einrichtung in [docs/TESTFLIGHT.md](docs/TESTFLIGHT.md)
