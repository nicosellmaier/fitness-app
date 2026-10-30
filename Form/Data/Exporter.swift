import Foundation
import UIKit

/// CSV, JSON und PDF aus den App-Daten
enum Exporter {
    private static var dir: URL {
        let d = FileManager.default.temporaryDirectory.appendingPathComponent("export", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    private static func write(_ text: String, _ name: String) -> URL? {
        let u = dir.appendingPathComponent(name)
        return (try? text.data(using: .utf8)?.write(to: u, options: .atomic)) != nil ? u : nil
    }

    private static let iso: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"; return f
    }()
    private static let isoTime: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd HH:mm"; return f
    }()

    private static func n(_ v: Double?, _ d: Int = 1) -> String {
        guard let v else { return "" }
        return String(format: "%.\(d)f", v).replacingOccurrences(of: ".", with: ",")
    }

    private static func q(_ s: String) -> String { "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }

    // MARK: CSV

    static func daysCSV(model: AppModel) -> URL? {
        var rows = ["Datum;Erholung;HRV ms;RMSSD ms;Ruhepuls;Atemfrequenz;SpO2 %;Temperatur;Schlaf h;Tiefschlaf h;REM h;Schlaf-Score;Belastung;Schritte;Trainingsminuten;Zyklusphase"]
        for (i, d) in model.days.enumerated() {
            let r = model.recovery(at: i)
            rows.append([
                iso.string(from: d.day), r.map { "\($0.score)" } ?? "", n(d.hrv, 0), n(d.rmssd, 0), n(d.rhr, 0), n(d.resp, 1),
                n(d.spo2.map { $0 * 100 }, 0), n(d.temp, 2), n(d.sleep.map { $0.asleep / 3600 }, 2), n(d.sleep.map { $0.time(.deep) / 3600 }, 2),
                n(d.sleep.map { $0.time(.rem) / 3600 }, 2), d.sleep.map { "\(model.sleepScore($0))" } ?? "",
                n(model.strain(on: d.day).score, 1), n(d.steps, 0), n(d.exerciseMin, 0), model.cyclePhase(on: d.day)?.label ?? "",
            ].joined(separator: ";"))
        }
        return write(rows.joined(separator: "\n"), "form-tageswerte.csv")
    }

    static func strengthCSV(store: DataStore) -> URL? {
        var rows = ["Datum;Uhrzeit;Einheit;Übung;Satz;Gewicht kg;Wiederholungen;Erledigt;RPE"]
        for s in store.data.sessions.sorted(by: { $0.start < $1.start }) {
            for e in s.exercises {
                for (i, set) in e.sets.enumerated() {
                    rows.append([iso.string(from: s.start), s.start.formatted(date: .omitted, time: .shortened), q(s.name), q(ExerciseDB.name(e.exerciseId)),
                                 "\(i + 1)", n(set.weight, 2), "\(set.reps)", set.done ? "ja" : "nein", s.rpe.map { "\($0)" } ?? ""].joined(separator: ";"))
                }
            }
        }
        return write(rows.joined(separator: "\n"), "form-kraft.csv")
    }

    static func workoutsCSV(model: AppModel) -> URL? {
        var rows = ["Start;Art;Name;Dauer min;Distanz km;Pace min/km;Ø Puls;Max Puls;kcal;Höhenmeter;Drinnen"]
        for w in model.workouts.sorted(by: { $0.start < $1.start }) {
            rows.append([isoTime.string(from: w.start), w.kind.label, q(w.name), n(w.duration / 60, 1), n(w.distance.map { $0 / 1000 }, 2),
                         w.pace.map { Fmt.pace($0) } ?? "", n(w.avgHR, 0), n(w.maxHR, 0), n(w.energy, 0), n(w.elevation, 0), w.indoor ? "ja" : "nein"].joined(separator: ";"))
        }
        return write(rows.joined(separator: "\n"), "form-workouts.csv")
    }

    static func nutritionCSV(store: DataStore) -> URL? {
        var rows = ["Datum;Mahlzeit;Lebensmittel;Gramm;kcal;Eiweiß g;Kohlenhydrate g;Fett g"]
        for e in store.data.entries.sorted(by: { $0.date < $1.date }) {
            rows.append([iso.string(from: e.date), e.meal.label, q(e.food.name), n(e.grams, 0), n(e.kcal, 0), n(e.protein, 1), n(e.carbs, 1), n(e.fat, 1)].joined(separator: ";"))
        }
        return write(rows.joined(separator: "\n"), "form-ernaehrung.csv")
    }

    static func fullJSON(store: DataStore) -> URL? {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let d = try? enc.encode(store.data) else { return nil }
        let u = dir.appendingPathComponent("form-backup.json")
        return (try? d.write(to: u, options: .atomic)) != nil ? u : nil
    }

    // MARK: PDF

    static func reportPDF(model: AppModel, store: DataStore) -> URL? {
        let page = CGRect(x: 0, y: 0, width: 595, height: 842)   // A4
        let r = UIGraphicsPDFRenderer(bounds: page)
        let u = dir.appendingPathComponent("form-bericht.pdf")
        let cal = Calendar.current
        let from = cal.addDays(-30, to: cal.startOfDay(for: .now))
        let days = model.days.filter { $0.day >= from }
        let p = store.data.profile
        func avg(_ v: [Double]) -> Double? { v.isEmpty ? nil : v.reduce(0, +) / Double(v.count) }

        let data = r.pdfData { ctx in
            ctx.beginPage()
            var y: CGFloat = 40
            func text(_ s: String, _ size: CGFloat, bold: Bool = false, color: UIColor = .black, x: CGFloat = 40, width: CGFloat = 515) {
                let font = bold ? UIFont.boldSystemFont(ofSize: size) : UIFont.systemFont(ofSize: size)
                let para = NSMutableParagraphStyle(); para.lineBreakMode = .byWordWrapping
                let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .paragraphStyle: para]
                let h = (s as NSString).boundingRect(with: CGSize(width: width, height: 1000), options: .usesLineFragmentOrigin, attributes: attrs, context: nil).height
                if y + h > 800 { ctx.beginPage(); y = 40 }
                (s as NSString).draw(in: CGRect(x: x, y: y, width: width, height: h), withAttributes: attrs)
                y += h + 4
            }
            func row(_ cols: [String], bold: Bool = false) {
                let w: CGFloat = 515 / CGFloat(cols.count)
                let font = bold ? UIFont.boldSystemFont(ofSize: 9) : UIFont.systemFont(ofSize: 9)
                if y + 14 > 800 { ctx.beginPage(); y = 40 }
                for (i, c) in cols.enumerated() {
                    (c as NSString).draw(in: CGRect(x: 40 + w * CGFloat(i), y: y, width: w, height: 14), withAttributes: [.font: font])
                }
                y += 14
            }

            text("Form: Gesundheitsbericht", 22, bold: true)
            text("\(p.name.isEmpty ? "" : p.name + ", ")\(p.sex.label), \(Int(model.age)) Jahre, \(Int(p.heightCm)) cm, \(Fmt.num(model.weightKg ?? p.weightKg, 1)) kg. Zeitraum: \(Fmt.shortDay(from)) bis \(Fmt.shortDay(.now)). Erstellt am \(Fmt.day(.now)).", 10, color: .darkGray)
            y += 8
            text("Zusammenfassung (30 Tage)", 14, bold: true)
            let lines: [(String, String)] = [
                ("Erholung Ø", avg(days.indices.compactMap { i in model.recovery(at: model.days.count - days.count + i).map { Double($0.score) } }).map { Fmt.num($0) + " / 100" } ?? "–"),
                ("HRV Ø (nachts)", avg(days.compactMap(\.hrv)).map { Fmt.num($0) + " ms" } ?? "–"),
                ("Ruhepuls Ø", avg(days.compactMap(\.rhr)).map { Fmt.num($0) + " bpm" } ?? "–"),
                ("Atemfrequenz Ø", avg(days.compactMap(\.resp)).map { Fmt.num($0, 1) + " /min" } ?? "–"),
                ("Blutsauerstoff Ø", avg(days.compactMap(\.spo2)).map { Fmt.num($0 * 100) + " %" } ?? "–"),
                ("Schlaf Ø", avg(days.compactMap { $0.sleep?.asleep }).map { Fmt.hm($0) + " h" } ?? "–"),
                ("Schritte Ø", avg(days.compactMap(\.steps)).map { Fmt.num($0) } ?? "–"),
                ("Trainingsminuten pro Woche", avg(days.compactMap(\.exerciseMin)).map { Fmt.num($0 * 7) + " min" } ?? "–"),
                ("VO2max", model.vo2.last.map { Fmt.num($0.value, 1) + " ml/kg/min" } ?? "–"),
                ("Workouts", "\(model.workouts.filter { $0.start >= from }.count)"),
                ("Krafteinheiten", "\(store.data.sessions.filter { $0.start >= from }.count)"),
            ]
            for (k, v) in lines { row([k, v]) }
            y += 8
            let inj = store.data.injuries.filter { $0.active || $0.since >= from }
            if !inj.isEmpty {
                text("Verletzungen", 14, bold: true)
                for i in inj { text("• \(i.title), seit \(Fmt.shortDay(i.start))\(i.active ? ", aktiv" : "")", 10) }
                y += 8
            }
            text("Tageswerte", 14, bold: true)
            row(["Datum", "Erholung", "HRV", "Ruhepuls", "Atmung", "SpO2", "Schlaf", "Belastung", "Schritte"], bold: true)
            for d in days.reversed() {
                let i = model.days.firstIndex { $0.day == d.day } ?? 0
                row([Fmt.shortDay(d.day), model.recovery(at: i).map { "\($0.score)" } ?? "–", d.hrv.map { Fmt.num($0) } ?? "–", d.rhr.map { Fmt.num($0) } ?? "–",
                     d.resp.map { Fmt.num($0, 1) } ?? "–", d.spo2.map { Fmt.num($0 * 100) + "%" } ?? "–", d.sleep.map { Fmt.hm($0.asleep) } ?? "–",
                     Fmt.num(model.strain(on: d.day).score, 1), d.steps.map { Fmt.num($0) } ?? "–"])
            }
            y += 10
            text("Erholung: HRV und Ruhepuls gegen den persönlichen 30-Tage-Schnitt plus Schlafdauer gegen Bedarf. Belastung: Banister-TRIMP aus dem Tagespuls, Skala 0 bis 21. Alle Werte stammen aus Apple Health (Apple Watch). Kein medizinisches Produkt.", 8, color: .darkGray)
        }
        return (try? data.write(to: u, options: .atomic)) != nil ? u : nil
    }
}
