import Foundation

enum Meal: String, Codable, CaseIterable, Identifiable {
    case breakfast, lunch, dinner, snack

    var id: String { rawValue }

    var label: String {
        switch self {
        case .breakfast: return "Frühstück"
        case .lunch: return "Mittagessen"
        case .dinner: return "Abendessen"
        case .snack: return "Snacks"
        }
    }

    static var now: Meal {
        let h = Calendar.current.component(.hour, from: .now)
        if h < 11 { return .breakfast }
        if h < 15 { return .lunch }
        if h < 17 { return .snack }
        return .dinner
    }
}

struct FoodItem: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var brand: String = ""
    var kcal: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var serving: Double? = nil
    var custom = false

    var title: String { brand.isEmpty ? name : "\(name) · \(brand)" }
}

struct FoodEntry: Identifiable, Codable, Hashable {
    var id = UUID()
    var date: Date
    var meal: Meal
    var food: FoodItem
    var grams: Double

    var factor: Double { grams / 100 }
    var kcal: Double { food.kcal * factor }
    var protein: Double { food.protein * factor }
    var carbs: Double { food.carbs * factor }
    var fat: Double { food.fat * factor }
}

struct Macros {
    var kcal: Double = 0
    var protein: Double = 0
    var carbs: Double = 0
    var fat: Double = 0

    static func sum(_ entries: [FoodEntry]) -> Macros {
        entries.reduce(Macros()) { m, e in
            Macros(kcal: m.kcal + e.kcal, protein: m.protein + e.protein, carbs: m.carbs + e.carbs, fat: m.fat + e.fat)
        }
    }
}

struct NutritionTargets {
    var bmr: Double
    var activity: Double
    var plannedBonus: Double
    var goalDelta: Double
    var kcal: Double
    var protein: Double
    var carbs: Double
    var fat: Double

    static func make(profile p: Profile, activeKcal: Double, plannedRunKm: Double) -> NutritionTargets {
        let base: Double = 10 * p.weightKg + 6.25 * p.heightCm - 5 * Double(p.age)
        let bmr: Double = base + (p.sex == .male ? 5 : -161)
        let everyday: Double = bmr * 0.2
        let bonus: Double = plannedRunKm * p.weightKg * 1.0
        let kcal: Double = max(1400, bmr + everyday + activeKcal + bonus + p.goal.kcalDelta)
        let protein: Double = p.proteinPerKg * p.weightKg
        let fat: Double = kcal * 0.27 / 9
        let carbs: Double = max(0, (kcal - protein * 4 - fat * 9) / 4)
        return NutritionTargets(bmr: bmr, activity: everyday + activeKcal, plannedBonus: bonus, goalDelta: p.goal.kcalDelta,
                                kcal: kcal, protein: protein, carbs: carbs, fat: fat)
    }
}

/// Open Food Facts: freie Lebensmitteldatenbank, gut für deutsche Supermarktprodukte
enum FoodDB {
    private static let fields = "code,product_name,product_name_de,brands,nutriments,serving_quantity"

    private static func request(_ url: URL) -> URLRequest {
        var r = URLRequest(url: url, timeoutInterval: 15)
        r.setValue("Form-App/1.0 (privat)", forHTTPHeaderField: "User-Agent")
        return r
    }

    static func product(barcode: String) async throws -> FoodItem? {
        guard let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(barcode).json?fields=\(fields)") else { return nil }
        let (data, _) = try await URLSession.shared.data(for: request(url))
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let p = json["product"] as? [String: Any] else { return nil }
        return parse(p, fallbackId: barcode)
    }

    static func search(_ query: String) async throws -> [FoodItem] {
        var comps = URLComponents(string: "https://world.openfoodfacts.org/cgi/search.pl")
        comps?.queryItems = [
            URLQueryItem(name: "search_terms", value: query),
            URLQueryItem(name: "search_simple", value: "1"),
            URLQueryItem(name: "action", value: "process"),
            URLQueryItem(name: "json", value: "1"),
            URLQueryItem(name: "page_size", value: "30"),
            URLQueryItem(name: "lc", value: "de"),
            URLQueryItem(name: "fields", value: fields),
        ]
        guard let url = comps?.url else { return [] }
        let (data, _) = try await URLSession.shared.data(for: request(url))
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let products = json["products"] as? [[String: Any]] else { return [] }
        return products.compactMap { parse($0, fallbackId: UUID().uuidString) }
    }

    private static func num(_ v: Any?) -> Double? {
        if let d = v as? Double { return d }
        if let i = v as? Int { return Double(i) }
        if let s = v as? String { return Double(s.replacingOccurrences(of: ",", with: ".")) }
        return nil
    }

    private static func parse(_ p: [String: Any], fallbackId: String) -> FoodItem? {
        let n = p["nutriments"] as? [String: Any] ?? [:]
        let name = ((p["product_name_de"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? (p["product_name"] as? String) ?? "").trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return nil }
        var kcal = num(n["energy-kcal_100g"])
        if kcal == nil, let kj = num(n["energy_100g"]) { kcal = kj / 4.184 }
        guard let k = kcal else { return nil }
        let brand = ((p["brands"] as? String) ?? "").components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces) ?? ""
        return FoodItem(id: (p["code"] as? String) ?? fallbackId, name: name, brand: brand, kcal: k,
                        protein: num(n["proteins_100g"]) ?? 0, carbs: num(n["carbohydrates_100g"]) ?? 0, fat: num(n["fat_100g"]) ?? 0,
                        serving: num(p["serving_quantity"]))
    }

    /// Häufige Grundnahrungsmittel ohne Barcode
    static let basics: [FoodItem] = [
        FoodItem(id: "b_oats", name: "Haferflocken", kcal: 372, protein: 13.5, carbs: 58.7, fat: 7),
        FoodItem(id: "b_rice", name: "Reis, gekocht", kcal: 130, protein: 2.7, carbs: 28, fat: 0.3),
        FoodItem(id: "b_pasta", name: "Nudeln, gekocht", kcal: 150, protein: 5.5, carbs: 30, fat: 0.9),
        FoodItem(id: "b_potato", name: "Kartoffeln, gekocht", kcal: 72, protein: 2, carbs: 15, fat: 0.1),
        FoodItem(id: "b_bread", name: "Vollkornbrot", kcal: 220, protein: 7.5, carbs: 39, fat: 2.5),
        FoodItem(id: "b_chicken", name: "Hähnchenbrust, gebraten", kcal: 165, protein: 31, carbs: 0, fat: 3.6),
        FoodItem(id: "b_egg", name: "Ei", kcal: 143, protein: 12.6, carbs: 0.7, fat: 9.5, serving: 60),
        FoodItem(id: "b_skyr", name: "Skyr natur", kcal: 63, protein: 11, carbs: 4, fat: 0.2),
        FoodItem(id: "b_quark", name: "Magerquark", kcal: 67, protein: 12, carbs: 4, fat: 0.3),
        FoodItem(id: "b_milk", name: "Milch 1,5 %", kcal: 47, protein: 3.4, carbs: 4.9, fat: 1.5),
        FoodItem(id: "b_banana", name: "Banane", kcal: 89, protein: 1.1, carbs: 22.8, fat: 0.3, serving: 120),
        FoodItem(id: "b_apple", name: "Apfel", kcal: 52, protein: 0.3, carbs: 13.8, fat: 0.2, serving: 150),
        FoodItem(id: "b_salmon", name: "Lachs", kcal: 208, protein: 20, carbs: 0, fat: 13),
        FoodItem(id: "b_beef", name: "Rinderhack", kcal: 250, protein: 26, carbs: 0, fat: 15),
        FoodItem(id: "b_tofu", name: "Tofu", kcal: 144, protein: 15, carbs: 3, fat: 8.5),
        FoodItem(id: "b_oil", name: "Olivenöl", kcal: 884, protein: 0, carbs: 0, fat: 100, serving: 10),
        FoodItem(id: "b_pb", name: "Erdnussbutter", kcal: 588, protein: 25, carbs: 20, fat: 50, serving: 20),
        FoodItem(id: "b_whey", name: "Whey Protein", kcal: 380, protein: 78, carbs: 7, fat: 5, serving: 30),
        FoodItem(id: "b_cheese", name: "Gouda", kcal: 356, protein: 25, carbs: 0, fat: 28, serving: 30),
        FoodItem(id: "b_nuts", name: "Mandeln", kcal: 579, protein: 21, carbs: 22, fat: 50, serving: 30),
    ]
}
