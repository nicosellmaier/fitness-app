import Foundation

enum BodyRegion: String, Codable, CaseIterable, Identifiable {
    case neck, shoulder, elbow, wrist, upperBack, lowerBack, hip, knee, ankle, achilles, foot

    var id: String { rawValue }

    var label: String {
        switch self {
        case .neck: return "Nacken"
        case .shoulder: return "Schulter"
        case .elbow: return "Ellenbogen"
        case .wrist: return "Handgelenk"
        case .upperBack: return "Oberer Rücken"
        case .lowerBack: return "Unterer Rücken"
        case .hip: return "Hüfte"
        case .knee: return "Knie"
        case .ankle: return "Sprunggelenk"
        case .achilles: return "Achillessehne"
        case .foot: return "Fuß"
        }
    }

    /// Betrifft das Laufen direkt
    var affectsRunning: Bool { [.lowerBack, .hip, .knee, .ankle, .achilles, .foot].contains(self) }
    var hasSide: Bool { ![.neck, .upperBack, .lowerBack].contains(self) }
}

enum MuscleGroup: String, Codable, CaseIterable, Identifiable {
    case chest, back, shoulders, biceps, triceps, quads, hamstrings, glutes, calves, core

    var id: String { rawValue }

    var label: String {
        switch self {
        case .chest: return "Brust"
        case .back: return "Rücken"
        case .shoulders: return "Schultern"
        case .biceps: return "Bizeps"
        case .triceps: return "Trizeps"
        case .quads: return "Oberschenkel vorne"
        case .hamstrings: return "Beinbeuger"
        case .glutes: return "Gesäß"
        case .calves: return "Waden"
        case .core: return "Rumpf"
        }
    }
}

struct Exercise: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let primary: MuscleGroup
    let stress: [BodyRegion]
    let equipment: String
    let compound: Bool
    let increment: Double
    var bodyweight: Bool = false
}

enum ExerciseDB {
    private static func ex(_ id: String, _ name: String, _ m: MuscleGroup, _ s: [BodyRegion], _ eq: String, compound: Bool = false, inc: Double = 2.5, bw: Bool = false) -> Exercise {
        Exercise(id: id, name: name, primary: m, stress: s, equipment: eq, compound: compound, increment: inc, bodyweight: bw)
    }

    static let builtIn: [Exercise] = [
        // Brust
        ex("bench", "Bankdrücken", .chest, [.shoulder, .elbow, .wrist], "Langhantel", compound: true),
        ex("incline_db", "Schrägbankdrücken Kurzhantel", .chest, [.shoulder, .elbow, .wrist], "Kurzhantel", compound: true, inc: 2),
        ex("db_bench", "Kurzhantel-Bankdrücken", .chest, [.shoulder, .elbow, .wrist], "Kurzhantel", compound: true, inc: 2),
        ex("chest_press", "Brustpresse Maschine", .chest, [.shoulder, .elbow], "Maschine", compound: true, inc: 5),
        ex("dips", "Dips", .chest, [.shoulder, .elbow, .wrist], "Körpergewicht", compound: true, bw: true),
        ex("pushup", "Liegestütze", .chest, [.shoulder, .wrist, .elbow], "Körpergewicht", compound: true, bw: true),
        ex("cable_fly", "Kabelzug-Fliegende", .chest, [.shoulder], "Kabel", inc: 2.5),
        // Rücken
        ex("pullup", "Klimmzüge", .back, [.shoulder, .elbow], "Körpergewicht", compound: true, bw: true),
        ex("lat_pulldown", "Latzug", .back, [.shoulder, .elbow], "Kabel", compound: true, inc: 5),
        ex("bb_row", "Rudern Langhantel", .back, [.lowerBack, .shoulder, .elbow], "Langhantel", compound: true),
        ex("db_row", "Einarmiges Rudern Kurzhantel", .back, [.shoulder, .elbow], "Kurzhantel", compound: true, inc: 2),
        ex("chest_row", "Rudern brustgestützt", .back, [.shoulder, .elbow], "Maschine", compound: true, inc: 5),
        ex("cable_row", "Rudern am Kabel", .back, [.shoulder, .elbow, .lowerBack], "Kabel", compound: true, inc: 5),
        ex("face_pull", "Face Pulls", .shoulders, [.shoulder], "Kabel", inc: 2.5),
        ex("back_ext", "Hyperextensions", .back, [.lowerBack], "Körpergewicht", bw: true),
        // Schultern
        ex("ohp", "Schulterdrücken Langhantel", .shoulders, [.shoulder, .elbow, .wrist, .lowerBack], "Langhantel", compound: true),
        ex("db_ohp", "Schulterdrücken Kurzhantel", .shoulders, [.shoulder, .elbow, .wrist], "Kurzhantel", compound: true, inc: 2),
        ex("lat_raise", "Seitheben", .shoulders, [.shoulder], "Kurzhantel", inc: 1),
        ex("rear_delt", "Reverse Flys", .shoulders, [.shoulder], "Kurzhantel", inc: 1),
        // Arme
        ex("curl", "Bizepscurls Kurzhantel", .biceps, [.elbow, .wrist], "Kurzhantel", inc: 1),
        ex("hammer_curl", "Hammercurls", .biceps, [.elbow, .wrist], "Kurzhantel", inc: 1),
        ex("cable_curl", "Bizepscurls Kabel", .biceps, [.elbow], "Kabel", inc: 2.5),
        ex("pushdown", "Trizepsdrücken Kabel", .triceps, [.elbow], "Kabel", inc: 2.5),
        ex("skullcrusher", "French Press", .triceps, [.elbow, .shoulder], "SZ-Stange", inc: 2.5),
        ex("overhead_ext", "Trizeps über Kopf", .triceps, [.elbow, .shoulder], "Kabel", inc: 2.5),
        // Beine
        ex("squat", "Kniebeuge", .quads, [.knee, .hip, .lowerBack, .ankle], "Langhantel", compound: true, inc: 2.5),
        ex("front_squat", "Frontkniebeuge", .quads, [.knee, .hip, .wrist, .ankle], "Langhantel", compound: true),
        ex("goblet", "Goblet Squat", .quads, [.knee, .hip], "Kurzhantel", compound: true, inc: 2),
        ex("leg_press", "Beinpresse", .quads, [.knee, .hip], "Maschine", compound: true, inc: 10),
        ex("bulgarian", "Bulgarian Split Squat", .quads, [.knee, .hip, .ankle], "Kurzhantel", compound: true, inc: 2),
        ex("lunge", "Ausfallschritte", .quads, [.knee, .hip, .ankle], "Kurzhantel", compound: true, inc: 2),
        ex("leg_ext", "Beinstrecker", .quads, [.knee], "Maschine", inc: 5),
        ex("deadlift", "Kreuzheben", .hamstrings, [.lowerBack, .hip, .knee, .wrist], "Langhantel", compound: true, inc: 5),
        ex("rdl", "Rumänisches Kreuzheben", .hamstrings, [.lowerBack, .hip], "Langhantel", compound: true, inc: 2.5),
        ex("leg_curl", "Beinbeuger Maschine", .hamstrings, [.knee], "Maschine", inc: 5),
        ex("nordic", "Nordic Curls", .hamstrings, [.knee], "Körpergewicht", bw: true),
        ex("hip_thrust", "Hip Thrust", .glutes, [.hip, .lowerBack], "Langhantel", compound: true, inc: 5),
        ex("glute_bridge", "Glute Bridge", .glutes, [.hip], "Körpergewicht", bw: true),
        ex("step_up", "Step-ups", .glutes, [.knee, .hip, .ankle], "Kurzhantel", compound: true, inc: 2),
        ex("abductor", "Abduktoren Maschine", .glutes, [.hip], "Maschine", inc: 5),
        ex("calf_raise", "Wadenheben stehend", .calves, [.ankle, .achilles, .foot], "Maschine", inc: 5),
        ex("seated_calf", "Wadenheben sitzend", .calves, [.achilles, .ankle], "Maschine", inc: 5),
        // Rumpf
        ex("plank", "Unterarmstütz", .core, [.shoulder, .lowerBack], "Körpergewicht", bw: true),
        ex("side_plank", "Seitstütz", .core, [.shoulder], "Körpergewicht", bw: true),
        ex("dead_bug", "Dead Bug", .core, [], "Körpergewicht", bw: true),
        ex("pallof", "Pallof Press", .core, [.shoulder], "Kabel", inc: 2.5),
        ex("hanging_raise", "Hängendes Beinheben", .core, [.shoulder, .wrist], "Körpergewicht", bw: true),
        ex("crunch_cable", "Kabelcrunch", .core, [.lowerBack], "Kabel", inc: 5),
        ex("bird_dog", "Bird Dog", .core, [.wrist], "Körpergewicht", bw: true),
        ex("copenhagen", "Copenhagen Plank", .core, [.hip], "Körpergewicht", bw: true),
        // Reha
        ex("band_er", "Außenrotation mit Band", .shoulders, [], "Band", bw: true),
        ex("tib_raise", "Tibialis Raises", .calves, [.ankle], "Körpergewicht", bw: true),
        ex("wall_sit", "Wandsitzen", .quads, [.knee], "Körpergewicht", bw: true),
    ]

    static var custom: [Exercise] = []

    static var all: [Exercise] { builtIn + custom }

    static func find(_ id: String) -> Exercise? {
        all.first { $0.id == id }
    }

    static func name(_ id: String) -> String { find(id)?.name ?? "Übung" }

    static func isBlocked(_ e: Exercise, by regions: Set<BodyRegion>) -> Bool {
        !regions.isDisjoint(with: e.stress)
    }

    /// Ersatzübungen, die denselben Muskel treffen, aber die verletzte Region nicht belasten
    static func alternatives(for e: Exercise, avoiding regions: Set<BodyRegion>) -> [Exercise] {
        all.filter { $0.id != e.id && $0.primary == e.primary && $0.stress.allSatisfy { !regions.contains($0) } }
            .sorted { a, b in
                if a.compound != b.compound { return a.compound == e.compound }
                return a.stress.count < b.stress.count
            }
    }

    /// Wenn für den Muskel nichts geht: sinnvolle Alternative aus einer anderen Gruppe
    static func fallback(avoiding regions: Set<BodyRegion>, preferLower: Bool) -> Exercise? {
        let order: [MuscleGroup] = preferLower ? [.quads, .hamstrings, .glutes, .calves, .core] : [.core, .glutes, .hamstrings, .quads]
        for m in order {
            if let e = all.first(where: { $0.primary == m && $0.stress.allSatisfy { !regions.contains($0) } }) { return e }
        }
        return nil
    }

    static var grouped: [(MuscleGroup, [Exercise])] {
        MuscleGroup.allCases.compactMap { m in
            let l = all.filter { $0.primary == m }.sorted { $0.name < $1.name }
            return l.isEmpty ? nil : (m, l)
        }
    }
}
