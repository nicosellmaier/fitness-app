import Foundation
import ActivityKit
import AppIntents

enum AppGroup {
    static let id = "group.de.nicosellmaier.form"

    static var containerURL: URL {
        if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id) { return url }
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}

/// Was die Widgets anzeigen. Die App schreibt das, die Widgets lesen es.
struct WidgetSnapshot: Codable {
    struct Session: Codable, Hashable, Identifiable {
        var id: String { "\(date.timeIntervalSince1970)-\(title)" }
        var date: Date
        var title: String
        var detail: String
        var done: Bool
        var quality: Bool
        var rest: Bool
    }

    var updated: Date = .now
    var recovery: Int?
    var recoveryLabel: String?
    var sleepMinutes: Int?
    var sleepScore: Int?
    var hrv: Int?
    var strain: Double?
    var bedtime: Date?
    var needMinutes: Int?
    var kcalLeft: Int?
    var kcalTarget: Int?
    var today: Session?
    var week: [Session] = []
    var weekKmDone: Double = 0
    var weekKmPlanned: Double = 0
    var phase: String?
    var demo: Bool = false

    static let fileName = "widget-snapshot.json"

    static func load() -> WidgetSnapshot? {
        let url = AppGroup.containerURL.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .secondsSince1970
        return try? dec.decode(WidgetSnapshot.self, from: data)
    }

    func save() {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .secondsSince1970
        guard let data = try? enc.encode(self) else { return }
        try? data.write(to: AppGroup.containerURL.appendingPathComponent(WidgetSnapshot.fileName), options: .atomic)
    }

    static var preview: WidgetSnapshot {
        var s = WidgetSnapshot()
        s.recovery = 82
        s.recoveryLabel = "Bereit für Intensität"
        s.sleepMinutes = 462
        s.sleepScore = 86
        s.hrv = 68
        s.strain = 4.1
        s.bedtime = Calendar.current.date(bySettingHour: 22, minute: 15, second: 0, of: .now)
        s.needMinutes = 515
        s.kcalLeft = 1310
        s.kcalTarget = 2950
        let today = Calendar.current.startOfDay(for: .now)
        s.today = Session(date: today, title: "Intervalle 6 × 800 m", detail: "9,6 km · 3:55/km", done: false, quality: true, rest: false)
        s.week = (0..<7).map { i in
            let d = Calendar.current.date(byAdding: .day, value: i - 2, to: today) ?? today
            let titles = ["Locker 10 km", "Kraft · Beine", "Intervalle 6 × 800 m", "Locker 8 km", "Kraft · Oberkörper", "Tempo 3 × 3 km", "Lang 24 km"]
            return Session(date: d, title: titles[i], detail: "", done: i < 2, quality: i == 2 || i == 5, rest: false)
        }
        s.weekKmDone = 31
        s.weekKmPlanned = 52
        s.phase = "Aufbau · Woche 8"
        return s
    }
}

// MARK: Satzpause als Live Activity (Dynamic Island)

struct RestTimerAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var endsAt: Date
        var total: Double
        var exercise: String
        var nextSet: String
        var target: String
    }

    var sessionName: String
}

extension Notification.Name {
    static let restTimerChanged = Notification.Name("restTimerChanged")
}

struct AddRestTimeIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "30 Sekunden mehr Pause"

    init() {}

    func perform() async throws -> some IntentResult {
        for activity in Activity<RestTimerAttributes>.activities {
            var state = activity.content.state
            state.endsAt = state.endsAt.addingTimeInterval(30)
            state.total += 30
            await activity.update(ActivityContent(state: state, staleDate: state.endsAt.addingTimeInterval(60)))
            let end = state.endsAt
            await MainActor.run {
                NotificationCenter.default.post(name: .restTimerChanged, object: nil, userInfo: ["endsAt": end])
            }
        }
        return .result()
    }
}

struct SkipRestIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Pause beenden"

    init() {}

    func perform() async throws -> some IntentResult {
        for activity in Activity<RestTimerAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        await MainActor.run {
            NotificationCenter.default.post(name: .restTimerChanged, object: nil, userInfo: ["skip": true])
        }
        return .result()
    }
}
