import SwiftUI
import WidgetKit

/// Zeigt die Widgets und die Satzpause-Ansicht so, wie sie auf dem Home- und Sperrbildschirm aussehen
struct WidgetGallery: View {
    @Environment(AppModel.self) private var model
    @Environment(DataStore.self) private var store
    var page = 0

    var body: some View {
        let entry = SnapEntry(date: .now, snap: WidgetBridge.make(model: model, store: store), empty: false)
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if page == 0 {
                    label("Erholung · klein")
                    HStack(spacing: 22) {
                        tile(RecoveryWidgetView(entry: entry, fixedFamily: .systemSmall), w: 170, h: 170)
                        VStack(alignment: .leading, spacing: 10) {
                            lockCircular(entry)
                            lockRect(entry)
                        }
                    }
                    label("Heute · mittel")
                    tile(TodayWidgetView(entry: entry), w: 364, h: 170)
                    label("Trainingswoche · groß")
                    tile(WeekWidgetView(entry: entry), w: 364, h: 382)
                } else {
                    label("Satzpause · Sperrbildschirm")
                    LockScreenRest(state: sampleRest, session: "Oberkörper")
                        .frame(width: 364)
                        .background(Theme.bg.opacity(0.92), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    label("Satzpause · Dynamic Island ausgeklappt")
                    expandedIsland
                    label("Satzpause · Dynamic Island kompakt")
                    compactIsland
                }
            }
            .padding(.horizontal, 19)
            .padding(.vertical, 12)
        }
        .background(
            LinearGradient(colors: [Color(hex: 0x1E2A16), Color(hex: 0x0E1320), Color(hex: 0x06070A)], startPoint: .topLeading, endPoint: .bottom)
                .ignoresSafeArea()
        )
        .navigationTitle("Widgets")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var sampleRest: RestTimerAttributes.ContentState {
        RestTimerAttributes.ContentState(endsAt: .now.addingTimeInterval(84), total: 120, exercise: "Bankdrücken", nextSet: "Satz 3/3", target: "77,5 kg × 10")
    }

    private func label(_ t: String) -> some View {
        Text(t.uppercased()).font(.caption2.weight(.heavy)).foregroundStyle(.white.opacity(0.6))
    }

    private func tile<V: View>(_ v: V, w: CGFloat, h: CGFloat) -> some View {
        v.padding(16)
            .frame(width: w, height: h)
            .background(Theme.bg, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    /// Sperrbildschirm-Widgets werden vom System eingefärbt, hier als helle Glas-Version nachgestellt
    private func lockCircular(_ e: SnapEntry) -> some View {
        let score = snapIsToday(e.snap) ? e.snap.recovery : nil
        return ZStack {
            Circle().fill(.white.opacity(0.12))
            Circle().trim(from: 0, to: Double(score ?? 0) / 100)
                .stroke(.white, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90)).padding(5)
            VStack(spacing: 0) {
                Image(systemName: "heart.fill").font(.system(size: 9))
                Text(score.map { "\($0)" } ?? "–").font(.system(size: 20, weight: .bold, design: .rounded))
            }
            .foregroundStyle(.white)
        }
        .frame(width: 68, height: 68)
    }

    private func lockRect(_ e: SnapEntry) -> some View {
        RecoveryWidgetView(entry: e, fixedFamily: .accessoryRectangular)
            .foregroundStyle(.white)
            .frame(width: 160, height: 68, alignment: .leading)
    }

    private var expandedIsland: some View {
        let st = sampleRest
        return VStack(spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Label("Pause", systemImage: "timer").font(.caption.weight(.bold)).foregroundStyle(Theme.accent)
                    Text(st.exercise).font(.caption).foregroundStyle(Theme.soft)
                }
                Spacer()
                Text(timerInterval: restCountdown(st), countsDown: true)
                    .font(.system(size: 30, weight: .heavy, design: .rounded)).monospacedDigit()
                    .foregroundStyle(.white).multilineTextAlignment(.trailing).frame(width: 90)
            }
            ProgressView(timerInterval: restProgress(st), countsDown: true) { EmptyView() } currentValueLabel: { EmptyView() }
                .tint(Theme.accent)
            HStack {
                Text("Als Nächstes: \(st.nextSet) · \(st.target)").font(.caption.weight(.semibold)).foregroundStyle(.white).lineLimit(1)
                Spacer()
                RestButtons(compact: true)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
        .frame(width: 364)
        .background(.black, in: RoundedRectangle(cornerRadius: 44, style: .continuous))
    }

    private var compactIsland: some View {
        HStack {
            Image(systemName: "dumbbell.fill").foregroundStyle(Theme.accent)
            Spacer()
            Text(timerInterval: restCountdown(sampleRest), countsDown: true)
                .monospacedDigit().font(.caption.weight(.bold)).foregroundStyle(Theme.accent)
                .frame(maxWidth: 46)
        }
        .padding(.horizontal, 14)
        .frame(width: 210, height: 37)
        .background(.black, in: Capsule())
        .frame(maxWidth: .infinity)
    }
}
