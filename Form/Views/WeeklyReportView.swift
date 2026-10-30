import SwiftUI
import Charts

struct WeeklyReportView: View {
    @Environment(AppModel.self) private var model
    @Environment(DataStore.self) private var store
    @State private var span = 7
    @State private var back = 0

    private var report: PeriodReport {
        let end = Calendar.current.addDays(-back * span, to: .now)
        return Reports.make(model: model, store: store, days: span, endingAt: end)
    }

    var body: some View {
        let r = report
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Zeitraum", selection: $span) {
                    Text("Woche").tag(7)
                    Text("Monat").tag(30)
                    Text("Jahr").tag(365)
                }
                .pickerStyle(.segmented)
                .sensoryFeedback(.selection, trigger: span)
                .onChange(of: span) { _, _ in back = 0 }
                rangeRow(r)
                summaryCard(r)
                recoveryCard(r)
                scatterCard(r)
                sleepCard(r)
                trainingCard(r)
                if r.nutritionDays > 0 { nutritionCard(r) }
                if span == 365 { yearCard(r) }
                ShareLink(item: shareText(r)) {
                    Label("Bericht teilen", systemImage: "square.and.arrow.up").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(CardBackground(radius: 16)).foregroundStyle(Theme.text)
                }
                .buttonStyle(.press)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
            .animation(.snappy, value: span)
            .animation(.snappy, value: back)
        }
        .screenBackground(Theme.good)
        .navigationTitle(span == 7 ? "Wochenbericht" : span == 30 ? "Monatsbericht" : "Jahresrückblick")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func rangeRow(_ r: PeriodReport) -> some View {
        HStack {
            Button { back += 1 } label: { Image(systemName: "chevron.left").font(.headline).frame(width: 40, height: 40).background(CardBackground(radius: 12)) }
                .buttonStyle(.press)
            Spacer()
            Text("\(Fmt.shortDay(r.from)) bis \(Fmt.shortDay(r.to))").font(.subheadline.weight(.semibold))
            Spacer()
            Button { back = max(0, back - 1) } label: { Image(systemName: "chevron.right").font(.headline).frame(width: 40, height: 40).background(CardBackground(radius: 12)) }
                .buttonStyle(.press)
                .disabled(back == 0).opacity(back == 0 ? 0.35 : 1)
        }
        .foregroundStyle(Theme.text)
    }

    // MARK: Zusammenfassung

    private func summaryCard(_ r: PeriodReport) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Das Wichtigste").font(.headline)
            if r.highlights.isEmpty {
                Text("Für diesen Zeitraum gibt es noch zu wenig Daten.").font(.footnote).foregroundStyle(Theme.soft)
            }
            ForEach(r.highlights, id: \.self) { h in
                HStack(alignment: .top, spacing: 8) {
                    Circle().fill(Theme.good).frame(width: 6, height: 6).padding(.top, 6)
                    Text(h).font(.footnote).foregroundStyle(Theme.soft).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CardBackground(radius: 22, tint: Theme.good))
    }

    // MARK: Erholung

    private func recoveryCard(_ r: PeriodReport) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Erholung").font(.headline)
                    Spacer()
                    if let a = r.recoveryAvg {
                        Text("Ø \(Fmt.num(a))").font(.title3.weight(.heavy))
                        if let p = r.recoveryPrev { delta(a - p, digits: 0, up: true) }
                    }
                }
                HStack(spacing: 6) {
                    pill("\(r.greenDays) grün", Theme.good)
                    pill("\(r.yellowDays) gelb", Theme.warn)
                    pill("\(r.redDays) rot", Theme.bad)
                }
                if !r.strainDays.isEmpty {
                    Chart(r.strainDays, id: \.0) { d in
                        if let s = d.2 {
                            BarMark(x: .value("Tag", d.0, unit: span > 60 ? .weekOfYear : .day), y: .value("Erholung", s))
                                .foregroundStyle(s >= 67 ? Theme.good : s >= 34 ? Theme.warn : Theme.bad).cornerRadius(3)
                        }
                    }
                    .chartYScale(domain: 0...100)
                    .chartXAxis { AxisMarks(values: .automatic(desiredCount: 5)) { _ in AxisValueLabel(format: .dateTime.day().month(.defaultDigits)) } }
                    .frame(height: 110)
                }
                HStack {
                    if let b = r.bestDay { miniStat("Bester Tag", "\(b.1)", Fmt.shortDay(b.0), Theme.good) }
                    if let w = r.worstDay { miniStat("Schwächster", "\(w.1)", Fmt.shortDay(w.0), Theme.bad) }
                    if let h = r.hrvAvg { miniStat("HRV Ø", Fmt.num(h) + " ms", r.hrvPrev.map { "davor \(Fmt.num($0))" } ?? "", Theme.good) }
                    if let h = r.rhrAvg { miniStat("Ruhepuls Ø", Fmt.num(h), r.rhrPrev.map { "davor \(Fmt.num($0))" } ?? "", Theme.bad) }
                }
            }
        }
    }

    // MARK: Belastung gegen Erholung

    private func scatterCard(_ r: PeriodReport) -> some View {
        let pts = r.strainDays.compactMap { d -> (Date, Double, Int)? in d.2.map { (d.0, d.1, $0) } }
        let over = pts.filter { $0.2 < 34 && $0.1 > 14 }.count
        let under = pts.filter { $0.2 >= 67 && $0.1 < 8 }.count
        return Card {
            VStack(alignment: .leading, spacing: 10) {
                Text("Belastung gegen Erholung").font(.headline)
                if pts.count < 3 {
                    Text("Nach ein paar Tagen zeigt sich hier, ob du an guten Tagen hart und an schlechten locker trainierst.").font(.footnote).foregroundStyle(Theme.soft)
                } else {
                    Chart {
                        RectangleMark(xStart: .value("a", 0), xEnd: .value("b", 100), yStart: .value("c", 0), yEnd: .value("d", 21))
                            .foregroundStyle(.clear)
                        RuleMark(x: .value("x", 34)).foregroundStyle(Theme.line)
                        RuleMark(x: .value("x", 67)).foregroundStyle(Theme.line)
                        RuleMark(y: .value("y", 10)).foregroundStyle(Theme.line)
                        RuleMark(y: .value("y", 14)).foregroundStyle(Theme.line)
                        ForEach(pts, id: \.0) { p in
                            PointMark(x: .value("Erholung", p.2), y: .value("Belastung", p.1))
                                .foregroundStyle(p.2 >= 67 ? Theme.good : p.2 >= 34 ? Theme.warn : Theme.bad)
                                .symbolSize(70)
                        }
                    }
                    .chartXScale(domain: 0...100)
                    .chartYScale(domain: 0...21)
                    .chartXAxisLabel("Erholung", alignment: .center)
                    .chartYAxisLabel("Belastung")
                    .frame(height: 180)
                    Text(over > 0 ? "\(over) Tage hart trainiert bei roter Erholung. Das sind die Tage, an denen Verletzungen und Infekte entstehen."
                         : under > 1 ? "\(under) grüne Tage kaum genutzt. An solchen Tagen darf es hart sein."
                         : "Gute Passung: hart an grünen Tagen, locker an roten. Oben rechts ist das Ziel, oben links die Gefahr.")
                        .font(.caption).foregroundStyle(Theme.soft)
                }
            }
        }
    }

    // MARK: Schlaf

    private func sleepCard(_ r: PeriodReport) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Schlaf").font(.headline)
                    Spacer()
                    if let s = r.sleepAvg {
                        Text("Ø \(Fmt.hm(s)) h").font(.title3.weight(.heavy))
                        if let p = r.sleepPrev { Text((s - p >= 0 ? "+" : "−") + Fmt.hm(abs(s - p))).font(.caption.weight(.bold)).foregroundStyle(s >= p ? Theme.good : Theme.warn) }
                    }
                }
                if let s = r.sleepAvg {
                    Bar(fraction: s / max(1, r.sleepNeed), color: Theme.sleep)
                    Text("\(Int(s / max(1, r.sleepNeed) * 100)) % deines Bedarfs von \(Fmt.hm(r.sleepNeed)) h").font(.caption).foregroundStyle(Theme.muted)
                }
                HStack {
                    if let c = r.sleepConsistency {
                        miniStat("Regelmäßigkeit", "±\(Int(c)) min", c < 30 ? "sehr gut" : c < 60 ? "gut" : "schwankend", c < 60 ? Theme.good : Theme.warn)
                    }
                    miniStat("Schlafschuld", Fmt.hm(r.sleepDebt) + " h", "14 Nächte", r.sleepDebt > 3600 ? Theme.warn : Theme.good)
                }
                if let c = r.sleepConsistency, c >= 45 {
                    Divider().overlay(Theme.line)
                    Label("Wochenziel: Schlafmitte auf ±30 Minuten bringen. Feste Aufstehzeit, auch am Wochenende, ist der einfachste Weg.", systemImage: "target")
                        .font(.caption).foregroundStyle(Theme.sleep)
                }
            }
        }
    }

    // MARK: Training

    private func trainingCard(_ r: PeriodReport) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Training").font(.headline)
                    Spacer()
                    Text("Belastung Ø \(Fmt.num(r.strainAvg, 1))").font(.subheadline.weight(.heavy)).foregroundStyle(Theme.warn)
                    if r.strainPrev > 0 { delta(r.strainAvg - r.strainPrev, digits: 1, up: nil) }
                }
                HStack {
                    miniStat("Läufe", "\(r.runCount)", Fmt.num(r.runKm, 1) + " km", Theme.accent)
                    miniStat("Kraft", "\(r.strengthSessions.count)", Fmt.num(r.strengthVolume / 1000, 1) + " t", Theme.warn)
                    miniStat("Aktiv", Fmt.num(r.exerciseMinutes) , "Minuten", Theme.good)
                    if let s = r.steps { miniStat("Schritte Ø", Fmt.num(s), "pro Tag", Theme.accent) }
                }
                if r.planDone + r.planMissed > 0 {
                    Divider().overlay(Theme.line)
                    HStack(spacing: 6) {
                        pill("\(r.planDone) erledigt", Theme.good)
                        if r.planMissed > 0 { pill("\(r.planMissed) verpasst", Theme.bad) }
                        if r.planAdjusted > 0 { pill("\(r.planAdjusted) angepasst", Theme.sleep) }
                        Spacer()
                        Text("Plan").font(.caption).foregroundStyle(Theme.muted)
                    }
                }
                if !r.workouts.isEmpty && span == 7 {
                    Divider().overlay(Theme.line)
                    ForEach(r.workouts) { w in
                        NavigationLink { WorkoutDetailView(item: w) } label: {
                            HStack {
                                Image(systemName: w.icon).foregroundStyle(w.kind.color).frame(width: 24)
                                Text(w.name).font(.footnote.weight(.semibold))
                                Spacer()
                                Text(Fmt.shortDay(w.start)).font(.caption).foregroundStyle(Theme.muted)
                                Text(Fmt.clock(w.duration)).font(.caption.weight(.bold))
                                Chevron()
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.press)
                    }
                }
            }
        }
    }

    private func nutritionCard(_ r: PeriodReport) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Text("Ernährung").font(.headline)
                HStack {
                    miniStat("Kalorien Ø", Fmt.num(r.kcalAvg ?? 0), "pro Tag", Theme.accent)
                    miniStat("Eiweiß Ø", Fmt.num(r.proteinAvg ?? 0) + " g", "pro Tag", Theme.good)
                    miniStat("Getrackt", "\(r.nutritionDays)", "von \(r.days) Tagen", Theme.soft)
                }
            }
        }
    }

    private func yearCard(_ r: PeriodReport) -> some View {
        let km = r.runKm
        let hours = r.workouts.reduce(0) { $0 + $1.duration } / 3600
        let longest = r.workouts.filter { $0.activity == .running }.max { ($0.distance ?? 0) < ($1.distance ?? 0) }
        return VStack(alignment: .leading, spacing: 12) {
            Text("Dein Jahr in Zahlen").font(.title3.weight(.heavy))
            HStack(spacing: 8) {
                StatTile(title: "Kilometer", value: Fmt.num(km), note: km > 0 ? "≈ \(Fmt.num(km / 42.195, 1)) Marathons" : nil)
                StatTile(title: "Stunden aktiv", value: Fmt.num(hours), note: "\(r.workouts.count) Workouts")
            }
            HStack(spacing: 8) {
                StatTile(title: "Kraft", value: Fmt.num(r.strengthVolume / 1000), unit: "t", note: "\(r.strengthSessions.count) Einheiten")
                StatTile(title: "Längster Lauf", value: longest.map { Fmt.km($0.distance ?? 0) } ?? "–", note: longest.map { Fmt.shortDay($0.start) })
            }
            HStack(spacing: 8) {
                StatTile(title: "Grüne Tage", value: "\(r.greenDays)", note: "\(r.redDays) rote")
                StatTile(title: "Schlaf gesamt", value: Fmt.num(((r.sleepAvg ?? 0) * Double(r.days)) / 3600), unit: "h", note: "≈ \(Int(((r.sleepAvg ?? 0) * Double(r.days)) / 86400)) Tage")
            }
        }
        .padding(16)
        .background(CardBackground(radius: 22, tint: Theme.accent))
    }

    // MARK: Helfer

    private func pill(_ t: String, _ c: Color) -> some View {
        Text(t).font(.caption2.weight(.heavy)).foregroundStyle(c).padding(.horizontal, 8).padding(.vertical, 4).background(c.opacity(0.14), in: Capsule())
    }

    private func miniStat(_ t: String, _ v: String, _ sub: String, _ c: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(t).font(.caption2).foregroundStyle(Theme.muted).lineLimit(1)
            Text(v).font(.subheadline.weight(.heavy)).foregroundStyle(c).lineLimit(1).minimumScaleFactor(0.7)
            Text(sub).font(.caption2).foregroundStyle(Theme.muted).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func delta(_ d: Double, digits: Int, up: Bool?) -> some View {
        let color: Color = up == nil ? Theme.muted : ((d >= 0) == up! ? Theme.good : Theme.warn)
        return Text((d >= 0 ? "+" : "−") + Fmt.num(abs(d), digits)).font(.caption.weight(.bold)).foregroundStyle(color)
    }

    private func shareText(_ r: PeriodReport) -> String {
        var s = "Form, \(r.label) \(Fmt.shortDay(r.from)) bis \(Fmt.shortDay(r.to))\n\n"
        s += r.highlights.map { "• " + $0 }.joined(separator: "\n")
        return s
    }
}
