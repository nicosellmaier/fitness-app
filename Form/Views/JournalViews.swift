import SwiftUI

/// Erinnerung auf "Heute": gestrigen Tag eintragen
struct JournalPromptCard: View {
    @Environment(DataStore.self) private var store

    var body: some View {
        let yesterday = Calendar.current.addDays(-1, to: Calendar.current.startOfDay(for: .now))
        let key = JournalBehavior.key(yesterday)
        if store.data.journal[key] == nil {
            NavigationLink { JournalView(day: yesterday) } label: {
                HStack(spacing: 12) {
                    Image(systemName: "book.closed.fill").font(.title3.weight(.bold)).foregroundStyle(Theme.bg)
                        .frame(width: 44, height: 44).background(Theme.sleep, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Journal für gestern").font(.subheadline.weight(.bold))
                        Text("30 Sekunden. Daraus lernt die App, was deine Erholung beeinflusst.").font(.caption).foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(Theme.muted)
                }
                .padding(14)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }
}

struct JournalCard: View {
    @Environment(DataStore.self) private var store
    @Environment(AppModel.self) private var model

    var body: some View {
        let insights = JournalAnalysis.insights(journal: store.data.journal, behaviors: store.data.behaviors, recoveryByDay: model.recoveryByDay)
        NavigationLink { JournalView(day: Calendar.current.addDays(-1, to: Calendar.current.startOfDay(for: .now))) } label: {
            Card {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Journal").font(.headline)
                        Spacer()
                        Text("\(store.data.journal.count) Tage").font(.caption.weight(.semibold)).foregroundStyle(Theme.muted)
                        Image(systemName: "chevron.right").foregroundStyle(Theme.muted)
                    }
                    if let top = insights.first(where: \.significant) ?? insights.first {
                        Text("\(top.label): Erholung \(top.diff >= 0 ? "+" : "−")\(Fmt.num(abs(top.diff))) Punkte am nächsten Morgen")
                            .font(.subheadline.weight(.semibold)).foregroundStyle(top.diff >= 0 ? Theme.good : Theme.warn)
                    } else {
                        Text("Nach je 5 Tagen mit und ohne ein Verhalten zeigt die App, wie es deine Erholung verändert.")
                            .font(.footnote).foregroundStyle(Theme.soft)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct JournalView: View {
    @Environment(DataStore.self) private var store
    @Environment(AppModel.self) private var model
    @State var day: Date
    @State private var showAdd = false
    @State private var newLabel = ""

    var body: some View {
        let key = JournalBehavior.key(day)
        let answers = store.data.journal[key] ?? [:]
        let insights = JournalAnalysis.insights(journal: store.data.journal, behaviors: store.data.behaviors, recoveryByDay: model.recoveryByDay)
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Button { day = Calendar.current.addDays(-1, to: day) } label: { Image(systemName: "chevron.left").frame(width: 40, height: 34) }
                    Spacer()
                    Text(Calendar.current.isDateInYesterday(day) ? "Gestern" : Calendar.current.isDateInToday(day) ? "Heute" : Fmt.shortDay(day))
                        .font(.headline)
                    Spacer()
                    Button { day = Calendar.current.addDays(1, to: day) } label: { Image(systemName: "chevron.right").frame(width: 40, height: 34) }
                        .disabled(Calendar.current.isDateInToday(day))
                }
                .foregroundStyle(Theme.text)

                VStack(spacing: 0) {
                    ForEach(store.data.behaviors) { b in
                        HStack(spacing: 10) {
                            Image(systemName: b.icon).font(.footnote.weight(.bold)).foregroundStyle(Theme.sleep).frame(width: 22)
                            Text(b.question).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 8)
                            answerButton("Nein", selected: answers[b.id] == false) { set(b.id, false, key) }
                            answerButton("Ja", selected: answers[b.id] == true) { set(b.id, true, key) }
                        }
                        .padding(.vertical, 9)
                        if b.id != store.data.behaviors.last?.id { Divider().overlay(Theme.line) }
                    }
                }
                .padding(.horizontal, 14)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))

                Button { showAdd = true } label: {
                    Label("Eigenes Verhalten hinzufügen", systemImage: "plus").font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                SectionHeader("Was deine Erholung beeinflusst")
                if insights.isEmpty {
                    Card {
                        Text("Sobald ein Verhalten mindestens 5-mal mit Ja und 5-mal mit Nein beantwortet ist, vergleicht die App deine Erholung am Morgen danach. Je mehr Tage, desto genauer.")
                            .font(.footnote).foregroundStyle(Theme.soft)
                    }
                } else {
                    VStack(spacing: 0) {
                        ForEach(insights) { i in
                            InsightRow(insight: i)
                            if i.id != insights.last?.id { Divider().overlay(Theme.line) }
                        }
                    }
                    .padding(.horizontal, 14)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    Text("Balken: Unterschied der Erholung am Morgen nach einem Ja gegenüber einem Nein, mit 95-%-Vertrauensbereich. Liegt der Bereich ganz auf einer Seite, ist der Effekt bei dir ziemlich sicher. Zusammenhang heißt nicht automatisch Ursache.")
                        .font(.caption).foregroundStyle(Theme.muted).padding(.horizontal, 4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
        }
        .screenBackground()
        .navigationTitle("Journal")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Eigenes Verhalten", isPresented: $showAdd) {
            TextField("z.B. Magnesium genommen", text: $newLabel)
            Button("Hinzufügen") { addCustom() }
            Button("Abbrechen", role: .cancel) { newLabel = "" }
        }
    }

    private func answerButton(_ t: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(t).font(.caption.weight(.bold)).frame(width: 46).padding(.vertical, 7)
                .background(selected ? (t == "Ja" ? Theme.accent : Theme.muted) : Theme.card2, in: Capsule())
                .foregroundStyle(selected ? Theme.bg : Theme.text)
        }
        .buttonStyle(.plain)
    }

    private func set(_ id: String, _ v: Bool, _ key: String) {
        store.update { d in
            var a = d.journal[key] ?? [:]
            if a[id] == v { a[id] = nil } else { a[id] = v }
            d.journal[key] = a.isEmpty ? nil : a
        }
    }

    private func addCustom() {
        let label = newLabel.trimmingCharacters(in: .whitespaces)
        newLabel = ""
        guard !label.isEmpty else { return }
        let b = JournalBehavior(id: "c_" + UUID().uuidString.prefix(8), label: label, icon: "star", question: label + "?", custom: true)
        store.update { $0.customBehaviors.append(b) }
    }
}

struct InsightRow: View {
    let insight: JournalInsight

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(insight.label).font(.subheadline.weight(.semibold))
                Spacer()
                Text((insight.diff >= 0 ? "+" : "−") + Fmt.num(abs(insight.diff)) + " Punkte")
                    .font(.subheadline.weight(.heavy)).foregroundStyle(insight.significant ? (insight.diff >= 0 ? Theme.good : Theme.warn) : Theme.muted)
            }
            GeometryReader { geo in
                let scale: Double = 30
                let mid = geo.size.width / 2
                let x0 = mid + CGFloat(max(-scale, insight.low) / scale) * mid
                let x1 = mid + CGFloat(min(scale, insight.high) / scale) * mid
                let xd = mid + CGFloat(max(-scale, min(scale, insight.diff)) / scale) * mid
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.track).frame(height: 4)
                    Rectangle().fill(Theme.muted.opacity(0.6)).frame(width: 1, height: 12).offset(x: mid)
                    Capsule().fill((insight.diff >= 0 ? Theme.good : Theme.warn).opacity(0.5)).frame(width: max(2, x1 - x0), height: 6).offset(x: x0)
                    Circle().fill(insight.diff >= 0 ? Theme.good : Theme.warn).frame(width: 10, height: 10).offset(x: xd - 5)
                }
                .frame(height: 12)
            }
            .frame(height: 12)
            Text("\(insight.yes)× ja, \(insight.no)× nein").font(.caption2).foregroundStyle(Theme.muted)
        }
        .padding(.vertical, 10)
    }
}
