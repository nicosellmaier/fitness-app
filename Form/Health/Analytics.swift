import Foundation
import HealthKit
import CoreLocation
import SwiftUI

enum Analytics {
    static var cal: Calendar { Calendar.current }

    // MARK: Schlaf-Nächte aus Rohdaten bauen

    static func nights(from samples: [HKCategorySample]) -> [SleepNight] {
        var groups: [[HKCategorySample]] = []
        var current: [HKCategorySample] = []
        var lastEnd: Date?
        for s in samples.sorted(by: { $0.startDate < $1.startDate }) {
            if let le = lastEnd, s.startDate.timeIntervalSince(le) > 3 * 3600 {
                groups.append(current)
                current = []
            }
            current.append(s)
            lastEnd = max(lastEnd ?? s.endDate, s.endDate)
        }
        if !current.isEmpty { groups.append(current) }

        var byDay: [Date: SleepNight] = [:]
        for g in groups {
            guard let night = night(from: g) else { continue }
            if night.asleep < 3 * 3600 { continue }
            if let existing = byDay[night.wakeDay], existing.asleep >= night.asleep { continue }
            byDay[night.wakeDay] = night
        }
        return byDay.values.sorted { $0.wakeDay < $1.wakeDay }
    }

    private static func night(from g: [HKCategorySample]) -> SleepNight? {
        let staged: Set<Int> = [
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue,
        ]
        let hasStages = g.contains { staged.contains($0.value) }
        var segs: [SleepSegment] = []
        for s in g {
            let stage: SleepStage?
            switch s.value {
            case HKCategoryValueSleepAnalysis.awake.rawValue: stage = .awake
            case HKCategoryValueSleepAnalysis.asleepREM.rawValue: stage = .rem
            case HKCategoryValueSleepAnalysis.asleepDeep.rawValue: stage = .deep
            case HKCategoryValueSleepAnalysis.asleepCore.rawValue: stage = .core
            case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue: stage = hasStages ? nil : .core
            default: stage = nil
            }
            if let stage { segs.append(SleepSegment(start: s.startDate, end: s.endDate, stage: stage)) }
        }
        segs.sort { $0.start < $1.start }
        // Überlappungen (mehrere Quellen) entfernen
        var clean: [SleepSegment] = []
        for s in segs {
            if let last = clean.last, s.start < last.end {
                if s.end <= last.end { continue }
                clean.append(SleepSegment(start: last.end, end: s.end, stage: s.stage))
            } else {
                clean.append(s)
            }
        }
        guard let first = clean.first, let last = clean.last else { return nil }
        let inBed = g.filter { $0.value == HKCategoryValueSleepAnalysis.inBed.rawValue }.map(\.startDate).min() ?? first.start
        return SleepNight(wakeDay: cal.dayStart(last.end), inBedStart: min(inBed, first.start), segments: clean, hasStages: hasStages)
    }

    // MARK: Tageswerte

    static func days(count: Int, nights: [SleepNight], hrv: [HKQuantitySample], rhr: [HKQuantitySample],
                     resp: [HKQuantitySample], spo2: [HKQuantitySample], temp: [HKQuantitySample],
                     rmssd: [(date: Date, ms: Double)] = [], steps: [Date: Double] = [:], exercise: [Date: Double] = [:]) -> [DayMetrics] {
        let today = cal.dayStart(.now)
        var out: [DayMetrics] = []
        let nightBy = Dictionary(nights.map { ($0.wakeDay, $0) }, uniquingKeysWith: { a, _ in a })
        func vals(_ s: [HKQuantitySample], _ unit: HKUnit, _ a: Date, _ b: Date) -> [Double] {
            s.filter { $0.startDate >= a && $0.startDate < b }.map { $0.quantity.doubleValue(for: unit) }
        }
        func mean(_ v: [Double]) -> Double? { v.isEmpty ? nil : v.reduce(0, +) / Double(v.count) }
        for i in stride(from: count - 1, through: 0, by: -1) {
            let day = cal.addDays(-i, to: today)
            let next = cal.addDays(1, to: day)
            var m = DayMetrics(day: day)
            let n = nightBy[day]
            m.sleep = n
            let (a, b): (Date, Date) = n.map { ($0.start.addingTimeInterval(-1800), $0.end.addingTimeInterval(600)) } ?? (day, next)
            m.hrv = mean(vals(hrv, HealthService.ms, a, b)) ?? mean(vals(hrv, HealthService.ms, day, next))
            m.rhr = vals(rhr, HealthService.bpm, day, next).last
            m.resp = mean(vals(resp, HealthService.bpm, a, b))
            let sp = vals(spo2, .percent(), a, b)
            m.spo2 = mean(sp)
            m.spo2Min = sp.min()
            m.temp = temp.filter { cal.isDate($0.endDate, inSameDayAs: day) }.last?.quantity.doubleValue(for: .degreeCelsius())
            if n != nil {
                let r = rmssd.filter { $0.date >= a && $0.date < b }.map(\.ms).sorted()
                if r.count >= 2 { m.rmssd = r[r.count / 2] }
            }
            m.steps = steps[day]
            m.exerciseMin = exercise[day]
            out.append(m)
        }
        return out
    }

    // MARK: Statistik

    static func meanSD(_ v: [Double]) -> (mean: Double, sd: Double)? {
        guard v.count >= 4 else { return nil }
        let m = v.reduce(0, +) / Double(v.count)
        let sd = sqrt(v.map { ($0 - m) * ($0 - m) }.reduce(0, +) / Double(v.count - 1))
        return (m, max(sd, 0.0001))
    }

    static func baseline(_ days: [DayMetrics], before i: Int, _ key: KeyPath<DayMetrics, Double?>) -> (mean: Double, sd: Double)? {
        meanSD(days[max(0, i - 30)..<i].compactMap { $0[keyPath: key] })
    }

    // MARK: Erholung

    static func recovery(days: [DayMetrics], index i: Int, need: TimeInterval) -> Recovery? {
        guard days.indices.contains(i) else { return nil }
        let d = days[i]
        guard d.hrv != nil || d.sleep != nil else { return nil }
        var score = 55.0
        var parts: [String] = []
        var hrvDelta: Double?
        var rhrDelta: Double?
        let prev = days[max(0, i - 30)..<i]
        // RMSSD aus Schlag-zu-Schlag-Daten bevorzugen, sonst Apples SDNN. Baseline immer mit derselben Größe.
        let rmssdBase = prev.compactMap { $0.rmssd.map { log($0) } }
        let useR = d.rmssd != nil && rmssdBase.count >= 7
        let hrvToday: Double? = useR ? d.rmssd : d.hrv
        let hrvBase: [Double] = useR ? rmssdBase : prev.compactMap { $0.hrv.map { log($0) } }
        if let h = hrvToday, let b = meanSD(hrvBase) {
            let z = max(-3, min(3, (log(h) - b.mean) / b.sd))
            score += 13 * z
            hrvDelta = h - exp(b.mean)
            parts.append(z > 0.4 ? "HRV über deinem Schnitt" : z < -0.4 ? "HRV unter deinem Schnitt" : "HRV im normalen Bereich")
        }
        if let r = d.rhr, let b = baseline(days, before: i, \.rhr) {
            let z = max(-3, min(3, (r - b.mean) / b.sd))
            score -= 8 * z
            rhrDelta = r - b.mean
            parts.append(z > 0.7 ? "Ruhepuls erhöht" : z < -0.5 ? "Ruhepuls niedrig" : "Ruhepuls stabil")
        }
        if let s = d.sleep {
            let perf = min(1.1, s.asleep / max(1, need))
            score += 35 * (perf - 0.88)
            if perf < 0.8 { parts.append("zu wenig Schlaf") }
        }
        if let rr = d.resp, let b = baseline(days, before: i, \.resp) {
            let z = (rr - b.mean) / b.sd
            if z > 1.5 { score -= 6 * (z - 1); parts.append("Atemfrequenz erhöht") }
        }
        if let t = d.temp, let b = baseline(days, before: i, \.temp) {
            let dev = t - b.mean
            if dev > 0.4 { score -= min(12, 20 * (dev - 0.3)); parts.append("Temperatur erhöht") }
        }
        let sc = Int(max(1, min(99, score.rounded())))
        let label: String
        let color: Color
        if sc >= 67 { label = "Bereit für Intensität"; color = Theme.good }
        else if sc >= 34 { label = "Moderat belasten"; color = Theme.warn }
        else { label = "Erholung priorisieren"; color = Theme.bad }
        let text = parts.isEmpty ? "Noch zu wenig Daten für eine genaue Einschätzung. Nach ein paar Nächten wird es genauer." : parts.joined(separator: ", ").capitalizedFirst + "."
        return Recovery(score: sc, label: label, color: color, text: text, hrvDelta: hrvDelta, rhrDelta: rhrDelta)
    }

    // MARK: Belastung (0 bis 21)

    static func strainTarget(_ r: Recovery?) -> ClosedRange<Double> { Strain.target(r) }

    // MARK: Schlafbedarf und -score

    static func sleepNeed(nights: [SleepNight], base: TimeInterval, strainToday: Double) -> SleepNeed {
        let weekly = nights.suffix(7).reduce(0) { $0 + max(0, base - $1.asleep) }
        let debt = min(45 * 60, weekly / 4)
        let strain = min(45 * 60, strainToday / 21 * 45 * 60)
        return SleepNeed(base: base, strain: strain, debt: debt, weeklyDebt: weekly)
    }

    /// Minuten seit 12 Uhr mittags, damit Zeiten um Mitternacht vergleichbar sind
    static func noonMinutes(_ d: Date) -> Double {
        let c = cal.dateComponents([.hour, .minute], from: d)
        return Double(((c.hour ?? 0) * 60 + (c.minute ?? 0) + 12 * 60) % 1440)
    }

    static func sleepScore(_ n: SleepNight, need: TimeInterval, recent: [SleepNight]) -> Int {
        let dur = min(1, n.asleep / max(1, need)) * 50
        let eff = max(0, min(1, (n.efficiency - 0.75) / 0.2)) * 20
        var q = 14.0
        if n.hasStages, n.asleep > 0 {
            let deepShare: Double = min(1, n.time(.deep) / n.asleep / 0.15)
            let remShare: Double = min(1, n.time(.rem) / n.asleep / 0.21)
            q = (deepShare + remShare) / 2 * 20
        }
        var cons = 8.0
        let beds = recent.map { noonMinutes($0.bedTime) }
        if beds.count >= 3 {
            let med = beds.sorted()[beds.count / 2]
            cons = max(0, 1 - abs(noonMinutes(n.bedTime) - med) / 90) * 10
        }
        return Int(max(0, min(100, (dur + eff + q + cons).rounded())))
    }

    /// Schlafregelmäßigkeit als Sleep Regularity Index der letzten 7 Tage
    static func consistency(_ nights: [SleepNight]) -> Int? {
        SleepRegularity.sri(nights, days: 7).map { Int(max(0, $0).rounded()) }
    }

    static func bedtime(nights: [SleepNight], need: TimeInterval) -> Date? {
        let wakes = nights.suffix(7).map { noonMinutes($0.end) }.sorted()
        guard !wakes.isEmpty else { return nil }
        let wakeMin = (wakes[wakes.count / 2] + 12 * 60).truncatingRemainder(dividingBy: 1440)
        let tomorrow = cal.addDays(1, to: cal.dayStart(.now))
        let wake = tomorrow.addingTimeInterval(wakeMin * 60)
        return wake.addingTimeInterval(-need - 15 * 60)
    }

    static func wakeTarget(nights: [SleepNight]) -> Date? {
        let wakes = nights.suffix(7).map { noonMinutes($0.end) }.sorted()
        guard !wakes.isEmpty else { return nil }
        let wakeMin = (wakes[wakes.count / 2] + 12 * 60).truncatingRemainder(dividingBy: 1440)
        return cal.addDays(1, to: cal.dayStart(.now)).addingTimeInterval(wakeMin * 60)
    }

    // MARK: Workout-Details

    static func zone(_ bpm: Double, maxHR: Double) -> Int {
        let p = bpm / maxHR
        if p < 0.6 { return 0 }
        if p < 0.7 { return 1 }
        if p < 0.8 { return 2 }
        if p < 0.9 { return 3 }
        return 4
    }

    static func fill(_ det: inout WorkoutDetail, item: WorkoutItem, maxHR: Double) {
        // Herzfrequenz-Zonen
        var zones = Array(repeating: 0.0, count: 5)
        for (i, p) in det.hr.enumerated() {
            let next = i + 1 < det.hr.count ? det.hr[i + 1].date : item.end
            let dt = min(30, max(0, next.timeIntervalSince(p.date)))
            zones[zone(p.bpm, maxHR: maxHR)] += dt
        }
        det.zones = zones

        // Splits und Höhenprofil aus der Route
        let locs = det.route
        guard locs.count > 2 else { return }
        var dist = 0.0
        var splitStart = locs[0].timestamp
        var splitDist = 0.0
        var gain = 0.0
        var splits: [Split] = []
        var profile: [ProfilePoint] = [ProfilePoint(distance: 0, altitude: locs[0].altitude)]
        var lastProfile = 0.0
        for i in 1..<locs.count {
            let a = locs[i - 1], b = locs[i]
            let d = b.distance(from: a)
            if d > 200 { continue }
            dist += d
            splitDist += d
            let dh = b.altitude - a.altitude
            if dh > 0.3 { gain += dh }
            if dist - lastProfile >= 50 {
                profile.append(ProfilePoint(distance: dist, altitude: b.altitude))
                lastProfile = dist
            }
            if splitDist >= 1000 {
                let hr = avgHR(det.hr, from: splitStart, to: b.timestamp)
                splits.append(Split(id: splits.count + 1, distance: splitDist, duration: b.timestamp.timeIntervalSince(splitStart), avgHR: hr, gain: gain))
                splitStart = b.timestamp
                splitDist = 0
                gain = 0
            }
        }
        if splitDist > 100, let last = locs.last {
            splits.append(Split(id: splits.count + 1, distance: splitDist, duration: last.timestamp.timeIntervalSince(splitStart),
                                avgHR: avgHR(det.hr, from: splitStart, to: last.timestamp), gain: gain))
        }
        det.splits = splits
        det.profile = profile
        if det.cadence == nil, let stride = det.stride, stride > 0, let d = item.distance, item.duration > 0 {
            det.cadence = (d / item.duration) / stride * 60
        }
    }

    static func avgHR(_ hr: [HRPoint], from a: Date, to b: Date) -> Double? {
        let v = hr.filter { $0.date >= a && $0.date <= b }.map(\.bpm)
        return v.isEmpty ? nil : v.reduce(0, +) / Double(v.count)
    }
}
