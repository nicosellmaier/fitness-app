import WidgetKit
import SwiftUI
import ActivityKit
import AppIntents

// MARK: Daten

struct SnapProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapEntry {
        SnapEntry(date: .now, snap: .preview, empty: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapEntry) -> Void) {
        if let s = WidgetSnapshot.load() {
            completion(SnapEntry(date: .now, snap: s, empty: false))
        } else {
            completion(SnapEntry(date: .now, snap: .preview, empty: !context.isPreview))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapEntry>) -> Void) {
        let s = WidgetSnapshot.load()
        let entry = SnapEntry(date: .now, snap: s ?? WidgetSnapshot(), empty: s == nil)
        let cal = Calendar.current
        let midnight = cal.startOfDay(for: cal.date(byAdding: .day, value: 1, to: .now) ?? .now)
        let next = min(Date.now.addingTimeInterval(30 * 60), midnight.addingTimeInterval(60))
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct RecoveryWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FormRecovery", provider: SnapProvider()) { entry in
            RecoveryWidgetView(entry: entry)
                .containerBackground(Theme.bg, for: .widget)
        }
        .configurationDisplayName("Erholung")
        .description("Erholung, Schlaf und HRV auf einen Blick.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FormToday", provider: SnapProvider()) { entry in
            TodayWidgetView(entry: entry)
                .containerBackground(Theme.bg, for: .widget)
        }
        .configurationDisplayName("Heute")
        .description("Erholung, Training des Tages, Kalorien und Schlafenszeit.")
        .supportedFamilies([.systemMedium])
    }
}

struct WeekWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FormWeek", provider: SnapProvider()) { entry in
            WeekWidgetView(entry: entry)
                .containerBackground(Theme.bg, for: .widget)
        }
        .configurationDisplayName("Trainingswoche")
        .description("Alle Einheiten der Woche mit Fortschritt.")
        .supportedFamilies([.systemLarge])
    }
}

// MARK: Satzpause in Dynamic Island und Sperrbildschirm

struct RestTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestTimerAttributes.self) { context in
            LockScreenRest(state: context.state, session: context.attributes.sessionName)
                .activityBackgroundTint(Theme.bg)
                .activitySystemActionForegroundColor(Theme.accent)
        } dynamicIsland: { context in
            let st = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Label("Pause", systemImage: "timer").font(.caption.weight(.bold)).foregroundStyle(Theme.accent)
                        Text(st.exercise).font(.caption).foregroundStyle(Theme.soft).lineLimit(1)
                    }
                    .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: restCountdown(st), countsDown: true)
                        .font(.system(size: 30, weight: .heavy, design: .rounded)).monospacedDigit()
                        .foregroundStyle(Theme.text).multilineTextAlignment(.trailing)
                        .frame(width: 90)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        ProgressView(timerInterval: restProgress(st), countsDown: true) { EmptyView() } currentValueLabel: { EmptyView() }
                            .tint(Theme.accent)
                        HStack {
                            Text("Als Nächstes: \(st.nextSet) · \(st.target)").font(.caption.weight(.semibold)).foregroundStyle(Theme.text).lineLimit(1)
                            Spacer()
                            RestButtons(compact: true)
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: "dumbbell.fill").foregroundStyle(Theme.accent)
            } compactTrailing: {
                Text(timerInterval: restCountdown(st), countsDown: true)
                    .monospacedDigit().font(.caption.weight(.bold)).foregroundStyle(Theme.accent)
                    .frame(maxWidth: 46)
            } minimal: {
                Image(systemName: "timer").foregroundStyle(Theme.accent)
            }
            .keylineTint(Theme.accent)
        }
    }
}

// MARK: Bündel

@main
struct FormWidgetsBundle: WidgetBundle {
    var body: some Widget {
        RecoveryWidget()
        TodayWidget()
        WeekWidget()
        RestTimerLiveActivity()
    }
}
