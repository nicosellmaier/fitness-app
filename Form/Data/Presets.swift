import Foundation

// MARK: Kraftprogramme

struct ProgramPreset: Identifiable {
    let id: String
    let name: String
    let level: String
    let days: String
    let minutes: Int
    let place: String
    let icon: String
    let summary: String
    let routines: [Routine]
}

private func item(_ id: String, _ sets: Int, _ lo: Int, _ hi: Int) -> RoutineItem {
    RoutineItem(exerciseId: id, sets: sets, repMin: lo, repMax: hi)
}

enum Presets {
    static let programs: [ProgramPreset] = [
        ProgramPreset(
            id: "beginner_full", name: "Einsteiger Ganzkörper", level: "Einsteiger", days: "2–3× pro Woche", minutes: 45,
            place: "Studio", icon: "figure.strengthtraining.functional",
            summary: "Zwei Ganzkörper-Einheiten im Wechsel, vor allem an Maschinen. Ideal für den Start: wenig Technik, schneller Fortschritt.",
            routines: [
                Routine(name: "Ganzkörper A", items: [
                    item("leg_press", 3, 10, 12), item("chest_press", 3, 10, 12), item("lat_pulldown", 3, 10, 12),
                    item("hip_thrust", 3, 10, 12), item("leg_curl", 2, 12, 15), item("plank", 2, 20, 45),
                ]),
                Routine(name: "Ganzkörper B", items: [
                    item("goblet", 3, 10, 12), item("db_row", 3, 10, 12), item("db_ohp", 3, 10, 12),
                    item("step_up", 2, 10, 12), item("abductor", 2, 12, 15), item("dead_bug", 2, 10, 16),
                ]),
            ]),
        ProgramPreset(
            id: "home_db", name: "Zuhause mit Kurzhanteln", level: "Einsteiger bis Mittel", days: "3× pro Woche", minutes: 40,
            place: "Zuhause", icon: "house.fill",
            summary: "Nur Kurzhanteln und Körpergewicht. Zwei Einheiten im Wechsel, deckt den ganzen Körper ab.",
            routines: [
                Routine(name: "Zuhause A", items: [
                    item("goblet", 3, 8, 15), item("pushup", 3, 6, 15), item("db_row", 3, 8, 12),
                    item("glute_bridge", 3, 12, 20), item("lat_raise", 2, 12, 20), item("dead_bug", 2, 10, 16),
                ]),
                Routine(name: "Zuhause B", items: [
                    item("bulgarian", 3, 8, 12), item("db_ohp", 3, 8, 12), item("db_row", 3, 8, 12),
                    item("lunge", 2, 10, 14), item("hammer_curl", 2, 10, 15), item("side_plank", 2, 20, 45),
                ]),
            ]),
        ProgramPreset(
            id: "lower_focus", name: "Beine & Po Fokus", level: "Alle Level", days: "3× pro Woche", minutes: 50,
            place: "Studio", icon: "figure.cross.training",
            summary: "Zwei Unterkörper-Tage mit Schwerpunkt auf Gesäß und Beinbeugern, dazu ein Oberkörper-Tag für Haltung und Balance.",
            routines: [
                Routine(name: "Beine & Po A", items: [
                    item("hip_thrust", 4, 8, 12), item("rdl", 3, 8, 12), item("bulgarian", 3, 8, 12),
                    item("abductor", 3, 12, 20), item("leg_curl", 2, 10, 15),
                ]),
                Routine(name: "Oberkörper", items: [
                    item("lat_pulldown", 3, 8, 12), item("chest_press", 3, 8, 12), item("cable_row", 3, 10, 12),
                    item("db_ohp", 2, 8, 12), item("lat_raise", 2, 12, 20), item("face_pull", 2, 12, 20),
                ]),
                Routine(name: "Beine & Po B", items: [
                    item("goblet", 3, 8, 12), item("step_up", 3, 8, 12), item("hip_thrust", 3, 10, 15),
                    item("leg_press", 3, 10, 15), item("copenhagen", 2, 15, 30), item("calf_raise", 2, 12, 15),
                ]),
            ]),
        ProgramPreset(
            id: "upper_lower", name: "Oberkörper / Unterkörper", level: "Mittel", days: "4× pro Woche", minutes: 60,
            place: "Studio", icon: "dumbbell.fill",
            summary: "Klassischer Split mit Grundübungen. Jeder Muskel zweimal pro Woche, guter Mix aus Kraft und Muskelaufbau.",
            routines: [
                Routine(name: "Oberkörper A", items: [
                    item("bench", 3, 5, 8), item("bb_row", 3, 6, 10), item("db_ohp", 3, 8, 12),
                    item("pullup", 3, 5, 10), item("pushdown", 2, 10, 15), item("curl", 2, 10, 15),
                ]),
                Routine(name: "Unterkörper A", items: [
                    item("squat", 3, 5, 8), item("rdl", 3, 6, 10), item("bulgarian", 2, 8, 12),
                    item("leg_curl", 2, 10, 15), item("calf_raise", 3, 10, 15),
                ]),
                Routine(name: "Oberkörper B", items: [
                    item("incline_db", 3, 8, 12), item("chest_row", 3, 8, 12), item("lat_pulldown", 3, 8, 12),
                    item("lat_raise", 3, 12, 20), item("face_pull", 2, 12, 20), item("hammer_curl", 2, 10, 15),
                ]),
                Routine(name: "Unterkörper B", items: [
                    item("deadlift", 3, 3, 6), item("leg_press", 3, 8, 12), item("lunge", 2, 10, 12),
                    item("leg_ext", 2, 12, 15), item("seated_calf", 2, 12, 15), item("hanging_raise", 2, 8, 15),
                ]),
            ]),
        ProgramPreset(
            id: "ppl", name: "Push / Pull / Beine", level: "Mittel bis Fortgeschritten", days: "3–6× pro Woche", minutes: 60,
            place: "Studio", icon: "figure.strengthtraining.traditional",
            summary: "Drücken, Ziehen, Beine. Dreimal pro Woche für Einsteiger in den Split, sechsmal für maximales Volumen.",
            routines: [
                Routine(name: "Push", items: [
                    item("bench", 3, 5, 8), item("incline_db", 3, 8, 12), item("db_ohp", 3, 8, 12),
                    item("lat_raise", 3, 12, 20), item("pushdown", 3, 10, 15), item("overhead_ext", 2, 10, 15),
                ]),
                Routine(name: "Pull", items: [
                    item("pullup", 3, 5, 10), item("bb_row", 3, 6, 10), item("cable_row", 3, 10, 12),
                    item("face_pull", 3, 12, 20), item("curl", 3, 8, 12), item("hammer_curl", 2, 10, 15),
                ]),
                Routine(name: "Beine", items: [
                    item("squat", 3, 5, 8), item("rdl", 3, 6, 10), item("leg_press", 3, 10, 12),
                    item("leg_curl", 3, 10, 15), item("calf_raise", 3, 10, 15), item("hanging_raise", 2, 8, 15),
                ]),
            ]),
        ProgramPreset(
            id: "runner", name: "Läufer-Kraft", level: "Alle Level", days: "2× pro Woche", minutes: 35,
            place: "Studio oder Zuhause", icon: "figure.run",
            summary: "Für alle, die laufen: einbeinige Übungen, Waden, Hüfte und Rumpf. Macht schneller und schützt vor typischen Läuferverletzungen.",
            routines: [
                Routine(name: "Läufer-Kraft A", items: [
                    item("bulgarian", 3, 6, 10), item("rdl", 3, 6, 10), item("seated_calf", 3, 10, 15),
                    item("tib_raise", 2, 15, 25), item("side_plank", 2, 30, 60),
                ]),
                Routine(name: "Läufer-Kraft B", items: [
                    item("step_up", 3, 8, 12), item("hip_thrust", 3, 8, 12), item("calf_raise", 3, 10, 15),
                    item("copenhagen", 2, 15, 30), item("dead_bug", 2, 10, 16),
                ]),
            ]),
        ProgramPreset(
            id: "compact", name: "Kraft kompakt", level: "Mittel", days: "2× pro Woche", minutes: 45,
            place: "Studio", icon: "bolt.fill",
            summary: "Wenig Zeit, viel Wirkung: fünf Grundübungen pro Einheit. Passt gut neben Ausdauertraining.",
            routines: [
                Routine(name: "Kompakt A", items: [
                    item("squat", 3, 5, 8), item("bench", 3, 5, 8), item("bb_row", 3, 6, 10),
                    item("pallof", 2, 10, 12),
                ]),
                Routine(name: "Kompakt B", items: [
                    item("deadlift", 3, 3, 6), item("db_ohp", 3, 8, 12), item("pullup", 3, 5, 10),
                    item("bulgarian", 2, 8, 12),
                ]),
            ]),
    ]
}

// MARK: Laufplan-Vorlagen

struct RunPreset: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
    let distance: RaceDistance
    let weeks: Int
    let runDays: [Int]
    let longRunDay: Int
    let startKm: Double
    let beginner: Bool

    func settings() -> PlanSettings {
        var s = PlanSettings()
        s.distance = distance
        s.raceDate = Calendar.current.addDays(7 * weeks, to: Calendar.current.startOfDay(for: .now))
        s.runDays = runDays
        s.longRunDay = longRunDay
        s.startWeeklyKm = startKm
        s.beginner = beginner
        s.strengthDays = beginner ? [3, 6] : [2, 5]
        s.raceName = beginner ? "0 auf 5 km" : ""
        return s
    }

    static let all: [RunPreset] = [
        RunPreset(id: "c25k", title: "0 auf 5 km", subtitle: "8 Wochen, 3× pro Woche. Laufen und Gehen im Wechsel, am Ende 30 Minuten am Stück.",
                  icon: "figure.walk.motion", distance: .fiveK, weeks: 8, runDays: [2, 4, 7], longRunDay: 7, startKm: 0, beginner: true),
        RunPreset(id: "5k", title: "5 km schneller", subtitle: "8 Wochen, 3–4× pro Woche. Für alle, die 5 km schon schaffen und schneller werden wollen.",
                  icon: "hare.fill", distance: .fiveK, weeks: 8, runDays: [3, 5, 1], longRunDay: 1, startKm: 15, beginner: false),
        RunPreset(id: "10k", title: "10 km", subtitle: "10 Wochen, 3–4× pro Woche. Vom lockeren Läufer zum ersten 10er.",
                  icon: "figure.run", distance: .tenK, weeks: 10, runDays: [3, 5, 1], longRunDay: 1, startKm: 18, beginner: false),
        RunPreset(id: "half", title: "Halbmarathon", subtitle: "12 Wochen, 4× pro Woche. Langer Lauf am Sonntag, Tempo unter der Woche.",
                  icon: "medal.fill", distance: .half, weeks: 12, runDays: [3, 4, 6, 1], longRunDay: 1, startKm: 25, beginner: false),
        RunPreset(id: "marathon", title: "Marathon", subtitle: "16 Wochen, 4–5× pro Woche. Für Läufer mit Halbmarathon-Erfahrung.",
                  icon: "flag.checkered", distance: .marathon, weeks: 16, runDays: [2, 3, 5, 6, 1], longRunDay: 1, startKm: 35, beginner: false),
    ]
}
