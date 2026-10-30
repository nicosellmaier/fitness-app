import SwiftUI

// MARK: Daten

struct MobilityStep: Identifiable, Hashable {
    var id: String { name + (side ?? "") }
    let name: String
    let seconds: Int
    let cue: String
    var side: String? = nil
}

struct MobilityRoutine: Identifiable {
    let id: String
    let name: String
    let icon: String
    let regions: [BodyRegion]
    let when: String
    let steps: [MobilityStep]

    var minutes: Int { Int(ceil(Double(steps.reduce(0) { $0 + $1.seconds }) / 60)) }

    static func both(_ name: String, _ sec: Int, _ cue: String) -> [MobilityStep] {
        [MobilityStep(name: name, seconds: sec, cue: cue, side: "links"), MobilityStep(name: name, seconds: sec, cue: cue, side: "rechts")]
    }

    static let all: [MobilityRoutine] = [
        MobilityRoutine(id: "runner", name: "Läufer-Mobility", icon: "figure.run", regions: [.hip, .knee, .ankle, .achilles], when: "Nach dem Lauf oder abends",
                        steps: both("Hüftbeuger-Dehnung im Ausfallschritt", 45, "Becken nach vorn kippen, Gesäß anspannen. Zug vorn an der Hüfte.")
                            + both("Wadendehnung an der Wand", 40, "Ferse am Boden, Knie gestreckt. Dann 20 s mit gebeugtem Knie für den Soleus.")
                            + both("Oberschenkelvorderseite im Stand", 40, "Knie zeigen zueinander, Becken aufrecht.")
                            + [MobilityStep(name: "Tiefe Hocke", seconds: 60, cue: "Fersen am Boden, Ellenbogen drücken Knie nach außen. Atmen.")]
                            + both("Taube (Gesäß)", 60, "Schienbein quer, Oberkörper nach vorn sinken lassen.")
                            + [MobilityStep(name: "Fußsohle ausrollen", seconds: 60, cue: "Mit Ball oder Flasche, 30 s pro Fuß.")]),
        MobilityRoutine(id: "hip_back", name: "Hüfte & unterer Rücken", icon: "figure.cooldown", regions: [.hip, .lowerBack], when: "Nach langem Sitzen, an Ruhetagen",
                        steps: [MobilityStep(name: "Katze-Kuh", seconds: 60, cue: "Langsam, mit der Atmung. Jeden Wirbel einzeln bewegen.")]
                            + both("90/90-Hüftrotation", 45, "Vorderes und hinteres Bein im rechten Winkel. Oberkörper über das vordere Schienbein.")
                            + both("Weltgrößte Dehnung", 45, "Ausfallschritt, Ellenbogen zum Boden, dann Arm zur Decke drehen.")
                            + [MobilityStep(name: "Kindhaltung", seconds: 60, cue: "Arme lang, Gesäß Richtung Fersen. Tief in den Rücken atmen."),
                               MobilityStep(name: "Rückenlage, Knie zur Brust", seconds: 45, cue: "Beide Knie umfassen, leicht schaukeln."),
                               MobilityStep(name: "Glute Bridge halten", seconds: 45, cue: "Fersen drücken, Gesäß fest, Rippen unten. Aktiv statt passiv.")]),
        MobilityRoutine(id: "shoulder", name: "Schulter & Nacken", icon: "figure.arms.open", regions: [.shoulder, .neck, .upperBack], when: "Nach Oberkörpertraining oder Schreibtisch",
                        steps: [MobilityStep(name: "Schulterkreisen", seconds: 30, cue: "Groß und langsam, vorwärts und rückwärts."),
                                MobilityStep(name: "Brustöffner im Türrahmen", seconds: 45, cue: "Unterarme am Rahmen, einen Schritt nach vorn. Zug in der Brust.")]
                            + both("Nacken seitlich", 30, "Ohr zur Schulter, andere Hand zieht sanft nach unten.")
                            + both("Schulter quer vor der Brust", 30, "Arm quer, mit dem anderen heranziehen. Schulter unten lassen.")
                            + [MobilityStep(name: "Wandengel", seconds: 45, cue: "Rücken und Arme an der Wand, Arme hoch und runter ohne Kontakt zu verlieren."),
                               MobilityStep(name: "Brustwirbelsäule auf der Rolle", seconds: 60, cue: "Rolle quer unter den Schulterblättern, Hände hinter dem Kopf, nach hinten strecken.")]),
        MobilityRoutine(id: "calf", name: "Waden & Achillessehne", icon: "figure.walk", regions: [.ankle, .achilles, .foot], when: "Täglich bei Achillesproblemen",
                        steps: both("Wadenheben auf der Stufe, langsam", 60, "3 s hoch, 3 s runter, Ferse tief. Das ist Reha, nicht Dehnen.")
                            + both("Soleus-Dehnung mit gebeugtem Knie", 40, "Knie Richtung Wand, Ferse unten.")
                            + both("Sprunggelenk kreisen", 30, "Groß, in beide Richtungen.")
                            + [MobilityStep(name: "Zehen greifen", seconds: 45, cue: "Handtuch mit den Zehen heranziehen. Kräftigt das Fußgewölbe."),
                               MobilityStep(name: "Tibialis-Heben", seconds: 45, cue: "Rücken an der Wand, Fersen vor, Zehen anziehen. Schützt das Schienbein.")]),
        MobilityRoutine(id: "evening", name: "Abend-Dehnen", icon: "moon.stars.fill", regions: [], when: "30 Minuten vor dem Schlafen",
                        steps: [MobilityStep(name: "Langsames Atmen", seconds: 60, cue: "4 s ein, 6 s aus. Nervensystem runterfahren."),
                                MobilityStep(name: "Vorbeuge im Sitzen", seconds: 60, cue: "Rücken lang, Knie dürfen leicht gebeugt sein.")]
                            + both("Taube", 60, "Lang halten, nichts erzwingen.")
                            + [MobilityStep(name: "Rückenlage, Beine an der Wand", seconds: 120, cue: "Arme locker, Augen zu. Einfach liegen bleiben."),
                               MobilityStep(name: "Drehdehnlage", seconds: 60, cue: "Knie zur Seite, Schultern am Boden, 30 s pro Seite.")]),
        MobilityRoutine(id: "warmup", name: "Aufwärmen vor Kraft", icon: "flame.fill", regions: [], when: "5 Minuten vor der ersten Übung",
                        steps: [MobilityStep(name: "Hampelmänner oder Seilspringen", seconds: 60, cue: "Puls hoch, Körper warm."),
                                MobilityStep(name: "Armkreisen und Beinschwünge", seconds: 45, cue: "Dynamisch, nicht halten."),
                                MobilityStep(name: "Tiefe Hocke mit Rotation", seconds: 45, cue: "Unten ankommen, Arm zur Decke, Seite wechseln."),
                                MobilityStep(name: "Ausfallschritte rückwärts", seconds: 45, cue: "Kontrolliert, Oberkörper aufrecht."),
                                MobilityStep(name: "Band-Pull-Aparts oder Liegestütze", seconds: 45, cue: "Schultern aktivieren, 15 bis 20 Wiederholungen.")]),
    ]

    /// Passende Routine für eine Verletzung
    static func recommended(for region: BodyRegion) -> MobilityRoutine? {
        all.first { $0.regions.contains(region) }
    }
}

// MARK: Liste

struct MobilityListView: View {
    @Environment(DataStore.self) private var store

    var body: some View {
        let active = store.data.injuries.filter(\.active)
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let i = active.first, let r = MobilityRoutine.recommended(for: i.region) {
                    NavigationLink { MobilityPlayerView(routine: r) } label: {
                        Hint(icon: "bandage.fill", title: "Empfohlen bei \(i.title): \(r.name)", text: "Täglich \(r.minutes) Minuten. Sanft, schmerzfrei, regelmäßig.", color: Theme.bad)
                    }
                    .buttonStyle(.press)
                }
                ForEach(MobilityRoutine.all) { r in
                    NavigationLink { MobilityPlayerView(routine: r) } label: {
                        HStack(spacing: 12) {
                            Image(systemName: r.icon).font(.title3.weight(.bold)).foregroundStyle(Theme.bg)
                                .frame(width: 44, height: 44).background(Theme.good, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(r.name).font(.subheadline.weight(.bold))
                                Text("\(r.minutes) min · \(r.steps.count) Übungen · \(r.when)").font(.caption).foregroundStyle(Theme.muted).lineLimit(2).multilineTextAlignment(.leading)
                            }
                            Spacer()
                            Chevron()
                        }
                        .padding(14)
                        .background(CardBackground(radius: 20))
                    }
                    .buttonStyle(.press)
                }
                Text("Dehnen macht nicht schneller, aber Mobility hält Hüfte, Sprunggelenk und Brustwirbelsäule beweglich, und genau dort entstehen die meisten Laufverletzungen. Kräftigende Übungen (Wadenheben, Tibialis) sind Reha und Prävention zugleich.")
                    .font(.caption).foregroundStyle(Theme.muted).padding(.horizontal, 4)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
        }
        .screenBackground(Theme.good)
        .navigationTitle("Mobility")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: Abspielen

struct MobilityPlayerView: View {
    let routine: MobilityRoutine
    @State private var index = 0
    @State private var remaining = 0
    @State private var running = false
    @State private var finished = false
    @Environment(\.dismiss) private var dismiss

    private var step: MobilityStep { routine.steps[min(index, routine.steps.count - 1)] }
    private var total: Int { routine.steps.reduce(0) { $0 + $1.seconds } }
    private var elapsed: Int { routine.steps.prefix(index).reduce(0) { $0 + $1.seconds } + (step.seconds - remaining) }

    var body: some View {
        VStack(spacing: 20) {
            if finished {
                Spacer()
                Image(systemName: "checkmark.seal.fill").font(.system(size: 60)).foregroundStyle(Theme.good).symbolEffect(.bounce, options: .nonRepeating)
                Text("Fertig").font(.title.weight(.heavy))
                Text("\(routine.minutes) Minuten für deinen Körper. Morgen wieder.").font(.footnote).foregroundStyle(Theme.soft)
                Spacer()
                Button { dismiss() } label: { Text("Schließen").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 15).background(Theme.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous)).foregroundStyle(Theme.bg) }
                    .buttonStyle(.press)
            } else {
                Bar(fraction: Double(elapsed) / Double(max(1, total)), color: Theme.good, height: 6)
                Text("\(index + 1) von \(routine.steps.count) · noch \(Fmt.clock(Double(total - elapsed)))").font(.caption.weight(.semibold)).foregroundStyle(Theme.muted)
                Spacer()
                ZStack {
                    Ring(progress: Double(step.seconds - remaining) / Double(max(1, step.seconds)), color: Theme.good, lineWidth: 14)
                    VStack(spacing: 2) {
                        Text("\(remaining)").font(.system(size: 64, weight: .heavy)).monospacedDigit().contentTransition(.numericText())
                        Text("Sekunden").font(.caption.weight(.semibold)).foregroundStyle(Theme.muted)
                    }
                }
                .frame(width: 220, height: 220)
                VStack(spacing: 6) {
                    if let s = step.side { Badge(text: s.uppercased(), color: Theme.good) }
                    Text(step.name).font(.title2.weight(.heavy)).multilineTextAlignment(.center)
                    Text(step.cue).font(.subheadline).foregroundStyle(Theme.soft).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 8)
                if index + 1 < routine.steps.count {
                    Text("Danach: \(routine.steps[index + 1].name)" + (routine.steps[index + 1].side.map { " (\($0))" } ?? "")).font(.caption).foregroundStyle(Theme.muted)
                }
                Spacer()
                HStack(spacing: 12) {
                    Button { previous() } label: { Image(systemName: "backward.fill").font(.headline).frame(width: 56, height: 56).background(CardBackground(radius: 18)) }
                        .buttonStyle(.press).disabled(index == 0)
                    Button { running.toggle() } label: {
                        Label(running ? "Pause" : (remaining == step.seconds && index == 0 ? "Start" : "Weiter"), systemImage: running ? "pause.fill" : "play.fill")
                            .font(.headline).frame(maxWidth: .infinity).frame(height: 56)
                            .background(Theme.accent, in: RoundedRectangle(cornerRadius: 18, style: .continuous)).foregroundStyle(Theme.bg)
                    }
                    .buttonStyle(.press)
                    Button { next() } label: { Image(systemName: "forward.fill").font(.headline).frame(width: 56, height: 56).background(CardBackground(radius: 18)) }
                        .buttonStyle(.press)
                }
                .foregroundStyle(Theme.text)
            }
        }
        .padding(20)
        .background(ScreenGlow(color: Theme.good))
        .navigationTitle(routine.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { remaining = step.seconds }
        .task(id: running) {
            guard running else { return }
            while running && !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard running else { break }
                if remaining > 1 {
                    remaining -= 1
                    if remaining <= 3 { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
                } else {
                    next()
                }
            }
        }
        .sensoryFeedback(.success, trigger: index)
    }

    private func next() {
        if index + 1 < routine.steps.count {
            withAnimation(.snappy) { index += 1; remaining = step.seconds }
        } else {
            running = false
            withAnimation(.snappy) { finished = true }
        }
    }

    private func previous() {
        guard index > 0 else { return }
        withAnimation(.snappy) { index -= 1; remaining = step.seconds }
    }
}
