import SwiftUI

/// Alle Messwerte, die eine eigene Detailseite haben
enum MetricKind: String, CaseIterable, Identifiable, Hashable {
    case recovery, strain, sleep, hrv, rhr, resp, spo2, temp, vo2, steps, exercise, weight

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recovery: return "Erholung"
        case .strain: return "Belastung"
        case .sleep: return "Schlafdauer"
        case .hrv: return "HRV"
        case .rhr: return "Ruhepuls"
        case .resp: return "Atemfrequenz"
        case .spo2: return "Blutsauerstoff"
        case .temp: return "Handgelenk-Temperatur"
        case .vo2: return "VO2max"
        case .steps: return "Schritte"
        case .exercise: return "Trainingsminuten"
        case .weight: return "Gewicht"
        }
    }

    var unit: String {
        switch self {
        case .recovery: return "%"
        case .strain: return "/21"
        case .sleep: return "h"
        case .hrv: return "ms"
        case .rhr: return "bpm"
        case .resp: return "/min"
        case .spo2: return "%"
        case .temp: return "°C"
        case .vo2: return "ml/kg/min"
        case .steps: return ""
        case .exercise: return "min"
        case .weight: return "kg"
        }
    }

    var icon: String {
        switch self {
        case .recovery: return "bolt.heart.fill"
        case .strain: return "flame.fill"
        case .sleep: return "bed.double.fill"
        case .hrv: return "waveform.path.ecg"
        case .rhr: return "heart.fill"
        case .resp: return "lungs.fill"
        case .spo2: return "drop.fill"
        case .temp: return "thermometer.medium"
        case .vo2: return "figure.run"
        case .steps: return "shoeprints.fill"
        case .exercise: return "figure.mixed.cardio"
        case .weight: return "scalemass.fill"
        }
    }

    var color: Color {
        switch self {
        case .recovery, .hrv: return Theme.good
        case .strain, .exercise: return Theme.warn
        case .sleep, .resp: return Theme.sleep
        case .rhr: return Theme.bad
        case .spo2: return Color(hex: 0x6FD3FF)
        case .temp: return Color(hex: 0xFF9F7A)
        case .vo2, .steps: return Theme.accent
        case .weight: return Theme.soft
        }
    }

    var digits: Int {
        switch self {
        case .resp, .vo2, .weight, .strain: return 1
        case .temp: return 2
        default: return 0
        }
    }

    /// nil: weder hoch noch tief ist besser
    var higherIsBetter: Bool? {
        switch self {
        case .recovery, .sleep, .hrv, .spo2, .vo2, .steps, .exercise: return true
        case .rhr: return false
        case .strain, .resp, .temp, .weight: return nil
        }
    }

    /// Balken statt Linie
    var bars: Bool { self == .steps || self == .exercise || self == .strain || self == .recovery || self == .sleep }

    func format(_ v: Double) -> String {
        switch self {
        case .sleep: return Fmt.hm(v * 3600)
        case .steps: return Fmt.num(v)
        default: return Fmt.num(v, digits)
        }
    }

    var about: String {
        switch self {
        case .recovery:
            return "Wie bereit dein Körper heute ist. Der Wert kombiniert HRV und Ruhepuls im Vergleich zu deinen letzten 30 Tagen mit der Schlafdauer gegenüber deinem Bedarf. Atemfrequenz und Temperatur ziehen ab, wenn sie deutlich erhöht sind."
        case .strain:
            return "Wie stark dein Herz-Kreislauf-System und deine Muskeln über den Tag gefordert wurden. Berechnet nach Banister (TRIMP) aus der Zeit in höheren Pulsbereichen, plus Krafttraining. Die Skala sättigt bei 21: Jeder weitere Punkt kostet mehr."
        case .sleep:
            return "Echte Schlafzeit ohne Wachphasen. Für Erwachsene sind 7 bis 9 Stunden empfohlen. Wer viel trainiert, braucht eher das obere Ende."
        case .hrv:
            return "Herzfrequenzvariabilität: die Schwankung der Zeit zwischen zwei Herzschlägen, gemessen im Schlaf. Hohe Werte zeigen ein entspanntes, erholtes Nervensystem. Der Wert ist sehr individuell, wichtig ist nur dein eigener Verlauf."
        case .rhr:
            return "Dein niedrigster stabiler Puls in Ruhe. Er sinkt mit besserer Fitness. Ein Anstieg um 5 bpm oder mehr über deinem Schnitt deutet oft auf Stress, Alkohol, Hitze, Schlafmangel oder einen beginnenden Infekt hin."
        case .resp:
            return "Atemzüge pro Minute im Schlaf. Der Wert ist bei gesunden Menschen sehr stabil, meist 12 bis 20. Ein plötzlicher Anstieg ist eines der frühesten Zeichen für einen Infekt."
        case .spo2:
            return "Anteil des Hämoglobins, der Sauerstoff trägt. Normal sind 95 bis 100 %. Die Watch misst im Schlaf. Einzelne tiefere Werte sind meist Messfehler, dauerhaft unter 95 % gehören ärztlich abgeklärt."
        case .temp:
            return "Hauttemperatur am Handgelenk im Schlaf. Der absolute Wert sagt wenig, wichtig ist die Abweichung von deinem Schnitt. Über +0,5 °C kann auf Fieber oder einen Infekt hindeuten. Bei Frauen schwankt sie mit dem Zyklus."
        case .vo2:
            return "Maximale Sauerstoffaufnahme, geschätzt von der Watch bei Läufen und Gehen im Freien. Der stärkste einzelne Messwert für Fitness und Lebenserwartung."
        case .steps:
            return "Schritte pro Tag. Studien zeigen: Das Sterberisiko sinkt deutlich bis etwa 8.000 bis 10.000 Schritte, danach flacht der Nutzen ab."
        case .exercise:
            return "Minuten mit mindestens zügigem Gehen, laut Apple-Watch-Trainingsring. Die WHO empfiehlt 150 bis 300 Minuten moderate Aktivität pro Woche."
        case .weight:
            return "Körpergewicht aus Apple Health, etwa von einer smarten Waage. Einzelne Tage schwanken um 1 bis 2 kg durch Wasser und Essen. Aussagekräftig ist der Trend über Wochen."
        }
    }

    var tips: [String] {
        switch self {
        case .recovery:
            return ["Regelmäßige Schlafenszeiten, auch am Wochenende", "Kein Alkohol am Abend, er senkt die HRV stark", "Nach harten Tagen bewusst locker bleiben"]
        case .strain:
            return ["Bei hoher Erholung darf die Belastung hoch sein", "Nach zwei harten Tagen einen lockeren einbauen", "Lange Phasen mit sehr wenig Belastung kosten Fitness"]
        case .sleep:
            return ["Jeden Tag zur gleichen Zeit aufstehen", "Schlafzimmer kühl und dunkel, etwa 18 °C", "Koffein nur bis etwa 8 bis 10 Stunden vor dem Schlafen"]
        case .hrv:
            return ["Genug schlafen und regelmäßig trainieren", "Alkohol und spätes, schweres Essen vermeiden", "Langsames Atmen (6 Atemzüge pro Minute) beruhigt akut"]
        case .rhr:
            return ["Lockeres Ausdauertraining senkt ihn langfristig", "Genug trinken, besonders nach Hitze und Sport", "Bei Anstieg plus Krankheitsgefühl: Pause"]
        case .resp:
            return ["Ein Anstieg um mehr als 1 bis 2 Atemzüge ist ein Warnsignal", "Dann Training reduzieren und mehr schlafen"]
        case .spo2:
            return ["Watch eng genug tragen, sonst gibt es Messfehler", "In der Höhe sind tiefere Werte normal"]
        case .temp:
            return ["Watch jede Nacht tragen, damit der Schnitt stabil ist", "Erhöhte Werte mit Ruhepuls und HRV zusammen ansehen"]
        case .vo2:
            return ["Intervalle im Bereich 90 bis 95 % der Maximalpuls bringen am meisten", "Viel lockeres Laufen bildet die Basis", "Regelmäßig draußen mit Watch laufen, damit sie messen kann"]
        case .steps:
            return ["Telefonate im Gehen führen", "Nach dem Essen 10 Minuten gehen, das senkt auch den Blutzucker", "Treppe statt Aufzug"]
        case .exercise:
            return ["Lieber täglich 30 Minuten als einmal 3 Stunden", "Zügiges Gehen zählt schon"]
        case .weight:
            return ["Morgens nach dem Aufstehen wiegen, immer gleich", "Auf den Wochenschnitt achten, nicht auf einzelne Tage"]
        }
    }
}

extension AppModel {
    /// Tageswerte eines Messwerts, älteste zuerst
    func points(_ k: MetricKind) -> [Point] {
        let cal = Calendar.current
        func fromDict(_ d: [Date: Double]) -> [Point] {
            d.filter { $0.value > 0 }.sorted { $0.key < $1.key }.map { Point(date: $0.key, value: $0.value) }
        }
        switch k {
        case .recovery:
            return days.indices.compactMap { i in recovery(at: i).map { Point(date: days[i].day, value: Double($0.score)) } }
        case .strain:
            // Pulsverlauf gibt es nur 14 Tage, davor schätzt die App aus den Workouts
            let first = days.first?.day ?? cal.addDays(-89, to: cal.startOfDay(for: .now))
            var out: [Point] = []
            var d = first
            let end = cal.startOfDay(for: .now)
            let hrStart = hr.map(\.date).min().map { cal.startOfDay(for: $0) } ?? end
            let byDay = Dictionary(grouping: hr) { cal.startOfDay(for: $0.date) }
            while d <= end {
                let s = Strain.day(d, hr: d >= hrStart ? (byDay[d] ?? []) : [], workouts: workouts, sessions: sessions,
                                   rhr: restingHR, maxHR: maxHR, female: female)
                out.append(Point(date: d, value: s.score))
                d = cal.addDays(1, to: d)
            }
            return out
        case .sleep:
            return nights.map { Point(date: cal.startOfDay(for: $0.wakeDay), value: $0.asleep / 3600) }
        case .hrv: return series(\.hrv, last: days.count)
        case .rhr: return rhrByDay.isEmpty ? series(\.rhr, last: days.count) : fromDict(rhrByDay)
        case .resp: return series(\.resp, last: days.count)
        case .spo2: return series(\.spo2, last: days.count, scale: 100)
        case .temp: return series(\.temp, last: days.count)
        case .vo2: return vo2
        case .steps: return stepsByDay.isEmpty ? series(\.steps, last: days.count) : fromDict(stepsByDay)
        case .exercise: return exerciseByDay.isEmpty ? series(\.exerciseMin, last: days.count) : fromDict(exerciseByDay)
        case .weight: return weights
        }
    }

    /// Wert an einem bestimmten Tag
    func value(_ k: MetricKind, on day: Date) -> Double? {
        let cal = Calendar.current
        return points(k).last { cal.isDate($0.date, inSameDayAs: day) }?.value
    }

    /// Schnitt und Streuung der 30 Tage vor einem Tag
    func baseline(_ k: MetricKind, before day: Date) -> (mean: Double, sd: Double)? {
        let from = Calendar.current.addDays(-30, to: day)
        let v = points(k).filter { $0.date >= from && $0.date < Calendar.current.startOfDay(for: day) }.map(\.value)
        guard v.count >= 4 else { return nil }
        let m = v.reduce(0, +) / Double(v.count)
        let sd = sqrt(v.map { ($0 - m) * ($0 - m) }.reduce(0, +) / Double(v.count - 1))
        return (m, max(sd, 0.0001))
    }
}
