import Foundation
import HealthKit
import Observation

@Observable
final class AppModel {
    var days: [DayMetrics] = []
    /// Zyklus: Blutungstage aus Health, daraus Phase und Korrektur
    var cycleRecords: [CycleRecord] = []
    var cycleCorrection: CycleCorrection?
    var nights: [SleepNight] = []
    var workouts: [WorkoutItem] = []
    var vo2: [Point] = []
    var activeKcalToday: Double = 0
    var weightKg: Double?
    /// Gewichtsverlauf (365 Tage, ein Wert pro Tag)
    var weights: [Point] = []
    var leanMassKg: Double?
    var heightM: Double?
    /// Pulswerte der letzten 14 Tage (Belastung über den Tag, Stress)
    var hr: [HRPoint] = []
    var stepSamples: [StepSample] = []
    var stepsByDay: [Date: Double] = [:]
    var exerciseByDay: [Date: Double] = [:]
    var rhrByDay: [Date: Double] = [:]
    /// Werden von der App aus den gespeicherten Daten gesetzt
    var sessions: [StrengthSession] = []
    var female = false
    var birthYear = 2003
    var sleepPrefs = SleepPrefs()
    /// Erster Termin am nächsten Morgen aus dem Kalender
    var tomorrowEvent: CalendarEvent?
    /// Harte oder lange Einheit morgen laut Trainingsplan
    var hardTomorrow: String?
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

    var cycle: CycleState? { female ? CycleModel.state(records: cycleRecords) : nil }

    /// Tageswerte für Erholung und Monitor: in Lutealphasen um den Zykluseffekt bereinigt
    var analysisDays: [DayMetrics] {
        guard female, let c = cycleCorrection, !cycleRecords.isEmpty else { return days }
        return CycleModel.adjust(days, records: cycleRecords, defaultLength: cycle?.length ?? 28, correction: c)
    }

    func cyclePhase(on day: Date) -> CyclePhase? {
        guard female, !cycleRecords.isEmpty else { return nil }
        return CycleModel.phase(on: day, records: cycleRecords, defaultLength: cycle?.length ?? 28)
    }

    /// Plan in den letzten Tagen vor der Periode entschärfen
    var cycleEaseReason: String? {
        guard let c = cycle, c.phase == .lateLuteal || (c.phase == .menstrual && c.day <= 2) else { return nil }
        return c.phase == .menstrual ? "Zyklus: erste Periodentage" : "Zyklus: späte Lutealphase"
    }
    var lastNight: SleepNight? { nights.last.flatMap { Calendar.current.isDateInToday($0.wakeDay) ? $0 : nil } ?? nights.last }

    var restingHR: Double { days.reversed().compactMap(\.rhr).first ?? 55 }

    var age: Double { Double(max(14, Calendar.current.component(.year, from: .now) - birthYear)) }

    func strain(on day: Date) -> StrainBreakdown {
        Strain.day(day, hr: hr, workouts: workouts, sessions: sessions, rhr: restingHR, maxHR: maxHR, female: female)
    }

    var strainBreakdownToday: StrainBreakdown { strain(on: .now) }
    var strainToday: Double { strainBreakdownToday.score }

    var needForLastNight: TimeInterval {
        let prevNights = nights.dropLast()
        let yesterday = Calendar.current.addDays(-1, to: .now)
        return Analytics.sleepNeed(nights: Array(prevNights), base: sleepBaseHours * 3600, strainToday: strain(on: yesterday).score).total
    }

    var needTonight: SleepNeed {
        Analytics.sleepNeed(nights: nights, base: sleepBaseHours * 3600, strainToday: strainToday)
    }

    var recoveryToday: Recovery? {
        let d = analysisDays
        return Analytics.recovery(days: d, index: d.count - 1, need: needForLastNight)
    }

    func recovery(at i: Int) -> Recovery? {
        Analytics.recovery(days: analysisDays, index: i, need: sleepBaseHours * 3600)
    }

    /// Erholung pro Tag, für Journal-Auswertungen
    var recoveryByDay: [Date: Int] {
        var out: [Date: Int] = [:]
        for i in days.indices { if let r = recovery(at: i) { out[days[i].day] = r.score } }
        return out
    }

    var hrvTrend: HRVTrend? { HRVTrend.make(analysisDays) }

    // MARK: Schlafplan

    var sleepDebt: SleepDebt { SleepPlanner.debt(nights, need: sleepBaseHours * 3600) }

    var sleepPlan: SleepPlan? {
        SleepPlanner.plan(nights: nights, need: needTonight.total, prefs: sleepPrefs, event: tomorrowEvent,
                          hardTomorrow: hardTomorrow, debtHours: sleepDebt.hours)
    }

    var chronotype: Chronotype? { SleepPlanner.chronotype(nights) }

    /// Aufwachzeit heute: aus der letzten Nacht, sonst gewohnt
    var todayWake: Date? {
        let cal = Calendar.current
        if let n = nights.last, cal.isDateInToday(n.wakeDay) { return n.end }
        guard let hw = SleepPlanner.habitualWake(nights, free: SleepPlanner.isFreeDay(.now)) else { return nil }
        return SleepPlanner.date(noonMinutes: hw, nightEnding: cal.startOfDay(for: .now))
    }

    var energyToday: [EnergyPoint] {
        guard let wake = todayWake, let plan = sleepPlan, let onset = SleepPlanner.habitualOnset(nights),
              let hw = SleepPlanner.habitualWake(nights, free: false) else { return [] }
        return SleepPlanner.energy(wake: wake, bed: plan.bedtime, habitualOnset: onset, habitualWake: hw, debtHours: sleepDebt.hours)
    }

    var planSteps: [PlanStep] {
        guard let wake = todayWake, let plan = sleepPlan else { return [] }
        return SleepPlanner.steps(plan: plan, todayWake: wake, todayBed: plan.bedtime, energy: energyToday)
    }

    var stressToday: StressDay? { Stress.compute(hr: hr, steps: stepSamples, workouts: workouts, nights: nights) }

    var vitals: [VitalStatus] { HealthMonitor.vitals(analysisDays) }

    var healthspan: Healthspan? {
        HealthspanModel.compute(HealthspanInputs(
            nights: nights, steps: stepsByDay, exercise: exerciseByDay, workouts: workouts, sessions: sessions,
            vo2: vo2, rhr: rhrByDay, leanMass: leanMassKg, heightM: heightM, age: age, female: female, maxHR: maxHR))
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
            let today = cal.dayStart(.now)
            let from = cal.addDays(-95, to: today)
            let long = cal.addDays(-185, to: today)
            async let sleepS = health.sleep(from: long)
            async let hrvS = health.quantity(.heartRateVariabilitySDNN, from: from)
            async let rhrS = health.quantity(.restingHeartRate, from: long)
            async let respS = health.quantity(.respiratoryRate, from: from)
            async let spoS = health.quantity(.oxygenSaturation, from: from)
            async let tempS = health.quantity(.appleSleepingWristTemperature, from: from)
            async let vo2S = health.quantity(.vo2Max, from: cal.addDays(-365, to: .now))
            async let wS = health.workouts(from: long, limit: 600)

            let (sl, hv, rh, rs, sp, tp, vo, ws) = try await (sleepS, hrvS, rhrS, respS, spoS, tempS, vo2S, wS)
            let builtNights = Analytics.nights(from: sl)
            if builtNights.isEmpty && hv.isEmpty && ws.isEmpty {
                applyDemo()
                return
            }
            async let stepsD = health.dailySums(.stepCount, unit: .count(), from: long)
            async let exD = health.dailySums(.appleExerciseTime, unit: .minute(), from: long)
            async let hrS = health.heartRate(from: cal.addDays(-14, to: today))
            async let stepS = health.stepSamples(from: cal.addDays(-14, to: today))
            let windows = builtNights.suffix(45).map { (start: $0.start.addingTimeInterval(-1800), end: $0.end.addingTimeInterval(600)) }
            async let rmS = health.rmssd(windows: windows)
            let steps = (try? await stepsD) ?? [:]
            let exercise = (try? await exD) ?? [:]
            let rm = (try? await rmS) ?? []
            hr = (try? await hrS) ?? []
            stepSamples = (try? await stepS) ?? []
            stepsByDay = steps
            exerciseByDay = exercise
            var rbd: [Date: Double] = [:]
            for q in rh { rbd[cal.startOfDay(for: q.startDate)] = q.quantity.doubleValue(for: HealthService.bpm) }
            rhrByDay = rbd

            usingDemo = false
            nights = builtNights
            days = Analytics.days(count: 90, nights: builtNights, hrv: hv, rhr: rh, resp: rs, spo2: sp, temp: tp,
                                  rmssd: rm, steps: steps, exercise: exercise)
            let unit = HKUnit(from: "ml/kg*min")
            vo2 = vo.map { Point(date: $0.startDate, value: $0.quantity.doubleValue(for: unit)) }
            workouts = ws.map { health.item(from: $0) }
            activeKcalToday = (try? await health.sum(.activeEnergyBurned, unit: .kilocalorie(), from: cal.dayStart(.now))) ?? 0
            weightKg = try? await health.latest(.bodyMass, unit: .gramUnit(with: .kilo))
            if let flow = try? await health.menstrualFlow(from: cal.addDays(-400, to: today)) {
                cycleRecords = CycleModel.records(from: flow)
                cycleCorrection = CycleModel.correction(days: days, records: cycleRecords, defaultLength: CycleModel.state(records: cycleRecords)?.length ?? 28)
            }
            if let ws = try? await health.quantity(.bodyMass, from: cal.addDays(-365, to: today)) {
                var byDay: [Date: Double] = [:]
                for q in ws.sorted(by: { $0.startDate < $1.startDate }) {
                    byDay[cal.startOfDay(for: q.startDate)] = q.quantity.doubleValue(for: .gramUnit(with: .kilo))
                }
                weights = byDay.sorted { $0.key < $1.key }.map { Point(date: $0.key, value: $0.value) }
            }
            leanMassKg = try? await health.latest(.leanBodyMass, unit: .gramUnit(with: .kilo), days: 365)
            heightM = try? await health.latest(.height, unit: .meter(), days: 3650)
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func applyDemo() {
        usingDemo = true
        needsAccess = false
        nights = DemoData.nights(count: 180)
        let steps = DemoData.steps()
        let exercise = DemoData.exercise()
        days = DemoData.days(nights: nights, steps: steps, exercise: exercise)
        vo2 = DemoData.vo2()
        workouts = DemoData.workouts()
        hr = DemoData.dayHR(workouts: workouts, nights: nights)
        stepSamples = DemoData.stepSamples()
        stepsByDay = steps
        exerciseByDay = exercise
        var rbd: [Date: Double] = [:]
        for d in days { if let r = d.rhr { rbd[d.day] = r } }
        rhrByDay = rbd
        activeKcalToday = 420
        weightKg = nil
        // Beispiel: langsam fallendes Gewicht mit Tagesschwankung, jeden zweiten Tag gewogen
        let cal = Calendar.current
        weights = stride(from: 120, through: 0, by: -2).map { ago in
            let d = cal.addDays(-ago, to: cal.startOfDay(for: .now))
            let wobble = sin(Double(ago) * 1.7) * 0.45 + cos(Double(ago) * 0.6) * 0.25
            return Point(date: d, value: 77.4 - Double(120 - ago) * 0.018 + wobble)
        }
        let tomorrow = Calendar.current.addDays(1, to: Calendar.current.startOfDay(for: .now))
        if !SleepPlanner.isFreeDay(tomorrow) {
            tomorrowEvent = CalendarEvent(title: "Vorlesung", start: tomorrow.addingTimeInterval(8 * 3600 + 15 * 60))
        }
        leanMassKg = 63.5
        heightM = 1.81
        // Beispiel-Zyklus: 29 Tage, letzte Periode vor 19 Tagen (Lutealphase)
        var recs: [CycleRecord] = []
        var start = cal.addDays(-18, to: cal.startOfDay(for: .now))
        for i in 0..<6 {
            let len = [29, 28, 30, 29, 27, 29][i]
            recs.insert(CycleRecord(start: start, length: i == 0 ? nil : len, periodDays: 5), at: 0)
            start = cal.addDays(-len, to: start)
        }
        cycleRecords = recs
        cycleCorrection = CycleCorrection(temp: 0.32, rhr: 3.1, hrv: -6.4, samples: 120)
    }
}
