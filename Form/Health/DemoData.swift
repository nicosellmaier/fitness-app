import Foundation
import HealthKit
import CoreLocation

/// Erfundene, aber plausible Daten, damit die App ohne Apple-Health-Daten (z.B. im Simulator) etwas zeigt.
enum DemoData {
    struct RNG {
        var s: UInt64
        mutating func next() -> Double {
            s = s &* 6364136223846793005 &+ 1442695040888963407
            return Double(s >> 11) / Double(UInt64(1) << 53)
        }
        mutating func range(_ a: Double, _ b: Double) -> Double { a + (b - a) * next() }
    }

    static var cal: Calendar { Calendar.current }

    static func nights(count: Int = 40) -> [SleepNight] {
        var rng = RNG(s: 42)
        let today = cal.dayStart(.now)
        var out: [SleepNight] = []
        for i in stride(from: count - 1, through: 0, by: -1) {
            let wakeDay = cal.addDays(-i, to: today)
            let prevDay = cal.addDays(-1, to: wakeDay)
            let wd = cal.component(.weekday, from: wakeDay)
            let weekend = wd == 1 || wd == 7
            let baseBed: Double = weekend ? 1480 : 1390
            let bedMin: Double = baseBed + rng.range(-35, 35)
            let bed = prevDay.addingTimeInterval(bedMin * 60)
            var t = bed
            var segs: [SleepSegment] = []
            func add(_ minutes: Double, _ s: SleepStage) {
                let e = t.addingTimeInterval(minutes * 60)
                segs.append(SleepSegment(start: t, end: e, stage: s))
                t = e
            }
            add(rng.range(4, 14), .awake)
            let target = rng.range(6.9, 8.1) * 3600
            var cycle = 0
            while t.timeIntervalSince(bed) < target {
                let late = Double(cycle) / 5
                add(rng.range(12, 22), .core)
                add(max(4, rng.range(28, 42) * (1 - late)), .deep)
                add(rng.range(10, 18), .core)
                add(rng.range(12, 22) * (1 + late), .rem)
                if rng.next() < 0.35 { add(rng.range(2, 7), .awake) }
                cycle += 1
            }
            add(rng.range(2, 6), .awake)
            out.append(SleepNight(wakeDay: wakeDay, inBedStart: bed, segments: segs, hasStages: true))
        }
        return out
    }

    static func days(nights: [SleepNight], steps: [Date: Double] = [:], exercise: [Date: Double] = [:]) -> [DayMetrics] {
        var rng = RNG(s: 7)
        let byDay = Dictionary(nights.map { ($0.wakeDay, $0) }, uniquingKeysWith: { a, _ in a })
        let today = cal.dayStart(.now)
        var out: [DayMetrics] = []
        for i in stride(from: 89, through: 0, by: -1) {
            let day = cal.addDays(-i, to: today)
            var m = DayMetrics(day: day)
            m.sleep = byDay[day]
            let trend: Double = Double(89 - i) * 0.055
            let wd = cal.component(.weekday, from: day)
            let afterHard: Double = wd == 5 || wd == 1 ? -5 : 0    // Tag nach Intervallen bzw. langem Lauf
            let hrv: Double = i == 0 ? 68 : 55 + trend + afterHard + rng.range(-8, 8)
            m.hrv = hrv
            m.rmssd = hrv * 1.32 + rng.range(-3, 3)
            m.rhr = i == 0 ? 46 : 49.5 - trend * 0.06 - afterHard * 0.2 + rng.range(-1.8, 1.8)
            m.resp = 13.9 + rng.range(-0.4, 0.4)
            m.spo2 = rng.range(0.955, 0.98)
            m.spo2Min = (m.spo2 ?? 0.96) - rng.range(0.01, 0.025)
            m.temp = 34.1 + rng.range(-0.15, 0.15)
            m.steps = steps[day]
            m.exerciseMin = exercise[day]
            out.append(m)
        }
        return out
    }

    static func steps() -> [Date: Double] {
        var rng = RNG(s: 21)
        let today = cal.dayStart(.now)
        var out: [Date: Double] = [:]
        for i in 0..<185 {
            let d = cal.addDays(-i, to: today)
            let recent: Double = i < 30 ? 900 : 0
            out[d] = i == 0 ? 6450 : 8200 + recent + rng.range(-2600, 3200)
        }
        return out
    }

    static func exercise() -> [Date: Double] {
        var rng = RNG(s: 23)
        let today = cal.dayStart(.now)
        var out: [Date: Double] = [:]
        for i in 0..<185 {
            let d = cal.addDays(-i, to: today)
            let wd = cal.component(.weekday, from: d)
            let base: Double = [1: 95, 2: 55, 3: 50, 4: 60, 5: 48, 6: 46, 7: 62][wd] ?? 40
            out[d] = i == 0 ? 22 : base + rng.range(-12, 12)
        }
        return out
    }

    /// Puls über den Tag für Stress und Belastung (letzte 14 Tage, alle 5 Minuten, im Workout alle 10 Sekunden)
    static func dayHR(workouts: [WorkoutItem], nights: [SleepNight]) -> [HRPoint] {
        var rng = RNG(s: 31)
        let start = cal.addDays(-14, to: cal.dayStart(.now))
        var out: [HRPoint] = []
        var t = start
        while t < .now {
            let h = Double(cal.component(.hour, from: t)) + Double(cal.component(.minute, from: t)) / 60
            if let w = workouts.first(where: { t >= $0.start && t < $0.end }) {
                var u = t
                while u < min(w.end, t.addingTimeInterval(300)) {
                    let f: Double = u.timeIntervalSince(w.start) / max(1, w.duration)
                    let avg: Double = w.avgHR ?? 140
                    out.append(HRPoint(date: u, bpm: avg * (0.85 + 0.15 * min(1, f * 6)) + 5 * sin(f * 25) + rng.range(-2, 2)))
                    u = u.addingTimeInterval(10)
                }
            } else if nights.contains(where: { t >= $0.start && t <= $0.end }) {
                out.append(HRPoint(date: t, bpm: 47 + rng.range(-3, 4)))
            } else {
                // Tagsüber: Arbeit am Schreibtisch, Wege, nachmittags ein Stressfenster
                let meeting: Double = h > 13.5 && h < 15.5 ? 14 : 0
                let commute: Double = (h > 7.5 && h < 8.2) || (h > 17.3 && h < 18) ? 22 : 0
                let bpm: Double = 62 + 6 * sin((h - 6) / 24 * 2 * .pi) + meeting + commute + rng.range(-5, 7)
                out.append(HRPoint(date: t, bpm: bpm))
            }
            t = t.addingTimeInterval(300)
        }
        return out
    }

    static func stepSamples() -> [StepSample] {
        let start = cal.addDays(-14, to: cal.dayStart(.now))
        var out: [StepSample] = []
        var t = start
        while t < .now {
            let h = Double(cal.component(.hour, from: t)) + Double(cal.component(.minute, from: t)) / 60
            if (h > 7.5 && h < 8.2) || (h > 17.3 && h < 18) {
                out.append(StepSample(start: t, end: t.addingTimeInterval(600), count: 1050))
            } else if h > 8 && h < 22 {
                out.append(StepSample(start: t, end: t.addingTimeInterval(600), count: 60))
            }
            t = t.addingTimeInterval(600)
        }
        return out
    }

    static func vo2() -> [Point] {
        var rng = RNG(s: 9)
        let today = cal.dayStart(.now)
        return stride(from: 120, through: 0, by: -6).map { i in
            let v: Double = 51.4 + Double(120 - i) / 120 * 2.8 + rng.range(-0.3, 0.3)
            return Point(date: cal.addDays(-i, to: today), value: v)
        }
    }

    static func workouts() -> [WorkoutItem] {
        var rng = RNG(s: 3)
        let today = cal.dayStart(.now)
        var out: [WorkoutItem] = []
        for i in 1...180 {
            let day = cal.addDays(-i, to: today)
            let wd = cal.component(.weekday, from: day) // 1 = So
            let plan: (HKWorkoutActivityType, Double, Double, Double, Double)? // typ, km, pace s/km, HR, Stunde
            switch wd {
            case 2: plan = (.running, 10, 312, 141, 7)
            case 3: plan = (.traditionalStrengthTraining, 0, 0, 118, 18)
            case 4: plan = (.running, 9.6, 285, 158, 18)
            case 5: plan = (.running, 8, 318, 139, 7)
            case 6: plan = (.traditionalStrengthTraining, 0, 0, 115, 17)
            case 7: plan = (.running, 12, 268, 162, 9)
            case 1: plan = (.running, 20 + Double(i % 3) * 2, 318, 146, 9)
            default: plan = nil
            }
            guard let p = plan else { continue }
            let start = day.addingTimeInterval(p.4 * 3600 + rng.range(0, 1800))
            let isRun = p.0 == .running
            let dist = isRun ? p.1 * 1000 * rng.range(0.98, 1.03) : nil
            let dur = isRun ? (dist! / 1000) * p.2 * rng.range(0.98, 1.02) : rng.range(48, 62) * 60
            out.append(WorkoutItem(
                id: UUID(), workout: nil, activity: p.0, kind: WorkoutItem.kind(for: p.0, distance: dist),
                name: WorkoutItem.name(for: p.0, start: start), start: start, end: start.addingTimeInterval(dur),
                duration: dur, distance: dist, energy: dur / 60 * (isRun ? 12.5 : 7), avgHR: p.3 + rng.range(-3, 3),
                maxHR: p.3 + rng.range(14, 24), elevation: isRun ? (dist! / 1000) * rng.range(6, 10) : nil, indoor: !isRun
            ))
        }
        return out.sorted { $0.start > $1.start }
    }

    static func detail(for item: WorkoutItem, maxHR: Double) -> WorkoutDetail {
        var rng = RNG(s: UInt64(abs(item.start.timeIntervalSince1970.rounded())))
        var det = WorkoutDetail()
        let n = max(2, Int(item.duration / 5))
        if let dist = item.distance, dist > 0 {
            // Schleife entlang der Wertach in Augsburg
            let centerLat = 48.3575, centerLon = 10.8745
            let rLat = dist / 1000 * 0.00142, rLon = dist / 1000 * 0.00213
            for k in 0..<n {
                let f = Double(k) / Double(n - 1)
                let a = f * 2 * .pi
                let wobble: Double = 1 + 0.12 * sin(a * 3) + rng.range(-0.004, 0.004)
                let lat: Double = centerLat + rLat * sin(a) * wobble
                let lon: Double = centerLon + rLon * (cos(a) - 1) * wobble
                let alt: Double = 480 + 9 * sin(a * 2) + rng.range(-0.4, 0.4)
                det.route.append(CLLocation(coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon), altitude: alt,
                                            horizontalAccuracy: 4, verticalAccuracy: 3,
                                            timestamp: item.start.addingTimeInterval(item.duration * f)))
            }
            det.power = 245 + rng.range(-10, 10)
            det.groundContact = 240 + rng.range(-8, 8)
            det.verticalOsc = 8.4 + rng.range(-0.4, 0.4)
            det.stride = 1.12 + rng.range(-0.05, 0.05)
            det.cadence = 172 + rng.range(-3, 3)
        }
        let avg = item.avgHR ?? 130
        for k in 0..<n {
            let f = Double(k) / Double(max(1, n - 1))
            let warm = min(1, f * 6)
            let base: Double = avg * (0.82 + 0.18 * warm)
            let wave: Double = 6 * sin(f * 30)
            let bpm: Double = base + wave + rng.range(-2, 2)
            det.hr.append(HRPoint(date: item.start.addingTimeInterval(item.duration * f), bpm: bpm))
        }
        Analytics.fill(&det, item: item, maxHR: maxHR)
        return det
    }

    static func sleepHR(for n: SleepNight) -> [HRPoint] {
        var rng = RNG(s: 11)
        let total = n.end.timeIntervalSince(n.start)
        return stride(from: 0.0, through: total, by: 300).map { t in
            let f = t / max(1, total)
            let dip: Double = 14 * sin(min(1.0, f * 1.6) * Double.pi / 2)
            let rise: Double = 8 * max(0.0, f - 0.7)
            let bpm: Double = 57 - dip + rise + rng.range(-1.5, 1.5)
            return HRPoint(date: n.start.addingTimeInterval(t), bpm: bpm)
        }
    }
}
