import SwiftUI
import Charts

struct CycleView: View {
    @Environment(AppModel.self) private var model
    @State private var logging = false
    @State private var logDay = Date()
    @State private var saved = false
    @State private var error: String?

    private let pink = Color(hex: 0xFF8AB8)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let c = model.cycle {
                    hero(c)
                    wheel(c)
                    phaseCard(c)
                    correctionCard
                    historyCard(c)
                } else {
                    empty
                }
                logButton
                Text("Die App liest Periodeneinträge aus Apple Health (Health-App → Zyklus, Apple Watch oder Apps wie Flo und Clue). Alles bleibt auf deinem iPhone und wird nie an den Coach geschickt.")
                    .font(.caption).foregroundStyle(Theme.muted).padding(.horizontal, 4)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
        }
        .screenBackground(pink)
        .navigationTitle("Zyklus")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $logging) { logSheet }
    }

    // MARK: Kopf

    private func hero(_ c: CycleState) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("ZYKLUSTAG").font(.caption.weight(.heavy)).foregroundStyle(Theme.muted)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(c.day)").font(.system(size: 40, weight: .heavy)).contentTransition(.numericText())
                        Text("von ~\(c.length)").font(.subheadline).foregroundStyle(Theme.muted)
                    }
                    Text(c.phase.label).font(.headline).foregroundStyle(c.phase.color)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    stat("Nächste Periode", c.phase == .late ? "überfällig" : "in \(c.daysToPeriod) T", Fmt.shortDay(c.nextPeriod))
                    stat("Eisprung ca.", c.ovulation > .now ? "in \(max(0, Calendar.current.dateComponents([.day], from: .now, to: c.ovulation).day ?? 0)) T" : "vorbei", Fmt.shortDay(c.ovulation))
                }
            }
            Label(c.phase.training, systemImage: "figure.run").font(.footnote.weight(.semibold)).foregroundStyle(c.phase.color)
        }
        .padding(18)
        .background(CardBackground(radius: 24, tint: c.phase.color))
    }

    private func stat(_ t: String, _ v: String, _ sub: String) -> some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text(t).font(.caption2).foregroundStyle(Theme.muted)
            Text(v).font(.subheadline.weight(.heavy))
            Text(sub).font(.caption2).foregroundStyle(Theme.muted)
        }
    }

    // MARK: Zyklusrad

    private func wheel(_ c: CycleState) -> some View {
        let segs: [(CyclePhase, Int, Int)] = {
            let ov = c.length - 14
            return [(.menstrual, 1, c.periodDays), (.follicular, c.periodDays + 1, ov - 2), (.ovulation, ov - 1, ov + 1),
                    (.luteal, ov + 2, c.length - 4), (.lateLuteal, c.length - 3, c.length)]
        }()
        return Card {
            VStack(alignment: .leading, spacing: 10) {
                Text("Dein Zyklus").font(.headline)
                GeometryReader { geo in
                    let w = geo.size.width
                    ZStack(alignment: .leading) {
                        HStack(spacing: 2) {
                            ForEach(segs, id: \.0) { s in
                                RoundedRectangle(cornerRadius: 4).fill(s.0.color.opacity(0.75))
                                    .frame(width: max(2, w * Double(max(0, s.2 - s.1 + 1)) / Double(c.length) - 2))
                            }
                        }
                        Capsule().fill(Theme.text).frame(width: 3, height: 26)
                            .offset(x: w * Double(min(c.day, c.length) - 1) / Double(c.length) + w / Double(c.length) / 2)
                    }
                }
                .frame(height: 18)
                HStack(spacing: 10) {
                    ForEach(segs, id: \.0) { s in
                        HStack(spacing: 4) {
                            Circle().fill(s.0.color).frame(width: 7, height: 7)
                            Text(s.0.label).font(.system(size: 10, weight: .semibold)).foregroundStyle(Theme.soft)
                        }
                    }
                }
            }
        }
    }

    // MARK: Phase

    private func phaseCard(_ c: CycleState) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Label(c.phase.label, systemImage: "info.circle.fill").font(.headline).foregroundStyle(c.phase.color)
                Text(c.phase.body).font(.footnote).foregroundStyle(Theme.soft).fixedSize(horizontal: false, vertical: true)
                Divider().overlay(Theme.line)
                Text("So nutzt die App das").font(.subheadline.weight(.bold))
                tip("Erholung und Gesundheitsmonitor rechnen den Zykluseffekt auf Temperatur, Ruhepuls und HRV heraus. Keine Fehlalarme in der Lutealphase.")
                tip("In den letzten 3 Tagen vor der Periode und an Tag 1 und 2 werden harte Laufeinheiten entschärft, wenn die Erholung nicht sehr gut ist.")
                tip("Der Coach kennt deine Phase und berücksichtigt sie bei Training und Essen.")
            }
        }
    }

    private func tip(_ t: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill").font(.footnote).foregroundStyle(pink)
            Text(t).font(.footnote).foregroundStyle(Theme.soft).fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Korrektur

    @ViewBuilder private var correctionCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Text("Dein Körper in der Lutealphase").font(.headline)
                if let k = model.cycleCorrection {
                    HStack(spacing: 8) {
                        StatTile(title: "Temperatur", value: "+" + Fmt.num(k.temp, 2), unit: "°C")
                        StatTile(title: "Ruhepuls", value: "+" + Fmt.num(k.rhr, 1), unit: "bpm")
                        StatTile(title: "HRV", value: Fmt.num(k.hrv, 1), unit: "ms")
                    }
                    Text("Gemessen über \(k.samples) Tage, verglichen mit deiner Follikelphase. Um diese Werte korrigiert die App Erholung und Monitor automatisch.")
                        .font(.caption).foregroundStyle(Theme.muted)
                } else {
                    Text("Nach etwa zwei vollständigen Zyklen mit Watch-Daten weiß die App, wie stark deine Werte in der zweiten Zyklushälfte steigen, und rechnet das heraus.")
                        .font(.footnote).foregroundStyle(Theme.soft)
                }
            }
        }
    }

    // MARK: Verlauf

    private func historyCard(_ c: CycleState) -> some View {
        let recs = Array(c.history.suffix(8).reversed())
        return Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Letzte Zyklen").font(.headline)
                    Spacer()
                    if let sd = c.regularity {
                        Text(sd <= 2 ? "sehr regelmäßig" : sd <= 4 ? "regelmäßig" : "schwankend")
                            .font(.caption.weight(.bold)).foregroundStyle(sd <= 4 ? Theme.good : Theme.warn)
                    }
                }
                Chart(recs.filter { $0.length != nil }) { r in
                    BarMark(x: .value("Start", Fmt.shortDay(r.start)), y: .value("Tage", r.length ?? 0))
                        .foregroundStyle(pink.opacity(0.8)).cornerRadius(4)
                        .annotation(position: .top) { Text("\(r.length ?? 0)").font(.system(size: 9, weight: .bold)).foregroundStyle(Theme.soft) }
                    RuleMark(y: .value("Schnitt", c.length)).foregroundStyle(Theme.soft.opacity(0.5)).lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }
                .chartYScale(domain: 15...45)
                .chartXAxis { AxisMarks { _ in AxisValueLabel().font(.system(size: 9)) } }
                .frame(height: 130)
                ForEach(recs) { r in
                    HStack {
                        Text(Fmt.shortDay(r.start)).font(.subheadline)
                        Spacer()
                        Text("\(r.periodDays) Tage Periode").font(.caption).foregroundStyle(Theme.muted)
                        Text(r.length.map { "\($0) Tage" } ?? "läuft").font(.subheadline.weight(.bold)).frame(minWidth: 60, alignment: .trailing)
                    }
                }
            }
        }
    }

    private var empty: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "circle.dotted.circle").font(.system(size: 30, weight: .bold)).foregroundStyle(pink)
                Text("Noch keine Zyklusdaten").font(.title3.weight(.heavy))
                Text("Trag deine Periode unten ein oder in der Health-App. Nach dem ersten Eintrag zeigt die App Phase, Prognose und passt Erholung und Plan an.")
                    .font(.footnote).foregroundStyle(Theme.soft)
            }
        }
    }

    // MARK: Eintragen

    private var logButton: some View {
        Button { logging = true } label: {
            Label("Periode eintragen", systemImage: "drop.fill").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(pink, in: RoundedRectangle(cornerRadius: 16, style: .continuous)).foregroundStyle(Theme.bg)
        }
        .buttonStyle(.press)
    }

    private var logSheet: some View {
        NavigationStack {
            SwiftUI.Form {
                Section {
                    DatePicker("Erster Tag", selection: $logDay, in: ...Date.now, displayedComponents: .date)
                } footer: {
                    Text("Trägt den Tag als Zyklusbeginn in Apple Health ein. Weitere Blutungstage kannst du in der Health-App ergänzen, für die Phase reicht der erste Tag.")
                }
                if let error { Text(error).foregroundStyle(Theme.bad).font(.footnote) }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("Periode eintragen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { logging = false } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        Task {
                            do {
                                if model.usingDemo {
                                    model.cycleRecords.append(CycleRecord(start: Calendar.current.startOfDay(for: logDay), length: nil, periodDays: 5))
                                } else {
                                    try await model.health.requestCycleWrite()
                                    try await model.health.logPeriod(day: logDay, cycleStart: true)
                                    await model.load()
                                }
                                logging = false
                            } catch { self.error = error.localizedDescription }
                        }
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
