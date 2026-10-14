import SwiftUI
import WorkoutKit

// MARK: Planübersicht

struct PlanOverview: View {
    @Environment(DataStore.self) private var store
    @Environment(AppModel.self) private var model
    @State private var showSetup = false
    @State private var sending = false
    @State private var sendResult: String?
    @State private var confirmDelete = false

    var body: some View {
        if let plan = store.data.plan {
            content(plan)
                .sheet(isPresented: $showSetup) { PlanSetupView(existing: plan.settings) }
        } else {
            empty.sheet(isPresented: $showSetup) { PlanSetupView(existing: nil) }
        }
    }

    private var empty: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: "flag.checkered").font(.system(size: 30, weight: .bold)).foregroundStyle(Theme.accent)
                Text("Dein persönlicher Trainingsplan").font(.title3.weight(.heavy))
                Text("Ziel und Datum eingeben. Die App schätzt deine Form aus deinen Läufen, baut Phasen, Umfänge und Einheiten und passt alles laufend an Erholung, Leistung, Verletzungen und verpasste Einheiten an. Intervalle landen direkt auf der Watch.")
                    .font(.footnote).foregroundStyle(Theme.soft)
                Button { showSetup = true } label: {
                    Text("Plan erstellen").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Theme.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous)).foregroundStyle(Theme.bg)
                }
            }
        }
    }

    @ViewBuilder private func content(_ plan: TrainingPlan) -> some View {
        let paces = plan.paces
        let predicted = VDOT.raceTime(meters: plan.settings.distance.meters, vdot: plan.vdot)
        let today = Calendar.current.startOfDay(for: .now)
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("ZIEL").font(.caption.weight(.heavy)).foregroundStyle(Theme.muted)
                        Text(plan.settings.raceName.isEmpty ? plan.settings.distance.label : plan.settings.raceName).font(.title2.weight(.heavy))
                        Text("\(Fmt.day(plan.raceDay)) · noch \(plan.weeksLeft) Wochen").font(.footnote).foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Prognose").font(.caption.weight(.semibold)).foregroundStyle(Theme.muted)
                        Text(Fmt.clock(predicted)).font(.title3.weight(.heavy)).foregroundStyle(Theme.accent)
                        if let t = plan.settings.targetSeconds {
                            Text("Ziel " + Fmt.clock(t)).font(.caption.weight(.semibold)).foregroundStyle(predicted <= t ? Theme.good : Theme.warn)
                        }
                    }
                }
                PhaseBar(plan: plan)
                let ws = PlanGenerator.weekStart(today)
                let weekRuns = plan.runs.filter { $0.date >= ws && $0.date < Calendar.current.addDays(7, to: ws) }
                let planned = weekRuns.reduce(0.0) { $0 + paces.totalMeters($1.structure) / 1000 }
                let done = weekRuns.filter { $0.status == .done }.reduce(0.0) { $0 + ($1.actualMeters ?? 0) / 1000 }
                HStack(spacing: 8) {
                    mini("Diese Woche", "\(Fmt.num(done)) / \(Fmt.num(planned)) km")
                    mini("Form-Wert", Fmt.num(plan.vdot, 1))
                    mini("Phase", plan.phase(on: today)?.name ?? "–")
                }
            }
            .padding(18)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 26, style: .continuous))

            if let last = plan.log.first, Calendar.current.dateComponents([.day], from: last.date, to: .now).day ?? 9 < 3 {
                Hint(icon: "arrow.triangle.2.circlepath", title: "Plan live angepasst", text: last.text, color: Theme.sleep)
            }

            if WatchExport.isSupported {
                Button {
                    sending = true
                    Task {
                        let n = await WatchExport.scheduleWeek(plan)
                        sendResult = n > 0 ? "\(n) Einheiten für die nächsten 7 Tage liegen jetzt in der Trainings-App deiner Watch." : "Konnte nichts auf die Watch legen. Erlaube den Zugriff in den Einstellungen."
                        sending = false
                    }
                } label: {
                    Label(sending ? "Wird übertragen …" : "Nächste 7 Tage auf die Watch", systemImage: "applewatch")
                        .font(.subheadline.weight(.bold)).frame(maxWidth: .infinity).padding(.vertical, 13)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .disabled(sending)
                if let r = sendResult { Text(r).font(.caption).foregroundStyle(Theme.soft).padding(.horizontal, 4) }
            }

            SectionHeader("Diese Woche")
            WeekList(plan: plan, weekStart: PlanGenerator.weekStart(today))

            SectionHeader("Nächste Wochen")
            UpcomingWeeks(plan: plan)

            SectionHeader("Deine Paces")
            Card {
                VStack(spacing: 8) {
                    ForEach([PaceZone.easy, .long, .marathon, .half, .tenK, .threshold, .interval, .race], id: \.self) { z in
                        HStack {
                            Circle().fill(z.isQuality ? z.color : Theme.muted).frame(width: 8, height: 8)
                            Text(z.label).font(.subheadline)
                            Spacer()
                            Text(paces.label(z)).font(.subheadline.weight(.bold)).monospacedDigit()
                        }
                    }
                    Text("Aus deinem Form-Wert berechnet. Läufst du schneller oder langsamer als geplant, passt die App die Paces automatisch an.")
                        .font(.caption).foregroundStyle(Theme.muted).padding(.top, 4)
                }
            }

            if !plan.log.isEmpty {
                SectionHeader("Anpassungen")
                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(plan.log.prefix(6)) { e in
                            VStack(alignment: .leading, spacing: 1) {
                                Text(Fmt.shortDay(e.date)).font(.caption2.weight(.bold)).foregroundStyle(Theme.muted)
                                Text(e.text).font(.footnote)
                            }
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                Button { showSetup = true } label: {
                    Text("Plan ändern").font(.subheadline.weight(.bold)).frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                Button(role: .destructive) { confirmDelete = true } label: {
                    Text("Plan löschen").font(.subheadline.weight(.bold)).frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            .padding(.top, 8)
        }
        .confirmationDialog("Plan wirklich löschen?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Löschen", role: .destructive) { store.update { $0.plan = nil } }
        }
    }

    private func mini(_ t: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(t).font(.caption2.weight(.semibold)).foregroundStyle(Theme.muted)
            Text(v).font(.subheadline.weight(.heavy)).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Theme.card2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct PhaseBar: View {
    let plan: TrainingPlan

    var body: some View {
        let total = max(1, plan.phases.reduce(0.0) { $0 + $1.end.timeIntervalSince($1.start) + 86400 })
        let now = Date.now
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                HStack(spacing: 3) {
                    ForEach(plan.phases) { ph in
                        let len = ph.end.timeIntervalSince(ph.start) + 86400
                        let w = max(4, geo.size.width * len / total - 3)
                        let progress = min(1, max(0, now.timeIntervalSince(ph.start) / len))
                        ZStack(alignment: .leading) {
                            Capsule().fill(Theme.track)
                            Capsule().fill(Theme.accent).frame(width: w * progress)
                        }
                        .frame(width: w)
                    }
                }
            }
            .frame(height: 8)
            HStack(spacing: 3) {
                ForEach(plan.phases) { ph in
                    let isNow = now >= ph.start && now < Calendar.current.addDays(1, to: ph.end)
                    Text(ph.name).font(.caption2.weight(isNow ? .heavy : .semibold)).foregroundStyle(isNow ? Theme.text : Theme.muted)
                        .frame(maxWidth: .infinity, alignment: .leading).lineLimit(1).minimumScaleFactor(0.7)
                }
            }
        }
    }
}

struct WeekList: View {
    @Environment(DataStore.self) private var store
    let plan: TrainingPlan
    let weekStart: Date

    var body: some View {
        let cal = Calendar.current
        let paces = plan.paces
        VStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { i in
                let day = cal.addDays(i, to: weekStart)
                let wd = cal.component(.weekday, from: day)
                let run = plan.run(on: day)
                let strength = plan.settings.strengthDays.contains(wd)
                let isToday = cal.isDateInToday(day)
                let past = day < cal.startOfDay(for: .now)
                Group {
                    if let run {
                        NavigationLink { RunDetailView(runId: run.id) } label: {
                            DayRow(day: day, isToday: isToday, past: past, title: run.title,
                                   subtitle: subtitle(run, paces), color: run.type.color, status: run.status,
                                   adjusted: run.adjusted != nil, strength: strength)
                        }
                        .buttonStyle(.plain)
                    } else {
                        DayRow(day: day, isToday: isToday, past: past, title: strength ? "Krafttraining" : "Ruhetag",
                               subtitle: strength ? "Routine im Kraft-Tab" : "Erholung gehört zum Training",
                               color: strength ? Theme.warn : Theme.muted, status: nil, adjusted: false, strength: false)
                    }
                }
                if i < 6 { Divider().overlay(Theme.line) }
            }
        }
        .padding(.horizontal, 14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func subtitle(_ r: PlannedRun, _ p: Paces) -> String {
        if r.status == .done, let m = r.actualMeters, let s = r.actualSeconds, m > 0 {
            return "Erledigt: \(Fmt.km(m)) in \(Fmt.clock(s)) · \(Fmt.pace(s / (m / 1000)))/km"
        }
        if r.status == .missed { return "Verpasst" }
        let km = p.totalMeters(r.structure) / 1000
        var t = km > 0 ? Fmt.num(km, 1) + " km · ca. " + Fmt.clock(p.totalSeconds(r.structure)) : r.purpose
        if r.type == .cross || r.type == .rest { t = r.purpose }
        return t
    }
}

struct DayRow: View {
    let day: Date
    let isToday: Bool
    let past: Bool
    let title: String
    let subtitle: String
    let color: Color
    let status: RunStatus?
    let adjusted: Bool
    let strength: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 0) {
                Text(day.formatted(Date.FormatStyle().weekday(.abbreviated).locale(Fmt.de)).uppercased())
                    .font(.caption2.weight(.heavy)).foregroundStyle(isToday ? Theme.accent : Theme.muted)
                Text("\(Calendar.current.component(.day, from: day))").font(.headline.weight(.heavy))
                    .foregroundStyle(isToday ? Theme.accent : Theme.text)
            }
            .frame(width: 36)
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 4, height: 34)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title).font(.subheadline.weight(.bold)).lineLimit(1)
                    if adjusted { Badge(text: "ANGEPASST", color: Theme.sleep) }
                }
                Text(subtitle + (strength ? " · + Kraft" : "")).font(.caption).foregroundStyle(Theme.muted).lineLimit(1)
            }
            Spacer(minLength: 4)
            if status == .done {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.good)
            } else if status == .missed {
                Image(systemName: "xmark.circle").foregroundStyle(Theme.muted)
            } else if isToday {
                Badge(text: "HEUTE", color: Theme.accent)
            }
        }
        .padding(.vertical, 10)
        .opacity(past && status != .done ? 0.55 : 1)
        .contentShape(Rectangle())
    }
}

struct UpcomingWeeks: View {
    let plan: TrainingPlan

    var body: some View {
        let cal = Calendar.current
        let paces = plan.paces
        let thisWeek = PlanGenerator.weekStart(.now)
        let weeks: [Date] = (1...max(1, min(plan.weeksLeft, 30))).map { cal.addDays(7 * $0, to: thisWeek) }.filter { $0 <= plan.raceDay }
        VStack(spacing: 8) {
            ForEach(weeks, id: \.self) { ws in
                let runs = plan.runs.filter { $0.date >= ws && $0.date < cal.addDays(7, to: ws) }
                let km = runs.reduce(0.0) { $0 + paces.totalMeters($1.structure) / 1000 }
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(runs) { r in
                            NavigationLink { RunDetailView(runId: r.id) } label: {
                                HStack {
                                    Text(r.date.formatted(Date.FormatStyle().weekday(.abbreviated).locale(Fmt.de)))
                                        .font(.caption.weight(.bold)).foregroundStyle(Theme.muted).frame(width: 30, alignment: .leading)
                                    Circle().fill(r.type.color).frame(width: 7, height: 7)
                                    Text(r.title).font(.footnote)
                                    Spacer()
                                    Image(systemName: "chevron.right").font(.caption2).foregroundStyle(Theme.muted)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 8)
                } label: {
                    HStack {
                        Text("Woche ab \(Fmt.shortDay(ws))").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.text)
                        Spacer()
                        Text(plan.phase(on: ws)?.name ?? "").font(.caption).foregroundStyle(Theme.muted)
                        Text("\(Fmt.num(km)) km").font(.subheadline.weight(.heavy)).foregroundStyle(Theme.text)
                    }
                }
                .padding(14)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }
}

// MARK: Einzelne Einheit

struct RunDetailView: View {
    @Environment(DataStore.self) private var store
    let runId: UUID
    @State private var showPreview = false
    @State private var authorized = false

    var body: some View {
        if let plan = store.data.plan, let run = plan.runs.first(where: { $0.id == runId }) {
            detail(plan, run)
        } else {
            Text("Einheit nicht gefunden").foregroundStyle(Theme.soft)
        }
    }

    private func detail(_ plan: TrainingPlan, _ run: PlannedRun) -> some View {
        let p = plan.paces
        let km = p.totalMeters(run.structure) / 1000
        return ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(Fmt.day(run.date) + (plan.phase(on: run.date).map { " · " + $0.name } ?? "")).font(.footnote.weight(.semibold)).foregroundStyle(Theme.muted)
                    Text(run.purpose).font(.subheadline).foregroundStyle(Theme.soft)
                }
                .padding(.horizontal, 4)
                if let a = run.adjusted {
                    Hint(icon: "arrow.triangle.2.circlepath", title: "Angepasst", text: a + (run.original.map { ". Ursprünglich: \($0.title)" } ?? ""), color: Theme.sleep)
                }
                if !run.structure.isEmpty {
                    HStack(spacing: 8) {
                        StatTile(title: "Distanz", value: Fmt.num(km, 1), unit: "km")
                        StatTile(title: "Dauer", value: Fmt.clock(p.totalSeconds(run.structure)))
                        StatTile(title: "Ø Pace", value: km > 0 ? Fmt.pace(p.totalSeconds(run.structure) / km) : "–")
                    }
                    StructureBar(structure: run.structure, paces: p)
                    Card { StepList(structure: run.structure, paces: p) }
                }
                if run.status == .done {
                    doneCard(run, p)
                }
                if run.status == .planned && !run.structure.isEmpty && run.type != .rest && WatchExport.isSupported {
                    Button { showPreview = true } label: {
                        Label("An Apple Watch senden", systemImage: "applewatch")
                            .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 15)
                            .background(Theme.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous)).foregroundStyle(Theme.bg)
                    }
                    Text("Die Einheit landet in der Trainings-App der Watch. Die Uhr sagt jeden Abschnitt an und warnt, wenn du zu schnell oder zu langsam bist.")
                        .font(.caption).foregroundStyle(Theme.muted).padding(.horizontal, 4)
                }
                if run.status != .done && run.type != .race {
                    Button {
                        store.update { d in
                            guard let i = d.plan?.runs.firstIndex(where: { $0.id == runId }) else { return }
                            d.plan?.runs[i].status = run.status == .missed ? .planned : .missed
                        }
                    } label: {
                        Text(run.status == .missed ? "Doch wieder einplanen" : "Diese Einheit auslassen").font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
        }
        .screenBackground()
        .navigationTitle(run.title)
        .navigationBarTitleDisplayMode(.inline)
        .workoutPreview(WatchExport.workoutPlan(for: run, paces: p), isPresented: $showPreview)
    }

    private func doneCard(_ run: PlannedRun, _ p: Paces) -> some View {
        let m = run.actualMeters ?? 0, s = run.actualSeconds ?? 0
        let planPace = p.totalSeconds(run.structure) / max(0.1, p.totalMeters(run.structure) / 1000)
        let actPace = m > 0 ? s / (m / 1000) : 0
        return Card {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Erledigt").font(.headline)
                    Spacer()
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.good)
                }
                HStack {
                    StatInline(title: "Distanz", value: Fmt.km(m))
                    StatInline(title: "Zeit", value: Fmt.clock(s))
                    StatInline(title: "Pace", value: Fmt.pace(actPace) + "/km")
                }
                if actPace > 0 {
                    let diff = actPace - planPace
                    Text(abs(diff) < 4 ? "Genau im Plan." : diff < 0 ? "\(Int(-diff)) s/km schneller als geplant." : "\(Int(diff)) s/km langsamer als geplant.")
                        .font(.footnote).foregroundStyle(Theme.soft)
                }
            }
        }
    }
}

struct StructureBar: View {
    let structure: RunStructure
    let paces: Paces
    var compact = false

    private struct Piece: Identifiable {
        let id = UUID()
        let seconds: Double
        let zone: PaceZone
    }

    var body: some View {
        var pieces: [Piece] = []
        if let w = structure.warmup { pieces.append(Piece(seconds: paces.seconds(w), zone: w.zone)) }
        for b in structure.blocks {
            for i in 0..<max(1, b.repeats) {
                pieces.append(Piece(seconds: paces.seconds(b.work), zone: b.work.zone))
                if let r = b.recovery, i < b.repeats - 1 { pieces.append(Piece(seconds: paces.seconds(r), zone: r.zone)) }
            }
        }
        if let c = structure.cooldown { pieces.append(Piece(seconds: paces.seconds(c), zone: c.zone)) }
        let total = max(1, pieces.reduce(0) { $0 + $1.seconds })
        let height: CGFloat = compact ? 34 : 56
        return GeometryReader { geo in
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(pieces) { pc in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(pc.zone.isQuality ? pc.zone.color : Theme.track)
                        .frame(width: max(2, geo.size.width * pc.seconds / total - 2), height: pc.zone.isQuality ? height : height * 0.36)
                }
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .frame(height: height)
        .padding(compact ? 0 : 16)
        .background(compact ? Color.clear : Theme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

struct StepList: View {
    let structure: RunStructure
    let paces: Paces

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let w = structure.warmup { row("Einlaufen", w, repeats: nil) }
            ForEach(Array(structure.blocks.enumerated()), id: \.offset) { _, b in
                if b.repeats > 1 {
                    row(amount(b.work) + " " + b.work.zone.label, b.work, repeats: b.repeats)
                    if let r = b.recovery { row("Pause: " + amount(r) + " traben", r, repeats: nil, isRecovery: true) }
                } else {
                    row(b.work.zone == .race || b.work.zone == .marathon ? "Tempoblock " + amount(b.work) : amount(b.work) + " " + b.work.zone.label, b.work, repeats: nil)
                }
            }
            if let c = structure.cooldown { row("Auslaufen", c, repeats: nil) }
        }
    }

    private func amount(_ s: Segment) -> String {
        if let m = s.meters { return PlanGenerator.distText(m) }
        if let t = s.seconds { return t < 60 ? "\(Int(t)) s" : "\(Fmt.num(t / 60)) min" }
        return ""
    }

    private func row(_ title: String, _ s: Segment, repeats: Int?, isRecovery: Bool = false) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 3).fill(s.zone.isQuality ? s.zone.color : Theme.track).frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 1) {
                Text(title.capitalizedFirst).font(.subheadline.weight(isRecovery ? .regular : .bold))
                Text(paces.label(s.zone) + (s.meters != nil && s.zone.isQuality ? " · " + Fmt.clock(paces.seconds(s)) + " pro Wdh." : ""))
                    .font(.caption).foregroundStyle(Theme.muted)
            }
            Spacer()
            if let r = repeats { Text("\(r)×").font(.subheadline.weight(.heavy)).foregroundStyle(Theme.accent) }
        }
        .padding(.vertical, 9)
    }
}

// MARK: Plan erstellen

struct PlanSetupView: View {
    @Environment(DataStore.self) private var store
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let existing: PlanSettings?
    @State private var s = PlanSettings()
    @State private var vdot: Double = 45
    @State private var useTarget = false
    @State private var targetH = 1
    @State private var targetM = 45
    @State private var recentDistance: RaceDistance = .tenK
    @State private var recentMin = 50
    @State private var recentSec = 0
    @State private var loaded = false

    private let weekdayNames = [(2, "Mo"), (3, "Di"), (4, "Mi"), (5, "Do"), (6, "Fr"), (7, "Sa"), (1, "So")]

    var body: some View {
        NavigationStack {
            SwiftUI.Form {
                Section("Ziel") {
                    Picker("Distanz", selection: $s.distance) {
                        ForEach(RaceDistance.allCases) { Text($0.label).tag($0) }
                    }
                    DatePicker("Datum", selection: $s.raceDate, in: Date.now..., displayedComponents: .date)
                        .environment(\.locale, Fmt.de)
                    TextField("Name des Wettkampfs (optional)", text: $s.raceName)
                    Toggle("Zielzeit festlegen", isOn: $useTarget)
                    if useTarget {
                        HStack {
                            Picker("Std", selection: $targetH) { ForEach(0..<8, id: \.self) { Text("\($0) h").tag($0) } }
                            Picker("Min", selection: $targetM) { ForEach(0..<60, id: \.self) { Text("\($0) min").tag($0) } }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 110)
                    }
                    let weeks = weeksUntil
                    if weeks < s.distance.minWeeks {
                        Label("Nur \(weeks) Wochen. Für \(s.distance.label) sind mindestens \(s.distance.minWeeks) ideal. Der Plan wird kompakter.", systemImage: "exclamationmark.triangle")
                            .font(.footnote).foregroundStyle(Theme.warn)
                    }
                }

                Section {
                    dayChips(selection: $s.runDays)
                    Picker("Langer Lauf am", selection: $s.longRunDay) {
                        ForEach(weekdayNames.filter { s.runDays.contains($0.0) }, id: \.0) { Text(longName($0.0)).tag($0.0) }
                    }
                } header: {
                    Text("Lauftage")
                } footer: {
                    Text("Mindestens 3 Lauftage. Bei 4 oder mehr kommt eine zweite Qualitätseinheit dazu.")
                }

                Section("Krafttage") {
                    dayChips(selection: $s.strengthDays)
                }

                Section {
                    Stepper("Aktuell \(Int(s.startWeeklyKm)) km pro Woche", value: $s.startWeeklyKm, in: 0...160, step: 1)
                    Stepper("Form-Wert \(Fmt.num(vdot, 1))", value: $vdot, in: 25...85, step: 0.5)
                    Text("Entspricht etwa 10 km in \(Fmt.clock(VDOT.raceTime(meters: 10000, vdot: vdot))) und Halbmarathon in \(Fmt.clock(VDOT.raceTime(meters: 21097.5, vdot: vdot))).")
                        .font(.footnote).foregroundStyle(Theme.soft)
                } header: {
                    Text("Deine Form")
                } footer: {
                    Text("Geschätzt aus deinen Läufen der letzten 8 Wochen und deiner VO2max. Wenn du einen aktuellen Wettkampf hast, trag ihn unten ein, das ist genauer.")
                }

                Section("Aktuelle Bestzeit (optional)") {
                    Picker("Distanz", selection: $recentDistance) {
                        ForEach([RaceDistance.fiveK, .tenK, .half, .marathon]) { Text($0.label).tag($0) }
                    }
                    HStack {
                        Picker("Min", selection: $recentMin) { ForEach(10..<300, id: \.self) { Text("\($0) min").tag($0) } }
                        Picker("Sek", selection: $recentSec) { ForEach(0..<60, id: \.self) { Text("\($0) s").tag($0) } }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 110)
                    Button("Form-Wert aus dieser Zeit übernehmen") {
                        vdot = (VDOT.from(meters: recentDistance.meters, seconds: Double(recentMin * 60 + recentSec)) * 2).rounded() / 2
                    }
                }
            }
            .navigationTitle(existing == nil ? "Plan erstellen" : "Plan ändern")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Erstellen") { create() }.disabled(s.runDays.count < 2)
                }
            }
            .onAppear(perform: setup)
        }
    }

    private var weeksUntil: Int {
        max(0, Int((Calendar.current.startOfDay(for: s.raceDate).timeIntervalSince(Calendar.current.startOfDay(for: .now)) / 86400 / 7).rounded(.down)))
    }

    private func longName(_ wd: Int) -> String {
        ["", "Sonntag", "Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag", "Samstag"][wd]
    }

    private func dayChips(selection: Binding<[Int]>) -> some View {
        HStack(spacing: 6) {
            ForEach(weekdayNames, id: \.0) { item in
                let wd = item.0
                let name = item.1
                let on = selection.wrappedValue.contains(wd)
                Button {
                    if on { selection.wrappedValue.removeAll { $0 == wd } } else { selection.wrappedValue.append(wd) }
                    if !s.runDays.contains(s.longRunDay), let last = PlanGenerator.mondayFirst.last(where: { s.runDays.contains($0) }) { s.longRunDay = last }
                } label: {
                    Text(name).font(.footnote.weight(.bold)).frame(maxWidth: .infinity).padding(.vertical, 9)
                        .background(on ? Theme.accent : Theme.card2, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .foregroundStyle(on ? Theme.bg : Theme.text)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func setup() {
        guard !loaded else { return }
        loaded = true
        if let e = existing {
            s = e
            vdot = store.data.plan?.vdot ?? e.startVDOT
            if let t = e.targetSeconds {
                useTarget = true
                targetH = Int(t) / 3600
                targetM = (Int(t) % 3600) / 60
            }
        } else {
            vdot = PlanGenerator.estimateVDOT(workouts: model.workouts, vo2max: model.vo2.last?.value)
            s.startWeeklyKm = max(10, PlanGenerator.recentWeeklyKm(workouts: model.workouts))
            s.startVDOT = vdot
        }
    }

    private func create() {
        var settings = s
        settings.targetSeconds = useTarget ? Double(targetH * 3600 + targetM * 60) : nil
        settings.startVDOT = vdot
        if !settings.runDays.contains(settings.longRunDay) { settings.longRunDay = PlanGenerator.mondayFirst.last { settings.runDays.contains($0) } ?? 1 }
        var plan = PlanGenerator.generate(settings: settings, vdot: vdot)
        PlanAdapter.adapt(&plan, workouts: model.workouts, recovery: model.recoveryToday, restrictions: store.restrictions)
        store.update { $0.plan = plan }
        WidgetBridge.update(model: model, store: store)
        dismiss()
    }
}
