import Foundation
import SwiftUI

// Schlafplan wie bei Rise: Weckzeit aus deinem Tag, Schlafenszeit aus Bedarf und innerer Uhr.
// Formeln und Quellen: docs/WISSENSCHAFT.md, Abschnitt 12.

struct SleepPrefs: Codable, Hashable {
    /// Minuten zwischen Aufwachen und erstem Termin (Morgenroutine plus Weg)
    var prepMinutes: Int = 60
    var useCalendar = true
    /// Leere Liste = alle Kalender
    var calendarIDs: [String] = []
    /// Feste Weckzeiten je Kalender-Wochentag (1 = So … 7 = Sa) in Minuten nach Mitternacht
    var fixedWake: [Int: Int] = [:]
    /// Weckzeit für einen bestimmten Tag (yyyy-MM-dd) von Hand überschrieben
    var wakeOverride: [String: Int] = [:]
    var autoAlarm = false
    var remindCaffeine = true
    var remindWindDown = true
    var remindMorningLight = false

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = SleepPrefs()
        prepMinutes = (try? c.decodeIfPresent(Int.self, forKey: .prepMinutes)) ?? d.prepMinutes
        useCalendar = (try? c.decodeIfPresent(Bool.self, forKey: .useCalendar)) ?? d.useCalendar
        calendarIDs = (try? c.decodeIfPresent([String].self, forKey: .calendarIDs)) ?? d.calendarIDs
        fixedWake = (try? c.decodeIfPresent([Int: Int].self, forKey: .fixedWake)) ?? d.fixedWake
        wakeOverride = (try? c.decodeIfPresent([String: Int].self, forKey: .wakeOverride)) ?? d.wakeOverride
        autoAlarm = (try? c.decodeIfPresent(Bool.self, forKey: .autoAlarm)) ?? d.autoAlarm
        remindCaffeine = (try? c.decodeIfPresent(Bool.self, forKey: .remindCaffeine)) ?? d.remindCaffeine
        remindWindDown = (try? c.decodeIfPresent(Bool.self, forKey: .remindWindDown)) ?? d.remindWindDown
        remindMorningLight = (try? c.decodeIfPresent(Bool.self, forKey: .remindMorningLight)) ?? d.remindMorningLight
    }
}

struct CalendarEvent: Hashable {
    let title: String
    let start: Date
}

struct PlanStep: Identifiable {
    let id = UUID()
    let time: Date
    let end: Date?
    let title: String
    let detail: String
    let icon: String
    let color: Color
}

struct EnergyPoint: Identifiable {
    let id = UUID()
    let date: Date
    let level: Double   // 0 bis 100
}

struct SleepPlan {
    enum Source { case override, fixed, calendar(CalendarEvent), habit }

    let bedtime: Date
    let wake: Date
    let need: TimeInterval
    let planned: TimeInterval          // geplante Schlafzeit
    let extra: TimeInterval            // Einschlafen und Wachphasen
    let source: Source
    let reasons: [String]
    let sleepGate: ClosedRange<Date>   // Schlaffenster der inneren Uhr
    let clampedEarly: Bool
    let hardTomorrow: String?

    var windDown: Date { bedtime.addingTimeInterval(-3600) }
    /// Koffein: mindestens 8,8 h vor dem Schlafen (Gardiner 2023), gerundet auf volle Viertelstunde davor
    var caffeineCutoff: Date { SleepPlanner.floor15(bedtime.addingTimeInterval(-8.8 * 3600)) }
    var lastMeal: Date { bedtime.addingTimeInterval(-3 * 3600) }
    var lastAlcohol: Date { bedtime.addingTimeInterval(-3 * 3600) }
    var lastHardTraining: Date { bedtime.addingTimeInterval(-3600) }

    var sourceText: String {
        switch source {
        case .override: return "Von dir festgelegt"
        case .fixed: return "Feste Weckzeit für diesen Wochentag"
        case .calendar(let e): return "Erster Termin: \(e.title) um \(Fmt.time(e.start))"
        case .habit: return "Deine übliche Aufstehzeit"
        }
    }
}

struct SleepDebt {
    let hours: Double
    let nights: [(date: Date, slept: TimeInterval)]
    let need: TimeInterval

    var label: String { hours < 5 ? "Niedrig" : hours < 10 ? "Mittel" : "Hoch" }
    var color: Color { hours < 5 ? Theme.good : hours < 10 ? Theme.warn : Theme.bad }
}

struct Chronotype {
    let msfsc: Double      // Minuten nach Mitternacht
    let label: String
    let text: String
}

enum SleepPlanner {
    static var cal: Calendar { Calendar.current }

    static func floor15(_ d: Date) -> Date {
        let m = cal.component(.minute, from: d)
        return cal.date(bySetting: .second, value: 0, of: d.addingTimeInterval(-Double(m % 15) * 60)) ?? d
    }

    static func round5(_ d: Date) -> Date {
        let t = (d.timeIntervalSinceReferenceDate / 300).rounded() * 300
        return Date(timeIntervalSinceReferenceDate: t)
    }

    static func median(_ v: [Double]) -> Double? {
        guard !v.isEmpty else { return nil }
        let s = v.sorted()
        return s.count % 2 == 1 ? s[s.count / 2] : (s[s.count / 2 - 1] + s[s.count / 2]) / 2
    }

    /// Minuten seit 12 Uhr mittags, damit Zeiten um Mitternacht vergleichbar sind
    static func noon(_ d: Date) -> Double { Analytics.noonMinutes(d) }

    /// Uhrzeit (Minuten seit Mittag) auf eine konkrete Nacht legen, die am Tag `wakeDay` endet
    static func date(noonMinutes m: Double, nightEnding wakeDay: Date) -> Date {
        let prevNoon = cal.date(bySettingHour: 12, minute: 0, second: 0, of: cal.addDays(-1, to: wakeDay)) ?? wakeDay
        return prevNoon.addingTimeInterval(m * 60)
    }

    static func isFreeDay(_ d: Date) -> Bool {
        let wd = cal.component(.weekday, from: d)
        return wd == 1 || wd == 7
    }

    /// Gewohnte Einschlafzeit (Median der letzten 14 Nächte)
    static func habitualOnset(_ nights: [SleepNight]) -> Double? {
        median(nights.suffix(14).map { noon($0.fellAsleep) })
    }

    /// Gewohnte Aufstehzeit für Arbeits- oder freie Tage (letzte 4 Wochen)
    static func habitualWake(_ nights: [SleepNight], free: Bool) -> Double? {
        let match = nights.suffix(28).filter { isFreeDay($0.wakeDay) == free }
        return median(match.map { noon($0.end) }) ?? median(nights.suffix(14).map { noon($0.end) })
    }

    /// Zeit im Bett, die nicht Schlaf ist: Einschlafen plus nächtliche Wachphasen
    static func extraTime(_ nights: [SleepNight]) -> TimeInterval {
        let v = nights.suffix(14).map { max(0, $0.span - $0.asleep) }
        return max(10 * 60, min(60 * 60, median(v) ?? 20 * 60))
    }

    // MARK: Schlafschuld

    /// Schlafschuld der letzten 14 Nächte: Nächte zählen linear weniger, je länger sie her sind. Mehr Schlaf zahlt zurück.
    static func debt(_ nights: [SleepNight], need: TimeInterval) -> SleepDebt {
        let recent = Array(nights.suffix(14).reversed())
        var sum: Double = 0
        for (i, n) in recent.enumerated() {
            let w: Double = 1 - Double(i) / 14
            sum += w * (need - n.asleep)
        }
        return SleepDebt(hours: max(0, sum / 3600), nights: nights.suffix(14).map { ($0.wakeDay, $0.asleep) }, need: need)
    }

    // MARK: Chronotyp (Roenneberg)

    static func chronotype(_ nights: [SleepNight]) -> Chronotype? {
        let recent = nights.suffix(28)
        let free = recent.filter { isFreeDay($0.wakeDay) }
        let work = recent.filter { !isFreeDay($0.wakeDay) }
        guard free.count >= 2, work.count >= 3 else { return nil }
        func mid(_ n: SleepNight) -> Double { noon(n.fellAsleep) + n.end.timeIntervalSince(n.fellAsleep) / 120 }
        guard let msf = median(free.map(mid)) else { return nil }
        let sdf: Double = free.map(\.asleep).reduce(0, +) / Double(free.count) / 60
        let sdw: Double = work.map(\.asleep).reduce(0, +) / Double(work.count) / 60
        var msfsc = msf
        if sdf > sdw {
            let sdWeek = (5 * sdw + 2 * sdf) / 7
            msfsc = msf - (sdf - sdWeek) / 2
        }
        let clock = (msfsc + 12 * 60).truncatingRemainder(dividingBy: 1440)   // Minuten nach Mitternacht
        let label: String
        let text: String
        if clock < 3 * 60 + 30 {
            label = "Früher Typ"
            text = "Deine innere Uhr läuft früh. Morgens bist du schnell fit, abends wirst du früh müde. Harte Einheiten liegen dir eher bis zum Nachmittag."
        } else if clock < 5 * 60 {
            label = "Mittlerer Typ"
            text = "Deine innere Uhr liegt im Durchschnitt. Leistungsspitze meist am späten Nachmittag."
        } else {
            label = "Später Typ"
            text = "Deine innere Uhr läuft spät. Frühes Aufstehen kostet dich mehr. Viel Morgenlicht hilft, die Uhr vorzustellen."
        }
        return Chronotype(msfsc: clock, label: label, text: text)
    }

    // MARK: Plan für die kommende Nacht

    /// Plant die Nacht, die am Abend von `evening` beginnt
    static func plan(nights: [SleepNight], need baseNeed: TimeInterval, prefs: SleepPrefs, event: CalendarEvent?,
                     hardTomorrow: String?, debtHours: Double, evening: Date = .now) -> SleepPlan? {
        guard let onset = habitualOnset(nights) else { return nil }
        // Nach Mitternacht gilt noch die laufende Nacht
        let now = evening
        let refDay = cal.component(.hour, from: now) < 5 ? cal.addDays(-1, to: cal.startOfDay(for: now)) : cal.startOfDay(for: now)
        let wakeDay = cal.addDays(1, to: refDay)
        let wd = cal.component(.weekday, from: wakeDay)
        let free = isFreeDay(wakeDay)
        var reasons: [String] = []

        // 1. Weckzeit
        var source: SleepPlan.Source = .habit
        var wake: Date
        if let m = prefs.wakeOverride[JournalBehavior.key(wakeDay)] {
            wake = wakeDay.addingTimeInterval(Double(m) * 60)
            source = .override
        } else if let m = prefs.fixedWake[wd] {
            wake = wakeDay.addingTimeInterval(Double(m) * 60)
            source = .fixed
            if let e = event, e.start.addingTimeInterval(-Double(prefs.prepMinutes) * 60) < wake {
                wake = e.start.addingTimeInterval(-Double(prefs.prepMinutes) * 60)
                source = .calendar(e)
            }
        } else if let e = event {
            wake = e.start.addingTimeInterval(-Double(prefs.prepMinutes) * 60)
            source = .calendar(e)
            reasons.append("\(e.title) um \(Fmt.time(e.start)), \(prefs.prepMinutes) min Vorlauf")
        } else {
            let hw = habitualWake(nights, free: free) ?? 19 * 60
            wake = date(noonMinutes: hw, nightEnding: wakeDay)
            source = .habit
            // Freier Tag ohne Termin: bei Schlafschuld länger schlafen, aber höchstens 1 h, damit die innere Uhr stabil bleibt
            if free && debtHours >= 2 {
                let bonus = min(60, debtHours * 10)
                wake = wake.addingTimeInterval(bonus * 60)
                reasons.append("Freier Tag: \(Int(bonus)) min länger schlafen gegen \(Fmt.num(debtHours, 1)) h Schlafschuld")
            }
        }
        wake = round5(wake)

        // 2. Bedarf
        var need = baseNeed
        if let h = hardTomorrow {
            need += 15 * 60
            reasons.append("Morgen \(h): 15 min mehr Schlaf eingeplant")
        }
        let extra = extraTime(nights)

        // 3. Schlafenszeit
        var bed = wake.addingTimeInterval(-need - extra)
        let gateCenter = date(noonMinutes: onset, nightEnding: wakeDay)
        let gate = gateCenter.addingTimeInterval(-30 * 60)...gateCenter.addingTimeInterval(30 * 60)
        let earliest = gateCenter.addingTimeInterval(-60 * 60)
        var clampedEarly = false
        if bed < earliest {
            let missing = earliest.timeIntervalSince(bed)
            bed = earliest
            clampedEarly = true
            reasons.append("Früher als \(Fmt.time(earliest)) schläfst du kaum ein (innere Uhr). Dir fehlen \(Fmt.hm(missing)) h: ein 20-Minuten-Nickerchen im Nachmittagstief hilft.")
        }
        bed = round5(bed)
        let planned = wake.timeIntervalSince(bed) - extra
        if planned > need + 10 * 60 && !clampedEarly {
            reasons.append("\(Fmt.hm(planned - need)) h mehr als dein Bedarf: zahlt Schlafschuld zurück")
        }
        return SleepPlan(bedtime: bed, wake: wake, need: need, planned: planned, extra: extra, source: source,
                         reasons: reasons, sleepGate: gate, clampedEarly: clampedEarly, hardTomorrow: hardTomorrow)
    }

    // MARK: Energiekurve (Zwei-Prozess-Modell)

    /// Wachheit über den Tag: innere Uhr (Prozess C) minus Schlafdruck (Prozess S) minus Schlafträgheit
    static func energy(wake: Date, bed: Date, habitualOnset: Double, habitualWake: Double, debtHours: Double) -> [EnergyPoint] {
        let tauRise: Double = 18.2        // Stunden, Anstieg des Schlafdrucks im Wachsein (Daan et al. 1984)
        let s0: Double = min(0.45, 0.2 + debtHours * 0.015)
        func clockOf(_ noonMin: Double) -> Double { (noonMin + 12 * 60).truncatingRemainder(dividingBy: 1440) / 60 }
        // Tiefpunkt der inneren Uhr etwa 2 h vor dem gewohnten Aufwachen, Abendhoch etwa 2,5 h vor dem gewohnten Einschlafen
        let tMin: Double = clockOf(habitualWake) - 2
        var tMax: Double = clockOf(habitualOnset) - 2.5
        if tMax <= tMin { tMax += 24 }
        let wakeClock: Double = Double(cal.component(.hour, from: wake)) + Double(cal.component(.minute, from: wake)) / 60
        let dipClock: Double = wakeClock + 7.5
        func circadian(_ clock: Double) -> Double {
            var t = clock
            while t < tMin { t += 24 }
            while t >= tMin + 24 { t -= 24 }
            if t <= tMax { return -cos(.pi * (t - tMin) / (tMax - tMin)) }
            return cos(.pi * (t - tMax) / (tMin + 24 - tMax))
        }
        var raw: [(Date, Double)] = []
        var t = wake
        let end = bed.addingTimeInterval(30 * 60)
        while t <= end {
            let h: Double = t.timeIntervalSince(wake) / 3600
            let clock: Double = Double(cal.component(.hour, from: t)) + Double(cal.component(.minute, from: t)) / 60
            let s: Double = 1 - (1 - s0) * exp(-h / tauRise)
            let c: Double = 0.30 * circadian(clock)
            let dip: Double = -0.20 * exp(-pow(clock - dipClock, 2) / (2 * 1.4 * 1.4))
            let inertia: Double = 0.35 * exp(-h / 0.45)
            raw.append((t, c + dip - s - inertia))
            t = t.addingTimeInterval(10 * 60)
        }
        guard let lo = raw.map(\.1).min(), let hi = raw.map(\.1).max(), hi > lo else { return [] }
        return raw.map { EnergyPoint(date: $0.0, level: 10 + 85 * ($0.1 - lo) / (hi - lo)) }
    }

    /// Tagesplan: wann was am besten passt
    static func steps(plan: SleepPlan, todayWake: Date, todayBed: Date, energy: [EnergyPoint]) -> [PlanStep] {
        var out: [PlanStep] = []
        let afterWake = energy.filter { $0.date >= todayWake.addingTimeInterval(3600) }
        let dipWindow = afterWake.filter { $0.date >= todayWake.addingTimeInterval(5 * 3600) && $0.date <= todayWake.addingTimeInterval(10 * 3600) }
        let dip = dipWindow.min { $0.level < $1.level }
        let morningPeak = afterWake.filter { $0.date < (dip?.date ?? todayWake.addingTimeInterval(6 * 3600)) }.max { $0.level < $1.level }
        let eveningPeak = energy.filter { $0.date > (dip?.date ?? todayWake.addingTimeInterval(8 * 3600)) && $0.date < todayBed.addingTimeInterval(-3600) }
            .max { $0.level < $1.level }

        out.append(PlanStep(time: todayWake, end: todayWake.addingTimeInterval(3600), title: "Tageslicht tanken",
                            detail: "10 bis 30 Minuten draußen in der ersten Stunde. Stellt die innere Uhr und macht abends früher müde.",
                            icon: "sun.max.fill", color: Theme.warn))
        out.append(PlanStep(time: todayWake, end: todayWake.addingTimeInterval(75 * 60), title: "Schlafträgheit",
                            detail: "Die ersten 30 bis 60 Minuten bist du langsamer. Keine wichtigen Entscheidungen, Kaffee frühestens jetzt.",
                            icon: "cloud.fog.fill", color: Theme.muted))
        if let p = morningPeak {
            out.append(PlanStep(time: p.date.addingTimeInterval(-90 * 60), end: p.date.addingTimeInterval(60 * 60), title: "Morgenhoch",
                                detail: "Beste Zeit für Lernen, Konzentration und schwierige Aufgaben.", icon: "brain.head.profile", color: Theme.accent))
        }
        out.append(PlanStep(time: plan.caffeineCutoff, end: nil, title: "Letzter Kaffee",
                            detail: "Koffein kostet im Schnitt 45 Minuten Schlaf. Eine Tasse braucht etwa 9 Stunden Abstand zum Schlafen.",
                            icon: "cup.and.saucer.fill", color: Theme.warn))
        if let d = dip {
            out.append(PlanStep(time: d.date.addingTimeInterval(-60 * 60), end: d.date.addingTimeInterval(60 * 60), title: "Nachmittagstief",
                                detail: "Natürliches Tief der inneren Uhr. Gut für ein Nickerchen von 10 bis 20 Minuten oder leichte Aufgaben.",
                                icon: "battery.25percent", color: Theme.sleep))
        }
        if let e = eveningPeak {
            out.append(PlanStep(time: e.date.addingTimeInterval(-90 * 60), end: e.date.addingTimeInterval(60 * 60), title: "Abendhoch",
                                detail: "Körpertemperatur und Kraft sind am höchsten. Gut für harte Einheiten.", icon: "bolt.heart.fill", color: Theme.accent))
        }
        out.append(PlanStep(time: plan.lastHardTraining, end: nil, title: "Ende harter Einheiten",
                            detail: "Lockeres Training am Abend stört den Schlaf nicht. Nur intensives Training bis kurz vor dem Schlafen kann ihn verschlechtern.",
                            icon: "figure.run", color: Theme.bad))
        out.append(PlanStep(time: plan.lastMeal, end: nil, title: "Letzte große Mahlzeit, letzter Alkohol",
                            detail: "Alkohol senkt die nächtliche HRV und deine Erholung, umso mehr, je später und mehr.",
                            icon: "fork.knife", color: Theme.warn))
        out.append(PlanStep(time: plan.windDown, end: plan.bedtime, title: "Runterfahren",
                            detail: "Licht dimmen, Bildschirm weg, Zimmer kühl und dunkel. Ab jetzt nichts Aufregendes mehr.",
                            icon: "moon.haze.fill", color: Theme.sleep))
        out.append(PlanStep(time: plan.bedtime, end: nil, title: "Ins Bett",
                            detail: "Geplant \(Fmt.hm(plan.planned)) h Schlaf bei \(Fmt.hm(plan.need)) h Bedarf.",
                            icon: "bed.double.fill", color: Theme.sleep))
        return out.sorted { $0.time < $1.time }
    }
}
