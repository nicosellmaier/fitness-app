import Foundation
import SwiftUI

// MARK: Grundtypen

enum RaceDistance: String, Codable, CaseIterable, Identifiable {
    case fiveK, tenK, half, marathon, ultra50

    var id: String { rawValue }

    var meters: Double {
        switch self {
        case .fiveK: return 5000
        case .tenK: return 10000
        case .half: return 21097.5
        case .marathon: return 42195
        case .ultra50: return 50000
        }
    }

    var label: String {
        switch self {
        case .fiveK: return "5 km"
        case .tenK: return "10 km"
        case .half: return "Halbmarathon"
        case .marathon: return "Marathon"
        case .ultra50: return "Ultra 50 km"
        }
    }

    var minWeeks: Int { [6, 8, 10, 14, 16][index] }
    var taperWeeks: Int { [1, 1, 2, 3, 2][index] }
    var peakKm: Double { [40, 50, 60, 75, 85][index] }
    var minStartKm: Double { [12, 18, 22, 28, 35][index] }
    var longCapKm: Double { [14, 18, 22, 32, 38][index] }
    var longShare: Double { [0.27, 0.28, 0.3, 0.32, 0.34][index] }

    private var index: Int { RaceDistance.allCases.firstIndex(of: self) ?? 0 }
}

enum PaceZone: String, Codable, CaseIterable {
    case recovery, easy, long, marathon, half, tenK, fiveK, threshold, interval, repetition, race

    var label: String {
        switch self {
        case .recovery: return "Trab"
        case .easy: return "Locker"
        case .long: return "Lang & locker"
        case .marathon: return "Marathontempo"
        case .half: return "HM-Tempo"
        case .tenK: return "10-km-Tempo"
        case .fiveK: return "5-km-Tempo"
        case .threshold: return "Schwelle"
        case .interval: return "Intervall"
        case .repetition: return "Sprint-Steigerung"
        case .race: return "Wettkampftempo"
        }
    }

    var isQuality: Bool { ![.recovery, .easy, .long].contains(self) }

    var color: Color {
        switch self {
        case .recovery, .easy, .long: return Theme.track
        case .marathon, .half, .race: return Theme.sleep
        case .tenK, .fiveK, .threshold: return Theme.warn
        case .interval, .repetition: return Theme.accent
        }
    }
}

enum RunType: String, Codable {
    case easy, long, recovery, strides, fartlek, intervals, threshold, racePace, shakeout, race, cross, rest

    var label: String {
        switch self {
        case .easy: return "Locker"
        case .long: return "Langer Lauf"
        case .recovery: return "Regeneration"
        case .strides: return "Locker + Steigerungen"
        case .fartlek: return "Fahrtspiel"
        case .intervals: return "Intervalle"
        case .threshold: return "Schwelle"
        case .racePace: return "Wettkampftempo"
        case .shakeout: return "Auflockern"
        case .race: return "Wettkampf"
        case .cross: return "Alternativtraining"
        case .rest: return "Pause"
        }
    }

    var isQuality: Bool { [.fartlek, .intervals, .threshold, .racePace, .race].contains(self) }

    var color: Color {
        switch self {
        case .intervals, .fartlek: return Theme.accent
        case .threshold: return Theme.warn
        case .racePace, .race: return Theme.sleep
        case .long: return Theme.good
        case .cross, .rest: return Theme.muted
        default: return Theme.soft
        }
    }

    var icon: String {
        switch self {
        case .cross: return "figure.outdoor.cycle"
        case .rest: return "bed.double.fill"
        case .race: return "flag.checkered"
        default: return "figure.run"
        }
    }
}

struct Segment: Codable, Hashable {
    var meters: Double? = nil
    var seconds: Double? = nil
    var zone: PaceZone

    static func km(_ km: Double, _ z: PaceZone) -> Segment { Segment(meters: km * 1000, zone: z) }
    static func m(_ m: Double, _ z: PaceZone) -> Segment { Segment(meters: m, zone: z) }
    static func min(_ min: Double, _ z: PaceZone) -> Segment { Segment(seconds: min * 60, zone: z) }
}

struct Block: Codable, Hashable {
    var repeats: Int
    var work: Segment
    var recovery: Segment? = nil
}

struct RunStructure: Codable, Hashable {
    var warmup: Segment? = nil
    var blocks: [Block] = []
    var cooldown: Segment? = nil

    static func steady(_ km: Double, _ z: PaceZone) -> RunStructure {
        RunStructure(blocks: [Block(repeats: 1, work: .km(km, z))])
    }

    var isEmpty: Bool { warmup == nil && blocks.isEmpty && cooldown == nil }
}

enum RunStatus: String, Codable {
    case planned, done, missed
}

struct PlannedRun: Identifiable, Codable, Hashable {
    var id = UUID()
    var date: Date
    var type: RunType
    var title: String
    var purpose: String
    var structure: RunStructure
    var status: RunStatus = .planned
    var adjusted: String? = nil
    var adjustKind: String? = nil
    var original: OriginalRun? = nil
    var workoutId: UUID? = nil
    var actualMeters: Double? = nil
    var actualSeconds: Double? = nil
    var actualHR: Double? = nil
    var evaluated = false
}

struct OriginalRun: Codable, Hashable {
    var type: RunType
    var title: String
    var purpose: String
    var structure: RunStructure
    var date: Date
}

struct PhaseSpan: Codable, Hashable, Identifiable {
    var id: String { name + String(start.timeIntervalSince1970) }
    var name: String
    var start: Date
    var end: Date
    var focus: String
}

struct PlanLogEntry: Codable, Hashable, Identifiable {
    var id = UUID()
    var date: Date
    var text: String
}

struct PlanSettings: Codable, Hashable {
    var distance: RaceDistance = .half
    var raceDate: Date = Calendar.current.addDays(84, to: .now)
    var raceName: String = ""
    var targetSeconds: Double? = nil
    var runDays: [Int] = [3, 4, 6, 1]        // Kalender-Wochentage: 1 = So, 2 = Mo, … 7 = Sa
    var longRunDay: Int = 1
    var strengthDays: [Int] = [2, 5]
    var startWeeklyKm: Double = 25
    var startVDOT: Double = 45
}

struct TrainingPlan: Codable {
    var settings: PlanSettings
    var vdot: Double
    var created: Date
    var runs: [PlannedRun]
    var phases: [PhaseSpan]
    var log: [PlanLogEntry] = []

    var paces: Paces { Paces(vdot: vdot, raceMeters: settings.distance.meters, raceTarget: settings.targetSeconds) }

    func run(on day: Date) -> PlannedRun? {
        runs.first { Calendar.current.isDate($0.date, inSameDayAs: day) }
    }

    func phase(on day: Date) -> PhaseSpan? {
        phases.first { day >= $0.start && day < Calendar.current.addDays(1, to: $0.end) }
    }

    var raceDay: Date { Calendar.current.startOfDay(for: settings.raceDate) }
    var weeksLeft: Int { max(0, Int(ceil(raceDay.timeIntervalSince(Calendar.current.startOfDay(for: .now)) / 86400 / 7))) }
}

// MARK: VDOT nach Daniels

enum VDOT {
    static func vo2(_ v: Double) -> Double { -4.60 + 0.182258 * v + 0.000104 * v * v }

    static func fraction(_ t: Double) -> Double {
        let a: Double = 0.1894393 * exp(-0.012778 * t)
        let b: Double = 0.2989558 * exp(-0.1932605 * t)
        return 0.8 + a + b
    }

    static func from(meters: Double, seconds: Double) -> Double {
        guard meters > 0, seconds > 0 else { return 0 }
        let t: Double = seconds / 60
        let v: Double = meters / t
        return vo2(v) / fraction(t)
    }

    /// Geschwindigkeit in m/min für eine Sauerstoffaufnahme
    static func velocity(vo2 target: Double) -> Double {
        let a: Double = 0.000104, b: Double = 0.182258
        let c: Double = -4.60 - target
        let disc: Double = b * b - 4 * a * c
        return (-b + sqrt(max(0, disc))) / (2 * a)
    }

    static func raceTime(meters: Double, vdot: Double) -> Double {
        var lo: Double = meters / 600
        var hi: Double = meters / 60
        for _ in 0..<60 {
            let mid: Double = (lo + hi) / 2
            if from(meters: meters, seconds: mid * 60) > vdot { lo = mid } else { hi = mid }
        }
        return (lo + hi) / 2 * 60
    }
}

struct Paces {
    let vdot: Double
    let raceMeters: Double
    let raceTarget: Double?

    private func atFraction(_ f: Double) -> Double { 60000 / VDOT.velocity(vo2: vdot * f) }
    private func race(_ m: Double) -> Double { VDOT.raceTime(meters: m, vdot: vdot) / (m / 1000) }

    /// Sekunden pro Kilometer
    func sec(_ z: PaceZone) -> Double {
        switch z {
        case .recovery: return atFraction(0.62)
        case .easy: return atFraction(0.70)
        case .long: return atFraction(0.68)
        case .marathon: return race(42195)
        case .half: return race(21097.5)
        case .tenK: return race(10000)
        case .fiveK: return race(5000)
        case .threshold: return atFraction(0.88)
        case .interval: return atFraction(0.98)
        case .repetition: return atFraction(1.06)
        case .race:
            if let t = raceTarget, t > 0 { return t / (raceMeters / 1000) }
            return race(raceMeters)
        }
    }

    func label(_ z: PaceZone) -> String {
        switch z {
        case .easy: return Fmt.pace(atFraction(0.74)) + "–" + Fmt.pace(atFraction(0.65)) + "/km"
        case .long: return Fmt.pace(atFraction(0.72)) + "–" + Fmt.pace(atFraction(0.65)) + "/km"
        case .recovery: return "locker traben"
        default: return Fmt.pace(sec(z)) + "/km"
        }
    }

    func meters(_ s: Segment) -> Double {
        if let m = s.meters { return m }
        if let t = s.seconds { return t / sec(s.zone) * 1000 }
        return 0
    }

    func seconds(_ s: Segment) -> Double {
        if let t = s.seconds { return t }
        if let m = s.meters { return m / 1000 * sec(s.zone) }
        return 0
    }

    func totalMeters(_ r: RunStructure) -> Double {
        var t: Double = 0
        if let w = r.warmup { t += meters(w) }
        for b in r.blocks {
            t += Double(b.repeats) * meters(b.work)
            if let rec = b.recovery { t += Double(max(0, b.repeats - 1)) * meters(rec) }
        }
        if let c = r.cooldown { t += meters(c) }
        return t
    }

    func totalSeconds(_ r: RunStructure) -> Double {
        var t: Double = 0
        if let w = r.warmup { t += seconds(w) }
        for b in r.blocks {
            t += Double(b.repeats) * seconds(b.work)
            if let rec = b.recovery { t += Double(max(0, b.repeats - 1)) * seconds(rec) }
        }
        if let c = r.cooldown { t += seconds(c) }
        return t
    }
}

// MARK: Plan erzeugen

enum PlanGenerator {
    enum Phase: Int {
        case base, build, specific, taper

        var name: String {
            switch self {
            case .base: return "Grundlage"
            case .build: return "Aufbau"
            case .specific: return "Spezifisch"
            case .taper: return "Tapering"
            }
        }

        var focus: String {
            switch self {
            case .base: return "Umfang aufbauen, Sehnen und Grundlagenausdauer stärken"
            case .build: return "VO2max und Laktatschwelle verbessern"
            case .specific: return "Wettkampftempo trainieren und festigen"
            case .taper: return "Umfang runter, Frische rauf"
            }
        }
    }

    static var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 2
        c.locale = Locale(identifier: "de_DE")
        return c
    }

    static func weekStart(_ d: Date) -> Date {
        cal.dateInterval(of: .weekOfYear, for: d)?.start ?? cal.startOfDay(for: d)
    }

    /// Wochentag-Reihenfolge ab Montag
    static let mondayFirst = [2, 3, 4, 5, 6, 7, 1]

    static func dayOffset(_ weekday: Int) -> Int { mondayFirst.firstIndex(of: weekday) ?? 0 }

    static func generate(settings s: PlanSettings, vdot: Double, today: Date = .now) -> TrainingPlan {
        let c = cal
        let todayStart = c.startOfDay(for: today)
        let raceDay = c.startOfDay(for: s.raceDate)
        let firstWeek = weekStart(todayStart)
        let raceWeek = weekStart(raceDay)
        let weeks = max(1, (c.dateComponents([.day], from: firstWeek, to: raceWeek).day ?? 0) / 7 + 1)
        let taper = min(s.distance.taperWeeks, max(0, weeks - 2))
        let trainWeeks = weeks - taper
        var base = max(1, Int((Double(trainWeeks) * 0.4).rounded()))
        var build = max(trainWeeks >= 3 ? 1 : 0, Int((Double(trainWeeks) * 0.35).rounded()))
        if base + build > trainWeeks { build = max(0, trainWeeks - base) }
        if base > trainWeeks { base = trainWeeks }
        let specific = max(0, trainWeeks - base - build)

        func phase(_ w: Int) -> Phase {
            if w >= trainWeeks { return .taper }
            if w < base { return .base }
            if w < base + build { return .build }
            return specific > 0 ? .specific : .build
        }

        // Wochenumfang
        let start = max(s.startWeeklyKm, s.distance.minStartKm * 0.8)
        let peak = max(start, min(s.distance.peakKm, start * 1.6))
        let taperFactors: [Double] = taper == 1 ? [0.55] : taper == 2 ? [0.7, 0.45] : [0.75, 0.6, 0.42]
        func volume(_ w: Int) -> Double {
            if w >= trainWeeks { return peak * taperFactors[min(taperFactors.count - 1, w - trainWeeks)] }
            let frac: Double = trainWeeks > 1 ? Double(w) / Double(trainWeeks - 1) : 1
            var v: Double = start + (peak - start) * frac
            if (w + 1) % 4 == 0 && w < trainWeeks - 1 { v *= 0.75 }
            return v
        }

        let runDays = mondayFirst.filter { s.runDays.contains($0) }
        let longDay = runDays.contains(s.longRunDay) ? s.longRunDay : (runDays.last ?? 1)

        var runs: [PlannedRun] = []
        var phaseCounters: [Phase: Int] = [:]
        var phases: [PhaseSpan] = []

        for w in 0..<weeks {
            let ws = c.date(byAdding: .day, value: 7 * w, to: firstWeek) ?? firstWeek
            let ph = phase(w)
            let pIndex = phaseCounters[ph, default: 0]
            phaseCounters[ph] = pIndex + 1
            let we = c.date(byAdding: .day, value: 6, to: ws) ?? ws
            if let last = phases.last, last.name == ph.name {
                phases[phases.count - 1].end = we
            } else {
                phases.append(PhaseSpan(name: ph.name, start: ws, end: we, focus: ph.focus))
            }
            let recoveryWeek = ph != .taper && (w + 1) % 4 == 0 && w < trainWeeks - 1
            let vol = volume(w)
            let isRaceWeek = w == weeks - 1

            // Rollen der Tage
            let others = runDays.filter { $0 != longDay }
            let dayBeforeLong = mondayFirst[(dayOffset(longDay) + 6) % 7]
            let q1Day = others.first(where: { [3, 4].contains($0) }) ?? others.first
            var q2Day: Int? = nil
            if others.count >= 3, let q1 = q1Day {
                q2Day = others.filter { $0 != q1 && $0 != dayBeforeLong && abs(dayOffset($0) - dayOffset(q1)) >= 2 }.last
            }

            var longKm: Double = min(s.distance.longCapKm, max(s.distance == .fiveK ? 6 : 8, vol * s.distance.longShare))
            if recoveryWeek { longKm *= 0.8 }
            if ph == .taper { longKm = min(longKm, vol * 0.38) }
            longKm = (longKm * 2).rounded() / 2

            var weekRuns: [(Int, PlannedRun)] = []
            let paces = Paces(vdot: vdot, raceMeters: s.distance.meters, raceTarget: s.targetSeconds)

            for wd in runDays {
                let date = c.date(byAdding: .day, value: dayOffset(wd), to: ws) ?? ws
                var run: PlannedRun
                if wd == longDay {
                    run = longRun(km: longKm, phase: ph, idx: pIndex, s: s, date: date)
                } else if wd == q1Day {
                    run = quality1(phase: ph, idx: pIndex, s: s, date: date, recoveryWeek: recoveryWeek, vol: vol)
                } else if isQ2(wd, q2Day, ph, recoveryWeek, pIndex) {
                    run = quality2(phase: ph, idx: pIndex, s: s, date: date)
                } else {
                    run = easy(km: 6, date: date)
                }
                weekRuns.append((wd, run))
            }
            // Lockere Läufe füllen den Rest des Wochenumfangs
            let fixedKm = weekRuns.filter { $0.1.type != .easy }.reduce(0.0) { $0 + paces.totalMeters($1.1.structure) / 1000 }
            let easyCount = weekRuns.filter { $0.1.type == .easy }.count
            if easyCount > 0 {
                var each: Double = max(5, (vol - fixedKm) / Double(easyCount))
                each = min(each, max(8, longKm * 0.7), 14)
                each = (each * 2).rounded() / 2
                for i in weekRuns.indices where weekRuns[i].1.type == .easy {
                    weekRuns[i].1 = easy(km: each, date: weekRuns[i].1.date)
                }
            }

            for (_, r) in weekRuns {
                if r.date < todayStart { continue }
                if r.date >= raceDay { continue }
                if isRaceWeek {
                    let daysToRace = c.dateComponents([.day], from: r.date, to: raceDay).day ?? 9
                    if daysToRace <= 1 { continue }
                    if daysToRace == 2 { runs.append(shakeout(date: r.date)); continue }
                }
                runs.append(r)
            }
            if isRaceWeek, raceDay >= todayStart {
                runs.append(race(s: s, date: raceDay))
            }
        }
        runs.sort { $0.date < $1.date }
        return TrainingPlan(settings: s, vdot: vdot, created: .now, runs: runs, phases: phases,
                            log: [PlanLogEntry(date: .now, text: "Plan erstellt: \(weeks) Wochen bis \(s.distance.label), Form-Wert \(Fmt.num(vdot, 1)).")])
    }

    static func isQ2(_ wd: Int, _ q2: Int?, _ ph: Phase, _ recoveryWeek: Bool, _ idx: Int) -> Bool {
        guard let q2, q2 == wd, !recoveryWeek else { return false }
        if ph == .base { return idx >= 2 }
        return true
    }

    // MARK: Einheiten

    static func easy(km: Double, date: Date) -> PlannedRun {
        PlannedRun(date: date, type: .easy, title: "Locker \(Fmt.num(km, km.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 1)) km",
                   purpose: "Grundlage und Erholung. Du solltest dich dabei unterhalten können.",
                   structure: .steady(km, .easy))
    }

    static func longRun(km: Double, phase: Phase, idx: Int, s: PlanSettings, date: Date) -> PlannedRun {
        let kmText = Fmt.num(km, km.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 1)
        let racey = s.distance == .marathon || s.distance == .half || s.distance == .ultra50
        if phase == .specific && racey && km >= 14 {
            let m: Double = s.distance == .half ? min(8, (km * 0.4).rounded()) : min(16, (km * 0.45).rounded())
            let st = RunStructure(warmup: .km(km - m - 1, .long), blocks: [Block(repeats: 1, work: .km(m, .race))], cooldown: .km(1, .easy))
            return PlannedRun(date: date, type: .long, title: "Langer Lauf \(kmText) km mit \(Fmt.num(m)) km Renntempo",
                              purpose: "Wettkampftempo auf müden Beinen. Genau das brauchst du am Renntag.", structure: st)
        }
        if phase == .build && racey && km >= 16 && idx % 2 == 1 {
            let st = RunStructure(warmup: .km(km - 3, .long), blocks: [Block(repeats: 1, work: .km(3, .marathon))])
            return PlannedRun(date: date, type: .long, title: "Langer Lauf \(kmText) km, Endbeschleunigung",
                              purpose: "Locker starten, die letzten 3 km zügig im Marathontempo.", structure: st)
        }
        return PlannedRun(date: date, type: .long, title: "Langer Lauf \(kmText) km",
                          purpose: "Ausdauer, Fettstoffwechsel und mentale Härte. Ruhig und gleichmäßig.",
                          structure: .steady(km, .long))
    }

    static func intervals(_ reps: Int, _ meters: Double, _ zone: PaceZone, title: String, purpose: String, date: Date, type: RunType = .intervals) -> PlannedRun {
        let rec: Segment = meters <= 800 ? .m(400, .recovery) : .min(meters >= 2000 ? 3 : 2, .recovery)
        let st = RunStructure(warmup: .km(2, .easy), blocks: [Block(repeats: reps, work: .m(meters, zone), recovery: rec)], cooldown: .km(1.5, .easy))
        return PlannedRun(date: date, type: type, title: title, purpose: purpose, structure: st)
    }

    static func timed(_ reps: Int, _ minutes: Double, _ zone: PaceZone, recMin: Double, title: String, purpose: String, date: Date, type: RunType) -> PlannedRun {
        let st = RunStructure(warmup: .km(2, .easy), blocks: [Block(repeats: reps, work: .min(minutes, zone), recovery: reps > 1 ? .min(recMin, .recovery) : nil)], cooldown: .km(1.5, .easy))
        return PlannedRun(date: date, type: type, title: title, purpose: purpose, structure: st)
    }

    static func distText(_ m: Double) -> String {
        m >= 1000 ? Fmt.num(m / 1000, m.truncatingRemainder(dividingBy: 1000) == 0 ? 0 : 1) + " km" : "\(Int(m)) m"
    }

    static func quality1(phase: Phase, idx: Int, s: PlanSettings, date: Date, recoveryWeek: Bool, vol: Double) -> PlannedRun {
        switch phase {
        case .base:
            let km: Double = max(5, min(9, (vol * 0.15).rounded()))
            let st = RunStructure(warmup: .km(km - 1, .easy), blocks: [Block(repeats: 6, work: .min(0.33, .repetition), recovery: .min(1, .recovery))], cooldown: .km(0.5, .easy))
            return PlannedRun(date: date, type: .strides, title: "Locker \(Fmt.num(km)) km + 6 Steigerungen",
                              purpose: "Lockerer Lauf mit kurzen, schnellen Steigerungen für Laufökonomie und Schnelligkeit.", structure: st)
        case .build:
            let list: [(Int, Double)] = [(5, 1000), (6, 800), (4, 1200), (5, 1000), (8, 600), (3, 1600)]
            var p = list[idx % list.count]
            if recoveryWeek { p.0 = max(3, p.0 - 2) }
            return intervals(p.0, p.1, .interval, title: "Intervalle \(p.0) × \(distText(p.1))",
                             purpose: "VO2max-Reiz: schnell, aber kontrolliert. Alle Wiederholungen gleich schnell.", date: date)
        case .specific:
            switch s.distance {
            case .fiveK:
                let list: [(Int, Double)] = [(6, 800), (5, 1000), (4, 1200)]
                let p = list[idx % list.count]
                return intervals(p.0, p.1, .race, title: "Renntempo \(p.0) × \(distText(p.1))", purpose: "5-km-Tempo festigen.", date: date, type: .racePace)
            case .tenK:
                let list: [(Int, Double)] = [(5, 1600), (4, 2000), (3, 3000)]
                let p = list[idx % list.count]
                return intervals(p.0, p.1, .race, title: "Renntempo \(p.0) × \(distText(p.1))", purpose: "10-km-Tempo festigen.", date: date, type: .racePace)
            default:
                let list: [(Int, Double)] = [(5, 1000), (4, 1600), (6, 800)]
                let p = list[idx % list.count]
                return intervals(p.0, p.1, .interval, title: "Intervalle \(p.0) × \(distText(p.1))",
                                 purpose: "VO2max halten, damit sich das Renntempo leichter anfühlt.", date: date)
            }
        case .taper:
            switch s.distance {
            case .fiveK, .tenK:
                return intervals(4, 800, .race, title: "Renntempo 4 × 800 m", purpose: "Kurz und knackig, Beine wach halten.", date: date, type: .racePace)
            default:
                return intervals(3, 1000, .race, title: "Renntempo 3 × 1 km", purpose: "Tempogefühl schärfen, ohne zu ermüden.", date: date, type: .racePace)
            }
        }
    }

    static func quality2(phase: Phase, idx: Int, s: PlanSettings, date: Date) -> PlannedRun {
        switch phase {
        case .base:
            return timed(8, 1, .tenK, recMin: 1, title: "Fahrtspiel 8 × 1 min", purpose: "Spielerisch Tempo machen, Pausen locker traben.", date: date, type: .fartlek)
        case .build, .taper:
            let list: [(Int, Double)] = [(3, 10), (2, 15), (4, 8), (1, 25)]
            let p = list[idx % list.count]
            let title = p.0 == 1 ? "Tempodauerlauf \(Int(p.1)) min" : "Schwelle \(p.0) × \(Int(p.1)) min"
            return timed(p.0, p.1, .threshold, recMin: 2, title: title,
                         purpose: "Laktatschwelle: anstrengend, aber kontrolliert. Du könntest kurze Sätze sprechen.", date: date, type: .threshold)
        case .specific:
            switch s.distance {
            case .half:
                let list: [(Int, Double)] = [(3, 3000), (2, 5000), (1, 10000)]
                let p = list[idx % list.count]
                let title = p.0 == 1 ? "Renntempo 10 km am Stück" : "Renntempo \(p.0) × \(distText(p.1))"
                return intervals(p.0, p.1, .race, title: title, purpose: "Halbmarathon-Tempo verinnerlichen.", date: date, type: .racePace)
            case .marathon, .ultra50:
                let km: Double = [10, 12, 14, 16][idx % 4]
                let st = RunStructure(warmup: .km(2, .easy), blocks: [Block(repeats: 1, work: .km(km, .race))], cooldown: .km(1.5, .easy))
                return PlannedRun(date: date, type: .racePace, title: "Renntempo \(Int(km)) km", purpose: "Marathontempo automatisieren, Verpflegung testen.", structure: st)
            default:
                return timed(3, 10, .threshold, recMin: 2, title: "Schwelle 3 × 10 min", purpose: "Laktatschwelle stabil halten.", date: date, type: .threshold)
            }
        }
    }

    static func shakeout(date: Date) -> PlannedRun {
        let st = RunStructure(warmup: .min(16, .easy), blocks: [Block(repeats: 4, work: .min(0.33, .repetition), recovery: .min(1, .recovery))])
        return PlannedRun(date: date, type: .shakeout, title: "Auflockern 20 min + 4 Steigerungen", purpose: "Beine wach machen, nicht müde.", structure: st)
    }

    static func race(s: PlanSettings, date: Date) -> PlannedRun {
        let name = s.raceName.isEmpty ? s.distance.label : s.raceName
        return PlannedRun(date: date, type: .race, title: "Wettkampf: \(name)", purpose: "Heute zählt's. Gleichmäßig starten, hinten raus Gas geben.",
                          structure: RunStructure(blocks: [Block(repeats: 1, work: .m(s.distance.meters, .race))]))
    }

    /// Form-Wert aus den letzten Läufen schätzen (ohne Ausreißer)
    static func estimateVDOT(workouts: [WorkoutItem], vo2max: Double?) -> Double {
        let since = Calendar.current.addDays(-56, to: .now)
        let values = workouts.filter { $0.activity == .running && $0.start >= since && ($0.distance ?? 0) >= 3000 }
            .compactMap { w -> Double? in
                guard let d = w.distance else { return nil }
                let v = VDOT.from(meters: d, seconds: w.duration)
                return v > 20 && v < 85 ? v : nil
            }
            .sorted(by: >)
        var best = values.prefix(2).reduce(0, +) / Double(max(1, min(2, values.count)))
        if values.isEmpty { best = 0 }
        // Normale Trainingsläufe sind nicht voll gelaufen
        let fromRuns = best > 0 ? best + 3 : 0
        let fromWatch = (vo2max ?? 0) * 0.9
        let est = max(fromRuns, fromWatch)
        return est > 25 ? (est * 2).rounded() / 2 : 42
    }

    static func recentWeeklyKm(workouts: [WorkoutItem]) -> Double {
        let since = Calendar.current.addDays(-28, to: .now)
        let km = workouts.filter { $0.activity == .running && $0.start >= since }.compactMap(\.distance).reduce(0, +) / 1000
        return (km / 4).rounded()
    }
}

// MARK: Live-Anpassung

enum PlanAdapter {
    static var cal: Calendar { Calendar.current }

    @discardableResult
    static func adapt(_ plan: inout TrainingPlan, workouts: [WorkoutItem], recovery: Recovery?, restrictions: Restrictions,
                      hrvLow: Bool = false, today: Date = .now) -> [String] {
        var notes: [String] = []
        let todayStart = cal.startOfDay(for: today)
        let runsDone = workouts.filter { $0.activity == .running }
        var linked = Set(plan.runs.compactMap(\.workoutId))

        // 1. Erledigte Läufe zuordnen, verpasste markieren
        for i in plan.runs.indices where plan.runs[i].status == .planned && plan.runs[i].date <= today {
            let day = plan.runs[i].date
            if let w = runsDone.first(where: { cal.isDate($0.start, inSameDayAs: day) && !linked.contains($0.id) }) {
                plan.runs[i].status = .done
                plan.runs[i].workoutId = w.id
                plan.runs[i].actualMeters = w.distance
                plan.runs[i].actualSeconds = w.duration
                plan.runs[i].actualHR = w.avgHR
                linked.insert(w.id)
            } else if day < todayStart && ![.rest, .cross].contains(plan.runs[i].type) {
                plan.runs[i].status = .missed
            }
        }

        // 2. Leistung auswerten: Form-Wert anpassen
        let paces = plan.paces
        for i in plan.runs.indices where plan.runs[i].status == .done && !plan.runs[i].evaluated {
            plan.runs[i].evaluated = true
            let r = plan.runs[i]
            guard let m = r.actualMeters, let s = r.actualSeconds, m > 1000 else { continue }
            if r.type == .race, abs(m - plan.settings.distance.meters) < plan.settings.distance.meters * 0.06 {
                let v = VDOT.from(meters: m, seconds: s)
                if v > 20 {
                    notes.append("Wettkampf ausgewertet: Form-Wert \(Fmt.num(plan.vdot, 1)) → \(Fmt.num(v, 1))")
                    plan.vdot = v
                }
                continue
            }
            guard r.type.isQuality else { continue }
            let expected = paces.totalSeconds(r.structure) / max(1, paces.totalMeters(r.structure) / 1000)
            let actual = s / (m / 1000)
            let ratio = actual / expected
            if ratio < 0.97 {
                let old = plan.vdot
                plan.vdot = min(old + 0.4, plan.settings.startVDOT + 6)
                notes.append("\(r.title) schneller als geplant: Paces etwas schneller (Form \(Fmt.num(old, 1)) → \(Fmt.num(plan.vdot, 1)))")
            } else if ratio > 1.05 {
                let old = plan.vdot
                plan.vdot = max(old - 0.4, plan.settings.startVDOT - 6)
                notes.append("\(r.title) war zäh: Paces etwas entschärft (Form \(Fmt.num(old, 1)) → \(Fmt.num(plan.vdot, 1)))")
            }
        }

        // 3. Einschränkungen durch Verletzung oder Krankheit
        let horizon = cal.addDays(restrictions.trainingPaused || !restrictions.runAllowed ? 7 : 3, to: todayStart)
        let reason = restrictions.reasons.joined(separator: ", ")
        for i in plan.runs.indices where plan.runs[i].status == .planned && plan.runs[i].date >= todayStart {
            let r = plan.runs[i]
            let inHorizon = r.date < horizon
            if r.adjustKind == "restriction" {
                // Wieder herstellen, wenn die Einschränkung weg ist
                let stillNeeded = inHorizon && (!restrictions.runAllowed || restrictions.trainingPaused || (restrictions.runEasyOnly && (r.original?.type.isQuality ?? false)))
                if !stillNeeded, let o = r.original {
                    plan.runs[i].type = o.type
                    plan.runs[i].title = o.title
                    plan.runs[i].purpose = o.purpose
                    plan.runs[i].structure = o.structure
                    plan.runs[i].adjusted = nil
                    plan.runs[i].adjustKind = nil
                    plan.runs[i].original = nil
                    notes.append("\(o.title) wieder im Plan")
                }
                continue
            }
            guard inHorizon, r.type != .race else { continue }
            if restrictions.trainingPaused {
                save(&plan.runs[i])
                plan.runs[i].type = .rest
                plan.runs[i].title = "Pause"
                plan.runs[i].purpose = "Krank trainieren verlängert die Pause. Erst gesund werden."
                plan.runs[i].structure = RunStructure()
                plan.runs[i].adjusted = "Wegen Krankheit pausiert"
                plan.runs[i].adjustKind = "restriction"
            } else if !restrictions.runAllowed {
                save(&plan.runs[i])
                let minutes: Double = r.type == .long ? 70 : 45
                plan.runs[i].type = .cross
                plan.runs[i].title = "Rad oder Schwimmen \(Int(minutes)) min"
                plan.runs[i].purpose = "Ausdauer erhalten, ohne die Verletzung zu belasten. Nur wenn es schmerzfrei geht."
                plan.runs[i].structure = RunStructure(blocks: [Block(repeats: 1, work: .min(minutes, .easy))])
                plan.runs[i].adjusted = "Wegen \(reason): Laufen pausiert"
                plan.runs[i].adjustKind = "restriction"
            } else if restrictions.runEasyOnly && r.type.isQuality {
                save(&plan.runs[i])
                let km = min(8, max(5, (paces.totalMeters(r.structure) / 1000).rounded()))
                let e = PlanGenerator.easy(km: km, date: r.date)
                plan.runs[i].type = .easy
                plan.runs[i].title = e.title
                plan.runs[i].purpose = e.purpose
                plan.runs[i].structure = e.structure
                plan.runs[i].adjusted = "Wegen \(reason): nur locker"
                plan.runs[i].adjustKind = "restriction"
            }
        }

        // 4. Tagesform: harte Einheit bei schlechter Erholung verschieben oder entschärfen
        if let rec = recovery, let ti = plan.runs.firstIndex(where: { cal.isDate($0.date, inSameDayAs: today) && $0.status == .planned && $0.adjustKind == nil }) {
            let r = plan.runs[ti]
            // Liegt der 7-Tage-HRV-Trend unter dem Normalbereich, wird höchstens moderat belastet (HRV-gesteuertes Training)
            let score = hrvLow ? min(rec.score, 45) : rec.score
            let why = hrvLow && rec.score > 45 ? "HRV-Trend unter Normalbereich" : "niedriger Erholung (\(rec.score))"
            if r.type.isQuality && r.type != .race {
                if score < 34 {
                    let longDays = Set(plan.runs.filter { $0.type == .long }.map { cal.startOfDay(for: $0.date) })
                    let swap = plan.runs.indices.first { (j: Int) -> Bool in
                        let d = plan.runs[j].date
                        let next = cal.addDays(1, to: cal.startOfDay(for: d))
                        return d > today && d < cal.addDays(4, to: todayStart) && plan.runs[j].type == .easy &&
                            plan.runs[j].status == .planned && !longDays.contains(next) && plan.runs[j].adjustKind == nil
                    }
                    if let j = swap {
                        let qDate = plan.runs[ti].date, eDate = plan.runs[j].date
                        plan.runs[ti].date = eDate
                        plan.runs[j].date = qDate
                        plan.runs[ti].adjusted = "Wegen \(why) verschoben"
                        plan.runs[ti].adjustKind = "recovery"
                        plan.runs[j].adjusted = "Getauscht: heute locker statt hart"
                        plan.runs[j].adjustKind = "recovery"
                        notes.append("\(r.title) auf \(Fmt.shortDay(eDate)) verschoben, heute locker")
                    } else {
                        save(&plan.runs[ti])
                        let e = PlanGenerator.easy(km: max(5, min(10, (paces.totalMeters(r.structure) / 1000).rounded())), date: r.date)
                        plan.runs[ti].type = .easy
                        plan.runs[ti].title = e.title
                        plan.runs[ti].purpose = e.purpose
                        plan.runs[ti].structure = e.structure
                        plan.runs[ti].adjusted = "Wegen \(why) nur locker"
                        plan.runs[ti].adjustKind = "recovery"
                        notes.append("\(r.title) heute nur locker")
                    }
                } else if score < 50 {
                    save(&plan.runs[ti])
                    var st = r.structure
                    for b in st.blocks.indices where st.blocks[b].repeats > 2 {
                        st.blocks[b].repeats = max(2, Int((Double(st.blocks[b].repeats) * 0.7).rounded()))
                    }
                    if st != r.structure {
                        plan.runs[ti].structure = st
                        plan.runs[ti].adjusted = hrvLow && rec.score > 45 ? "HRV-Trend unter Normalbereich: weniger Wiederholungen" : "Erholung nur \(rec.score): weniger Wiederholungen"
                        plan.runs[ti].adjustKind = "recovery"
                        notes.append("\(r.title): Umfang reduziert")
                    }
                }
            }
        }

        plan.runs.sort { $0.date < $1.date }
        for n in notes { plan.log.insert(PlanLogEntry(date: .now, text: n), at: 0) }
        if plan.log.count > 60 { plan.log = Array(plan.log.prefix(60)) }
        return notes
    }

    private static func save(_ r: inout PlannedRun) {
        if r.original == nil {
            r.original = OriginalRun(type: r.type, title: r.title, purpose: r.purpose, structure: r.structure, date: r.date)
        }
    }
}
