import Foundation

// MARK: - Model

struct PredefinedMeal: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let category: String       // matches MealType.rawValue
    let calories: Double
    let proteinGrams: Double?
    let carbohydrateGrams: Double?
    let fatGrams: Double?
    let serving: String

    var mealType: MealType {
        MealType(rawValue: category) ?? .snack
    }

    var macroSummary: String {
        var parts: [String] = ["\(Int(calories)) kcal"]
        if let p = proteinGrams  { parts.append("\(Int(p))g P") }
        if let c = carbohydrateGrams { parts.append("\(Int(c))g C") }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Service

@MainActor
final class PredefinedMealService {

    static let shared = PredefinedMealService()

    private var meals: [PredefinedMeal] = []

    private init() {
        load()
    }

    // MARK: - Query

    /// Returns all meals whose name contains the query (case-insensitive).
    /// If query is empty, returns all meals.
    func search(_ query: String) -> [PredefinedMeal] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return meals }
        return meals.filter { $0.name.localizedCaseInsensitiveContains(q) }
    }

    /// Returns meals matching the given MealType category.
    func meals(for type: MealType) -> [PredefinedMeal] {
        meals.filter { $0.category == type.rawValue }
    }

    // MARK: - Load

    private func load() {
        guard let url  = Bundle.main.url(forResource: "predefined_meals", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("[PredefinedMealService] predefined_meals.json not found in bundle")
            return
        }
        meals = (try? JSONDecoder().decode([PredefinedMeal].self, from: data)) ?? []
    }
}
