import Foundation
import HealthKit
import SwiftUI

// MARK: Zyklus

enum CyclePhase: String, CaseIterable {
    case menstrual, follicular, ovulation, luteal, lateLuteal, late

    var label: String {
        switch self {
        case .menstrual: return "Periode"
        case .follicular: return "Follikelphase"
        case .ovulation: return "Eisprung"
        case .luteal: return "Lutealphase"
        case .lateLuteal: return "Späte Lutealphase"
        case .late: return "Überfällig"
        }
    }

    var color: Color {
        switch self {
        case .menstrual: return Color(hex: 0xFF6B8A)
        case .follicular: return Theme.good
        case .ovulation: return Theme.accent
        case .luteal: return Theme.warn
        case .lateLuteal: return Color(hex: 0xFF9F7A)
        case .late: return Theme.muted
        }
    }

    /// Was der Körper in dieser Phase typischerweise macht
    var body: String {
        switch self {
        case .menstrual:
            return "Östrogen und Progesteron sind niedrig. Viele fühlen sich an Tag 1 und 2 schlapp, danach steigt die Energie schnell. Eisenbedarf ist höher."
        case .follicular:
            return "Östrogen steigt. Mehr Kraft, bessere Erholung, höhere Schmerztoleranz. Die beste Phase für harte Einheiten und neue Bestleistungen."
        case .ovulation:
            return "Östrogen am Höchststand, kurz danach ein LH-Peak. Leistungsfähig, aber Bänder sind etwas lockerer: sauber aufwärmen, Sprünge und schnelle Richtungswechsel kontrolliert."
        case .luteal:
            return "Progesteron steigt. Körpertemperatur liegt 0,3 bis 0,5 °C höher, Ruhepuls 2 bis 5 bpm höher, HRV etwas niedriger. Das ist normal und kein Warnsignal. Ausdauer bei Hitze fällt schwerer, mehr trinken."
        case .lateLuteal:
            return "Die letzten Tage vor der Periode. Schlaf oft unruhiger, Hunger höher, Stimmung schwankt. Lockeres Training tut gut, harte Einheiten lieber auf die Tage nach der Periode legen."
        case .late:
            return "Die Periode ist später als in deinen letzten Zyklen. Zyklen schwanken, besonders bei Stress, Reisen oder viel Training."
        }
    }

    var training: String {
        switch self {
        case .menstrual: return "Locker starten, ab Tag 3 geht wieder alles"
        case .follicular: return "Harte Einheiten, Intervalle, schwere Sätze"
        case .ovulation: return "Volle Leistung, gut aufwärmen"
        case .luteal: return "Normal trainieren, bei Hitze kürzer"
        case .lateLuteal: return "Locker halten, Schlaf schützen"
        case .late: return "Nach Gefühl trainieren"
        }
    }

    /// Phasen mit angehobener Temperatur und Ruhepuls
    var isHighHormone: Bool { self == .luteal || self == .lateLuteal }
}

struct CycleState {
    let lastStart: Date
    /// Tag im Zyklus, 1 = erster Tag der Periode
    let day: Int
    let length: Int
    let periodDays: Int
    let phase: CyclePhase
    let regularity: Double?     // Standardabweichung der Zykluslängen in Tagen
    let history: [CycleRecord]

    var nextPeriod: Date { Calendar.current.addDays(length, to: lastStart) }
    var ovulation: Date { Calendar.current.addDays(length - 14, to: lastStart) }
    var daysToPeriod: Int { max(0, Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: .now), to: nextPeriod).day ?? 0) }
}

struct CycleRecord: Identifiable {
    var id: Date { start }
    let start: Date
    let length: Int?
    let periodDays: Int
}

/// Korrektur für Lutealphasen: so viel liegen Temperatur, Ruhepuls und HRV dort typischerweise über oder unter der Follikelphase
struct CycleCorrection {
    var temp: Double = 0
    var rhr: Double = 0
    var hrv: Double = 0
    var samples = 0
}

enum CycleModel {
    /// Zyklusstarts aus Blutungs-Einträgen: neuer Zyklus, wenn mehr als 5 Tage keine Blutung war oder Apple den Start markiert hat
    static func records(from flow: [(day: Date, cycleStart: Bool)]) -> [CycleRecord] {
        let cal = Calendar.current
        let days = Array(Set(flow.map { cal.startOfDay(for: $0.day) })).sorted()
        let marked = Set(flow.filter(\.cycleStart).map { cal.startOfDay(for: $0.day) })
        guard !days.isEmpty else { return [] }
        var starts: [Date] = []
        var prev: Date?
        for d in days {
            let gap = prev.map { cal.dateComponents([.day], from: $0, to: d).day ?? 99 } ?? 99
            if marked.contains(d) || gap > 5 { starts.append(d) }
            prev = d
        }
        var out: [CycleRecord] = []
        for (i, s) in starts.enumerated() {
            let next = i + 1 < starts.count ? starts[i + 1] : nil
            let len = next.map { cal.dateComponents([.day], from: s, to: $0).day ?? 28 }
            let end = next ?? cal.addDays(10, to: s)
            let pd = days.filter { $0 >= s && $0 < end && (cal.dateComponents([.day], from: s, to: $0).day ?? 0) <= 9 }.count
            out.append(CycleRecord(start: s, length: len, periodDays: max(1, pd)))
        }
        return out
    }

    static func state(records: [CycleRecord], today: Date = .now) -> CycleState? {
        guard let last = records.last else { return nil }
        let cal = Calendar.current
        let lengths = records.suffix(7).compactMap(\.length).filter { (18...45).contains($0) }
        let length = lengths.isEmpty ? 28 : Int((Double(lengths.reduce(0, +)) / Double(lengths.count)).rounded())
        let periodDays = max(2, min(8, records.suffix(4).map(\.periodDays).max() ?? 5))
        let day = (cal.dateComponents([.day], from: last.start, to: cal.startOfDay(for: today)).day ?? 0) + 1
        guard day <= 60 else { return nil }   // zu lange her: keine Aussage
        var sd: Double?
        if lengths.count >= 3 {
            let m = Double(lengths.reduce(0, +)) / Double(lengths.count)
            sd = sqrt(lengths.map { pow(Double($0) - m, 2) }.reduce(0, +) / Double(lengths.count - 1))
        }
        return CycleState(lastStart: last.start, day: day, length: length, periodDays: periodDays,
                          phase: phase(day: day, length: length, periodDays: periodDays), regularity: sd, history: records)
    }

    static func phase(day: Int, length: Int, periodDays: Int) -> CyclePhase {
        let ov = length - 14
        if day > length + 3 { return .late }
        if day <= periodDays { return .menstrual }
        if day >= ov - 1 && day <= ov + 1 { return .ovulation }
        if day < ov { return .follicular }
        if day >= length - 3 { return .lateLuteal }
        return .luteal
    }

    /// Phase an einem beliebigen Tag der Vergangenheit
    static func phase(on day: Date, records: [CycleRecord], defaultLength: Int) -> CyclePhase? {
        let cal = Calendar.current
        let d = cal.startOfDay(for: day)
        guard let rec = records.last(where: { $0.start <= d }) else { return nil }
        let n = (cal.dateComponents([.day], from: rec.start, to: d).day ?? 0) + 1
        let len = rec.length ?? defaultLength
        guard n <= len + 3 else { return nil }
        return phase(day: n, length: len, periodDays: rec.periodDays)
    }

    /// Mittlerer Unterschied Luteal minus Follikel über die Vergangenheit
    static func correction(days: [DayMetrics], records: [CycleRecord], defaultLength: Int) -> CycleCorrection? {
        var lut: [DayMetrics] = [], fol: [DayMetrics] = []
        for d in days {
            switch phase(on: d.day, records: records, defaultLength: defaultLength) {
            case .luteal, .lateLuteal: lut.append(d)
            case .follicular, .ovulation: fol.append(d)
            default: break
            }
        }
        guard lut.count >= 6, fol.count >= 6 else { return nil }
        func diff(_ k: KeyPath<DayMetrics, Double?>) -> Double {
            let a = lut.compactMap { $0[keyPath: k] }, b = fol.compactMap { $0[keyPath: k] }
            guard a.count >= 4, b.count >= 4 else { return 0 }
            return a.reduce(0, +) / Double(a.count) - b.reduce(0, +) / Double(b.count)
        }
        var c = CycleCorrection()
        c.temp = max(0, min(0.8, diff(\.temp)))
        c.rhr = max(0, min(8, diff(\.rhr)))
        c.hrv = min(0, max(-20, diff(\.hrv)))
        c.samples = lut.count + fol.count
        return c
    }

    /// Tageswerte so verschieben, dass Lutealphasen mit Follikelphasen vergleichbar sind
    static func adjust(_ days: [DayMetrics], records: [CycleRecord], defaultLength: Int, correction: CycleCorrection) -> [DayMetrics] {
        days.map { d in
            guard let p = phase(on: d.day, records: records, defaultLength: defaultLength), p.isHighHormone else { return d }
            var m = d
            if let t = m.temp { m.temp = t - correction.temp }
            if let r = m.rhr { m.rhr = r - correction.rhr }
            if let h = m.hrv { m.hrv = h - correction.hrv }
            if let h = m.rmssd { m.rmssd = h - correction.hrv }
            return m
        }
    }
}

// MARK: HealthKit

extension HealthService {
    var cycleType: HKCategoryType { HKCategoryType(.menstrualFlow) }

    func menstrualFlow(from: Date) async throws -> [(day: Date, cycleStart: Bool)] {
        let pred = HKQuery.predicateForSamples(withStart: from, end: .now, options: [])
        let d = HKSampleQueryDescriptor(predicates: [.categorySample(type: cycleType, predicate: pred)],
                                        sortDescriptors: [SortDescriptor(\.startDate, order: .forward)])
        let samples = try await d.result(for: store)
        return samples.compactMap { s in
            guard s.value != HKCategoryValueMenstrualFlow.none.rawValue else { return nil }
            let start = (s.metadata?[HKMetadataKeyMenstrualCycleStart] as? Bool) ?? false
            return (s.startDate, start)
        }
    }

    func requestCycleWrite() async throws {
        try await store.requestAuthorization(toShare: [cycleType], read: [cycleType])
    }

    /// Periode für einen Tag eintragen
    func logPeriod(day: Date, cycleStart: Bool, heavy: Bool = false) async throws {
        let cal = Calendar.current
        let start = cal.startOfDay(for: day)
        let end = cal.addDays(1, to: start).addingTimeInterval(-1)
        let value: HKCategoryValueMenstrualFlow = heavy ? .heavy : .medium
        let s = HKCategorySample(type: cycleType, value: value.rawValue, start: start, end: end,
                                 metadata: [HKMetadataKeyMenstrualCycleStart: cycleStart])
        try await store.save(s)
    }
}
