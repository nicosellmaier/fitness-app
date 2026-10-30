import Foundation
import SwiftUI
import UserNotifications

/// Rückblick über einen Zeitraum: Woche, Monat oder Jahr
struct PeriodReport {
    let from: Date
    let to: Date
    let days: Int

    var recoveryAvg: Double?
    var recoveryPrev: Double?
    var greenDays = 0, yellowDays = 0, redDays = 0
    var strainAvg: Double = 0
    var strainPrev: Double = 0
    var strainDays: [(Date, Double, Int?)] = []
    var sleepAvg: TimeInterval?
    var sleepPrev: TimeInterval?
    var sleepNeed: TimeInterval = 8 * 3600
    var sleepConsistency: Double?       // Streuung der Schlafmitte in Minuten
    var sleepDebt: TimeInterval = 0
    var hrvAvg: Double?, hrvPrev: Double?
    var rhrAvg: Double?, rhrPrev: Double?
    var workouts: [WorkoutItem] = []
    var runKm: Double = 0, runKmPrev: Double = 0
    var runCount = 0
    var strengthSessions: [StrengthSession] = []
    var strengthVolume: Double = 0, strengthVolumePrev: Double = 0
    var steps: Double?
    var exerciseMinutes: Double = 0
    var journalInsight: JournalInsight?
    var planDone = 0, planMissed = 0, planAdjusted = 0
    var kcalAvg: Double?
    var proteinAvg: Double?
    var nutritionDays = 0
    var bestDay: (Date, Int)?
    var worstDay: (Date, Int)?
    var highlights: [String] = []

    var label: String {
        switch days {
        case ..<10: return "Woche"
        case ..<40: return "Monat"
        default: return "Jahr"
        }
    }
}

enum Reports {
    static func make(model: AppModel, store: DataStore, days n: Int, endingAt end: Date = .now) -> PeriodReport {
        let cal = Calendar.current
        let to = cal.startOfDay(for: end)
        let from = cal.addDays(-(n - 1), to: to)
        let prevFrom = cal.addDays(-n, to: from)
        var r = PeriodReport(from: from, to: to, days: n)

        func inRange(_ d: Date) -> Bool { d >= from && d < cal.addDays(1, to: to) }
        func inPrev(_ d: Date) -> Bool { d >= prevFrom && d < from }
        func mean(_ v: [Double]) -> Double? { v.isEmpty ? nil : v.reduce(0, +) / Double(v.count) }

        // Erholung
        var rec: [(Date, Int)] = [], recPrev: [Int] = []
        for i in model.days.indices {
            let d = model.days[i].day
            guard let s = model.recovery(at: i)?.score else { continue }
            if inRange(d) { rec.append((d, s)) } else if inPrev(d) { recPrev.append(s) }
        }
        r.recoveryAvg = mean(rec.map { Double($0.1) })
        r.recoveryPrev = mean(recPrev.map(Double.init))
        r.greenDays = rec.filter { $0.1 >= 67 }.count
        r.yellowDays = rec.filter { $0.1 >= 34 && $0.1 < 67 }.count
        r.redDays = rec.filter { $0.1 < 34 }.count
        r.bestDay = rec.max { $0.1 < $1.1 }
        r.worstDay = rec.min { $0.1 < $1.1 }

        // Belastung
        let strainPts = model.points(.strain)
        let cur = strainPts.filter { inRange($0.date) }, prev = strainPts.filter { inPrev($0.date) }
        r.strainAvg = mean(cur.map(\.value)) ?? 0
        r.strainPrev = mean(prev.map(\.value)) ?? 0
        let recByDay = Dictionary(uniqueKeysWithValues: rec.map { ($0.0, $0.1) })
        r.strainDays = cur.map { ($0.date, $0.value, recByDay[$0.date]) }

        // Schlaf
        let nights = model.nights.filter { inRange(cal.startOfDay(for: $0.wakeDay)) }
        let nightsPrev = model.nights.filter { inPrev(cal.startOfDay(for: $0.wakeDay)) }
        r.sleepAvg = mean(nights.map(\.asleep))
        r.sleepPrev = mean(nightsPrev.map(\.asleep))
        r.sleepNeed = model.sleepBaseHours * 3600
        r.sleepDebt = model.sleepDebt.hours * 3600
        if nights.count >= 3 {
            let mids = nights.map { n -> Double in
                let mid = n.start.addingTimeInterval(n.end.timeIntervalSince(n.start) / 2)
                var m = Double(cal.component(.hour, from: mid) * 60 + cal.component(.minute, from: mid))
                if m > 12 * 60 { m -= 24 * 60 }   // Mitternacht als 0
                return m
            }
            let mm = mids.reduce(0, +) / Double(mids.count)
            r.sleepConsistency = sqrt(mids.map { ($0 - mm) * ($0 - mm) }.reduce(0, +) / Double(mids.count))
        }

        // HRV, Ruhepuls
        let dd = model.days.filter { inRange($0.day) }, dp = model.days.filter { inPrev($0.day) }
        r.hrvAvg = mean(dd.compactMap(\.hrv)); r.hrvPrev = mean(dp.compactMap(\.hrv))
        r.rhrAvg = mean(dd.compactMap(\.rhr)); r.rhrPrev = mean(dp.compactMap(\.rhr))
        r.steps = mean(dd.compactMap(\.steps))
        r.exerciseMinutes = dd.compactMap(\.exerciseMin).reduce(0, +)

        // Training
        r.workouts = model.workouts.filter { inRange($0.start) }.sorted { $0.start < $1.start }
        let runs = r.workouts.filter { $0.activity == .running }
        r.runCount = runs.count
        r.runKm = runs.compactMap(\.distance).reduce(0, +) / 1000
        r.runKmPrev = model.workouts.filter { inPrev($0.start) && $0.activity == .running }.compactMap(\.distance).reduce(0, +) / 1000
        r.strengthSessions = store.data.sessions.filter { inRange($0.start) }
        r.strengthVolume = r.strengthSessions.map(\.volume).reduce(0, +)
        r.strengthVolumePrev = store.data.sessions.filter { inPrev($0.start) }.map(\.volume).reduce(0, +)
        if let plan = store.data.plan {
            let pr = plan.runs.filter { inRange($0.date) && $0.type != .rest }
            r.planDone = pr.filter { $0.status == .done }.count
            r.planMissed = pr.filter { $0.status == .missed }.count
            r.planAdjusted = pr.filter { $0.adjusted != nil }.count
        }

        // Ernährung
        let es = store.data.entries.filter { inRange($0.date) }
        let byDay = Dictionary(grouping: es) { cal.startOfDay(for: $0.date) }
        r.nutritionDays = byDay.count
        r.kcalAvg = mean(byDay.values.map { $0.map(\.kcal).reduce(0, +) })
        r.proteinAvg = mean(byDay.values.map { $0.map(\.protein).reduce(0, +) })

        // Journal
        r.journalInsight = JournalAnalysis.insights(journal: store.data.journal, behaviors: store.data.behaviors, recoveryByDay: model.recoveryByDay)
            .first(where: \.significant)

        r.highlights = highlights(r)
        return r
    }

    /// Drei bis fünf Sätze, die die Woche zusammenfassen
    static func highlights(_ r: PeriodReport) -> [String] {
        var out: [String] = []
        if let a = r.recoveryAvg, let p = r.recoveryPrev {
            let d = a - p
            if abs(d) >= 5 { out.append("Erholung im Schnitt \(Fmt.num(a)), das sind \(d > 0 ? "+" : "−")\(Fmt.num(abs(d))) gegenüber der \(r.label) davor.") }
            else { out.append("Erholung stabil bei \(Fmt.num(a)) im Schnitt.") }
        }
        if r.redDays >= 2 { out.append("\(r.redDays) rote Tage. Schau, ob Alkohol, späte Nächte oder ein Infekt dahinterstecken.") }
        if let s = r.sleepAvg {
            let diff = s - r.sleepNeed
            if diff < -30 * 60 { out.append("Du hast im Schnitt \(Fmt.hm(abs(diff))) h weniger geschlafen als dein Bedarf. Das ist der größte Hebel.") }
            else { out.append("Schlaf passt: im Schnitt \(Fmt.hm(s)) h bei \(Fmt.hm(r.sleepNeed)) h Bedarf.") }
        }
        if let c = r.sleepConsistency {
            if c > 60 { out.append("Deine Schlafmitte schwankt um \(Int(c)) Minuten. Gleichmäßigere Zeiten bringen oft mehr als eine Stunde extra Schlaf.") }
            else if c < 30 { out.append("Sehr regelmäßiger Schlafrhythmus (Schwankung \(Int(c)) min).") }
        }
        if r.strainPrev > 0 {
            let d = (r.strainAvg - r.strainPrev) / r.strainPrev
            if d > 0.25 { out.append("Belastung \(Int(d * 100)) % höher als zuvor. Nach so einer Woche gehört eine ruhigere dazu.") }
            else if d < -0.25 { out.append("Deutlich ruhigere Woche (Belastung \(Int(abs(d) * 100)) % niedriger). Gut als Erholungswoche, als Dauerzustand kostet es Fitness.") }
        }
        if r.runKm > 0 { out.append("\(Fmt.num(r.runKm, 1)) km gelaufen in \(r.runCount) Läufen" + (r.runKmPrev > 0 ? " (davor \(Fmt.num(r.runKmPrev, 1)) km)." : ".")) }
        if r.strengthSessions.count > 0 {
            let d = r.strengthVolumePrev > 0 ? (r.strengthVolume - r.strengthVolumePrev) / r.strengthVolumePrev : 0
            out.append("\(r.strengthSessions.count) Krafteinheiten, \(Fmt.num(r.strengthVolume / 1000, 1)) t Volumen" + (abs(d) > 0.1 ? " (\(d > 0 ? "+" : "−")\(Int(abs(d) * 100)) %)." : "."))
        }
        if r.planMissed > 0 { out.append("\(r.planMissed) geplante Läufe verpasst. Der Plan hat sich angepasst, kein Grund zum Nachholen.") }
        if let j = r.journalInsight { out.append("Journal: \(j.label) verändert deine Erholung um \(j.diff >= 0 ? "+" : "−")\(Fmt.num(abs(j.diff))) Punkte am nächsten Morgen.") }
        if let h = r.hrvAvg, let p = r.hrvPrev, abs(h - p) >= 4 { out.append("HRV \(h > p ? "gestiegen" : "gefallen") auf \(Fmt.num(h)) ms (davor \(Fmt.num(p)) ms).") }
        if let k = r.kcalAvg, r.nutritionDays >= 3 { out.append("Ernährung an \(r.nutritionDays) Tagen getrackt, im Schnitt \(Fmt.num(k)) kcal und \(Fmt.num(r.proteinAvg ?? 0)) g Eiweiß.") }
        return Array(out.prefix(6))
    }
}

// MARK: Erinnerungen

enum Reminders {
    /// Alle wiederkehrenden Erinnerungen neu setzen
    static func update(prefs: ReminderPrefs, store: DataStore) {
        let c = UNUserNotificationCenter.current()
        c.removePendingNotificationRequests(withIdentifiers: ["briefing", "journal", "meal-lunch", "meal-dinner", "water-1", "water-2", "water-3", "weekly"])
        guard !UserDefaults.standard.bool(forKey: "seedDemo") else { return }
        func daily(_ id: String, _ title: String, _ body: String, hour: Int, minute: Int = 0, weekday: Int? = nil) {
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            var dc = DateComponents(hour: hour, minute: minute)
            if let weekday { dc.weekday = weekday }
            c.add(UNNotificationRequest(identifier: id, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)))
        }
        if prefs.briefing { daily("briefing", "Dein Morgen", "Erholung, Schlaf und Training für heute sind da.", hour: prefs.briefingHour, minute: prefs.briefingMinute) }
        if prefs.journal { daily("journal", "Journal für gestern", "30 Sekunden: Alkohol, Koffein, Bildschirm, Stress?", hour: prefs.journalHour) }
        if prefs.meals {
            daily("meal-lunch", "Mittagessen eintragen", "Was gab es? Ein Tipp reicht für Favoriten und gestern.", hour: 13, minute: 30)
            daily("meal-dinner", "Abendessen eintragen", "Tagesbilanz wird erst mit dem Abendessen rund.", hour: 20)
        }
        if prefs.water {
            daily("water-1", "Trinken", "Erstes Glas? Ziel heute \(Int(prefs.waterGoalMl)) ml.", hour: 10)
            daily("water-2", "Trinken", "Halbzeit. Ein großes Glas Wasser jetzt.", hour: 14)
            daily("water-3", "Trinken", "Noch ein Glas, dann bist du nah am Ziel.", hour: 17, minute: 30)
        }
        if prefs.weeklyReport { daily("weekly", "Dein Wochenbericht", "Erholung, Schlaf, Belastung und Training der letzten 7 Tage.", hour: 8, minute: 0, weekday: 2) }
    }
}
