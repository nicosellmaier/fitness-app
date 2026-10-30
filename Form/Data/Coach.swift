import Foundation
import Security

// MARK: Schlüsselbund für das App-Token

enum Keychain {
    static func set(_ value: String, for key: String) {
        let base: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: key]
        SecItemDelete(base as CFDictionary)
        guard !value.isEmpty else { return }
        var add = base
        add[kSecValueData as String] = Data(value.utf8)
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(add as CFDictionary, nil)
    }

    static func get(_ key: String) -> String? {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: key,
                                kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let d = out as? Data else { return nil }
        return String(data: d, encoding: .utf8)
    }
}

// MARK: Verbindung zum eigenen Worker

enum CoachConfig {
    static var url: String {
        get { UserDefaults.standard.string(forKey: "coachURL") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "coachURL") }
    }
    static var token: String {
        get { Keychain.get("coachToken") ?? "" }
        set { Keychain.set(newValue, for: "coachToken") }
    }
    static var isConfigured: Bool { URL(string: url)?.scheme == "https" && !token.isEmpty }
}

enum CoachError: LocalizedError {
    case notConfigured, http(Int, String)

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Der Coach ist noch nicht verbunden. Trag in den Einstellungen die Adresse deines Workers und das App-Token ein."
        case .http(let code, let msg): return code == 401 ? "Das App-Token stimmt nicht mit dem im Worker überein." : "Fehler \(code): \(msg)"
        }
    }
}

enum CoachClient {
    /// Schickt den Verlauf an den Worker und liefert den Text Stück für Stück, sobald Claude ihn schreibt
    static func stream(messages: [CoachMessage], context: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { cont in
            let task = Task {
                do {
                    guard CoachConfig.isConfigured, let base = URL(string: CoachConfig.url) else { throw CoachError.notConfigured }
                    var req = URLRequest(url: base.appendingPathComponent("chat"), timeoutInterval: 120)
                    req.httpMethod = "POST"
                    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    req.setValue("Bearer " + CoachConfig.token, forHTTPHeaderField: "Authorization")
                    let body: [String: Any] = [
                        "context": context,
                        "messages": messages.suffix(20).map { ["role": $0.role, "content": $0.text] },
                    ]
                    req.httpBody = try JSONSerialization.data(withJSONObject: body)
                    let (bytes, resp) = try await URLSession.shared.bytes(for: req)
                    let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
                    if code != 200 {
                        var text = ""
                        for try await line in bytes.lines { text += line; if text.count > 400 { break } }
                        throw CoachError.http(code, text)
                    }
                    for try await line in bytes.lines {
                        guard line.hasPrefix("data:") else { continue }
                        let json = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                        guard let data = json.data(using: .utf8),
                              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
                        let type = obj["type"] as? String
                        if type == "content_block_delta", let delta = obj["delta"] as? [String: Any],
                           delta["type"] as? String == "text_delta", let t = delta["text"] as? String {
                            cont.yield(t)
                        } else if type == "error", let e = obj["error"] as? [String: Any] {
                            throw CoachError.http(500, e["message"] as? String ?? "Unbekannter Fehler")
                        }
                    }
                    cont.finish()
                } catch {
                    cont.finish(throwing: error)
                }
            }
            cont.onTermination = { _ in task.cancel() }
        }
    }
}

// MARK: Kontext aus deinen Daten

enum CoachContext {
    /// Kompakte Zusammenfassung aller relevanten Daten. Wird bei jeder Nachricht frisch erzeugt.
    static func make(model: AppModel, store: DataStore) -> String {
        let cal = Calendar.current
        var L: [String] = []
        let p = store.data.profile
        L.append("Heute: \(Fmt.day(.now)), \(Fmt.time(.now)) Uhr.")
        L.append("Profil: \(p.sex.label), \(Int(model.age)) Jahre, \(Int(p.heightCm)) cm, \(Fmt.num(model.weightKg ?? p.weightKg, 1)) kg, Ernährungsziel \(p.goal.label), Maximalpuls \(Int(model.maxHR)).")
        if model.usingDemo { L.append("Hinweis: Die App zeigt gerade Beispieldaten, keine echten Messwerte.") }
        if let c = model.cycle {
            L.append("Zyklus: Tag \(c.day) von etwa \(c.length), \(c.phase.label). Nächste Periode voraussichtlich in \(c.daysToPeriod) Tagen. Erholung und Monitor sind um den Zykluseffekt bereinigt. Berücksichtige die Phase bei Training, Essen (Eisen in der Periode, mehr Hunger vor der Periode) und Schlaf.")
        }

        if let r = model.recoveryToday {
            L.append("\nERHOLUNG HEUTE: \(r.score)/100 (\(r.label)). \(r.text)")
        }
        L.append("Belastung heute: \(Fmt.num(model.strainToday, 1))/21, Zielbereich \(Int(Analytics.strainTarget(model.recoveryToday).lowerBound))–\(Int(Analytics.strainTarget(model.recoveryToday).upperBound)).")
        if let t = model.hrvTrend {
            L.append("HRV-Trend (7 Tage): \(Fmt.num(t.rolling7)) ms, Normalbereich \(Fmt.num(t.lower))–\(Fmt.num(t.upper)) ms, \(t.label). Quelle: \(t.usesRMSSD ? "RMSSD" : "SDNN").")
        }
        let need = model.needTonight
        L.append("Schlafbedarf heute Nacht: \(Fmt.hm(need.total)) h (Grundbedarf \(Fmt.hm(need.base)), Belastung +\(Fmt.hm(need.strain)), Schuld +\(Fmt.hm(need.debt))).")
        if let p = model.sleepPlan {
            // Kalendertitel bleiben auf dem iPhone, nur die Uhrzeit geht mit
            var src = p.sourceText
            var reasons = p.reasons
            if case .calendar(let e) = p.source {
                src = "erster Kalendertermin um \(Fmt.time(e.start))"
                reasons = reasons.filter { !$0.contains(e.title) }
            }
            L.append("Schlafplan heute Nacht: ins Bett \(Fmt.time(p.bedtime)), Wecker \(Fmt.time(p.wake)) (\(src)), geplant \(Fmt.hm(p.planned)) h Schlaf. Schlaffenster der inneren Uhr \(Fmt.time(p.sleepGate.lowerBound))–\(Fmt.time(p.sleepGate.upperBound)). Letzter Kaffee \(Fmt.time(p.caffeineCutoff)).")
            if !reasons.isEmpty { L.append("Hinweise zum Schlafplan: " + reasons.joined(separator: "; ")) }
        }
        L.append("Schlafschuld (14 Nächte, gewichtet): \(Fmt.num(model.sleepDebt.hours, 1)) h.")
        if let c = model.chronotype { L.append("Chronotyp: \(c.label), Schlafmitte freie Tage (korrigiert) \(Int(c.msfsc) / 60):\(String(format: "%02d", Int(c.msfsc) % 60)).") }
        if let s = model.stressToday, let a = s.average { L.append("Stress heute (0–3): Schnitt \(Fmt.num(a, 1)), \(Fmt.num(s.highMinutes)) min hoch.") }
        let outside = model.vitals.filter(\.outside)
        if !outside.isEmpty { L.append("Auffällige Nachtwerte: " + outside.map { "\($0.name) \($0.value) (Bereich \($0.range))" }.joined(separator: "; ") + ".") }

        L.append("\nLETZTE 14 TAGE (Datum | Erholung | HRV ms | Ruhepuls | Schlaf h | Schlaf-Score | Belastung):")
        for i in model.days.indices.suffix(14) {
            let d = model.days[i]
            let rec = model.recovery(at: i).map { "\($0.score)" } ?? "–"
            let hrv = (d.rmssd ?? d.hrv).map { Fmt.num($0) } ?? "–"
            let rhr = d.rhr.map { Fmt.num($0) } ?? "–"
            let sl = d.sleep.map { Fmt.hm($0.asleep) } ?? "–"
            let ss = d.sleep.map { "\(model.sleepScore($0))" } ?? "–"
            L.append("\(Fmt.shortDay(d.day)) | \(rec) | \(hrv) | \(rhr) | \(sl) | \(ss) | \(Fmt.num(model.strain(on: d.day).score, 1))")
        }
        if let sri = Analytics.consistency(model.nights) { L.append("Schlafregelmäßigkeit (SRI, 7 Tage): \(sri).") }

        let since = cal.addDays(-14, to: .now)
        let ws = model.workouts.filter { $0.start >= since }
        if !ws.isEmpty {
            L.append("\nWORKOUTS (14 Tage):")
            for w in ws.prefix(20) {
                var t = "\(Fmt.shortDay(w.start)): \(w.name), \(Fmt.clock(w.duration))"
                if let d = w.distance { t += ", \(Fmt.km(d))" }
                if let pace = w.pace { t += ", \(Fmt.pace(pace))/km" }
                if let hr = w.avgHR { t += ", Ø \(Int(hr)) bpm" }
                L.append(t)
            }
        }
        let sessions = store.data.sessions.filter { $0.start >= since }
        if !sessions.isEmpty {
            L.append("Kraft-Einheiten (14 Tage): " + sessions.map { "\(Fmt.shortDay($0.start)) \($0.name), \($0.doneSets) Sätze, \(Fmt.num($0.volume / 1000, 1)) t" }.joined(separator: "; "))
        }

        if let plan = store.data.plan {
            let today = cal.startOfDay(for: .now)
            L.append("\nTRAININGSPLAN: \(plan.settings.distance.label)\(plan.settings.raceName.isEmpty ? "" : " (\(plan.settings.raceName))") am \(Fmt.day(plan.raceDay)), noch \(plan.weeksLeft) Wochen, Phase \(plan.phase(on: today)?.name ?? "–"), Form-Wert (VDOT) \(Fmt.num(plan.vdot, 1)), Prognose \(Fmt.clock(VDOT.raceTime(meters: plan.settings.distance.meters, vdot: plan.vdot)))\(plan.settings.targetSeconds.map { ", Ziel \(Fmt.clock($0))" } ?? "").")
            let next = plan.runs.filter { $0.date >= today && $0.date < cal.addDays(7, to: today) }
            for r in next {
                L.append("\(Fmt.shortDay(r.date)): \(r.title) [\(r.status.rawValue)]\(r.adjusted.map { " (angepasst: \($0))" } ?? "")")
            }
            let paces = plan.paces
            L.append("Paces: locker \(paces.label(.easy)), Schwelle \(paces.label(.threshold)), Intervall \(paces.label(.interval)), Renntempo \(paces.label(.race)).")
            if let last = plan.log.first { L.append("Letzte Planänderung: \(last.text)") }
        } else {
            L.append("\nKein Trainingsplan angelegt.")
        }

        let r = store.restrictions
        let inj = store.data.injuries.filter(\.active)
        if !inj.isEmpty { L.append("\nAKTIVE VERLETZUNGEN: " + inj.map { "\($0.title), \($0.severityLabel), seit \(Fmt.shortDay($0.start))" }.joined(separator: "; ")) }
        if store.data.illness?.active == true { L.append("KRANK seit \(Fmt.shortDay(store.data.illness!.start))\(store.data.illness!.fever ? " mit Fieber" : "").") }
        if !r.isEmpty { L.append("Einschränkungen: Laufen \(r.runAllowed ? (r.runEasyOnly ? "nur locker" : "erlaubt") : "pausiert"), Kraft \(r.strengthAllowed ? "erlaubt" : "pausiert"), gesperrte Regionen: \(r.blockedRegions.map(\.label).sorted().joined(separator: ", ")).") }

        let today = cal.startOfDay(for: .now)
        let m = Macros.sum(store.entries(on: today))
        let t = store.nutritionTargets(model: model, day: today)
        L.append("\nERNÄHRUNG HEUTE: \(Fmt.num(m.kcal)) von \(Fmt.num(t.kcal)) kcal, Eiweiß \(Fmt.num(m.protein))/\(Fmt.num(t.protein)) g, Kohlenhydrate \(Fmt.num(m.carbs))/\(Fmt.num(t.carbs)) g, Fett \(Fmt.num(m.fat))/\(Fmt.num(t.fat)) g.")
        let past = (1...7).map { store.entries(on: cal.addDays(-$0, to: today)) }.filter { !$0.isEmpty }
        if !past.isEmpty {
            let avg = past.map { Macros.sum($0).kcal }.reduce(0, +) / Double(past.count)
            let prot = past.map { Macros.sum($0).protein }.reduce(0, +) / Double(past.count)
            L.append("Schnitt der letzten \(past.count) getrackten Tage: \(Fmt.num(avg)) kcal, \(Fmt.num(prot)) g Eiweiß.")
        }

        if let h = model.healthspan {
            L.append("\nFORM-ALTER: \(Fmt.num(h.formAge, 1)) (Kalenderalter \(Int(h.chronological)))\(h.pace.map { ", Tempo des Alterns \(Fmt.num($0, 1))x" } ?? "").")
            L.append(h.metrics.map { "\($0.name) \($0.value) (\($0.years >= 0 ? "+" : "")\(Fmt.num($0.years, 1)) J)" }.joined(separator: "; "))
        }

        let insights = JournalAnalysis.insights(journal: store.data.journal, behaviors: store.data.behaviors, recoveryByDay: model.recoveryByDay)
        if !insights.isEmpty {
            L.append("\nJOURNAL-ZUSAMMENHÄNGE (Erholung am Morgen danach, ja vs. nein, 95%-KI):")
            for i in insights.prefix(8) { L.append("\(i.label): \(i.diff >= 0 ? "+" : "")\(Fmt.num(i.diff)) (\(Fmt.num(i.low)) bis \(Fmt.num(i.high))), n=\(i.yes)/\(i.no)") }
        }
        let yKey = JournalBehavior.key(cal.addDays(-1, to: today))
        if let y = store.data.journal[yKey] {
            let yes = store.data.behaviors.filter { y[$0.id] == true }.map(\.label)
            if !yes.isEmpty { L.append("Gestern laut Journal: " + yes.joined(separator: ", ") + ".") }
        }

        if !store.data.coachMemory.isEmpty {
            L.append("\nGEDÄCHTNIS (vom Nutzer bestätigt):")
            for m in store.data.coachMemory { L.append("- " + m) }
        }
        return L.joined(separator: "\n")
    }
}
