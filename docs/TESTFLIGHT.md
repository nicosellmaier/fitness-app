# Form auf dein iPhone bringen (TestFlight)

Einmalige Einrichtung, dauert etwa 20 Minuten. Danach reicht ein Klick in GitHub für jede neue Version. Alles geht auch am iPad oder iPhone im Browser (Safari), ein Mac ist nicht nötig.

## 1. Developer Account
Der Apple Developer Account (99 € im Jahr) muss aktiv sein. Die Freischaltung dauert nach dem Bezahlen manchmal bis zu 48 Stunden.

Deine Team ID `2HB4D3R8QB` ist schon im Projekt eingetragen.

## 2. Kennungen registrieren
developer.apple.com/account → *Certificates, IDs & Profiles* → *Identifiers* → **+**

1. **App Group**: Typ *App Groups* → Beschreibung `Form`, ID `group.de.nicosellmaier.form`
2. **App ID der App**: Typ *App IDs* → *App* → Beschreibung `Form`, Bundle ID *Explicit* `de.nicosellmaier.form`.
   Unter *Capabilities* anhaken: **HealthKit** und **App Groups**. Danach bei App Groups auf *Configure* und die Gruppe aus Schritt 1 auswählen.
3. **App ID der Widgets**: wie oben, Bundle ID `de.nicosellmaier.form.widgets`, nur **App Groups** anhaken und dieselbe Gruppe zuweisen.

## 2b. iPhone registrieren (einmalig)

Beim Bauen signiert Xcode die App zuerst mit einem Entwicklerprofil, und das braucht mindestens ein registriertes Gerät. Ohne Gerät bricht der Lauf mit "Your team has no devices" ab.

1. Schließ das iPhone per Kabel an einen Mac an (macOS 10.15 reicht).
2. Öffne den Finder und wähle links das iPhone aus.
3. Klick oben unter dem Gerätenamen auf die graue Zeile mit Modell und Speicher, bis die **UDID** erscheint.
4. Klick mit der rechten Maustaste darauf und kopiere sie.
5. Öffne developer.apple.com/account → *Certificates, IDs & Profiles* → *Devices* → **+**.
6. Wähle iOS, gib als Name `iPhone Nico` ein und füg die UDID ein.

## 3. App in App Store Connect anlegen
appstoreconnect.apple.com → *Apps* → **+** → *Neue App*

- Plattform: iOS
- Name: `Form` (falls vergeben, z. B. `Form Training`; der Name ist nur für dich sichtbar, solange du nichts veröffentlichst)
- Primäre Sprache: Deutsch
- Bundle-ID: `de.nicosellmaier.form`
- SKU: `form-app`
- Benutzerzugriff: Vollständiger Zugriff

## 4. API-Schlüssel für GitHub
App Store Connect → *Benutzer und Zugriff* → *Integrationen* → *App Store Connect API* → *Teamschlüssel* → **+**

- Name: `GitHub`
- Zugriff: **Admin** (nötig, damit GitHub das Signier-Zertifikat selbst verwalten darf)

Danach:
- **Schlüssel-ID** notieren
- **Issuer-ID** notieren (steht oben über der Tabelle)
- **API-Schlüssel laden** (`AuthKey_XXXX.p8`). Das geht nur ein einziges Mal, also gut aufheben.

Die .p8-Datei ist ein Passwort. Sie gehört nur in die GitHub Secrets, niemals ins Repository.

## 5. Secrets in GitHub hinterlegen
github.com/nicosellmaier/fitness-app → *Settings* → *Secrets and variables* → *Actions* → **New repository secret**

| Name | Inhalt |
|---|---|
| `ASC_KEY_ID` | Schlüssel-ID aus Schritt 4 |
| `ASC_ISSUER_ID` | Issuer-ID aus Schritt 4 |
| `ASC_KEY_P8` | Kompletter Inhalt der .p8-Datei, inklusive der Zeilen `-----BEGIN PRIVATE KEY-----` und `-----END PRIVATE KEY-----` |

Die .p8-Datei kannst du am iPhone in der Dateien-App mit einem Texteditor öffnen oder am Rechner mit einem beliebigen Editor, dann alles kopieren.

## 6. Build starten
github.com/nicosellmaier/fitness-app → *Actions* → **TestFlight** → *Run workflow* → Branch auswählen → *Run workflow*

Der Lauf dauert etwa 15 Minuten. Ist er grün, verarbeitet Apple den Build noch 10 bis 30 Minuten.

## 7. Auf dem iPhone installieren
1. App Store Connect → deine App → *TestFlight* → *Interne Tests* → **+** neue Gruppe, dich selbst als Tester hinzufügen.
2. Auf dem iPhone die App **TestFlight** aus dem App Store laden und mit derselben Apple-ID anmelden.
3. Form erscheint dort, auf *Installieren* tippen.
4. Beim ersten Start Zugriff auf Apple Health erlauben (am besten *Alle aktivieren*).

Die Frage zur Verschlüsselung (Exportkonformität) ist in der App schon beantwortet, du musst nichts ausfüllen.

## Neue Version
Einfach Schritt 6 wiederholen. Die Build-Nummer zählt automatisch hoch, TestFlight aktualisiert die App.

## Apple Watch
Die App braucht keine eigene Watch-App. Einheiten aus dem Trainingsplan landen über *An Apple Watch senden* direkt in der **Trainings-App** der Watch (watchOS 10 oder neuer), inklusive Intervallen und Pace-Warnungen. Alle Messwerte kommen über Apple Health ins iPhone.

## Widgets und Dynamic Island
- Widgets: Home-Bildschirm lange drücken → **+** → *Form* → Erholung (klein und Sperrbildschirm), Heute (mittel) oder Trainingswoche (groß).
- Dynamic Island: startet automatisch, sobald du im Krafttraining einen Satz abhakst. Dort und auf dem Sperrbildschirm kannst du die Pause um 30 Sekunden verlängern oder überspringen.

## Wenn etwas schiefgeht
Der Fehler steht in GitHub direkt in der Zusammenfassung des Laufs.

- **Your team has no devices**: Schritt 2b fehlt.
- **No profiles for 'de.nicosellmaier.form' were found**: Schritt 2 prüfen, beide App IDs müssen existieren und HealthKit beziehungsweise App Groups aktiviert haben.
- **Cloud signing permission error**: Der API-Schlüssel hat nicht die Rolle *Admin*. Neuen Schlüssel mit Admin anlegen und die Secrets ersetzen.
- **No suitable application records were found**: Schritt 3 fehlt oder die Bundle-ID ist anders geschrieben.
- **Invalid key / 401**: In `ASC_KEY_P8` fehlt eine Zeile oder es wurde ein Leerzeichen mitkopiert.

## iCloud-Container

Die App sichert ihre Daten in iCloud Drive. Dafür braucht die App-ID die Berechtigung "iCloud" mit dem Container `iCloud.de.nicosellmaier.form`.

Xcode legt den Container beim signierten Build normalerweise selbst an. Schlägt der Release-Workflow mit einem Fehler zu "iCloud" oder "container" fehl:

1. Öffne developer.apple.com → Certificates, Identifiers & Profiles → Identifiers.
2. Wähle oben rechts "iCloud Containers" und tippe auf "+".
3. Beschreibung "Form", Identifier `iCloud.de.nicosellmaier.form`. Speichern.
4. Wechsle zu "App IDs" → `de.nicosellmaier.form` → Capabilities → iCloud einschalten → "CloudKit" aus, "iCloud Documents" an → den Container zuweisen. Speichern.
5. Starte den Release-Workflow erneut.
