import SwiftUI
import Charts

struct HealthView: View {
    @Environment(AppModel.self) private var model
    @Environment(DataStore.self) private var store

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if model.usingDemo { DemoBanner() }
                    hero
                    alerts
                    SectionHeader("Bereiche")
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        tile("Schlaf", "bed.double.fill", Theme.sleep,
                             model.lastNight.map { Fmt.hm($0.asleep) + " h" } ?? "–",
                             model.lastNight.map { "Score \(model.sleepScore($0))" } ?? "keine Daten") { SleepView() }
                        tile("Schlafplan", "alarm.fill", Theme.sleep,
                             model.sleepPlan.map { Fmt.time($0.bedtime) } ?? "–",
                             model.sleepPlan.map { "Wecker \(Fmt.time($0.wake))" } ?? "ins Bett") { SleepPlanView() }
                        tile("Vitalwerte", "waveform.path.ecg", Theme.good,
                             model.today?.hrv.map { Fmt.num($0) + " ms" } ?? "–",
                             outsideText) { VitalsView() }
                        tile("Belastung", "flame.fill", Theme.warn,
                             Fmt.num(model.strainToday, 1),
                             "Ziel \(Int(Analytics.strainTarget(model.recoveryToday).lowerBound))–\(Int(Analytics.strainTarget(model.recoveryToday).upperBound))") { StrainDetailView() }
                        tile("Stress", "brain.head.profile", Theme.warn,
                             model.stressToday.map { Fmt.num($0.current ?? $0.average ?? 0, 1) } ?? "–",
                             model.stressToday.map { StressDay.label($0.current ?? $0.average ?? 0) } ?? "keine Daten") { StressView() }
                        tile("Form-Alter", "hourglass", Theme.accent,
                             model.healthspan.map { Fmt.num($0.formAge, 1) } ?? "–",
                             model.healthspan.map { $0.delta <= 0 ? "\(Fmt.num(abs($0.delta), 1)) J jünger" : "\(Fmt.num($0.delta, 1)) J älter" } ?? "Jahre") { HealthspanView() }
                        if model.female {
                            tile("Zyklus", "circle.dotted.circle", Color(hex: 0xFF8AB8),
                                 model.cycle.map { "Tag \($0.day)" } ?? "–",
                                 model.cycle?.phase.label ?? "keine Daten") { CycleView() }
                        }
                        tile("Gewicht", "scalemass.fill", Theme.soft,
                             (model.weights.last?.value ?? model.weightKg).map { Fmt.num($0, 1) + " kg" } ?? "–",
                             weightTrend) { MetricDetailView(kind: .weight) }
                        tile("Journal", "book.closed.fill", Theme.sleep,
                             "\(store.data.journal.count)", "Tage eingetragen") {
                            JournalView(day: Calendar.current.addDays(-1, to: Calendar.current.startOfDay(for: .now)))
                        }
                        tile("Nicht fit?", store.restrictions.isEmpty ? "figure.walk" : "bandage.fill",
                             store.restrictions.isEmpty ? Theme.good : Theme.bad,
                             store.restrictions.isEmpty ? "Alles fit" : "\(store.restrictions.allReasons.count) aktiv",
                             store.restrictions.isEmpty ? "Verletzung, Krankheit" : store.restrictions.allReasons.joined(separator: ", ")) { InjuryView() }
                    }
                    SectionHeader("Letzte Tage")
                    recentDays
                    SectionHeader("Alle Messwerte")
                    AllMetricsCard()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .screenBackground(model.recoveryToday?.color ?? Theme.accent)
            .refreshable { await model.load() }
            .navigationTitle("Körper")
        }
    }

    // MARK: Kopf

    @ViewBuilder private var hero: some View {
        if let r = model.recoveryToday {
            NavigationLink { DayDetailView(day: .now) } label: {
                HStack(spacing: 16) {
                    ZStack {
                        Ring(progress: Double(r.score) / 100, color: r.color, lineWidth: 10)
                        Text("\(r.score)").font(.system(size: 30, weight: .heavy)).contentTransition(.numericText())
                    }
                    .frame(width: 88, height: 88)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ERHOLUNG HEUTE").font(.caption.weight(.heavy)).foregroundStyle(Theme.muted)
                        Text(r.label).font(.headline).foregroundStyle(r.color)
                        Text(r.text).font(.footnote).foregroundStyle(Theme.soft).multilineTextAlignment(.leading).lineLimit(2)
                    }
                    Spacer(minLength: 0)
                    Chevron()
                }
                .padding(18)
                .background(CardBackground(radius: 24, tint: r.color))
            }
            .buttonStyle(.press)
        }
    }

    /// Nur, wenn etwas auffällig ist
    @ViewBuilder private var alerts: some View {
        let outside = model.vitals.filter(\.outside)
        if outside.count >= 2 {
            NavigationLink { VitalsView() } label: {
                Hint(icon: "exclamationmark.triangle.fill", title: "\(outside.count) Werte außerhalb deines Bereichs",
                     text: outside.map(\.name).joined(separator: ", ") + ". Oft vor einem Infekt, nach Alkohol oder bei Schlafmangel. Heute lieber locker.",
                     color: Theme.warn)
            }
            .buttonStyle(.press)
        }
        if let t = model.hrvTrend, t.state == .below {
            NavigationLink { MetricDetailView(kind: .hrv) } label: {
                Hint(icon: "waveform.path.ecg", title: "HRV-Trend unter deinem Bereich",
                     text: "7-Tage-Schnitt \(Fmt.num(t.rolling7)) ms. Der Plan setzt harte Einheiten aus, bis er zurück ist.", color: Theme.warn)
            }
            .buttonStyle(.press)
        }
    }

    private var outsideText: String {
        let v = model.vitals
        if v.isEmpty { return "keine Daten" }
        let o = v.filter(\.outside).count
        return o == 0 ? "alle im Bereich" : "\(o) auffällig"
    }

    private var weightTrend: String {
        let w = model.weights
        guard w.count >= 4, let last = w.last else { return "Verlauf" }
        let from = Calendar.current.addDays(-30, to: last.date)
        let old = w.filter { $0.date >= from }
        guard old.count >= 2, let first = old.first else { return "Verlauf" }
        let d = last.value - first.value
        return (d >= 0 ? "+" : "−") + Fmt.num(abs(d), 1) + " kg in 30 T"
    }

    private func tile<D: View>(_ title: String, _ icon: String, _ color: Color, _ value: String, _ note: String,
                               @ViewBuilder destination: @escaping () -> D) -> some View {
        NavigationLink { destination() } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon).font(.subheadline.weight(.bold)).foregroundStyle(Theme.bg)
                        .frame(width: 32, height: 32)
                        .background(color, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    Spacer()
                    Chevron()
                }
                Text(title).font(.subheadline.weight(.bold)).lineLimit(1)
                Text(value).font(.title3.weight(.heavy)).lineLimit(1).minimumScaleFactor(0.7).contentTransition(.numericText())
                Text(note).font(.caption2).foregroundStyle(Theme.muted).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(CardBackground(radius: 20))
        }
        .buttonStyle(.press)
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
