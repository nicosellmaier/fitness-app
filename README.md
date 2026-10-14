# Form

Eigene iOS-App für Erholung, Schlaf, Training und Gesundheit auf Basis von Apple Health und Apple Watch.

## Stand: Etappe 1
- Heute: Erholungs-Score, Schlaf, HRV, Belastung, letzte Aktivitäten
- Schlaf im Detail: Phasen, Puls, Nachtwerte, Bedarf für heute Nacht, Regelmäßigkeit
- Gesundheit: Trends (HRV, Ruhepuls, VO2max, Atemfrequenz), Recovery-Verlauf, Frühwarnung
- Training: Workouts automatisch als Ausdauer/Kraft erkannt, Lauf-Detail mit Route, Splits, Zonen, Laufdynamik
- Finanzen: bindet die bestehende Finanz-Web-App ein

## Build
Das Xcode-Projekt wird mit [XcodeGen](https://github.com/yonaskolb/XcodeGen) aus `project.yml` erzeugt.
GitHub Actions baut bei jedem Push unsigniert (`.github/workflows/build.yml`).
Signieren und TestFlight folgen, sobald der Apple Developer Account steht.
