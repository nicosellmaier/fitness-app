import Foundation
import SwiftUI

// Wissenschaftliche Grundlage und Quellen: docs/WISSENSCHAFT.md

struct StepSample {
    let start: Date
    let end: Date
    let count: Double
}

// MARK: HRV aus Schlag-zu-Schlag-Intervallen

enum HRVMath {
    /// RMSSD in ms. Artefakte: RR außerhalb 300–2000 ms und Sprünge über 20 % zum Vorgänger werden verworfen.
    static func rmssd(beats: [(t: Double, gap: Bool)]) -> Double? {
        var rr: [Double] = []
        var prev: Double?
        for b in beats {
            if let p = prev, !b.gap {
                let v: Double = (b.t - p) * 1000
                if v >= 300 && v <= 2000 { rr.append(v) } else { rr.append(.nan) }
            } else if prev != nil {
                rr.append(.nan)
            }
            prev = b.t
        }
        var sq: [Double] = []
        for i in 1..<max(1, rr.count) {
            let a = rr[i - 1], b = rr[i]
            guard a.isFinite, b.isFinite, abs(b - a) <= 0.2 * a else { continue }
            sq.append((b - a) * (b - a))
        }
        guard sq.count >= 20 else { return nil }
        return sqrt(sq.reduce(0, +) / Double(sq.count))
    }
}

// MARK: Belastung

struct StrainBreakdown {
    var cardio: Double = 0      // TRIMP aus Herzfrequenz
    var muscular: Double = 0    // TRIMP-Äquivalent aus Krafttraining
    var total: Double { cardio + muscular }
    var score: Double { Strain.score(total) }
}

enum Strain {
    /// Belastungsskala 0 bis 21, sättigend wie bei Whoop
    static func score(_ trimp: Double) -> Double { 21 * (1 - exp(-trimp / 120)) }

    /// Banister-TRIMP-Gewichtung, getrennt für Männer und Frauen
    static func weight(_ x: Double, female: Bool) -> Double {
        female ? 0.86 * exp(1.67 * x) : 0.64 * exp(1.92 * x)
    }

    /// Belastung eines Tages: Herzfrequenz über den ganzen Tag plus Krafttraining
    static func day(_ day: Date, hr: [HRPoint], workouts: [WorkoutItem], sessions: [StrengthSession],
                    rhr: Double, maxHR: Double, female: Bool) -> StrainBreakdown {
        let cal = Calendar.current
        var out = StrainBreakdown()
        let samples = hr.filter { cal.isDate($0.date, inSameDayAs: day) }.sorted { $0.date < $1.date }
        let reserve: Double = max(1, maxHR - rhr)
        if samples.count >= 20 {
            for i in samples.indices {
                let next: Date = i + 1 < samples.count ? samples[i + 1].date : samples[i].date.addingTimeInterval(60)
                let minutes: Double = min(10, max(0, next.timeIntervalSince(samples[i].date) / 60))
                let x: Double = (samples[i].bpm - rhr) / reserve
                guard x >= 0.3 else { continue }   // Aktivitätsschwelle 30 % Herzfrequenzreserve
                let xc = min(1, x)
                out.cardio += minutes * xc * weight(xc, female: female)
            }
        } else {
            // Ohne Pulsverlauf: Schätzung aus Durchschnittspuls der Workouts
            for w in workouts where cal.isDate(w.start, inSameDayAs: day) {
                let share: Double = w.kind == .strength ? 0.45 : 0.6
                let hrAvg: Double = w.avgHR ?? (rhr + share * reserve)
                let x: Double = max(0, min(1, (hrAvg - rhr) / reserve))
                out.cardio += w.duration / 60 * x * weight(x, female: female)
            }
        }
        // Muskuläre Last: Volumen der Einheit relativ zu deinen letzten Einheiten, typische Einheit = 40
        let past = sessions.filter { $0.start < cal.startOfDay(for: day) }.suffix(8).map(\.volume).filter { $0 > 0 }.sorted()
        let typical: Double = past.isEmpty ? 0 : past[past.count / 2]
        for s in sessions where cal.isDate(s.start, inSameDayAs: day) && s.volume > 0 {
            let rel: Double = typical > 0 ? s.volume / typical : 1
            out.muscular += 40 * min(2, max(0.3, rel))
        }
        return out
    }

    /// Belastung eines einzelnen Workouts aus dem Durchschnittspuls
    static func workout(_ w: WorkoutItem, rhr: Double, maxHR: Double, female: Bool) -> Double {
        let reserve: Double = max(1, maxHR - rhr)
        let share: Double = w.kind == .strength ? 0.45 : 0.6
        let hr: Double = w.avgHR ?? (rhr + share * reserve)
        let x: Double = max(0, min(1, (hr - rhr) / reserve))
        return score(w.duration / 60 * x * weight(x, female: female))
    }

    static func target(_ r: Recovery?) -> ClosedRange<Double> {
        guard let r else { return 8...14 }
        if r.score >= 67 { return 14...18 }
        if r.score >= 34 { return 10...14 }
        return 0...10
    }
}

// MARK: Schlafregelmäßigkeit (Sleep Regularity Index)

enum SleepRegularity {
    /// SRI nach Phillips et al. 2017: −100 bis 100. Wahrscheinlichkeit, 24 h später im selben Zustand zu sein.
    static func sri(_ nights: [SleepNight], days: Int = 7) -> Double? {
        let cal = Calendar.current
        let recent = Array(nights.suffix(days + 1))
        guard recent.count >= 4, let first = recent.first, let last = recent.last else { return nil }
        let start = cal.startOfDay(for: first.start)
        let end = cal.startOfDay(for: last.end)
        let epoch: TimeInterval = 300
        let n = Int(end.timeIntervalSince(start) / epoch)
        guard n > 288 * 2 else { return nil }
        var asleep = [Bool](repeating: false, count: n)
        for night in recent {
            for seg in night.segments where seg.stage != .awake {
                let a = max(0, Int(seg.start.timeIntervalSince(start) / epoch))
                let b = min(n, Int(seg.end.timeIntervalSince(start) / epoch))
                if a < b { for k in a..<b { asleep[k] = true } }
            }
        }
        var same = 0, total = 0
        for k in 0..<(n - 288) {
            total += 1
            if asleep[k] == asleep[k + 288] { same += 1 }
        }
        guard total > 0 else { return nil }
        return -100 + 200 * Double(same) / Double(total)
    }
}

// MARK: HRV-Trend (gleitender 7-Tage-Schnitt gegen Normalbereich)

struct HRVTrend {
    enum State { case below, within, above }
    let rolling7: Double        // ms
    let lower: Double
    let upper: Double
    let cv7: Double             // Variationskoeffizient der letzten 7 Tage in %
    let state: State
    let usesRMSSD: Bool
    let series: [(date: Date, value: Double, rolling: Double?)]

    var label: String {
        switch state {
        case .below: return "Unter deinem Normalbereich"
        case .within: return "Im Normalbereich"
        case .above: return "Über deinem Normalbereich"
        }
    }

    var color: Color {
        switch state {
        case .below: return Theme.warn
        case .within: return Theme.good
        case .above: return Theme.sleep
        }
    }

    /// Nach Plews et al. und Javaloyes et al.: ln(HRV), 7-Tage-Schnitt gegen Mittelwert ± 0,5 SD der letzten 60 Tage
    static func make(_ days: [DayMetrics]) -> HRVTrend? {
        let rmssdCount = days.suffix(30).compactMap(\.rmssd).count
        let useR = rmssdCount >= 14
        let vals: [(Date, Double)] = days.compactMap { d in
            let v = useR ? d.rmssd : d.hrv
            return v.map { (d.day, log($0)) }
        }
        guard vals.count >= 14 else { return nil }
        var series: [(date: Date, value: Double, rolling: Double?)] = []
        for (i, v) in vals.enumerated() {
            let win = vals[max(0, i - 6)...i].map(\.1)
            series.append((v.0, exp(v.1), win.count >= 4 ? exp(win.reduce(0, +) / Double(win.count)) : nil))
        }
        let last7 = vals.suffix(7).map(\.1)
        let r7: Double = last7.reduce(0, +) / Double(last7.count)
        let base = Array(vals.suffix(60)).map(\.1)
        guard let ms = Analytics.meanSD(base) else { return nil }
        let lo: Double = ms.mean - 0.5 * ms.sd
        let hi: Double = ms.mean + 0.5 * ms.sd
        let raw7 = last7.map { exp($0) }
        let m7 = raw7.reduce(0, +) / Double(raw7.count)
        let sd7 = Analytics.meanSD(raw7)?.sd ?? 0
        let state: State = r7 < lo ? .below : r7 > hi ? .above : .within
        return HRVTrend(rolling7: exp(r7), lower: exp(lo), upper: exp(hi), cv7: m7 > 0 ? sd7 / m7 * 100 : 0,
                        state: state, usesRMSSD: useR, series: Array(series.suffix(42)))
    }
}

// MARK: Stress

struct StressPoint: Identifiable {
    let id = UUID()
    let date: Date
    let level: Double   // 0 bis 3
}

struct StressDay {
    let points: [StressPoint]
    let current: Double?
    let average: Double?
    let highMinutes: Double
    let calmHR: Double
    let highHR: Double

    static func label(_ v: Double) -> String {
        v < 1 ? "Entspannt" : v < 2 ? "Mittel" : "Hoch"
    }

    static func color(_ v: Double) -> Color {
        v < 1 ? Theme.good : v < 2 ? Theme.warn : Theme.bad
    }
}

enum Stress {
    /// Nicht-sportliche Herzfrequenz im Verhältnis zu deinem 14-Tage-Bereich in Ruhe. Bewegung und Workouts werden ausgeblendet.
    static func compute(hr: [HRPoint], steps: [StepSample], workouts: [WorkoutItem], nights: [SleepNight], day: Date = .now) -> StressDay? {
        let cal = Calendar.current
        let since = cal.addDays(-14, to: cal.startOfDay(for: day))
        let ws = workouts.filter { $0.end >= since }
        let ns = nights.filter { $0.end >= since }
        // Schritte in 5-Minuten-Fächer, damit die Prüfung pro Pulswert schnell bleibt
        var bucket: [Int: Double] = [:]
        for s in steps where s.end >= since {
            let dur = max(60, s.end.timeIntervalSince(s.start))
            let perMin = s.count / dur * 60
            var t = s.start
            while t < s.end {
                bucket[Int(t.timeIntervalSince1970 / 300), default: 0] = max(bucket[Int(t.timeIntervalSince1970 / 300), default: 0], perMin)
                t = t.addingTimeInterval(300)
            }
        }
        func moving(_ t: Date) -> Bool {
            let k = Int(t.timeIntervalSince1970 / 300)
            if (bucket[k] ?? 0) > 30 || (bucket[k - 1] ?? 0) > 30 { return true }
            if ws.contains(where: { t >= $0.start.addingTimeInterval(-120) && t <= $0.end.addingTimeInterval(900) }) { return true }
            if ns.contains(where: { t >= $0.start && t <= $0.end }) { return true }
            return false
        }
        let calm = hr.filter { $0.date >= since && !moving($0.date) }
        guard calm.count >= 30 else { return nil }
        let sorted = calm.map(\.bpm).sorted()
        let lo = sorted[Int(Double(sorted.count - 1) * 0.25)]
        let hi = max(lo + 8, sorted[Int(Double(sorted.count - 1) * 0.95)])
        let today = calm.filter { cal.isDate($0.date, inSameDayAs: day) }.sorted { $0.date < $1.date }
        let pts = today.map { StressPoint(date: $0.date, level: max(0, min(3, 3 * ($0.bpm - lo) / (hi - lo)))) }
        var high: Double = 0
        for (i, p) in pts.enumerated() where p.level >= 2 {
            let next = i + 1 < pts.count ? pts[i + 1].date : p.date.addingTimeInterval(300)
            high += min(15, next.timeIntervalSince(p.date) / 60)
        }
        let avg = pts.isEmpty ? nil : pts.map(\.level).reduce(0, +) / Double(pts.count)
        let recent = pts.last.flatMap { Date.now.timeIntervalSince($0.date) < 3600 ? $0.level : nil }
        return StressDay(points: pts, current: recent, average: avg, highMinutes: high, calmHR: lo, highHR: hi)
    }
}

// MARK: Gesundheitsmonitor

struct VitalStatus: Identifiable {
    var id: String { name }
    let name: String
    let value: String
    let range: String
    let outside: Bool
    let icon: String
}

enum HealthMonitor {
    /// Heutiger Wert gegen deinen 30-Tage-Bereich (Mittelwert ± 2 SD)
    static func vitals(_ days: [DayMetrics]) -> [VitalStatus] {
        guard let i = days.indices.last else { return [] }
        let d = days[i]
        var out: [VitalStatus] = []
        func add(_ name: String, _ icon: String, _ key: KeyPath<DayMetrics, Double?>, scale: Double, digits: Int, unit: String) {
            guard let v = d[keyPath: key] else { return }
            let b = Analytics.baseline(days, before: i, key)
            var outside = false
            var range = "Baseline wird gelernt"
            if let b {
                let sd = max(b.sd, key == \DayMetrics.temp ? 0.15 : 0.0001)
                let lo = (b.mean - 2 * sd) * scale, hi = (b.mean + 2 * sd) * scale
                outside = v * scale < lo || v * scale > hi
                range = Fmt.num(lo, digits) + "–" + Fmt.num(hi, digits) + " " + unit
            }
            out.append(VitalStatus(name: name, value: Fmt.num(v * scale, digits) + " " + unit, range: range, outside: outside, icon: icon))
        }
        add("Herzfrequenzvariabilität", "waveform.path.ecg", \.hrv, scale: 1, digits: 0, unit: "ms")
        add("Ruhepuls", "heart.fill", \.rhr, scale: 1, digits: 0, unit: "bpm")
        add("Atemfrequenz", "lungs.fill", \.resp, scale: 1, digits: 1, unit: "/min")
        add("Blutsauerstoff", "drop.fill", \.spo2, scale: 100, digits: 0, unit: "%")
        add("Handgelenktemperatur", "thermometer.medium", \.temp, scale: 1, digits: 1, unit: "°C")
        return out
    }
}

// MARK: Form-Alter (Healthspan)

struct HealthspanMetric: Identifiable {
    var id: String { name }
    let name: String
    let icon: String
    let value: String
    let target: String
    let years: Double       // positiv = älter
    let tip: String
}

struct Healthspan {
    let chronological: Double
    let formAge: Double
    let pace: Double?
    let metrics: [HealthspanMetric]
    let daysOfData: Int

    var delta: Double { formAge - chronological }
}

struct HealthspanInputs {
    var nights: [SleepNight]
    var steps: [Date: Double]
    var exercise: [Date: Double]
    var workouts: [WorkoutItem]
    var sessions: [StrengthSession]
    var vo2: [Point]
    var rhr: [Date: Double]
    var leanMass: Double?
    var heightM: Double?
    var age: Double
    var female: Bool
    var maxHR: Double
}

enum HealthspanModel {
    /// Sterblichkeit verdoppelt sich bei Erwachsenen etwa alle 8 Jahre (Gompertz)
    static let gompertz: Double = log(2) / 8
    /// Überlappung der Faktoren (alle hängen mit Fitness zusammen): Summe der log-Hazards wird geschrumpft
    static let shrink: Double = 0.6

    static func interp(_ x: Double, _ pts: [(Double, Double)]) -> Double {
        guard let f = pts.first, let l = pts.last else { return 0 }
        if x <= f.0 { return f.1 }
        if x >= l.0 { return l.1 }
        for i in 1..<pts.count where x <= pts[i].0 {
            let a = pts[i - 1], b = pts[i]
            return a.1 + (b.1 - a.1) * (x - a.0) / (b.0 - a.0)
        }
        return l.1
    }

    /// VO2max-Median (FRIEND-Register, Kaminsky 2015) für Alter und Geschlecht
    static func vo2Reference(age: Double, female: Bool) -> Double {
        let men: [(Double, Double)] = [(25, 48.0), (35, 42.4), (45, 37.8), (55, 32.6), (65, 28.2), (75, 24.4)]
        let women: [(Double, Double)] = [(25, 37.6), (35, 30.2), (45, 26.7), (55, 23.4), (65, 20.0), (75, 18.3)]
        return interp(age, female ? women : men)
    }

    // Log-Hazard-Funktionen je Faktor
    static func lnVO2(_ v: Double, ref: Double) -> Double { log(0.87) * max(-4, min(4, (v - ref) / 3.5)) }
    static func lnRHR(_ r: Double) -> Double { log(1.09) * (max(40, min(100, r)) - 70) / 10 }
    static func lnSteps(_ s: Double, age: Double) -> Double {
        let plateau: Double = age < 60 ? 9000 : 7000
        let best: Double = age < 60 ? 0.60 : 0.43
        return log(best) * max(0, min(1, (s - 3500) / (plateau - 3500)))
    }
    static func lnMVPA(_ minutesPerWeek: Double) -> Double {
        interp(minutesPerWeek, [(0, 0), (75, log(0.80)), (225, log(0.69)), (375, log(0.63)), (600, log(0.61))])
    }
    static func lnStrength(_ minutesPerWeek: Double) -> Double {
        interp(minutesPerWeek, [(0, 0), (40, log(0.83)), (60, log(0.85))])
    }
    static func lnSleep(_ hours: Double) -> Double {
        if hours < 7 { return log(1.12) * min(1.5, 7 - hours) }
        if hours > 8.5 { return 0.5 * log(1.30) * min(1, (hours - 8.5) / 1.5) }
        return 0
    }
    static func lnSRI(_ sri: Double) -> Double { log(0.6) * max(0, min(1, (sri - 60) / 25)) }
    static func lnFFMI(_ ffmi: Double, female: Bool) -> Double {
        let low: Double = female ? 14.5 : 17
        return log(1.30) * max(0, min(1, (low - ffmi) / 2))
    }

    struct Window {
        var sleepH: Double?
        var sri: Double?
        var steps: Double?
        var moderate: Double?   // min/Woche
        var vigorous: Double?
        var strength: Double?
        var vo2: Double?
        var rhr: Double?
        var days: Int
    }

    static func window(_ inp: HealthspanInputs, days: Int) -> Window {
        let cal = Calendar.current
        let from = cal.addDays(-days, to: cal.startOfDay(for: .now))
        let nights = inp.nights.filter { $0.wakeDay >= from }
        let stepVals = inp.steps.filter { $0.key >= from && $0.key < cal.startOfDay(for: .now) }.map(\.value).filter { $0 > 200 }
        let exVals = inp.exercise.filter { $0.key >= from }.map(\.value)
        let span: Double = Double(max(stepVals.count, exVals.count, nights.count, 1))
        let weeks: Double = max(1, span / 7)
        var vig: Double = 0
        var strengthMin: Double = 0
        var strengthDays = Set<Date>()
        for w in inp.workouts where w.start >= from {
            if w.kind == .strength {
                strengthMin += w.duration / 60
                strengthDays.insert(cal.startOfDay(for: w.start))
            } else if let hr = w.avgHR, hr >= 0.77 * inp.maxHR {
                vig += w.duration / 60
            }
        }
        for s in inp.sessions where s.start >= from && !strengthDays.contains(cal.startOfDay(for: s.start)) {
            strengthMin += (s.end ?? s.start).timeIntervalSince(s.start) / 60
        }
        let exSum: Double = exVals.reduce(0, +)
        let moderate: Double = max(0, exSum - vig) / weeks
        let rhrVals = inp.rhr.filter { $0.key >= from }.map(\.value)
        let vo2 = inp.vo2.filter { $0.date >= cal.addDays(-max(days, 90), to: .now) }.last?.value
        return Window(
            sleepH: nights.isEmpty ? nil : nights.map(\.asleep).reduce(0, +) / Double(nights.count) / 3600,
            sri: SleepRegularity.sri(nights, days: min(days, 30)),
            steps: stepVals.isEmpty ? nil : stepVals.reduce(0, +) / Double(stepVals.count),
            moderate: exVals.isEmpty && inp.workouts.isEmpty ? nil : moderate,
            vigorous: vig / weeks,
            strength: strengthMin / weeks,
            vo2: vo2,
            rhr: rhrVals.isEmpty ? nil : rhrVals.reduce(0, +) / Double(rhrVals.count),
            days: Int(span))
    }

    /// Summe der Jahre (vor Schrumpfung) und Einzelbeiträge
    static func years(_ w: Window, inp: HealthspanInputs) -> (total: Double, parts: [String: Double]) {
        var parts: [String: Double] = [:]
        let k: Double = shrink / gompertz
        if let v = w.sleepH { parts["sleep"] = (lnSleep(v) - lnSleep(7.5)) * k }
        if let v = w.sri { parts["sri"] = (lnSRI(v) - lnSRI(81)) * k }
        if let v = w.steps { parts["steps"] = (lnSteps(v, age: inp.age) - lnSteps(7000, age: inp.age)) * k }
        if let m = w.moderate {
            let vig = w.vigorous ?? 0
            let eq: Double = m + 2 * vig
            let total: Double = (lnMVPA(eq) - lnMVPA(150)) * k
            let share: Double = eq > 0 ? m / eq : 0.5
            parts["moderate"] = total * share
            parts["vigorous"] = total * (1 - share)
        }
        if let v = w.strength { parts["strength"] = (lnStrength(v) - lnStrength(0)) * k }
        if let v = w.vo2 { parts["vo2"] = lnVO2(v, ref: vo2Reference(age: inp.age, female: inp.female)) * k }
        if let v = w.rhr { parts["rhr"] = lnRHR(v) * k }
        if let lbm = inp.leanMass, let h = inp.heightM, h > 1 { parts["lean"] = lnFFMI(lbm / (h * h), female: inp.female) * k }
        let total = max(-15, min(15, parts.values.reduce(0, +)))
        return (total, parts)
    }

    static func compute(_ inp: HealthspanInputs) -> Healthspan? {
        let long = window(inp, days: 180)
        guard long.days >= 21 else { return nil }
        let res = years(long, inp: inp)
        var pace: Double?
        if long.days >= 45 {
            let short = window(inp, days: 30)
            let y30 = years(short, inp: inp).total
            // Bleibt dein Verhalten wie in den letzten 30 Tagen, nähert sich das Form-Alter in ~6 Monaten diesem Wert an
            pace = max(-1, min(3, 1 + (y30 - res.total) / 0.5))
        }
        func r(_ key: String) -> Double { res.parts[key] ?? 0 }
        let age = inp.age
        var m: [HealthspanMetric] = []
        m.append(HealthspanMetric(name: "Schlafdauer", icon: "bed.double.fill",
                                  value: long.sleepH.map { Fmt.num($0, 1) + " h" } ?? "–", target: "7–8,5 h", years: r("sleep"),
                                  tip: "Unter 7 Stunden steigt das Risiko messbar. Feste Bettzeit hilft am meisten."))
        m.append(HealthspanMetric(name: "Schlafregelmäßigkeit", icon: "clock.arrow.circlepath",
                                  value: long.sri.map { Fmt.num($0) } ?? "–", target: "über 85", years: r("sri"),
                                  tip: "Regelmäßigkeit sagt Sterblichkeit stärker voraus als die Dauer. Gleiche Zeiten auch am Wochenende."))
        m.append(HealthspanMetric(name: "Schritte", icon: "figure.walk",
                                  value: long.steps.map { Fmt.num($0) + " / Tag" } ?? "–", target: age < 60 ? "8.000–10.000" : "6.000–8.000", years: r("steps"),
                                  tip: "Der Nutzen flacht ab etwa 8.000 bis 10.000 Schritten ab."))
        m.append(HealthspanMetric(name: "Moderate Aktivität", icon: "figure.run",
                                  value: long.moderate.map { Fmt.num($0) + " min/Wo" } ?? "–", target: "150–300 min", years: r("moderate"),
                                  tip: "Zählt Apples Trainingsminuten ohne die intensiven Workouts."))
        m.append(HealthspanMetric(name: "Intensive Aktivität", icon: "bolt.heart.fill",
                                  value: long.vigorous.map { Fmt.num($0) + " min/Wo" } ?? "–", target: "75–150 min", years: r("vigorous"),
                                  tip: "Workouts mit Durchschnittspuls über 77 % deines Maximalpulses. Zählen doppelt."))
        m.append(HealthspanMetric(name: "Krafttraining", icon: "dumbbell.fill",
                                  value: long.strength.map { Fmt.num($0) + " min/Wo" } ?? "–", target: "30–60 min", years: r("strength"),
                                  tip: "Der größte Effekt liegt bei 30 bis 60 Minuten pro Woche."))
        m.append(HealthspanMetric(name: "VO2max", icon: "lungs.fill",
                                  value: long.vo2.map { Fmt.num($0, 1) } ?? "–", target: "über " + Fmt.num(vo2Reference(age: age, female: inp.female) + 3.5, 0), years: r("vo2"),
                                  tip: "Stärkster Einzelfaktor. Jede 3,5 ml/kg/min mehr senkt das Sterberisiko um rund 13 %."))
        m.append(HealthspanMetric(name: "Ruhepuls", icon: "heart.fill",
                                  value: long.rhr.map { Fmt.num($0) + " bpm" } ?? "–", target: "unter 60", years: r("rhr"),
                                  tip: "Sinkt mit Ausdauertraining, gutem Schlaf und wenig Alkohol."))
        if res.parts["lean"] != nil, let lbm = inp.leanMass, let h = inp.heightM {
            m.append(HealthspanMetric(name: "Magermasse-Index", icon: "figure.strengthtraining.traditional",
                                      value: Fmt.num(lbm / (h * h), 1) + " kg/m²", target: inp.female ? "über 14,5" : "über 17", years: r("lean"),
                                      tip: "Fettfreie Masse geteilt durch Größe zum Quadrat. Braucht eine Körperfettwaage in Apple Health."))
        }
        return Healthspan(chronological: age, formAge: age + res.total, pace: pace, metrics: m, daysOfData: long.days)
    }
}

// MARK: Journal-Auswertung

struct JournalInsight: Identifiable {
    var id: String { behavior }
    let behavior: String
    let label: String
    let diff: Double        // Erholungspunkte ja minus nein
    let low: Double
    let high: Double
    let yes: Int
    let no: Int

    var significant: Bool { low > 0 || high < 0 }
}

enum JournalAnalysis {
    /// Erholung am Morgen danach, ja gegen nein, mit 95-%-Konfidenzintervall (Welch)
    static func insights(journal: [String: [String: Bool]], behaviors: [JournalBehavior], recoveryByDay: [Date: Int]) -> [JournalInsight] {
        let cal = Calendar.current
        let since = cal.addDays(-90, to: .now)
        var out: [JournalInsight] = []
        for b in behaviors {
            var yes: [Double] = [], no: [Double] = []
            for (key, answers) in journal {
                guard let day = JournalBehavior.date(key), day >= since, let a = answers[b.id] else { continue }
                guard let r = recoveryByDay[cal.addDays(1, to: day)] else { continue }
                if a { yes.append(Double(r)) } else { no.append(Double(r)) }
            }
            guard yes.count >= 5, no.count >= 5, let y = Analytics.meanSD(yes), let n = Analytics.meanSD(no) else { continue }
            let se: Double = sqrt(y.sd * y.sd / Double(yes.count) + n.sd * n.sd / Double(no.count))
            let d: Double = y.mean - n.mean
            out.append(JournalInsight(behavior: b.id, label: b.label, diff: d, low: d - 1.96 * se, high: d + 1.96 * se, yes: yes.count, no: no.count))
        }
        return out.sorted { abs($0.diff) > abs($1.diff) }
    }
}
