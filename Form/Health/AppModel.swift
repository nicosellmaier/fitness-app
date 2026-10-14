import Foundation
import HealthKit
import Observation

@Observable
final class AppModel {
    var days: [DayMetrics] = []
    var nights: [SleepNight] = []
    var workouts: [WorkoutItem] = []
    var vo2: [Point] = []
    var loading = false
    var loaded = false
    var usingDemo = false
    var needsAccess = false
    var errorText: String?

    let health = HealthService()

    // Einstellungen
    var maxHR: Double {
        get { let v = UserDefaults.standard.double(forKey: "maxHR"); return v > 0 ? v : 192 }
        set { UserDefaults.standard.set(newValue, forKey: "maxHR") }
    }
    var sleepBaseHours: Double {
        get { let v = UserDefaults.standard.double(forKey: "sleepBase"); return v > 0 ? v : 8 }
        set { UserDefaults.standard.set(newValue, forKey: "sleepBase") }
    }
    var forceDemo: Bool {
        get { UserDefaults.standard.bool(forKey: "demo") }
        set { UserDefaults.standard.set(newValue, forKey: "demo") }
    }
    private var askedAccess: Bool {
        get { UserDefaults.standard.bool(forKey: "hkAsked") }
        set { UserDefaults.standard.set(newValue, forKey: "hkAsked") }
    }

    // MARK: Abgeleitete Werte

    var today: DayMetrics? { days.last }
    var lastNight: SleepNight? { nights.last.flatMap { Calendar.current.isDateInToday($0.wakeDay) ? $0 : nil } ?? nights.last }

    var restingHR: Double { days.reversed().compactMap(\.rhr).first ?? 55 }

    var strainToday: Double { Analytics.strain(workouts, on: .now, rhr: restingHR, maxHR: maxHR) }

    var needForLastNight: TimeInterval {
        let prevNights = nights.dropLast()
        let yesterday = Calendar.current.addDays(-1, to: .now)
        return Analytics.sleepNeed(nights: Array(prevNights), base: sleepBaseHours * 3600,
                                   strainToday: Analytics.strain(workouts, on: yesterday, rhr: restingHR, maxHR: maxHR)).total
    }

    var needTonight: SleepNeed {
        Analytics.sleepNeed(nights: nights, base: sleepBaseHours * 3600, strainToday: strainToday)
    }

    var recoveryToday: Recovery? {
        Analytics.recovery(days: days, index: days.count - 1, need: needForLastNight)
    }

    func recovery(at i: Int) -> Recovery? {
        Analytics.recovery(days: days, index: i, need: sleepBaseHours * 3600)
    }

    func sleepScore(_ n: SleepNight) -> Int {
        let recent = nights.filter { $0.wakeDay < n.wakeDay }.suffix(7)
        return Analytics.sleepScore(n, need: sleepBaseHours * 3600, recent: Array(recent))
    }

    func series(_ key: KeyPath<DayMetrics, Double?>, last n: Int = 30, scale: Double = 1) -> [Point] {
        days.suffix(n).compactMap { d in d[keyPath: key].map { Point(date: d.day, value: $0 * scale) } }
    }

    // MARK: Laden

    @MainActor
    func requestAccess() async {
        do {
            try await health.requestAccess()
            askedAccess = true
            needsAccess = false
            await load()
        } catch {
            errorText = error.localizedDescription
        }
    }

    @MainActor
    func load() async {
        if loading { return }
        loading = true
        defer { loading = false; loaded = true }
        errorText = nil
        if forceDemo || !health.isAvailable {
            applyDemo()
            return
        }
        if !askedAccess {
            needsAccess = true
            return
        }
        do {
            let cal = Calendar.current
            let from = cal.addDays(-45, to: cal.dayStart(.now))
            async let sleepS = health.sleep(from: from)
            async let hrvS = health.quantity(.heartRateVariabilitySDNN, from: from)
            async let rhrS = health.quantity(.restingHeartRate, from: from)
            async let respS = health.quantity(.respiratoryRate, from: from)
            async let spoS = health.quantity(.oxygenSaturation, from: from)
            async let tempS = health.quantity(.appleSleepingWristTemperature, from: from)
            async let vo2S = health.quantity(.vo2Max, from: cal.addDays(-365, to: .now))
            async let wS = health.workouts(from: cal.addDays(-60, to: .now))

            let (sl, hv, rh, rs, sp, tp, vo, ws) = try await (sleepS, hrvS, rhrS, respS, spoS, tempS, vo2S, wS)
            let builtNights = Analytics.nights(from: sl)
            if builtNights.isEmpty && hv.isEmpty && ws.isEmpty {
                applyDemo()
                return
            }
            usingDemo = false
            nights = builtNights
            days = Analytics.days(count: 40, nights: builtNights, hrv: hv, rhr: rh, resp: rs, spo2: sp, temp: tp)
            let unit = HKUnit(from: "ml/kg*min")
            vo2 = vo.map { Point(date: $0.startDate, value: $0.quantity.doubleValue(for: unit)) }
            workouts = ws.map { health.item(from: $0) }
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func applyDemo() {
        usingDemo = true
        needsAccess = false
        nights = DemoData.nights()
        days = DemoData.days(nights: nights)
        vo2 = DemoData.vo2()
        workouts = DemoData.workouts()
    }
}
