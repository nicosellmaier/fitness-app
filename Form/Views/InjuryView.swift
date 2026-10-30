import SwiftUI

struct InjuryView: View {
    @Environment(DataStore.self) private var store
    @Environment(AppModel.self) private var model
    @State private var mode = 0
    @State private var draft = Injury(region: .knee)
    @State private var editingNew = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Sag der App, was los ist. Training und Plan bauen sich automatisch drumherum.")
                    .font(.subheadline).foregroundStyle(Theme.soft).padding(.horizontal, 4)
                Picker("Art", selection: $mode) {
                    Text("Verletzung").tag(0)
                    Text("Krankheit").tag(1)
                }
                .pickerStyle(.segmented)

                if mode == 0 { injuries } else { illness }

                Text("Die App ersetzt keine Diagnose. Bei starken, anhaltenden oder unklaren Beschwerden lass es ärztlich abklären.")
                    .font(.caption).foregroundStyle(Theme.muted).multilineTextAlignment(.center).frame(maxWidth: .infinity).padding(.top, 8)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
        }
        .screenBackground()
        .navigationTitle("Nicht fit?")
        .onAppear { if store.data.illness?.active == true && store.data.injuries.allSatisfy({ !$0.active }) { mode = 1 } }
    }

    // MARK: Verletzungen

    @ViewBuilder private var injuries: some View {
        let active = store.data.injuries.filter(\.active)
        ForEach(active) { inj in
            Card {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(inj.title).font(.headline)
                            Text("\(inj.severityLabel) · seit \(Fmt.shortDay(inj.start)) · Pause bis ca. \(Fmt.shortDay(inj.expectedEnd))")
                                .font(.caption).foregroundStyle(Theme.muted)
                        }
                        Spacer()
                        Badge(text: "AKTIV", color: Theme.bad)
                    }
                    Button {
                        store.update { d in
                            if let i = d.injuries.firstIndex(where: { $0.id == inj.id }) { d.injuries[i].resolved = .now }
                        }
                        refresh()
                    } label: {
                        Text("Wieder fit").font(.subheadline.weight(.bold)).frame(maxWidth: .infinity).padding(.vertical, 11)
                            .background(Theme.card2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }
        }
        if !active.isEmpty { effects }

        SectionHeader(active.isEmpty ? "Was tut weh?" : "Weitere Verletzung")
        BodyPicker(selected: $draft.region)
        if draft.region.hasSide {
            Picker("Seite", selection: Binding(get: { draft.side ?? .right }, set: { draft.side = $0 })) {
                ForEach(Side.allCases) { Text($0.label.capitalizedFirst).tag($0) }
            }
            .pickerStyle(.segmented)
        }
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Text("WIE SCHLIMM?").font(.caption.weight(.heavy)).foregroundStyle(Theme.muted)
                HStack(spacing: 6) {
                    ForEach(1...3, id: \.self) { lvl in
                        let label = ["Ziept leicht", "Schmerz bei Last", "Auch in Ruhe"][lvl - 1]
                        Button { draft.severity = lvl } label: {
                            Text(label).font(.footnote.weight(.bold)).frame(maxWidth: .infinity).padding(.vertical, 10)
                                .background(draft.severity == lvl ? Theme.warn.opacity(0.2) : Theme.card2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(draft.severity == lvl ? Theme.warn : .clear, lineWidth: 1.5))
                                .foregroundStyle(draft.severity == lvl ? Theme.warn : Theme.text)
                        }
                        .buttonStyle(.press)
                    }
                }
                Stepper("Pause geplant: \(draft.expectedDays) Tage", value: $draft.expectedDays, in: 2...90, step: draft.expectedDays < 14 ? 1 : 7)
                    .font(.subheadline)
                TextField("Notiz (optional)", text: $draft.note)
                    .padding(10).background(Theme.card2, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        preview
        Button {
            var i = draft
            i.start = .now
            if !i.region.hasSide { i.side = nil } else if i.side == nil { i.side = .right }
            store.update { $0.injuries.append(i) }
            draft = Injury(region: .knee)
            refresh()
        } label: {
            Text("Verletzung eintragen und Plan anpassen").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 15)
                .background(Theme.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous)).foregroundStyle(Theme.bg)
        }
    }

    /// Vorschau: was würde sich ändern
    private var preview: some View {
        let r = Restrictions.from(injuries: store.data.injuries + [draft], illness: store.data.illness)
        let removed = store.data.routines.flatMap { Strength.blockedItems($0, restrictions: r) }
        var seen = Set<String>()
        let unique = removed.filter { seen.insert($0.0.id).inserted }
        return VStack(alignment: .leading, spacing: 10) {
            Card {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Wird rausgenommen").font(.subheadline.weight(.bold))
                        Spacer()
                        Text("\(unique.count) Übungen").font(.footnote.weight(.heavy)).foregroundStyle(Theme.bad)
                    }
                    if unique.isEmpty {
                        Text("Keine deiner Übungen belastet diesen Bereich.").font(.footnote).foregroundStyle(Theme.soft)
                    }
                    ForEach(unique, id: \.0.id) { pair in
                        HStack {
                            Text(pair.0.name).strikethrough().foregroundStyle(Theme.muted)
                            Spacer()
                            Text(pair.1.map { "→ " + $0.name } ?? "entfällt").foregroundStyle(pair.1 == nil ? Theme.muted : Theme.accent)
                        }
                        .font(.footnote.weight(.semibold))
                    }
                }
            }
            Card {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Was weiterläuft").font(.subheadline.weight(.bold))
                    effectLine(ok: r.runAllowed && !r.runEasyOnly, text: runningText(r))
                    effectLine(ok: true, text: "Krafttraining für alle anderen Bereiche")
                    if draft.region == .shoulder {
                        effectLine(ok: true, text: "Reha: Außenrotation mit Band, nur schmerzfrei", plus: true)
                    }
                    if draft.region == .knee || draft.region == .achilles {
                        effectLine(ok: true, text: "Isometrisch: Wandsitzen bzw. Wadenheben langsam, nur schmerzfrei", plus: true)
                    }
                }
            }
        }
    }

    private func runningText(_ r: Restrictions) -> String {
        if !r.runAllowed { return "Laufen pausiert, stattdessen Rad oder Schwimmen" }
        if r.runEasyOnly { return "Nur lockere Läufe, keine Intervalle" }
        return "Laufplan unverändert"
    }

    private func effectLine(ok: Bool, text: String, plus: Bool = false) -> some View {
        HStack(spacing: 10) {
            Image(systemName: plus ? "plus.circle.fill" : ok ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(plus ? Theme.accent : ok ? Theme.good : Theme.warn)
            Text(text).font(.footnote)
        }
    }

    private var effects: some View {
        let r = store.restrictions
        return Hint(icon: "wand.and.stars", title: "Plan ist angepasst",
                    text: runningText(r) + ". Gesperrte Kraftübungen werden beim Start automatisch ersetzt.",
                    color: Theme.sleep)
    }

    // MARK: Krankheit

    @ViewBuilder private var illness: some View {
        if let ill = store.data.illness, ill.active {
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Krank seit \(Fmt.shortDay(ill.start))").font(.headline)
                        Spacer()
                        Badge(text: "AKTIV", color: Theme.bad)
                    }
                    Text(ill.fever || !ill.aboveNeckOnly
                         ? "Fieber oder Symptome unterhalb des Halses: Alle Einheiten sind pausiert."
                         : "Nur Schnupfen oder Halskratzen: Lockere, kurze Einheiten sind okay, wenn du dich gut fühlst.")
                        .font(.footnote).foregroundStyle(Theme.soft)
                    Toggle("Fieber", isOn: Binding(get: { ill.fever }, set: { v in store.update { $0.illness?.fever = v }; refresh() }))
                    Toggle("Nur über dem Hals (Schnupfen, Hals)", isOn: Binding(get: { ill.aboveNeckOnly }, set: { v in store.update { $0.illness?.aboveNeckOnly = v }; refresh() }))
                    Button {
                        store.update { $0.illness?.resolved = .now }
                        refresh()
                    } label: {
                        Text("Gesund melden").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(Theme.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous)).foregroundStyle(Theme.bg)
                    }
                }
            }
            Hint(icon: "arrow.up.right", title: "Danach: sanfter Wiedereinstieg",
                 text: "Nach dem Gesundmelden gibt es drei Tage nur lockere Läufe. Intervalle kommen erst wieder, wenn Ruhepuls und Erholung normal sind.",
                 color: Theme.sleep)
        } else {
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Krankheitsmodus").font(.headline)
                    Text("Harte Einheiten werden pausiert, der Plan verschiebt sich und Erinnerungen bleiben stumm. Faustregel: Symptome nur über dem Hals, dann locker möglich. Fieber oder Gliederschmerzen, dann Pause.")
                        .font(.footnote).foregroundStyle(Theme.soft)
                    Button {
                        store.update { $0.illness = Illness(start: .now, aboveNeckOnly: true, fever: false) }
                        refresh()
                    } label: {
                        Text("Ich bin krank").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(Theme.bad.opacity(0.85), in: RoundedRectangle(cornerRadius: 14, style: .continuous)).foregroundStyle(Theme.bg)
                    }
                }
            }
            if let last = store.data.illness, let res = last.resolved {
                Text("Zuletzt krank: \(Fmt.shortDay(last.start)) bis \(Fmt.shortDay(res))").font(.caption).foregroundStyle(Theme.muted).padding(.horizontal, 4)
            }
        }
    }

    private func refresh() {
        guard store.data.plan != nil else { return }
        let rec = model.recoveryToday
        let workouts = model.workouts
        let r = store.restrictions
        store.update { d in
            if var p = d.plan {
                PlanAdapter.adapt(&p, workouts: workouts, recovery: rec, restrictions: r)
                d.plan = p
            }
        }
        WidgetBridge.update(model: model, store: store)
    }
}

/// Einfache Körperskizze zum Antippen
struct BodyPicker: View {
    @Binding var selected: BodyRegion

    private let spots: [(BodyRegion, CGPoint)] = [
        (.neck, CGPoint(x: 0.5, y: 0.15)), (.shoulder, CGPoint(x: 0.3, y: 0.21)), (.upperBack, CGPoint(x: 0.5, y: 0.27)),
        (.elbow, CGPoint(x: 0.2, y: 0.38)), (.wrist, CGPoint(x: 0.15, y: 0.5)), (.lowerBack, CGPoint(x: 0.5, y: 0.45)),
        (.hip, CGPoint(x: 0.38, y: 0.52)), (.knee, CGPoint(x: 0.4, y: 0.72)), (.achilles, CGPoint(x: 0.6, y: 0.88)),
        (.ankle, CGPoint(x: 0.4, y: 0.9)), (.foot, CGPoint(x: 0.38, y: 0.97)),
    ]

    var body: some View {
        HStack(spacing: 14) {
            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                ZStack {
                    BodyShape().stroke(Theme.muted.opacity(0.6), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    ForEach(spots, id: \.0) { spot in
                        let isSel = spot.0 == selected
                        Button { selected = spot.0 } label: {
                            Circle().fill(isSel ? Theme.bad : Theme.muted.opacity(0.35))
                                .frame(width: isSel ? 16 : 11, height: isSel ? 16 : 11)
                                .background(Circle().fill(Theme.bad.opacity(isSel ? 0.25 : 0)).frame(width: 34, height: 34))
                                .frame(width: 34, height: 34)
                                .contentShape(Circle())
                        }
                        .buttonStyle(.press)
                        .accessibilityLabel(spot.0.label)
                        .position(x: spot.1.x * w, y: spot.1.y * h)
                    }
                }
            }
            .frame(width: 120, height: 220)
            VStack(alignment: .leading, spacing: 6) {
                Text("BEREICH").font(.caption.weight(.heavy)).foregroundStyle(Theme.muted)
                Text(selected.label).font(.title3.weight(.heavy))
                FlowChips(selected: $selected)
            }
        }
        .padding(14)
        .background(CardBackground(radius: 22))
    }
}

struct FlowChips: View {
    @Binding var selected: BodyRegion

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 6)], alignment: .leading, spacing: 6) {
            ForEach(BodyRegion.allCases) { r in
                Button { selected = r } label: {
                    Text(r.label).font(.caption.weight(.bold)).lineLimit(1).minimumScaleFactor(0.8)
                        .padding(.horizontal, 8).padding(.vertical, 7).frame(maxWidth: .infinity)
                        .background(r == selected ? Theme.bad.opacity(0.18) : Theme.card2, in: Capsule())
                        .overlay(Capsule().stroke(r == selected ? Theme.bad : .clear, lineWidth: 1.2))
                        .foregroundStyle(r == selected ? Theme.bad : Theme.text)
                }
                .buttonStyle(.press)
            }
        }
    }
}

struct BodyShape: Shape {
    func path(in r: CGRect) -> Path {
        let w = r.width, h = r.height
        var p = Path()
        p.addEllipse(in: CGRect(x: w * 0.4, y: h * 0.0, width: w * 0.2, height: h * 0.11))
        p.move(to: CGPoint(x: w * 0.5, y: h * 0.11)); p.addLine(to: CGPoint(x: w * 0.5, y: h * 0.16))
        p.move(to: CGPoint(x: w * 0.3, y: h * 0.2))
        p.addQuadCurve(to: CGPoint(x: w * 0.7, y: h * 0.2), control: CGPoint(x: w * 0.5, y: h * 0.15))
        p.addLine(to: CGPoint(x: w * 0.66, y: h * 0.5)); p.addLine(to: CGPoint(x: w * 0.34, y: h * 0.5)); p.closeSubpath()
        p.move(to: CGPoint(x: w * 0.3, y: h * 0.21)); p.addLine(to: CGPoint(x: w * 0.2, y: h * 0.38)); p.addLine(to: CGPoint(x: w * 0.15, y: h * 0.52))
        p.move(to: CGPoint(x: w * 0.7, y: h * 0.21)); p.addLine(to: CGPoint(x: w * 0.8, y: h * 0.38)); p.addLine(to: CGPoint(x: w * 0.85, y: h * 0.52))
        p.move(to: CGPoint(x: w * 0.4, y: h * 0.5)); p.addLine(to: CGPoint(x: w * 0.4, y: h * 0.72)); p.addLine(to: CGPoint(x: w * 0.4, y: h * 0.92)); p.addLine(to: CGPoint(x: w * 0.33, y: h * 0.97))
        p.move(to: CGPoint(x: w * 0.6, y: h * 0.5)); p.addLine(to: CGPoint(x: w * 0.6, y: h * 0.72)); p.addLine(to: CGPoint(x: w * 0.6, y: h * 0.92)); p.addLine(to: CGPoint(x: w * 0.67, y: h * 0.97))
        return p
    }
}
