import SwiftUI
import Charts

// MARK: Gesundheitsmonitor

struct HealthMonitorCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let vitals = model.vitals
        let outside = vitals.filter(\.outside)
        VStack(alignment: .leading, spacing: 10) {
            if outside.count >= 2 {
                NavigationLink { InjuryView() } label: {
                    Hint(icon: "exclamationmark.triangle.fill", title: "\(outside.count) Werte außerhalb deines Bereichs",
                         text: "\(outside.map(\.name).joined(separator: ", ")). Das passiert oft vor einem Infekt, nach Alkohol oder bei Schlafmangel. Heute lieber locker. Fühlst du dich krank, tippe hier für den Krankheitsmodus.",
                         color: Theme.warn)
                }
                .buttonStyle(.plain)
            }
            Card {
                VStack(spacing: 0) {
                    HStack {
                        Text("Gesundheitsmonitor").font(.headline)
                        Spacer()
                        Text(vitals.isEmpty ? "–" : outside.isEmpty ? "Alles im Bereich" : "\(outside.count) auffällig")
                            .font(.caption.weight(.bold)).foregroundStyle(outside.isEmpty ? Theme.good : Theme.warn)
                    }
                    .padding(.bottom, 6)
                    if vitals.isEmpty {
                        Text("Nach einer Nacht mit der Watch erscheinen hier deine Nachtwerte.").font(.footnote).foregroundStyle(Theme.soft)
                    }
                    ForEach(vitals) { v in
                        HStack(spacing: 10) {
                            Image(systemName: v.icon).font(.footnote.weight(.bold)).foregroundStyle(v.outside ? Theme.warn : Theme.good).frame(width: 22)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(v.name).font(.subheadline.weight(.semibold))
                                Text("Dein Bereich: " + v.range).font(.caption).foregroundStyle(Theme.muted)
                            }
                            Spacer()
                            Text(v.value).font(.subheadline.weight(.heavy)).foregroundStyle(v.outside ? Theme.warn : Theme.text)
                        }
                        .padding(.vertical, 8)
                        if v.id != vitals.last?.id { Divider().overlay(Theme.line) }
                    }
                }
            }
        }
    }
}

// MARK: HRV-Trend

struct HRVTrendCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if let t = model.hrvTrend {
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("HRV-TREND · 7 TAGE").font(.caption.weight(.heavy)).foregroundStyle(Theme.muted)
                            Text("\(Fmt.num(t.rolling7)) ms").font(.title2.weight(.heavy))
                        }
                        Spacer()
                        Badge(text: t.label.uppercased(), color: t.color)
                    }
                    Chart {
                        RectangleMark(xStart: .value("von", t.series.first?.date ?? .now), xEnd: .value("bis", t.series.last?.date ?? .now),
                                      yStart: .value("unten", t.lower), yEnd: .value("oben", t.upper))
                            .foregroundStyle(Theme.good.opacity(0.12))
                        ForEach(t.series, id: \.date) { p in
                            PointMark(x: .value("Tag", p.date), y: .value("HRV", p.value))
                                .foregroundStyle(Theme.muted.opacity(0.6)).symbolSize(14)
                        }
                        ForEach(t.series.filter { $0.rolling != nil }, id: \.date) { p in
                            LineMark(x: .value("Tag", p.date), y: .value("Schnitt", p.rolling ?? 0))
                                .foregroundStyle(Theme.accent).lineStyle(StrokeStyle(lineWidth: 2.5)).interpolationMethod(.catmullRom)
                        }
                    }
                    .chartYScale(domain: .automatic(includesZero: false))
                    .frame(height: 130)
                    Text(explanation(t)).font(.caption).foregroundStyle(Theme.soft).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func explanation(_ t: HRVTrend) -> String {
        let src = t.usesRMSSD ? "RMSSD aus den Schlag-zu-Schlag-Daten der Nacht" : "Apples SDNN"
        let base = "Grüne Fläche: dein Normalbereich der letzten 60 Tage. Linie: 7-Tage-Schnitt (\(src)). Schwankung diese Woche \(Fmt.num(t.cv7))%."
        switch t.state {
        case .below: return base + " Liegt der Schnitt darunter, plant die App bis zur Rückkehr in den Bereich keine harten Einheiten."
        case .within: return base + " Im Bereich darf hart trainiert werden."
        case .above: return base + " Über dem Bereich ist meist gut, kann bei sehr hohem Umfang aber auch Ermüdung zeigen."
        }
    }
}

// MARK: Belastung im Detail

struct StrainDetailView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let today = model.strainBreakdownToday
        let target = Analytics.strainTarget(model.recoveryToday)
        let cal = Calendar.current
        let week: [(Date, Double)] = (0..<14).reversed().map { i in
            let d = cal.addDays(-i, to: cal.startOfDay(for: .now))
            return (d, model.strain(on: d).score)
        }
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 18) {
                    ZStack {
                        Ring(progress: today.score / 21, color: Theme.warn, lineWidth: 13)
                        VStack(spacing: 0) {
                            Text(Fmt.num(today.score, 1)).font(.system(size: 34, weight: .heavy))
                            Text("von 21").font(.caption.weight(.semibold)).foregroundStyle(Theme.muted)
                        }
                    }
                    .frame(width: 124, height: 124)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ziel heute \(Int(target.lowerBound))–\(Int(target.upperBound))").font(.headline).foregroundStyle(Theme.warn)
                        Text(advice(today.score, target)).font(.footnote).foregroundStyle(Theme.soft)
                    }
                }
                .padding(18)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 26, style: .continuous))

                HStack(spacing: 8) {
                    StatTile(title: "Herz-Kreislauf", value: Fmt.num(today.cardio), unit: "TRIMP")
                    StatTile(title: "Muskulär", value: Fmt.num(today.muscular), unit: "TRIMP")
                }

                SectionHeader("Letzte 14 Tage")
                Card {
                    Chart(week, id: \.0) { p in
                        BarMark(x: .value("Tag", p.0, unit: .day), y: .value("Belastung", p.1))
                            .foregroundStyle(p.1 >= 14 ? Theme.bad : p.1 >= 10 ? Theme.warn : Theme.accent)
                            .cornerRadius(4)
                    }
                    .chartYScale(domain: 0...21)
                    .frame(height: 150)
                }

                Card {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("So wird gerechnet").font(.subheadline.weight(.bold))
                        Text("Jede Minute mit einem Puls über 30 % deiner Herzfrequenzreserve zählt nach Banisters TRIMP, harte Minuten exponentiell stärker. Krafttraining kommt aus deinem Satz-Log dazu: eine für dich typische Einheit zählt 40 Punkte, mehr Volumen entsprechend mehr. Die Summe wird auf die Skala 0 bis 21 gebracht, die nach oben immer schwerer zu füllen ist.")
                            .font(.caption).foregroundStyle(Theme.soft)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
        }
        .screenBackground()
        .navigationTitle("Belastung")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func advice(_ s: Double, _ t: ClosedRange<Double>) -> String {
        if s < t.lowerBound { return "Noch \(Fmt.num(t.lowerBound - s, 1)) bis zum Zielbereich. Deine Erholung lässt das heute zu." }
        if s <= t.upperBound { return "Im Zielbereich. Mehr bringt heute wenig zusätzlichen Reiz, kostet aber Erholung." }
        return "Über dem Zielbereich. Plane heute Nacht etwas mehr Schlaf ein, der Bedarf steigt schon automatisch."
    }
}
