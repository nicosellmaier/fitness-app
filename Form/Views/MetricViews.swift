import SwiftUI
import Charts

// MARK: Detailseite für einen Messwert

struct MetricDetailView: View {
    @Environment(AppModel.self) private var model
    let kind: MetricKind
    @State private var range = 30
    @State private var selected: Date?

    private let ranges = [(7, "7 T"), (30, "30 T"), (90, "90 T"), (365, "1 J")]

    var body: some View {
        let all = model.points(kind)
        let from = Calendar.current.addDays(-(range - 1), to: Calendar.current.startOfDay(for: .now))
        let pts = all.filter { $0.date >= from }
        let shown = range > 90 ? weekly(pts) : pts
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                header(all: all, pts: pts)
                Picker("Zeitraum", selection: $range) {
                    ForEach(ranges, id: \.0) { Text($0.1).tag($0.0) }
                }
                .pickerStyle(.segmented)
                .sensoryFeedback(.selection, trigger: range)
                chartCard(shown, raw: pts)
                statsGrid(pts)
                if range >= 30, pts.count >= 14 { weekdayCard(pts) }
                aboutCard
                if !pts.isEmpty { dailyList(pts) }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
            .animation(.snappy, value: range)
        }
        .screenBackground(kind.color)
        .navigationTitle(kind.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Kopf

    private func header(all: [Point], pts: [Point]) -> some View {
        let last = all.last
        let mean = pts.isEmpty ? nil : pts.map(\.value).reduce(0, +) / Double(pts.count)
        return HStack(alignment: .center, spacing: 14) {
            Image(systemName: kind.icon).font(.title2.weight(.bold)).foregroundStyle(Theme.bg)
                .frame(width: 54, height: 54)
                .background(LinearGradient(colors: [kind.color, kind.color.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: RoundedRectangle(cornerRadius: 17, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(last.map { kind.format($0.value) } ?? "–").font(.system(size: 38, weight: .heavy)).monospacedDigit()
                        .contentTransition(.numericText())
                    if !kind.unit.isEmpty { Text(kind.unit).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.muted) }
                }
                if let last {
                    Text(lastText(last, mean: mean)).font(.footnote.weight(.semibold)).foregroundStyle(deltaColor(last.value - (mean ?? last.value)))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 6)
    }

    private func lastText(_ p: Point, mean: Double?) -> String {
        let cal = Calendar.current
        let when = cal.isDateInToday(p.date) ? "Heute" : cal.isDateInYesterday(p.date) ? "Gestern" : Fmt.shortDay(p.date)
        guard let mean, abs(p.value - mean) > 0 else { return when }
        let d = p.value - mean
        return when + " · " + (d >= 0 ? "+" : "−") + kind.format(abs(d)) + " vs. Ø \(rangeLabel)"
    }

    private var rangeLabel: String { range == 365 ? "1 Jahr" : "\(range) Tage" }

    private func deltaColor(_ d: Double) -> Color {
        guard let up = kind.higherIsBetter, abs(d) > 0 else { return Theme.muted }
        return (d > 0) == up ? Theme.good : Theme.warn
    }

    // MARK: Diagramm

    private func chartCard(_ pts: [Point], raw: [Point]) -> some View {
        let mean = raw.isEmpty ? 0 : raw.map(\.value).reduce(0, +) / Double(raw.count)
        let sel = selected.flatMap { s in pts.min { abs($0.date.timeIntervalSince(s)) < abs($1.date.timeIntervalSince(s)) } }
        return Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    if let sel {
                        VStack(alignment: .leading, spacing: 1) {
                            Text((range > 90 ? "Woche ab " : "") + Fmt.shortDay(sel.date)).font(.caption.weight(.semibold)).foregroundStyle(Theme.muted)
                            Text(kind.format(sel.value) + " " + kind.unit).font(.headline.weight(.heavy)).foregroundStyle(kind.color)
                                .contentTransition(.numericText())
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Ø \(rangeLabel)").font(.caption.weight(.semibold)).foregroundStyle(Theme.muted)
                            Text(raw.isEmpty ? "–" : kind.format(mean) + " " + kind.unit).font(.headline.weight(.heavy))
                        }
                    }
                    Spacer()
                    Text("Gedrückt halten und ziehen").font(.caption2).foregroundStyle(Theme.muted)
                }
                if pts.isEmpty {
                    Text("Für diesen Zeitraum gibt es noch keine Daten.").font(.footnote).foregroundStyle(Theme.soft)
                        .frame(maxWidth: .infinity, minHeight: 160)
                } else {
                    chart(pts, mean: mean, sel: sel).frame(height: 190)
                }
            }
        }
    }

    @ChartContentBuilder
    private func marks(_ pts: [Point], sel: Point?, floor: Double) -> some ChartContent {
        let unit: Calendar.Component = range > 90 ? .weekOfYear : .day
        ForEach(pts) { p in
            if kind.bars {
                BarMark(x: .value("Tag", p.date, unit: unit), y: .value(kind.title, p.value))
                    .foregroundStyle(barColor(p).opacity(sel == nil || sel?.id == p.id ? 1 : 0.35))
                    .cornerRadius(3)
            } else {
                AreaMark(x: .value("Tag", p.date), yStart: .value("Basis", floor), yEnd: .value(kind.title, p.value))
                    .foregroundStyle(LinearGradient(colors: [kind.color.opacity(0.28), kind.color.opacity(0)], startPoint: .top, endPoint: .bottom))
                    .interpolationMethod(.catmullRom)
                LineMark(x: .value("Tag", p.date), y: .value(kind.title, p.value))
                    .foregroundStyle(kind.color)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .interpolationMethod(.catmullRom)
            }
        }
    }

    private func chart(_ pts: [Point], mean: Double, sel: Point?) -> some View {
        let lo = pts.map(\.value).min() ?? 0, hi = pts.map(\.value).max() ?? 1
        let pad = max((hi - lo) * 0.15, kind == .temp ? 0.1 : 1)
        let domain: ClosedRange<Double> = kind.bars ? 0...(hi * 1.1 + 0.001) : (lo - pad)...(hi + pad)
        return Chart {
            marks(pts, sel: sel, floor: domain.lowerBound)
            RuleMark(y: .value("Schnitt", mean))
                .foregroundStyle(Theme.soft.opacity(0.6))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .annotation(position: .top, alignment: .trailing) {
                    Text("Ø").font(.caption2.weight(.bold)).foregroundStyle(Theme.soft)
                }
            if let sel {
                RuleMark(x: .value("Auswahl", sel.date))
                    .foregroundStyle(Theme.text.opacity(0.35))
                if !kind.bars {
                    PointMark(x: .value("Tag", sel.date), y: .value(kind.title, sel.value))
                        .foregroundStyle(kind.color).symbolSize(90)
                }
            }
        }
        .chartYScale(domain: domain)
        .chartPlotStyle { $0.clipped() }
        .chartXSelection(value: $selected)
        .sensoryFeedback(.selection, trigger: sel?.id)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                AxisGridLine().foregroundStyle(Theme.line)
                AxisValueLabel(format: range > 30 ? .dateTime.month(.abbreviated).day() : .dateTime.day().month(.defaultDigits))
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine().foregroundStyle(Theme.line)
                AxisValueLabel()
            }
        }
    }

    private func barColor(_ p: Point) -> Color {
        switch kind {
        case .recovery: return p.value >= 67 ? Theme.good : p.value >= 34 ? Theme.warn : Theme.bad
        case .steps: return p.value >= 8000 ? Theme.accent : Theme.accent.opacity(0.55)
        case .sleep: return p.value >= 7 ? Theme.sleep : Theme.sleep.opacity(0.55)
        default: return kind.color
        }
    }

    private func weekly(_ pts: [Point]) -> [Point] {
        let cal = Calendar.current
        let groups = Dictionary(grouping: pts) { cal.dateInterval(of: .weekOfYear, for: $0.date)?.start ?? $0.date }
        return groups.map { Point(date: $0.key, value: $0.value.map(\.value).reduce(0, +) / Double($0.value.count)) }
            .sorted { $0.date < $1.date }
    }

    // MARK: Kennzahlen

    private func statsGrid(_ pts: [Point]) -> some View {
        let v = pts.map(\.value)
        let mean = v.isEmpty ? nil : v.reduce(0, +) / Double(v.count)
        let change: Double? = {
            guard v.count >= 6 else { return nil }
            let h = v.count / 2
            return v.suffix(h).reduce(0, +) / Double(h) - v.prefix(h).reduce(0, +) / Double(h)
        }()
        let maxP = pts.max { $0.value < $1.value }, minP = pts.min { $0.value < $1.value }
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
            StatTile(title: "Schnitt", value: mean.map { kind.format($0) } ?? "–", unit: kind.unit)
            StatTile(title: "Höchster", value: maxP.map { kind.format($0.value) } ?? "–", unit: "",
                     note: maxP.map { Fmt.shortDay($0.date) })
            StatTile(title: "Tiefster", value: minP.map { kind.format($0.value) } ?? "–", unit: "",
                     note: minP.map { Fmt.shortDay($0.date) })
            StatTile(title: "Trend", value: change.map { ($0 >= 0 ? "+" : "−") + kind.format(abs($0)) } ?? "–", unit: "",
                     note: change == nil ? "zu wenig Daten" : "2. vs. 1. Hälfte", noteColor: change.map(deltaColor) ?? Theme.muted)
            StatTile(title: "Tage mit Daten", value: "\(pts.count)", unit: "/\(range)")
            StatTile(title: "Streuung", value: spread(v).map { kind.format($0) } ?? "–", unit: "",
                     note: "Standardabw.")
        }
    }

    private func spread(_ v: [Double]) -> Double? {
        guard v.count >= 3 else { return nil }
        let m = v.reduce(0, +) / Double(v.count)
        return sqrt(v.map { ($0 - m) * ($0 - m) }.reduce(0, +) / Double(v.count - 1))
    }

    // MARK: Wochentage

    private func weekdayCard(_ pts: [Point]) -> some View {
        let cal = Calendar.current
        let order = [2, 3, 4, 5, 6, 7, 1]
        let names = [2: "Mo", 3: "Di", 4: "Mi", 5: "Do", 6: "Fr", 7: "Sa", 1: "So"]
        let groups = Dictionary(grouping: pts) { cal.component(.weekday, from: $0.date) }
        let avg: [(String, Double)] = order.compactMap { wd in
            guard let g = groups[wd], !g.isEmpty else { return nil }
            return (names[wd] ?? "", g.map(\.value).reduce(0, +) / Double(g.count))
        }
        let best = avg.max { a, b in kind.higherIsBetter == false ? a.1 > b.1 : a.1 < b.1 }
        return Card {
            VStack(alignment: .leading, spacing: 10) {
                Text("Nach Wochentag").font(.headline)
                Chart(avg, id: \.0) { a in
                    BarMark(x: .value("Tag", a.0), y: .value(kind.title, a.1))
                        .foregroundStyle(a.0 == best?.0 ? kind.color : kind.color.opacity(0.4))
                        .cornerRadius(4)
                        .annotation(position: .top) {
                            Text(kind.format(a.1)).font(.system(size: 9, weight: .bold)).foregroundStyle(Theme.soft)
                        }
                }
                .chartYAxis(.hidden)
                .chartYScale(domain: 0...((avg.map(\.1).max() ?? 1) * 1.2))
                .frame(height: 120)
                if let best, kind.higherIsBetter != nil {
                    Text("Bester Tag im Schnitt: \(best.0).").font(.footnote).foregroundStyle(Theme.soft)
                }
            }
        }
    }

    // MARK: Erklärung

    private var aboutCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Label("Was bedeutet das?", systemImage: "info.circle.fill").font(.headline).foregroundStyle(kind.color)
                Text(kind.about).font(.footnote).foregroundStyle(Theme.soft).fixedSize(horizontal: false, vertical: true)
                Divider().overlay(Theme.line)
                Text("So beeinflusst du es").font(.subheadline.weight(.bold))
                ForEach(kind.tips, id: \.self) { t in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill").font(.footnote).foregroundStyle(kind.color)
                        Text(t).font(.footnote).foregroundStyle(Theme.soft).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    // MARK: Tagesliste

    private func dailyList(_ pts: [Point]) -> some View {
        let mean = pts.map(\.value).reduce(0, +) / Double(pts.count)
        let rows = Array(pts.reversed().prefix(60))
        return VStack(alignment: .leading, spacing: 8) {
            SectionHeader("Einzelne Tage", trailing: pts.count > 60 ? "letzte 60" : nil)
            VStack(spacing: 0) {
                ForEach(rows) { p in
                    NavigationLink { DayDetailView(day: p.date) } label: {
                        HStack(spacing: 10) {
                            Text(Fmt.shortDay(p.date)).font(.subheadline)
                            Spacer()
                            let d = p.value - mean
                            Text((d >= 0 ? "+" : "−") + kind.format(abs(d))).font(.caption.weight(.bold)).foregroundStyle(deltaColor(d))
                            Text(kind.format(p.value) + (kind.unit.isEmpty ? "" : " " + kind.unit)).font(.subheadline.weight(.heavy)).monospacedDigit()
                                .frame(minWidth: 74, alignment: .trailing)
                            Chevron()
                        }
                        .padding(.vertical, 11)
                    }
                    .buttonStyle(.press)
                    if p.id != rows.last?.id { Divider().overlay(Theme.line) }
                }
            }
            .padding(.horizontal, 16)
            .background(CardBackground(radius: 20))
        }
    }
}

// MARK: Tagesansicht

struct DayDetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(DataStore.self) private var store
    @State var day: Date

    init(day: Date) { _day = State(initialValue: Calendar.current.startOfDay(for: day)) }

    private var cal: Calendar { Calendar.current }
    private var isToday: Bool { cal.isDateInToday(day) }
    private var index: Int? { model.days.firstIndex { cal.isDate($0.day, inSameDayAs: day) } }
    private var metrics: DayMetrics? { index.map { model.days[$0] } }
    private var night: SleepNight? { model.nights.last { cal.isDate($0.wakeDay, inSameDayAs: day) } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                dayPicker
                recoverySection
                vitalsSection
                sleepSection
                activitySection
                trainingSection
                nutritionSection
                journalSection
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
            .animation(.snappy, value: day)
        }
        .screenBackground(recovery?.color ?? Theme.accent)
        .navigationTitle(isToday ? "Heute" : Fmt.shortDay(day))
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.selection, trigger: day)
    }

    private var recovery: Recovery? {
        guard let i = index else { return nil }
        return i == model.days.count - 1 && isToday ? model.recoveryToday : model.recovery(at: i)
    }

    // MARK: Tag wählen

    private var dayPicker: some View {
        let first = model.days.first?.day ?? cal.addDays(-89, to: .now)
        return HStack {
            Button { day = cal.addDays(-1, to: day) } label: {
                Image(systemName: "chevron.left").font(.headline).frame(width: 44, height: 44)
                    .background(CardBackground(radius: 14))
            }
            .buttonStyle(.press)
            .disabled(day <= first)
            Spacer()
            VStack(spacing: 1) {
                Text(Fmt.day(day)).font(.headline).contentTransition(.numericText())
                Text(isToday ? "Heute" : cal.isDateInYesterday(day) ? "Gestern" : "vor \(cal.dateComponents([.day], from: day, to: cal.startOfDay(for: .now)).day ?? 0) Tagen")
                    .font(.caption).foregroundStyle(Theme.muted)
            }
            Spacer()
            Button { day = cal.addDays(1, to: day) } label: {
                Image(systemName: "chevron.right").font(.headline).frame(width: 44, height: 44)
                    .background(CardBackground(radius: 14))
            }
            .buttonStyle(.press)
            .disabled(isToday)
            .opacity(isToday ? 0.35 : 1)
        }
        .foregroundStyle(Theme.text)
    }

    // MARK: Erholung

    @ViewBuilder private var recoverySection: some View {
        if let r = recovery {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 16) {
                    ZStack {
                        Ring(progress: Double(r.score) / 100, color: r.color, lineWidth: 11)
                        Text("\(r.score)").font(.system(size: 30, weight: .heavy)).contentTransition(.numericText())
                    }
                    .frame(width: 92, height: 92)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ERHOLUNG").font(.caption.weight(.heavy)).foregroundStyle(Theme.muted)
                        Text(r.label).font(.headline).foregroundStyle(r.color)
                        Text(r.text).font(.footnote).foregroundStyle(Theme.soft).fixedSize(horizontal: false, vertical: true)
                    }
                }
                if !r.parts.isEmpty {
                    Divider().overlay(Theme.line)
                    Text("So setzt sich der Wert zusammen").font(.subheadline.weight(.bold))
                    HStack {
                        Text("Ausgangswert").font(.footnote).foregroundStyle(Theme.soft)
                        Spacer()
                        Text("55").font(.footnote.weight(.heavy)).monospacedDigit()
                    }
                    ForEach(r.parts) { p in PartRow(part: p) }
                }
                NavigationLink { MetricDetailView(kind: .recovery) } label: {
                    HStack { Text("Erholung im Verlauf").font(.footnote.weight(.bold)); Spacer(); Chevron() }
                        .foregroundStyle(r.color)
                }
                .buttonStyle(.press)
            }
            .padding(18)
            .background(CardBackground(radius: 24, tint: r.color))
        } else {
            Hint(icon: "moon.zzz", title: "Keine Erholung für diesen Tag", text: "Für diesen Tag fehlen Schlaf- oder HRV-Daten.", color: Theme.muted)
        }
    }

    // MARK: Vitalwerte

    @ViewBuilder private var vitalsSection: some View {
        let kinds: [MetricKind] = [.hrv, .rhr, .resp, .spo2, .temp]
        let rows = kinds.compactMap { k in model.value(k, on: day).map { (k, $0) } }
        if !rows.isEmpty {
            SectionHeader("Vitalwerte", trailing: "vs. 30 Tage davor")
            VStack(spacing: 0) {
                ForEach(rows, id: \.0) { k, v in
                    NavigationLink { MetricDetailView(kind: k) } label: {
                        VitalRow(kind: k, value: v, base: model.baseline(k, before: day))
                    }
                    .buttonStyle(.press)
                    if k != rows.last?.0 { Divider().overlay(Theme.line) }
                }
            }
            .padding(.horizontal, 16)
            .background(CardBackground(radius: 20))
        }
    }

    // MARK: Schlaf

    @ViewBuilder private var sleepSection: some View {
        if let n = night {
            SectionHeader("Schlaf", trailing: "Score \(model.sleepScore(n))")
            NavigationLink { MetricDetailView(kind: .sleep) } label: {
                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(Fmt.hm(n.asleep) + " h").font(.title2.weight(.heavy))
                            Text("\(Fmt.time(n.bedTime)) – \(Fmt.time(n.end))").font(.footnote).foregroundStyle(Theme.muted)
                            Spacer()
                            Chevron()
                        }
                        StageBar(night: n).frame(height: 10)
                        HStack {
                            ForEach([SleepStage.deep, .core, .rem, .awake]) { s in
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(s.label).font(.caption2.weight(.semibold)).foregroundStyle(s.color)
                                    Text(Fmt.hm(n.time(s))).font(.footnote.weight(.heavy))
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        HStack(spacing: 14) {
                            mini("Effizienz", "\(Int(n.efficiency * 100)) %")
                            mini("Eingeschlafen", "\(Int(n.latency / 60)) min")
                            mini("Wach", "\(n.awakenings.count)×")
                        }
                    }
                }
            }
            .buttonStyle(.press)
        }
    }

    private func mini(_ t: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(t).font(.caption2).foregroundStyle(Theme.muted)
            Text(v).font(.footnote.weight(.bold))
        }
    }

    // MARK: Aktivität

    private var activitySection: some View {
        let strain = model.strain(on: day)
        let steps = model.value(.steps, on: day)
        let ex = model.value(.exercise, on: day)
        return VStack(alignment: .leading, spacing: 8) {
            SectionHeader("Aktivität")
            HStack(spacing: 8) {
                NavigationLink { StrainDetailView() } label: {
                    StatTile(title: "Belastung", value: Fmt.num(strain.score, 1), unit: "/21",
                             note: strain.muscular > 0 ? "inkl. Kraft" : nil, noteColor: Theme.warn)
                }
                .buttonStyle(.press)
                NavigationLink { MetricDetailView(kind: .steps) } label: {
                    StatTile(title: "Schritte", value: steps.map { Fmt.num($0) } ?? "–", note: (steps ?? 0) >= 8000 ? "Ziel erreicht" : nil, noteColor: Theme.good)
                }
                .buttonStyle(.press)
                NavigationLink { MetricDetailView(kind: .exercise) } label: {
                    StatTile(title: "Training", value: ex.map { Fmt.num($0) } ?? "–", unit: "min")
                }
                .buttonStyle(.press)
            }
            if strain.total > 0 {
                HStack(spacing: 8) {
                    Text("Herz-Kreislauf").font(.caption).foregroundStyle(Theme.muted)
                    Bar(fraction: strain.cardio / max(1, strain.total), color: Theme.warn, height: 6)
                    Text("Muskeln").font(.caption).foregroundStyle(Theme.muted)
                }
                .padding(.horizontal, 4)
            }
        }
    }

    // MARK: Training

    @ViewBuilder private var trainingSection: some View {
        let ws = model.workouts.filter { cal.isDate($0.start, inSameDayAs: day) }.sorted { $0.start < $1.start }
        let ss = store.data.sessions.filter { cal.isDate($0.start, inSameDayAs: day) }
        if !ws.isEmpty || !ss.isEmpty {
            SectionHeader("Training", trailing: "\(ws.count + ss.count)")
            VStack(spacing: 0) {
                ForEach(ws) { w in
                    NavigationLink { WorkoutDetailView(item: w) } label: {
                        HStack(spacing: 12) {
                            Image(systemName: w.icon).font(.headline).foregroundStyle(Theme.accent).frame(width: 30)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(w.name).font(.subheadline.weight(.bold))
                                Text("\(Fmt.time(w.start)) · \(Fmt.clock(w.duration))" + (w.distance.map { " · " + Fmt.km($0) } ?? ""))
                                    .font(.caption).foregroundStyle(Theme.muted)
                            }
                            Spacer()
                            if let hr = w.avgHR { Text("\(Int(hr)) bpm").font(.caption.weight(.bold)).foregroundStyle(Theme.bad) }
                            Chevron()
                        }
                        .padding(.vertical, 11)
                    }
                    .buttonStyle(.press)
                    Divider().overlay(Theme.line)
                }
                ForEach(ss) { s in
                    NavigationLink { SessionDetailView(session: s) } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "dumbbell.fill").font(.headline).foregroundStyle(Theme.warn).frame(width: 30)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(s.name).font(.subheadline.weight(.bold))
                                Text("\(Fmt.time(s.start)) · \(s.doneSets) Sätze · \(Fmt.num(s.volume)) kg Volumen").font(.caption).foregroundStyle(Theme.muted)
                            }
                            Spacer()
                            Chevron()
                        }
                        .padding(.vertical, 11)
                    }
                    .buttonStyle(.press)
                    Divider().overlay(Theme.line)
                }
            }
            .padding(.horizontal, 16)
            .background(CardBackground(radius: 20))
        }
    }

    // MARK: Ernährung

    @ViewBuilder private var nutritionSection: some View {
        let es = store.data.entries.filter { cal.isDate($0.date, inSameDayAs: day) }
        if !es.isEmpty {
            let kcal = es.map(\.kcal).reduce(0, +), p = es.map(\.protein).reduce(0, +)
            let c = es.map(\.carbs).reduce(0, +), f = es.map(\.fat).reduce(0, +)
            SectionHeader("Ernährung", trailing: "\(es.count) Einträge")
            HStack(spacing: 8) {
                StatTile(title: "Kalorien", value: Fmt.num(kcal), unit: "kcal")
                StatTile(title: "Eiweiß", value: Fmt.num(p), unit: "g")
                StatTile(title: "KH / Fett", value: "\(Fmt.num(c)) / \(Fmt.num(f))", unit: "g")
            }
        }
    }

    // MARK: Journal

    @ViewBuilder private var journalSection: some View {
        let answers = store.data.journal[JournalBehavior.key(day)] ?? [:]
        if !answers.isEmpty {
            let list = store.data.behaviors.filter { answers[$0.id] != nil }
            SectionHeader("Journal")
            Card {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(list) { b in
                        HStack {
                            Text(b.label).font(.subheadline)
                            Spacer()
                            Image(systemName: answers[b.id] == true ? "checkmark.circle.fill" : "xmark.circle")
                                .foregroundStyle(answers[b.id] == true ? Theme.good : Theme.muted)
                        }
                    }
                }
            }
        }
    }
}

struct PartRow: View {
    let part: RecoveryPart

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(part.name).font(.footnote.weight(.bold))
                Text(part.detail).font(.caption2).foregroundStyle(Theme.muted)
            }
            Spacer()
            // Balken von der Mitte: links negativ, rechts positiv
            GeometryReader { geo in
                let w = geo.size.width / 2
                let f = min(1, abs(part.points) / 30)
                ZStack {
                    Capsule().fill(Theme.track)
                    HStack(spacing: 0) {
                        if part.points < 0 {
                            Spacer(minLength: 0)
                            Capsule().fill(Theme.bad).frame(width: w * f)
                            Color.clear.frame(width: w)
                        } else {
                            Color.clear.frame(width: w)
                            Capsule().fill(Theme.good).frame(width: w * f)
                            Spacer(minLength: 0)
                        }
                    }
                    Rectangle().fill(Theme.soft.opacity(0.5)).frame(width: 1)
                }
            }
            .frame(width: 80, height: 6)
            Text((part.points >= 0 ? "+" : "−") + Fmt.num(abs(part.points)))
                .font(.footnote.weight(.heavy)).monospacedDigit()
                .foregroundStyle(part.points >= 0 ? Theme.good : Theme.bad)
                .frame(width: 34, alignment: .trailing)
        }
    }
}

struct VitalRow: View {
    let kind: MetricKind
    let value: Double
    let base: (mean: Double, sd: Double)?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: kind.icon).font(.subheadline.weight(.bold)).foregroundStyle(kind.color).frame(width: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text(kind.title).font(.subheadline.weight(.bold))
                if let base { Text("Ø \(kind.format(base.mean)) \(kind.unit)").font(.caption).foregroundStyle(Theme.muted) }
            }
            Spacer()
            if let base {
                let z = (value - base.mean) / base.sd
                Text(z > 1 ? "erhöht" : z < -1 ? "niedrig" : "normal").font(.caption2.weight(.heavy))
                    .foregroundStyle(color(z))
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(color(z).opacity(0.14), in: Capsule())
            }
            Text(kind.format(value) + " " + kind.unit).font(.subheadline.weight(.heavy)).monospacedDigit()
            Chevron()
        }
        .padding(.vertical, 11)
    }

    private func color(_ z: Double) -> Color {
        guard abs(z) > 1 else { return Theme.good }
        guard let up = kind.higherIsBetter else { return Theme.warn }
        return (z > 0) == up ? Theme.good : Theme.warn
    }
}

// MARK: Alle Messwerte

struct AllMetricsCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 0) {
            let kinds = MetricKind.allCases.filter { !model.points($0).isEmpty }
            ForEach(kinds) { k in
                NavigationLink { MetricDetailView(kind: k) } label: { MetricListRow(kind: k, points: model.points(k)) }
                    .buttonStyle(.press)
                if k != kinds.last { Divider().overlay(Theme.line) }
            }
        }
        .padding(.horizontal, 14)
        .background(CardBackground(radius: 20))
    }
}

struct MetricListRow: View {
    let kind: MetricKind
    let points: [Point]

    var body: some View {
        let recent = Array(points.suffix(30))
        HStack(spacing: 12) {
            Image(systemName: kind.icon).font(.subheadline.weight(.bold)).foregroundStyle(Theme.bg)
                .frame(width: 32, height: 32)
                .background(kind.color, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(kind.title).font(.subheadline.weight(.bold)).lineLimit(1)
                Text(points.last.map { Fmt.shortDay($0.date) } ?? "").font(.caption2).foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 6)
            if recent.count > 2 {
                Chart(recent) { p in
                    LineMark(x: .value("Tag", p.date), y: .value(kind.title, p.value))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(kind.color)
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(width: 64, height: 24)
            }
            Text(points.last.map { kind.format($0.value) } ?? "–").font(.subheadline.weight(.heavy)).monospacedDigit()
                .frame(minWidth: 48, alignment: .trailing)
            Chevron()
        }
        .padding(.vertical, 10)
    }
}
