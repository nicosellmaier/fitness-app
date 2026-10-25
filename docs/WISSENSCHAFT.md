# Form: Wissenschaftliche Grundlage

Dieses Dokument beschreibt, wie Form die Funktionen von Whoop mit Daten der Apple Watch nachbildet, welche Formeln dahinterstecken, auf welchen Studien sie beruhen und wo ihre Grenzen liegen. Jede Zahl im Code lässt sich hier zurückverfolgen.

Stand: Oktober 2026.

---

## 1. Überblick: Whoop und Form im Vergleich

| Whoop-Funktion | In Form | Datenquelle | Evidenz |
|---|---|---|---|
| Recovery | Erholung 1–99 | HRV (RMSSD bzw. SDNN), Ruhepuls, Schlaf, Atemfrequenz, Handgelenktemperatur | gut für Trends, mittel für Einzeltage |
| Strain (Herz-Kreislauf) | Belastung 0–21 | Puls über den ganzen Tag, Banister-TRIMP | gut |
| Strength Trainer / Muscular Load | Muskuläre Last | Satz-Log in Form (Volumen) | mäßig, eigene Heuristik |
| Sleep Need, Sleep Performance | Schlafbedarf, Schlaf-Score | Schlafphasen der Watch | gut für Dauer, mäßig für Phasen |
| Sleep Consistency | Sleep Regularity Index (SRI) | Schlafphasen, 5-Minuten-Raster | gut |
| Strain Coach | Belastungsziel je nach Erholung | Erholung | Expertenkonsens |
| Stress Monitor (0–3) | Stress 0–3 | Puls ohne Bewegung, Schritte | mäßig |
| Atemübungen | Zyklisches Seufzen, Resonanzatmung, Box-Atmung | keine Messung nötig | gut (RCT, Meta-Analyse) |
| Health Monitor | Gesundheitsmonitor + Frühwarnung | 5 Nachtwerte gegen persönlichen Bereich | gut als Frühzeichen |
| HRV-Trend | 7-Tage-Schnitt gegen Normalbereich | ln(HRV) | gut (Meta-Analyse) |
| Healthspan, WHOOP Age, Pace of Aging | Form-Alter, Tempo des Alterns | 9 Faktoren, Hazard Ratios aus Kohortenstudien | Einzelfaktoren gut, Gesamtmodell nicht validiert |
| Journal, Behavior Insights | Journal mit Verhaltensanalyse | eigene Antworten + Erholung | statistisch sauber, aber nur Korrelation |
| Weekly Plan | Wochenziele | Aktivität, Kraft, Schritte, Schlaf | Leitlinien (WHO) |
| WHOOP Coach, My Memory | KI-Coach mit Gedächtnis | alle obigen Daten, Claude API | siehe Abschnitt 11 |
| Rise: Schlafens- und Weckzeit, Energiekurve, Schlafschuld, Gewohnheiten | Schlafplan | Schlaf, Kalender, Trainingsplan | siehe Abschnitt 12 |
| VO2max | aus Apple Health, zusätzlich Form-Wert (VDOT) aus Läufen | Apple-Schätzung, Laufzeiten | Apple unterschätzt, siehe 2.3 |

Nicht nachgebaut, mit Begründung, siehe Abschnitt 13. Der Schlafplan nach dem Vorbild von Rise steht in Abschnitt 12.

---

## 2. Was die Apple Watch misst und wie genau

### 2.1 Herzfrequenzvariabilität

Whoop berechnet RMSSD aus der letzten Tiefschlafphase. Apple speichert in Apple Health standardmäßig **SDNN** aus etwa einminütigen Messungen, mehrmals am Tag und in der Nacht. SDNN und RMSSD hängen eng zusammen, sind aber nicht austauschbar. RMSSD bildet den Vagus (Parasympathikus) direkter ab.

Die Watch legt zu vielen dieser Messungen zusätzlich die **Schlag-zu-Schlag-Zeitpunkte** ab (HKHeartbeatSeriesSample). Form liest diese Reihen für alle Messungen innerhalb der Schlaffenster, berechnet daraus selbst RMSSD und nimmt den Median der Nacht.

Artefaktfilter:
- RR-Intervalle außerhalb 300–2000 ms werden verworfen.
- Aufeinanderfolgende Intervalle, die sich um mehr als 20 % unterscheiden, gehen nicht in die Differenzen ein.
- Eine Messung braucht mindestens 20 gültige Differenzen.

Form nutzt RMSSD, sobald für mindestens 7 Tage der Baseline Werte vorliegen (bei der Erholung) bzw. 14 der letzten 30 Tage (beim HRV-Trend). Sonst fällt es auf SDNN zurück. Baseline und Tageswert stammen immer aus derselben Größe.

Genauigkeit: Gegenüber EKG misst die Apple Watch HRV in Ruhe gut, bei Bewegung schlechter (Hernando et al. 2018). Für Nachtwerte reicht die Genauigkeit, um Veränderungen gegenüber der eigenen Baseline zu erkennen.

### 2.2 Schlafphasen

In einem Vergleich von sechs Wearables mit der Polysomnographie (Schyvens et al. 2025) hatte die Apple Watch Series 8 die beste Übereinstimmung (Cohens κ = 0,53, Sensitivität 96 %, Spezifität 52 %). Sie überschätzt die Gesamtschlafzeit um etwa 20 Minuten und unterschätzt Tiefschlaf (−25 min) und REM (−13 min). Whoop 4.0 lag im selben Vergleich darunter.

Folgen für Form: Schlafdauer und Regelmäßigkeit sind belastbar, die Phasenanteile nur grob. Deshalb zählen die Phasen im Schlaf-Score nur 20 von 100 Punkten.

### 2.3 VO2max

Die Apple-Schätzung unterschätzt die im Labor gemessene VO2max im Mittel um 6,1 ml/kg/min, mittlerer absoluter Fehler 13 % (Lambe et al. 2025, n = 30). Form zeigt Apples Wert unverändert an und rechnet zusätzlich einen Form-Wert (VDOT nach Daniels) aus deinen Läufen, der im Trainingsplan benutzt wird. Für das Form-Alter wird Apples Wert benutzt. Wegen der Unterschätzung fällt der VO2max-Beitrag dort eher vorsichtig aus.

---

## 3. Erholung

Grundidee wie bei Whoop: Der Körper zeigt seine Bereitschaft in der Nacht durch hohe HRV, niedrigen Ruhepuls, unauffällige Atmung und Temperatur sowie ausreichenden Schlaf. Entscheidend ist immer der Vergleich mit der **eigenen** Baseline, nicht mit Normwerten (Altini & Plews 2021).

Baseline: Mittelwert und Standardabweichung der 30 Tage davor.

```
z_HRV  = (ln HRV_heute − Mittel ln HRV) / SD ln HRV         begrenzt auf ±3
z_RHR  = (Ruhepuls_heute − Mittel) / SD                       begrenzt auf ±3
Schlafleistung = min(1,1; Schlaf / Schlafbedarf)

Score = 55
      + 13 · z_HRV
      −  8 · z_RHR
      + 35 · (Schlafleistung − 0,88)
      −  6 · (z_Atem − 1)                 nur wenn z_Atem > 1,5
      −  min(12; 20 · (ΔTemp − 0,3))      nur wenn ΔTemp > 0,4 °C
```

Ergebnis begrenzt auf 1–99. Farben wie bei Whoop: ab 67 grün, ab 34 gelb, darunter rot.

Warum diese Gewichte:
- HRV ist der empfindlichste Marker für Belastung, Alkohol und Krankheit, aber auch der unspezifischste. Ruhepuls zeigt oft größere Effektstärken (Altini & Plews 2021: Krankheit RHR +6 %, d = 0,97; HRV −10 %, d = 0,47). Darum fließen beide ein.
- Die Logarithmierung der HRV ist Standard, weil HRV rechtsschief verteilt ist (Plews et al. 2013).
- Die Gewichte sind so gewählt, dass ein Tag mit 1 SD besserer HRV, normalem Puls und vollem Schlaf bei etwa 70 landet und ein typischer Infekt-Tag (HRV −1,5 SD, Puls +2 SD, Atmung und Temperatur erhöht) unter 34 fällt. Sie sind eine begründete Setzung, nicht aus Daten geschätzt.

---

## 4. HRV-Trend und HRV-gesteuertes Training

Einzelne HRV-Werte schwanken stark. Wochenmittel bilden Trainingsanpassungen deutlich besser ab als Tageswerte (Plews et al. 2013). Die heute übliche Entscheidungsregel stammt von Kiviniemi et al. und wurde von Javaloyes et al. weiterentwickelt:

```
gleitender 7-Tage-Schnitt von ln(HRV)
Normalbereich = Mittelwert ± 0,5 · SD von ln(HRV) der letzten 60 Tage
unter dem Bereich  → keine harten Einheiten
im oder über dem Bereich → Training wie geplant
```

Eine Meta-Analyse zu Wearable-gestütztem HRV-Training findet gegenüber festen Plänen gleich gute bis leicht bessere Anpassungen (Düking et al. 2021). Auch bei untrainierten Erwachsenen funktioniert ein app-gesteuertes Vorgehen (Casanova-Lizón et al. 2025).

In Form:
- Die Karte "HRV-Trend" zeigt Tageswerte, 7-Tage-Schnitt und Normalbereich.
- Zusätzlich wird der Variationskoeffizient der Woche angezeigt. Eine steigende Schwankung bei gleichem oder fallendem Mittel gilt als frühes Ermüdungszeichen (Plews et al. 2012).
- **Der Trainingsplan nutzt den Trend:** Liegt der 7-Tage-Schnitt unter dem Bereich, wird die Erholung für die Planung auf höchstens 45 gesetzt. Harte Einheiten werden dann um ein Drittel der Wiederholungen gekürzt oder bei niedriger Erholung mit einem lockeren Tag getauscht.

---

## 5. Belastung

### 5.1 Herz-Kreislauf

Banisters Trainingsimpuls (TRIMP), angewendet auf jeden Pulswert des Tages:

```
x = (Puls − Ruhepuls) / (Maximalpuls − Ruhepuls)          Anteil der Herzfrequenzreserve
TRIMP_Minute = Minuten · x · 0,64 · e^(1,92 · x)          Männer
TRIMP_Minute = Minuten · x · 0,86 · e^(1,67 · x)          Frauen
```

Der exponentielle Faktor bildet ab, dass Laktat und Ermüdung oberhalb der Schwelle überproportional steigen. Minuten unter 30 % der Herzfrequenzreserve werden nicht gezählt, sonst würde normales Gehen und Sitzen über 16 Stunden eine hohe Belastung ergeben. Lücken zwischen zwei Pulswerten zählen höchstens 10 Minuten.

Fehlt der Pulsverlauf, schätzt Form die Belastung aus Dauer und Durchschnittspuls der Workouts.

### 5.2 Muskulär

Whoop schätzt die muskuläre Last aus Beschleunigungsdaten am Handgelenk, das Verfahren ist nicht veröffentlicht. Form nutzt stattdessen dein Satz-Log:

```
relatives Volumen = Volumen der Einheit / Median der letzten 8 Einheiten     begrenzt auf 0,3–2
Muskuläre Last = 40 · relatives Volumen
```

Eine für dich typische Krafteinheit zählt damit so viel wie etwa 40 Minuten lockeres Laufen. Das ist eine Heuristik, angelehnt an die Session-RPE-Methode (Foster et al. 2001), die Minuten mal empfundene Anstrengung rechnet.

### 5.3 Skala 0 bis 21

```
Belastung = 21 · (1 − e^(−TRIMP_gesamt / 120))
```

Die Kurve sättigt wie bei Whoop: Eine Stunde locker (TRIMP ~73) ergibt etwa 10, eine harte Stunde (TRIMP ~143) etwa 14, über 19 kommt man nur mit sehr langen oder sehr harten Tagen.

### 5.4 Zielbereich

| Erholung | Zielbelastung |
|---|---|
| ab 67 | 14–18 |
| 34–66 | 10–14 |
| unter 34 | 0–10 |

### 5.5 Bewusst nicht genutzt: Acute:Chronic Workload Ratio

Viele Apps zeigen das Verhältnis aus akuter und chronischer Belastung als Verletzungsrisiko. Die Methode hat statistische Grundprobleme (mathematische Kopplung, Verhältnisartefakte) und keinen belegten kausalen Zusammenhang mit Verletzungen (Impellizzeri et al. 2020). Form verzichtet deshalb darauf und steuert über Erholung und HRV-Trend.

---

## 6. Schlaf

### 6.1 Schlafbedarf

```
Bedarf = Grundbedarf (Standard 8 h, einstellbar)
       + Belastung des Tages / 21 · 45 min           höchstens 45 min
       + 15 % der Schlafschuld (Abschnitt 12.3)         höchstens 60 min
```

Für Sportler gibt es keinen festen Wert. Das Expertenkonsens-Papier (Walsh et al. 2021) empfiehlt ausdrücklich einen individuellen Bedarf statt pauschal 7–9 Stunden. Chronisch 6 Stunden führen über zwei Wochen zu kumulativen Leistungseinbußen, die man selbst kaum bemerkt (Van Dongen et al. 2003). Darum wird Schlafschuld angerechnet, aber nur zu 15 % pro Nacht, damit der Bedarf realistisch bleibt.

### 6.2 Schlaf-Score (0–100)

| Teil | Punkte | Berechnung |
|---|---|---|
| Dauer | 50 | Schlaf / Bedarf |
| Effizienz | 20 | 75 % → 0, 95 % → voll |
| Phasen | 20 | Tiefschlaf gegen 15 %, REM gegen 21 % |
| Einschlafzeit | 10 | Abweichung vom Median der letzten 7 Nächte, ab 90 min 0 |

### 6.3 Schlafregelmäßigkeit (SRI)

Statt Standardabweichungen von Bett- und Aufstehzeit nutzt Form den Sleep Regularity Index nach Phillips et al. 2017:

```
Raster aus 5-Minuten-Epochen, Zustand schlafend oder wach
SRI = −100 + 200 · Anteil der Epochen, in denen der Zustand 24 h später gleich ist
```

100 heißt exakt gleiche Zeiten jeden Tag. In der UK Biobank (60.977 Personen) lag der Median bei 81. Die regelmäßigeren vier Fünftel hatten 20 bis 48 % weniger Gesamtsterblichkeit als das unregelmäßigste Fünftel, und Regelmäßigkeit sagte Sterblichkeit besser voraus als Schlafdauer (Windred et al. 2023).

---

## 7. Stress und Atemübungen

### 7.1 Stress-Monitor

Whoop vergleicht Puls und HRV mit einer 14-Tage-Baseline und blendet Bewegung aus. Die Apple Watch misst tagsüber nur alle paar Minuten den Puls und HRV nur gelegentlich, deshalb nutzt Form den Puls:

1. Alle Pulswerte der letzten 14 Tage ohne Bewegung: nicht im Workout (bis 15 min danach), nicht im Schlaf, und im 5-Minuten-Fenster weniger als 30 Schritte pro Minute.
2. Ruhepunkt = 25. Perzentil, Hochpunkt = 95. Perzentil dieser Werte (mindestens 8 bpm Abstand).
3. `Stress = 3 · (Puls − Ruhepunkt) / (Hochpunkt − Ruhepunkt)`, begrenzt auf 0–3.
4. Ab 2 gilt als hoch, die Minuten darüber werden gezählt.

Grenze: Erhöhter Puls ohne Schritte kann auch Kaffee, Hitze, Verdauung oder Radfahren ohne Workout sein. Der Wert zeigt körperliche Aktivierung, nicht psychischen Stress im engeren Sinn.

### 7.2 Atemübungen

| Übung | Ablauf | Evidenz |
|---|---|---|
| Zyklisches Seufzen | 2,5 s ein, 1 s nachatmen, 6 s aus | 5 min täglich über 4 Wochen: stärkere Stimmungsverbesserung und niedrigere Atemfrequenz als Achtsamkeitsmeditation (Balban et al. 2023, RCT, n = 108) |
| Resonanzatmung | 4 s ein, 6 s aus = 6/min | Langsames Atmen unter 10/min erhöht die vagal vermittelte HRV während und nach der Übung (Laborde et al. 2022, Meta-Analyse, 223 Studien) |
| Box-Atmung | je 4 s ein, halten, aus, halten | im selben RCT wirksam, aber schwächer als zyklisches Seufzen |

Whoops "zyklische Hyperventilation" zum Wachwerden ist bewusst nicht dabei, weil sie Schwindel auslösen kann und allein ohne Anleitung wenig sinnvoll ist.

Abgeschlossene Übungen ab 50 Sekunden werden als Achtsamkeitsminuten in Apple Health gespeichert.

---

## 8. Gesundheitsmonitor und Frühwarnung

Für HRV, Ruhepuls, Atemfrequenz, Blutsauerstoff und Handgelenktemperatur wird der heutige Nachtwert mit **Mittelwert ± 2 SD der letzten 30 Tage** verglichen (bei der Temperatur mindestens ± 0,3 °C, weil die Streuung sonst unrealistisch klein wird). Auffällig ist nur die ungünstige Richtung: HRV und Blutsauerstoff zu niedrig, Ruhepuls, Atemfrequenz und Temperatur zu hoch. Liegen zwei oder mehr Werte außerhalb, erscheint eine Warnung mit direktem Weg in den Krankheitsmodus.

Grundlage:
- Smartwatch-Daten (Ruhepuls, Schritte, Schlaf) zeigten bei über 80 % der COVID-Infektionen Veränderungen, oft vor den Symptomen (Mishra et al. 2020).
- Die Kombination mehrerer Signale erkennt Infekte besser als einzelne: Sensoren allein AUC 0,72, mit Symptomen 0,80 (Quer et al. 2021).
- Die nächtliche Atemfrequenz steigt bei Atemwegsinfekten schon vor Symptombeginn (Miller et al. 2020, mit Whoop-Daten).
- Kontinuierlich gemessene Hauttemperatur erkennt Fieberbeginn oft vor den Symptomen (Smarr et al. 2020).

Grenze: Alkohol, Schlafmangel, Hitze oder ein sehr harter Trainingstag können dasselbe Muster erzeugen. Die Warnung ist ein Anlass hinzuschauen, keine Diagnose.

---

## 9. Form-Alter und Tempo des Alterns

### 9.1 Idee

Whoop rechnet neun Verhaltens- und Fitnessfaktoren über veröffentlichte Hazard Ratios für Gesamtsterblichkeit in ein "physiologisches Alter" um. Die Gewichte sind proprietär. Form macht dasselbe transparent mit Primärstudien.

### 9.2 Von Risiko zu Jahren

Die Sterblichkeit Erwachsener steigt exponentiell mit dem Alter und verdoppelt sich etwa alle 8 Jahre (Gompertz-Gesetz). Ein relatives Risiko HR entspricht damit einer Verschiebung des Alters um

```
Δ Jahre = ln(HR) / (ln 2 / 8) = ln(HR) · 11,5
```

Beispiel: HR 0,87 (eine MET mehr VO2max) entspricht −1,6 Jahren.

### 9.3 Die Faktoren

Jeder Faktor wird gegen einen Referenzwert (typischer Erwachsener) verglichen. Ln-Hazard-Funktionen, zwischen den Stützstellen linear interpoliert:

| Faktor | Funktion | Referenz | Quelle |
|---|---|---|---|
| VO2max | ln(0,87) je 3,5 ml/kg/min Abstand, begrenzt auf ± 4 MET | Median FRIEND-Register für Alter und Geschlecht (Männer 20–29: 48,0; 30–39: 42,4; …) | Kodama et al. 2009 (33 Studien, 102.980 Personen); Kaminsky et al. 2015 |
| Ruhepuls | ln(1,09) je 10 bpm über 70, Bereich 40–100 | 70 bpm | Zhang et al. 2016 (46 Studien, 1,25 Mio. Personen) |
| Schritte | 3.500 → 0, linear in ln bis HR 0,60 bei 9.000 (unter 60 J.) bzw. HR 0,43 bei 7.000 (ab 60 J.) | 7.000/Tag | Paluch et al. 2022 (15 Kohorten, 47.471 Personen) |
| Moderate + intensive Aktivität | min/Woche, intensive doppelt: 0 → 1; 75 → 0,80; 225 → 0,69; 375 → 0,63; 600 → 0,61 | 150 min | Arem et al. 2015 (661.137 Personen) |
| Krafttraining | 0 → 1; 40 min/Woche → 0,83; ab 60 min → 0,85 | 0 | Momma et al. 2022 (Meta-Analyse) |
| Schlafdauer | unter 7 h: ln(1,12) je Stunde, höchstens 1,5 h; über 8,5 h: halbes ln(1,30) bis 10 h | 7,5 h | Cappuccio et al. 2010 (1,38 Mio. Personen) |
| Schlafregelmäßigkeit (SRI) | SRI 60 → 1, linear in ln bis HR 0,6 bei 85 | 81 | Windred et al. 2023 |
| Magermasse-Index (optional) | unter 17 kg/m² (Männer) bzw. 14,5 (Frauen) bis HR 1,30 | normal | Li et al. 2025 (11 Studien) |

Datenfenster: 180 Tage, mindestens 21 Tage. Moderate Minuten = Apples Trainingsminuten minus Workouts mit Durchschnittspuls ≥ 77 % des Maximalpulses (intensiv nach ACSM). Krafttraining = Kraft-Workouts aus Apple Health plus Einheiten aus Form, ohne Doppelzählung am selben Tag.

### 9.4 Überlappung

Die Studien sind jeweils für Alter, Geschlecht und viele Störgrößen adjustiert, aber nicht gegeneinander. Wer viele Schritte macht, hat meist auch mehr VO2max und einen niedrigeren Ruhepuls. Würde man alle Effekte einfach addieren, käme man auf unrealistische 20 bis 30 Jahre Unterschied. Form schrumpft deshalb die Summe der Log-Hazards um 40 % (Faktor 0,6) und begrenzt das Ergebnis auf ± 15 Jahre. Whoop beschreibt eine ähnliche Überlappungskorrektur, ohne sie offenzulegen.

```
Form-Alter = Kalenderalter + 0,6 · Σ (ln HR_Faktor − ln HR_Referenz) · 11,5
```

### 9.5 Tempo des Alterns

Whoop zeigt −1x bis 3x. Form leitet das so her: Das Form-Alter basiert auf 6 Monaten. Behältst du das Verhalten der letzten 30 Tage bei, nähert es sich innerhalb dieser 6 Monate dem 30-Tage-Wert an. In einem halben Kalenderjahr ändert sich das Form-Alter also um 0,5 Jahre plus die Differenz:

```
Tempo = (0,5 + (Jahre_30 Tage − Jahre_180 Tage)) / 0,5 = 1 + 2 · Differenz      begrenzt auf −1 bis 3
```

1,0x heißt: du alterst im Takt des Kalenders. 0,5x heißt: dein Form-Alter wird in einem Jahr nur ein halbes Jahr älter. Braucht mindestens 45 Tage Daten.

### 9.6 Grenzen

- Die Hazard Ratios stammen aus Beobachtungsstudien. Sie zeigen Zusammenhänge, keine bewiesene Wirkung für dich persönlich.
- Lange Schlafdauer ist in Studien stark durch Krankheit verzerrt (wer krank ist, schläft mehr). Darum zählt sie nur halb.
- Bei Krafttraining zeigt die Meta-Analyse über 140 min/Woche keinen klaren Zusatznutzen, teilweise sogar eine J-Kurve. Form hält den Effekt ab 60 Minuten konstant statt ihn wieder zu verschlechtern, weil die J-Kurve bei hohen Umfängen unsicher und vermutlich verzerrt ist.
- Das Gesamtmodell ist nicht gegen Sterblichkeitsdaten validiert. Es ist ein Werkzeug, um zu sehen, welches Verhalten am meisten bringt.

---

## 10. Journal und Verhaltensanalyse

Jeden Morgen fragt Form zum Vortag: Alkohol, Koffein nach 14 Uhr, spätes Essen, Handy im Bett, stressiger Tag, Krankheitsgefühl, Trinkmenge, Mobility, Sauna, Lesen vor dem Schlafen, plus eigene Verhaltensweisen.

Auswertung je Verhalten über die letzten 90 Tage, sobald mindestens 5-mal Ja und 5-mal Nein vorliegen:

```
Δ = mittlere Erholung am Morgen nach Ja − mittlere Erholung nach Nein
95-%-Konfidenzintervall nach Welch: Δ ± 1,96 · √(s²_ja / n_ja + s²_nein / n_nein)
```

Liegt das ganze Intervall auf einer Seite der Null, ist der Effekt bei dir statistisch ziemlich sicher. Beispiel aus der Forschung: In 4.098 Personen senkte Alkohol die nächtliche RMSSD dosisabhängig um 2, 6 und 13 ms und hob den Puls um 1, 4 und 9 bpm (Pietilä et al. 2018).

Grenze: Zusammenhang ist nicht Ursache. Wer an stressigen Tagen auch Alkohol trinkt, sieht beide Effekte vermischt.

---

## 11. KI-Coach

### 11.1 Aufbau

```
iPhone (Form)  ──HTTPS, App-Token──►  Cloudflare Worker  ──API-Schlüssel──►  Claude API
        ◄────────── Text-Stream (Server-Sent Events) ──────────
```

- Der Claude-API-Schlüssel liegt nur im Worker als Secret. Die App kennt nur ein eigenes App-Token, das im iOS-Schlüsselbund liegt.
- Bei jeder Frage baut die App eine kompakte Zusammenfassung (etwa 3.000 bis 5.000 Tokens): Erholung, HRV-Trend, 14 Tage Verlauf, Workouts, Plan und Paces, Verletzungen, Ernährung, Form-Alter, Journal-Zusammenhänge und das Gedächtnis.
- Der feste Systemprompt mit den Grundsätzen liegt im Worker und wird per Prompt-Caching wiederverwendet.
- Die Antwort wird live gestreamt.
- "Gedächtnis" wie Whoops My Memory: Der Coach schlägt dauerhafte Fakten mit einer Zeile `MERKEN: …` vor, gespeichert wird nur, was du antippst. Du kannst alles ansehen und löschen.

### 11.2 Modell und Kosten

Standard ist Claude Sonnet 5.5 (`claude-sonnet-5-5`) mit mittlerem Denkaufwand (`effort: medium`). Preise laut Anthropic (pro Million Tokens): Sonnet 5.5 2 $ Eingabe, 10 $ Ausgabe; Haiku 5.5 0,10 $ und 0,50 $.

Eine typische Frage kostet mit Sonnet 5.5 etwa 1 bis 2 Cent, mit Haiku 5.5 unter 0,1 Cent. Bei täglichem Briefing plus ein paar Fragen sind das unter 1 € im Monat. Modell und Tageslimit stellst du im Worker ein (`wrangler.toml`).

### 11.3 Grenzen

- Der Coach rechnet nicht selbst, er interpretiert die Werte, die die App berechnet hat.
- Er kann sich irren. Bei Warnzeichen (Brustschmerz, Atemnot, Fieber, Ohnmacht) verweist er ausdrücklich an Ärztin oder Arzt, so steht es im Systemprompt.
- Die Zusammenfassung deiner Daten geht bei jeder Frage über deinen Worker an die Claude API von Anthropic. Was dort mit API-Daten passiert, regeln die Datenschutzbedingungen von Anthropic.

Einrichtung: [KI-COACH.md](KI-COACH.md).

---

## 12. Schlafplan wie Rise

Rise gibt jeden Tag eine ideale Schlafens- und Weckzeit, eine Energiekurve und Zeitpunkte für Gewohnheiten aus. Rise legt seine Rechnung nicht offen. Form baut das mit veröffentlichter Schlafforschung nach.

### 12.1 Weckzeit aus deinem Tag

Reihenfolge, die erste passende Regel gewinnt:

1. Von Hand für morgen festgelegt.
2. Feste Weckzeit für diesen Wochentag (z.B. Arbeit). Ein früherer Kalendertermin minus Vorlauf hat trotzdem Vorrang.
3. Erster Kalendertermin zwischen 3 und 14 Uhr minus Vorlauf (Morgenroutine plus Weg, Standard 60 min). Ganztägige, als frei markierte und abgelehnte Termine zählen nicht.
4. Deine übliche Aufstehzeit (Median der letzten 4 Wochen, getrennt nach Arbeits- und freien Tagen). An freien Tagen mit Schlafschuld ab 2 h: bis zu 60 min später, 10 min je Stunde Schuld. Mehr nicht, weil große Verschiebungen am Wochenende die innere Uhr verstellen ("sozialer Jetlag").

### 12.2 Schlafenszeit

```
Ins Bett = Weckzeit − Schlafbedarf − Zusatzzeit
Schlafbedarf = Grundbedarf + Belastung + Schuldabbau (Abschnitt 6.1), +15 min wenn morgen eine harte oder lange Einheit ansteht
Zusatzzeit = Median der letzten 14 Nächte aus (Zeit im Bett − Schlaf), also Einschlafen plus Wachphasen, begrenzt auf 10–60 min
```

**Schlaffenster:** Die gewohnte Einschlafzeit (Median der letzten 14 Nächte) ± 30 min. Etwa 2 bis 3 Stunden vor der gewohnten Schlafenszeit liegt die Wach-Erhaltungszone, in der man kaum einschläft (Lavie 1986; Monterastelli et al. 2024). Form plant deshalb nie früher als 60 min vor der gewohnten Einschlafzeit. Reicht das nicht für den Bedarf, sagt die App das und empfiehlt ein kurzes Nickerchen.

### 12.3 Schlafschuld

```
Schuld = max(0; Σ über die letzten 14 Nächte w_i · (Grundbedarf − Schlaf_i)),   w_i = 1 − i/14 (i = 0 ist letzte Nacht)
```

Neuere Nächte zählen mehr, Nächte mit mehr Schlaf als Bedarf zahlen zurück. Unter 5 h gilt als niedrig, wie bei Rise. Der Bedarf jeder Nacht enthält 15 % der Schuld, höchstens 60 min: Abbau in kleinen Schritten, nicht durch langes Ausschlafen. Kumulative Leistungseinbußen durch chronisch zu wenig Schlaf sind gut belegt (Van Dongen et al. 2003).

### 12.4 Energiekurve

Zwei-Prozess-Modell der Schlafregulation (Borbély; Daan, Beersma & Borbély 1984):

```
Schlafdruck S(t) = 1 − (1 − S₀) · e^(−t / 18,2 h)          t = Stunden seit dem Aufwachen, S₀ steigt mit der Schlafschuld
Innere Uhr C(t): Tiefpunkt 2 h vor der gewohnten Aufwachzeit, Hoch 2,5 h vor der gewohnten Einschlafzeit
Nachmittagstief: Gauß-Delle 7,5 h nach dem Aufwachen
Schlafträgheit I(t) = 0,35 · e^(−t / 0,45 h)
Energie = C − S − I, auf 10–95 skaliert
```

Daraus liest die App Morgenhoch, Nachmittagstief und Abendhoch ab. Schlafträgheit dauert meist 15 bis 30 Minuten, volle Erholung braucht eine Stunde oder mehr (Hilditch & McHill 2019). Die Kurve ist ein Modell, keine Messung.

### 12.5 Tagesplan

| Zeitpunkt | Regel | Quelle |
|---|---|---|
| Tageslicht | erste Stunde nach dem Aufwachen | Licht am Morgen verschiebt die innere Uhr nach vorn (Khalsa et al. 2003) |
| Letzter Kaffee | 8,8 h vor dem Schlafen | Koffein kostet im Schnitt 45 min Schlaf, Kaffee mit 107 mg braucht 8,8 h Abstand (Gardiner et al. 2023, 24 Studien) |
| Nickerchen | im Nachmittagstief, 10 bis 20 min | 10 Minuten bringen den besten Nutzen ohne Trägheit (Brooks & Lack 2006) |
| Ende harter Einheiten | 1 h vor dem Schlafen | Abendtraining stört nicht, nur intensives Training bis ≤ 1 h vor dem Schlafen (Stutz et al. 2019) |
| Letzte große Mahlzeit, letzter Alkohol | 3 h vor dem Schlafen | Alkohol senkt die nächtliche HRV dosisabhängig (Pietilä et al. 2018) |
| Runterfahren | 1 h vor dem Schlafen | Expertenempfehlung zur Schlafhygiene (Walsh et al. 2021) |

### 12.6 Chronotyp

Schlafmitte an freien Tagen, korrigiert um nachgeholten Schlaf (MSFsc, Roenneberg):

```
MSF = Mitte zwischen Einschlafen und Aufwachen an freien Tagen
wenn Schlafdauer frei > Schlafdauer Arbeitstag:
MSFsc = MSF − (SD_frei − SD_Woche) / 2,   SD_Woche = (5 · SD_Arbeit + 2 · SD_frei) / 7
```

Unter 3:30 Uhr früher Typ, 3:30 bis 5:00 mittlerer, darüber später Typ. Als freie Tage zählen Samstag und Sonntag.

### 12.7 Wecker

Ab iOS 26 stellt Form über Apples AlarmKit einen echten Wecker, der auch im Lautlos-Modus klingelt. Auf älteren Versionen kommt eine Mitteilung mit Ton. Optional stellt die App den Wecker jeden Abend automatisch auf den Plan. Ein Wecker, der in der Leichtschlafphase weckt, braucht eine eigene Watch-App (siehe Abschnitt 13).

### 12.8 Grenzen

- Die innere Uhr wird nicht gemessen, sondern aus deinen Schlafzeiten geschätzt.
- Kalendertermine ohne Ortsangabe kennen deinen Weg nicht. Darum der einstellbare Vorlauf.
- Kalenderdaten bleiben auf dem iPhone. An den KI-Coach geht nur die Uhrzeit des ersten Termins, nie der Titel.

---

## 13. Bewusst nicht nachgebaut

| Whoop | Warum nicht |
|---|---|
| Vibrationswecker im Leichtschlaf | Braucht eine eigene Watch-App mit Hintergrundlaufzeit. Form stellt stattdessen einen echten Wecker zur geplanten Zeit (12.7). |
| Advanced Labs (Bluttests) | Laborleistung, keine Software. |
| Zyklus- und Schwangerschafts-Insights | Für dich nicht relevant. Technisch über Apple Health möglich, falls gewünscht. |
| Blutdruck-Insights, EKG | Macht die Apple Watch selbst (Bluthochdruck-Hinweise, EKG-App) und ist dort medizinisch zugelassen. |
| Passive Muskelbelastung aus Handbewegungen | Whoops Verfahren ist nicht veröffentlicht und laut Whoop selbst noch nicht validiert. Form nutzt dein Satz-Log. |
| Acute:Chronic Workload Ratio | Wissenschaftlich nicht haltbar, siehe 5.5. |

---

## 14. Quellen

1. Altini M, Plews D (2021). What is behind changes in resting heart rate and heart rate variability? A large-scale analysis of longitudinal measurements acquired in free-living. *Sensors* 21(23):7932. https://www.mdpi.com/1424-8220/21/23/7932
2. Arem H, et al. (2015). Leisure time physical activity and mortality: a detailed pooled analysis of the dose-response relationship. *JAMA Internal Medicine* 175(6):959–967.
3. Balban MY, et al. (2023). Brief structured respiration practices enhance mood and reduce physiological arousal. *Cell Reports Medicine* 4(1):100895. https://pmc.ncbi.nlm.nih.gov/articles/PMC9873947
4. Cappuccio FP, et al. (2010). Sleep duration and all-cause mortality: a systematic review and meta-analysis of prospective studies. *Sleep* 33(5):585–592.
5. Casanova-Lizón A, et al. (2025). Impact of heart rate variability-based exercise prescription. *Frontiers in Sports and Active Living* 7:1578478. https://doi.org/10.3389/fspor.2025.1578478
6. Düking P, et al. (2021). Monitoring and adapting endurance training on the basis of heart rate variability monitored by wearable technologies: a systematic review with meta-analysis. *Journal of Science and Medicine in Sport* 24(11):1180–1192.
7. Foster C, et al. (2001). A new approach to monitoring exercise training. *Journal of Strength and Conditioning Research* 15(1):109–115.
8. Hernando D, et al. (2018). Validation of the Apple Watch for heart rate variability measurements during relax and mental stress in healthy subjects. *Sensors* 18(8):2619.
9. Impellizzeri FM, et al. (2020). Acute:chronic workload ratio: conceptual issues and fundamental pitfalls. *International Journal of Sports Physiology and Performance* 15(6):907–913.
10. Kaminsky LA, Arena R, Myers J (2015). Reference standards for cardiorespiratory fitness measured with cardiopulmonary exercise testing: data from FRIEND. *Mayo Clinic Proceedings* 90(11):1515–1523.
11. Kodama S, et al. (2009). Cardiorespiratory fitness as a quantitative predictor of all-cause mortality and cardiovascular events in healthy men and women: a meta-analysis. *JAMA* 301(19):2024–2035.
12. Laborde S, et al. (2022). Effects of voluntary slow breathing on heart rate and heart rate variability: a systematic review and a meta-analysis. *Neuroscience & Biobehavioral Reviews* 138:104711.
13. Lambe O, O'Grady C, Baldwin M, Doherty C (2025). Investigating the accuracy of Apple Watch VO2 max measurements: a validation study. *PLOS ONE* 20(5):e0323741.
14. Li J, Liu X, Yang Q, Huang W, Nie Z, Wang Y (2025). Systematische Übersicht und Meta-Analyse zu Magermasse und Gesamtsterblichkeit. *Frontiers in Medicine* 12:1589888. https://www.frontiersin.org/journals/medicine/articles/10.3389/fmed.2025.1589888/full
15. Miller DJ, et al. (2020). Analyzing changes in respiratory rate to predict the risk of COVID-19 infection. *PLOS ONE* 15(12):e0243693.
16. Mishra T, et al. (2020). Pre-symptomatic detection of COVID-19 from smartwatch data. *Nature Biomedical Engineering* 4:1208–1220.
17. Momma H, et al. (2022). Muscle-strengthening activities are associated with lower risk and mortality in major non-communicable diseases: a systematic review and meta-analysis of cohort studies. *British Journal of Sports Medicine* 56(13):755–763.
18. Paluch AE, et al. (2022). Daily steps and all-cause mortality: a meta-analysis of 15 international cohorts. *Lancet Public Health* 7(3):e219–e228.
19. Phillips AJK, et al. (2017). Irregular sleep/wake patterns are associated with poorer academic performance and delayed circadian and sleep/wake timing. *Scientific Reports* 7:3216.
20. Pietilä J, et al. (2018). Acute effect of alcohol intake on cardiovascular autonomic regulation during the first hours of sleep in a large real-world sample of Finnish employees. *JMIR Mental Health* 5(1):e23. https://mental.jmir.org/2018/1/e23
21. Plews DJ, et al. (2012). Heart rate variability in elite triathletes: is variation in variability the key to effective training? *European Journal of Applied Physiology* 112:3729–3741.
22. Plews DJ, Laursen PB, Kilding AE, Buchheit M (2013). Evaluating training adaptation with heart-rate measures: a methodological comparison. *International Journal of Sports Physiology and Performance* 8(6):688–691.
23. Quer G, et al. (2021). Wearable sensor data and self-reported symptoms for COVID-19 detection. *Nature Medicine* 27:73–77.
24. Schyvens AM, Peters B, Van Oost NC, et al. (2025). Vergleich von sechs Consumer-Wearables mit der Polysomnographie. *SLEEP Advances* 6(2):zpaf021. https://academic.oup.com/sleepadvances/article/6/2/zpaf021/8090472
25. Smarr BL, et al. (2020). Feasibility of continuous fever monitoring using wearable devices. *Scientific Reports* 10:21640.
26. Van Dongen HPA, et al. (2003). The cumulative cost of additional wakefulness: dose-response effects on neurobehavioral functions and sleep physiology from chronic sleep restriction and total sleep deprivation. *Sleep* 26(2):117–126.
27. Walsh NP, et al. (2021). Sleep and the athlete: narrative review and 2021 expert consensus recommendations. *British Journal of Sports Medicine* 55(7):356–368.
28. Windred DP, et al. (2023). Sleep regularity is a stronger predictor of mortality risk than sleep duration: a prospective cohort study. *Sleep* 47(1):zsad253.
29. Zhang D, Shen X, Qi X (2016). Resting heart rate and all-cause and cardiovascular mortality in the general population: a meta-analysis. *CMAJ* 188(3):E53–E63.
30. Daan S, Beersma DGM, Borbély AA (1984). Timing of human sleep: recovery process gated by a circadian pacemaker. *American Journal of Physiology* 246(2):R161–R183.
31. Borbély A (2022). The two-process model of sleep regulation: beginnings and outlook. *Journal of Sleep Research* 31(4):e13598. https://pmc.ncbi.nlm.nih.gov/articles/PMC9540767
32. Brooks A, Lack L (2006). A brief afternoon nap following nocturnal sleep restriction: which nap duration is most recuperative? *Sleep* 29(6):831–840.
33. Gardiner C, Weakley J, Burke LM, et al. (2023). The effect of caffeine on subsequent sleep: a systematic review and meta-analysis. *Sleep Medicine Reviews* 69:101764.
34. Hilditch CJ, McHill AW (2019). Sleep inertia: current insights. *Nature and Science of Sleep* 11:155–165.
35. Khalsa SBS, Jewett ME, Cajochen C, Czeisler CA (2003). A phase response curve to single bright light pulses in human subjects. *Journal of Physiology* 549(3):945–952.
36. Lavie P (1986). Ultrashort sleep-waking schedule. III. 'Gates' and 'forbidden zones' for sleep. *Electroencephalography and Clinical Neurophysiology* 63(5):414–425.
37. Monterastelli AJ, Adams J, Eastman CI, Crowley SJ (2024). The forbidden zone for sleep is more robust in adolescents compared to adults. *Frontiers in Sleep* 2:1304647.
38. Roenneberg T, et al. (2004). A marker for the end of adolescence. *Current Biology* 14(24):R1038–R1039.
39. Stutz J, Eiholzer R, Spengler CM (2019). Effects of evening exercise on sleep in healthy participants: a systematic review and meta-analysis. *Sports Medicine* 49(2):269–287.

Rise: [RISE Sleep Tracker](https://www.risescience.com/llms.txt).

Whoop-Funktionen: [What's new at WHOOP 2026](https://www.whoop.com/us/en/thelocker/2026-whats-new/), [Healthspan](https://www.whoop.com/us/en/thelocker/healthspan/), [Stress Monitor](https://www.whoop.com/thelocker/introducing-stress-monitor-a-new-way-to-monitor-manage-stress/), [Passive MSK (the5krunner)](https://the5krunner.com/2026/02/28/new-whoop-strength-trainer-update/).

Apple AlarmKit: [WWDC25 "Wake up to the AlarmKit API"](https://developer.apple.com/videos/play/wwdc2025/230/).

Claude API: [Preise](https://platform.claude.com/docs/en/about-claude/pricing), [Streaming](https://platform.claude.com/docs/en/build-with-claude/streaming), [Prompt-Caching](https://platform.claude.com/docs/en/build-with-claude/prompt-caching), [Effort](https://platform.claude.com/docs/en/build-with-claude/effort).
