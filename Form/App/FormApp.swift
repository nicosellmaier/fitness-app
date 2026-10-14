import SwiftUI

@main
struct FormApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var phase

    var body: some View {
        Group {
            if model.needsAccess {
                OnboardingView()
            } else {
                TabView {
                    TodayView().tabItem { Label("Heute", systemImage: "house.fill") }
                    TrainingView().tabItem { Label("Training", systemImage: "figure.run") }
                    NutritionPlaceholderView().tabItem { Label("Ernährung", systemImage: "fork.knife") }
                    HealthView().tabItem { Label("Gesundheit", systemImage: "heart.fill") }
                    FinanceView().tabItem { Label("Finanzen", systemImage: "creditcard.fill") }
                }
            }
        }
        .task { await model.load() }
        .onChange(of: phase) { _, newPhase in
            if newPhase == .active, model.loaded { Task { await model.load() } }
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

struct NutritionPlaceholderView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    Hint(icon: "hammer.fill", title: "Kommt in Etappe 4",
                         text: "Barcode-Scan, Makros und Abgleich mit deinem Verbrauch von der Watch.",
                         color: Theme.accent)
                }
                .padding(16)
            }
            .screenBackground()
            .navigationTitle("Ernährung")
        }
    }
}
