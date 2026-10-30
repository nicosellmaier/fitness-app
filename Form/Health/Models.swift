import Foundation
import HealthKit
import CoreLocation
import SwiftUI

enum SleepStage: Int, CaseIterable, Identifiable {
    case awake, rem, core, deep

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .awake: return "Wach"
        case .rem: return "REM"
        case .core: return "Kern"
        case .deep: return "Tief"
        }
    }

    var color: Color {
        switch self {
        case .awake: return Theme.warn
        case .rem: return Theme.sleep
        case .core: return Theme.core
        case .deep: return Theme.deep
        }
    }
}

struct SleepSegment: Identifiable {
    let id = UUID()
    let start: Date
    let end: Date
    let stage: SleepStage
    var duration: TimeInterval { end.timeIntervalSince(start) }
}

struct SleepNight: Identifiable {
    let id = UUID()
    let wakeDay: Date
    let inBedStart: Date
    let segments: [SleepSegment]
    let hasStages: Bool

    var start: Date { segments.first?.start ?? inBedStart }
    var end: Date { segments.last?.end ?? inBedStart }

    func time(_ s: SleepStage) -> TimeInterval {
        segments.filter { $0.stage == s }.reduce(0) { $0 + $1.duration }
    }

    var asleep: TimeInterval { time(.rem) + time(.core) + time(.deep) }
    var span: TimeInterval { end.timeIntervalSince(min(inBedStart, start)) }
    var efficiency: Double { span > 0 ? asleep / span : 0 }

    var fellAsleep: Date { segments.first(where: { $0.stage != .awake })?.start ?? start }
    var latency: TimeInterval { max(0, fellAsleep.timeIntervalSince(min(inBedStart, start))) }

    var awakenings: [SleepSegment] {
        let first = fellAsleep
        let lastAsleep = segments.last(where: { $0.stage != .awake })?.end ?? end
        return segments.filter { $0.stage == .awake && $0.start > first && $0.end <= lastAsleep }
    }

    var bedTime: Date { min(inBedStart, start) }
}

struct DayMetrics: Identifiable {
    var id: Date { day }
    let day: Date
    var hrv: Double? = nil
    var rhr: Double? = nil
    var resp: Double? = nil
    var spo2: Double? = nil
    var spo2Min: Double? = nil
    var temp: Double? = nil
    var sleep: SleepNight? = nil
    /// RMSSD aus Schlag-zu-Schlag-Reihen im Schlaf (ms)
    var rmssd: Double? = nil
    var steps: Double? = nil
    var exerciseMin: Double? = nil
}

struct Point: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

enum ActivityKind {
    case endurance, strength, other

    var label: String {
        switch self {
        case .endurance: return "AUSDAUER"
        case .strength: return "KRAFT"
        case .other: return "AKTIV"
        }
    }

    var color: Color {
        switch self {
        case .endurance: return Theme.accent
        case .strength: return Theme.warn
        case .other: return Theme.sleep
        }
    }
}

struct WorkoutItem: Identifiable {
    let id: UUID
    let workout: HKWorkout?
    let activity: HKWorkoutActivityType
    let kind: ActivityKind
    let name: String
    let start: Date
    let end: Date
    let duration: TimeInterval
    let distance: Double?
    let energy: Double?
    let avgHR: Double?
    let maxHR: Double?
    let elevation: Double?
    let indoor: Bool

    var pace: Double? {
        guard let d = distance, d > 200 else { return nil }
        return duration / (d / 1000)
    }

    var icon: String { WorkoutItem.icon(for: activity) }

    static func icon(for t: HKWorkoutActivityType) -> String {
        switch t {
        case .running: return "figure.run"
        case .walking: return "figure.walk"
        case .hiking: return "figure.hiking"
        case .cycling: return "figure.outdoor.cycle"
        case .swimming: return "figure.pool.swim"
        case .traditionalStrengthTraining: return "figure.strengthtraining.traditional"
        case .functionalStrengthTraining: return "figure.strengthtraining.functional"
        case .coreTraining: return "figure.core.training"
        case .highIntensityIntervalTraining: return "figure.highintensity.intervaltraining"
        case .yoga: return "figure.yoga"
        case .rowing: return "figure.rower"
        default: return "figure.mixed.cardio"
        }
    }

    static func kind(for t: HKWorkoutActivityType, distance: Double?) -> ActivityKind {
        switch t {
        case .running, .cycling, .swimming, .walking, .hiking, .rowing, .elliptical, .crossCountrySkiing, .stairClimbing:
            return .endurance
        case .traditionalStrengthTraining, .functionalStrengthTraining, .coreTraining, .crossTraining:
            return .strength
        default:
            return (distance ?? 0) > 500 ? .endurance : .other
        }
    }

    static func name(for t: HKWorkoutActivityType, start: Date) -> String {
        let h = Calendar.current.component(.hour, from: start)
        let part = h < 11 ? "Morgen" : h < 14 ? "Mittag" : h < 18 ? "Nachmittag" : "Abend"
        switch t {
        case .running: return part + "lauf"
        case .walking: return "Spaziergang"
        case .hiking: return "Wanderung"
        case .cycling: return part + "fahrt"
        case .swimming: return "Schwimmen"
        case .traditionalStrengthTraining: return "Krafttraining"
        case .functionalStrengthTraining: return "Funktionelles Training"
        case .coreTraining: return "Core-Training"
        case .highIntensityIntervalTraining: return "HIIT"
        case .yoga: return "Yoga"
        case .rowing: return "Rudern"
        case .elliptical: return "Crosstrainer"
        default: return "Training"
        }
    }
}

struct HRPoint: Identifiable {
    let id = UUID()
    let date: Date
    let bpm: Double
}

struct Split: Identifiable {
    let id: Int
    let distance: Double
    let duration: TimeInterval
    let avgHR: Double?
    let gain: Double

    var pace: Double { distance > 0 ? duration / (distance / 1000) : 0 }
}

struct ProfilePoint: Identifiable {
    let id = UUID()
    let distance: Double
    let altitude: Double
}

struct WorkoutDetail {
    var route: [CLLocation] = []
    var hr: [HRPoint] = []
    var splits: [Split] = []
    var zones: [TimeInterval] = Array(repeating: 0, count: 5)
    var profile: [ProfilePoint] = []
    var power: Double? = nil
    var groundContact: Double? = nil
    var verticalOsc: Double? = nil
    var stride: Double? = nil
    var cadence: Double? = nil
}

struct Recovery {
    let score: Int
    let label: String
    let color: Color
    let text: String
    let hrvDelta: Double?
    let rhrDelta: Double?
    /// Beitrag jedes Messwerts zum Score (Punkte, Basis 55)
    var parts: [RecoveryPart] = []
}

struct RecoveryPart: Identifiable {
    var id: String { name }
    let name: String
    let points: Double
    let detail: String
}

struct SleepNeed {
    let base: TimeInterval
    let strain: TimeInterval
    let debt: TimeInterval
    let weeklyDebt: TimeInterval
    var total: TimeInterval { base + strain + debt }
}
