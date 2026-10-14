import SwiftUI

struct TodayView: View {
    @Environment(AppModel.self) private var model
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if model.usingDemo { DemoBanner() }
                    Text(Fmt.day(.now)).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.muted).padding(.horizontal, 4)
                    recoveryCard
                    statsRow
                    sleepSection
                    activitiesSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .screenBackground()
            .refreshable { await model.load() }
            .navigationTitle("Heute")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel("Einstellungen")
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
        }
    }

    @ViewBuilder private var recoveryCard: some View {
        if let r = model.recoveryToday {
            HStack(spacing: 18) {
                ZStack {
                    Ring(progress: Double(r.score) / 100, color: r.color, lineWidth: 13)
                    VStack(spacing: 0) {
                        Text("\(r.score)").font(.system(size: 36, weight: .heavy))
                        Text("Erholung").font(.caption.weight(.semibold)).foregroundStyle(Theme.muted)
                    }
                }
                .frame(width: 124, height: 124)
                VStack(alignment: .leading, spacing: 6) {
                    Text(r.label).font(.headline.weight(.bold)).foregroundStyle(r.color)
                    Text(r.text).font(.footnote).foregroundStyle(Theme.soft).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(20)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        } else {
            Card {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Noch keine Erholung berechnet").font(.headline)
                    Text("Trag die Watch eine Nacht lang, dann gibt es morgen früh den ersten Wert.")
                        .font(.footnote).foregroundStyle(Theme.soft)
                }
            }
        }
    }

    private var statsRow: some View {
        let t = model.today
        let night = model.lastNight
        let hrvB = Analytics.baseline(model.days, before: max(0, model.days.count - 1), \.hrv)
        let target = Analytics.strainTarget(model.recoveryToday)
        return HStack(spacing: 8) {
            StatTile(title: "Schlaf", value: night.map { Fmt.hm($0.asleep) } ?? "–", unit: "h",
                     note: night.map { "Score \(model.sleepScore($0))" }, noteColor: Theme.sleep)
            StatTile(title: "HRV", value: t?.hrv.map { Fmt.num($0) } ?? "–", unit: "ms",
                     note: deltaText(t?.hrv, hrvB?.mean, unit: ""), noteColor: (t?.hrv ?? 0) >= (hrvB?.mean ?? 0) ? Theme.good : Theme.warn)
            StatTile(title: "Belastung", value: Fmt.num(model.strainToday, 1), unit: "/21",
                     note: "Ziel \(Int(target.lowerBound))–\(Int(target.upperBound))", noteColor: Theme.warn)
        }
    }

    private func deltaText(_ v: Double?, _ base: Double?, unit: String) -> String? {
        guard let v, let base else { return nil }
        let d = v - base
        return (d >= 0 ? "+" : "−") + Fmt.num(abs(d)) + unit + " zum Schnitt"
    }

    @ViewBuilder private var sleepSection: some View {
        SectionHeader("Schlaf")
        if let n = model.lastNight {
            NavigationLink { SleepView() } label: {
                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(Fmt.hm(n.asleep) + " h").font(.title2.weight(.heavy))
                            Text("\(Fmt.time(n.bedTime)) – \(Fmt.time(n.end))").font(.footnote).foregroundStyle(Theme.muted)
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(Theme.muted)
                        }
                        StageBar(night: n).frame(height: 10)
                        let need = model.needTonight
                        if let bed = Analytics.bedtime(nights: model.nights, need: need.total) {
                            Text("Heute Nacht: \(Fmt.hm(need.total)) h Bedarf · ins Bett um \(Fmt.time(bed))")
                                .font(.footnote.weight(.semibold)).foregroundStyle(Theme.sleep)
                        }
                    }
                }
            }
            .buttonStyle(.plain)
        } else {
            Card { Text("Keine Schlafdaten von letzter Nacht.").font(.footnote).foregroundStyle(Theme.soft) }
        }
    }

    @ViewBuilder private var activitiesSection: some View {
        SectionHeader("Letzte Aktivitäten")
        if model.workouts.isEmpty {
            Card { Text("Noch keine Workouts aufgezeichnet.").font(.footnote).foregroundStyle(Theme.soft) }
        } else {
            VStack(spacing: 0) {
                ForEach(Array(model.workouts.prefix(4))) { w in
                    NavigationLink { WorkoutDetailView(item: w) } label: { WorkoutRow(item: w) }
                        .buttonStyle(.plain)
                    if w.id != model.workouts.prefix(4).last?.id { Divider().overlay(Theme.line) }
                }
            }
            .padding(.horizontal, 16)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }
}

struct StageBar: View {
    let night: SleepNight

    var body: some View {
        GeometryReader { geo in
            let total = max(1, night.end.timeIntervalSince(night.start))
            HStack(spacing: 1) {
                ForEach(night.segments) { s in
                    Rectangle().fill(s.stage.color)
                        .frame(width: max(0.5, geo.size.width * s.duration / total - 1))
                }
            }
            .clipShape(Capsule())
        }
    }
}

struct WorkoutRow: View {
    let item: WorkoutItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(item.kind.color)
                .frame(width: 40, height: 40)
                .background(item.kind.color.opacity(0.14), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).font(.subheadline.weight(.bold))
                Text(subtitle).font(.caption).foregroundStyle(Theme.muted).lineLimit(1)
            }
            Spacer(minLength: 4)
            Badge(text: item.kind.label, color: item.kind.color)
        }
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }

    private var subtitle: String {
        var parts = [Fmt.shortDay(item.start)]
        if let d = item.distance, d > 200 { parts.append(Fmt.km(d)) }
        parts.append(Fmt.clock(item.duration))
        if let p = item.pace, item.kind == .endurance { parts.append(Fmt.pace(p) + "/km") }
        if let hr = item.avgHR { parts.append("Ø \(Int(hr)) bpm") }
        return parts.joined(separator: " · ")
    }
}
