import SwiftUI
import WebKit

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var profile = Profile()
    @State private var maxHR: Double = 192
    @State private var sleepBase: Double = 8
    @State private var demo = false
    @State var rem = ReminderPrefs()
    @AppStorage("financeURL") private var financeURL = FinanceView.defaultURL

    var body: some View {
        NavigationStack {
            SwiftUI.Form {
                Section {
                    TextField("Vorname", text: $profile.name)
                    Picker("Geschlecht", selection: $profile.sex) {
                        ForEach(Sex.allCases) { Text($0.label).tag($0) }
                    }
                    Stepper("Geburtsjahr: \(String(profile.birthYear))", value: $profile.birthYear, in: 1940...2015)
                    Stepper("Größe: \(Int(profile.heightCm)) cm", value: $profile.heightCm, in: 140...215)
                    Stepper("Gewicht: \(Fmt.num(profile.weightKg, 1)) kg", value: $profile.weightKg, in: 40...160, step: 0.5)
                } header: {
                    Text("Profil")
                } footer: {
                    if let w = model.weightKg {
                        Text("Apple Health meldet \(Fmt.num(w, 1)) kg. Dieser Wert wird für die Ernährung bevorzugt.")
                    } else {
                        Text("Für Grundumsatz und Kalorienziel. Wiegst du dich mit einer Waage, die in Apple Health schreibt, nimmt die App automatisch den aktuellen Wert.")
                    }
                }
                Section {
                    Picker("Ziel", selection: $profile.goal) {
                        ForEach(NutritionGoal.allCases) { Text($0.label).tag($0) }
                    }
                    Stepper("Eiweiß: \(Fmt.num(profile.proteinPerKg, 1)) g pro kg", value: $profile.proteinPerKg, in: 1.0...2.6, step: 0.1)
                } header: {
                    Text("Ernährung")
                } footer: {
                    Text("Abnehmen zieht 400 kcal ab, Muskelaufbau legt 250 kcal drauf. Für Ausdauer plus Kraft sind 1,6 bis 2,0 g Eiweiß pro kg sinnvoll.")
                }
                Section("Krafttraining") {
                    Stepper("Satzpause: \(Fmt.clock(Double(profile.restSeconds)))", value: $profile.restSeconds, in: 30...300, step: 15)
                    Toggle("Einheiten in Apple Health sichern", isOn: $profile.saveStrengthToHealth)
                }
                Section {
                    Toggle("Erinnerung vor der Schlafenszeit", isOn: $profile.bedtimeReminder)
                } header: {
                    Text("Schlaf")
                } footer: {
                    Text("30 Minuten vor der Zeit, zu der du für deinen heutigen Schlafbedarf im Bett sein solltest.")
                }
                Section {
                    Stepper("Maximalpuls: \(Int(maxHR)) bpm", value: $maxHR, in: 150...220)
                    Stepper("Schlaf-Grundbedarf: \(Fmt.num(sleepBase, 1)) h", value: $sleepBase, in: 6...10, step: 0.25)
                } header: {
                    Text("Herz & Schlaf")
                } footer: {
                    Text("Der Maximalpuls bestimmt die Herzfrequenz-Zonen und die Belastung. Am genauesten ist der höchste Wert aus einem harten Wettkampf oder Test.")
                }
                Section {
                    NavigationLink("Weckzeiten, Kalender, Erinnerungen") { SleepPrefsView() }
                } header: {
                    Text("Schlafplan")
                }
                Section {
                    Toggle("Morgenbriefing", isOn: $rem.briefing)
                    if rem.briefing {
                        DatePicker("Uhrzeit", selection: briefingTime, displayedComponents: .hourAndMinute)
                    }
                    Toggle("Journal ausfüllen", isOn: $rem.journal)
                    if rem.journal {
                        Stepper("Um \(rem.journalHour):00 Uhr", value: $rem.journalHour, in: 6...22)
                    }
                    Toggle("Essen eintragen (13:30, 20:00)", isOn: $rem.meals)
                    Toggle("Trinken (10, 14, 17:30 Uhr)", isOn: $rem.water)
                    if rem.water {
                        Stepper("Ziel: \(Int(rem.waterGoalMl)) ml", value: $rem.waterGoalMl, in: 1000...5000, step: 250)
                    }
                    Toggle("Wochenbericht montags 8 Uhr", isOn: $rem.weeklyReport)
                } header: {
                    Text("Erinnerungen")
                } footer: {
                    Text("Alles lokal auf dem iPhone geplant. Die Erinnerung vor der Schlafenszeit stellst du oben unter Schlaf ein.")
                }
                Section {
                    NavigationLink("KI-Coach verbinden") { CoachSetupView() }
                    NavigationLink("Coach-Gedächtnis") { CoachMemoryView() }
                } header: {
                    Text("Coach")
                } footer: {
                    Text(CoachConfig.isConfigured ? "Verbunden mit deinem Worker." : "Noch nicht verbunden. Anleitung im Repo unter docs/KI-COACH.md.")
                }
                Section {
                    NavigationLink("Widgets und Dynamic Island") { WidgetGallery(page: 0) }
                    NavigationLink("Satzpause-Vorschau") { WidgetGallery(page: 1) }
                } header: {
                    Text("Vorschau")
                } footer: {
                    Text("So sehen die Widgets mit deinen aktuellen Daten aus. Hinzufügen: Home-Bildschirm lange drücken, dann + und Form.")
                }
                Section("Daten") {
                    Button("Zugriff auf Apple Health erneut anfragen") { Task { await model.requestAccess() } }
                    Toggle("Beispieldaten anzeigen", isOn: $demo)
                    if let e = model.errorText { Text(e).foregroundStyle(Theme.bad).font(.footnote) }
                }
                Section {
                    Toggle("Finanzen-Tab anzeigen", isOn: $profile.showFinance)
                    if profile.showFinance {
                    TextField("Adresse", text: $financeURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    }
                } header: {
                    Text("Finanzen")
                } footer: {
                    Text("Adresse deiner Finanz-App bei Cloudflare.")
                }
                Section {
                    LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–")
                }
            }
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") {
                        let wantsReminder = profile.bedtimeReminder && !store.data.profile.bedtimeReminder
                        let p = profile
                        let r = rem
                        let remOn = r.briefing || r.journal || r.meals || r.water || r.weeklyReport
                        store.update { $0.profile = p; $0.reminders = r }
                        if remOn { Task { await Notifications.requestPermission() } }
                        if wantsReminder { Task { await Notifications.requestPermission() } }
                        let need = model.needTonight
                        Notifications.updateBedtime(enabled: p.bedtimeReminder, bedtime: model.sleepPlan?.bedtime, need: need.total)
                        WidgetBridge.update(model: model, store: store)
                        model.maxHR = maxHR
                        model.sleepBaseHours = sleepBase
                        let demoChanged = demo != model.forceDemo
                        model.forceDemo = demo
                        dismiss()
                        if demoChanged { Task { await model.load() } }
                    }
                }
            }
            .onAppear {
                profile = store.data.profile
                maxHR = model.maxHR
                sleepBase = model.sleepBaseHours
                demo = model.forceDemo
                rem = store.data.reminders
            }
        }
    }
}

extension SettingsView {
    var briefingTime: Binding<Date> {
        Binding(get: {
            Calendar.current.date(from: DateComponents(hour: rem.briefingHour, minute: rem.briefingMinute)) ?? .now
        }, set: { d in
            rem.briefingHour = Calendar.current.component(.hour, from: d)
            rem.briefingMinute = Calendar.current.component(.minute, from: d)
        })
    }
}

struct FinanceView: View {
    static let defaultURL = "https://finanzen.nicosellmaier14.workers.dev"
    @AppStorage("financeURL") private var financeURL = FinanceView.defaultURL

    var body: some View {
        Group {
            if let url = URL(string: financeURL), url.scheme == "https" {
                WebView(url: url)
            } else {
                Text("Keine gültige Adresse in den Einstellungen.").foregroundStyle(Theme.soft)
            }
        }
        .background(Theme.bg.ignoresSafeArea())
    }
}

struct WebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        let view = WKWebView(frame: .zero, configuration: config)
        let bg = UIColor(red: 0.043, green: 0.047, blue: 0.039, alpha: 1)
        view.isOpaque = false
        view.backgroundColor = bg
        view.scrollView.backgroundColor = bg
        view.allowsBackForwardNavigationGestures = true
        view.load(URLRequest(url: url))
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        if view.url == nil { view.load(URLRequest(url: url)) }
    }
}
