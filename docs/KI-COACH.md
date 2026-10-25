# KI-Coach einrichten

Der Coach in Form nutzt die Claude API. Damit dein API-Schlüssel nie auf dem iPhone liegt, läuft dazwischen ein kleiner Cloudflare Worker, so wie bei deiner Finanz-App. Einrichtung etwa 15 Minuten, alles geht im Browser am iPad oder iPhone.

```
Form auf dem iPhone  ──App-Token──►  dein Worker (Cloudflare)  ──API-Schlüssel──►  Claude API
```

## 1. Claude-API-Schlüssel holen

1. platform.claude.com öffnen und mit deiner E-Mail registrieren.
2. Unter *Billing* Guthaben aufladen (5 € reichen für Monate).
3. Unter *Limits* ein monatliches Ausgabenlimit setzen, zum Beispiel 5 €. Dann kann nie mehr passieren.
4. Unter *API Keys* → *Create Key*, Name `form-coach`. Den Schlüssel (`sk-ant-…`) kopieren, er wird nur einmal angezeigt.

## 2. App-Token ausdenken

Das ist ein eigenes Passwort zwischen App und Worker. Am einfachsten in der Passwörter-App einen neuen Eintrag anlegen und ein starkes Passwort erzeugen lassen (mindestens 32 Zeichen). Kopieren und gut aufheben.

## 3. Worker anlegen

1. dash.cloudflare.com → *Workers & Pages* → *Erstellen* → *Worker* → Name `form-coach` → *Bereitstellen*.
2. *Code bearbeiten*, alles löschen und den Inhalt von [`coach-worker/worker.js`](../coach-worker/worker.js) einfügen. Am iPhone: Datei auf GitHub öffnen, *Raw*, alles markieren und kopieren.
3. *Bereitstellen*.
4. Zurück zum Worker → *Einstellungen* → *Variablen und Geheimnisse* → *Hinzufügen*:

| Name | Typ | Wert |
|---|---|---|
| `ANTHROPIC_API_KEY` | Geheimnis | dein `sk-ant-…` Schlüssel |
| `APP_TOKEN` | Geheimnis | dein App-Token aus Schritt 2 |
| `MODEL` | Text (optional) | `claude-sonnet-5-5` oder günstiger `claude-haiku-5-5` |
| `EFFORT` | Text (optional) | `medium` (Standard), `low` ist schneller |

5. *Bereitstellen*.
6. Test: Die Adresse des Workers (`https://form-coach.<dein-name>.workers.dev`) im Browser öffnen. Es muss "Form-Coach läuft." erscheinen.

## 4. In der App verbinden

Form → *Heute* → Zahnrad → *KI-Coach verbinden*:
- Adresse: `https://form-coach.<dein-name>.workers.dev`
- App-Token: aus Schritt 2

*Verbindung testen*. Erscheint "✓ Verbindung steht.", bist du fertig. Das Token liegt danach im iOS-Schlüsselbund.

## Optional: Tageslimit

Falls das Token einmal in falsche Hände gerät, begrenzt das die Kosten zusätzlich zum Ausgabenlimit:

1. Cloudflare → *Speicher und Datenbanken* → *KV* → *Namespace erstellen*, Name `form-coach-limits`.
2. Worker → *Einstellungen* → *Bindungen* → *Hinzufügen* → *KV-Namespace*, Variablenname `LIMITS`, den Namespace auswählen.
3. Optional Variable `DAILY_LIMIT` (Standard 150 Nachrichten pro Tag).

## Kosten

| Modell | pro Frage etwa | 3 Fragen täglich im Monat |
|---|---|---|
| Claude Sonnet 5.5 | 1–2 Cent | etwa 1–2 € |
| Claude Haiku 5.5 | unter 0,1 Cent | wenige Cent |

Sonnet antwortet durchdachter, Haiku schneller und fast kostenlos. Wechseln geht jederzeit über die Variable `MODEL`, ohne die App anzufassen.

## Mit der Kommandozeile (falls du am Rechner bist)

```bash
cd coach-worker
npx wrangler deploy
npx wrangler secret put ANTHROPIC_API_KEY
npx wrangler secret put APP_TOKEN
```

## Wenn etwas nicht geht

- **"Das App-Token stimmt nicht …"**: In App und Worker muss exakt dasselbe Token stehen, ohne Leerzeichen am Ende.
- **Fehler 502 mit "Claude API: invalid x-api-key"**: Der API-Schlüssel im Worker ist falsch oder gelöscht.
- **Fehler 400 mit "credit balance"**: Guthaben bei Anthropic aufladen.
- **Fehler 429**: Tageslimit erreicht oder Anthropic-Ratenlimit, später nochmal.
- **"Worker nicht eingerichtet"**: `APP_TOKEN` oder `ANTHROPIC_API_KEY` fehlt als Geheimnis.

## Was an Anthropic geht

Bei jeder Frage schickt die App eine Zusammenfassung deiner Werte (Erholung, Schlaf, Training, Plan, Ernährung, Journal, Gedächtnis) und die letzten 20 Nachrichten des Chats. Rohdaten wie GPS-Routen oder einzelne Pulswerte werden nicht gesendet. Der Verlauf und das Gedächtnis bleiben auf dem iPhone und lassen sich im Coach über *…* löschen.
