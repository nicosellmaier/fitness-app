import Foundation
import ActivityKit
import UserNotifications
import WidgetKit
import Observation

// MARK: Satzpause mit Live Activity

@Observable
final class RestTimer {
    var endsAt: Date?
    var total: Double = 0
    var exercise = ""
    var nextSet = ""
    var target = ""

    private var activity: Activity<RestTimerAttributes>?
    private var observer: NSObjectProtocol?

    init() {
        observer = NotificationCenter.default.addObserver(forName: .restTimerChanged, object: nil, queue: .main) { [weak self] note in
            guard let self else { return }
            if note.userInfo?["skip"] as? Bool == true {
                self.endsAt = nil
                self.activity = nil
                Notifications.cancel("rest")
            } else if let end = note.userInfo?["endsAt"] as? Date {
                self.total += end.timeIntervalSince(self.endsAt ?? end)
                self.endsAt = end
                Notifications.schedule(id: "rest", title: "Pause vorbei", body: "\(self.exercise): \(self.nextSet)", at: end)
            }
        }
    }

    var running: Bool { (endsAt ?? .distantPast) > .now }

    func start(seconds: Double, exercise: String, nextSet: String, target: String, session: String) {
        let end = Date.now.addingTimeInterval(seconds)
        endsAt = end
        total = seconds
        self.exercise = exercise
        self.nextSet = nextSet
        self.target = target
        Notifications.schedule(id: "rest", title: "Pause vorbei", body: "\(exercise): \(nextSet) · \(target)", at: end)
        let state = RestTimerAttributes.ContentState(endsAt: end, total: seconds, exercise: exercise, nextSet: nextSet, target: target)
        let content = ActivityContent(state: state, staleDate: end.addingTimeInterval(60))
        if let a = activity {
            Task { await a.update(content) }
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        activity = try? Activity.request(attributes: RestTimerAttributes(sessionName: session), content: content, pushType: nil)
    }

    func add(_ seconds: Double) {
        guard let e = endsAt else { return }
        let end = max(Date.now, e).addingTimeInterval(seconds)
        endsAt = end
        total += seconds
        Notifications.schedule(id: "rest", title: "Pause vorbei", body: "\(exercise): \(nextSet)", at: end)
        if let a = activity {
            let state = RestTimerAttributes.ContentState(endsAt: end, total: total, exercise: exercise, nextSet: nextSet, target: target)
            Task { await a.update(ActivityContent(state: state, staleDate: end.addingTimeInterval(60))) }
        }
    }

    func stop() {
        endsAt = nil
        Notifications.cancel("rest")
        endActivity()
    }

    func endActivity() {
        let a = activity
        activity = nil
        Task {
            await a?.end(nil, dismissalPolicy: .immediate)
            for other in Activity<RestTimerAttributes>.activities { await other.end(nil, dismissalPolicy: .immediate) }
        }
    }
}

// MARK: Lokale Benachrichtigungen

enum Notifications {
    static func requestPermission() async {
        // Bei Screenshot-Läufen keine Systemabfrage einblenden
        if UserDefaults.standard.bool(forKey: "seedDemo") { return }
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
    }

    static func schedule(id: String, title: String, body: String, at date: Date) {
        let interval = date.timeIntervalSinceNow
        guard interval > 1 else { return }
        let c = UNMutableNotificationContent()
        c.title = title
        c.body = body
        c.sound = .default
        if id == "rest" { c.interruptionLevel = .timeSensitive }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: c, trigger: trigger))
    }

    static func cancel(_ id: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }

    /// Erinnerung 30 Minuten vor der empfohlenen Schlafenszeit
    static func updateBedtime(enabled: Bool, bedtime: Date?, need: TimeInterval) {
        cancel("bedtime")
        guard enabled, var bed = bedtime else { return }
        while bed.addingTimeInterval(-1800) < .now { bed = Calendar.current.addDays(1, to: bed) }
        schedule(id: "bedtime", title: "Bald ins Bett", body: "Für \(Fmt.hm(need)) h Schlaf solltest du um \(Fmt.time(bed)) im Bett sein.", at: bed.addingTimeInterval(-1800))
    }
}

// MARK: Daten für die Widgets

enum WidgetBridge {
    static func update(model: AppModel, store: DataStore) {
        make(model: model, store: store).save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func make(model: AppModel, store: DataStore) -> WidgetSnapshot {
        var s = WidgetSnapshot()
        s.demo = model.usingDemo
        if let r = model.recoveryToday {
            s.recovery = r.score
            s.recoveryLabel = r.label
        }
        if let n = model.lastNight {
            s.sleepMinutes = Int(n.asleep / 60)
            s.sleepScore = model.sleepScore(n)
        }
        s.hrv = model.today?.hrv.map { Int($0.rounded()) }
        s.strain = model.strainToday
        let need = model.needTonight
        s.needMinutes = Int(need.total / 60)
        s.bedtime = Analytics.bedtime(nights: model.nights, need: need.total)

        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let entries = store.data.entries.filter { cal.isDate($0.date, inSameDayAs: today) }
        let plan = store.data.plan
        let todayRun = plan?.run(on: today)
        let paces = plan?.paces
        let targets = store.nutritionTargets(model: model, day: today)
        s.kcalTarget = Int(targets.kcal)
        s.kcalLeft = Int(targets.kcal - Macros.sum(entries).kcal)

        if let plan, let paces {
            func brief(_ r: PlannedRun) -> WidgetSnapshot.Session {
                let km = paces.totalMeters(r.structure) / 1000
                var detail = km > 0 ? Fmt.num(km, 1) + " km" : ""
                if r.type.isQuality, let z = r.structure.blocks.first?.work.zone { detail += " · " + Fmt.pace(paces.sec(z)) + "/km" }
                return WidgetSnapshot.Session(date: r.date, title: r.title, detail: detail, done: r.status == .done,
                                              quality: r.type.isQuality, rest: r.type == .rest)
            }
            s.today = todayRun.map(brief)
            let ws = PlanGenerator.weekStart(today)
            let we = cal.addDays(7, to: ws)
            let weekRuns = plan.runs.filter { $0.date >= ws && $0.date < we }
            var week = weekRuns.map(brief)
            for wd in plan.settings.strengthDays {
                let d = cal.addDays(PlanGenerator.dayOffset(wd), to: ws)
                let done = store.data.sessions.contains { cal.isDate($0.start, inSameDayAs: d) }
                week.append(WidgetSnapshot.Session(date: d, title: "Krafttraining", detail: "", done: done, quality: false, rest: false))
            }
            s.week = week.sorted { $0.date < $1.date }
            s.weekKmPlanned = weekRuns.reduce(0) { $0 + paces.totalMeters($1.structure) / 1000 }
            s.weekKmDone = weekRuns.filter { $0.status == .done }.reduce(0) { $0 + ($1.actualMeters ?? 0) / 1000 }
            if let ph = plan.phase(on: today) {
                let n = (cal.dateComponents([.day], from: plan.phases.first?.start ?? ws, to: today).day ?? 0) / 7 + 1
                s.phase = "\(ph.name) · Woche \(n)"
            }
        }
        return s
    }
}
