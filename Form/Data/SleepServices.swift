import Foundation
import EventKit
import SwiftUI
import ActivityKit
#if canImport(AlarmKit)
import AlarmKit
#endif

// MARK: Kalender

enum CalendarService {
    static let store = EKEventStore()

    static var authorized: Bool { EKEventStore.authorizationStatus(for: .event) == .fullAccess }

    static func requestAccess() async -> Bool {
        (try? await store.requestFullAccessToEvents()) ?? false
    }

    static func calendars() -> [EKCalendar] {
        guard authorized else { return [] }
        return store.calendars(for: .event).sorted { $0.title < $1.title }
    }

    /// Erster echter Termin am Morgen des Weck-Tages (3 bis 14 Uhr), ohne ganztägige und als "frei" markierte Termine
    static func firstEvent(on wakeDay: Date, calendarIDs: [String]) -> CalendarEvent? {
        guard authorized else { return nil }
        let start = wakeDay.addingTimeInterval(3 * 3600)
        let end = wakeDay.addingTimeInterval(14 * 3600)
        let cals: [EKCalendar]? = calendarIDs.isEmpty ? nil : store.calendars(for: .event).filter { calendarIDs.contains($0.calendarIdentifier) }
        if let c = cals, c.isEmpty { return nil }
        let pred = store.predicateForEvents(withStart: start, end: end, calendars: cals)
        let events = store.events(matching: pred).filter { e in
            if e.isAllDay || e.availability == .free { return false }
            if let me = e.attendees?.first(where: { $0.isCurrentUser }), me.participantStatus == .declined { return false }
            return true
        }
        guard let first = events.min(by: { $0.startDate < $1.startDate }) else { return nil }
        return CalendarEvent(title: first.title?.isEmpty == false ? first.title! : "Termin", start: first.startDate)
    }
}

extension SleepPlanner {
    /// Der Tag, an dem du als Nächstes aufwachst
    static func nextWakeDay(_ now: Date = .now) -> Date {
        let ref = cal.component(.hour, from: now) < 5 ? cal.addDays(-1, to: cal.startOfDay(for: now)) : cal.startOfDay(for: now)
        return cal.addDays(1, to: ref)
    }
}

// MARK: Wecker

#if canImport(AlarmKit)
@available(iOS 26.0, *)
struct WakeAlarmData: AlarmMetadata {}
#endif

enum WakeAlarm {
    enum Result { case alarm, notification, failed }

    static var scheduledFor: Date? {
        let t = UserDefaults.standard.double(forKey: "wakeAlarmDate")
        guard t > 0 else { return nil }
        let d = Date(timeIntervalSince1970: t)
        return d > .now ? d : nil
    }

    static var usesRealAlarm: Bool {
        if #available(iOS 26.0, *) { return true }
        return false
    }

    /// Echter Wecker über AlarmKit (klingelt auch im Lautlos-Modus), sonst eine Mitteilung als Ersatz
    @MainActor
    static func set(_ date: Date) async -> Result {
        await cancel()
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            let manager = AlarmManager.shared
            if manager.authorizationState == .notDetermined {
                _ = try? await manager.requestAuthorization()
            }
            if manager.authorizationState == .authorized {
                let stop = AlarmButton(text: "Aus", textColor: .white, systemImageName: "sun.max.fill")
                let alert = AlarmPresentation.Alert(title: "Guten Morgen", stopButton: stop)
                let attributes = AlarmAttributes<WakeAlarmData>(presentation: AlarmPresentation(alert: alert),
                                                                metadata: WakeAlarmData(), tintColor: Theme.accent)
                let config = AlarmManager.AlarmConfiguration<WakeAlarmData>(
                    countdownDuration: nil, schedule: .fixed(date), attributes: attributes,
                    stopIntent: nil, secondaryIntent: nil, sound: .default)
                let id = UUID()
                do {
                    _ = try await manager.schedule(id: id, configuration: config)
                    UserDefaults.standard.set(id.uuidString, forKey: "wakeAlarmID")
                    UserDefaults.standard.set(date.timeIntervalSince1970, forKey: "wakeAlarmDate")
                    return .alarm
                } catch {
                    // weiter mit der Mitteilung
                }
            }
        }
        #endif
        await Notifications.requestPermission()
        Notifications.schedule(id: "wake", title: "Guten Morgen", body: "Zeit aufzustehen. Ab nach draußen ins Tageslicht.", at: date)
        UserDefaults.standard.set(date.timeIntervalSince1970, forKey: "wakeAlarmDate")
        return date > .now ? .notification : .failed
    }

    @MainActor
    static func cancel() async {
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *), let s = UserDefaults.standard.string(forKey: "wakeAlarmID"), let id = UUID(uuidString: s) {
            try? await AlarmManager.shared.cancel(id: id)
        }
        #endif
        Notifications.cancel("wake")
        UserDefaults.standard.removeObject(forKey: "wakeAlarmID")
        UserDefaults.standard.removeObject(forKey: "wakeAlarmDate")
    }
}

// MARK: Erinnerungen aus dem Tagesplan

enum PlanReminders {
    static func update(plan: SleepPlan?, prefs: SleepPrefs, bedtimeReminder: Bool, need: TimeInterval) {
        for id in ["plan.caffeine", "plan.winddown", "plan.light"] { Notifications.cancel(id) }
        Notifications.updateBedtime(enabled: bedtimeReminder, bedtime: plan?.bedtime, need: need)
        guard let p = plan else { return }
        if prefs.remindCaffeine, p.caffeineCutoff > .now {
            Notifications.schedule(id: "plan.caffeine", title: "Letzter Kaffee",
                                   body: "Ab jetzt kein Koffein mehr, sonst schläfst du um \(Fmt.time(p.bedtime)) schlechter ein.", at: p.caffeineCutoff)
        }
        if prefs.remindWindDown, p.windDown > .now {
            Notifications.schedule(id: "plan.winddown", title: "Runterfahren",
                                   body: "In einer Stunde ins Bett. Licht dimmen, Bildschirm weg.", at: p.windDown)
        }
        if prefs.remindMorningLight {
            let t = p.wake.addingTimeInterval(15 * 60)
            Notifications.schedule(id: "plan.light", title: "Tageslicht",
                                   body: "10 bis 30 Minuten raus. Das stellt deine innere Uhr für heute Abend.", at: t)
        }
    }
}
