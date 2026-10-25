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
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

struct Ring: View {
    var progress: Double
    var color: Color
    var lineWidth: CGFloat = 14

    var body: some View {
        ZStack {
            Circle().stroke(Theme.track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, progress)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
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
                if !unit.isEmpty { Text(unit).font(.caption).foregroundStyle(Theme.muted) }
            }
            if let note { Text(note).font(.caption.weight(.semibold)).foregroundStyle(noteColor).lineLimit(1) }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.track)
                Capsule().fill(color).frame(width: max(0, min(1, fraction)) * geo.size.width)
            }
        }
        .frame(height: height)
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

extension View {
    func screenBackground() -> some View {
        self.scrollContentBackground(.hidden).background(Theme.bg.ignoresSafeArea())
    }
}
