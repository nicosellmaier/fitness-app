import Foundation
import SwiftUI

// MARK: Bestzeiten

struct BestEffort: Identifiable {
    var id: String { label }
    let label: String
    let meters: Double
    let seconds: Double
    let workout: WorkoutItem
    /// Aus dem Durchschnittstempo eines längeren Laufs geschätzt
    let estimated: Bool

    var pace: Double { seconds / (meters / 1000) }
}

enum Records {
    static let targets: [(String, Double)] = [("1 km", 1000), ("5 km", 5000), ("10 km", 10000), ("Halbmarathon", 21097.5), ("Marathon", 42195)]

    /// Schnellste Zeit je Distanz: exakt bei Läufen nahe der Distanz, sonst aus dem Schnitt des Laufs
    static func bests(_ workouts: [WorkoutItem]) -> [BestEffort] {
        let runs = workouts.filter { $0.activity == .running && ($0.distance ?? 0) > 900 && $0.duration > 120 }
        var out: [BestEffort] = []
        for (label, m) in targets {
            var best: BestEffort?
            for w in runs {
                guard let d = w.distance, d >= m * 0.98 else { continue }
                let secs = w.duration * (m / d)
                let est = d > m * 1.3
                if best == nil || secs < best!.seconds {
                    best = BestEffort(label: label, meters: m, seconds: secs, workout: w, estimated: est)
                }
            }
            if let best { out.append(best) }
        }
        return out
    }

    static func longest(_ workouts: [WorkoutItem]) -> WorkoutItem? {
        workouts.filter { $0.activity == .running }.max { ($0.distance ?? 0) < ($1.distance ?? 0) }
    }

    static func biggestWeek(_ workouts: [WorkoutItem]) -> (Date, Double)? {
        let cal = Calendar.current
        var weeks: [Date: Double] = [:]
        for w in workouts where w.activity == .running {
            let ws = cal.dateInterval(of: .weekOfYear, for: w.start)?.start ?? w.start
            weeks[ws, default: 0] += (w.distance ?? 0) / 1000
        }
        return weeks.max { $0.value < $1.value }.map { ($0.key, $0.value) }
    }

    static func streakWeeks(_ workouts: [WorkoutItem]) -> Int {
        let cal = Calendar.current
        let weeks = Set(workouts.map { cal.dateInterval(of: .weekOfYear, for: $0.start)?.start ?? $0.start })
        var n = 0
        var w = cal.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        while weeks.contains(w) { n += 1; w = cal.date(byAdding: .weekOfYear, value: -1, to: w) ?? w }
        return n
    }
}

// MARK: Schuhe

extension DataStore {
    /// Kilometer eines Schuhs: Startwert plus zugeordnete Läufe, Standardschuh bekommt alle Läufe ohne Zuordnung seit Kauf
    func shoeKm(_ shoe: Shoe, workouts: [WorkoutItem]) -> Double {
        var km = shoe.startKm
        for w in workouts where w.activity == .running {
            guard let d = w.distance else { continue }
            let note = data.workoutNotes[w.id.uuidString]
            if note?.shoeId == shoe.id { km += d / 1000 }
            else if note?.shoeId == nil && shoe.isDefault && !shoe.retired && w.start >= shoe.since { km += d / 1000 }
        }
        return km
    }

    func note(for w: WorkoutItem) -> WorkoutNote { data.workoutNotes[w.id.uuidString] ?? WorkoutNote() }

    func setNote(_ n: WorkoutNote, for w: WorkoutItem) {
        update { $0.workoutNotes[w.id.uuidString] = n }
    }
}

// MARK: Wettkampftag

struct RacePlan {
    let distance: Double
    let targetSeconds: Double
    let splits: [(km: Int, cumulative: Double, pace: Double)]
    let checkpoints: [(label: String, at: Double, time: Double)]
    let warmup: String
    let hrCap: Int
    let timeline: [(when: String, what: String)]
    let fueling: [String]

    var goalPace: Double { targetSeconds / (distance / 1000) }

    /// Leicht negativer Split: erste 10 % 2 % langsamer, letzte 20 % 1,5 % schneller
    static func make(distance: Double, targetSeconds: Double, maxHR: Double, start: Date) -> RacePlan {
        let kmCount = Int(ceil(distance / 1000))
        let base = targetSeconds / (distance / 1000)
        var splits: [(Int, Double, Double)] = []
        var cum = 0.0
        for k in 1...kmCount {
            let frac = Double(k) / Double(kmCount)
            let factor = frac <= 0.1 ? 1.02 : frac >= 0.8 ? 0.985 : 1.0
            let len = k == kmCount ? (distance - Double(kmCount - 1) * 1000) / 1000 : 1.0
            let pace = base * factor
            cum += pace * len
            splits.append((k, cum, pace))
        }
        // Auf die Zielzeit normieren
        let scale = targetSeconds / cum
        splits = splits.map { ($0.0, $0.1 * scale, $0.2 * scale) }
        var cps: [(String, Double, Double)] = []
        for (label, m) in [("5 km", 5000.0), ("10 km", 10000.0), ("Halbzeit", distance / 2), ("15 km", 15000.0), ("Halbmarathon", 21097.5), ("30 km", 30000.0)] where m < distance - 500 {
            let t = splits.first { Double($0.0) * 1000 >= m }.map { s in s.1 - (Double(s.0) * 1000 - m) / 1000 * s.2 } ?? 0
            cps.append((label, m, t))
        }
        cps.sort { $0.1 < $1.1 }
        let isLong = distance > 15000
        let cap = Int(maxHR * (isLong ? 0.88 : 0.95))
        let cal = Calendar.current
        func t(_ h: Double) -> String { Fmt.time(start.addingTimeInterval(-h * 3600)) }
        var tl: [(String, String)] = [
            ("3 Tage vorher", isLong ? "Kohlenhydrate hoch (8 bis 10 g pro kg), Training nur locker, viel schlafen." : "Normal essen, Training kurz und locker, früh ins Bett."),
            ("Vorabend", "Bekanntes Essen, nichts Neues. Startnummer, Schuhe, Kleidung bereitlegen. Wecker stellen."),
            (t(3), "Aufstehen, \(isLong ? "2 bis 3 g Kohlenhydrate pro kg" : "leichtes Frühstück"), z. B. Toast mit Marmelade, Banane. 500 ml trinken."),
            (t(1), "Letzter Toilettengang, Koffein (wer es gewohnt ist), ab jetzt nur noch Schlucke trinken."),
            (t(0.5), "Einlaufen: \(isLong ? "10 min locker" : "15 min locker, 4 Steigerungen"). Nicht mehr."),
            (Fmt.time(start), "Start. Erster Kilometer bewusst langsam, du wirst überholt. Das ist richtig."),
        ]
        if isLong { tl.insert((t(2), "Letzter Bissen, danach nur noch Flüssigkeit."), at: 4) }
        _ = cal
        var fuel: [String] = []
        if distance >= 15000 { fuel.append("Ab km 5 alle 20 bis 25 Minuten 25 bis 30 g Kohlenhydrate (ein Gel oder 300 ml Iso).") }
        if distance >= 30000 { fuel.append("Ab km 25 ist der Kopf wichtiger als die Beine. Pro Kilometer denken, nicht bis ins Ziel.") }
        fuel.append(distance >= 15000 ? "An jeder Verpflegungsstation trinken, bei Wärme auch über den Kopf." : "Trinken nur bei Hitze nötig. Keine Gels.")
        fuel.append("Puls über \(cap) bpm in der ersten Hälfte heißt: zu schnell.")
        return RacePlan(distance: distance, targetSeconds: targetSeconds, splits: splits.map { (km: $0.0, cumulative: $0.1, pace: $0.2) },
                        checkpoints: cps.map { (label: $0.0, at: $0.1, time: $0.2) },
                        warmup: isLong ? "10 min locker, 2 kurze Steigerungen" : "15 min locker, 4 × 20 s Steigerungen, 5 min bis zum Start",
                        hrCap: cap, timeline: tl.map { (when: $0.0, what: $0.1) }, fueling: fuel)
    }
}

// MARK: Steigerungen

extension RunStructure {
    /// 4 bis 6 kurze Steigerungen (20 s schnell, 60 s traben) ans Ende eines lockeren Laufs
    func withStrides(_ n: Int = 5) -> RunStructure {
        var s = self
        s.blocks.append(Block(repeats: n, work: .min(20.0 / 60, .repetition), recovery: .min(1, .easy)))
        return s
    }
}

// MARK: Laufband

enum Treadmill {
    /// km/h für eine Pace in s/km
    static func kmh(_ secPerKm: Double) -> Double { secPerKm > 0 ? 3600 / secPerKm : 0 }

    /// 1 % Steigung gleicht den fehlenden Luftwiderstand aus
    static let incline = 1.0
}
