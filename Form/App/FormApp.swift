import SwiftUI

@main
struct FormApp: App {
    @State private var model = AppModel()
    @State private var store = DataStore()
    @State private var timer = RestTimer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .environment(store)
                .environment(timer)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
        }
    }
}

private struct SwitchTabKey: EnvironmentKey {
    static let defaultValue: (Int) -> Void = { _ in }
}

extension EnvironmentValues {
    /// Wechselt den Tab der Haupt-Navigation
    var switchTab: (Int) -> Void {
        get { self[SwitchTabKey.self] }
        set { self[SwitchTabKey.self] = newValue }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(DataStore.self) private var store
    @Environment(RestTimer.self) private var timer
    @Environment(\.scenePhase) private var phase
    @State private var tab = UserDefaults.standard.integer(forKey: "startTab")
    private let shot = UserDefaults.standard.string(forKey: "shot") ?? ""

    /// Neue Nutzer (z. B. ein zweites iPhone) füllen beim ersten Start ihr Profil aus
    private var needsProfile: Binding<Bool> {
        Binding(get: { model.loaded && !model.usingDemo && shot.isEmpty && !store.data.profileDone },
                set: { _ in })
    }

    var body: some View {
        Group {
            if model.needsAccess {
                OnboardingView()
            } else if shot == "sleep" {
                NavigationStack { SleepView() }
            } else if shot == "workout", let w = model.workouts.first(where: { $0.distance != nil }) {
                NavigationStack { WorkoutDetailView(item: w) }
            } else if shot == "injury" {
                NavigationStack { InjuryView() }
            } else if shot == "run", let r = store.data.plan?.runs.first(where: { $0.type == .intervals && $0.status == .planned }) {
                NavigationStack { RunDetailView(runId: r.id) }
            } else if shot == "session" || shot == "rest", store.activeSession != nil {
                NavigationStack { SessionView() }
                    .task {
                        guard shot == "rest", !timer.running else { return }
                        timer.start(seconds: 105, exercise: "Bankdrücken", nextSet: "Satz 3/3", target: "77,5 kg × 10", session: "Oberkörper")
                    }
            } else if shot == "healthspan" {
                NavigationStack { HealthspanView() }
            } else if shot == "stress" {
                NavigationStack { StressView() }
            } else if shot == "journal" {
                NavigationStack { JournalView(day: Calendar.current.addDays(-1, to: Calendar.current.startOfDay(for: .now))) }
            } else if shot == "coach" {
                CoachView()
            } else if shot == "sleepplan" {
                NavigationStack { SleepPlanView() }
            } else if shot == "strain" {
                NavigationStack { StrainDetailView() }
            } else if shot == "widgets" || shot == "widgets2" {
                NavigationStack { WidgetGallery(page: shot == "widgets" ? 0 : 1) }
            } else {
                TabView(selection: $tab) {
                    TodayView().tabItem { Label("Heute", systemImage: "house.fill") }.tag(0)
                    TrainingView().tabItem { Label("Training", systemImage: "figure.run") }.tag(1)
                    NutritionView().tabItem { Label("Ernährung", systemImage: "fork.knife") }.tag(2)
                    HealthView().tabItem { Label("Gesundheit", systemImage: "heart.fill") }.tag(3)
                    if store.data.profile.showFinance {
                        FinanceView().tabItem { Label("Finanzen", systemImage: "creditcard.fill") }.tag(4)
                    }
                }
                .sensoryFeedback(.selection, trigger: tab)
                .environment(\.switchTab, { tab = $0 })
                .sheet(isPresented: needsProfile) { ProfileSetupView() }
            }
        }
        .task { await refresh() }
        .onChange(of: phase) { _, newPhase in
            if newPhase == .active, model.loaded { Task { await refresh() } }
        }
        .onChange(of: store.data.injuries) { _, _ in afterChange() }
        .onChange(of: store.data.illness) { _, _ in afterChange() }
        .onChange(of: store.data.sessions.count) { _, _ in syncModel() }
        .onChange(of: store.data.profile.birthYear) { _, _ in syncModel() }
        .onChange(of: store.data.profile.sex) { _, _ in syncModel() }
        .onChange(of: store.data.sleepPrefs) { _, _ in afterChange() }
        .onChange(of: store.data.profile.bedtimeReminder) { _, _ in afterChange() }
    }

    /// Health-Daten laden, Plan live anpassen, Widgets und Erinnerungen aktualisieren
    @MainActor
    private func syncModel() {
        model.sessions = store.data.sessions
        model.sleepPrefs = store.data.sleepPrefs
        let wakeDay = SleepPlanner.nextWakeDay()
        if let r = store.data.plan?.run(on: wakeDay), r.status == .planned, r.type.isQuality || r.type == .long {
            model.hardTomorrow = r.title
        } else {
            model.hardTomorrow = nil
        }
        if !model.usingDemo {
            model.tomorrowEvent = store.data.sleepPrefs.useCalendar
                ? CalendarService.firstEvent(on: wakeDay, calendarIDs: store.data.sleepPrefs.calendarIDs) : nil
        }
        model.female = store.data.profile.sex == .female
        model.birthYear = store.data.profile.birthYear
    }

    @MainActor
    private func refresh() async {
        syncModel()
        await model.load()
        guard model.loaded, !model.needsAccess else { return }
        if UserDefaults.standard.bool(forKey: "seedDemo") { DemoSeed.seed(store: store, model: model, shot: shot) }
        afterChange()
    }

    @MainActor
    private func afterChange() {
        syncModel()
        if var plan = store.data.plan {
            let before = plan.log.count
            let snapshot = try? JSONEncoder().encode(plan.runs)
            PlanAdapter.adapt(&plan, workouts: model.workouts, recovery: model.recoveryToday, restrictions: store.restrictions,
                              hrvLow: model.hrvTrend?.state == .below)
            if plan.log.count != before || (try? JSONEncoder().encode(plan.runs)) != snapshot || plan.vdot != store.data.plan?.vdot {
                let p = plan
                store.update { $0.plan = p }
            }
        }
        WidgetBridge.update(model: model, store: store)
        let plan = model.sleepPlan
        PlanReminders.update(plan: plan, prefs: store.data.sleepPrefs, bedtimeReminder: store.data.profile.bedtimeReminder,
                             need: model.needTonight.total)
        // Wecker automatisch auf den Plan stellen
        if store.data.sleepPrefs.autoAlarm, let p = plan, p.wake > .now, !model.usingDemo {
            if WakeAlarm.scheduledFor.map({ abs($0.timeIntervalSince(p.wake)) >= 60 }) ?? true {
                Task { @MainActor in _ = await WakeAlarm.set(p.wake) }
            }
        }
    }
}

struct OnboardingView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer()
            ZStack {
                Ring(progress: 0.82, color: Theme.accent, lineWidth: 16).frame(width: 110, height: 110)
                Image(systemName: "waveform.path.ecg").font(.system(size: 38, weight: .bold)).foregroundStyle(Theme.text)
            }
            Text("Form").font(.system(size: 40, weight: .heavy))
            Text("Erholung, Schlaf und Training aus deiner Apple Watch, ausgewertet an einem Ort.")
                .font(.title3).foregroundStyle(Theme.soft)
            VStack(alignment: .leading, spacing: 10) {
                Label("Schlafphasen, HRV, Ruhepuls", systemImage: "moon.zzz.fill")
                Label("Workouts mit Route und Splits", systemImage: "map.fill")
                Label("Alles bleibt auf deinem iPhone", systemImage: "lock.fill")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.text)
            .padding(.top, 6)
            Spacer()
            Button {
                Task { await model.requestAccess() }
            } label: {
                Text("Zugriff auf Apple Health erlauben")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Theme.accent, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .foregroundStyle(Theme.bg)
            }
            if let e = model.errorText { Text(e).font(.footnote).foregroundStyle(Theme.bad) }
        }
        .padding(24)
        .background(Theme.bg.ignoresSafeArea())
    }
}
