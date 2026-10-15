import WidgetKit
import SwiftUI
import ActivityKit
import AppIntents

// Ansichten der Widgets. Liegen in Shared, damit die App sie auch als Vorschau zeigen kann.

struct SnapEntry: TimelineEntry {
    let date: Date
    let snap: WidgetSnapshot
    let empty: Bool
}

func widgetRecoveryColor(_ score: Int?) -> Color {
    guard let s = score else { return Theme.muted }
    return s >= 67 ? Theme.good : s >= 34 ? Theme.warn : Theme.bad
}

func snapIsToday(_ snap: WidgetSnapshot) -> Bool { Calendar.current.isDateInToday(snap.updated) }

func widgetSleepText(_ m: Int?) -> String {
    guard let m else { return "–" }
    return "\(m / 60):" + String(format: "%02d", m % 60)
}

struct WidgetRing: View {
    let progress: Double
    let color: Color
    var width: CGFloat = 8

    var body: some View {
        ZStack {
            Circle().stroke(Theme.track, lineWidth: width)
            Circle().trim(from: 0, to: max(0.001, min(1, progress)))
                .stroke(color, style: StrokeStyle(lineWidth: width, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

struct EmptyHint: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: "waveform.path.ecg").font(.title3.weight(.bold)).foregroundStyle(Theme.accent)
            Text("Öffne Form").font(.headline).foregroundStyle(Theme.text)
            Text("Dann erscheinen hier deine Werte.").font(.caption).foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: Erholung (klein und Sperrbildschirm)

struct RecoveryWidgetView: View {
    @Environment(\.widgetFamily) private var envFamily
    let entry: SnapEntry
    /// Für die Vorschau in der App, dort gibt es keine Widget-Größe aus der Umgebung
    var fixedFamily: WidgetFamily? = nil

    private var family: WidgetFamily { fixedFamily ?? envFamily }

    var body: some View {
        let s = entry.snap
        let fresh = snapIsToday(s)
        let score = fresh ? s.recovery : nil
        switch family {
        case .accessoryCircular:
            Gauge(value: Double(score ?? 0), in: 0...100) {
                Image(systemName: "heart.fill")
            } currentValueLabel: {
                Text(score.map { "\($0)" } ?? "–").font(.system(.title3, design: .rounded).weight(.bold))
            }
            .gaugeStyle(.accessoryCircular)
            .widgetAccentable()
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Text("Erholung \(score.map { "\($0) %" } ?? "–")").font(.headline).widgetAccentable()
                Text("Schlaf \(widgetSleepText(fresh ? s.sleepMinutes : nil)) h · HRV \(s.hrv.map { "\($0)" } ?? "–")").font(.caption)
                if let t = s.today, Calendar.current.isDateInToday(t.date) {
                    Text(t.done ? "✓ " + t.title : t.title).font(.caption).lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .accessoryInline:
            Text("Erholung \(score.map { "\($0)" } ?? "–") · Schlaf \(widgetSleepText(fresh ? s.sleepMinutes : nil)) h")
        default:
            if entry.empty {
                EmptyHint()
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("ERHOLUNG").font(.caption2.weight(.heavy)).foregroundStyle(Theme.muted)
                        Spacer()
                        if s.demo { Text("DEMO").font(.system(size: 8, weight: .heavy)).foregroundStyle(Theme.sleep) }
                    }
                    ZStack {
                        WidgetRing(progress: Double(score ?? 0) / 100, color: widgetRecoveryColor(score), width: 9)
                        VStack(spacing: -2) {
                            Text(score.map { "\($0)" } ?? "–").font(.system(size: 30, weight: .heavy, design: .rounded)).foregroundStyle(Theme.text)
                            Text("%").font(.caption2.weight(.bold)).foregroundStyle(Theme.muted)
                        }
                    }
                    .frame(width: 78, height: 78)
                    .frame(maxWidth: .infinity)
                    HStack {
                        Label(widgetSleepText(fresh ? s.sleepMinutes : nil), systemImage: "moon.fill").foregroundStyle(Theme.sleep)
                        Spacer()
                        Text("HRV \(s.hrv.map { "\($0)" } ?? "–")").foregroundStyle(Theme.soft)
                    }
                    .font(.caption2.weight(.bold))
                }
            }
        }
    }
}

// MARK: Heute (mittel)

struct TodayWidgetView: View {
    let entry: SnapEntry

    var body: some View {
        let s = entry.snap
        let fresh = snapIsToday(s)
        let score = fresh ? s.recovery : nil
        if entry.empty {
            EmptyHint()
        } else {
            HStack(spacing: 14) {
                VStack(spacing: 4) {
                    ZStack {
                        WidgetRing(progress: Double(score ?? 0) / 100, color: widgetRecoveryColor(score), width: 9)
                        Text(score.map { "\($0)" } ?? "–").font(.system(size: 28, weight: .heavy, design: .rounded)).foregroundStyle(Theme.text)
                    }
                    .frame(width: 80, height: 80)
                    Text(fresh ? (s.recoveryLabel ?? "Erholung") : "Noch kein Wert").font(.caption2.weight(.bold)).foregroundStyle(widgetRecoveryColor(score))
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
                .frame(width: 96)
                VStack(alignment: .leading, spacing: 7) {
                    if let t = s.today, Calendar.current.isDateInToday(t.date) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("HEUTE").font(.caption2.weight(.heavy)).foregroundStyle(Theme.muted)
                            Text((t.done ? "✓ " : "") + t.title).font(.subheadline.weight(.heavy)).foregroundStyle(t.quality ? Theme.accent : Theme.text).lineLimit(2)
                            if !t.detail.isEmpty { Text(t.detail).font(.caption).foregroundStyle(Theme.soft).lineLimit(1) }
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("HEUTE").font(.caption2.weight(.heavy)).foregroundStyle(Theme.muted)
                            Text("Kein Lauf geplant").font(.subheadline.weight(.heavy)).foregroundStyle(Theme.text)
                        }
                    }
                    HStack(spacing: 12) {
                        if let k = s.kcalLeft, fresh {
                            mini(icon: "fork.knife", text: k >= 0 ? "\(k) kcal übrig" : "\(-k) kcal drüber", color: Theme.accent)
                        }
                        if let b = s.bedtime {
                            mini(icon: "bed.double.fill", text: b.formatted(date: .omitted, time: .shortened), color: Theme.sleep)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    func mini(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.caption2.weight(.bold)).foregroundStyle(color)
            Text(text).font(.caption.weight(.bold)).foregroundStyle(Theme.text).lineLimit(1).minimumScaleFactor(0.8)
        }
    }
}

// MARK: Woche (groß)

struct WeekWidgetView: View {
    let entry: SnapEntry

    var body: some View {
        let s = entry.snap
        if entry.empty {
            EmptyHint()
        } else if s.week.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: "flag.checkered").font(.title2.weight(.bold)).foregroundStyle(Theme.accent)
                Text("Noch kein Trainingsplan").font(.headline).foregroundStyle(Theme.text)
                Text("Erstelle in Form einen Plan, dann siehst du hier deine Woche.").font(.caption).foregroundStyle(Theme.muted)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("DIESE WOCHE").font(.caption2.weight(.heavy)).foregroundStyle(Theme.muted)
                        Text(s.phase ?? "Trainingsplan").font(.headline.weight(.heavy)).foregroundStyle(Theme.text)
                    }
                    Spacer()
                    Text("\(Fmt.num(s.weekKmDone)) / \(Fmt.num(s.weekKmPlanned)) km").font(.subheadline.weight(.heavy)).foregroundStyle(Theme.accent)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.track)
                        Capsule().fill(Theme.accent).frame(width: geo.size.width * min(1, s.weekKmDone / max(1, s.weekKmPlanned)))
                    }
                }
                .frame(height: 6)
                VStack(spacing: 0) {
                    ForEach(s.week.prefix(9)) { item in
                        row(item)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    func row(_ item: WidgetSnapshot.Session) -> some View {
        let today = Calendar.current.isDateInToday(item.date)
        let past = item.date < Calendar.current.startOfDay(for: .now)
        let strength = item.title == "Krafttraining"
        return HStack(spacing: 10) {
            Text(item.date.formatted(Date.FormatStyle().weekday(.abbreviated).locale(Fmt.de)).uppercased())
                .font(.caption2.weight(.heavy)).foregroundStyle(today ? Theme.accent : Theme.muted).frame(width: 26, alignment: .leading)
            RoundedRectangle(cornerRadius: 2)
                .fill(item.rest ? Theme.muted : strength ? Theme.warn : item.quality ? Theme.accent : Theme.soft)
                .frame(width: 3, height: 22)
            VStack(alignment: .leading, spacing: 0) {
                Text(item.title).font(.caption.weight(.bold)).foregroundStyle(Theme.text).lineLimit(1)
                if !item.detail.isEmpty { Text(item.detail).font(.caption2).foregroundStyle(Theme.muted).lineLimit(1) }
            }
            Spacer(minLength: 4)
            if item.done {
                Image(systemName: "checkmark.circle.fill").font(.caption).foregroundStyle(Theme.good)
            } else if today {
                Text("HEUTE").font(.system(size: 9, weight: .heavy)).foregroundStyle(Theme.accent)
            }
        }
        .padding(.vertical, 4)
        .opacity(past && !item.done ? 0.5 : 1)
    }
}

func restCountdown(_ st: RestTimerAttributes.ContentState) -> ClosedRange<Date> {
    let now = Date.now
    return now...max(now, st.endsAt)
}

func restProgress(_ st: RestTimerAttributes.ContentState) -> ClosedRange<Date> {
    let start = st.endsAt.addingTimeInterval(-max(1, st.total))
    return start...max(start.addingTimeInterval(1), st.endsAt)
}

struct LockScreenRest: View {
    let state: RestTimerAttributes.ContentState
    let session: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SATZPAUSE · \(session.uppercased())").font(.caption2.weight(.heavy)).foregroundStyle(Theme.muted).lineLimit(1)
                    Text(timerInterval: restCountdown(state), countsDown: true)
                        .font(.system(size: 40, weight: .heavy, design: .rounded)).monospacedDigit().foregroundStyle(Theme.text)
                }
                Spacer()
                RestButtons(compact: false)
            }
            ProgressView(timerInterval: restProgress(state), countsDown: true) { EmptyView() } currentValueLabel: { EmptyView() }
                .tint(Theme.accent)
            Text("Als Nächstes: \(state.exercise), \(state.nextSet) · \(state.target)")
                .font(.caption.weight(.semibold)).foregroundStyle(Theme.soft).lineLimit(1)
        }
        .padding(16)
    }
}

struct RestButtons: View {
    let compact: Bool

    var body: some View {
        HStack(spacing: 8) {
            Button(intent: AddRestTimeIntent()) {
                Text("+30 s").font(.caption.weight(.heavy)).padding(.horizontal, compact ? 8 : 12).padding(.vertical, compact ? 5 : 8)
            }
            .buttonStyle(.plain)
            .background(Theme.card2, in: Capsule())
            .foregroundStyle(Theme.text)
            Button(intent: SkipRestIntent()) {
                Image(systemName: "forward.fill").font(.caption.weight(.heavy)).padding(.horizontal, compact ? 8 : 12).padding(.vertical, compact ? 5 : 8)
            }
            .buttonStyle(.plain)
            .background(Theme.accent, in: Capsule())
            .foregroundStyle(Theme.bg)
        }
    }
}
