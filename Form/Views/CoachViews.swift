import SwiftUI

struct CoachView: View {
    @Environment(AppModel.self) private var model
    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var initialPrompt: String? = nil

    @State private var input = ""
    @State private var streaming = ""
    @State private var busy = false
    @State private var errorText: String?
    @State private var showMemory = false
    @State private var showSetup = false
    @State private var configured = CoachConfig.isConfigured
    @State private var task: Task<Void, Never>?
    @FocusState private var focused: Bool

    private let quick = [
        "Gib mir mein Tagesbriefing",
        "Wie soll ich heute trainieren?",
        "Warum ist meine Erholung so?",
        "Was sollte ich heute noch essen?",
        "Wie war mein Schlaf diese Woche?",
        "Was bringt mich bei meinem Rennziel am meisten weiter?",
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            if !configured && !demo {
                                setupHint
                            }
                            if store.data.coachHistory.isEmpty && streaming.isEmpty {
                                intro
                            }
                            ForEach(store.data.coachHistory) { m in
                                Bubble(message: m, onRemember: remember).id(m.id)
                            }
                            if busy {
                                Bubble(message: CoachMessage(role: "assistant", text: streaming.isEmpty ? "…" : streaming), onRemember: nil, live: true)
                                    .id("live")
                            }
                            if let e = errorText {
                                Hint(icon: "exclamationmark.triangle.fill", title: "Hat nicht geklappt", text: e, color: Theme.bad)
                            }
                            Color.clear.frame(height: 4).id("end")
                        }
                        .padding(16)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: streaming) { _, _ in proxy.scrollTo("end", anchor: .bottom) }
                    .onChange(of: store.data.coachHistory.count) { _, _ in withAnimation { proxy.scrollTo("end", anchor: .bottom) } }
                    .onAppear { proxy.scrollTo("end", anchor: .bottom) }
                }
                inputBar
            }
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("Coach")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fertig") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button { showMemory = true } label: { Label("Gedächtnis (\(store.data.coachMemory.count))", systemImage: "brain") }
                        Button { showSetup = true } label: { Label("Verbindung", systemImage: "link") }
                        Button(role: .destructive) { store.update { $0.coachHistory = [] } } label: { Label("Verlauf löschen", systemImage: "trash") }
                    } label: { Image(systemName: "ellipsis.circle") }
                }
            }
            .sheet(isPresented: $showMemory) { CoachMemoryView() }
            .sheet(isPresented: $showSetup, onDismiss: { configured = CoachConfig.isConfigured }) { CoachSetupView() }
            .onAppear {
                if demo && store.data.coachHistory.isEmpty { store.update { $0.coachHistory = DemoCoach.history } }
                if let p = initialPrompt, configured { send(p) }
            }
            .onDisappear { task?.cancel() }
        }
    }

    private var demo: Bool { UserDefaults.standard.bool(forKey: "seedDemo") }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "sparkles").font(.system(size: 30, weight: .bold)).foregroundStyle(Theme.accent)
            Text("Dein Coach kennt deine Daten").font(.title3.weight(.heavy))
            Text("Erholung, Schlaf, HRV, Training, Plan, Ernährung, Verletzungen und dein Journal. Frag einfach, er antwortet mit deinen Zahlen und nach aktueller Sportwissenschaft.")
                .font(.footnote).foregroundStyle(Theme.soft)
            PromptList(items: quick) { q in send(q) }
                .padding(.top, 4)
        }
        .padding(16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var setupHint: some View {
        Button { showSetup = true } label: {
            Hint(icon: "link", title: "Coach verbinden",
                 text: "Der Coach läuft über deinen eigenen Cloudflare Worker mit der Claude API. Tippe hier, um Adresse und App-Token einzutragen. Anleitung: docs/KI-COACH.md im Repo.",
                 color: Theme.sleep)
        }
        .buttonStyle(.plain)
    }

    private var inputBar: some View {
        VStack(spacing: 8) {
            if !store.data.coachHistory.isEmpty && !busy {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(quick.prefix(4), id: \.self) { q in
                            Button { send(q) } label: {
                                Text(q).font(.caption.weight(.semibold)).padding(.horizontal, 12).padding(.vertical, 7)
                                    .background(Theme.card2, in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            HStack(alignment: .bottom, spacing: 8) {
                TextField("Frag deinen Coach", text: $input, axis: .vertical)
                    .lineLimit(1...5)
                    .focused($focused)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                Button {
                    if busy { task?.cancel(); busy = false } else { send(input) }
                } label: {
                    Image(systemName: busy ? "stop.fill" : "arrow.up").font(.headline.weight(.bold))
                        .frame(width: 40, height: 40)
                        .background(busy || !input.trimmingCharacters(in: .whitespaces).isEmpty ? Theme.accent : Theme.card2, in: Circle())
                        .foregroundStyle(Theme.bg)
                }
                .disabled(!busy && input.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 10)
        .background(Theme.bg)
    }

    private func send(_ text: String) {
        let q = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, !busy else { return }
        input = ""
        errorText = nil
        store.update { $0.coachHistory.append(CoachMessage(role: "user", text: q)) }
        if demo && !configured {
            store.update { $0.coachHistory.append(CoachMessage(role: "assistant", text: DemoCoach.answer)) }
            return
        }
        busy = true
        streaming = ""
        let context = CoachContext.make(model: model, store: store)
        let history = store.data.coachHistory
        task = Task { @MainActor in
            do {
                for try await chunk in CoachClient.stream(messages: history, context: context) {
                    streaming += chunk
                }
                let final = streaming.trimmingCharacters(in: .whitespacesAndNewlines)
                if !final.isEmpty {
                    store.update { d in
                        d.coachHistory.append(CoachMessage(role: "assistant", text: final))
                        if d.coachHistory.count > 80 { d.coachHistory.removeFirst(d.coachHistory.count - 80) }
                    }
                }
            } catch is CancellationError {
            } catch {
                if !streaming.isEmpty { store.update { $0.coachHistory.append(CoachMessage(role: "assistant", text: streaming)) } }
                errorText = error.localizedDescription
            }
            streaming = ""
            busy = false
        }
    }

    private func remember(_ fact: String) {
        guard !store.data.coachMemory.contains(fact) else { return }
        store.update { $0.coachMemory.append(fact) }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

struct Bubble: View {
    let message: CoachMessage
    let onRemember: ((String) -> Void)?
    var live = false

    var body: some View {
        let isUser = message.role == "user"
        let parts = split(message.text)
        HStack {
            if isUser { Spacer(minLength: 40) }
            VStack(alignment: .leading, spacing: 8) {
                Text(markdown(parts.text))
                    .font(.subheadline)
                    .foregroundStyle(isUser ? Theme.bg : Theme.text)
                    .textSelection(.enabled)
                ForEach(parts.memories, id: \.self) { m in
                    Button { onRemember?(m) } label: {
                        Label("Merken: " + m, systemImage: "brain").font(.caption.weight(.semibold)).multilineTextAlignment(.leading)
                            .padding(.horizontal, 10).padding(.vertical, 7)
                            .background(Theme.card2, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(onRemember == nil)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(isUser ? Theme.accent : Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .opacity(live && message.text == "…" ? 0.6 : 1)
            if !isUser { Spacer(minLength: 24) }
        }
    }

    /// Zeilen "MERKEN: …" werden als Knopf angezeigt statt als Text
    private func split(_ t: String) -> (text: String, memories: [String]) {
        var keep: [String] = []
        var mem: [String] = []
        for line in t.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.uppercased().hasPrefix("MERKEN:") {
                let fact = trimmed.dropFirst(7).trimmingCharacters(in: .whitespaces)
                if !fact.isEmpty { mem.append(fact) }
            } else {
                keep.append(line)
            }
        }
        return (keep.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines), mem)
    }

    private func markdown(_ s: String) -> AttributedString {
        (try? AttributedString(markdown: s, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(s)
    }
}

struct PromptList: View {
    let items: [String]
    let action: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { q in
                Button { action(q) } label: {
                    HStack {
                        Text(q).font(.footnote.weight(.semibold)).multilineTextAlignment(.leading)
                        Spacer()
                        Image(systemName: "arrow.up.right").font(.caption.weight(.bold)).foregroundStyle(Theme.accent)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    .background(Theme.card2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct CoachMemoryView: View {
    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var newFact = ""

    var body: some View {
        NavigationStack {
            SwiftUI.Form {
                Section {
                    ForEach(store.data.coachMemory, id: \.self) { m in Text(m) }
                        .onDelete { idx in store.update { $0.coachMemory.remove(atOffsets: idx) } }
                    HStack {
                        TextField("z.B. Ich trainiere morgens vor der Uni", text: $newFact)
                        Button("Hinzufügen") {
                            let f = newFact.trimmingCharacters(in: .whitespaces)
                            if !f.isEmpty { store.update { $0.coachMemory.append(f) } }
                            newFact = ""
                        }
                        .disabled(newFact.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } footer: {
                    Text("Das weiß der Coach dauerhaft über dich: Ziele, Vorlieben, Umstände. Er schlägt selbst Dinge zum Merken vor, gespeichert wird nur, was du antippst. Alles bleibt auf deinem iPhone und wird nur zusammen mit einer Frage an deinen Worker geschickt.")
                }
            }
            .navigationTitle("Gedächtnis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
        }
    }
}

struct CoachSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var url = CoachConfig.url
    @State private var token = CoachConfig.token
    @State private var testing = false
    @State private var result: String?

    var body: some View {
        NavigationStack {
            SwiftUI.Form {
                Section {
                    TextField("https://form-coach.….workers.dev", text: $url)
                        .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                    SecureField("App-Token", text: $token)
                } header: {
                    Text("Dein Worker")
                } footer: {
                    Text("Adresse und App-Token aus der Einrichtung (docs/KI-COACH.md). Der Claude-API-Schlüssel bleibt im Worker und kommt nie aufs iPhone. Das Token liegt im Schlüsselbund.")
                }
                Section {
                    Button(testing ? "Teste …" : "Verbindung testen") { test() }.disabled(testing)
                    if let r = result { Text(r).font(.footnote) }
                }
            }
            .navigationTitle("Coach verbinden")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") { save(); dismiss() }
                }
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
            }
        }
    }

    private func save() {
        CoachConfig.url = url.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        CoachConfig.token = token.trimmingCharacters(in: .whitespaces)
    }

    private func test() {
        save()
        testing = true
        result = nil
        Task { @MainActor in
            do {
                var text = ""
                for try await c in CoachClient.stream(messages: [CoachMessage(role: "user", text: "Antworte nur mit: Verbindung steht.")], context: "Test") {
                    text += c
                }
                result = "✓ " + (text.isEmpty ? "Verbunden." : text)
            } catch {
                result = error.localizedDescription
            }
            testing = false
        }
    }
}

/// Beispielunterhaltung für Screenshots ohne Netzwerk
enum DemoCoach {
    static let history: [CoachMessage] = [
        CoachMessage(role: "user", text: "Gib mir mein Tagesbriefing"),
        CoachMessage(role: "assistant", text: answer),
    ]

    static let answer = """
    **Erholung 94, du bist bereit.** Deine HRV liegt mit 68 ms über deinem 7-Tage-Schnitt und im oberen Teil deines Normalbereichs, der Ruhepuls ist mit 46 so niedrig wie seit Wochen nicht. Das passt zu den 7:33 h Schlaf.

    **Training:** Heute stehen 13 km locker an. Bleib wirklich bei 4:56 bis 5:28/km, auch wenn es sich leicht anfühlt. Die harte Einheit kommt am Samstag, dafür sparst du dir die Frische.

    **Essen:** Bis jetzt 1.266 von 3.513 kcal und 109 g Eiweiß. Vor dem Lauf eine kohlenhydratreiche Mahlzeit, danach noch 30 bis 40 g Eiweiß, dann passt der Tag.

    **Schlaf:** Für 8:40 h Bedarf solltest du um 22:40 im Bett sein. Deine Schlafregelmäßigkeit ist mit 84 gut, am Wochenende gehst du im Schnitt 1,5 h später ins Bett.

    MERKEN: Ziel ist ein Halbmarathon unter 1:39 im Dezember
    """
}
