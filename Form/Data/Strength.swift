import Foundation
import HealthKit

enum Strength {
    /// Geschätztes Maximalgewicht für eine Wiederholung (Epley)
    static func oneRM(_ w: Double, _ reps: Int) -> Double {
        guard w > 0, reps > 0 else { return 0 }
        return reps == 1 ? w : w * (1 + Double(reps) / 30)
    }

    /// Letzte Einheit, in der die Übung gemacht wurde
    static func last(_ exerciseId: String, in sessions: [StrengthSession], before: Date = .distantFuture) -> SessionExercise? {
        for s in sessions.sorted(by: { $0.start > $1.start }) where s.start < before {
            if let e = s.exercises.first(where: { $0.exerciseId == exerciseId && $0.sets.contains(where: \.done) }) { return e }
        }
        return nil
    }

    struct Suggestion {
        let weight: Double
        let reps: Int
        let text: String
        let increase: Bool
    }

    /// Doppelte Progression: erst Wiederholungen bis zum oberen Ende, dann Gewicht rauf
    static func suggestion(exerciseId: String, repMin: Int, repMax: Int, sessions: [StrengthSession]) -> Suggestion {
        guard let last = last(exerciseId, in: sessions) else {
            return Suggestion(weight: 0, reps: repMin, text: "Erstes Mal: Gewicht wählen, mit dem du \(repMin)–\(repMax) saubere Wiederholungen schaffst.", increase: false)
        }
        let done = last.sets.filter(\.done)
        let weight = done.map(\.weight).max() ?? 0
        let atWeight = done.filter { $0.weight == weight }
        let inc = ExerciseDB.find(exerciseId)?.increment ?? 2.5
        let bw = ExerciseDB.find(exerciseId)?.bodyweight ?? false
        if !atWeight.isEmpty, atWeight.allSatisfy({ $0.reps >= repMax }), atWeight.count >= max(1, last.sets.count - 1) {
            if bw && weight == 0 {
                return Suggestion(weight: 0, reps: repMax, text: "Alle Sätze am oberen Ende. Zeit für Zusatzgewicht oder eine schwerere Variante.", increase: true)
            }
            return Suggestion(weight: weight + inc, reps: repMin, text: "Alle Sätze bei \(repMax) Wdh. geschafft: +\(Fmt.num(inc, inc < 1 ? 1 : (inc.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 1))) kg, wieder ab \(repMin) Wdh.", increase: true)
        }
        let minReps = atWeight.map(\.reps).min() ?? repMin
        let target = min(repMax, max(repMin, minReps + 1))
        return Suggestion(weight: weight, reps: target, text: "Letztes Mal \(Fmt.num(weight, weight.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 1)) kg × \(atWeight.map { String($0.reps) }.joined(separator: "/")). Ziel heute: \(target) Wdh. pro Satz.", increase: false)
    }

    static func lastSummary(_ e: SessionExercise) -> String {
        e.sets.filter(\.done).map { "\(Fmt.num($0.weight, $0.weight.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 1))×\($0.reps)" }.joined(separator: " · ")
    }

    /// Neue Einheit aus einer Routine bauen, gesperrte Übungen automatisch ersetzen
    static func makeSession(from routine: Routine, sessions: [StrengthSession], restrictions: Restrictions) -> StrengthSession {
        var used = Set<String>()
        var list: [SessionExercise] = []
        for item in routine.items {
            guard let ex = ExerciseDB.find(item.exerciseId) else { continue }
            var chosen = ex
            var replaced: String? = nil
            if ExerciseDB.isBlocked(ex, by: restrictions.blockedRegions) {
                let alts = ExerciseDB.alternatives(for: ex, avoiding: restrictions.blockedRegions).filter { !used.contains($0.id) }
                guard let alt = alts.first else { continue }
                chosen = alt
                replaced = ex.id
            }
            used.insert(chosen.id)
            let sug = suggestion(exerciseId: chosen.id, repMin: item.repMin, repMax: item.repMax, sessions: sessions)
            let sets = (0..<item.sets).map { _ in SetEntry(weight: sug.weight, reps: sug.reps) }
            list.append(SessionExercise(exerciseId: chosen.id, repMin: item.repMin, repMax: item.repMax, sets: sets, replaced: replaced))
        }
        return StrengthSession(routineId: routine.id, name: routine.name, start: .now, end: nil, exercises: list)
    }

    /// Was in einer Routine wegen Verletzung wegfällt
    static func blockedItems(_ routine: Routine, restrictions: Restrictions) -> [(Exercise, Exercise?)] {
        routine.items.compactMap { item in
            guard let ex = ExerciseDB.find(item.exerciseId), ExerciseDB.isBlocked(ex, by: restrictions.blockedRegions) else { return nil }
            return (ex, ExerciseDB.alternatives(for: ex, avoiding: restrictions.blockedRegions).first)
        }
    }

    struct Record {
        let exerciseId: String
        let oneRM: Double
        let previous: Double
    }

    /// Neue Bestwerte in einer Einheit
    static func records(in session: StrengthSession, history: [StrengthSession]) -> [Record] {
        session.exercises.compactMap { e in
            let best = e.sets.filter(\.done).map { oneRM($0.weight, $0.reps) }.max() ?? 0
            guard best > 0 else { return nil }
            let prev = history.filter { $0.id != session.id && $0.start < session.start }
                .flatMap { $0.exercises.filter { $0.exerciseId == e.exerciseId } }
                .flatMap { $0.sets.filter(\.done) }
                .map { oneRM($0.weight, $0.reps) }.max() ?? 0
            return best > prev + 0.01 && prev > 0 ? Record(exerciseId: e.exerciseId, oneRM: best, previous: prev) : nil
        }
    }

    /// Verlauf des geschätzten 1RM pro Einheit
    static func progress(_ exerciseId: String, sessions: [StrengthSession]) -> [Point] {
        sessions.sorted { $0.start < $1.start }.compactMap { s in
            let best = s.exercises.filter { $0.exerciseId == exerciseId }.flatMap { $0.sets.filter(\.done) }.map { oneRM($0.weight, $0.reps) }.max()
            return best.flatMap { $0 > 0 ? Point(date: s.start, value: $0) : nil }
        }
    }

    static func save(_ session: StrengthSession, to store: HKHealthStore) async {
        guard HKHealthStore.isHealthDataAvailable(), let end = session.end else { return }
        let config = HKWorkoutConfiguration()
        config.activityType = .traditionalStrengthTraining
        config.locationType = .indoor
        let builder = HKWorkoutBuilder(healthStore: store, configuration: config, device: .local())
        do {
            try await builder.beginCollection(at: session.start)
            try await builder.addMetadata([HKMetadataKeyWorkoutBrandName: "Form"])
            try await builder.endCollection(at: end)
            _ = try await builder.finishWorkout()
        } catch {
            print("Workout speichern fehlgeschlagen: \(error)")
        }
    }
}
