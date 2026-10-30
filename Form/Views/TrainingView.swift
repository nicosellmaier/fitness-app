import SwiftUI
import Charts
import MapKit

enum TrainingDest: Hashable { case running, strength }

struct TrainingView: View {
    @Environment(AppModel.self) private var model
    @Environment(DataStore.self) private var store
    /// Von außen gesetzt (Heute-Tab, Screenshots): 1 öffnet Laufen, 2 öffnet Kraft
    @AppStorage("trainingSeg") private var openSection = 0
    @State private var path: [TrainingDest] = []
    @State private var filter = 0
    @State private var openSession = false

    private var filtered: [WorkoutItem] {
        switch filter {
        case 1: return model.workouts.filter { $0.kind == .endurance }
        case 2: return model.workouts.filter { $0.kind == .strength }
        default: return model.workouts
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if model.usingDemo { DemoBanner() }
                    restrictionBanner
                    activeSessionCard
                    todayCard
                    HStack(spacing: 10) {
                        runningTile
                        strengthTile
                    }
                    SectionHeader("Diese Woche")
                    weekCard
                    SectionHeader("Verlauf", trailing: "\(model.workouts.count) Einheiten")
                    Picker("Filter", selection: $filter) {
                        Text("Alle").tag(0)
                        Text("Ausdauer").tag(1)
                        Text("Kraft").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .sensoryFeedback(.selection, trigger: filter)
                    list
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .screenBackground()
            .refreshable { await model.load() }
            .navigationTitle("Training")
            .navigationDestination(for: TrainingDest.self) { d in
                switch d {
                case .running: RunningHomeView()
                case .strength: StrengthPageView()
                }
            }
            .navigationDestination(isPresented: $openSession) { SessionView() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink { InjuryView() } label: {
                        Image(systemName: store.restrictions.isEmpty ? "bandage" : "bandage.fill")
                            .foregroundStyle(store.restrictions.isEmpty ? Theme.text : Theme.bad)
                    }
                }
            }
            .onAppear { openRequested() }
            .onChange(of: openSection) { _, _ in openRequested() }
        }
    }

    private func openRequested() {
        guard openSection != 0 else { return }
        path = [openSection == 2 ? .strength : .running]
        openSection = 0
    }

    // MARK: Heute

    @ViewBuilder private var activeSessionCard: some View {
        if let s = store.activeSession {
            Button { openSession = true } label: {
                HStack(spacing: 12) {
                    Image(systemName: "timer").font(.title3.weight(.bold)).foregroundStyle(Theme.bg)
                        .frame(width: 44, height: 44).background(Theme.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Einheit läuft: \(s.name)").font(.subheadline.weight(.bold))
                        Text("Seit \(Fmt.time(s.start)) · \(s.doneSets) Sätze erledigt").font(.caption).foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    Chevron()
                }
                .padding(14)
                .background(CardBackground(radius: 20, tint: Theme.accent))
            }
            .buttonStyle(.press)
        }
    }

    @ViewBuilder private var todayCard: some View {
        let today = Calendar.current.startOfDay(for: .now)
        let wd = Calendar.current.component(.weekday, from: today)
        if let plan = store.data.plan {
            let run = plan.run(on: today)
            let strengthDay = plan.settings.strengthDays.contains(wd)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("HEUTE").font(.caption.weight(.heavy)).foregroundStyle(Theme.muted)
                    Spacer()
                    if let ph = plan.phase(on: today) { Text(ph.name).font(.caption.weight(.semibold)).foregroundStyle(Theme.muted) }
                }
                if let run {
                    NavigationLink { RunDetailView(runId: run.id) } label: {
                        HStack(spacing: 12) {
                            Image(systemName: run.type.icon).font(.title3.weight(.bold)).foregroundStyle(Theme.bg)
                                .frame(width: 44, height: 44).background(run.type.color, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(run.title).font(.headline).multilineTextAlignment(.leading)
                                Text(run.status == .done ? "Erledigt" : "\(Fmt.num(plan.paces.totalMeters(run.structure) / 1000, 1)) km · ca. \(Fmt.clock(plan.paces.totalSeconds(run.structure)))")
                                    .font(.caption).foregroundStyle(run.status == .done ? Theme.good : Theme.muted)
                            }
                            Spacer()
                            Image(systemName: run.status == .done ? "checkmark.circle.fill" : "chevron.right")
                                .foregroundStyle(run.status == .done ? Theme.good : Theme.muted)
                        }
                    }
                    .buttonStyle(.press)
                }
                if strengthDay {
                    if run != nil { Divider().overlay(Theme.line) }
                    Button { path = [.strength] } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "dumbbell.fill").font(.title3.weight(.bold)).foregroundStyle(Theme.bg)
                                .frame(width: 44, height: 44).background(Theme.warn, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Krafttag").font(.headline)
                                Text(run != nil ? "Nach dem Lauf oder mit 6 Stunden Abstand" : "Routine wählen und starten").font(.caption).foregroundStyle(Theme.muted)
                            }
                            Spacer()
                            Chevron()
                        }
                    }
                    .buttonStyle(.press)
                }
                if run == nil && !strengthDay {
                    HStack(spacing: 12) {
                        Image(systemName: "bed.double.fill").font(.title3).foregroundStyle(Theme.muted).frame(width: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Ruhetag").font(.headline)
                            Text("Erholung ist Teil des Plans.").font(.caption).foregroundStyle(Theme.muted)
                        }
                    }
                }
            }
            .padding(16)
            .background(CardBackground(radius: 22))
        }
    }

    // MARK: Einstiege

    private var runningTile: some View {
        let plan = store.data.plan
        let next = plan?.runs.first { $0.status == .planned && $0.date >= Calendar.current.startOfDay(for: .now) && $0.type != .rest }
        return Button { path = [.running] } label: {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "figure.run").font(.title2.weight(.bold)).foregroundStyle(Theme.bg)
                    .frame(width: 44, height: 44)
                    .background(LinearGradient(colors: [Theme.accent, Theme.good], startPoint: .topLeading, endPoint: .bottomTrailing),
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                Text("Laufen").font(.headline)
                if let plan {
                    Text(plan.settings.raceName.isEmpty ? plan.settings.distance.label : plan.settings.raceName).font(.caption.weight(.semibold)).foregroundStyle(Theme.soft).lineLimit(1)
                    Text(next.map { "Nächster: \(Fmt.shortDay($0.date))" } ?? "noch \(plan.weeksLeft) Wochen").font(.caption2).foregroundStyle(Theme.muted).lineLimit(1)
                } else {
                    Text("Plan erstellen").font(.caption.weight(.semibold)).foregroundStyle(Theme.accent)
                    Text("5 Vorlagen, auch für Einsteiger").font(.caption2).foregroundStyle(Theme.muted).lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(CardBackground(radius: 20))
        }
        .buttonStyle(.press)
    }

    private var strengthTile: some View {
        let last = store.data.sessions.max { $0.start < $1.start }
        return Button { path = [.strength] } label: {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "dumbbell.fill").font(.title2.weight(.bold)).foregroundStyle(Theme.bg)
                    .frame(width: 44, height: 44)
                    .background(LinearGradient(colors: [Theme.warn, Theme.bad.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing),
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                Text("Kraft").font(.headline)
                if store.data.routines.isEmpty {
                    Text("Programm wählen").font(.caption.weight(.semibold)).foregroundStyle(Theme.warn)
                    Text("\(Presets.programs.count) fertige Programme").font(.caption2).foregroundStyle(Theme.muted).lineLimit(1)
                } else {
                    Text("\(store.data.routines.count) Routinen").font(.caption.weight(.semibold)).foregroundStyle(Theme.soft)
                    Text(last.map { "Zuletzt: \(Fmt.shortDay($0.start))" } ?? "Noch keine Einheit").font(.caption2).foregroundStyle(Theme.muted).lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(CardBackground(radius: 20))
        }
        .buttonStyle(.press)
    }

    @ViewBuilder private var restrictionBanner: some View {
        let r = store.restrictions
        if !r.isEmpty {
            NavigationLink { InjuryView() } label: {
                Hint(icon: r.trainingPaused ? "cross.case.fill" : "bandage.fill",
                     title: r.trainingPaused ? "Krankheitsmodus" : r.runAllowed ? "Eingeschränkt" : "Laufpause",
                     text: r.trainingPaused ? "Training pausiert. Der Plan setzt aus und baut sich danach wieder auf."
                        : "Wegen \(r.allReasons.joined(separator: ", ")). Plan und Kraftübungen werden automatisch angepasst.",
                     color: Theme.bad)
            }
            .buttonStyle(.press)
        }
    }

    private var weekCard: some View {
        let cal = Calendar.current
        let weekStart = cal.dateInterval(of: .weekOfYear, for: .now)?.start ?? cal.dayStart(.now)
        let week = model.workouts.filter { $0.start >= weekStart }
        let km = week.compactMap { $0.kind == .endurance ? $0.distance : nil }.reduce(0, +) / 1000
        let time = week.reduce(0) { $0 + $1.duration }
        let strength = max(week.filter { $0.kind == .strength }.count, store.data.sessions.filter { $0.start >= weekStart }.count)
        let days: [(String, Double, ActivityKind?)] = (0..<7).map { i in
            let d = cal.addDays(i, to: weekStart)
            let ws = model.workouts.filter { cal.isDate($0.start, inSameDayAs: d) }
            let label = d.formatted(Date.FormatStyle().weekday(.narrow).locale(Fmt.de))
            return (label, ws.reduce(0) { $0 + $1.duration } / 60, ws.first?.kind)
        }
        let maxMin = max(30, days.map(\.1).max() ?? 30)
        return Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    StatInline(title: "Laufen/Rad", value: Fmt.num(km, 1) + " km")
                    StatInline(title: "Trainingszeit", value: Fmt.hm(time) + " h")
                    StatInline(title: "Krafteinheiten", value: "\(strength)")
                }
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(0..<7, id: \.self) { i in
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(days[i].2?.color ?? Theme.track)
                                .frame(height: max(4, 60 * days[i].1 / maxMin))
                            Text(days[i].0).font(.caption2.weight(.bold)).foregroundStyle(Theme.muted)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 80, alignment: .bottom)
            }
        }
    }

    @ViewBuilder private var list: some View {
        if filtered.isEmpty {
            Card { Text("Keine Einheiten gefunden.").font(.footnote).foregroundStyle(Theme.soft) }
        } else {
            VStack(spacing: 0) {
                ForEach(filtered) { w in
                    NavigationLink { WorkoutDetailView(item: w) } label: { WorkoutRow(item: w) }
                        .buttonStyle(.press)
                    if w.id != filtered.last?.id { Divider().overlay(Theme.line) }
                }
            }
            .padding(.horizontal, 16)
            .background(CardBackground(radius: 22))
        }
    }
}

/// Laufen: Plan oder Vorlagen, als eigene Seite
struct RunningHomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(DataStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                PlanOverview()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .screenBackground()
        .navigationTitle(store.data.plan == nil ? "Laufplan" : "Laufen")
        .navigationBarTitleDisplayMode(.large)
    }
}

/// Kraft: Routinen, Programme, Verlauf, als eigene Seite
struct StrengthPageView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                StrengthHomeView()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .screenBackground(Theme.warn)
        .navigationTitle("Kraft")
        .navigationBarTitleDisplayMode(.large)
    }
}

struct WorkoutDetailView: View {
    @Environment(AppModel.self) private var model
    let item: WorkoutItem
    @State private var detail: WorkoutDetail?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(Fmt.day(item.start) + " · " + Fmt.time(item.start)).font(.footnote.weight(.semibold)).foregroundStyle(Theme.muted)
                    HStack(spacing: 6) {
                        Badge(text: item.kind.label, color: item.kind.color)
                        if item.indoor { Badge(text: "DRINNEN", color: Theme.muted) }
                    }
                }
                .padding(.horizontal, 4)

                if let d = detail, d.route.count > 1 { RouteMap(route: d.route) }
                stats
                if let d = detail {
                    if d.profile.count > 3 { profileCard(d) }
                    if !d.hr.isEmpty { hrCard(d) }
                    if d.zones.reduce(0, +) > 0 { zonesCard(d) }
                    if !d.splits.isEmpty { splitsCard(d) }
                    if d.power != nil || d.cadence != nil || d.groundContact != nil { dynamicsCard(d) }
                    comparison
                } else {
                    ProgressView().frame(maxWidth: .infinity).padding(30)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
        }
        .screenBackground()
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.large)
        .task { detail = await model.health.detail(for: item, maxHR: model.maxHR) }
    }

    private var stats: some View {
        var tiles: [(String, String)] = []
        if let d = item.distance, d > 200 { tiles.append(("Distanz", Fmt.km(d))) }
        tiles.append(("Zeit", Fmt.clock(item.duration)))
        if let p = item.pace, item.kind == .endurance { tiles.append(("Ø Pace", Fmt.pace(p) + " /km")) }
        if let hr = item.avgHR { tiles.append(("Ø Puls", "\(Int(hr)) bpm")) }
        if let mx = item.maxHR { tiles.append(("Max. Puls", "\(Int(mx)) bpm")) }
        if let e = item.elevation, e > 1 { tiles.append(("Höhenmeter", "↑ \(Int(e)) m")) }
        if let k = item.energy { tiles.append(("Kalorien", "\(Int(k)) kcal")) }
        tiles.append(("Belastung", Fmt.num(Strain.workout(item, rhr: model.restingHR, maxHR: model.maxHR, female: model.female), 1)))
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            ForEach(tiles, id: \.0) { t in StatTile(title: t.0, value: t.1) }
        }
    }

    private func profileCard(_ d: WorkoutDetail) -> some View {
        let minAlt = (d.profile.map(\.altitude).min() ?? 0) - 3
        let maxAlt = (d.profile.map(\.altitude).max() ?? 0) + 3
        return Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Höhenprofil").font(.subheadline.weight(.bold))
                    Spacer()
                    Text("\(Int(minAlt + 3))–\(Int(maxAlt - 3)) m").font(.caption).foregroundStyle(Theme.muted)
                }
                Chart(d.profile) { p in
                    AreaMark(x: .value("km", p.distance / 1000), yStart: .value("min", minAlt), yEnd: .value("Höhe", p.altitude))
                        .foregroundStyle(Theme.accent.opacity(0.25))
                    LineMark(x: .value("km", p.distance / 1000), y: .value("Höhe", p.altitude))
                        .foregroundStyle(Theme.accent)
                }
                .chartYScale(domain: minAlt...maxAlt)
                .chartYAxis(.hidden)
                .frame(height: 100)
            }
        }
    }

    private func hrCard(_ d: WorkoutDetail) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Text("Herzfrequenz").font(.subheadline.weight(.bold))
                Chart(d.hr) { p in
                    LineMark(x: .value("Zeit", p.date), y: .value("Puls", p.bpm))
                        .foregroundStyle(Theme.bad)
                        .interpolationMethod(.catmullRom)
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .chartXAxis(.hidden)
                .frame(height: 110)
            }
        }
    }

    private func zonesCard(_ d: WorkoutDetail) -> some View {
        let total = max(1, d.zones.reduce(0, +))
        let colors = [Theme.sleep, Theme.good, Theme.accent, Theme.warn, Theme.bad]
        return Card {
            VStack(alignment: .leading, spacing: 9) {
                Text("Herzfrequenz-Zonen").font(.subheadline.weight(.bold))
                ForEach(0..<5, id: \.self) { i in
                    HStack(spacing: 10) {
                        Text("Z\(i + 1)").font(.footnote.weight(.bold)).foregroundStyle(Theme.muted).frame(width: 26, alignment: .leading)
                        Bar(fraction: d.zones[i] / total, color: colors[i], height: 10)
                        Text(Fmt.clock(d.zones[i])).font(.footnote.weight(.bold)).frame(width: 52, alignment: .trailing)
                    }
                }
                Text("Zonen nach \(Int(model.maxHR)) bpm Maximalpuls, anpassbar in den Einstellungen.").font(.caption).foregroundStyle(Theme.muted)
            }
        }
    }

    private func splitsCard(_ d: WorkoutDetail) -> some View {
        let paces = d.splits.map(\.pace)
        let fastest = paces.min() ?? 1, slowest = paces.max() ?? 1
        return Card {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("KM").frame(width: 34, alignment: .leading)
                    Text("PACE")
                    Spacer()
                    Text("PULS").frame(width: 44, alignment: .trailing)
                    Text("HM").frame(width: 36, alignment: .trailing)
                }
                .font(.caption2.weight(.heavy)).foregroundStyle(Theme.muted)
                ForEach(d.splits) { s in
                    HStack(spacing: 8) {
                        Text(s.distance < 990 ? Fmt.num(Double(s.id - 1) + s.distance / 1000, 1) : "\(s.id)")
                            .font(.footnote.weight(.bold)).frame(width: 34, alignment: .leading)
                        let f = slowest > fastest ? 1 - (s.pace - fastest) / (slowest - fastest) : 1
                        Bar(fraction: 0.45 + 0.55 * f, color: s.pace == fastest ? Theme.accent : Theme.accent.opacity(0.45), height: 8)
                        Text(Fmt.pace(s.pace)).font(.footnote.weight(.heavy)).frame(width: 40, alignment: .trailing)
                        Text(s.avgHR.map { "\(Int($0))" } ?? "–").font(.footnote).frame(width: 44, alignment: .trailing)
                        Text("+\(Int(s.gain))").font(.footnote).foregroundStyle(Theme.muted).frame(width: 36, alignment: .trailing)
                    }
                }
            }
        }
    }

    private func dynamicsCard(_ d: WorkoutDetail) -> some View {
        var tiles: [(String, String)] = []
        if let c = d.cadence { tiles.append(("Kadenz", "\(Int(c)) spm")) }
        if let p = d.power { tiles.append(("Laufleistung", "\(Int(p)) W")) }
        if let g = d.groundContact { tiles.append(("Bodenkontaktzeit", "\(Int(g)) ms")) }
        if let v = d.verticalOsc { tiles.append(("Vertikale Bewegung", Fmt.num(v, 1) + " cm")) }
        if let s = d.stride { tiles.append(("Schrittlänge", Fmt.num(s, 2) + " m")) }
        return Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("Laufdynamik").font(.subheadline.weight(.bold))
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 12) {
                    ForEach(tiles, id: \.0) { t in StatInline(title: t.0, value: t.1) }
                }
            }
        }
    }

    @ViewBuilder private var comparison: some View {
        if item.activity == .running, let d = item.distance, let p = item.pace {
            let similar = model.workouts.filter {
                $0.id != item.id && $0.activity == .running && $0.start < item.start &&
                abs(($0.distance ?? 0) - d) < d * 0.08
            }
            if similar.count >= 2 {
                let avgPace = similar.compactMap(\.pace).reduce(0, +) / Double(similar.count)
                let diff = avgPace - p
                Hint(icon: "chart.line.uptrend.xyaxis", title: "Vergleich mit ähnlichen Läufen",
                     text: "\(similar.count) Läufe mit ähnlicher Distanz. Heute \(Fmt.num(abs(diff))) s/km \(diff >= 0 ? "schneller" : "langsamer") als dein Schnitt dort.",
                     color: diff >= 0 ? Theme.good : Theme.warn)
            }
        }
    }
}

struct RouteMap: View {
    let route: [CLLocation]

    var body: some View {
        let coords = route.map(\.coordinate)
        Map(initialPosition: .automatic, interactionModes: [.zoom, .pan]) {
            MapPolyline(coordinates: coords).stroke(Theme.accent, lineWidth: 4)
            Annotation("Start", coordinate: coords[0]) {
                Circle().fill(Theme.good).frame(width: 14, height: 14).overlay(Circle().stroke(Color.black, lineWidth: 3))
            }
            Annotation("Ziel", coordinate: coords[coords.count - 1]) {
                Circle().fill(Theme.bad).frame(width: 12, height: 12).overlay(Circle().stroke(Color.black, lineWidth: 3))
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
        .frame(height: 280)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}
