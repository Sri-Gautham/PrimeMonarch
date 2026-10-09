import Foundation

// MARK: - Ingredient

struct Ingredient: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let amount: Double
    let unit: String            // "g", "ml", "piece", "slice", "tsp"
    let groceryCategory: String // "produce", "protein", "dairy", "grains", "pantry", "condiments"
}

// MARK: - Recipe

struct Recipe: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let category: String           // MealType.rawValue
    let calories: Double
    let proteinGrams: Double
    let carbohydrateGrams: Double
    let fatGrams: Double
    let servings: Int
    let prepMinutes: Int
    let cookMinutes: Int
    let ingredients: [Ingredient]
    let instructions: [String]
    let dietaryStyleTags: [String] // DietaryStyle.rawValue — styles this recipe is suitable for

    var mealType: MealType { MealType(rawValue: category) ?? .snack }
    var totalMinutes: Int { prepMinutes + cookMinutes }

    var macroSummary: String {
        "\(Int(calories)) kcal · \(Int(proteinGrams))g P · \(Int(carbohydrateGrams))g C · \(Int(fatGrams))g F"
    }

    /// Returns true when this recipe is compatible with all of the user's dietary preferences.
    func isSuitable(for styles: [DietaryStyle]) -> Bool {
        if styles.isEmpty || styles.contains(.noRestrictions) { return true }
        return styles.allSatisfy { dietaryStyleTags.contains($0.rawValue) }
    }

    /// Returns true if any ingredient name (or the recipe name itself) contains
    /// any of the given terms as a case-insensitive substring match.
    /// Used to hard-exclude recipes that conflict with a user's allergies or foods-to-avoid.
    /// Returns false when `terms` is empty (no restrictions).
    func contains(anyOf terms: [String]) -> Bool {
        guard !terms.isEmpty else { return false }
        let lowerTerms   = terms.map { $0.lowercased() }
        let searchTargets = ingredients.map { $0.name.lowercased() } + [name.lowercased()]
        return lowerTerms.contains { term in
            searchTargets.contains { $0.contains(term) }
        }
    }
}
