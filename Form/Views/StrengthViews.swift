import SwiftUI
import UIKit
import Charts

// MARK: Übersicht Krafttraining

struct StrengthHomeView: View {
    @Environment(DataStore.self) private var store
    @State private var editing: Routine?
    @State private var openSession = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let s = store.activeSession {
                Button { openSession = true } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "timer").font(.title3.weight(.bold)).foregroundStyle(Theme.bg)
                            .frame(width: 44, height: 44).background(Theme.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Einheit läuft: \(s.name)").font(.subheadline.weight(.bold))
                            Text("Seit \(Fmt.time(s.start)) · \(s.doneSets) Sätze erledigt").font(.caption).foregroundStyle(Theme.muted)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(Theme.muted)
                    }
                    .padding(14)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            let r = store.restrictions
            if !r.blockedRegions.isEmpty || !r.strengthAllowed {
                NavigationLink { InjuryView() } label: {
                    Hint(icon: "bandage.fill", title: r.strengthAllowed ? "Verletzung aktiv" : "Krankheitsmodus aktiv",
                         text: r.strengthAllowed
                            ? "Übungen, die \(r.blockedRegions.map(\.label).sorted().joined(separator: ", ")) belasten, werden automatisch ersetzt."
                            : "Krafttraining ist pausiert, bis du dich gesund meldest.",
                         color: Theme.bad)
                }
                .buttonStyle(.plain)
            }

            HStack {
                Text("Routinen").font(.title3.weight(.bold))
                Spacer()
                Button { editing = Routine(name: "", items: []) } label: { Label("Neu", systemImage: "plus") }
                    .font(.subheadline.weight(.bold))
            }
            .padding(.horizontal, 4)
            .padding(.top, 6)

            NavigationLink { ProgramLibraryView() } label: {
                HStack(spacing: 12) {
                    Image(systemName: "square.stack.3d.up.fill").font(.title3.weight(.bold)).foregroundStyle(Theme.bg)
                        .frame(width: 44, height: 44)
                        .background(LinearGradient(colors: [Theme.warn, Theme.bad.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing),
                                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.data.routines.isEmpty ? "Mit einem Programm starten" : "Programme entdecken").font(.subheadline.weight(.bold))
                        Text("\(Presets.programs.count) fertige Pläne: Einsteiger, Zuhause, Beine & Po, Split").font(.caption).foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(Theme.muted)
                }
                .padding(14)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .buttonStyle(.plain)

            ForEach(store.data.routines) { routine in
                RoutineCard(routine: routine, onEdit: { editing = routine }, onStart: { start(routine) })
            }

            if !store.data.sessions.isEmpty {
                SectionHeader("Verlauf", trailing: "\(store.data.sessions.count) Einheiten")
                VStack(spacing: 0) {
                    let recent = Array(store.data.sessions.sorted { $0.start > $1.start }.prefix(8))
                    ForEach(recent) { s in
                        NavigationLink { SessionDetailView(session: s) } label: { SessionRow(session: s) }
                            .buttonStyle(.plain)
                        if s.id != recent.last?.id { Divider().overlay(Theme.line) }
                    }
                }
                .padding(.horizontal, 16)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))

                SectionHeader("Fortschritt")
                ProgressList()
            }
        }
        .sheet(item: $editing) { r in RoutineEditor(routine: r) }
        .navigationDestination(isPresented: $openSession) { SessionView() }
    }

    private func start(_ routine: Routine) {
        Task { await Notifications.requestPermission() }
        if store.activeSession == nil {
            store.activeSession = Strength.makeSession(from: routine, sessions: store.data.sessions, restrictions: store.restrictions)
            store.saveActiveSession()
        }
        openSession = true
    }
}

struct RoutineCard: View {
    @Environment(DataStore.self) private var store
    let routine: Routine
    let onEdit: () -> Void
    let onStart: () -> Void

    var body: some View {
        let blocked = Strength.blockedItems(routine, restrictions: store.restrictions)
        Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(routine.name).font(.headline)
                        Text("\(routine.items.count) Übungen · \(routine.items.reduce(0) { $0 + $1.sets }) Sätze")
                            .font(.caption).foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    Button("Bearbeiten", action: onEdit).font(.footnote.weight(.semibold)).foregroundStyle(Theme.muted)
                }
                Text(routine.items.compactMap { ExerciseDB.find($0.exerciseId)?.name }.joined(separator: " · "))
                    .font(.footnote).foregroundStyle(Theme.soft).lineLimit(2)
                if !blocked.isEmpty {
                    ForEach(blocked, id: \.0.id) { pair in
                        HStack(spacing: 6) {
                            Text(pair.0.name).strikethrough().foregroundStyle(Theme.muted)
                            Image(systemName: "arrow.right").font(.caption2).foregroundStyle(Theme.muted)
                            Text(pair.1?.name ?? "entfällt").foregroundStyle(pair.1 == nil ? Theme.bad : Theme.accent)
                        }
                        .font(.caption.weight(.semibold))
                    }
                }
                Button(action: onStart) {
                    Label(store.activeSession == nil ? "Training starten" : "Zur laufenden Einheit", systemImage: "play.fill")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Theme.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .foregroundStyle(Theme.bg)
                }
                .disabled(!store.restrictions.strengthAllowed)
                .opacity(store.restrictions.strengthAllowed ? 1 : 0.4)
            }
        }
    }
}

struct SessionRow: View {
    let session: StrengthSession

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "dumbbell.fill").foregroundStyle(Theme.warn)
                .frame(width: 40, height: 40)
                .background(Theme.warn.opacity(0.14), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(session.name).font(.subheadline.weight(.bold))
                Text("\(Fmt.shortDay(session.start)) · \(session.doneSets) Sätze · \(Fmt.num(session.volume / 1000, 1)) t bewegt")
                    .font(.caption).foregroundStyle(Theme.muted)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.muted)
        }
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }
}

struct ProgressList: View {
    @Environment(DataStore.self) private var store

    var body: some View {
        let ids = Array(Set(store.data.sessions.flatMap { $0.exercises.filter { $0.sets.contains(where: \.done) }.map(\.exerciseId) }))
            .sorted { ExerciseDB.name($0) < ExerciseDB.name($1) }
        VStack(spacing: 0) {
            ForEach(ids, id: \.self) { id in
                let pts = Strength.progress(id, sessions: store.data.sessions)
                NavigationLink { ExerciseHistoryView(exerciseId: id) } label: {
                    HStack {
                        Text(ExerciseDB.name(id)).font(.subheadline.weight(.semibold))
                        Spacer()
                        if let last = pts.last {
                            Text("1RM ≈ \(Fmt.num(last.value)) kg").font(.footnote.weight(.bold))
                            if pts.count > 1, let first = pts.first {
                                let d = last.value - first.value
                                Text((d >= 0 ? "+" : "−") + Fmt.num(abs(d)))
                                    .font(.caption.weight(.bold)).foregroundStyle(d >= 0 ? Theme.good : Theme.warn)
                            }
                        }
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.muted)
                    }
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if id != ids.last { Divider().overlay(Theme.line) }
            }
        }
        .padding(.horizontal, 16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

// MARK: Laufende Einheit

struct SessionView: View {
    @Environment(DataStore.self) private var store
    @Environment(RestTimer.self) private var timer
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var picker: PickerMode?
    @State private var summary: StrengthSession?
    @State private var confirmFinish = false
    @State private var confirmDiscard = false

    enum PickerMode: Identifiable {
        case add
        case replace(Int)
        var id: String {
            switch self {
            case .add: return "add"
            case .replace(let i): return "r\(i)"
            }
        }
    }

    var body: some View {
        ScrollView {
            if let s = store.activeSession {
                VStack(alignment: .leading, spacing: 12) {
                    TimelineView(.periodic(from: .now, by: 1)) { ctx in
                        HStack(spacing: 8) {
                            StatTile(title: "Dauer", value: Fmt.clock(ctx.date.timeIntervalSince(s.start)))
                            StatTile(title: "Sätze", value: "\(s.doneSets)/\(s.exercises.reduce(0) { $0 + $1.sets.count })")
                            StatTile(title: "Volumen", value: Fmt.num(s.volume / 1000, 2), unit: "t")
                        }
                    }
                    ForEach(Array(s.exercises.enumerated()), id: \.element.id) { i, _ in
                        ExerciseCard(ex: binding(i), onSetDone: { setIndex in setDone(i, setIndex) },
                                     onReplace: { picker = .replace(i) }, onDelete: { remove(i) })
                    }
                    Button { picker = .add } label: {
                        Label("Übung hinzufügen", systemImage: "plus")
                            .font(.subheadline.weight(.bold)).frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    Button { confirmFinish = true } label: {
                        Text("Training beenden").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 15)
                            .background(Theme.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .foregroundStyle(Theme.bg)
                    }
                    .padding(.top, 6)
                    Button("Einheit verwerfen", role: .destructive) { confirmDiscard = true }
                        .font(.footnote).frame(maxWidth: .infinity).padding(.top, 4)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 120)
            } else {
                Card { Text("Keine laufende Einheit.").foregroundStyle(Theme.soft) }.padding(16)
            }
        }
        .screenBackground()
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(store.activeSession?.name ?? "Training")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Fertig") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
            }
        }
        .safeAreaInset(edge: .bottom) { if timer.running { RestBar() } }
        .sheet(item: $picker) { mode in
            switch mode {
            case .add:
                ExercisePicker(current: nil) { add($0) }
            case .replace(let i):
                ExercisePicker(current: store.activeSession?.exercises[safe: i].flatMap { ExerciseDB.find($0.exerciseId) }) { replace(i, with: $0) }
            }
        }
        .sheet(item: $summary, onDismiss: { dismiss() }) { s in SessionSummaryView(session: s) }
        .confirmationDialog("Training beenden?", isPresented: $confirmFinish, titleVisibility: .visible) {
            Button("Beenden und speichern") { finish() }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Offene Sätze ohne Haken werden nicht gezählt.")
        }
        .confirmationDialog("Einheit wirklich verwerfen?", isPresented: $confirmDiscard, titleVisibility: .visible) {
            Button("Verwerfen", role: .destructive) {
                store.activeSession = nil
                store.saveActiveSession()
                timer.stop()
                dismiss()
            }
        }
        .task { await Notifications.requestPermission() }
    }

    private func binding(_ i: Int) -> Binding<SessionExercise> {
        Binding(
            get: { store.activeSession?.exercises[safe: i] ?? SessionExercise(exerciseId: "", repMin: 0, repMax: 0, sets: []) },
            set: { new in
                guard store.activeSession?.exercises.indices.contains(i) == true else { return }
                store.activeSession?.exercises[i] = new
                store.saveActiveSession()
            }
        )
    }

    private func setDone(_ i: Int, _ setIndex: Int) {
        guard let s = store.activeSession, let ex = s.exercises[safe: i] else { return }
        let rest = Double(store.data.profile.restSeconds) * (ExerciseDB.find(ex.exerciseId)?.compound == true ? 1 : 0.6)
        var nextName = ExerciseDB.name(ex.exerciseId)
        var nextSet = "Satz \(setIndex + 2)/\(ex.sets.count)"
        var target = ""
        if let next = ex.sets[safe: setIndex + 1] {
            target = "\(Fmt.kg(next.weight)) kg × \(next.reps)"
        } else if let nextEx = s.exercises[safe: i + 1], let first = nextEx.sets.first {
            nextName = ExerciseDB.name(nextEx.exerciseId)
            nextSet = "Satz 1/\(nextEx.sets.count)"
            target = "\(Fmt.kg(first.weight)) kg × \(first.reps)"
        } else {
            nextSet = "Letzter Satz geschafft"
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        timer.start(seconds: rest, exercise: nextName, nextSet: nextSet, target: target, session: s.name)
    }

    private func add(_ e: Exercise) {
        let sug = Strength.suggestion(exerciseId: e.id, repMin: 8, repMax: 12, sessions: store.data.sessions)
        store.activeSession?.exercises.append(SessionExercise(exerciseId: e.id, repMin: 8, repMax: 12,
                                                              sets: (0..<3).map { _ in SetEntry(weight: sug.weight, reps: sug.reps) }))
        store.saveActiveSession()
    }

    private func replace(_ i: Int, with e: Exercise) {
        guard var ex = store.activeSession?.exercises[safe: i] else { return }
        let sug = Strength.suggestion(exerciseId: e.id, repMin: ex.repMin, repMax: ex.repMax, sessions: store.data.sessions)
        ex.replaced = ex.replaced ?? ex.exerciseId
        ex.exerciseId = e.id
        ex.sets = ex.sets.map { _ in SetEntry(weight: sug.weight, reps: sug.reps, done: false) }
        store.activeSession?.exercises[i] = ex
        store.saveActiveSession()
    }

    private func remove(_ i: Int) {
        guard store.activeSession?.exercises.indices.contains(i) == true else { return }
        store.activeSession?.exercises.remove(at: i)
        store.saveActiveSession()
    }

    private func finish() {
        guard var s = store.activeSession else { return }
        s.end = .now
        s.exercises = s.exercises.filter { $0.sets.contains(where: \.done) }.map { e in
            var e = e
            e.sets = e.sets.filter(\.done)
            return e
        }
        let session = s
        store.update { $0.sessions.append(session) }
        store.activeSession = nil
        store.saveActiveSession()
        timer.stop()
        if store.data.profile.saveStrengthToHealth && !model.usingDemo && session.doneSets > 0 {
            let hk = model.health.store
            Task { await Strength.save(session, to: hk) }
        }
        summary = session
    }
}

struct ExerciseCard: View {
    @Binding var ex: SessionExercise
    @Environment(DataStore.self) private var store
    let onSetDone: (Int) -> Void
    let onReplace: () -> Void
    let onDelete: () -> Void

    var body: some View {
        let info = ExerciseDB.find(ex.exerciseId)
        let last = Strength.last(ex.exerciseId, in: store.data.sessions)
        let sug = Strength.suggestion(exerciseId: ex.exerciseId, repMin: ex.repMin, repMax: ex.repMax, sessions: store.data.sessions)
        Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(info?.name ?? "Übung").font(.headline)
                        Text("\(info?.primary.label ?? "") · Ziel \(ex.repMin)–\(ex.repMax) Wdh.").font(.caption).foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    Menu {
                        Button { onReplace() } label: { Label("Übung ersetzen", systemImage: "arrow.triangle.2.circlepath") }
                        Button { ex.sets.append(SetEntry(weight: ex.sets.last?.weight ?? 0, reps: ex.sets.last?.reps ?? ex.repMin)) } label: { Label("Satz hinzufügen", systemImage: "plus") }
                        if ex.sets.count > 1 {
                            Button { ex.sets.removeLast() } label: { Label("Letzten Satz löschen", systemImage: "minus") }
                        }
                        Button(role: .destructive) { onDelete() } label: { Label("Übung entfernen", systemImage: "trash") }
                    } label: {
                        Image(systemName: "ellipsis").frame(width: 36, height: 30).foregroundStyle(Theme.muted)
                    }
                    .accessibilityLabel("Optionen")
                }
                if let r = ex.replaced {
                    Badge(text: "ERSATZ FÜR \(ExerciseDB.name(r).uppercased())", color: Theme.sleep)
                }
                if let last {
                    Text("Letztes Mal: " + Strength.lastSummary(last)).font(.caption).foregroundStyle(Theme.soft)
                }
                Text(sug.text).font(.caption.weight(.semibold)).foregroundStyle(sug.increase ? Theme.accent : Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    Text("SATZ").frame(width: 34, alignment: .leading)
                    Text("KG").frame(maxWidth: .infinity)
                    Text("WDH").frame(maxWidth: .infinity)
                    Spacer().frame(width: 44)
                }
                .font(.caption2.weight(.heavy)).foregroundStyle(Theme.muted)

                ForEach($ex.sets) { $set in
                    let idx = ex.sets.firstIndex { $0.id == set.id } ?? 0
                    HStack(spacing: 8) {
                        Text("\(idx + 1)").font(.subheadline.weight(.heavy)).frame(width: 34, alignment: .leading)
                            .foregroundStyle(set.done ? Theme.accent : Theme.text)
                        TextField("0", value: $set.weight, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.center)
                            .font(.body.weight(.bold))
                            .padding(.vertical, 9)
                            .background(Theme.card2, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        TextField("0", value: $set.reps, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.center)
                            .font(.body.weight(.bold))
                            .padding(.vertical, 9)
                            .background(Theme.card2, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        Button {
                            set.done.toggle()
                            if set.done { onSetDone(idx) }
                        } label: {
                            Image(systemName: set.done ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundStyle(set.done ? Theme.accent : Theme.muted)
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel(set.done ? "Satz erledigt" : "Satz abhaken")
                    }
                    .opacity(set.done ? 0.75 : 1)
                }
            }
        }
    }
}

struct RestBar: View {
    @Environment(RestTimer.self) private var timer

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { ctx in
            let end = timer.endsAt ?? ctx.date
            let remaining = max(0, end.timeIntervalSince(ctx.date))
            let progress = timer.total > 0 ? 1 - remaining / timer.total : 1
            VStack(spacing: 10) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("SATZPAUSE").font(.caption2.weight(.heavy)).foregroundStyle(Theme.muted)
                        Text(Fmt.clock(remaining)).font(.system(size: 34, weight: .heavy)).monospacedDigit().foregroundStyle(Theme.warn)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(timer.exercise).font(.subheadline.weight(.bold)).lineLimit(1)
                        Text(timer.nextSet + (timer.target.isEmpty ? "" : " · " + timer.target)).font(.caption.weight(.semibold)).foregroundStyle(Theme.accent).lineLimit(1)
                    }
                }
                Bar(fraction: progress, color: Theme.warn, height: 6)
                HStack(spacing: 8) {
                    Button { timer.add(30) } label: {
                        Text("+ 30 s").font(.subheadline.weight(.bold)).frame(maxWidth: .infinity).padding(.vertical, 10)
                            .background(Theme.card2, in: Capsule())
                    }
                    Button { timer.stop() } label: {
                        Text("Weiter").font(.subheadline.weight(.bold)).frame(maxWidth: .infinity).padding(.vertical, 10)
                            .background(Theme.accent, in: Capsule()).foregroundStyle(Theme.bg)
                    }
                }
            }
            .padding(16)
            .background(.black, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(Theme.line))
            .padding(.horizontal, 12)
            .padding(.bottom, 4)
        }
        .task(id: timer.endsAt) {
            guard let end = timer.endsAt else { return }
            let wait = end.timeIntervalSinceNow
            if wait > 0 { try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000)) }
            if !Task.isCancelled, let e = timer.endsAt, e <= .now.addingTimeInterval(0.3) {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                timer.stop()
            }
        }
    }
}

struct SessionSummaryView: View {
    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let session: StrengthSession

    var body: some View {
        let records = Strength.records(in: session, history: store.data.sessions)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Image(systemName: "checkmark.seal.fill").font(.system(size: 54)).foregroundStyle(Theme.accent)
                        .frame(maxWidth: .infinity).padding(.top, 10)
                    Text("Stark, Einheit gespeichert").font(.title2.weight(.heavy)).frame(maxWidth: .infinity)
                    HStack(spacing: 8) {
                        StatTile(title: "Dauer", value: Fmt.clock((session.end ?? .now).timeIntervalSince(session.start)))
                        StatTile(title: "Sätze", value: "\(session.doneSets)")
                        StatTile(title: "Volumen", value: Fmt.num(session.volume / 1000, 2), unit: "t")
                    }
                    if !records.isEmpty {
                        SectionHeader("Neue Bestwerte")
                        ForEach(records, id: \.exerciseId) { r in
                            Hint(icon: "trophy.fill", title: ExerciseDB.name(r.exerciseId),
                                 text: "Geschätztes Maximum \(Fmt.num(r.oneRM)) kg, vorher \(Fmt.num(r.previous)) kg.", color: Theme.accent)
                        }
                    }
                    SectionHeader("Nächstes Mal")
                    ForEach(session.exercises) { e in
                        let sug = Strength.suggestion(exerciseId: e.exerciseId, repMin: e.repMin, repMax: e.repMax, sessions: store.data.sessions)
                        HStack(alignment: .top) {
                            Text(ExerciseDB.name(e.exerciseId)).font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(sug.weight > 0 ? "\(Fmt.kg(sug.weight)) kg × \(sug.reps)" : "\(sug.reps) Wdh.")
                                .font(.subheadline.weight(.bold)).foregroundStyle(sug.increase ? Theme.accent : Theme.text)
                        }
                        .padding(.horizontal, 4)
                    }
                }
                .padding(16)
            }
            .screenBackground()
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
        }
    }
}

struct SessionDetailView: View {
    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let session: StrengthSession
    @State private var confirmDelete = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(Fmt.day(session.start) + " · " + Fmt.time(session.start)).font(.footnote.weight(.semibold)).foregroundStyle(Theme.muted)
                HStack(spacing: 8) {
                    StatTile(title: "Dauer", value: Fmt.clock((session.end ?? session.start).timeIntervalSince(session.start)))
                    StatTile(title: "Sätze", value: "\(session.doneSets)")
                    StatTile(title: "Volumen", value: Fmt.num(session.volume / 1000, 2), unit: "t")
                }
                ForEach(session.exercises) { e in
                    Card {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(ExerciseDB.name(e.exerciseId)).font(.headline)
                            ForEach(Array(e.sets.enumerated()), id: \.element.id) { i, s in
                                HStack {
                                    Text("Satz \(i + 1)").foregroundStyle(Theme.muted)
                                    Spacer()
                                    Text("\(Fmt.kg(s.weight)) kg × \(s.reps)").fontWeight(.bold)
                                }
                                .font(.subheadline)
                            }
                        }
                    }
                }
                Button("Einheit löschen", role: .destructive) { confirmDelete = true }
                    .frame(maxWidth: .infinity).padding(.top, 8)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .screenBackground()
        .navigationTitle(session.name)
        .confirmationDialog("Einheit löschen?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Löschen", role: .destructive) {
                store.update { d in d.sessions.removeAll { $0.id == session.id } }
                dismiss()
            }
        }
    }
}

struct ExerciseHistoryView: View {
    @Environment(DataStore.self) private var store
    let exerciseId: String

    var body: some View {
        let pts = Strength.progress(exerciseId, sessions: store.data.sessions)
        let rows = store.data.sessions.sorted { $0.start > $1.start }.compactMap { s -> (Date, SessionExercise)? in
            s.exercises.first { $0.exerciseId == exerciseId }.map { (s.start, $0) }
        }
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Geschätztes Maximum (1RM)").font(.subheadline.weight(.bold))
                        if pts.count > 1 {
                            Chart(pts) { p in
                                LineMark(x: .value("Datum", p.date), y: .value("kg", p.value)).foregroundStyle(Theme.accent)
                                PointMark(x: .value("Datum", p.date), y: .value("kg", p.value)).foregroundStyle(Theme.accent)
                            }
                            .chartYScale(domain: .automatic(includesZero: false))
                            .frame(height: 160)
                        } else {
                            Text("Ab zwei Einheiten siehst du hier deinen Verlauf.").font(.footnote).foregroundStyle(Theme.soft)
                        }
                    }
                }
                ForEach(rows, id: \.0) { row in
                    HStack {
                        Text(Fmt.shortDay(row.0)).foregroundStyle(Theme.muted)
                        Spacer()
                        Text(Strength.lastSummary(row.1)).fontWeight(.semibold)
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 4)
                }
            }
            .padding(16)
        }
        .screenBackground()
        .navigationTitle(ExerciseDB.name(exerciseId))
    }
}

// MARK: Übungsauswahl

struct ExercisePicker: View {
    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let current: Exercise?
    let onPick: (Exercise) -> Void
    @State private var query = ""
    @State private var showCustom = false

    var body: some View {
        let blocked = store.restrictions.blockedRegions
        NavigationStack {
            List {
                if let c = current {
                    let alts = ExerciseDB.alternatives(for: c, avoiding: blocked)
                    if !alts.isEmpty {
                        Section("Passender Ersatz für \(c.name)") {
                            ForEach(alts.prefix(6)) { e in row(e, blocked: blocked) }
                        }
                    }
                }
                ForEach(ExerciseDB.grouped, id: \.0) { group in
                    let list = group.1.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }
                    if !list.isEmpty {
                        Section(group.0.label) {
                            ForEach(list) { e in row(e, blocked: blocked) }
                        }
                    }
                }
                Section {
                    Button { showCustom = true } label: { Label("Eigene Übung anlegen", systemImage: "plus") }
                }
            }
            .searchable(text: $query, prompt: "Übung suchen")
            .navigationTitle(current == nil ? "Übung hinzufügen" : "Übung ersetzen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } } }
            .sheet(isPresented: $showCustom) { CustomExerciseView() }
        }
    }

    private func row(_ e: Exercise, blocked: Set<BodyRegion>) -> some View {
        let isBlocked = ExerciseDB.isBlocked(e, by: blocked)
        return Button {
            onPick(e)
            dismiss()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(e.name).foregroundStyle(isBlocked ? Theme.muted : Theme.text)
                    Text(e.equipment + (e.stress.isEmpty ? "" : " · belastet " + e.stress.map(\.label).joined(separator: ", ")))
                        .font(.caption).foregroundStyle(Theme.muted).lineLimit(1)
                }
                Spacer()
                if isBlocked { Image(systemName: "bandage").foregroundStyle(Theme.bad) }
            }
        }
    }
}

struct CustomExerciseView: View {
    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var muscle: MuscleGroup = .chest
    @State private var stress: Set<BodyRegion> = []
    @State private var increment: Double = 2.5

    var body: some View {
        NavigationStack {
            SwiftUI.Form {
                TextField("Name", text: $name)
                Picker("Muskel", selection: $muscle) {
                    ForEach(MuscleGroup.allCases) { Text($0.label).tag($0) }
                }
                Stepper("Steigerung: \(Fmt.num(increment, 1)) kg", value: $increment, in: 0.5...10, step: 0.5)
                Section("Belastet (für den Verletzungsmodus)") {
                    ForEach(BodyRegion.allCases) { r in
                        Toggle(r.label, isOn: Binding(get: { stress.contains(r) }, set: { on in if on { stress.insert(r) } else { stress.remove(r) } }))
                    }
                }
            }
            .navigationTitle("Eigene Übung")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        let e = Exercise(id: "c_" + UUID().uuidString.prefix(8), name: name, primary: muscle, stress: Array(stress),
                                         equipment: "Eigene", compound: false, increment: increment)
                        store.update { $0.customExercises.append(e) }
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

// MARK: Routine bearbeiten

struct RoutineEditor: View {
    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var routine: Routine
    @State private var showPicker = false
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            SwiftUI.Form {
                TextField("Name der Routine", text: $routine.name)
                Section {
                    ForEach($routine.items) { $item in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(ExerciseDB.name(item.exerciseId)).font(.subheadline.weight(.bold))
                            Stepper("\(item.sets) Sätze", value: $item.sets, in: 1...8)
                            Stepper("Wdh. von \(item.repMin)", value: $item.repMin, in: 1...item.repMax)
                            Stepper("bis \(item.repMax)", value: $item.repMax, in: item.repMin...60)
                        }
                        .font(.subheadline)
                    }
                    .onDelete { routine.items.remove(atOffsets: $0) }
                    .onMove { routine.items.move(fromOffsets: $0, toOffset: $1) }
                    Button { showPicker = true } label: { Label("Übung hinzufügen", systemImage: "plus") }
                } header: {
                    Text("Übungen")
                } footer: {
                    Text("Doppelte Progression: Erst die Wiederholungen bis zum oberen Wert steigern, dann gibt es mehr Gewicht.")
                }
                if store.data.routines.contains(where: { $0.id == routine.id }) {
                    Button("Routine löschen", role: .destructive) { confirmDelete = true }
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle(routine.name.isEmpty ? "Neue Routine" : routine.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        let r = routine
                        store.update { d in
                            if let i = d.routines.firstIndex(where: { $0.id == r.id }) { d.routines[i] = r } else { d.routines.append(r) }
                        }
                        dismiss()
                    }
                    .disabled(routine.name.trimmingCharacters(in: .whitespaces).isEmpty || routine.items.isEmpty)
                }
            }
            .sheet(isPresented: $showPicker) {
                ExercisePicker(current: nil) { e in routine.items.append(RoutineItem(exerciseId: e.id)) }
            }
            .confirmationDialog("Routine löschen?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Löschen", role: .destructive) {
                    let id = routine.id
                    store.update { d in d.routines.removeAll { $0.id == id } }
                    dismiss()
                }
            }
        }
    }
}

extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}
