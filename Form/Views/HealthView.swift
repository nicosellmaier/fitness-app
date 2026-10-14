import SwiftUI
import Charts

struct HealthView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if model.usingDemo { DemoBanner() }
                    sleepCard
                    SectionHeader("Trends", trailing: "30 Tage")
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                        TrendTile(title: "HRV", unit: "ms", points: model.series(\.hrv), color: Theme.good, digits: 0, higherIsBetter: true)
                        TrendTile(title: "Ruhepuls", unit: "bpm", points: model.series(\.rhr), color: Theme.good, digits: 0, higherIsBetter: false)
                        TrendTile(title: "VO2max", unit: "", points: model.vo2, color: Theme.accent, digits: 1, higherIsBetter: true)
                        TrendTile(title: "Atemfrequenz", unit: "/min", points: model.series(\.resp), color: Theme.sleep, digits: 1, higherIsBetter: nil)
                    }
                    SectionHeader("Recovery-Verlauf", trailing: "14 Tage")
                    recoveryChart
                    warning
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .screenBackground()
            .refreshable { await model.load() }
            .navigationTitle("Gesundheit")
        }
    }

    @ViewBuilder private var sleepCard: some View {
        if let n = model.lastNight {
            NavigationLink { SleepView() } label: {
                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("LETZTE NACHT").font(.caption.weight(.heavy)).foregroundStyle(Theme.muted)
                                Text(Fmt.hm(n.asleep) + " h").font(.title.weight(.heavy))
                                Text("\(Fmt.time(n.bedTime)) – \(Fmt.time(n.end)) · \(Int(n.efficiency * 100)) % Effizienz")
                                    .font(.footnote).foregroundStyle(Theme.muted)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("Score").font(.caption.weight(.semibold)).foregroundStyle(Theme.muted)
                                Text("\(model.sleepScore(n))").font(.title.weight(.heavy)).foregroundStyle(Theme.sleep)
                            }
                        }
                        StageBar(night: n).frame(height: 12)
                        HStack {
                            ForEach([SleepStage.deep, .core, .rem, .awake]) { s in
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(s.label).font(.caption2.weight(.semibold)).foregroundStyle(s.color)
                                    Text(Fmt.hm(n.time(s))).font(.footnote.weight(.heavy))
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        let need = model.needTonight
                        if need.weeklyDebt > 1800 {
                            Text("Schlafschuld der Woche: \(Fmt.hm(need.weeklyDebt)) h. Heute Nacht \(Fmt.hm(need.total)) h einplanen.")
                                .font(.caption).foregroundStyle(Theme.soft)
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Theme.card2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var recoveryChart: some View {
        let start = max(0, model.days.count - 14)
        let pts: [(Date, Int)] = (start..<model.days.count).compactMap { i in
            model.recovery(at: i).map { (model.days[i].day, $0.score) }
        }
        return Card {
            if pts.isEmpty {
                Text("Noch zu wenig Daten.").font(.footnote).foregroundStyle(Theme.soft)
            } else {
                Chart(pts, id: \.0) { p in
                    BarMark(x: .value("Tag", p.0, unit: .day), y: .value("Erholung", p.1))
                        .foregroundStyle(p.1 >= 67 ? Theme.good : p.1 >= 34 ? Theme.warn : Theme.bad)
                        .cornerRadius(4)
                }
                .chartYScale(domain: 0...100)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 2)) { _ in
                        AxisValueLabel(format: .dateTime.day())
                    }
                }
                .frame(height: 130)
            }
        }
    }

    @ViewBuilder private var warning: some View {
        if let t = model.today, let i = model.days.indices.last {
            let rb = Analytics.baseline(model.days, before: i, \.rhr)
            let tb = Analytics.baseline(model.days, before: i, \.temp)
            let rhrHigh = (t.rhr ?? 0) - (rb?.mean ?? 999) > 4
            let tempHigh = (t.temp ?? 0) - (tb?.mean ?? 999) > 0.5
            if rhrHigh && tempHigh {
                Hint(icon: "exclamationmark.triangle.fill", title: "Frühwarnung",
                     text: "Ruhepuls und Temperatur sind gleichzeitig erhöht. Heute lieber locker oder Ruhetag, und beobachte, ob du krank wirst.",
                     color: Theme.warn)
            } else {
                Hint(icon: "checkmark.shield.fill", title: "Keine Auffälligkeiten",
                     text: "Steigen Ruhepuls und Temperatur gleichzeitig, warnt dich die App, bevor du dich krank fühlst.",
                     color: Theme.good)
            }
        }
    }
}

struct TrendTile: View {
    let title: String
    let unit: String
    let points: [Point]
    let color: Color
    let digits: Int
    let higherIsBetter: Bool?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(Theme.muted)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(points.last.map { Fmt.num($0.value, digits) } ?? "–").font(.title3.weight(.heavy))
                if !unit.isEmpty { Text(unit).font(.caption).foregroundStyle(Theme.muted) }
            }
            if points.count > 1 {
                Chart(points) { p in
                    LineMark(x: .value("Tag", p.date), y: .value(title, p.value))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(color)
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(height: 36)
            }
            Text(trendText).font(.caption.weight(.bold)).foregroundStyle(trendColor)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var change: Double? {
        guard points.count >= 6 else { return nil }
        let half = points.count / 2
        let a = points.prefix(half).map(\.value), b = points.suffix(half).map(\.value)
        return b.reduce(0, +) / Double(b.count) - a.reduce(0, +) / Double(a.count)
    }

    private var trendText: String {
        guard let c = change else { return "zu wenig Daten" }
        if abs(c) < 0.5 * pow(10, -Double(digits)) * 2 { return "stabil" }
        return (c > 0 ? "steigend" : "fallend") + " (" + (c > 0 ? "+" : "−") + Fmt.num(abs(c), digits) + ")"
    }

    private var trendColor: Color {
        guard let c = change, let up = higherIsBetter else { return Theme.muted }
        return (c > 0) == up ? Theme.good : Theme.warn
    }
}
