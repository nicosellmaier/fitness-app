import SwiftUI
import WebKit

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var maxHR: Double = 192
    @State private var sleepBase: Double = 8
    @State private var demo = false
    @AppStorage("financeURL") private var financeURL = FinanceView.defaultURL

    var body: some View {
        NavigationStack {
            SwiftUI.Form {
                Section {
                    Stepper("Maximalpuls: \(Int(maxHR)) bpm", value: $maxHR, in: 150...220)
                    Stepper("Schlaf-Grundbedarf: \(Fmt.num(sleepBase, 1)) h", value: $sleepBase, in: 6...10, step: 0.25)
                } header: {
                    Text("Persönliche Werte")
                } footer: {
                    Text("Der Maximalpuls bestimmt die Herzfrequenz-Zonen und die Belastung. Am genauesten ist der höchste Wert aus einem harten Wettkampf oder Test.")
                }
                Section("Daten") {
                    Button("Zugriff auf Apple Health erneut anfragen") { Task { await model.requestAccess() } }
                    Toggle("Beispieldaten anzeigen", isOn: $demo)
                    if let e = model.errorText { Text(e).foregroundStyle(Theme.bad).font(.footnote) }
                }
                Section {
                    TextField("Adresse", text: $financeURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
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
                maxHR = model.maxHR
                sleepBase = model.sleepBaseHours
                demo = model.forceDemo
            }
        }
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
