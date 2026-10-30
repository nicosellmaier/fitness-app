import SwiftUI

struct ProgramLibraryView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Fertige Programme zum Übernehmen. Gewichte und Wiederholungen schlägt die App danach Einheit für Einheit vor.")
                    .font(.subheadline).foregroundStyle(Theme.soft).padding(.horizontal, 4)
                ForEach(Presets.programs) { p in
                    NavigationLink { ProgramDetailView(program: p) } label: { ProgramCard(program: p) }
                        .buttonStyle(.press)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
        }
        .screenBackground()
        .navigationTitle("Programme")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ProgramCard: View {
    let program: ProgramPreset

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: program.icon).font(.title3.weight(.bold)).foregroundStyle(Theme.bg)
                    .frame(width: 48, height: 48)
                    .background(LinearGradient(colors: [Theme.warn, Theme.bad.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing),
                                in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(program.name).font(.headline)
                    Text(program.level).font(.caption.weight(.semibold)).foregroundStyle(Theme.warn)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").foregroundStyle(Theme.muted)
            }
            Text(program.summary).font(.footnote).foregroundStyle(Theme.soft).multilineTextAlignment(.leading)
            HStack(spacing: 6) {
                chip("calendar", program.days)
                chip("clock", "\(program.minutes) min")
                chip("mappin.and.ellipse", program.place)
            }
        }
        .padding(16)
        .background(CardBackground(radius: 22))
    }

    private func chip(_ icon: String, _ t: String) -> some View {
        Label(t, systemImage: icon).font(.caption2.weight(.bold)).lineLimit(1)
            .padding(.horizontal, 8).padding(.vertical, 5)
            .background(Theme.card2, in: Capsule())
            .foregroundStyle(Theme.soft)
    }
}

struct ProgramDetailView: View {
    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let program: ProgramPreset
    @State private var confirm = false
    @State private var added = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ProgramCard(program: program)
                ForEach(program.routines) { r in
                    Card {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(r.name).font(.headline)
                            ForEach(r.items) { it in
                                HStack {
                                    Text(ExerciseDB.name(it.exerciseId)).font(.subheadline)
                                    Spacer()
                                    Text("\(it.sets) × \(it.repMin)–\(it.repMax)").font(.subheadline.weight(.bold)).monospacedDigit()
                                        .foregroundStyle(Theme.soft)
                                }
                            }
                        }
                    }
                }
                Text("Zahlen sind Sätze × Wiederholungen. Bei Halte-Übungen wie Unterarmstütz sind es Sekunden. Sobald du alle Sätze am oberen Ende schaffst, schlägt die App mehr Gewicht vor.")
                    .font(.caption).foregroundStyle(Theme.muted).padding(.horizontal, 4)
                Button { confirm = true } label: {
                    Label(added ? "Übernommen" : "Programm übernehmen", systemImage: added ? "checkmark.circle.fill" : "plus.circle.fill")
                        .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 15)
                        .background(Theme.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .foregroundStyle(Theme.bg)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.press)
                .disabled(added)
                .sensoryFeedback(.success, trigger: added)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
        }
        .screenBackground()
        .navigationTitle(program.name)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Programm übernehmen", isPresented: $confirm, titleVisibility: .visible) {
            Button("Zu meinen Routinen hinzufügen") { apply(replace: false) }
            if !store.data.routines.isEmpty {
                Button("Meine Routinen ersetzen", role: .destructive) { apply(replace: true) }
            }
        } message: {
            Text("Dein Verlauf und deine Bestwerte bleiben in beiden Fällen erhalten.")
        }
    }

    private func apply(replace: Bool) {
        // Neue IDs, damit ein Programm mehrfach übernommen werden kann
        let fresh = program.routines.map { r in
            Routine(name: r.name, items: r.items.map { RoutineItem(exerciseId: $0.exerciseId, sets: $0.sets, repMin: $0.repMin, repMax: $0.repMax) })
        }
        store.update { d in
            if replace { d.routines = fresh } else { d.routines += fresh }
        }
        withAnimation(.snappy) { added = true }
    }
}

// MARK: Profil beim ersten Start

struct ProfileSetupView: View {
    @Environment(DataStore.self) private var store
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var p = Profile()
    @State private var page = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TabView(selection: $page) {
                    about.tag(0)
                    goals.tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.snappy, value: page)
                HStack(spacing: 6) {
                    ForEach(0..<2, id: \.self) { i in
                        Capsule().fill(i == page ? Theme.accent : Theme.track).frame(width: i == page ? 22 : 8, height: 8)
                    }
                }
                .animation(.snappy, value: page)
                .padding(.vertical, 12)
                Button {
                    if page == 0 { page = 1 } else { save() }
                } label: {
                    Text(page == 0 ? "Weiter" : "Los geht's").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(Theme.accent, in: RoundedRectangle(cornerRadius: 18, style: .continuous)).foregroundStyle(Theme.bg)
                }
                .buttonStyle(.press)
                .sensoryFeedback(.impact(weight: .medium), trigger: page)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("Willkommen")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { p = store.data.profile }
        }
        .interactiveDismissDisabled()
    }

    private var about: some View {
        SwiftUI.Form {
            Section {
                TextField("Vorname", text: $p.name)
                Picker("Geschlecht", selection: $p.sex) {
                    ForEach(Sex.allCases) { Text($0.label).tag($0) }
                }
                Stepper("Geburtsjahr: \(String(p.birthYear))", value: $p.birthYear, in: 1940...2015)
                Stepper("Größe: \(Int(p.heightCm)) cm", value: $p.heightCm, in: 140...215)
                Stepper("Gewicht: \(Fmt.num(p.weightKg, 1)) kg", value: $p.weightKg, in: 40...160, step: 0.5)
            } header: {
                Text("Über dich")
            } footer: {
                Text("Für Kalorienziel, Belastung und Form-Alter. Alles bleibt auf diesem iPhone.")
            }
        }
        .scrollContentBackground(.hidden)
    }

    private var goals: some View {
        SwiftUI.Form {
            Section("Ernährung") {
                Picker("Ziel", selection: $p.goal) {
                    ForEach(NutritionGoal.allCases) { Text($0.label).tag($0) }
                }
            }
            Section {
                Toggle("Finanzen-Tab anzeigen", isOn: $p.showFinance)
            } footer: {
                Text("Nur sinnvoll, wenn du eine eigene Finanz-App verbunden hast. Lässt sich jederzeit in den Einstellungen ändern.")
            }
            Section {
                Label("Programme für Kraft findest du unter Training → Kraft, Laufpläne unter Training → Plan.", systemImage: "figure.strengthtraining.traditional")
                    .font(.footnote)
            }
        }
        .scrollContentBackground(.hidden)
    }

    private func save() {
        var prof = p
        prof.name = prof.name.trimmingCharacters(in: .whitespaces)
        store.update { d in
            d.profile = prof
            d.profileDone = true
        }
        dismiss()
    }
}
