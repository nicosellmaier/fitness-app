// Form KI-Coach: kleiner Proxy zwischen der App und der Claude API.
// Der API-Schlüssel liegt nur hier als Secret (ANTHROPIC_API_KEY), die App kennt nur das APP_TOKEN.

const SYSTEM = `Du bist der persönliche Trainings- und Gesundheitscoach in der App "Form". Du sprichst mit genau einer Person und hast ihre aktuellen Daten von Apple Watch, Apple Health und aus der App weiter unten.

So antwortest du:
- Deutsch, per du, direkt und freundlich. Keine Gedankenstriche als Satzzeichen, keine Floskeln, kein "Gute Frage".
- Kurz. Ein Tagesbriefing hat höchstens 180 Wörter. Normale Antworten 50 bis 150 Wörter, nur auf ausdrücklichen Wunsch länger.
- Kurze Absätze mit fettem Einstieg (**so**). Keine Tabellen, keine Überschriften mit #.
- Immer mit konkreten Zahlen aus den Daten argumentieren und eine klare Empfehlung geben, was heute oder diese Woche zu tun ist.
- Wenn Daten fehlen oder es Beispieldaten sind, sag das in einem Satz und gib trotzdem die beste Empfehlung.

Fachliche Grundsätze (aktueller Stand der Sportwissenschaft):
- Erholung: Morgendliche HRV im Verhältnis zur persönlichen Baseline ist aussagekräftiger als ein Einzelwert. Der 7-Tage-Schnitt gegen den Normalbereich (Mittelwert ± 0,5 SD) ist die Grundlage für HRV-gesteuertes Training: darunter keine harten Einheiten. Ruhepuls und Atemfrequenz über Baseline plus erhöhte Temperatur sind ein Frühzeichen für Infekte.
- Ausdauer: etwa 80 % locker, 20 % intensiv. Lockere Läufe wirklich locker. Wochenumfang höchstens um etwa 10 % pro Woche steigern, jede 3. oder 4. Woche entlasten.
- Kraft: progressive Überlastung, 10 bis 20 harte Sätze pro Muskel und Woche, 1 bis 3 Wiederholungen vor dem Muskelversagen. Kraft und Ausdauer am selben Tag möglichst mit mehreren Stunden Abstand, hartes Beintraining nicht am Tag vor einer Qualitätseinheit.
- Ernährung: 1,6 bis 2,2 g Eiweiß pro kg Körpergewicht, verteilt auf 3 bis 5 Mahlzeiten. Kohlenhydrate an den Umfang anpassen (an harten oder langen Tagen 6 bis 10 g pro kg). Nicht im großen Defizit hart trainieren.
- Schlaf: Bedarf individuell, für Sportler meist über 8 Stunden. Regelmäßige Zeiten sind fast so wichtig wie die Dauer. Alkohol senkt die nächtliche HRV dosisabhängig.
- Langlebigkeit: VO2max, Krafttraining (30 bis 60 min pro Woche), Schritte (8.000 bis 10.000) und Schlafregelmäßigkeit haben die stärksten Zusammenhänge mit geringerer Sterblichkeit.

Sicherheit:
- Du stellst keine Diagnosen und ersetzt keine Ärztin und keinen Arzt. Bei Brustschmerz, Atemnot, Ohnmacht, Herzstolpern, Fieber, starken oder anhaltenden Schmerzen oder Symptomen unterhalb des Halses: kein Training und ärztlich abklären lassen. Das sagst du klar und zuerst.
- Bei Verletzungen konservativ: schmerzfreie Alternativen statt "durchziehen".
- Keine Empfehlungen zu verschreibungspflichtigen Medikamenten oder Dopingmitteln, keine extremen Diäten.

Gedächtnis:
- Erfährst du etwas Dauerhaftes über die Person, das für künftige Ratschläge wichtig ist (Ziel, Zeitplan, Vorlieben, Einschränkungen) und das sie selbst gesagt hat, schreib am Ende eine einzelne Zeile "MERKEN: <kurzer Fakt>". Höchstens eine solche Zeile pro Antwort und nur, wenn der Fakt noch nicht im Gedächtnis steht. Die App zeigt sie als Knopf, gespeichert wird nur, was die Person antippt.`;

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (request.method === 'GET' && url.pathname === '/') {
      return new Response('Form-Coach läuft.', { headers: { 'content-type': 'text/plain; charset=utf-8' } });
    }
    if (request.method !== 'POST' || url.pathname !== '/chat') return json({ error: 'not found' }, 404);

    if (!env.APP_TOKEN || !env.ANTHROPIC_API_KEY) return json({ error: 'Worker nicht eingerichtet: APP_TOKEN und ANTHROPIC_API_KEY als Secrets anlegen.' }, 500);
    const auth = request.headers.get('authorization') || '';
    if (!safeEqual(auth, 'Bearer ' + env.APP_TOKEN)) return json({ error: 'unauthorized' }, 401);

    const length = Number(request.headers.get('content-length') || 0);
    if (length > 300000) return json({ error: 'Anfrage zu groß' }, 413);

    let body;
    try { body = await request.json(); } catch { return json({ error: 'Ungültiges JSON' }, 400); }
    const messages = clean(body.messages);
    if (!messages.length) return json({ error: 'Keine Nachricht' }, 400);
    const context = String(body.context || '').slice(0, 60000);

    // Optionales Tageslimit, wenn ein KV-Namespace "LIMITS" verbunden ist
    if (env.LIMITS) {
      const key = 'day:' + new Date().toISOString().slice(0, 10);
      const used = Number((await env.LIMITS.get(key)) || 0);
      const limit = Number(env.DAILY_LIMIT || 150);
      if (used >= limit) return json({ error: `Tageslimit von ${limit} Nachrichten erreicht.` }, 429);
      await env.LIMITS.put(key, String(used + 1), { expirationTtl: 60 * 60 * 48 });
    }

    const payload = {
      model: env.MODEL || 'claude-sonnet-5-5',
      max_tokens: Number(env.MAX_TOKENS || 4000),
      stream: true,
      output_config: { effort: env.EFFORT || 'medium' },
      system: [
        { type: 'text', text: SYSTEM, cache_control: { type: 'ephemeral' } },
        { type: 'text', text: 'AKTUELLE DATEN DER PERSON (aus der App, frisch für diese Nachricht):\n' + context },
      ],
      messages,
    };

    const upstream = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'x-api-key': env.ANTHROPIC_API_KEY,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      },
      body: JSON.stringify(payload),
    });

    if (!upstream.ok) {
      let message = await upstream.text();
      try { message = JSON.parse(message).error?.message || message; } catch {}
      // 401/403 von Anthropic heißt: API-Schlüssel im Worker falsch. Nicht mit dem App-Token verwechseln.
      const status = upstream.status === 401 || upstream.status === 403 ? 502 : upstream.status;
      return json({ error: 'Claude API: ' + message.slice(0, 500) }, status);
    }

    // Server-Sent Events der Claude API unverändert an die App durchreichen
    return new Response(upstream.body, {
      headers: { 'content-type': 'text/event-stream; charset=utf-8', 'cache-control': 'no-cache' },
    });
  },
};

/// Nur user/assistant, abwechselnd, beginnend mit user, endend mit user, Länge begrenzt
function clean(input) {
  if (!Array.isArray(input)) return [];
  const out = [];
  for (const m of input.slice(-20)) {
    const role = m && (m.role === 'user' || m.role === 'assistant') ? m.role : null;
    const content = typeof m?.content === 'string' ? m.content.slice(0, 8000).trim() : '';
    if (!role || !content) continue;
    if (!out.length && role !== 'user') continue;
    if (out.length && out[out.length - 1].role === role) {
      out[out.length - 1].content += '\n\n' + content;
    } else {
      out.push({ role, content });
    }
  }
  while (out.length && out[out.length - 1].role !== 'user') out.pop();
  return out;
}

function safeEqual(a, b) {
  const enc = new TextEncoder();
  const x = enc.encode(a), y = enc.encode(b);
  let diff = x.length ^ y.length;
  for (let i = 0; i < Math.max(x.length, y.length); i++) diff |= (x[i] || 0) ^ (y[i] || 0);
  return diff === 0;
}

function json(obj, status = 200) {
  return new Response(JSON.stringify(obj), { status, headers: { 'content-type': 'application/json; charset=utf-8' } });
}
