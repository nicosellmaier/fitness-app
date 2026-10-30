import SwiftUI
import Charts

// MARK: RPE

struct RPEPicker: View {
    @Binding var value: Int?
    var title = "Wie anstrengend war es?"

    private let labels = ["", "sehr leicht", "leicht", "leicht", "moderat", "moderat", "anstrengend", "anstrengend", "hart", "sehr hart", "maximal"]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                if let v = value { Text("\(v) · \(labels[v])").font(.caption.weight(.bold)).foregroundStyle(color(v)) }
            }
            HStack(spacing: 5) {
                ForEach(1...10, id: \.self) { i in
                    Button { withAnimation(.snappy) { value = value == i ? nil : i } } label: {
                        Text("\(i)").font(.caption.weight(.heavy))
                            .frame(maxWidth: .infinity).frame(height: 36)
                            .background(value == i ? color(i) : Theme.card2, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                            .foregroundStyle(value == i ? Theme.bg : Theme.text)
                    }
                    .buttonStyle(.press)
                }
            }
            .sensoryFeedback(.selection, trigger: value)
            Text("Gefühlte Anstrengung von 1 (Spaziergang) bis 10 (alles gegeben). Macht Belastung und Plan genauer.").font(.caption2).foregroundStyle(Theme.muted)
        }
    }

    private func color(_ i: Int) -> Color { i <= 4 ? Theme.good : i <= 7 ? Theme.warn : Theme.bad }
}

/// RPE, Schuh und Notiz zu einem Workout aus Apple Health
struct WorkoutNoteCard: View {
    @Environment(DataStore.self) private var store
    let item: WorkoutItem
    @State private var note = WorkoutNote()
    @State private var text = ""

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                RPEPicker(value: Binding(get: { note.rpe }, set: { note.rpe = $0; save() }))
                if item.activity == .running {
                    let shoes = store.data.shoes.filter { !$0.retired }
                    if !shoes.isEmpty {
                        Divider().overlay(Theme.line)
                        HStack {
                            Label("Schuh", systemImage: "shoe.fill").font(.subheadline.weight(.bold))
                            Spacer()
                            Picker("Schuh", selection: Binding(get: { note.shoeId }, set: { note.shoeId = $0; save() })) {
                                Text("Standard").tag(UUID?.none)
                                ForEach(shoes) { s in Text(s.name).tag(UUID?.some(s.id)) }
                            }
                            .tint(Theme.accent)
                        }
                    }
                    if item.indoor {
                        Toggle(isOn: Binding(get: { note.treadmill }, set: { note.treadmill = $0; save() })) {
                            Label("Laufband", systemImage: "figure.run.treadmill")
                        }
                        .tint(Theme.accent)
                    }
                }
                Divider().overlay(Theme.line)
                TextField("Notiz: Strecke, Wetter, wie es sich angefühlt hat", text: $text, axis: .vertical)
                    .lineLimit(1...4)
                    .onSubmit { note.text = text; save() }
                    .onChange(of: text) { _, v in note.text = v; save() }
            }
        }
        .onAppear { note = store.note(for: item); text = note.text }
    }

    private func save() { store.setNote(note, for: item) }
}

// MARK: Bestzeiten

struct RecordsCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let bests = Records.bests(model.workouts)
        if !bests.isEmpty {
            NavigationLink { RecordsView() } label: {
                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label("Bestzeiten", systemImage: "trophy.fill").font(.headline).foregroundStyle(Theme.accent)
                            Spacer()
                            Chevron()
                        }
                        HStack(spacing: 8) {
                            ForEach(bests.prefix(3)) { b in
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(b.label).font(.caption2).foregroundStyle(Theme.muted)
                                    Text((b.estimated ? "≈" : "") + Fmt.clock(b.seconds)).font(.subheadline.weight(.heavy))
                                    Text(Fmt.pace(b.pace) + "/km").font(.caption2).foregroundStyle(Theme.soft)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }
            }
            .buttonStyle(.press)
        }
    }
}

struct RecordsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let bests = Records.bests(model.workouts)
        let longest = Records.longest(model.workouts)
        let week = Records.biggestWeek(model.workouts)
        let streak = Records.streakWeeks(model.workouts)
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(spacing: 0) {
                    ForEach(bests) { b in
                        NavigationLink { WorkoutDetailView(item: b.workout) } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "trophy.fill").foregroundStyle(Theme.accent).frame(width: 26)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(b.label).font(.subheadline.weight(.bold))
                                    Text("\(Fmt.shortDay(b.workout.start)) · \(b.workout.name)" + (b.estimated ? " · aus dem Schnitt geschätzt" : "")).font(.caption).foregroundStyle(Theme.muted).lineLimit(1)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 1) {
                                    Text((b.estimated ? "≈ " : "") + Fmt.clock(b.seconds)).font(.subheadline.weight(.heavy)).monospacedDigit()
                                    Text(Fmt.pace(b.pace) + "/km").font(.caption2).foregroundStyle(Theme.soft)
                                }
                                Chevron()
                            }
                            .padding(.vertical, 11)
                        }
                        .buttonStyle(.press)
                        if b.id != bests.last?.id { Divider().overlay(Theme.line) }
                    }
                }
                .padding(.horizontal, 16)
                .background(CardBackground(radius: 20))
                HStack(spacing: 8) {
                    StatTile(title: "Längster Lauf", value: longest.map { Fmt.km($0.distance ?? 0) } ?? "–", note: longest.map { Fmt.shortDay($0.start) })
                    StatTile(title: "Größte Woche", value: week.map { Fmt.num($0.1, 1) + " km" } ?? "–", note: week.map { "ab \(Fmt.shortDay($0.0))" })
                }
                HStack(spacing: 8) {
                    StatTile(title: "Wochen in Folge", value: "\(streak)", note: "mit Training")
                    StatTile(title: "VO2max Bestwert", value: model.vo2.max { $0.value < $1.value }.map { Fmt.num($0.value, 1) } ?? "–", note: model.vo2.max { $0.value < $1.value }.map { Fmt.shortDay($0.date) })
                }
                if let v = model.vo2.last {
                    Card {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Was dein Form-Wert hergibt").font(.headline)
                            Text("Aus VO2max \(Fmt.num(v.value, 1)) (Daniels-Tabelle). Realistisch nach gezieltem Training, nicht ab morgen.").font(.caption).foregroundStyle(Theme.muted)
                            ForEach(RaceDistance.allCases.filter { $0 != .ultra50 }) { d in
                                HStack {
                                    Text(d.label).font(.subheadline)
                                    Spacer()
                                    Text(Fmt.clock(VDOT.raceTime(meters: d.meters, vdot: v.value))).font(.subheadline.weight(.bold)).monospacedDigit()
                                }
                            }
                        }
                    }
                }
                Text("Bestzeiten entstehen aus deinen Läufen in Apple Health. Bei Läufen, die deutlich länger sind als die Distanz, wird aus dem Durchschnittstempo geschätzt (≈).")
                    .font(.caption).foregroundStyle(Theme.muted).padding(.horizontal, 4)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
        }
        .screenBackground()
        .navigationTitle("Bestzeiten")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: Schuhe

struct ShoesView: View {
    @Environment(DataStore.self) private var store
    @Environment(AppModel.self) private var model
    @State private var editing: Shoe?

    var body: some View {
        List {
            if store.data.shoes.isEmpty {
                Text("Laufschuhe verlieren nach 600 bis 800 km ihre Dämpfung. Trag deine Schuhe ein, die App zählt die Kilometer aus deinen Läufen und warnt rechtzeitig.")
                    .font(.footnote).foregroundStyle(Theme.muted).listRowBackground(Theme.card)
            }
            ForEach(store.data.shoes.sorted { !$0.retired && $1.retired }) { s in
                let km = store.shoeKm(s, workouts: model.workouts)
                Button { editing = s } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(s.name).font(.subheadline.weight(.bold)).foregroundStyle(s.retired ? Theme.muted : Theme.text)
                            if s.isDefault && !s.retired { Badge(text: "STANDARD", color: Theme.accent) }
                            if s.retired { Badge(text: "AUSGEMUSTERT", color: Theme.muted) }
                            Spacer()
                            Text("\(Fmt.num(km)) / \(Fmt.num(s.limitKm)) km").font(.subheadline.weight(.heavy)).foregroundStyle(km >= s.limitKm ? Theme.bad : km >= s.limitKm * 0.85 ? Theme.warn : Theme.text)
                        }
                        Bar(fraction: km / max(1, s.limitKm), color: km >= s.limitKm ? Theme.bad : km >= s.limitKm * 0.85 ? Theme.warn : Theme.good, height: 6)
                        if km >= s.limitKm * 0.85 && !s.retired {
                            Text(km >= s.limitKm ? "Grenze erreicht. Neue Schuhe schützen Knie und Achillessehne." : "Noch etwa \(Fmt.num(s.limitKm - km)) km, dann ist er durch.")
                                .font(.caption).foregroundStyle(Theme.warn)
                        }
                    }
                }
                .listRowBackground(Theme.card)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle("Schuhe")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { editing = Shoe(name: "", isDefault: store.data.shoes.isEmpty) } label: { Image(systemName: "plus") } } }
        .sheet(item: $editing) { s in ShoeEditor(shoe: s) }
    }
}

struct ShoeEditor: View {
    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var shoe: Shoe

    var body: some View {
        NavigationStack {
            SwiftUI.Form {
                Section {
                    TextField("Modell, z. B. Pegasus 41", text: $shoe.name)
                    DatePicker("Seit", selection: $shoe.since, displayedComponents: .date)
                    Stepper("Schon gelaufen: \(Fmt.num(shoe.startKm)) km", value: $shoe.startKm, in: 0...2000, step: 10)
                    Stepper("Grenze: \(Fmt.num(shoe.limitKm)) km", value: $shoe.limitKm, in: 300...1500, step: 50)
                } footer: { Text("Leichte Wettkampfschuhe halten eher 400 km, gedämpfte Trainingsschuhe 700 bis 900 km.") }
                Section {
                    Toggle("Standardschuh", isOn: $shoe.isDefault)
                    Toggle("Ausgemustert", isOn: $shoe.retired)
                } footer: { Text("Läufe ohne zugeordneten Schuh zählen zum Standardschuh. Im Lauf-Detail kannst du den Schuh pro Lauf ändern.") }
                if store.data.shoes.contains(where: { $0.id == shoe.id }) {
                    Section { Button("Löschen", role: .destructive) { store.update { $0.shoes.removeAll { $0.id == shoe.id } }; dismiss() } }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle(shoe.name.isEmpty ? "Neuer Schuh" : shoe.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        let s = shoe
                        store.update { d in
                            if s.isDefault { for i in d.shoes.indices { d.shoes[i].isDefault = false } }
                            if let i = d.shoes.firstIndex(where: { $0.id == s.id }) { d.shoes[i] = s } else { d.shoes.append(s) }
                        }
                        dismiss()
                    }
                    .disabled(shoe.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

// MARK: Wettkampftag

struct RaceDayView: View {
    @Environment(DataStore.self) private var store
    @Environment(AppModel.self) private var model
    @State private var targetMinutes: Double = 0
    @State private var showPreview = false

    var body: some View {
        if let plan = store.data.plan {
            let meters = plan.settings.distance.meters
            let predicted = VDOT.raceTime(meters: meters, vdot: plan.vdot)
            let target = targetMinutes > 0 ? targetMinutes * 60 : (plan.settings.targetSeconds ?? predicted)
            let start = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: plan.raceDay) ?? plan.raceDay
            let rp = RacePlan.make(distance: meters, targetSeconds: target, maxHR: model.maxHR, start: start)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(plan.settings.raceName.isEmpty ? plan.settings.distance.label : plan.settings.raceName).font(.title2.weight(.heavy))
                        Text("\(Fmt.day(plan.raceDay)) · noch \(max(0, Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: .now), to: plan.raceDay).day ?? 0)) Tage").font(.footnote).foregroundStyle(Theme.muted)
                        HStack(spacing: 8) {
                            StatTile(title: "Zielzeit", value: Fmt.clock(target), note: "Prognose \(Fmt.clock(predicted))", noteColor: target <= predicted ? Theme.warn : Theme.good)
                            StatTile(title: "Zielpace", value: Fmt.pace(rp.goalPace), unit: "/km")
                            StatTile(title: "Puls-Deckel", value: "\(rp.hrCap)", unit: "bpm", note: "erste Hälfte")
                        }
                        HStack {
                            Text("Zielzeit anpassen").font(.caption).foregroundStyle(Theme.muted)
                            Spacer()
                            Stepper("", value: $targetMinutes, in: 10...600, step: 1).labelsHidden()
                                .onAppear { if targetMinutes == 0 { targetMinutes = (target / 60).rounded() } }
                        }
                    }
                    .padding(16)
                    .background(CardBackground(radius: 22, tint: Theme.accent))

                    if target < predicted * 0.97 {
                        Hint(icon: "exclamationmark.triangle.fill", title: "Ziel ambitioniert", text: "Dein Form-Wert sagt \(Fmt.clock(predicted)). Mehr als 3 % schneller zu starten endet meist mit Einbruch. Lieber die Prognose laufen und in der zweiten Hälfte zulegen.", color: Theme.warn)
                    }

                    Card {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Zwischenzeiten").font(.headline)
                            Text("Leicht negativ: ruhig raus, hinten zulegen.").font(.caption).foregroundStyle(Theme.muted)
                            ForEach(rp.checkpoints, id: \.label) { c in
                                HStack {
                                    Text(c.label).font(.subheadline)
                                    Spacer()
                                    Text(Fmt.clock(c.time)).font(.subheadline.weight(.heavy)).monospacedDigit()
                                }
                            }
                            Divider().overlay(Theme.line)
                            HStack { Text("Ziel").font(.subheadline.weight(.bold)); Spacer(); Text(Fmt.clock(target)).font(.subheadline.weight(.heavy)).monospacedDigit().foregroundStyle(Theme.accent) }
                        }
                    }

                    Card {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Kilometer für Kilometer").font(.headline)
                            Chart(rp.splits, id: \.km) { s in
                                BarMark(x: .value("km", s.km), y: .value("Pace", s.pace))
                                    .foregroundStyle(s.pace > rp.goalPace * 1.005 ? Theme.sleep : s.pace < rp.goalPace * 0.995 ? Theme.accent : Theme.soft)
                            }
                            .chartYScale(domain: (rp.goalPace * 0.9)...(rp.goalPace * 1.08))
                            .chartYAxis { AxisMarks(position: .leading) { v in AxisValueLabel { if let d = v.as(Double.self) { Text(Fmt.pace(d)) } } } }
                            .frame(height: 120)
                            HStack(spacing: 12) {
                                legend("Anlaufen", Theme.sleep); legend("Zielpace", Theme.soft); legend("Zulegen", Theme.accent)
                            }
                        }
                    }

                    if WatchExport.isSupported {
                        let run = PlannedRun(date: plan.raceDay, type: .race, title: "Wettkampf", purpose: "", structure: raceStructure(rp))
                        Button { showPreview = true } label: {
                            Label("Pacingplan an Apple Watch senden", systemImage: "applewatch").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 15)
                                .background(Theme.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous)).foregroundStyle(Theme.bg)
                        }
                        .buttonStyle(.press)
                        .workoutPreview(WatchExport.workoutPlan(for: run, paces: plan.paces), isPresented: $showPreview)
                        Text("Die Uhr warnt in jedem Abschnitt, wenn du zu schnell bist. Das ist am Anfang das Wichtigste.").font(.caption).foregroundStyle(Theme.muted).padding(.horizontal, 4)
                    }

                    Card {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Ablauf").font(.headline)
                            ForEach(rp.timeline, id: \.when) { t in
                                HStack(alignment: .top, spacing: 10) {
                                    Text(t.when).font(.caption.weight(.heavy)).foregroundStyle(Theme.accent).frame(width: 90, alignment: .leading)
                                    Text(t.what).font(.footnote).foregroundStyle(Theme.soft).fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                    Card {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Verpflegung und Puls").font(.headline)
                            ForEach(rp.fueling, id: \.self) { f in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill").font(.footnote).foregroundStyle(Theme.accent)
                                    Text(f).font(.footnote).foregroundStyle(Theme.soft).fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            Text("Einlaufen: \(rp.warmup).").font(.footnote).foregroundStyle(Theme.soft)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
            .screenBackground()
            .navigationTitle("Wettkampftag")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func legend(_ t: String, _ c: Color) -> some View {
        HStack(spacing: 4) { Circle().fill(c).frame(width: 7, height: 7); Text(t).font(.caption2).foregroundStyle(Theme.soft) }
    }

    /// Drei Abschnitte in Wettkampfzone, die Watch warnt nur bei Tempo-Abweichung
    private func raceStructure(_ rp: RacePlan) -> RunStructure {
        let d = rp.distance
        var s = RunStructure()
        s.blocks = [
            Block(repeats: 1, work: .m(d * 0.1, .race)),
            Block(repeats: 1, work: .m(d * 0.7, .race)),
            Block(repeats: 1, work: .m(d * 0.2, .race)),
        ]
        return s
    }
}

// MARK: Plan pausieren

struct PlanPauseSheet: View {
    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var until = Calendar.current.addDays(7, to: .now)

    var body: some View {
        NavigationStack {
            SwiftUI.Form {
                Section {
                    DatePicker("Pause bis", selection: $until, in: Date.now..., displayedComponents: .date)
                } footer: {
                    Text("Urlaub, Prüfungen, Dienstreise. Alle Läufe bis dahin werden zu Ruhetagen. Der Plan läuft danach normal weiter, bei mehr als 10 Tagen Pause startet er mit zwei lockeren Tagen.")
                }
                if store.data.planPausedUntil != nil {
                    Section { Button("Pause beenden", role: .destructive) { store.update { $0.planPausedUntil = nil }; dismiss() } }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("Plan pausieren")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Pausieren") { let u = Calendar.current.startOfDay(for: until); store.update { $0.planPausedUntil = u }; dismiss() } }
            }
        }
        .presentationDetents([.medium])
    }
}
