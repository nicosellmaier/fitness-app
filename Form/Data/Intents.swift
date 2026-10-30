import AppIntents
import Foundation

// MARK: Siri und Kurzbefehle

struct RecoveryIntent: AppIntent {
    static var title: LocalizedStringResource = "Erholung abfragen"
    static var description = IntentDescription("Sagt dir Erholung, Schlaf und Belastung von heute.")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let s = WidgetSnapshot.load() else {
            return .result(dialog: "Noch keine Daten. Öffne Form einmal, dann klappt es.")
        }
        var parts: [String] = []
        if let r = s.recovery { parts.append("Erholung \(r) Prozent" + (s.recoveryLabel.map { ", \($0.lowercased())" } ?? "")) }
        if let m = s.sleepMinutes { parts.append("geschlafen \(m / 60) Stunden \(m % 60) Minuten") }
        if let h = s.hrv { parts.append("HRV \(h) Millisekunden") }
        if let st = s.strain { parts.append("Belastung \(Fmt.num(st, 1)) von 21") }
        if let t = s.today, !t.rest { parts.append("heute \(t.title)") }
        return .result(dialog: IntentDialog(stringLiteral: parts.joined(separator: ", ") + "."))
    }
}

struct SleepPlanIntent: AppIntent {
    static var title: LocalizedStringResource = "Schlafenszeit abfragen"
    static var description = IntentDescription("Wann du heute ins Bett solltest und wann der Wecker klingelt.")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let s = WidgetSnapshot.load(), let b = s.bedtime, let w = s.wake else {
            return .result(dialog: "Noch kein Schlafplan. Öffne Form einmal.")
        }
        let need = s.needMinutes.map { " für \($0 / 60) Stunden \($0 % 60) Minuten Schlaf" } ?? ""
        return .result(dialog: IntentDialog(stringLiteral: "Ins Bett um \(Fmt.time(b)), Wecker um \(Fmt.time(w))\(need)."))
    }
}

struct LogWaterIntent: AppIntent {
    static var title: LocalizedStringResource = "Wasser eintragen"
    static var description = IntentDescription("Trägt getrunkenes Wasser für heute ein.")
    static var openAppWhenRun = false

    @Parameter(title: "Milliliter", default: 250)
    var ml: Int

    static var parameterSummary: some ParameterSummary { Summary("\(\.$ml) ml Wasser eintragen") }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = DataStore()
        let key = JournalBehavior.key(.now)
        store.update { $0.water[key] = ($0.water[key] ?? 0) + Double(ml) }
        let total = store.data.water[key] ?? 0
        let goal = store.data.reminders.waterGoalMl
        return .result(dialog: IntentDialog(stringLiteral: "\(ml) Milliliter eingetragen. Heute \(Fmt.num(total / 1000, 2)) von \(Fmt.num(goal / 1000, 1)) Litern."))
    }
}

struct LogWeightIntent: AppIntent {
    static var title: LocalizedStringResource = "Gewicht eintragen"
    static var openAppWhenRun = false

    @Parameter(title: "Kilogramm")
    var kg: Double

    static var parameterSummary: some ParameterSummary { Summary("\(\.$kg) kg eintragen") }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard kg > 30, kg < 250 else { return .result(dialog: "Das klingt nicht nach einem Körpergewicht.") }
        let store = DataStore()
        store.update { $0.weightLog[JournalBehavior.key(.now)] = kg; $0.profile.weightKg = kg }
        return .result(dialog: IntentDialog(stringLiteral: "\(Fmt.num(kg, 1)) Kilogramm eingetragen."))
    }
}

struct StartRoutineIntent: AppIntent {
    static var title: LocalizedStringResource = "Krafttraining starten"
    static var description = IntentDescription("Öffnet Form und startet eine Routine.")
    static var openAppWhenRun = true

    @Parameter(title: "Routine")
    var name: String?

    static var parameterSummary: some ParameterSummary { Summary("Routine \(\.$name) starten") }

    @MainActor
    func perform() async throws -> some IntentResult {
        UserDefaults.standard.set(name ?? "", forKey: "pendingRoutine")
        UserDefaults.standard.set(2, forKey: "trainingSeg")
        UserDefaults.standard.set(1, forKey: "pendingTab")
        return .result()
    }
}

struct OpenCoachIntent: AppIntent {
    static var title: LocalizedStringResource = "Tagesbriefing vom Coach"
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        UserDefaults.standard.set(true, forKey: "pendingBriefing")
        return .result()
    }
}

struct FormShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: RecoveryIntent(), phrases: ["Wie ist meine Erholung in \(.applicationName)", "\(.applicationName) Erholung", "Wie erholt bin ich laut \(.applicationName)"],
                    shortTitle: "Erholung", systemImageName: "bolt.heart.fill")
        AppShortcut(intent: SleepPlanIntent(), phrases: ["Wann soll ich ins Bett laut \(.applicationName)", "\(.applicationName) Schlafenszeit"],
                    shortTitle: "Schlafenszeit", systemImageName: "bed.double.fill")
        AppShortcut(intent: LogWaterIntent(), phrases: ["Wasser in \(.applicationName) eintragen", "\(.applicationName) ich habe getrunken"],
                    shortTitle: "Wasser", systemImageName: "drop.fill")
        AppShortcut(intent: LogWeightIntent(), phrases: ["Gewicht in \(.applicationName) eintragen"],
                    shortTitle: "Gewicht", systemImageName: "scalemass.fill")
        AppShortcut(intent: StartRoutineIntent(), phrases: ["Krafttraining in \(.applicationName) starten", "\(.applicationName) Training starten"],
                    shortTitle: "Training starten", systemImageName: "dumbbell.fill")
        AppShortcut(intent: OpenCoachIntent(), phrases: ["Tagesbriefing von \(.applicationName)", "\(.applicationName) Briefing"],
                    shortTitle: "Briefing", systemImageName: "sparkles")
    }
}
