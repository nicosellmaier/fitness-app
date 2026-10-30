import SwiftUI
import Charts
import HealthKit

// MARK: Wasser

struct WaterCard: View {
    @Environment(DataStore.self) private var store
    let day: Date

    private var key: String { JournalBehavior.key(day) }
    private var ml: Double { store.data.water[key] ?? 0 }
    private var goal: Double { store.data.reminders.waterGoalMl }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Ring(progress: ml / max(1, goal), color: Color(hex: 0x6FD3FF), lineWidth: 7)
                Image(systemName: "drop.fill").font(.footnote.weight(.bold)).foregroundStyle(Color(hex: 0x6FD3FF))
            }
            .frame(width: 46, height: 46)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(Fmt.num(ml / 1000, 2)) von \(Fmt.num(goal / 1000, 1)) l").font(.subheadline.weight(.bold)).contentTransition(.numericText())
                Text(ml >= goal ? "Ziel erreicht" : "Wasser heute").font(.caption).foregroundStyle(ml >= goal ? Theme.good : Theme.muted)
            }
            Spacer()
            ForEach([250.0, 500.0], id: \.self) { amt in
                Button { add(amt) } label: {
                    Text("+\(Int(amt))").font(.caption.weight(.heavy)).padding(.horizontal, 10).padding(.vertical, 8)
                        .background(Theme.card2, in: Capsule())
                }
                .buttonStyle(.press)
            }
            if ml > 0 {
                Button { add(-250) } label: {
                    Image(systemName: "minus").font(.caption.weight(.heavy)).frame(width: 30, height: 30).background(Theme.card2, in: Circle())
                }
                .buttonStyle(.press)
            }
        }
        .padding(14)
        .background(CardBackground(radius: 20))
        .sensoryFeedback(.increase, trigger: ml)
    }

    private func add(_ amt: Double) {
        let k = key
        withAnimation(.snappy) { store.update { $0.water[k] = max(0, ($0.water[k] ?? 0) + amt) } }
        if amt > 0 { WaterHealth.save(ml: amt, at: entryDate(for: day)) }
    }
}

enum WaterHealth {
    static func save(ml: Double, at date: Date) {
        guard HKHealthStore.isHealthDataAvailable(), !UserDefaults.standard.bool(forKey: "demo") else { return }
        let type = HKQuantityType(.dietaryWater)
        let s = HKQuantitySample(type: type, quantity: HKQuantity(unit: .literUnit(with: .milli), doubleValue: ml), start: date, end: date)
        HKHealthStore().save(s) { _, _ in }
    }
}

// MARK: Gewicht

struct WeightCard: View {
    @Environment(DataStore.self) private var store
    @Environment(AppModel.self) private var model
    let day: Date
    @State private var editing = false
    @State private var value: Double = 75

    private var key: String { JournalBehavior.key(day) }
    private var logged: Double? { store.data.weightLog[key] ?? model.weights.last { Calendar.current.isDate($0.date, inSameDayAs: day) }?.value }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "scalemass.fill").font(.title3.weight(.bold)).foregroundStyle(Theme.bg)
                .frame(width: 44, height: 44).background(Theme.soft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(logged.map { Fmt.num($0, 1) + " kg" } ?? "Gewicht").font(.subheadline.weight(.bold))
                Text(logged == nil ? (model.weights.last.map { "Zuletzt \(Fmt.num($0.value, 1)) kg am \(Fmt.shortDay($0.date))" } ?? "Heute noch nicht gewogen") : trend)
                    .font(.caption).foregroundStyle(Theme.muted).lineLimit(1)
            }
            Spacer()
            NavigationLink { MetricDetailView(kind: .weight) } label: { Image(systemName: "chart.xyaxis.line").font(.subheadline.weight(.bold)).frame(width: 34, height: 34).background(Theme.card2, in: Circle()) }
                .buttonStyle(.press)
            Button {
                value = logged ?? model.weights.last?.value ?? model.weightKg ?? store.data.profile.weightKg
                editing = true
            } label: { Image(systemName: logged == nil ? "plus" : "pencil").font(.subheadline.weight(.bold)).frame(width: 34, height: 34).background(Theme.accent, in: Circle()).foregroundStyle(Theme.bg) }
                .buttonStyle(.press)
        }
        .padding(14)
        .background(CardBackground(radius: 20))
        .sheet(isPresented: $editing) { sheet }
    }

    private var trend: String {
        let w = model.weights
        guard w.count >= 7, let last = w.last else { return "Wochenschnitt folgt nach 7 Messungen" }
        let week = w.suffix(7).map(\.value)
        let avg = week.reduce(0, +) / Double(week.count)
        return "7-Tage-Schnitt \(Fmt.num(avg, 1)) kg · " + (last.value - avg >= 0 ? "+" : "−") + Fmt.num(abs(last.value - avg), 1)
    }

    private var sheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text(Fmt.num(value, 1) + " kg").font(.system(size: 54, weight: .heavy)).contentTransition(.numericText())
                HStack(spacing: 10) {
                    ForEach([-1.0, -0.1, 0.1, 1.0], id: \.self) { d in
                        Button { withAnimation(.snappy) { value = (value + d * 10).rounded() / 10 } } label: {
                            Text(d > 0 ? "+\(Fmt.num(d, 1))" : Fmt.num(d, 1)).font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
                                .background(CardBackground(radius: 14))
                        }
                        .buttonStyle(.press)
                    }
                }
                Slider(value: $value, in: 40...160, step: 0.1).tint(Theme.accent)
                Text("Wird auch in Apple Health gespeichert. Am besten morgens nach dem Aufstehen, vor dem Frühstück.").font(.caption).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
                Spacer()
            }
            .padding(24)
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("Gewicht \(Calendar.current.isDateInToday(day) ? "heute" : Fmt.shortDay(day))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { editing = false } }
                ToolbarItem(placement: .confirmationAction) { Button("Speichern") { save() } }
            }
        }
        .presentationDetents([.medium])
    }

    private func save() {
        let k = key, v = value, d = day
        store.update { $0.weightLog[k] = v; $0.profile.weightKg = v }
        let cal = Calendar.current
        var w = model.weights.filter { !cal.isDate($0.date, inSameDayAs: d) }
        w.append(Point(date: cal.startOfDay(for: d), value: v))
        model.weights = w.sorted { $0.date < $1.date }
        if cal.isDateInToday(d) { model.weightKg = v }
        if HKHealthStore.isHealthDataAvailable(), !model.usingDemo {
            let s = HKQuantitySample(type: HKQuantityType(.bodyMass), quantity: HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: v),
                                     start: entryDate(for: d), end: entryDate(for: d))
            HKHealthStore().save(s) { _, _ in }
        }
        editing = false
    }
}

// MARK: Verlauf

struct NutritionHistoryView: View {
    @Environment(DataStore.self) private var store
    @Environment(AppModel.self) private var model
    @State private var range = 30

    var body: some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let days: [Date] = (0..<range).map { cal.addDays($0 - (range - 1), to: today) }
        let rows: [(Date, Macros)] = days.map { ($0, Macros.sum(store.entries(on: $0))) }
        let logged = rows.filter { $0.1.kcal > 0 }
        let target = store.nutritionTargets(model: model, day: today).kcal
        let avgK = logged.isEmpty ? 0 : logged.map(\.1.kcal).reduce(0, +) / Double(logged.count)
        let avgP = logged.isEmpty ? 0 : logged.map(\.1.protein).reduce(0, +) / Double(logged.count)
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Zeitraum", selection: $range) {
                    Text("30 T").tag(30); Text("90 T").tag(90)
                }
                .pickerStyle(.segmented)
                HStack(spacing: 8) {
                    StatTile(title: "Ø Kalorien", value: logged.isEmpty ? "–" : Fmt.num(avgK), unit: "kcal", note: "Ziel \(Fmt.num(target))")
                    StatTile(title: "Ø Eiweiß", value: logged.isEmpty ? "–" : Fmt.num(avgP), unit: "g")
                    StatTile(title: "Getrackt", value: "\(logged.count)", unit: "/\(range)")
                }
                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Kalorien pro Tag").font(.headline)
                        Chart {
                            ForEach(rows, id: \.0) { r in
                                if r.1.kcal > 0 {
                                    BarMark(x: .value("Tag", r.0, unit: .day), y: .value("kcal", r.1.kcal))
                                        .foregroundStyle(r.1.kcal > target * 1.05 ? Theme.warn : Theme.accent).cornerRadius(2)
                                }
                            }
                            RuleMark(y: .value("Ziel", target)).foregroundStyle(Theme.muted).lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        }
                        .chartXAxis { AxisMarks(values: .automatic(desiredCount: 5)) { _ in AxisValueLabel(format: .dateTime.day().month(.defaultDigits)) } }
                        .frame(height: 160)
                    }
                }
                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Makros im Schnitt").font(.headline)
                        if logged.isEmpty {
                            Text("Noch nichts eingetragen.").font(.footnote).foregroundStyle(Theme.soft)
                        } else {
                            let p = avgP * 4, c = logged.map(\.1.carbs).reduce(0, +) / Double(logged.count) * 4, f = logged.map(\.1.fat).reduce(0, +) / Double(logged.count) * 9
                            let tot = max(1, p + c + f)
                            GeometryReader { geo in
                                HStack(spacing: 2) {
                                    Rectangle().fill(Theme.good).frame(width: geo.size.width * p / tot)
                                    Rectangle().fill(Theme.accent).frame(width: geo.size.width * c / tot)
                                    Rectangle().fill(Theme.warn).frame(width: geo.size.width * f / tot)
                                }
                                .clipShape(Capsule())
                            }
                            .frame(height: 12)
                            HStack {
                                legend("Eiweiß \(Int(p / tot * 100)) %", Theme.good)
                                legend("Kohlenhydrate \(Int(c / tot * 100)) %", Theme.accent)
                                legend("Fett \(Int(f / tot * 100)) %", Theme.warn)
                            }
                        }
                    }
                }
                if model.weights.count >= 2 {
                    Card {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Gewicht").font(.headline)
                                Spacer()
                                NavigationLink { MetricDetailView(kind: .weight) } label: { HStack(spacing: 4) { Text("Details").font(.caption.weight(.bold)); Chevron() } }
                                    .buttonStyle(.press)
                            }
                            let w = model.weights.filter { $0.date >= days.first! }
                            Chart(w) { p in
                                LineMark(x: .value("Tag", p.date), y: .value("kg", p.value)).foregroundStyle(Theme.soft).interpolationMethod(.catmullRom)
                                PointMark(x: .value("Tag", p.date), y: .value("kg", p.value)).foregroundStyle(Theme.soft).symbolSize(14)
                            }
                            .chartYScale(domain: .automatic(includesZero: false))
                            .frame(height: 120)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
        }
        .screenBackground()
        .navigationTitle("Verlauf")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func legend(_ t: String, _ c: Color) -> some View {
        HStack(spacing: 4) { Circle().fill(c).frame(width: 7, height: 7); Text(t).font(.caption2).foregroundStyle(Theme.soft) }
    }
}

// MARK: Schnell-Eintrag

struct QuickAddView: View {
    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let meal: Meal
    let day: Date
    var done: () -> Void = {}
    @State private var name = ""
    @State private var kcal: Double?
    @State private var protein: Double?
    @State private var carbs: Double?
    @State private var fat: Double?

    var body: some View {
        NavigationStack {
            SwiftUI.Form {
                Section {
                    TextField("Bezeichnung (optional)", text: $name)
                    row("Kalorien", "kcal", $kcal)
                } footer: { Text("Nur die Kalorien sind Pflicht. Makros, wenn du sie kennst, z. B. von der Speisekarte.") }
                Section("Makros") {
                    row("Eiweiß", "g", $protein)
                    row("Kohlenhydrate", "g", $carbs)
                    row("Fett", "g", $fat)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("Schnell-Eintrag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        let f = FoodItem.quick(kcal: kcal ?? 0, protein: protein ?? 0, carbs: carbs ?? 0, fat: fat ?? 0, name: name.isEmpty ? "Schnell-Eintrag" : name)
                        store.update { $0.entries.append(FoodEntry(date: entryDate(for: day), meal: meal, food: f, grams: 100)) }
                        dismiss(); done()
                    }
                    .disabled((kcal ?? 0) <= 0)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func row(_ t: String, _ u: String, _ v: Binding<Double?>) -> some View {
        HStack { Text(t); Spacer(); TextField("0", value: v, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 90); Text(u).foregroundStyle(Theme.muted) }
    }
}

// MARK: Rezepte

struct RecipeListView: View {
    @Environment(DataStore.self) private var store
    @State private var editing: Recipe?
    var onPick: ((FoodItem) -> Void)? = nil

    var body: some View {
        List {
            if store.data.recipes.isEmpty {
                Text("Noch keine Rezepte. Ein Rezept ist ein Lebensmittel aus mehreren Zutaten: einmal anlegen, danach mit einem Tipp eintragen.")
                    .font(.footnote).foregroundStyle(Theme.muted).listRowBackground(Theme.card)
            }
            ForEach(store.data.recipes) { r in
                Button {
                    if let onPick { onPick(r.asFood) } else { editing = r }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(r.name).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.text)
                            Text("\(r.ingredients.count) Zutaten · Portion \(Fmt.num(r.portionGrams)) g · E \(Fmt.num(r.totalProtein / max(1, r.portions))) g")
                                .font(.caption).foregroundStyle(Theme.muted)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 0) {
                            Text(Fmt.num(r.totalKcal / max(1, r.portions))).font(.subheadline.weight(.bold)).foregroundStyle(Theme.text)
                            Text("kcal/Portion").font(.caption2).foregroundStyle(Theme.muted)
                        }
                        if onPick != nil { Chevron() }
                    }
                }
                .swipeActions {
                    Button(role: .destructive) { store.update { $0.recipes.removeAll { $0.id == r.id } } } label: { Label("Löschen", systemImage: "trash") }
                    Button { editing = r } label: { Label("Bearbeiten", systemImage: "pencil") }.tint(Theme.sleep)
                }
            }
            .listRowBackground(Theme.card)
        }
        .scrollContentBackground(.hidden)
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle("Rezepte")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { editing = Recipe(name: "") } label: { Image(systemName: "plus") } } }
        .sheet(item: $editing) { r in RecipeEditor(recipe: r) }
    }
}

struct RecipeEditor: View {
    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var recipe: Recipe
    @State private var picking = false

    var body: some View {
        NavigationStack {
            SwiftUI.Form {
                Section {
                    TextField("Name, z. B. Overnight Oats", text: $recipe.name)
                    Stepper("Portionen: \(Fmt.num(recipe.portions, recipe.portions.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 1))", value: $recipe.portions, in: 0.5...20, step: 0.5)
                }
                Section {
                    ForEach($recipe.ingredients) { $ing in
                        HStack {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(ing.food.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                                Text("\(Fmt.num(ing.food.kcal * ing.grams / 100)) kcal").font(.caption).foregroundStyle(Theme.muted)
                            }
                            Spacer()
                            TextField("g", value: $ing.grams, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 70)
                            Text("g").foregroundStyle(Theme.muted)
                        }
                    }
                    .onDelete { recipe.ingredients.remove(atOffsets: $0) }
                    Button { picking = true } label: { Label("Zutat hinzufügen", systemImage: "plus") }
                } header: { Text("Zutaten") } footer: {
                    if !recipe.ingredients.isEmpty {
                        Text("Gesamt \(Fmt.num(recipe.totalGrams)) g, \(Fmt.num(recipe.totalKcal)) kcal. Pro Portion \(Fmt.num(recipe.portionGrams)) g, \(Fmt.num(recipe.totalKcal / max(1, recipe.portions))) kcal, \(Fmt.num(recipe.totalProtein / max(1, recipe.portions))) g Eiweiß.")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle(recipe.ingredients.isEmpty && recipe.name.isEmpty ? "Neues Rezept" : recipe.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        let r = recipe
                        store.update { d in
                            if let i = d.recipes.firstIndex(where: { $0.id == r.id }) { d.recipes[i] = r } else { d.recipes.append(r) }
                        }
                        dismiss()
                    }
                    .disabled(recipe.name.trimmingCharacters(in: .whitespaces).isEmpty || recipe.ingredients.isEmpty)
                }
            }
            .sheet(isPresented: $picking) {
                FoodPicker { f in
                    recipe.ingredients.append(RecipeIngredient(food: f, grams: f.serving ?? 100))
                    picking = false
                }
            }
        }
    }
}

/// Lebensmittel auswählen ohne Eintrag: für Rezepte und Mahlzeiten
struct FoodPicker: View {
    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let onPick: (FoodItem) -> Void
    @State private var query = ""
    @State private var results: [FoodItem] = []
    @State private var searching = false

    private var local: [FoodItem] {
        let q = query.lowercased()
        var seen = Set<String>()
        return (store.data.foods + store.recentFoods + FoodDB.basics).filter { f in
            guard !seen.contains(f.id), q.isEmpty || f.title.lowercased().contains(q) else { return false }
            seen.insert(f.id); return true
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section(query.isEmpty ? "Zuletzt und Basis" : "Deine Lebensmittel") {
                    ForEach(local.prefix(40)) { f in row(f) }
                }
                .listRowBackground(Theme.card)
                if !query.isEmpty {
                    Section("Datenbank") {
                        if searching { ProgressView() }
                        ForEach(results) { f in row(f) }
                    }
                    .listRowBackground(Theme.card)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bg.ignoresSafeArea())
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Zutat suchen")
            .task(id: query) {
                let q = query.trimmingCharacters(in: .whitespaces)
                guard q.count >= 2 else { results = []; return }
                try? await Task.sleep(nanoseconds: 450_000_000)
                if Task.isCancelled { return }
                searching = true
                results = (try? await FoodDB.search(q)) ?? []
                searching = false
            }
            .navigationTitle("Zutat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } } }
        }
    }

    private func row(_ f: FoodItem) -> some View {
        Button { onPick(f) } label: {
            HStack {
                Text(f.title).font(.subheadline).foregroundStyle(Theme.text).lineLimit(1)
                Spacer()
                Text("\(Fmt.num(f.kcal)) kcal").font(.caption.weight(.bold)).foregroundStyle(Theme.muted)
            }
        }
    }
}

// MARK: Gespeicherte Mahlzeiten

struct MealTemplatesView: View {
    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let meal: Meal
    let day: Date

    var body: some View {
        NavigationStack {
            List {
                if store.data.mealTemplates.isEmpty {
                    Text("Noch keine gespeicherten Mahlzeiten. Trag eine Mahlzeit ein und wähl im Menü der Mahlzeit \"Als Mahlzeit speichern\".")
                        .font(.footnote).foregroundStyle(Theme.muted).listRowBackground(Theme.card)
                }
                ForEach(store.data.mealTemplates) { t in
                    Button {
                        let stamp = entryDate(for: day)
                        store.update { d in for i in t.items { d.entries.append(FoodEntry(date: stamp, meal: meal, food: i.food, grams: i.grams)) } }
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(t.name).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.text)
                                Text(t.items.map(\.food.name).joined(separator: ", ")).font(.caption).foregroundStyle(Theme.muted).lineLimit(2)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 0) {
                                Text(Fmt.num(t.kcal)).font(.subheadline.weight(.bold)).foregroundStyle(Theme.text)
                                Text("E \(Fmt.num(t.protein)) g").font(.caption2).foregroundStyle(Theme.muted)
                            }
                        }
                    }
                    .swipeActions { Button(role: .destructive) { store.update { $0.mealTemplates.removeAll { $0.id == t.id } } } label: { Label("Löschen", systemImage: "trash") } }
                }
                .listRowBackground(Theme.card)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("Gespeicherte Mahlzeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Fertig") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }
}
