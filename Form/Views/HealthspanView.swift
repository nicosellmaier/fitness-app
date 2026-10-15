import SwiftUI

struct HealthspanCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationLink { HealthspanView() } label: {
            Card {
                if let h = model.healthspan {
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("FORM-ALTER").font(.caption.weight(.heavy)).foregroundStyle(Theme.muted)
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(Fmt.num(h.formAge, 1)).font(.system(size: 34, weight: .heavy))
                                Text("Jahre").font(.footnote).foregroundStyle(Theme.muted)
                            }
                            Text(deltaText(h)).font(.footnote.weight(.semibold)).foregroundStyle(h.delta <= 0 ? Theme.good : Theme.warn)
                        }
                        Spacer()
                        if let p = h.pace { PaceGauge(pace: p).frame(width: 96, height: 60) }
                        Image(systemName: "chevron.right").foregroundStyle(Theme.muted)
                    }
                } else {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Form-Alter").font(.headline)
                            Text("Braucht mindestens 3 Wochen Daten aus Schlaf, Schritten und Training.").font(.footnote).foregroundStyle(Theme.soft)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(Theme.muted)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func deltaText(_ h: Healthspan) -> String {
        let d = h.delta
        if abs(d) < 0.3 { return "So alt wie du bist" }
        return Fmt.num(abs(d), 1) + (d < 0 ? " Jahre jünger als dein Alter" : " Jahre älter als dein Alter")
    }
}

/// Tempo des Alterns: −1x bis 3x, 1x entspricht einem Jahr pro Jahr
struct PaceGauge: View {
    let pace: Double

    var body: some View {
        let f = (pace + 1) / 4
        VStack(spacing: 2) {
            ZStack {
                Circle().trim(from: 0.5, to: 1).stroke(Theme.track, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                Circle().trim(from: 0.5, to: 0.5 + 0.5 * max(0.02, min(1, f)))
                    .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
            }
            .frame(width: 84, height: 84)
            .offset(y: 21)
            .frame(height: 42, alignment: .top)
            .clipped()
            Text(Fmt.num(pace, 1) + "×").font(.subheadline.weight(.heavy)).foregroundStyle(color)
        }
    }

    private var color: Color { pace < 0.9 ? Theme.good : pace <= 1.1 ? Theme.accent : Theme.warn }
}

struct HealthspanView: View {
    @Environment(AppModel.self) private var model
    @Environment(DataStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let h = model.healthspan {
                    header(h)
                    SectionHeader("Was dein Alter bewegt")
                    VStack(spacing: 0) {
                        ForEach(h.metrics) { m in
                            MetricYearsRow(metric: m)
                            if m.id != h.metrics.last?.id { Divider().overlay(Theme.line) }
                        }
                    }
                    .padding(.horizontal, 14)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    SectionHeader("Diese Woche")
                    WeeklyGoals()
                    method(h)
                } else {
                    Card {
                        Text("Für das Form-Alter braucht die App mindestens 21 Tage Daten. Trag die Watch nachts und tagsüber, dann erscheint der Wert automatisch.")
                            .font(.footnote).foregroundStyle(Theme.soft)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
        }
        .screenBackground()
        .navigationTitle("Form-Alter")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func header(_ h: Healthspan) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("FORM-ALTER").font(.caption.weight(.heavy)).foregroundStyle(Theme.muted)
                    Text(Fmt.num(h.formAge, 1)).font(.system(size: 52, weight: .heavy))
                    Text("Kalenderalter \(Int(h.chronological)) · \(h.delta <= 0 ? "−" : "+")\(Fmt.num(abs(h.delta), 1)) Jahre")
                        .font(.footnote.weight(.semibold)).foregroundStyle(h.delta <= 0 ? Theme.good : Theme.warn)
                }
                Spacer()
                if let p = h.pace {
                    VStack(spacing: 2) {
                        PaceGauge(pace: p).frame(width: 96, height: 64)
                        Text("Tempo des Alterns").font(.caption2.weight(.semibold)).foregroundStyle(Theme.muted)
                    }
                }
            }
            if let p = h.pace {
                Text(paceText(p)).font(.footnote).foregroundStyle(Theme.soft).fixedSize(horizontal: false, vertical: true)
            }
            Text("Basiert auf \(h.daysOfData) Tagen. Aktualisiert sich täglich.").font(.caption).foregroundStyle(Theme.muted)
        }
        .padding(18)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private func paceText(_ p: Double) -> String {
        if p < 0.5 { return "Deine letzten 30 Tage sind deutlich besser als dein Halbjahresschnitt. Bleibst du so, wird dein Form-Alter jünger." }
        if p < 0.95 { return "Du alterst gerade langsamer als der Kalender. Die letzten 30 Tage ziehen dein Form-Alter nach unten." }
        if p <= 1.05 { return "Du alterst im Takt des Kalenders. Deine letzten 30 Tage entsprechen deinem Halbjahresschnitt." }
        return "Die letzten 30 Tage waren schwächer als dein Halbjahresschnitt. Schau unten, welcher Faktor gerade Jahre kostet."
    }

    private func method(_ h: Healthspan) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 6) {
                Text("So wird gerechnet").font(.subheadline.weight(.bold))
                Text("Jeder Faktor wird mit Daten aus großen Studien zur Gesamtsterblichkeit in ein relatives Risiko übersetzt, zum Beispiel 13 % weniger Risiko je 3,5 ml/kg/min VO2max (Kodama 2009) oder der Schritte-Effekt aus 15 Kohorten (Paluch 2022). Weil sich die Faktoren überlappen, wird die Summe um 40 % gekürzt. Da sich das Sterberisiko von Erwachsenen etwa alle 8 Jahre verdoppelt (Gompertz), lässt sich das Risiko in Lebensjahre umrechnen. Das Ergebnis ist eine Orientierung für dein Verhalten, keine medizinische Diagnose.")
                    .font(.caption).foregroundStyle(Theme.soft)
            }
        }
    }
}

struct MetricYearsRow: View {
    let metric: HealthspanMetric
    @State private var open = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button { withAnimation(.snappy) { open.toggle() } } label: {
                HStack(spacing: 10) {
                    Image(systemName: metric.icon).font(.footnote.weight(.bold)).foregroundStyle(color).frame(width: 22)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(metric.name).font(.subheadline.weight(.semibold))
                        Text(metric.value + " · Ziel " + metric.target).font(.caption).foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    Text(yearsText).font(.subheadline.weight(.heavy)).foregroundStyle(color).monospacedDigit()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            YearsBar(years: metric.years).frame(height: 6).padding(.leading, 32)
            if open {
                Text(metric.tip).font(.caption).foregroundStyle(Theme.soft).padding(.leading, 32).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 10)
    }

    private var yearsText: String {
        abs(metric.years) < 0.05 ? "±0" : (metric.years < 0 ? "−" : "+") + Fmt.num(abs(metric.years), 1) + " J"
    }

    private var color: Color { metric.years < -0.05 ? Theme.good : metric.years > 0.05 ? Theme.warn : Theme.muted }
}

/// Balken ab der Mitte: links jünger, rechts älter
struct YearsBar: View {
    let years: Double

    var body: some View {
        GeometryReader { geo in
            let half = geo.size.width / 2
            let w = min(half, half * abs(years) / 3)
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.track)
                Rectangle().fill(Theme.muted.opacity(0.5)).frame(width: 1).offset(x: half)
                Capsule().fill(years < 0 ? Theme.good : Theme.warn)
                    .frame(width: max(2, w))
                    .offset(x: years < 0 ? half - w : half)
            }
        }
    }
}

struct WeeklyGoals: View {
    @Environment(AppModel.self) private var model
    @Environment(DataStore.self) private var store

    var body: some View {
        let cal = Calendar.current
        let ws = PlanGenerator.weekStart(.now)
        let days = (0..<7).map { cal.addDays($0, to: ws) }.filter { $0 <= .now }
        let steps = days.compactMap { model.stepsByDay[$0] }
        let avgSteps: Double = steps.isEmpty ? 0 : steps.reduce(0, +) / Double(steps.count)
        let ex = days.compactMap { model.exerciseByDay[$0] }.reduce(0, +)
        let weekWorkouts = model.workouts.filter { $0.start >= ws }
        let vig = weekWorkouts.filter { $0.kind != .strength && ($0.avgHR ?? 0) >= 0.77 * model.maxHR }.reduce(0.0) { $0 + $1.duration / 60 }
        var strength = weekWorkouts.filter { $0.kind == .strength }.reduce(0.0) { $0 + $1.duration / 60 }
        let sDays = Set(weekWorkouts.filter { $0.kind == .strength }.map { cal.startOfDay(for: $0.start) })
        strength += store.data.sessions.filter { $0.start >= ws && !sDays.contains(cal.startOfDay(for: $0.start)) }
            .reduce(0.0) { $0 + (($1.end ?? $1.start).timeIntervalSince($1.start) / 60) }
        let nights = model.nights.filter { $0.wakeDay >= ws }
        let sleepH: Double = nights.isEmpty ? 0 : nights.map(\.asleep).reduce(0, +) / Double(nights.count) / 3600
        return VStack(spacing: 8) {
            GoalRow(icon: "figure.run", title: "Aktive Minuten", detail: "Intensive zählen doppelt", value: ex + vig, goal: 300, unit: "min")
            GoalRow(icon: "dumbbell.fill", title: "Krafttraining", detail: "30–60 min bringen am meisten", value: strength, goal: 60, unit: "min")
            GoalRow(icon: "figure.walk", title: "Schritte pro Tag", detail: "Durchschnitt dieser Woche", value: avgSteps, goal: 8000, unit: "")
            GoalRow(icon: "bed.double.fill", title: "Schlaf pro Nacht", detail: "Durchschnitt dieser Woche", value: sleepH, goal: 7.5, unit: "h", digits: 1)
        }
    }
}

struct GoalRow: View {
    let icon: String
    let title: String
    let detail: String
    let value: Double
    let goal: Double
    let unit: String
    var digits = 0

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Ring(progress: value / goal, color: value >= goal ? Theme.good : Theme.accent, lineWidth: 5)
                Image(systemName: icon).font(.caption.weight(.bold)).foregroundStyle(Theme.text)
            }
            .frame(width: 38, height: 38)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.subheadline.weight(.bold))
                Text(detail).font(.caption).foregroundStyle(Theme.muted)
            }
            Spacer()
            Text("\(Fmt.num(value, digits)) / \(Fmt.num(goal, digits)) \(unit)").font(.footnote.weight(.heavy)).monospacedDigit()
        }
        .padding(12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
