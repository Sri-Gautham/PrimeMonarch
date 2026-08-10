import Foundation

// MARK: - Day Meal Plan

struct MealSlot: Identifiable {
    let id: String
    let mealType: MealType
    let recipe: Recipe
}

struct DayMealPlan {
    let date: Date
    let slots: [MealSlot]

    var totalCalories: Int  { Int(slots.reduce(0) { $0 + $1.recipe.calories }) }
    var totalProtein: Double { slots.reduce(0) { $0 + $1.recipe.proteinGrams } }
    var totalCarbs: Double  { slots.reduce(0) { $0 + $1.recipe.carbohydrateGrams } }
    var totalFat: Double    { slots.reduce(0) { $0 + $1.recipe.fatGrams } }

    static let empty = DayMealPlan(date: Date(), slots: [])
}

// MARK: - Meal Plan Engine

enum MealPlanEngine {

    /// Deterministically builds a DayMealPlan from available recipes.
    /// The same inputs always produce the same output; the day-of-year rotates recipe selections.
    static func plan(
        for date: Date,
        calorieTarget: Int,
        mealsPerDay: Int,
        dietaryStyles: [DietaryStyle],
        catalog: [Recipe]
    ) -> DayMealPlan {
        let suitable = catalog.filter { $0.isSuitable(for: dietaryStyles) }
        let types    = mealTypes(for: mealsPerDay)
        let dayIndex = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1

        var slots: [MealSlot] = []

        for (i, type) in types.enumerated() {
            // Prefer suitable recipes; fall back to full catalog if dietary filters leave nothing.
            var candidates = suitable.filter { $0.category == type.rawValue }
            if candidates.isEmpty {
                candidates = catalog.filter { $0.category == type.rawValue }
            }
            guard !candidates.isEmpty else { continue }

            let fraction   = targetCalorieFraction(for: type, totalSlots: types.count)
            let targetCals = Double(calorieTarget) * fraction

            // Sort by proximity to the calorie target for this slot.
            let sorted = candidates.sorted { abs($0.calories - targetCals) < abs($1.calories - targetCals) }

            // Rotate recipe selection daily (offset per slot prevents all meals cycling in sync).
            let index  = (dayIndex + i * 7) % sorted.count
            let recipe = sorted[index]

            let cal = Calendar.current
            let slotId = "\(type.rawValue)_\(cal.component(.year, from: date))_\(cal.component(.month, from: date))_\(cal.component(.day, from: date))"
            slots.append(MealSlot(id: slotId, mealType: type, recipe: recipe))
        }

        return DayMealPlan(date: date, slots: slots)
    }

    // MARK: - Private

    private static func mealTypes(for count: Int) -> [MealType] {
        switch count {
        case 1:  return [.lunch]
        case 2:  return [.breakfast, .dinner]
        case 3:  return [.breakfast, .lunch, .dinner]
        default: return [.breakfast, .lunch, .dinner, .snack]
        }
    }

    private static func targetCalorieFraction(for type: MealType, totalSlots: Int) -> Double {
        switch type {
        case .breakfast: return 0.25
        case .lunch:     return totalSlots >= 4 ? 0.30 : 0.35
        case .dinner:    return totalSlots >= 4 ? 0.35 : 0.40
        case .snack:     return 0.10
        default:         return 1.0 / Double(max(totalSlots, 1))
        }
    }
}
