import SwiftUI
import Charts

struct HealthView: View {
    @Environment(AppModel.self) private var model
    @Environment(DataStore.self) private var store

    @State private var showCoach = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if model.usingDemo { DemoBanner() }
                    sleepCard
                    HealthMonitorCard()
                    HRVTrendCard()
                    SectionHeader("Langfristig")
                    HealthspanCard()
                    SectionHeader("Alltag")
                    StressCard()
                    JournalCard()
                    SectionHeader("Trends", trailing: "30 Tage")
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                        ForEach(trendKinds) { k in
                            NavigationLink { MetricDetailView(kind: k) } label: {
                                TrendTile(title: k.title, unit: k.unit, points: Array(model.points(k).suffix(30)), color: k.color,
                                          digits: k.digits, higherIsBetter: k.higherIsBetter, format: k.format)
                            }
                            .buttonStyle(.press)
                        }
                    }
                    SectionHeader("Recovery-Verlauf", trailing: "14 Tage")
                    NavigationLink { MetricDetailView(kind: .recovery) } label: { recoveryChart }
                        .buttonStyle(.press)
                    SectionHeader("Letzte Tage")
                    recentDays
                    SectionHeader("Alle Messwerte")
                    AllMetricsCard()
                    SectionHeader("Verletzung & Krankheit")
                    injuryLink
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .screenBackground()
            .refreshable { await model.load() }
            .navigationTitle("Gesundheit")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showCoach = true } label: { Image(systemName: "sparkles") }
                        .accessibilityLabel("Coach")
                }
            }
            .sheet(isPresented: $showCoach) { CoachView() }
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
                            Text("Schlafschuld (14 Nächte): \(Fmt.hm(need.weeklyDebt)) h. Heute Nacht \(Fmt.hm(need.total)) h einplanen.")
                                .font(.caption).foregroundStyle(Theme.soft)
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Theme.card2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                }
            }
            .buttonStyle(.press)
        }
    }

    private var trendKinds: [MetricKind] {
        [.hrv, .rhr, .sleep, .vo2, .steps, .exercise, .resp, .weight].filter { !model.points($0).isEmpty }
    }

    /// Die letzten 7 Tage, jeweils zum Aufklappen
    private var recentDays: some View {
        let cal = Calendar.current
        let n = model.days.count
        let idx = Array((max(0, n - 7)..<n).reversed())
        return VStack(spacing: 0) {
            ForEach(idx, id: \.self) { i in
                let d = model.days[i]
                let r = i == n - 1 ? model.recoveryToday : model.recovery(at: i)
                NavigationLink { DayDetailView(day: d.day) } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Ring(progress: Double(r?.score ?? 0) / 100, color: r?.color ?? Theme.muted, lineWidth: 4)
                            Text(r.map { "\($0.score)" } ?? "–").font(.caption.weight(.heavy))
                        }
                        .frame(width: 38, height: 38)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(cal.isDateInToday(d.day) ? "Heute" : cal.isDateInYesterday(d.day) ? "Gestern" : Fmt.shortDay(d.day))
                                .font(.subheadline.weight(.bold))
                            Text([d.sleep.map { Fmt.hm($0.asleep) + " h Schlaf" }, d.hrv.map { "HRV " + Fmt.num($0) }]
                                .compactMap { $0 }.joined(separator: " · "))
                                .font(.caption).foregroundStyle(Theme.muted)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 1) {
                            Text(Fmt.num(model.strain(on: d.day).score, 1)).font(.subheadline.weight(.heavy)).foregroundStyle(Theme.warn)
                            Text("Belastung").font(.caption2).foregroundStyle(Theme.muted)
                        }
                        Chevron()
                    }
                    .padding(.vertical, 10)
                }
                .buttonStyle(.press)
                if i != idx.last { Divider().overlay(Theme.line) }
            }
        }
        .padding(.horizontal, 14)
        .background(CardBackground(radius: 20))
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

}

extension HealthView {
    var injuryLink: some View {
        let active = store.data.injuries.filter(\.active)
        let ill = store.data.illness?.active == true
        return NavigationLink { InjuryView() } label: {
            HStack(spacing: 12) {
                Image(systemName: active.isEmpty && !ill ? "figure.walk" : "bandage.fill").font(.title3.weight(.bold))
                    .foregroundStyle(active.isEmpty && !ill ? Theme.good : Theme.bad).frame(width: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(ill ? "Krankheitsmodus aktiv" : active.isEmpty ? "Alles fit" : active.map(\.title).joined(separator: ", "))
                        .font(.subheadline.weight(.bold))
                    Text(active.isEmpty && !ill ? "Verletzung oder Krankheit eintragen, Plan und Kraft passen sich an." : "Tippen zum Ändern oder Gesundmelden.")
                        .font(.caption).foregroundStyle(Theme.muted)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Theme.muted)
            }
            .padding(14)
            .background(CardBackground(radius: 20))
        }
        .buttonStyle(.press)
    }
}

struct TrendTile: View {
    let title: String
    let unit: String
    let points: [Point]
    let color: Color
    let digits: Int
    let higherIsBetter: Bool?
    var format: ((Double) -> String)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(.caption.weight(.semibold)).foregroundStyle(Theme.muted).lineLimit(1)
                Spacer(minLength: 0)
                Chevron()
            }
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(points.last.map { format?($0.value) ?? Fmt.num($0.value, digits) } ?? "–").font(.title3.weight(.heavy))
                    .contentTransition(.numericText())
                if !unit.isEmpty { Text(unit).font(.caption).foregroundStyle(Theme.muted) }
            }
            if points.count > 1 {
                Chart(points) { p in
                    LineMark(x: .value("Tag", p.date), y: .value(title, p.value))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(color)
                    AreaMark(x: .value("Tag", p.date), yStart: .value("min", lowest), yEnd: .value(title, p.value))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(LinearGradient(colors: [color.opacity(0.25), color.opacity(0)], startPoint: .top, endPoint: .bottom))
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
        .background(CardBackground(radius: 18))
    }

    private var lowest: Double { points.map(\.value).min() ?? 0 }

    private var change: Double? {
        guard points.count >= 6 else { return nil }
        let half = points.count / 2
        let a = points.prefix(half).map(\.value), b = points.suffix(half).map(\.value)
        return b.reduce(0, +) / Double(b.count) - a.reduce(0, +) / Double(a.count)
    }

    private var trendText: String {
        guard let c = change else { return "zu wenig Daten" }
        if abs(c) < 0.5 * pow(10, -Double(digits)) * 2 { return "stabil" }
        return (c > 0 ? "steigend" : "fallend") + " (" + (c > 0 ? "+" : "−") + (format?(abs(c)) ?? Fmt.num(abs(c), digits)) + ")"
    }

    private var trendColor: Color {
        guard let c = change, let up = higherIsBetter else { return Theme.muted }
        return (c > 0) == up ? Theme.good : Theme.warn
    }
}
