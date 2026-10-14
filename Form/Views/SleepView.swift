import SwiftUI
import Charts
import HealthKit

struct SleepView: View {
    @Environment(AppModel.self) private var model
    @State private var index: Int? = nil
    @State private var heart: [HRPoint] = []

    private var nights: [SleepNight] { model.nights }
    private var current: Int { index ?? max(0, nights.count - 1) }
    private var night: SleepNight? { nights.indices.contains(current) ? nights[current] : nil }
    private var day: DayMetrics? { night.flatMap { n in model.days.first { $0.day == n.wakeDay } } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let n = night {
                    header(n)
                    summary(n)
                    stages(n)
                    heartCard(n)
                    nightValues
                    SectionHeader("Heute Nacht")
                    tonight
                    SectionHeader("Regelmäßigkeit", trailing: "14 Nächte")
                    regularity
                } else {
                    Card { Text("Noch keine Schlafdaten.").foregroundStyle(Theme.soft) }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
        }
        .screenBackground()
        .navigationTitle("Schlaf")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: night?.id) { await loadHeart() }
    }

    private func header(_ n: SleepNight) -> some View {
        HStack {
            Button { index = max(0, current - 1) } label: { Image(systemName: "chevron.left").frame(width: 36, height: 36) }
                .disabled(current == 0)
                .accessibilityLabel("Vorherige Nacht")
            Spacer()
            Text("Nacht auf " + Fmt.day(n.wakeDay)).font(.subheadline.weight(.semibold))
            Spacer()
            Button { index = min(nights.count - 1, current + 1) } label: { Image(systemName: "chevron.right").frame(width: 36, height: 36) }
                .disabled(current >= nights.count - 1)
                .accessibilityLabel("Nächste Nacht")
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.text)
    }

    private func summary(_ n: SleepNight) -> some View {
        let score = model.sleepScore(n)
        let need = model.sleepBaseHours * 3600
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 16) {
                ZStack {
                    Ring(progress: Double(score) / 100, color: Theme.sleep, lineWidth: 11)
                    VStack(spacing: 0) {
                        Text("\(score)").font(.system(size: 30, weight: .heavy))
                        Text("Score").font(.caption2.weight(.bold)).foregroundStyle(Theme.muted)
                    }
                }
                .frame(width: 104, height: 104)
                VStack(alignment: .leading, spacing: 4) {
                    Text(Fmt.hm(n.asleep) + " h").font(.title.weight(.heavy))
                    Text("von \(Fmt.hm(need)) h Bedarf · \(Int(min(100, n.asleep / need * 100))) %")
                        .font(.footnote).foregroundStyle(Theme.muted)
                    Bar(fraction: n.asleep / need, color: Theme.sleep).padding(.top, 4)
                }
            }
            HStack(spacing: 6) {
                miniStat("Im Bett", Fmt.time(n.bedTime))
                miniStat("Eingeschlafen", "\(Int(n.latency / 60)) min")
                miniStat("Wach", "\(n.awakenings.count)× · \(Int(n.time(.awake) / 60)) min")
                miniStat("Effizienz", "\(Int(n.efficiency * 100)) %")
            }
        }
        .padding(18)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private func miniStat(_ t: String, _ v: String) -> some View {
        VStack(spacing: 2) {
            Text(t).font(.caption2.weight(.semibold)).foregroundStyle(Theme.muted).lineLimit(1).minimumScaleFactor(0.8)
            Text(v).font(.footnote.weight(.heavy)).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Theme.card2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func stages(_ n: SleepNight) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("Schlafphasen").font(.subheadline.weight(.bold))
                Chart(n.segments) { s in
                    RectangleMark(
                        xStart: .value("Start", s.start),
                        xEnd: .value("Ende", s.end),
                        y: .value("Phase", s.stage.label)
                    )
                    .foregroundStyle(s.stage.color)
                    .cornerRadius(3)
                }
                .chartYScale(domain: ["Wach", "REM", "Kern", "Tief"])
                .chartXAxis {
                    AxisMarks(values: .stride(by: .hour, count: 2)) { _ in
                        AxisGridLine().foregroundStyle(Theme.line)
                        AxisValueLabel(format: .dateTime.hour(.twoDigits(amPM: .omitted)).minute())
                    }
                }
                .frame(height: 150)

                let asleep = max(1, n.asleep)
                ForEach([SleepStage.deep, .core, .rem, .awake]) { st in
                    let t = n.time(st)
                    let share = st == .awake ? t / max(1, n.span) : t / asleep
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 3).fill(st.color).frame(width: 10, height: 10)
                        Text(stageName(st)).font(.footnote)
                        Spacer()
                        Text(Fmt.hm(t)).font(.footnote.weight(.heavy))
                        Text("\(Int((share * 100).rounded())) %")
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(stageOK(st, share) ? Theme.good : Theme.muted)
                            .frame(width: 48, alignment: .trailing)
                    }
                }
                if !n.hasStages {
                    Text("Diese Nacht hat keine Schlafphasen (z.B. ohne Watch aufgezeichnet).").font(.caption).foregroundStyle(Theme.muted)
                }
            }
        }
    }

    private func stageName(_ s: SleepStage) -> String {
        switch s {
        case .deep: return "Tiefschlaf"
        case .core: return "Kernschlaf"
        case .rem: return "REM"
        case .awake: return "Wach"
        }
    }

    private func stageOK(_ s: SleepStage, _ share: Double) -> Bool {
        switch s {
        case .deep: return share >= 0.13 && share <= 0.25
        case .rem: return share >= 0.18 && share <= 0.28
        default: return false
        }
    }

    private func heartCard(_ n: SleepNight) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Puls im Schlaf").font(.subheadline.weight(.bold))
                    Spacer()
                    if let m = heart.min(by: { $0.bpm < $1.bpm }) {
                        Text("Tiefster Wert \(Fmt.time(m.date))").font(.caption).foregroundStyle(Theme.muted)
                    }
                }
                if heart.isEmpty {
                    Text("Keine Pulsdaten für diese Nacht.").font(.footnote).foregroundStyle(Theme.soft)
                } else {
                    Chart(heart) { p in
                        LineMark(x: .value("Zeit", p.date), y: .value("Puls", p.bpm))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(Theme.bad)
                    }
                    .chartYScale(domain: .automatic(includesZero: false))
                    .chartXAxis(.hidden)
                    .frame(height: 90)
                    let v = heart.map(\.bpm)
                    HStack {
                        StatInline(title: "Minimum", value: "\(Int(v.min() ?? 0)) bpm")
                        StatInline(title: "Ø Nacht", value: "\(Int(v.reduce(0, +) / Double(v.count))) bpm")
                        StatInline(title: "Maximum", value: "\(Int(v.max() ?? 0)) bpm")
                    }
                }
            }
        }
    }

    @ViewBuilder private var nightValues: some View {
        let idx = model.days.firstIndex { $0.day == night?.wakeDay } ?? max(0, model.days.count - 1)
        let d = day
        VStack(spacing: 0) {
            let hb = Analytics.baseline(model.days, before: idx, \.hrv)
            MetricRow(title: "HRV nachts", subtitle: hb.map { "Basis \(Fmt.num($0.mean)) ms" },
                      value: d?.hrv.map { Fmt.num($0) + " ms" } ?? "–",
                      badge: badge(d?.hrv, hb, higherIsBetter: true))
            Divider().overlay(Theme.line)
            let rb = Analytics.baseline(model.days, before: idx, \.resp)
            MetricRow(title: "Atemfrequenz", subtitle: rb.map { "Basis \(Fmt.num($0.mean, 1)) /min" },
                      value: d?.resp.map { Fmt.num($0, 1) + " /min" } ?? "–",
                      badge: badge(d?.resp, rb, higherIsBetter: false))
            Divider().overlay(Theme.line)
            MetricRow(title: "Blutsauerstoff", subtitle: "Spanne der Nacht",
                      value: d?.spo2.map { s in "\(Int(((d?.spo2Min ?? s) * 100).rounded()))–\(Int((s * 100).rounded()) + 1) %" } ?? "–",
                      badge: d?.spo2.map { $0 >= 0.94 ? ("NORMAL", Theme.good) : ("NIEDRIG", Theme.warn) })
            Divider().overlay(Theme.line)
            let tb = Analytics.baseline(model.days, before: idx, \.temp)
            MetricRow(title: "Handgelenk-Temperatur", subtitle: "zur Basis",
                      value: tempText(d?.temp, tb?.mean),
                      badge: tempBadge(d?.temp, tb?.mean))
        }
        .padding(.horizontal, 16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func badge(_ v: Double?, _ b: (mean: Double, sd: Double)?, higherIsBetter: Bool) -> (String, Color)? {
        guard let v, let b else { return nil }
        let z = (v - b.mean) / b.sd
        if higherIsBetter { return z > 0.4 ? ("GUT", Theme.good) : z < -1 ? ("NIEDRIG", Theme.warn) : ("NORMAL", Theme.good) }
        return z > 1.5 ? ("ERHÖHT", Theme.warn) : ("NORMAL", Theme.good)
    }

    private func tempText(_ t: Double?, _ base: Double?) -> String {
        guard let t, let base else { return "–" }
        let d = t - base
        return (d >= 0 ? "+" : "−") + Fmt.num(abs(d), 1) + " °C"
    }

    private func tempBadge(_ t: Double?, _ base: Double?) -> (String, Color)? {
        guard let t, let base else { return nil }
        return abs(t - base) > 0.5 ? ("AUFFÄLLIG", Theme.warn) : ("NORMAL", Theme.good)
    }

    private var tonight: some View {
        let need = model.needTonight
        return Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("DEIN BEDARF").font(.caption.weight(.heavy)).foregroundStyle(Theme.muted)
                        Text(Fmt.hm(need.total) + " h").font(.title.weight(.heavy))
                    }
                    Spacer()
                    if let bed = Analytics.bedtime(nights: model.nights, need: need.total) {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("INS BETT UM").font(.caption.weight(.heavy)).foregroundStyle(Theme.muted)
                            Text(Fmt.time(bed)).font(.title.weight(.heavy)).foregroundStyle(Theme.accent)
                        }
                    }
                }
                kv("Grundbedarf", Fmt.hm(need.base))
                kv("+ Belastung heute", "+" + Fmt.hm(need.strain))
                kv("+ Schlafschuld abbauen", "+" + Fmt.hm(need.debt))
                if let wake = Analytics.wakeTarget(nights: model.nights) {
                    Text("Gerechnet für deine übliche Aufwachzeit um \(Fmt.time(wake)). Schlafschuld der letzten 7 Nächte: \(Fmt.hm(need.weeklyDebt)) h.")
                        .font(.caption).foregroundStyle(Theme.soft)
                        .padding(10)
                        .background(Theme.card2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
    }

    private func kv(_ k: String, _ v: String) -> some View {
        HStack { Text(k).foregroundStyle(Theme.muted); Spacer(); Text(v).fontWeight(.bold) }.font(.footnote)
    }

    private var regularity: some View {
        let recent = Array(model.nights.suffix(14))
        return Card {
            VStack(alignment: .leading, spacing: 10) {
                Chart(recent) { n in
                    BarMark(
                        x: .value("Nacht", n.wakeDay, unit: .day),
                        yStart: .value("Bett", Analytics.noonMinutes(n.bedTime)),
                        yEnd: .value("Auf", Analytics.noonMinutes(n.end)),
                        width: .ratio(0.55)
                    )
                    .foregroundStyle(isWeekend(n.wakeDay) ? Theme.warn : Theme.sleep)
                    .cornerRadius(5)
                }
                .chartYScale(domain: .automatic(includesZero: false, reversed: true))
                .chartYAxis {
                    AxisMarks(values: [660, 780, 900, 1020, 1140]) { v in
                        AxisGridLine().foregroundStyle(Theme.line)
                        AxisValueLabel { Text(clockLabel(v.as(Double.self) ?? 0)) }
                    }
                }
                .chartXAxis(.hidden)
                .frame(height: 150)
                HStack(alignment: .firstTextBaseline) {
                    if let c = Analytics.consistency(model.nights) {
                        Text("\(c) %").font(.title3.weight(.heavy))
                        Text("Konsistenz").font(.footnote).foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    Text("Wochenende orange").font(.caption).foregroundStyle(Theme.warn)
                }
            }
        }
    }

    private func isWeekend(_ d: Date) -> Bool {
        let wd = Calendar.current.component(.weekday, from: Calendar.current.addDays(-1, to: d))
        return wd == 6 || wd == 7
    }

    private func clockLabel(_ noonMin: Double) -> String {
        let m = (Int(noonMin) + 12 * 60) % 1440
        return String(format: "%02d:%02d", m / 60, m % 60)
    }

    private func loadHeart() async {
        guard let n = night else { heart = []; return }
        if model.usingDemo { heart = DemoData.sleepHR(for: n); return }
        let samples = (try? await model.health.quantity(.heartRate, from: n.start, to: n.end)) ?? []
        heart = samples.map { HRPoint(date: $0.startDate, bpm: $0.quantity.doubleValue(for: HealthService.bpm)) }
    }
}

struct StatInline: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(Theme.muted)
            Text(value).font(.subheadline.weight(.heavy))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
