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
    @Environment(\.scenePhase) private var phase
    @State private var tab = UserDefaults.standard.integer(forKey: "startTab")
    private let shot = UserDefaults.standard.string(forKey: "shot") ?? ""

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
            } else if shot == "session", store.activeSession != nil {
                NavigationStack { SessionView() }
            } else {
                TabView(selection: $tab) {
                    TodayView().tabItem { Label("Heute", systemImage: "house.fill") }.tag(0)
                    TrainingView().tabItem { Label("Training", systemImage: "figure.run") }.tag(1)
                    NutritionView().tabItem { Label("Ernährung", systemImage: "fork.knife") }.tag(2)
                    HealthView().tabItem { Label("Gesundheit", systemImage: "heart.fill") }.tag(3)
                    FinanceView().tabItem { Label("Finanzen", systemImage: "creditcard.fill") }.tag(4)
                }
                .environment(\.switchTab, { tab = $0 })
            }
        }
        .task { await refresh() }
        .onChange(of: phase) { _, newPhase in
            if newPhase == .active, model.loaded { Task { await refresh() } }
        }
        .onChange(of: store.data.injuries) { _, _ in afterChange() }
        .onChange(of: store.data.illness) { _, _ in afterChange() }
    }

    /// Health-Daten laden, Plan live anpassen, Widgets und Erinnerungen aktualisieren
    @MainActor
    private func refresh() async {
        await model.load()
        guard model.loaded, !model.needsAccess else { return }
        if UserDefaults.standard.bool(forKey: "seedDemo") { DemoSeed.seed(store: store, model: model, shot: shot) }
        afterChange()
    }

    @MainActor
    private func afterChange() {
        if var plan = store.data.plan {
            let before = plan.log.count
            let snapshot = try? JSONEncoder().encode(plan.runs)
            PlanAdapter.adapt(&plan, workouts: model.workouts, recovery: model.recoveryToday, restrictions: store.restrictions)
            if plan.log.count != before || (try? JSONEncoder().encode(plan.runs)) != snapshot || plan.vdot != store.data.plan?.vdot {
                let p = plan
                store.update { $0.plan = p }
            }
        }
        WidgetBridge.update(model: model, store: store)
        let need = model.needTonight
        Notifications.updateBedtime(enabled: store.data.profile.bedtimeReminder,
                                    bedtime: Analytics.bedtime(nights: model.nights, need: need.total), need: need.total)
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
