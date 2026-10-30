import SwiftUI
import Charts
import VisionKit

// MARK: Ziele berechnen

extension DataStore {
    func entries(on day: Date) -> [FoodEntry] {
        data.entries.filter { Calendar.current.isDate($0.date, inSameDayAs: day) }
    }

    /// Kalorien- und Makroziel für einen Tag: Grundumsatz, Aktivität, geplanter Lauf und Ziel
    func nutritionTargets(model: AppModel, day: Date) -> NutritionTargets {
        var p = data.profile
        if let w = model.weightKg, w > 30 { p.weightKg = w }
        let isToday = Calendar.current.isDateInToday(day)
        var runKm: Double = 0
        if let plan = data.plan, let r = plan.run(on: day), r.type != .rest, r.type != .cross, r.status != .missed {
            runKm = plan.paces.totalMeters(r.structure) / 1000
        }
        // Heute zählt der geplante Lauf vorab, damit du vor dem Lauf genug isst.
        // Ist er schon gelaufen, steckt er in der aktiven Energie und wird nicht doppelt gezählt.
        if isToday, let r = data.plan?.run(on: day), r.status == .done { runKm = 0 }
        return NutritionTargets.make(profile: p, activeKcal: isToday ? model.activeKcalToday : 0, plannedRunKm: runKm)
    }

    var recentFoods: [FoodItem] {
        var seen = Set<String>()
        var out: [FoodItem] = []
        for e in data.entries.sorted(by: { $0.date > $1.date }) where !seen.contains(e.food.id) {
            seen.insert(e.food.id)
            out.append(e.food)
            if out.count >= 25 { break }
        }
        return out
    }
}

// MARK: Tagesansicht

struct NutritionView: View {
    @Environment(DataStore.self) private var store
    @Environment(AppModel.self) private var model
    @State private var day = Calendar.current.startOfDay(for: .now)
    @State private var addMeal: Meal?
    @State private var editing: FoodEntry?
    @State private var showBreakdown = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    dayPicker
                    let entries = store.entries(on: day)
                    let sum = Macros.sum(entries)
                    let t = store.nutritionTargets(model: model, day: day)
                    summary(sum, t)
                    if showBreakdown { breakdown(t) }
                    trainingHint(t)
                    ForEach(Meal.allCases) { meal in
                        mealSection(meal, entries.filter { $0.meal == meal })
                    }
                    SectionHeader("Letzte 7 Tage")
                    WeekKcalChart(endDay: day, target: t.kcal)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
            .screenBackground()
            .navigationTitle("Ernährung")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { addMeal = Meal.now } label: { Image(systemName: "plus.circle.fill").font(.title3) }
                }
            }
            .sheet(item: $addMeal) { meal in AddFoodView(meal: meal, day: day) }
            .sheet(item: $editing) { e in AmountView(food: e.food, meal: e.meal, day: e.date, existing: e) { editing = nil } }
        }
    }

    private var dayPicker: some View {
        let cal = Calendar.current
        let isToday = cal.isDateInToday(day)
        return HStack {
            Button { day = cal.addDays(-1, to: day) } label: { Image(systemName: "chevron.left").font(.headline).frame(width: 40, height: 36) }
            Spacer()
            VStack(spacing: 0) {
                Text(isToday ? "Heute" : cal.isDateInYesterday(day) ? "Gestern" : Fmt.shortDay(day)).font(.headline)
                if !isToday { Button("Zu heute") { day = cal.startOfDay(for: .now) }.font(.caption) }
            }
            Spacer()
            Button { day = cal.addDays(1, to: day) } label: { Image(systemName: "chevron.right").font(.headline).frame(width: 40, height: 36) }
                .disabled(isToday)
        }
        .foregroundStyle(Theme.text)
    }

    private func summary(_ m: Macros, _ t: NutritionTargets) -> some View {
        let left = t.kcal - m.kcal
        return VStack(spacing: 16) {
            HStack(spacing: 20) {
                ZStack {
                    Ring(progress: m.kcal / max(1, t.kcal), color: m.kcal > t.kcal * 1.05 ? Theme.warn : Theme.accent, lineWidth: 13)
                    VStack(spacing: 0) {
                        Text(Fmt.num(abs(left))).font(.title2.weight(.heavy)).monospacedDigit()
                        Text(left >= 0 ? "übrig" : "drüber").font(.caption.weight(.semibold)).foregroundStyle(Theme.muted)
                    }
                }
                .frame(width: 118, height: 118)
                VStack(alignment: .leading, spacing: 8) {
                    kv("Ziel", Fmt.num(t.kcal) + " kcal")
                    kv("Gegessen", Fmt.num(m.kcal) + " kcal")
                    Button { withAnimation { showBreakdown.toggle() } } label: {
                        Label(showBreakdown ? "Weniger" : "So entsteht dein Ziel", systemImage: "info.circle")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(Theme.accent)
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 10) {
                MacroBar(name: "Eiweiß", value: m.protein, target: t.protein, color: Theme.accent)
                MacroBar(name: "Kohlenhydrate", value: m.carbs, target: t.carbs, color: Theme.sleep)
                MacroBar(name: "Fett", value: m.fat, target: t.fat, color: Theme.warn)
            }
        }
        .padding(18)
        .background(CardBackground(radius: 26))
    }

    private func kv(_ k: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(k).font(.caption.weight(.semibold)).foregroundStyle(Theme.muted)
            Text(v).font(.headline.weight(.heavy)).monospacedDigit()
        }
    }

    private func breakdown(_ t: NutritionTargets) -> some View {
        Card {
            VStack(spacing: 0) {
                MetricRow(title: "Grundumsatz", subtitle: "Mifflin-St Jeor aus Größe, Gewicht, Alter", value: Fmt.num(t.bmr) + " kcal")
                Divider().overlay(Theme.line)
                MetricRow(title: "Alltag & Bewegung", subtitle: "Aktive Energie laut Watch plus Grundbewegung", value: "+" + Fmt.num(t.activity) + " kcal")
                if t.plannedBonus > 0 {
                    Divider().overlay(Theme.line)
                    MetricRow(title: "Geplanter Lauf", subtitle: "Etwa 1 kcal pro kg und km", value: "+" + Fmt.num(t.plannedBonus) + " kcal")
                }
                if t.goalDelta != 0 {
                    Divider().overlay(Theme.line)
                    MetricRow(title: "Ziel: " + store.data.profile.goal.label, value: (t.goalDelta > 0 ? "+" : "−") + Fmt.num(abs(t.goalDelta)) + " kcal")
                }
                Divider().overlay(Theme.line)
                MetricRow(title: "Eiweiß", subtitle: "\(Fmt.num(store.data.profile.proteinPerKg, 1)) g pro kg Körpergewicht", value: Fmt.num(t.protein) + " g")
            }
        }
    }

    @ViewBuilder private func trainingHint(_ t: NutritionTargets) -> some View {
        if t.plannedBonus > 0, let r = store.data.plan?.run(on: day) {
            Hint(icon: "fork.knife", title: "Trainingstag: \(r.title)",
                 text: "Dein Ziel liegt \(Fmt.num(t.plannedBonus)) kcal höher. Das meiste davon als Kohlenhydrate, idealerweise 2 bis 3 Stunden vor dem Lauf und danach mit Eiweiß.",
                 color: Theme.sleep)
        } else if store.restrictions.trainingPaused {
            Hint(icon: "cross.case", title: "Krank", text: "Genug trinken und essen. Jetzt ist kein guter Moment für ein Defizit.", color: Theme.warn)
        }
    }

    private func mealSection(_ meal: Meal, _ entries: [FoodEntry]) -> some View {
        let kcal = entries.reduce(0) { $0 + $1.kcal }
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(meal.label).font(.headline)
                Text(entries.isEmpty ? "" : Fmt.num(kcal) + " kcal").font(.subheadline).foregroundStyle(Theme.muted)
                Spacer()
                Menu {
                    Button { addMeal = meal } label: { Label("Lebensmittel hinzufügen", systemImage: "plus") }
                    Button { copyYesterday(meal) } label: { Label("Von gestern übernehmen", systemImage: "doc.on.doc") }
                } label: {
                    Image(systemName: "plus").font(.headline).frame(width: 34, height: 30)
                        .background(Theme.card2, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                } primaryAction: {
                    addMeal = meal
                }
            }
            .padding(.vertical, 12)
            ForEach(entries) { e in
                Divider().overlay(Theme.line)
                Button { editing = e } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(e.food.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                            Text("\(Fmt.num(e.grams)) g · E \(Fmt.num(e.protein)) · K \(Fmt.num(e.carbs)) · F \(Fmt.num(e.fat))")
                                .font(.caption).foregroundStyle(Theme.muted)
                        }
                        Spacer()
                        Text(Fmt.num(e.kcal)).font(.subheadline.weight(.bold)).monospacedDigit()
                    }
                    .padding(.vertical, 9)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.press)
                .contextMenu {
                    Button(role: .destructive) { store.update { $0.entries.removeAll { $0.id == e.id } } } label: { Label("Löschen", systemImage: "trash") }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, entries.isEmpty ? 0 : 6)
        .background(CardBackground(radius: 22))
    }

    private func copyYesterday(_ meal: Meal) {
        let y = Calendar.current.addDays(-1, to: day)
        let items = store.entries(on: y).filter { $0.meal == meal }
        guard !items.isEmpty else { return }
        let stamp = entryDate(for: day)
        store.update { d in
            for e in items { d.entries.append(FoodEntry(date: stamp, meal: meal, food: e.food, grams: e.grams)) }
        }
    }
}

/// Einträge für heute bekommen die aktuelle Uhrzeit, andere Tage 12 Uhr
func entryDate(for day: Date) -> Date {
    let cal = Calendar.current
    if cal.isDateInToday(day) { return .now }
    return cal.date(bySettingHour: 12, minute: 0, second: 0, of: day) ?? day
}

struct MacroBar: View {
    let name: String
    let value: Double
    let target: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(name).font(.caption.weight(.semibold)).foregroundStyle(Theme.muted).lineLimit(1).minimumScaleFactor(0.8)
            Bar(fraction: value / max(1, target), color: value > target * 1.1 ? Theme.warn : color, height: 6)
            Text("\(Fmt.num(value)) / \(Fmt.num(target)) g").font(.caption.weight(.bold)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct WeekKcalChart: View {
    @Environment(DataStore.self) private var store
    let endDay: Date
    let target: Double

    var body: some View {
        let cal = Calendar.current
        let days: [Date] = (0..<7).map { cal.addDays($0 - 6, to: cal.startOfDay(for: endDay)) }
        let values: [(Date, Double)] = days.map { d in (d, store.entries(on: d).reduce(0) { $0 + $1.kcal }) }
        let logged = values.filter { $0.1 > 0 }
        let avg = logged.isEmpty ? 0 : logged.reduce(0) { $0 + $1.1 } / Double(logged.count)
        let avgProtein: Double = {
            let p = days.map { d in store.entries(on: d).reduce(0) { $0 + $1.protein } }.filter { $0 > 0 }
            return p.isEmpty ? 0 : p.reduce(0, +) / Double(p.count)
        }()
        return Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    StatInline(title: "Ø Kalorien", value: logged.isEmpty ? "–" : Fmt.num(avg) + " kcal")
                    StatInline(title: "Ø Eiweiß", value: avgProtein > 0 ? Fmt.num(avgProtein) + " g" : "–")
                    StatInline(title: "Getrackt", value: "\(logged.count) von 7 Tagen")
                }
                Chart {
                    ForEach(values, id: \.0) { v in
                        BarMark(x: .value("Tag", v.0, unit: .day), y: .value("kcal", v.1))
                            .foregroundStyle(v.1 > target * 1.05 ? Theme.warn : Theme.accent)
                            .cornerRadius(5)
                    }
                    RuleMark(y: .value("Ziel", target))
                        .foregroundStyle(Theme.muted)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.narrow), centered: true)
                    }
                }
                .chartYAxis { AxisMarks(position: .leading) }
                .frame(height: 140)
            }
        }
    }
}

// MARK: Hinzufügen

struct AddFoodView: View {
    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var meal: Meal
    let day: Date

    @State private var query = ""
    @State private var results: [FoodItem] = []
    @State private var searching = false
    @State private var searchError: String?
    @State private var selected: FoodItem?
    @State private var scanning = false
    @State private var lookingUp = false
    @State private var notFound: String?
    @State private var missingCode: String?
    @State private var showCustom = false
    @State private var tab = 0

    init(meal: Meal, day: Date) {
        _meal = State(initialValue: meal)
        self.day = day
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Mahlzeit", selection: $meal) {
                        ForEach(Meal.allCases) { Text($0.label).tag($0) }
                    }
                    if scannerAvailable {
                        Button { scanning = true } label: {
                            Label(lookingUp ? "Suche Produkt …" : "Barcode scannen", systemImage: "barcode.viewfinder")
                        }
                        .disabled(lookingUp)
                    }
                    Button { missingCode = nil; showCustom = true } label: { Label("Eigenes Lebensmittel anlegen", systemImage: "square.and.pencil") }
                }
                .listRowBackground(Theme.card)

                if let nf = notFound {
                    Section {
                        Text(nf).font(.footnote).foregroundStyle(Theme.warn)
                        if missingCode != nil {
                            Button { showCustom = true } label: { Label("Jetzt anlegen", systemImage: "plus") }
                        }
                    }
                    .listRowBackground(Theme.card)
                }

                if query.trimmingCharacters(in: .whitespaces).isEmpty {
                    Section {
                        Picker("", selection: $tab) {
                            Text("Zuletzt").tag(0)
                            Text("Basis").tag(1)
                            Text("Eigene").tag(2)
                        }
                        .pickerStyle(.segmented)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                    }
                    Section {
                        let list = tab == 0 ? store.recentFoods : tab == 1 ? FoodDB.basics : store.data.foods.filter(\.custom)
                        if list.isEmpty {
                            Text(tab == 0 ? "Noch nichts eingetragen. Suche oben oder scanne einen Barcode." : "Noch keine eigenen Lebensmittel.")
                                .font(.footnote).foregroundStyle(Theme.muted)
                        }
                        ForEach(list) { f in foodRow(f) }
                            .onDelete(perform: tab == 2 ? deleteCustom : nil)
                    }
                    .listRowBackground(Theme.card)
                } else {
                    let local = localMatches
                    if !local.isEmpty {
                        Section("Deine Lebensmittel") { ForEach(local) { foodRow($0) } }
                            .listRowBackground(Theme.card)
                    }
                    Section {
                        if searching {
                            HStack { ProgressView(); Text("Suche in Open Food Facts …").foregroundStyle(Theme.muted) }
                        } else if let e = searchError {
                            Text(e).font(.footnote).foregroundStyle(Theme.warn)
                        } else if results.isEmpty {
                            Text("Nichts gefunden. Versuch es mit einem anderen Wort oder lege es selbst an.").font(.footnote).foregroundStyle(Theme.muted)
                        }
                        ForEach(results) { foodRow($0) }
                    } header: {
                        Text("Datenbank")
                    } footer: {
                        Text("Daten von Open Food Facts. Werte pro 100 g.")
                    }
                    .listRowBackground(Theme.card)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bg.ignoresSafeArea())
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Lebensmittel oder Marke")
            .task(id: query) { await search() }
            .navigationTitle("Hinzufügen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Fertig") { dismiss() } } }
            .sheet(item: $selected) { f in
                AmountView(food: f, meal: meal, day: day, existing: nil) { dismiss() }
            }
            .sheet(isPresented: $showCustom) {
                CustomFoodView(barcode: missingCode) { f in
                    showCustom = false
                    notFound = nil
                    missingCode = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { selected = f }
                }
            }
            .fullScreenCover(isPresented: $scanning) {
                ScannerScreen { code in
                    scanning = false
                    Task { await lookup(code) }
                }
            }
        }
    }

    private var scannerAvailable: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    private var localMatches: [FoodItem] {
        let q = query.lowercased()
        var seen = Set<String>()
        return (store.data.foods + store.recentFoods + FoodDB.basics).filter { f in
            guard !seen.contains(f.id), f.title.lowercased().contains(q) else { return false }
            seen.insert(f.id)
            return true
        }
    }

    private func foodRow(_ f: FoodItem) -> some View {
        Button { selected = f } label: {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(f.name).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.text).lineLimit(2)
                    Text((f.brand.isEmpty ? "" : f.brand + " · ") + "E \(Fmt.num(f.protein, 1)) · K \(Fmt.num(f.carbs, 1)) · F \(Fmt.num(f.fat, 1))")
                        .font(.caption).foregroundStyle(Theme.muted).lineLimit(1)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text(Fmt.num(f.kcal)).font(.subheadline.weight(.bold)).foregroundStyle(Theme.text).monospacedDigit()
                    Text("kcal").font(.caption2).foregroundStyle(Theme.muted)
                }
            }
        }
    }

    private func deleteCustom(_ idx: IndexSet) {
        let list = store.data.foods.filter(\.custom)
        let ids = Set(idx.map { list[$0].id })
        store.update { $0.foods.removeAll { ids.contains($0.id) } }
    }

    private func search() async {
        let q = query.trimmingCharacters(in: .whitespaces)
        searchError = nil
        guard q.count >= 2 else { results = []; return }
        try? await Task.sleep(nanoseconds: 450_000_000)
        if Task.isCancelled { return }
        searching = true
        defer { searching = false }
        do {
            let r = try await FoodDB.search(q)
            if Task.isCancelled { return }
            results = r
        } catch {
            if Task.isCancelled || (error as? URLError)?.code == .cancelled { return }
            searchError = "Suche gerade nicht erreichbar. Prüfe die Verbindung."
        }
    }

    private func lookup(_ code: String) async {
        notFound = nil
        missingCode = nil
        if let known = (store.data.foods + store.recentFoods).first(where: { $0.id == code }) {
            selected = known
            return
        }
        lookingUp = true
        defer { lookingUp = false }
        do {
            if let f = try await FoodDB.product(barcode: code) {
                selected = f
            } else {
                missingCode = code
                notFound = "Produkt \(code) ist nicht in der Datenbank. Lege es einmal als eigenes Lebensmittel an, dann kennt die App es."
            }
        } catch {
            notFound = "Konnte das Produkt nicht laden. Prüfe die Verbindung."
        }
    }
}

// MARK: Menge wählen

struct AmountView: View {
    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let food: FoodItem
    let day: Date
    let existing: FoodEntry?
    let done: () -> Void
    @State private var meal: Meal
    @State private var grams: Double
    @FocusState private var focused: Bool

    init(food: FoodItem, meal: Meal, day: Date, existing: FoodEntry?, done: @escaping () -> Void) {
        self.food = food
        self.day = day
        self.existing = existing
        self.done = done
        _meal = State(initialValue: existing?.meal ?? meal)
        _grams = State(initialValue: existing?.grams ?? food.serving ?? 100)
    }

    var body: some View {
        let f = grams / 100
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(food.name).font(.title3.weight(.heavy))
                        if !food.brand.isEmpty { Text(food.brand).font(.subheadline).foregroundStyle(Theme.muted) }
                    }
                    HStack(alignment: .firstTextBaseline) {
                        TextField("Menge", value: $grams, format: .number.precision(.fractionLength(0...1)).locale(Fmt.de))
                            .keyboardType(.decimalPad)
                            .focused($focused)
                            .font(.system(size: 44, weight: .heavy))
                            .monospacedDigit()
                            .fixedSize()
                        Text("g").font(.title2.weight(.bold)).foregroundStyle(Theme.muted)
                        Spacer()
                        Stepper("", value: $grams, in: 0...5000, step: 5).labelsHidden()
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            if let s = food.serving, s > 0 {
                                chip("1 Portion (\(Fmt.num(s)) g)") { grams = s }
                                chip("2 Portionen") { grams = s * 2 }
                            }
                            ForEach([50.0, 100, 150, 200, 250, 300], id: \.self) { g in chip("\(Int(g)) g") { grams = g } }
                        }
                    }
                    HStack(spacing: 8) {
                        StatTile(title: "Kalorien", value: Fmt.num(food.kcal * f), unit: "kcal")
                        StatTile(title: "Eiweiß", value: Fmt.num(food.protein * f, 1), unit: "g")
                    }
                    HStack(spacing: 8) {
                        StatTile(title: "Kohlenhydrate", value: Fmt.num(food.carbs * f, 1), unit: "g")
                        StatTile(title: "Fett", value: Fmt.num(food.fat * f, 1), unit: "g")
                    }
                    Picker("Mahlzeit", selection: $meal) {
                        ForEach(Meal.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Text("Pro 100 g: \(Fmt.num(food.kcal)) kcal · E \(Fmt.num(food.protein, 1)) g · K \(Fmt.num(food.carbs, 1)) g · F \(Fmt.num(food.fat, 1)) g")
                        .font(.caption).foregroundStyle(Theme.muted)
                    if existing != nil {
                        Button(role: .destructive) {
                            store.update { $0.entries.removeAll { $0.id == existing?.id } }
                            dismiss()
                            done()
                        } label: {
                            Text("Eintrag löschen").font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(CardBackground(radius: 14))
                        }
                    }
                }
                .padding(16)
            }
            .screenBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(existing == nil ? "Hinzufügen" : "Sichern") { save() }.disabled(grams <= 0).fontWeight(.bold)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Fertig") { focused = false }
                }
            }
        }
        .presentationDetents([.large])
    }

    private func chip(_ t: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(t).font(.footnote.weight(.bold)).padding(.horizontal, 12).padding(.vertical, 8)
                .background(Theme.card2, in: Capsule())
        }
        .buttonStyle(.press)
    }

    private func save() {
        if let e = existing {
            store.update { d in
                if let i = d.entries.firstIndex(where: { $0.id == e.id }) {
                    d.entries[i].grams = grams
                    d.entries[i].meal = meal
                }
            }
        } else {
            store.update { $0.entries.append(FoodEntry(date: entryDate(for: day), meal: meal, food: food, grams: grams)) }
        }
        dismiss()
        done()
    }
}

// MARK: Eigenes Lebensmittel

struct CustomFoodView: View {
    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var barcode: String? = nil
    let created: (FoodItem) -> Void
    @State private var name = ""
    @State private var brand = ""
    @State private var kcal: Double?
    @State private var protein: Double?
    @State private var carbs: Double?
    @State private var fat: Double?
    @State private var serving: Double?

    var body: some View {
        NavigationStack {
            SwiftUI.Form {
                Section {
                    TextField("Name", text: $name)
                    TextField("Marke (optional)", text: $brand)
                }
                Section {
                    numField("Kalorien", "kcal", $kcal)
                    numField("Eiweiß", "g", $protein)
                    numField("Kohlenhydrate", "g", $carbs)
                    numField("Fett", "g", $fat)
                } header: {
                    Text("Pro 100 g")
                } footer: {
                    Text("Steht auf der Verpackung in der Nährwerttabelle.")
                }
                Section("Portion (optional)") {
                    numField("Eine Portion", "g", $serving)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("Eigenes Lebensmittel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") { save() }.disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || kcal == nil)
                }
            }
        }
    }

    private func numField(_ title: String, _ unit: String, _ value: Binding<Double?>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("0", value: value, format: .number.locale(Fmt.de))
                .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 90)
            Text(unit).foregroundStyle(Theme.muted).frame(width: 34, alignment: .leading)
        }
    }

    private func save() {
        let f = FoodItem(id: barcode ?? "c_" + UUID().uuidString, name: name.trimmingCharacters(in: .whitespaces),
                         brand: brand.trimmingCharacters(in: .whitespaces), kcal: kcal ?? 0, protein: protein ?? 0,
                         carbs: carbs ?? 0, fat: fat ?? 0, serving: serving, custom: true)
        store.update { $0.foods.append(f) }
        created(f)
    }
}

// MARK: Barcode-Scanner

struct ScannerScreen: View {
    @Environment(\.dismiss) private var dismiss
    let found: (String) -> Void

    var body: some View {
        ZStack(alignment: .top) {
            BarcodeScanner(found: found).ignoresSafeArea()
            VStack {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.headline).padding(12).background(.ultraThinMaterial, in: Circle())
                    }
                }
                Spacer()
                Text("Barcode in den Rahmen halten").font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, 40)
            }
            .padding(16)
        }
    }
}

struct BarcodeScanner: UIViewControllerRepresentable {
    let found: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(found: found) }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let vc = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.ean13, .ean8, .upce, .code128])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: true
        )
        vc.delegate = context.coordinator
        try? vc.startScanning()
        return vc
    }

    func updateUIViewController(_ vc: DataScannerViewController, context: Context) {
        if !vc.isScanning { try? vc.startScanning() }
    }

    static func dismantleUIViewController(_ vc: DataScannerViewController, coordinator: Coordinator) {
        vc.stopScanning()
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let found: (String) -> Void
        private var done = false

        init(found: @escaping (String) -> Void) { self.found = found }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            handle(addedItems)
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            handle([item])
        }

        private func handle(_ items: [RecognizedItem]) {
            guard !done else { return }
            for item in items {
                if case .barcode(let b) = item, let code = b.payloadStringValue, !code.isEmpty {
                    done = true
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    found(code)
                    return
                }
            }
        }
    }
}
