import SwiftUI
import WorkoutKit

struct TodayView: View {
    @Environment(AppModel.self) private var model
    @Environment(DataStore.self) private var store
    @Environment(\.switchTab) private var switchTab
    @AppStorage("trainingSeg") private var trainingSeg = 0
    @State private var showSettings = false
    @State private var showWatch = false
    @State private var showPlanSetup = false
    @State private var coachPrompt: CoachPrompt?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if model.usingDemo { DemoBanner() }
                    Text(Fmt.day(.now)).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.muted).padding(.horizontal, 4)
                    recoveryCard
                    statsRow
                    coachCard
                    JournalPromptCard()
                    restrictionBanner
                    planSection
                    nutritionSection
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
                ToolbarItem(placement: .topBarLeading) {
                    Button { coachPrompt = CoachPrompt(text: nil) } label: { Image(systemName: "sparkles") }
                        .accessibilityLabel("Coach")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel("Einstellungen")
                }
            }
            .sheet(item: $coachPrompt) { p in CoachView(initialPrompt: p.text) }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showPlanSetup) { PlanSetupView(existing: nil) }
        }
    }

    // MARK: Coach

    private var coachCard: some View {
        Button { coachPrompt = CoachPrompt(text: "Gib mir mein Tagesbriefing") } label: {
            HStack(spacing: 12) {
                Image(systemName: "sparkles").font(.title3.weight(.bold)).foregroundStyle(Theme.bg)
                    .frame(width: 44, height: 44).background(Theme.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tagesbriefing vom Coach").font(.subheadline.weight(.bold))
                    Text("Erholung, Training, Essen und Schlaf für heute in einer Antwort").font(.caption).foregroundStyle(Theme.muted)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Theme.muted)
            }
            .padding(14)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: Einschränkungen

    @ViewBuilder private var restrictionBanner: some View {
        let r = store.restrictions
        if !r.isEmpty {
            NavigationLink { InjuryView() } label: {
                Hint(icon: r.trainingPaused ? "cross.case.fill" : "bandage.fill",
                     title: r.trainingPaused ? "Krankheitsmodus aktiv" : "Eingeschränkt: " + r.allReasons.joined(separator: ", "),
                     text: restrictionText(r), color: Theme.bad)
            }
            .buttonStyle(.plain)
        }
    }

    private func restrictionText(_ r: Restrictions) -> String {
        if r.trainingPaused { return "Kein Training, bis du dich gesund meldest. Plan und Kraft sind pausiert." }
        var parts: [String] = []
        if !r.runAllowed { parts.append("Laufen wird durch Alternativtraining ersetzt") } else if r.runEasyOnly { parts.append("Nur lockere Läufe") }
        if !r.blockedRegions.isEmpty { parts.append("Kraftübungen für \(r.blockedRegions.map(\.label).sorted().joined(separator: ", ")) werden ersetzt") }
        return parts.joined(separator: ". ") + "."
    }

    // MARK: Plan

    @ViewBuilder private var planSection: some View {
        if let plan = store.data.plan {
            let today = Calendar.current.startOfDay(for: .now)
            let wd = Calendar.current.component(.weekday, from: today)
            let strengthDay = plan.settings.strengthDays.contains(wd)
            SectionHeader("Training heute", trailing: plan.phase(on: today)?.name)
            if let run = plan.run(on: today) {
                todayRun(run, plan)
            } else {
                Card {
                    HStack(spacing: 12) {
                        Image(systemName: strengthDay ? "dumbbell.fill" : "bed.double.fill").font(.title3).foregroundStyle(strengthDay ? Theme.warn : Theme.muted)
                            .frame(width: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(strengthDay ? "Krafttag" : "Ruhetag").font(.headline)
                            Text(strengthDay ? "Kein Lauf geplant. Zeit für eine Kraftroutine." : "Kein Lauf geplant. Erholung ist Teil des Plans.")
                                .font(.footnote).foregroundStyle(Theme.soft)
                        }
                    }
                }
            }
            if strengthDay, plan.run(on: today) != nil, store.restrictions.strengthAllowed {
                Button { trainingSeg = 1; switchTab(1) } label: {
                    Hint(icon: "dumbbell.fill", title: "Heute zusätzlich Kraft", text: "Am besten nach dem Lauf oder mit 6 Stunden Abstand.", color: Theme.warn)
                }
                .buttonStyle(.plain)
            }
        } else {
            SectionHeader("Training heute")
            Button { showPlanSetup = true } label: {
                Hint(icon: "flag.checkered", title: "Noch kein Trainingsplan",
                     text: "Ziel und Datum eingeben, die App baut den Plan und passt ihn jeden Tag an deine Erholung an.", color: Theme.accent)
            }
            .buttonStyle(.plain)
        }
    }

    private func todayRun(_ run: PlannedRun, _ plan: TrainingPlan) -> some View {
        let p = plan.paces
        let km = p.totalMeters(run.structure) / 1000
        return VStack(alignment: .leading, spacing: 12) {
            NavigationLink { RunDetailView(runId: run.id) } label: {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: run.type.icon).font(.title3.weight(.bold)).foregroundStyle(Theme.bg)
                        .frame(width: 44, height: 44).background(run.type.color, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(run.title).font(.headline).multilineTextAlignment(.leading)
                        if run.status == .done, let m = run.actualMeters, let s = run.actualSeconds {
                            Text("Erledigt: \(Fmt.km(m)) in \(Fmt.clock(s))").font(.footnote.weight(.semibold)).foregroundStyle(Theme.good)
                        } else if km > 0 && run.type != .cross {
                            Text("\(Fmt.num(km, 1)) km · ca. \(Fmt.clock(p.totalSeconds(run.structure)))").font(.footnote).foregroundStyle(Theme.muted)
                        }
                        Text(run.purpose).font(.footnote).foregroundStyle(Theme.soft).multilineTextAlignment(.leading).lineLimit(3)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: run.status == .done ? "checkmark.circle.fill" : "chevron.right")
                        .foregroundStyle(run.status == .done ? Theme.good : Theme.muted)
                }
            }
            .buttonStyle(.plain)
            if let a = run.adjusted {
                Label(a, systemImage: "arrow.triangle.2.circlepath").font(.caption.weight(.semibold)).foregroundStyle(Theme.sleep)
            }
            if run.type.isQuality || run.type == .long, !run.structure.isEmpty {
                StructureBar(structure: run.structure, paces: p, compact: true)
            }
            if run.status == .planned && run.type != .rest && !run.structure.isEmpty && WatchExport.isSupported {
                Button { showWatch = true } label: {
                    Label("An Apple Watch senden", systemImage: "applewatch").font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Theme.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .foregroundStyle(Theme.bg)
                }
                .workoutPreview(WatchExport.workoutPlan(for: run, paces: p), isPresented: $showWatch)
            }
        }
        .padding(16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    // MARK: Ernährung

    private var nutritionSection: some View {
        let today = Calendar.current.startOfDay(for: .now)
        let m = Macros.sum(store.entries(on: today))
        let t = store.nutritionTargets(model: model, day: today)
        return Button { switchTab(2) } label: {
            HStack(spacing: 14) {
                ZStack {
                    Ring(progress: m.kcal / max(1, t.kcal), color: Theme.accent, lineWidth: 7)
                    Image(systemName: "fork.knife").font(.footnote.weight(.bold)).foregroundStyle(Theme.accent)
                }
                .frame(width: 46, height: 46)
                VStack(alignment: .leading, spacing: 2) {
                    Text(m.kcal > 0 ? "\(Fmt.num(m.kcal)) von \(Fmt.num(t.kcal)) kcal" : "Ziel heute \(Fmt.num(t.kcal)) kcal").font(.subheadline.weight(.bold))
                    Text("Eiweiß \(Fmt.num(m.protein)) / \(Fmt.num(t.protein)) g" + (t.plannedBonus > 0 ? " · Trainingstag" : ""))
                        .font(.caption).foregroundStyle(Theme.muted)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Theme.muted)
            }
            .padding(14)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
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
            NavigationLink { StrainDetailView() } label: {
                StatTile(title: "Belastung", value: Fmt.num(model.strainToday, 1), unit: "/21",
                         note: "Ziel \(Int(target.lowerBound))–\(Int(target.upperBound))", noteColor: Theme.warn)
            }
            .buttonStyle(.plain)
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

struct CoachPrompt: Identifiable {
    let id = UUID()
    let text: String?
}
