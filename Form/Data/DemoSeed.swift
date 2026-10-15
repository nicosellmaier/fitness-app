import Foundation

/// Füllt die App mit Beispielinhalten für Vorschau und Screenshots (Startargument -seedDemo YES)
enum DemoSeed {
    static func seed(store: DataStore, model: AppModel, shot: String) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)

        if store.data.plan == nil {
            var s = PlanSettings()
            s.distance = .half
            s.raceName = "Stadtlauf Halbmarathon"
            s.raceDate = cal.addDays(70, to: today)
            s.targetSeconds = 1 * 3600 + 39 * 60
            s.startWeeklyKm = max(25, PlanGenerator.recentWeeklyKm(workouts: model.workouts))
            let vdot = PlanGenerator.estimateVDOT(workouts: model.workouts, vo2max: model.vo2.last?.value)
            s.startVDOT = vdot
            let plan = PlanGenerator.generate(settings: s, vdot: vdot)
            store.update { $0.plan = plan }
        }

        if store.data.sessions.isEmpty, let routine = store.data.routines.first, let legs = store.data.routines.dropFirst().first {
            var sessions: [StrengthSession] = []
            for week in 0..<4 {
                for (k, r) in [routine, legs].enumerated() {
                    let start = cal.date(bySettingHour: 18, minute: 10, second: 0, of: cal.addDays(-27 + week * 7 + k * 3, to: today)) ?? today
                    var exs: [SessionExercise] = []
                    for item in r.items {
                        let base = baseWeight[item.exerciseId] ?? 0
                        let w = base + Double(week) * (base >= 40 ? 2.5 : base > 0 ? 1 : 0)
                        let reps = min(item.repMax, item.repMin + week + 1)
                        let sets = (0..<item.sets).map { i in SetEntry(weight: w, reps: max(item.repMin, reps - (i == item.sets - 1 ? 1 : 0)), done: true) }
                        exs.append(SessionExercise(exerciseId: item.exerciseId, repMin: item.repMin, repMax: item.repMax, sets: sets))
                    }
                    sessions.append(StrengthSession(routineId: r.id, name: r.name, start: start, end: start.addingTimeInterval(55 * 60), exercises: exs))
                }
            }
            store.update { $0.sessions = sessions }
        }

        if store.entries(on: today).isEmpty {
            let b = FoodDB.basics
            func food(_ id: String) -> FoodItem { b.first { $0.id == id } ?? b[0] }
            var list: [FoodEntry] = []
            for back in 0..<7 {
                let day = cal.addDays(-back, to: today)
                func at(_ h: Int) -> Date { cal.date(bySettingHour: h, minute: 0, second: 0, of: day) ?? day }
                let f = 1 + Double((back * 37) % 5 - 2) * 0.06
                list += [
                    FoodEntry(date: at(7), meal: .breakfast, food: food("b_oats"), grams: 80 * f),
                    FoodEntry(date: at(7), meal: .breakfast, food: food("b_milk"), grams: 250),
                    FoodEntry(date: at(7), meal: .breakfast, food: food("b_banana"), grams: 120),
                    FoodEntry(date: at(10), meal: .snack, food: food("b_skyr"), grams: 250),
                ]
                if back > 0 {
                    list += [
                        FoodEntry(date: at(13), meal: .lunch, food: food("b_rice"), grams: 280 * f),
                        FoodEntry(date: at(13), meal: .lunch, food: food("b_chicken"), grams: 180),
                        FoodEntry(date: at(19), meal: .dinner, food: food("b_pasta"), grams: 300 * f),
                        FoodEntry(date: at(19), meal: .dinner, food: food("b_beef"), grams: 125),
                        FoodEntry(date: at(19), meal: .dinner, food: food("b_oil"), grams: 10),
                    ]
                } else {
                    list += [
                        FoodEntry(date: at(9), meal: .lunch, food: food("b_rice"), grams: 250),
                        FoodEntry(date: at(9), meal: .lunch, food: food("b_chicken"), grams: 180),
                    ]
                }
            }
            store.update { $0.entries += list }
        }

        if shot == "session" || shot == "rest", store.activeSession == nil, let r = store.data.routines.first {
            var s = Strength.makeSession(from: r, sessions: store.data.sessions, restrictions: store.restrictions)
            s.start = Date.now.addingTimeInterval(-14 * 60)
            for i in s.exercises.indices.prefix(2) {
                for j in s.exercises[i].sets.indices where i == 0 || j == 0 { s.exercises[i].sets[j].done = true }
            }
            store.activeSession = s
            store.saveActiveSession()
        }

        if shot == "injury", !store.data.injuries.contains(where: \.active) {
            store.update { $0.injuries.append(Injury(region: .shoulder, side: .left, severity: 2, start: cal.addDays(-3, to: today), expectedDays: 21)) }
        }
    }

    private static let baseWeight: [String: Double] = [
        "bench": 70, "bb_row": 60, "db_ohp": 20, "pullup": 0, "lat_raise": 8, "pushdown": 25, "curl": 12,
        "squat": 85, "rdl": 80, "bulgarian": 18, "leg_curl": 35, "calf_raise": 60, "copenhagen": 0, "dead_bug": 0,
        "step_up": 16, "seated_calf": 40, "tib_raise": 0, "side_plank": 0,
    ]
}
