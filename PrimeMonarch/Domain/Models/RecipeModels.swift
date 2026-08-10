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
}
