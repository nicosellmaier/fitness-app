import SwiftUI

/// Alle Nachtwerte, HRV-Trend, Erholungsverlauf und Trends an einem Ort
struct VitalsView: View {
    @Environment(AppModel.self) private var model

    private var trendKinds: [MetricKind] {
        [.hrv, .rhr, .resp, .spo2, .temp, .vo2].filter { !model.points($0).isEmpty }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HealthMonitorCard()
                HRVTrendCard()
                SectionHeader("Trends", trailing: "30 Tage")
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    ForEach(trendKinds) { k in
                        NavigationLink { MetricDetailView(kind: k) } label: {
                            TrendTile(title: k.title, unit: k.unit, points: Array(model.points(k).suffix(30)), color: k.color,
                                      digits: k.digits, higherIsBetter: k.higherIsBetter, format: k.format)
                        }
                        .buttonStyle(.press)
                    }
                }
                SectionHeader("Erholung", trailing: "14 Tage")
                NavigationLink { MetricDetailView(kind: .recovery) } label: { RecoveryBars() }
                    .buttonStyle(.press)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
        }
        .screenBackground(Theme.good)
        .navigationTitle("Vitalwerte")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Mehr: Coach, Berichte, Einstellungen, Extras
struct MoreView: View {
    @Environment(AppModel.self) private var model
    @Environment(DataStore.self) private var store
    @State private var showSettings = false
    @State private var showCoach = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Button { showCoach = true } label: {
                        row("KI-Coach", "Tagesbriefing, Fragen zu Training, Essen und Schlaf", "sparkles", Theme.accent)
                    }
                    .buttonStyle(.press)
                    NavigationLink { WeeklyReportView() } label: {
                        row("Wochenbericht", "Erholung, Belastung, Schlaf und Training der letzten 7 Tage", "chart.bar.doc.horizontal.fill", Theme.good)
                    }
                    .buttonStyle(.press)
                    if store.data.profile.showFinance {
                        NavigationLink { FinanceView().navigationTitle("Finanzen").navigationBarTitleDisplayMode(.inline) } label: {
                            row("Finanzen", "Deine Finanz-App", "creditcard.fill", Theme.sleep)
                        }
                        .buttonStyle(.press)
                    }
                    SectionHeader("App")
                    VStack(spacing: 0) {
                        Button { showSettings = true } label: { line("Einstellungen", "gearshape.fill") }
                            .buttonStyle(.press)
                        Divider().overlay(Theme.line)
                        NavigationLink { WidgetGallery(page: 0) } label: { line("Widgets und Dynamic Island", "square.grid.2x2.fill") }
                            .buttonStyle(.press)
                        Divider().overlay(Theme.line)
                        NavigationLink { ExportView() } label: { line("Daten exportieren", "square.and.arrow.up.fill") }
                            .buttonStyle(.press)
                        Divider().overlay(Theme.line)
                        NavigationLink { BackupView() } label: { line("iCloud-Backup", "icloud.fill") }
                            .buttonStyle(.press)
                    }
                    .padding(.horizontal, 16)
                    .background(CardBackground(radius: 20))
                    SectionHeader("Wissen")
                    VStack(spacing: 0) {
                        Link(destination: URL(string: "https://github.com/nicosellmaier/fitness-app/blob/main/docs/WISSENSCHAFT.md")!) {
                            line("So rechnet die App", "book.fill")
                        }
                        .buttonStyle(.press)
                        Divider().overlay(Theme.line)
                        Link(destination: URL(string: "https://github.com/nicosellmaier/fitness-app")!) {
                            line("Quellcode auf GitHub", "chevron.left.forwardslash.chevron.right")
                        }
                        .buttonStyle(.press)
                    }
                    .padding(.horizontal, 16)
                    .background(CardBackground(radius: 20))
                    Text("Form \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "") (\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""))")
                        .font(.caption).foregroundStyle(Theme.muted).frame(maxWidth: .infinity).padding(.top, 8)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .screenBackground()
            .navigationTitle("Mehr")
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showCoach) { CoachView() }
        }
    }

    private func row(_ title: String, _ sub: String, _ icon: String, _ color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.title3.weight(.bold)).foregroundStyle(Theme.bg)
                .frame(width: 44, height: 44).background(color, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.bold))
                Text(sub).font(.caption).foregroundStyle(Theme.muted).multilineTextAlignment(.leading)
            }
            Spacer()
            Chevron()
        }
        .padding(14)
        .background(CardBackground(radius: 20))
    }

    private func line(_ title: String, _ icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.subheadline.weight(.bold)).foregroundStyle(Theme.accent).frame(width: 26)
            Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.text)
            Spacer()
            Chevron()
        }
        .padding(.vertical, 13)
        .contentShape(Rectangle())
    }
}

/// Erholungsbalken der letzten 14 Tage
struct RecoveryBars: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let start = max(0, model.days.count - 14)
        let pts: [(Date, Int)] = (start..<model.days.count).compactMap { i in
            model.recovery(at: i).map { (model.days[i].day, $0.score) }
        }
        Card {
            if pts.isEmpty {
                Text("Noch zu wenig Daten.").font(.footnote).foregroundStyle(Theme.soft)
            } else {
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(pts, id: \.0) { p in
                        VStack(spacing: 3) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(p.1 >= 67 ? Theme.good : p.1 >= 34 ? Theme.warn : Theme.bad)
                                .frame(height: max(4, 90 * Double(p.1) / 100))
                            Text(p.0.formatted(.dateTime.day())).font(.system(size: 9, weight: .bold)).foregroundStyle(Theme.muted)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 110, alignment: .bottom)
            }
        }
    }
}

// MARK: iCloud

struct BackupView: View {
    @Environment(DataStore.self) private var store
    @State private var last = CloudBackup.lastBackup
    @State private var confirmRestore = false
    @State private var message: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: CloudBackup.isAvailable ? "icloud.fill" : "icloud.slash").font(.title2).foregroundStyle(CloudBackup.isAvailable ? Theme.good : Theme.warn)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(CloudBackup.isAvailable ? "iCloud aktiv" : "iCloud nicht verfügbar").font(.headline)
                                Text(CloudBackup.isAvailable
                                     ? (last.map { "Letzte Sicherung: \(Fmt.shortDay($0)), \(Fmt.time($0))" } ?? "Noch keine Sicherung")
                                     : FileManager.default.ubiquityIdentityToken == nil
                                     ? "Melde dich in den iPhone-Einstellungen bei iCloud an und erlaube iCloud Drive."
                                     : "In diesem Build noch nicht freigeschaltet. Bis dahin: Mehr → Daten exportieren → Komplettes Backup.")
                                    .font(.footnote).foregroundStyle(Theme.soft)
                            }
                        }
                        if CloudBackup.size > 0 {
                            Text("Größe: \(ByteCountFormatter.string(fromByteCount: Int64(CloudBackup.size), countStyle: .file))").font(.caption).foregroundStyle(Theme.muted)
                        }
                    }
                }
                Text("Was gesichert wird: Routinen, Krafteinheiten, Trainingsplan, Ernährungseinträge, Journal, Verletzungen, Einstellungen und das Coach-Gedächtnis. Nicht gesichert: Apple-Health-Daten, die liegen ohnehin in deinem Health-Backup.")
                    .font(.footnote).foregroundStyle(Theme.soft).padding(.horizontal, 4)
                Text("Jede Änderung wird nach wenigen Sekunden in iCloud geschrieben. Auf einem neuen iPhone mit derselben Apple-ID übernimmt die App die Daten beim ersten Start automatisch.")
                    .font(.footnote).foregroundStyle(Theme.soft).padding(.horizontal, 4)
                Button {
                    store.backupNow()
                    last = .now
                    message = "Gesichert."
                } label: {
                    Label("Jetzt sichern", systemImage: "arrow.up.to.line").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Theme.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous)).foregroundStyle(Theme.bg)
                }
                .buttonStyle(.press)
                .disabled(!CloudBackup.isAvailable)
                Button { confirmRestore = true } label: {
                    Label("Aus iCloud wiederherstellen", systemImage: "arrow.down.to.line").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(CardBackground(radius: 16)).foregroundStyle(Theme.text)
                }
                .buttonStyle(.press)
                .disabled(!CloudBackup.isAvailable || last == nil)
                if let message { Text(message).font(.footnote.weight(.semibold)).foregroundStyle(Theme.good).frame(maxWidth: .infinity) }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
        }
        .screenBackground(Theme.sleep)
        .navigationTitle("iCloud-Backup")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Lokale Daten ersetzen?", isPresented: $confirmRestore, titleVisibility: .visible) {
            Button("Wiederherstellen", role: .destructive) {
                message = store.restoreFromCloud() ? "Wiederhergestellt." : "Keine Sicherung gefunden."
            }
        } message: {
            Text("Alles auf diesem iPhone wird durch die iCloud-Kopie ersetzt.")
        }
    }
}

// MARK: Export

struct ExportView: View {
    @Environment(DataStore.self) private var store
    @Environment(AppModel.self) private var model
    @State private var files: [URL] = []
    @State private var busy = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Für Arzt, Physio, Trainer oder eine Tabelle. Die Dateien entstehen auf dem iPhone und gehen nur dorthin, wo du sie teilst.")
                    .font(.footnote).foregroundStyle(Theme.soft).padding(.horizontal, 4)
                exportRow("Tageswerte (CSV)", "Erholung, HRV, Ruhepuls, Schlaf, Belastung, Schritte pro Tag", "tablecells") { Exporter.daysCSV(model: model) }
                exportRow("Krafteinheiten (CSV)", "Jeder Satz mit Datum, Übung, Gewicht, Wiederholungen", "dumbbell") { Exporter.strengthCSV(store: store) }
                exportRow("Workouts (CSV)", "Alle Aktivitäten mit Distanz, Dauer, Puls", "figure.run") { Exporter.workoutsCSV(model: model) }
                exportRow("Ernährung (CSV)", "Alle Einträge mit Kalorien und Makros", "fork.knife") { Exporter.nutritionCSV(store: store) }
                exportRow("Gesundheitsbericht (PDF)", "Letzte 30 Tage auf zwei Seiten, zum Mitnehmen zum Arzt", "doc.richtext") { Exporter.reportPDF(model: model, store: store) }
                exportRow("Komplettes Backup (JSON)", "Alle App-Daten in einer Datei", "externaldrive") { Exporter.fullJSON(store: store) }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
        }
        .screenBackground()
        .navigationTitle("Daten exportieren")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func exportRow(_ title: String, _ sub: String, _ icon: String, make: @escaping () -> URL?) -> some View {
        ExportRow(title: title, sub: sub, icon: icon, make: make)
    }
}

private struct ExportRow: View {
    let title: String
    let sub: String
    let icon: String
    let make: () -> URL?
    @State private var url: URL?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.subheadline.weight(.bold)).foregroundStyle(Theme.accent).frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.bold))
                Text(sub).font(.caption).foregroundStyle(Theme.muted)
            }
            Spacer()
            if let url {
                ShareLink(item: url) { Image(systemName: "square.and.arrow.up").font(.headline) }
            } else {
                Button { url = make() } label: { Text("Erstellen").font(.caption.weight(.bold)).padding(.horizontal, 10).padding(.vertical, 6).background(Theme.card2, in: Capsule()) }
                    .buttonStyle(.press)
            }
        }
        .padding(14)
        .background(CardBackground(radius: 18))
    }
}
