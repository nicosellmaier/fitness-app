import SwiftUI
import Charts

// MARK: Karte auf "Heute"

struct TonightCard: View {
    @Environment(AppModel.self) private var model
    @State private var alarmText: String?
    @State private var setting = false

    var body: some View {
        if let p = model.sleepPlan {
            VStack(alignment: .leading, spacing: 12) {
                NavigationLink { SleepPlanView() } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("HEUTE NACHT").font(.caption.weight(.heavy)).foregroundStyle(Theme.muted)
                            Spacer()
                            Text("Tagesplan").font(.caption.weight(.bold)).foregroundStyle(Theme.accent)
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.muted)
                        }
                        HStack(alignment: .bottom, spacing: 0) {
                            TimeBlock(title: "Ins Bett", time: p.bedtime, icon: "moon.fill", color: Theme.sleep)
                            Spacer()
                            VStack(spacing: 2) {
                                Text(Fmt.hm(p.planned) + " h").font(.subheadline.weight(.heavy))
                                Rectangle().fill(Theme.line).frame(width: 60, height: 1)
                                Text("Schlaf").font(.caption2).foregroundStyle(Theme.muted)
                            }
                            .padding(.bottom, 8)
                            Spacer()
                            TimeBlock(title: "Wecker", time: p.wake, icon: "alarm.fill", color: Theme.accent, trailing: true)
                        }
                        Text(p.sourceText).font(.caption).foregroundStyle(Theme.soft)
                        if let r = p.reasons.first(where: { !$0.hasPrefix(p.sourceText) }), !r.isEmpty {
                            Text(r).font(.caption).foregroundStyle(p.clampedEarly ? Theme.warn : Theme.soft).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                AlarmButtonRow(plan: p)
            }
            .padding(16)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }
}

struct TimeBlock: View {
    let title: String
    let time: Date
    let icon: String
    let color: Color
    var trailing = false

    var body: some View {
        VStack(alignment: trailing ? .trailing : .leading, spacing: 2) {
            Label(title, systemImage: icon).font(.caption.weight(.bold)).foregroundStyle(color)
            Text(Fmt.time(time)).font(.system(size: 34, weight: .heavy)).monospacedDigit()
        }
    }
}

struct AlarmButtonRow: View {
    let plan: SleepPlan
    @State private var scheduled = WakeAlarm.scheduledFor
    @State private var busy = false
    @State private var note: String?

    var body: some View {
        let isSet = scheduled.map { abs($0.timeIntervalSince(plan.wake)) < 60 } ?? false
        VStack(alignment: .leading, spacing: 6) {
            Button {
                busy = true
                Task { @MainActor in
                    if isSet {
                        await WakeAlarm.cancel()
                        note = nil
                    } else {
                        let r = await WakeAlarm.set(plan.wake)
                        switch r {
                        case .alarm: note = "Echter Wecker gestellt, klingelt auch im Lautlos-Modus."
                        case .notification: note = "Als Mitteilung gestellt. Für einen echten Wecker in den iPhone-Einstellungen Form den Wecker-Zugriff erlauben."
                        case .failed: note = "Der Zeitpunkt liegt in der Vergangenheit."
                        }
                    }
                    scheduled = WakeAlarm.scheduledFor
                    busy = false
                }
            } label: {
                Label(isSet ? "Wecker gestellt · \(Fmt.time(plan.wake))" : "Wecker auf \(Fmt.time(plan.wake)) stellen",
                      systemImage: isSet ? "checkmark.circle.fill" : "alarm")
                    .font(.subheadline.weight(.bold)).frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(isSet ? Theme.card2 : Theme.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .foregroundStyle(isSet ? Theme.text : Theme.bg)
            }
            .disabled(busy)
            if let n = note { Text(n).font(.caption).foregroundStyle(Theme.soft) }
            if let s = scheduled, !isSet {
                Text("Gestellt ist noch \(Fmt.time(s)). Tippen stellt auf den neuen Plan um.").font(.caption).foregroundStyle(Theme.warn)
            }
        }
        .onAppear { scheduled = WakeAlarm.scheduledFor }
    }
}

// MARK: Schlafplan im Detail

struct SleepPlanView: View {
    @Environment(AppModel.self) private var model
    @Environment(DataStore.self) private var store
    @State private var editWake = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let p = model.sleepPlan {
                    hero(p)
                    if true {
                        Card {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("So kommt der Plan zustande").font(.subheadline.weight(.bold))
                                reasonRow("calendar", p.sourceText)
                                reasonRow("bed.double", "Bedarf \(Fmt.hm(p.need)) h, dazu \(Fmt.num(p.extra / 60)) min zum Einschlafen und für Wachphasen (dein Schnitt)")
                                reasonRow("moon.stars", "Schlaffenster deiner inneren Uhr: \(Fmt.time(p.sleepGate.lowerBound))–\(Fmt.time(p.sleepGate.upperBound))")
                                ForEach(p.reasons, id: \.self) { r in reasonRow("info.circle", r) }
                            }
                        }
                    }
                    SectionHeader("Deine Energie heute")
                    EnergyCard()
                    SectionHeader("Dein Tag")
                    PlanTimeline(steps: model.planSteps)
                } else {
                    Card {
                        Text("Nach ein paar Nächten mit der Watch kennt die App deine gewohnten Zeiten und plant deine Nächte.")
                            .font(.footnote).foregroundStyle(Theme.soft)
                    }
                }
                SectionHeader("Schlafschuld", trailing: "14 Nächte")
                DebtCard()
                if let c = model.chronotype {
                    SectionHeader("Chronotyp")
                    Card {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(c.label).font(.headline)
                                Spacer()
                                Text("Schlafmitte \(Int(c.msfsc) / 60):" + String(format: "%02d", Int(c.msfsc) % 60)).font(.subheadline.weight(.bold)).foregroundStyle(Theme.sleep)
                            }
                            Text(c.text).font(.footnote).foregroundStyle(Theme.soft)
                            Text("Mitte deines Schlafs an freien Tagen, korrigiert um nachgeholten Schlaf (Roenneberg).").font(.caption).foregroundStyle(Theme.muted)
                        }
                    }
                }
                NavigationLink { SleepPrefsView() } label: {
                    Label("Weckzeiten, Kalender und Erinnerungen", systemImage: "slider.horizontal.3")
                        .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity).padding(.vertical, 13)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .padding(.top, 6)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
        }
        .screenBackground()
        .navigationTitle("Schlafplan")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $editWake) { WakeOverrideSheet() }
    }

    private func hero(_ p: SleepPlan) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .bottom) {
                TimeBlock(title: "Ins Bett", time: p.bedtime, icon: "moon.fill", color: Theme.sleep)
                Spacer()
                TimeBlock(title: "Wecker", time: p.wake, icon: "alarm.fill", color: Theme.accent, trailing: true)
            }
            HStack(spacing: 8) {
                mini("Geplant", Fmt.hm(p.planned) + " h")
                mini("Bedarf", Fmt.hm(p.need) + " h")
                mini("Runterfahren", Fmt.time(p.windDown))
            }
            AlarmButtonRow(plan: p)
            Button { editWake = true } label: {
                Text("Weckzeit für morgen ändern").font(.footnote.weight(.semibold)).frame(maxWidth: .infinity)
            }
            .foregroundStyle(Theme.soft)
        }
        .padding(18)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private func mini(_ t: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(t).font(.caption2.weight(.semibold)).foregroundStyle(Theme.muted)
            Text(v).font(.subheadline.weight(.heavy))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Theme.card2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func reasonRow(_ icon: String, _ t: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon).font(.caption.weight(.bold)).foregroundStyle(Theme.sleep).frame(width: 18)
            Text(t).font(.footnote).foregroundStyle(Theme.soft).fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct EnergyCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let pts = model.energyToday
        let steps = model.planSteps.filter { ["Morgenhoch", "Nachmittagstief", "Abendhoch"].contains($0.title) }
        Card {
            if pts.isEmpty {
                Text("Noch zu wenig Schlafdaten für deine Energiekurve.").font(.footnote).foregroundStyle(Theme.soft)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Chart {
                        ForEach(steps) { s in
                            RectangleMark(xStart: .value("von", s.time), xEnd: .value("bis", s.end ?? s.time), yStart: .value("u", 0), yEnd: .value("o", 100))
                                .foregroundStyle(s.color.opacity(0.10))
                        }
                        ForEach(pts) { p in
                            AreaMark(x: .value("Zeit", p.date), y: .value("Energie", p.level))
                                .foregroundStyle(LinearGradient(colors: [Theme.accent.opacity(0.45), Theme.accent.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                                .interpolationMethod(.catmullRom)
                            LineMark(x: .value("Zeit", p.date), y: .value("Energie", p.level))
                                .foregroundStyle(Theme.accent).lineStyle(StrokeStyle(lineWidth: 2.5)).interpolationMethod(.catmullRom)
                        }
                        if let first = pts.first?.date, let last = pts.last?.date, Date.now > first, Date.now < last {
                            RuleMark(x: .value("Jetzt", Date.now)).foregroundStyle(Theme.text.opacity(0.6))
                                .annotation(position: .top, alignment: .center) {
                                    Text("Jetzt").font(.caption2.weight(.bold)).foregroundStyle(Theme.text)
                                }
                        }
                    }
                    .chartYScale(domain: 0...105)
                    .chartYAxis(.hidden)
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .hour, count: 3)) { _ in
                            AxisGridLine().foregroundStyle(Theme.line)
                            AxisValueLabel(format: .dateTime.hour(.twoDigits(amPM: .omitted)).locale(Fmt.de))
                        }
                    }
                    .frame(height: 170)
                    HStack(spacing: 12) {
                        ForEach(steps) { s in
                            VStack(alignment: .leading, spacing: 1) {
                                Text(s.title).font(.caption2.weight(.bold)).foregroundStyle(s.color)
                                Text(Fmt.time(s.time) + "–" + Fmt.time(s.end ?? s.time)).font(.caption.weight(.semibold)).monospacedDigit()
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    Text("Modell aus innerer Uhr und Schlafdruck (Zwei-Prozess-Modell), angepasst an deine Aufwachzeit, Schlafzeiten und Schlafschuld.")
                        .font(.caption).foregroundStyle(Theme.muted)
                }
            }
        }
    }
}

struct PlanTimeline: View {
    let steps: [PlanStep]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.element.id) { i, s in
                let past = (s.end ?? s.time) < .now
                HStack(alignment: .top, spacing: 12) {
                    VStack(spacing: 0) {
                        Image(systemName: s.icon).font(.footnote.weight(.bold)).foregroundStyle(Theme.bg)
                            .frame(width: 30, height: 30).background(s.color, in: Circle())
                        if i < steps.count - 1 { Rectangle().fill(Theme.line).frame(width: 2).frame(maxHeight: .infinity) }
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(s.title).font(.subheadline.weight(.bold))
                            Spacer()
                            Text(Fmt.time(s.time) + (s.end.map { "–" + Fmt.time($0) } ?? "")).font(.footnote.weight(.heavy)).monospacedDigit()
                        }
                        Text(s.detail).font(.caption).foregroundStyle(Theme.soft).fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.bottom, 14)
                }
                .opacity(past ? 0.45 : 1)
            }
        }
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

struct DebtCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let d = model.sleepDebt
        Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(Fmt.num(d.hours, 1) + " h").font(.title.weight(.heavy))
                    Text(d.label).font(.subheadline.weight(.bold)).foregroundStyle(d.color)
                    Spacer()
                    Text("Bedarf \(Fmt.hm(d.need)) h").font(.caption).foregroundStyle(Theme.muted)
                }
                Chart {
                    ForEach(d.nights, id: \.date) { n in
                        BarMark(x: .value("Nacht", n.date, unit: .day), y: .value("Schlaf", n.slept / 3600))
                            .foregroundStyle(n.slept >= d.need ? Theme.good : n.slept >= d.need - 3600 ? Theme.warn : Theme.bad)
                            .cornerRadius(3)
                    }
                    RuleMark(y: .value("Bedarf", d.need / 3600)).foregroundStyle(Theme.muted).lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }
                .chartYScale(domain: 0...max(10, (d.nights.map { $0.slept / 3600 }.max() ?? 9) + 0.5))
                .frame(height: 120)
                Text("Wie Rise: Summe aus Bedarf minus Schlaf der letzten 14 Nächte, neuere Nächte zählen mehr, Nächte mit mehr Schlaf zahlen zurück. Unter 5 h ist gut. Der Plan baut die Schuld in kleinen Schritten ab: früher ins Bett statt am Wochenende lang ausschlafen.")
                    .font(.caption).foregroundStyle(Theme.muted)
            }
        }
    }
}

struct WakeOverrideSheet: View {
    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var time = Date.now

    private var key: String { JournalBehavior.key(SleepPlanner.nextWakeDay()) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                DatePicker("Weckzeit", selection: $time, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel).labelsHidden().environment(\.locale, Fmt.de)
                Text("Gilt nur für morgen. Danach plant die App wieder automatisch.").font(.footnote).foregroundStyle(Theme.soft)
                if store.data.sleepPrefs.wakeOverride[key] != nil {
                    Button("Automatisch planen", role: .destructive) {
                        store.update { $0.sleepPrefs.wakeOverride[key] = nil }
                        dismiss()
                    }
                }
                Spacer()
            }
            .padding(20)
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("Weckzeit morgen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        let c = Calendar.current.dateComponents([.hour, .minute], from: time)
                        let m = (c.hour ?? 7) * 60 + (c.minute ?? 0)
                        let k = key
                        store.update { d in
                            d.sleepPrefs.wakeOverride = d.sleepPrefs.wakeOverride.filter { ($0.key >= JournalBehavior.key(.now)) }
                            d.sleepPrefs.wakeOverride[k] = m
                        }
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: Einstellungen

struct SleepPrefsView: View {
    @Environment(DataStore.self) private var store
    @Environment(AppModel.self) private var model
    @State private var prefs = SleepPrefs()
    @State private var calAuthorized = CalendarService.authorized
    @State private var loaded = false

    private let days: [(Int, String)] = [(2, "Montag"), (3, "Dienstag"), (4, "Mittwoch"), (5, "Donnerstag"), (6, "Freitag"), (7, "Samstag"), (1, "Sonntag")]

    var body: some View {
        SwiftUI.Form {
            Section {
                Stepper("Vorlauf: \(prefs.prepMinutes) min", value: $prefs.prepMinutes, in: 15...180, step: 5)
            } header: {
                Text("Morgens")
            } footer: {
                Text("Zeit vom Aufwachen bis zum ersten Termin: Duschen, Frühstück, Weg. Bei Pendeln mit Zug oder Auto großzügig rechnen.")
            }

            Section {
                Toggle("Kalender nutzen", isOn: $prefs.useCalendar)
                if prefs.useCalendar {
                    if calAuthorized {
                        ForEach(CalendarService.calendars(), id: \.calendarIdentifier) { c in
                            Toggle(isOn: Binding(
                                get: { prefs.calendarIDs.isEmpty || prefs.calendarIDs.contains(c.calendarIdentifier) },
                                set: { on in
                                    var ids = prefs.calendarIDs.isEmpty ? CalendarService.calendars().map(\.calendarIdentifier) : prefs.calendarIDs
                                    if on { ids.append(c.calendarIdentifier) } else { ids.removeAll { $0 == c.calendarIdentifier } }
                                    let all = CalendarService.calendars().map(\.calendarIdentifier)
                                    prefs.calendarIDs = Set(ids) == Set(all) ? [] : Array(Set(ids))
                                })) {
                                HStack {
                                    Circle().fill(Color(cgColor: c.cgColor)).frame(width: 10, height: 10)
                                    Text(c.title)
                                }
                            }
                        }
                    } else {
                        Button("Zugriff auf Kalender erlauben") {
                            Task { @MainActor in calAuthorized = await CalendarService.requestAccess() }
                        }
                    }
                }
            } header: {
                Text("Kalender")
            } footer: {
                Text("Der erste Termin am Morgen bestimmt die Weckzeit. Ganztägige und als frei markierte Termine zählen nicht. Kalenderdaten bleiben auf dem iPhone.")
            }

            Section {
                ForEach(days, id: \.0) { item in
                    let wd = item.0
                    let name = item.1
                    HStack {
                        Toggle(name, isOn: Binding(
                            get: { prefs.fixedWake[wd] != nil },
                            set: { on in prefs.fixedWake[wd] = on ? (prefs.fixedWake[wd] ?? 6 * 60 + 30) : nil }))
                        if let m = prefs.fixedWake[wd] {
                            DatePicker("", selection: Binding(
                                get: { Calendar.current.startOfDay(for: .now).addingTimeInterval(Double(m) * 60) },
                                set: { d in
                                    let c = Calendar.current.dateComponents([.hour, .minute], from: d)
                                    prefs.fixedWake[wd] = (c.hour ?? 6) * 60 + (c.minute ?? 30)
                                }), displayedComponents: .hourAndMinute)
                                .labelsHidden().environment(\.locale, Fmt.de)
                        }
                    }
                }
            } header: {
                Text("Feste Weckzeiten")
            } footer: {
                Text("Für Tage mit festem Beginn, zum Beispiel Arbeit. Ein früherer Kalendertermin hat trotzdem Vorrang. Ohne feste Zeit und ohne Termin nimmt die App deine übliche Aufstehzeit.")
            }

            Section {
                Toggle("Wecker automatisch stellen", isOn: $prefs.autoAlarm)
            } footer: {
                Text(WakeAlarm.usesRealAlarm ? "Stellt jeden Abend einen echten Wecker auf die geplante Zeit. Er klingelt auch im Lautlos-Modus und lässt sich wie ein normaler Wecker ausschalten." : "Ab iOS 26 stellt die App einen echten Wecker. Davor kommt eine Mitteilung mit Ton.")
            }

            Section("Erinnerungen") {
                Toggle("Letzter Kaffee", isOn: $prefs.remindCaffeine)
                Toggle("Runterfahren (1 h vor dem Schlafen)", isOn: $prefs.remindWindDown)
                Toggle("Tageslicht am Morgen", isOn: $prefs.remindMorningLight)
                Toggle("Schlafenszeit (30 min vorher)", isOn: Binding(
                    get: { store.data.profile.bedtimeReminder },
                    set: { v in store.update { $0.profile.bedtimeReminder = v } }))
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle("Schlafplan")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard !loaded else { return }
            loaded = true
            prefs = store.data.sleepPrefs
        }
        .onChange(of: prefs) { _, new in
            store.update { $0.sleepPrefs = new }
            Task { await Notifications.requestPermission() }
        }
    }
}
