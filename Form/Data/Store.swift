import Foundation
import Observation

// MARK: Profil

enum Sex: String, Codable, CaseIterable, Identifiable {
    case male, female
    var id: String { rawValue }
    var label: String { self == .male ? "Männlich" : "Weiblich" }
}

enum NutritionGoal: String, Codable, CaseIterable, Identifiable {
    case cut, maintain, bulk
    var id: String { rawValue }
    var label: String {
        switch self {
        case .cut: return "Abnehmen"
        case .maintain: return "Gewicht halten"
        case .bulk: return "Muskelaufbau"
        }
    }
    var kcalDelta: Double {
        switch self {
        case .cut: return -400
        case .maintain: return 0
        case .bulk: return 250
        }
    }
}

struct Profile: Codable {
    var sex: Sex = .male
    var birthYear: Int = 2003
    var heightCm: Double = 180
    var weightKg: Double = 75
    var goal: NutritionGoal = .maintain
    var proteinPerKg: Double = 1.8
    var restSeconds: Int = 120
    var saveStrengthToHealth: Bool = true
    var bedtimeReminder: Bool = false

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Profile()
        sex = (try? c.decodeIfPresent(Sex.self, forKey: .sex)) ?? d.sex
        birthYear = (try? c.decodeIfPresent(Int.self, forKey: .birthYear)) ?? d.birthYear
        heightCm = (try? c.decodeIfPresent(Double.self, forKey: .heightCm)) ?? d.heightCm
        weightKg = (try? c.decodeIfPresent(Double.self, forKey: .weightKg)) ?? d.weightKg
        goal = (try? c.decodeIfPresent(NutritionGoal.self, forKey: .goal)) ?? d.goal
        proteinPerKg = (try? c.decodeIfPresent(Double.self, forKey: .proteinPerKg)) ?? d.proteinPerKg
        restSeconds = (try? c.decodeIfPresent(Int.self, forKey: .restSeconds)) ?? d.restSeconds
        saveStrengthToHealth = (try? c.decodeIfPresent(Bool.self, forKey: .saveStrengthToHealth)) ?? d.saveStrengthToHealth
        bedtimeReminder = (try? c.decodeIfPresent(Bool.self, forKey: .bedtimeReminder)) ?? d.bedtimeReminder
    }

    var age: Int { max(14, Calendar.current.component(.year, from: .now) - birthYear) }
}

// MARK: Krafttraining

struct RoutineItem: Identifiable, Codable, Hashable {
    var id = UUID()
    var exerciseId: String
    var sets: Int = 3
    var repMin: Int = 6
    var repMax: Int = 10
}

struct Routine: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var items: [RoutineItem]
}

struct SetEntry: Identifiable, Codable, Hashable {
    var id = UUID()
    var weight: Double
    var reps: Int
    var done: Bool = false
}

struct SessionExercise: Identifiable, Codable, Hashable {
    var id = UUID()
    var exerciseId: String
    var repMin: Int
    var repMax: Int
    var sets: [SetEntry]
    var replaced: String? = nil
}

struct StrengthSession: Identifiable, Codable, Hashable {
    var id = UUID()
    var routineId: UUID?
    var name: String
    var start: Date
    var end: Date?
    var exercises: [SessionExercise]

    var volume: Double {
        exercises.reduce(0) { acc, e in acc + e.sets.filter(\.done).reduce(0) { $0 + $1.weight * Double($1.reps) } }
    }
    var doneSets: Int { exercises.reduce(0) { $0 + $1.sets.filter(\.done).count } }
}

// MARK: Verletzung und Krankheit

enum Side: String, Codable, CaseIterable, Identifiable {
    case left, right, both
    var id: String { rawValue }
    var label: String {
        switch self {
        case .left: return "links"
        case .right: return "rechts"
        case .both: return "beidseitig"
        }
    }
}

struct Injury: Identifiable, Codable, Hashable {
    var id = UUID()
    var region: BodyRegion
    var side: Side? = nil
    var severity: Int = 2
    var start: Date = .now
    var expectedDays: Int = 14
    var resolved: Date? = nil
    var note: String = ""

    var active: Bool { resolved == nil }
    var title: String { region.label + (side.map { " " + $0.label } ?? "") }
    var severityLabel: String { ["", "Ziept leicht", "Schmerz bei Belastung", "Schmerz auch in Ruhe"][max(1, min(3, severity))] }
    var expectedEnd: Date { Calendar.current.addDays(expectedDays, to: start) }
}

struct Illness: Codable, Hashable {
    var start: Date = .now
    var aboveNeckOnly: Bool = true
    var fever: Bool = false
    var resolved: Date? = nil

    var active: Bool { resolved == nil }
}

/// Was durch Verletzung oder Krankheit gerade nicht geht
struct Restrictions {
    var blockedRegions: Set<BodyRegion> = []
    var runAllowed = true
    var runEasyOnly = false
    var trainingPaused = false
    var strengthAllowed = true
    /// Gründe, die das Laufen einschränken
    var reasons: [String] = []
    /// Alle aktiven Verletzungen und Krankheiten
    var allReasons: [String] = []

    var isEmpty: Bool { blockedRegions.isEmpty && runAllowed && !runEasyOnly && !trainingPaused }
    var affectsRunning: Bool { !runAllowed || runEasyOnly || trainingPaused }

    static func from(injuries: [Injury], illness: Illness?) -> Restrictions {
        var r = Restrictions()
        for i in injuries where i.active {
            r.blockedRegions.insert(i.region)
            r.allReasons.append(i.title)
            if i.region.affectsRunning {
                if i.severity >= 2 { r.runAllowed = false } else { r.runEasyOnly = true }
                r.reasons.append(i.title)
            }
        }
        let cal = Calendar.current
        if let ill = illness {
            if ill.active {
                if ill.fever || !ill.aboveNeckOnly {
                    r.trainingPaused = true
                    r.runAllowed = false
                    r.strengthAllowed = false
                } else {
                    r.runEasyOnly = true
                }
                r.reasons.append("Krankheit")
                r.allReasons.append("Krankheit")
            } else if let res = ill.resolved, cal.dateComponents([.day], from: cal.startOfDay(for: res), to: cal.startOfDay(for: .now)).day ?? 99 < 3 {
                r.runEasyOnly = true
                r.reasons.append("Wiedereinstieg nach Krankheit")
                r.allReasons.append("Wiedereinstieg nach Krankheit")
            }
        }
        return r
    }
}

// MARK: Journal

struct JournalBehavior: Identifiable, Codable, Hashable {
    var id: String
    var label: String
    var icon: String
    var question: String
    var custom = false

    static let defaults: [JournalBehavior] = [
        JournalBehavior(id: "alcohol", label: "Alkohol", icon: "wineglass", question: "Alkohol getrunken?"),
        JournalBehavior(id: "caffeine_late", label: "Koffein nach 14 Uhr", icon: "cup.and.saucer", question: "Koffein nach 14 Uhr?"),
        JournalBehavior(id: "late_meal", label: "Spät gegessen", icon: "fork.knife", question: "Weniger als 2 Stunden vor dem Schlafen gegessen?"),
        JournalBehavior(id: "screen_bed", label: "Handy im Bett", icon: "iphone", question: "Im Bett noch aufs Handy geschaut?"),
        JournalBehavior(id: "stress", label: "Stressiger Tag", icon: "brain.head.profile", question: "War der Tag stressig?"),
        JournalBehavior(id: "sick", label: "Krankheitsgefühl", icon: "allergens", question: "Krank oder angeschlagen gefühlt?"),
        JournalBehavior(id: "hydrated", label: "Genug getrunken", icon: "drop", question: "Mindestens 2 Liter Wasser?"),
        JournalBehavior(id: "mobility", label: "Dehnen / Mobility", icon: "figure.flexibility", question: "Gedehnt oder Mobility gemacht?"),
        JournalBehavior(id: "sauna", label: "Sauna", icon: "flame", question: "In der Sauna gewesen?"),
        JournalBehavior(id: "reading", label: "Gelesen vorm Schlafen", icon: "book", question: "Vor dem Schlafen gelesen statt Bildschirm?"),
    ]

    static let fmt: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func key(_ d: Date) -> String { fmt.string(from: d) }
    static func date(_ k: String) -> Date? { fmt.date(from: k) }
}

// MARK: KI-Coach

struct CoachMessage: Identifiable, Codable, Hashable {
    var id = UUID()
    var role: String        // "user" oder "assistant"
    var text: String
    var date: Date = .now
}

// MARK: Gesamte gespeicherte Daten

struct AppData: Codable {
    var profile = Profile()
    var routines: [Routine] = []
    var sessions: [StrengthSession] = []
    var customExercises: [Exercise] = []
    var injuries: [Injury] = []
    var illness: Illness? = nil
    var plan: TrainingPlan? = nil
    var foods: [FoodItem] = []
    var entries: [FoodEntry] = []
    var seeded = false
    /// Tag (yyyy-MM-dd) → Verhalten → ja/nein
    var journal: [String: [String: Bool]] = [:]
    var customBehaviors: [JournalBehavior] = []
    var hiddenBehaviors: [String] = []
    var coachMemory: [String] = []
    var coachHistory: [CoachMessage] = []
    var sleepPrefs = SleepPrefs()

    init() {}

    var behaviors: [JournalBehavior] {
        (JournalBehavior.defaults + customBehaviors).filter { !hiddenBehaviors.contains($0.id) }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        profile = (try? c.decodeIfPresent(Profile.self, forKey: .profile)) ?? Profile()
        routines = (try? c.decodeIfPresent([Routine].self, forKey: .routines)) ?? []
        sessions = (try? c.decodeIfPresent([StrengthSession].self, forKey: .sessions)) ?? []
        customExercises = (try? c.decodeIfPresent([Exercise].self, forKey: .customExercises)) ?? []
        injuries = (try? c.decodeIfPresent([Injury].self, forKey: .injuries)) ?? []
        illness = try? c.decodeIfPresent(Illness.self, forKey: .illness)
        plan = try? c.decodeIfPresent(TrainingPlan.self, forKey: .plan)
        foods = (try? c.decodeIfPresent([FoodItem].self, forKey: .foods)) ?? []
        entries = (try? c.decodeIfPresent([FoodEntry].self, forKey: .entries)) ?? []
        seeded = (try? c.decodeIfPresent(Bool.self, forKey: .seeded)) ?? false
        journal = (try? c.decodeIfPresent([String: [String: Bool]].self, forKey: .journal)) ?? [:]
        customBehaviors = (try? c.decodeIfPresent([JournalBehavior].self, forKey: .customBehaviors)) ?? []
        hiddenBehaviors = (try? c.decodeIfPresent([String].self, forKey: .hiddenBehaviors)) ?? []
        coachMemory = (try? c.decodeIfPresent([String].self, forKey: .coachMemory)) ?? []
        coachHistory = (try? c.decodeIfPresent([CoachMessage].self, forKey: .coachHistory)) ?? []
        sleepPrefs = (try? c.decodeIfPresent(SleepPrefs.self, forKey: .sleepPrefs)) ?? SleepPrefs()
    }
}

@Observable
final class DataStore {
    private(set) var data = AppData()
    var activeSession: StrengthSession?

    private let url = AppGroup.containerURL.appendingPathComponent("form-data.json")
    private let sessionURL = AppGroup.containerURL.appendingPathComponent("form-active-session.json")

    init() {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .secondsSince1970
        if let d = try? Data(contentsOf: url), let decoded = try? dec.decode(AppData.self, from: d) {
            data = decoded
        }
        if let d = try? Data(contentsOf: sessionURL), let s = try? dec.decode(StrengthSession.self, from: d) {
            activeSession = s
        }
        ExerciseDB.custom = data.customExercises
        if !data.seeded {
            data.routines = DataStore.defaultRoutines
            data.seeded = true
            save()
        }
    }

    func update(_ change: (inout AppData) -> Void) {
        change(&data)
        ExerciseDB.custom = data.customExercises
        save()
    }

    private func save() {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .secondsSince1970
        if let d = try? enc.encode(data) { try? d.write(to: url, options: .atomic) }
    }

    func saveActiveSession() {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .secondsSince1970
        if let s = activeSession, let d = try? enc.encode(s) {
            try? d.write(to: sessionURL, options: .atomic)
        } else {
            try? FileManager.default.removeItem(at: sessionURL)
        }
    }

    var restrictions: Restrictions { Restrictions.from(injuries: data.injuries, illness: data.illness) }

    static var defaultRoutines: [Routine] {
        [
            Routine(name: "Oberkörper", items: [
                RoutineItem(exerciseId: "bench", sets: 3, repMin: 6, repMax: 10),
                RoutineItem(exerciseId: "bb_row", sets: 3, repMin: 6, repMax: 10),
                RoutineItem(exerciseId: "db_ohp", sets: 3, repMin: 8, repMax: 12),
                RoutineItem(exerciseId: "pullup", sets: 3, repMin: 5, repMax: 10),
                RoutineItem(exerciseId: "lat_raise", sets: 3, repMin: 12, repMax: 20),
                RoutineItem(exerciseId: "pushdown", sets: 2, repMin: 10, repMax: 15),
                RoutineItem(exerciseId: "curl", sets: 2, repMin: 10, repMax: 15),
            ]),
            Routine(name: "Beine & Rumpf", items: [
                RoutineItem(exerciseId: "squat", sets: 3, repMin: 5, repMax: 8),
                RoutineItem(exerciseId: "rdl", sets: 3, repMin: 6, repMax: 10),
                RoutineItem(exerciseId: "bulgarian", sets: 3, repMin: 8, repMax: 12),
                RoutineItem(exerciseId: "leg_curl", sets: 2, repMin: 10, repMax: 15),
                RoutineItem(exerciseId: "calf_raise", sets: 3, repMin: 10, repMax: 15),
                RoutineItem(exerciseId: "copenhagen", sets: 2, repMin: 20, repMax: 40),
                RoutineItem(exerciseId: "dead_bug", sets: 2, repMin: 10, repMax: 16),
            ]),
            Routine(name: "Läufer-Kraft", items: [
                RoutineItem(exerciseId: "bulgarian", sets: 3, repMin: 6, repMax: 10),
                RoutineItem(exerciseId: "rdl", sets: 3, repMin: 6, repMax: 10),
                RoutineItem(exerciseId: "step_up", sets: 2, repMin: 8, repMax: 12),
                RoutineItem(exerciseId: "seated_calf", sets: 3, repMin: 10, repMax: 15),
                RoutineItem(exerciseId: "tib_raise", sets: 2, repMin: 15, repMax: 25),
                RoutineItem(exerciseId: "side_plank", sets: 2, repMin: 30, repMax: 60),
            ]),
        ]
    }
}
