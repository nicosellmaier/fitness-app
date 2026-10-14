import SwiftUI

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: alpha)
    }
}

enum Theme {
    static let bg = Color(hex: 0x0B0C0A)
    static let card = Color(hex: 0x151713)
    static let card2 = Color(hex: 0x1D201A)
    static let track = Color(hex: 0x22251F)
    static let line = Color.white.opacity(0.07)
    static let text = Color(hex: 0xF1F3EC)
    static let muted = Color(hex: 0x8B9185)
    static let soft = Color(hex: 0xB9BEB2)
    static let accent = Color(hex: 0xC6F432)
    static let good = Color(hex: 0x62E38C)
    static let warn = Color(hex: 0xFFB25B)
    static let bad = Color(hex: 0xFF7B7B)
    static let sleep = Color(hex: 0x8FB3FF)
    static let core = Color(hex: 0x4F6FB8)
    static let deep = Color(hex: 0x3B56A3)
}

enum Fmt {
    static let de = Locale(identifier: "de_DE")

    static func hm(_ t: TimeInterval) -> String {
        let m = Int((max(0, t) / 60).rounded())
        return "\(m / 60):" + String(format: "%02d", m % 60)
    }

    static func num(_ v: Double, _ digits: Int = 0) -> String {
        v.formatted(.number.precision(.fractionLength(digits)).locale(de))
    }

    static func time(_ d: Date) -> String {
        d.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(de))
    }

    static func day(_ d: Date) -> String {
        d.formatted(Date.FormatStyle().weekday(.wide).day().month(.wide).locale(de))
    }

    static func shortDay(_ d: Date) -> String {
        d.formatted(Date.FormatStyle().weekday(.abbreviated).day().month(.abbreviated).locale(de))
    }

    static func km(_ meters: Double) -> String {
        num(meters / 1000, meters >= 100_000 ? 1 : 2) + " km"
    }

    static func pace(_ secPerKm: Double) -> String {
        guard secPerKm.isFinite, secPerKm > 0 else { return "–" }
        let s = Int(secPerKm.rounded())
        return "\(s / 60):" + String(format: "%02d", s % 60)
    }

    static func clock(_ t: TimeInterval) -> String {
        let s = Int(t.rounded())
        if s >= 3600 { return "\(s / 3600):" + String(format: "%02d:%02d", (s % 3600) / 60, s % 60) }
        return "\(s / 60):" + String(format: "%02d", s % 60)
    }
}

extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}

extension Calendar {
    func dayStart(_ d: Date) -> Date { startOfDay(for: d) }
    func addDays(_ n: Int, to d: Date) -> Date { date(byAdding: .day, value: n, to: d) ?? d }
}
