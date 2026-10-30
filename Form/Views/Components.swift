import SwiftUI

struct Card<Content: View>: View {
    let padding: CGFloat
    let content: Content

    init(padding: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(CardBackground(radius: 22))
    }
}

/// Karte mit leichtem Verlauf und feiner Lichtkante oben
struct CardBackground: View {
    var radius: CGFloat = 22
    var tint: Color? = nil

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        shape
            .fill(LinearGradient(colors: [tint.map { $0.opacity(0.16) } ?? Theme.card2.opacity(0.9), Theme.card],
                                 startPoint: .top, endPoint: .bottom))
            .overlay(shape.strokeBorder(LinearGradient(colors: [(tint ?? .white).opacity(tint == nil ? 0.09 : 0.35), .white.opacity(0.015)],
                                                       startPoint: .top, endPoint: .bottom), lineWidth: 1))
    }
}

/// Gedrückt: kurz kleiner und heller. Fühlt sich an wie eine echte Taste.
struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed ? 0.965 : 1)
            .brightness(configuration.isPressed ? 0.06 : 0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressStyle {
    static var press: PressStyle { PressStyle() }
}

struct Ring: View {
    var progress: Double
    var color: Color
    var lineWidth: CGFloat = 14
    @State private var shown: Double = 0

    var body: some View {
        ZStack {
            Circle().stroke(Theme.track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, shown)))
                .stroke(AngularGradient(colors: [color.opacity(0.55), color], center: .center,
                                        startAngle: .degrees(0), endAngle: .degrees(360 * max(0.05, min(1, shown)))),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: color.opacity(0.35), radius: lineWidth * 0.5)
        }
        .onAppear {
            if UserDefaults.standard.string(forKey: "shot") != nil { shown = progress; return }
            withAnimation(.spring(response: 1.1, dampingFraction: 0.85).delay(0.05)) { shown = progress }
        }
        .onChange(of: progress) { _, v in withAnimation(.spring(response: 0.8, dampingFraction: 0.85)) { shown = v } }
    }
}

struct StatTile: View {
    let title: String
    let value: String
    var unit: String = ""
    var note: String? = nil
    var noteColor: Color = Theme.muted

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(Theme.muted)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value).font(.title3.weight(.heavy)).lineLimit(1).minimumScaleFactor(0.7)
                    .contentTransition(.numericText())
                if !unit.isEmpty { Text(unit).font(.caption).foregroundStyle(Theme.muted) }
            }
            if let note { Text(note).font(.caption.weight(.semibold)).foregroundStyle(noteColor).lineLimit(1) }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CardBackground(radius: 18))
    }
}

struct SectionHeader: View {
    let title: String
    var trailing: String? = nil

    init(_ title: String, trailing: String? = nil) {
        self.title = title
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.title3.weight(.bold))
            Spacer()
            if let trailing { Text(trailing).font(.subheadline).foregroundStyle(Theme.muted) }
        }
        .padding(.horizontal, 4)
        .padding(.top, 14)
    }
}

struct Hint: View {
    let icon: String
    let title: String
    let text: String
    var color: Color = Theme.accent

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).foregroundStyle(color).font(.body.weight(.semibold)).frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.bold))
                Text(text).font(.footnote).foregroundStyle(Theme.soft).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(CardBackground(radius: 18))
        .overlay(alignment: .leading) {
            UnevenRoundedRectangle(topLeadingRadius: 18, bottomLeadingRadius: 18)
                .fill(color)
                .frame(width: 4)
        }
    }
}

struct Badge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.heavy))
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

struct Bar: View {
    var fraction: Double
    var color: Color
    var height: CGFloat = 8
    @State private var shown: Double = 0

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.track)
                Capsule().fill(LinearGradient(colors: [color.opacity(0.7), color], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(0, min(1, shown)) * geo.size.width)
            }
        }
        .frame(height: height)
        .onAppear {
            if UserDefaults.standard.string(forKey: "shot") != nil { shown = fraction; return }
            withAnimation(.spring(response: 0.9, dampingFraction: 0.85)) { shown = fraction }
        }
        .onChange(of: fraction) { _, v in withAnimation(.snappy) { shown = v } }
    }
}

struct MetricRow: View {
    let title: String
    var subtitle: String? = nil
    let value: String
    var badge: (String, Color)? = nil

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.subheadline.weight(.bold))
                if let subtitle { Text(subtitle).font(.caption).foregroundStyle(Theme.muted) }
            }
            Spacer()
            Text(value).font(.subheadline.weight(.heavy))
            if let badge { Badge(text: badge.0, color: badge.1) }
        }
        .padding(.vertical, 11)
    }
}

struct DemoBanner: View {
    var body: some View {
        Hint(icon: "sparkles", title: "Beispieldaten",
             text: "Noch keine Daten aus Apple Health. Was du siehst, ist erfunden und nur zur Vorschau.",
             color: Theme.sleep)
    }
}

/// Dunkler Hintergrund mit einem weichen Lichtschein oben
struct ScreenGlow: View {
    var color: Color = Theme.accent

    var body: some View {
        ZStack(alignment: .top) {
            Theme.bg
            RadialGradient(colors: [color.opacity(0.13), color.opacity(0.03), .clear],
                           center: UnitPoint(x: 0.25, y: -0.08), startRadius: 10, endRadius: 420)
                .frame(height: 520)
        }
        .ignoresSafeArea()
    }
}

extension View {
    func screenBackground(_ glow: Color = Theme.accent) -> some View {
        self.scrollContentBackground(.hidden).background(ScreenGlow(color: glow))
    }
}

/// Kleiner Pfeil für klickbare Karten
struct Chevron: View {
    var body: some View {
        Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(Theme.muted)
    }
}
