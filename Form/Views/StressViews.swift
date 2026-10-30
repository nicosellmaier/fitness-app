import SwiftUI
import Charts

struct StressCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationLink { StressView() } label: {
            Card {
                if let s = model.stressToday {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("STRESS HEUTE").font(.caption.weight(.heavy)).foregroundStyle(Theme.muted)
                                HStack(alignment: .firstTextBaseline, spacing: 6) {
                                    Text(Fmt.num(s.current ?? s.average ?? 0, 1)).font(.title.weight(.heavy))
                                    Text(StressDay.label(s.current ?? s.average ?? 0)).font(.subheadline.weight(.bold))
                                        .foregroundStyle(StressDay.color(s.current ?? s.average ?? 0))
                                }
                            }
                            Spacer()
                            Text("\(Fmt.num(s.highMinutes)) min hoch").font(.caption.weight(.semibold)).foregroundStyle(Theme.muted)
                            Image(systemName: "chevron.right").foregroundStyle(Theme.muted)
                        }
                        StressChart(points: s.points).frame(height: 70)
                    }
                } else {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Stress").font(.headline)
                            Text("Braucht ein paar Tage Pulsdaten von der Watch.").font(.footnote).foregroundStyle(Theme.soft)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(Theme.muted)
                    }
                }
            }
        }
        .buttonStyle(.press)
    }
}

struct StressChart: View {
    let points: [StressPoint]
    var showAxis = false

    var body: some View {
        Chart(points) { p in
            AreaMark(x: .value("Zeit", p.date), y: .value("Stress", p.level))
                .foregroundStyle(LinearGradient(colors: [Theme.bad.opacity(0.55), Theme.warn.opacity(0.35), Theme.good.opacity(0.15)], startPoint: .top, endPoint: .bottom))
                .interpolationMethod(.monotone)
            LineMark(x: .value("Zeit", p.date), y: .value("Stress", p.level))
                .foregroundStyle(Theme.warn).lineStyle(StrokeStyle(lineWidth: 1.5)).interpolationMethod(.monotone)
        }
        .chartYScale(domain: 0...3)
        .chartYAxis(showAxis ? .automatic : .hidden)
        .chartXAxis(showAxis ? .automatic : .hidden)
    }
}

struct StressView: View {
    @Environment(AppModel.self) private var model
    @State private var breathing: BreathMode?

    var body: some View {
        let cal = Calendar.current
        let week: [(Date, Double)] = (0..<7).reversed().compactMap { i in
            let d = cal.addDays(-i, to: cal.startOfDay(for: .now))
            guard let s = Stress.compute(hr: model.hr, steps: model.stepSamples, workouts: model.workouts, nights: model.nights, day: d),
                  let a = s.average else { return nil }
            return (d, a)
        }
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let s = model.stressToday {
                    Card {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                StatInline(title: "Jetzt", value: s.current.map { Fmt.num($0, 1) } ?? "–")
                                StatInline(title: "Schnitt heute", value: s.average.map { Fmt.num($0, 1) } ?? "–")
                                StatInline(title: "Zeit hoch", value: Fmt.num(s.highMinutes) + " min")
                            }
                            StressChart(points: s.points, showAxis: true).frame(height: 170)
                            Text("0 heißt Puls wie in deinen ruhigsten Momenten (\(Fmt.num(s.calmHR)) bpm), 3 heißt so hoch wie in deinen angespanntesten ruhigen Phasen (\(Fmt.num(s.highHR)) bpm). Workouts, Schlaf und Phasen mit Schritten werden ausgeblendet.")
                                .font(.caption).foregroundStyle(Theme.soft)
                        }
                    }
                } else {
                    Card { Text("Noch zu wenig Pulsdaten. Die Watch misst tagsüber alle paar Minuten, nach ein paar Tagen gibt es hier deinen Verlauf.").font(.footnote).foregroundStyle(Theme.soft) }
                }

                SectionHeader("Runterkommen")
                ForEach(BreathMode.allCases) { m in
                    Button { breathing = m } label: {
                        HStack(spacing: 12) {
                            Image(systemName: m.icon).font(.title3.weight(.bold)).foregroundStyle(Theme.bg)
                                .frame(width: 44, height: 44).background(m.color, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(m.title).font(.subheadline.weight(.bold))
                                Text(m.subtitle).font(.caption).foregroundStyle(Theme.muted).multilineTextAlignment(.leading)
                            }
                            Spacer()
                            Image(systemName: "play.fill").foregroundStyle(Theme.accent)
                        }
                        .padding(12)
                        .background(CardBackground(radius: 18))
                    }
                    .buttonStyle(.press)
                }

                if week.count >= 2 {
                    SectionHeader("Letzte 7 Tage")
                    Card {
                        Chart(week, id: \.0) { p in
                            BarMark(x: .value("Tag", p.0, unit: .day), y: .value("Stress", p.1))
                                .foregroundStyle(StressDay.color(p.1)).cornerRadius(4)
                        }
                        .chartYScale(domain: 0...3)
                        .frame(height: 120)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
        }
        .screenBackground()
        .navigationTitle("Stress")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $breathing) { m in BreathingView(mode: m) }
    }
}

// MARK: Atemübungen

enum BreathMode: String, CaseIterable, Identifiable {
    case sigh, resonance, box

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sigh: return "Zyklisches Seufzen"
        case .resonance: return "Resonanzatmung"
        case .box: return "Box-Atmung"
        }
    }

    var subtitle: String {
        switch self {
        case .sigh: return "Doppelt einatmen, lang ausatmen. In einer Studie besser für die Stimmung als Meditation."
        case .resonance: return "6 Atemzüge pro Minute. Hebt nachweislich die Herzfrequenzvariabilität."
        case .box: return "4 Sekunden ein, halten, aus, halten. Gut zum Fokussieren."
        }
    }

    var icon: String {
        switch self {
        case .sigh: return "wind"
        case .resonance: return "waveform.path.ecg"
        case .box: return "square"
        }
    }

    var color: Color {
        switch self {
        case .sigh: return Theme.sleep
        case .resonance: return Theme.accent
        case .box: return Theme.warn
        }
    }

    /// Phasen: Name, Dauer in Sekunden, Zielgröße des Kreises
    var phases: [(String, Double, CGFloat)] {
        switch self {
        case .sigh: return [("Einatmen", 2.5, 0.85), ("Nochmal kurz ein", 1.0, 1.0), ("Lang ausatmen", 6.0, 0.35)]
        case .resonance: return [("Einatmen", 4.0, 1.0), ("Ausatmen", 6.0, 0.35)]
        case .box: return [("Einatmen", 4.0, 1.0), ("Halten", 4.0, 1.0), ("Ausatmen", 4.0, 0.35), ("Halten", 4.0, 0.35)]
        }
    }
}

struct BreathingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppModel.self) private var model
    let mode: BreathMode
    @State private var minutes = 3
    @State private var running = false
    @State private var phase = ""
    @State private var scale: CGFloat = 0.35
    @State private var startedAt: Date?
    @State private var finished = false

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(spacing: 24) {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.headline).padding(12).background(Theme.card, in: Circle())
                    }
                    .foregroundStyle(Theme.text)
                }
                Text(mode.title).font(.title2.weight(.heavy))
                Spacer()
                ZStack {
                    Circle().fill(mode.color.opacity(0.12)).frame(width: 290, height: 290)
                    Circle().fill(mode.color.opacity(0.85)).frame(width: 290, height: 290).scaleEffect(scale)
                    Text(finished ? "Fertig" : running ? phase : "Bereit").font(.title3.weight(.heavy)).foregroundStyle(Theme.bg)
                        .shadow(color: .black.opacity(0.2), radius: 4)
                }
                if running, let s = startedAt {
                    TimelineView(.periodic(from: .now, by: 1)) { ctx in
                        let left = max(0, Double(minutes * 60) - ctx.date.timeIntervalSince(s))
                        Text(Fmt.clock(left)).font(.title3.weight(.bold)).monospacedDigit().foregroundStyle(Theme.soft)
                    }
                }
                Spacer()
                if !running {
                    if finished {
                        Text("Gespeichert als Achtsamkeitsminuten in Apple Health. Zwei bis drei Durchgänge pro Tag reichen.")
                            .font(.footnote).foregroundStyle(Theme.soft).multilineTextAlignment(.center)
                    }
                    Picker("Dauer", selection: $minutes) {
                        Text("1 min").tag(1)
                        Text("3 min").tag(3)
                        Text("5 min").tag(5)
                    }
                    .pickerStyle(.segmented)
                    Button { start() } label: {
                        Text(finished ? "Nochmal" : "Starten").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 15)
                            .background(mode.color, in: RoundedRectangle(cornerRadius: 16, style: .continuous)).foregroundStyle(Theme.bg)
                    }
                    Text("Durch die Nase einatmen, durch den Mund ausatmen. Wird dir schwindelig, normal weiteratmen.")
                        .font(.caption).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
                } else {
                    Button("Beenden") { running = false }.font(.headline).foregroundStyle(Theme.soft)
                }
            }
            .padding(24)
        }
        .preferredColorScheme(.dark)
    }

    private func start() {
        finished = false
        running = true
        let begin = Date.now
        startedAt = begin
        UIApplication.shared.isIdleTimerDisabled = true
        Task { @MainActor in
            let end = begin.addingTimeInterval(Double(minutes * 60))
            outer: while running && Date.now < end {
                for p in mode.phases {
                    guard running else { break outer }
                    phase = p.0
                    UIImpactFeedbackGenerator(style: p.2 > scale ? .soft : .light).impactOccurred()
                    withAnimation(.easeInOut(duration: p.1)) { scale = p.2 }
                    try? await Task.sleep(nanoseconds: UInt64(p.1 * 1_000_000_000))
                }
            }
            let completed = Date.now
            running = false
            UIApplication.shared.isIdleTimerDisabled = false
            withAnimation(.easeInOut(duration: 1)) { scale = 0.35 }
            if completed.timeIntervalSince(begin) >= 50 {
                finished = true
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                if !model.usingDemo { await model.health.saveMindful(start: begin, end: completed) }
            }
        }
    }
}
