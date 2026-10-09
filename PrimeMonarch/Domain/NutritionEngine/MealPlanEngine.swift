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
    ///
    /// Selection order of safety guarantees (strongest first):
    /// 1. Hard allergy/avoid filter — recipes containing any `avoidTerms` term are never served.
    /// 2. Dietary-style filter — restricted to styles in `dietaryStyles`; falls back to the
    ///    allergen-safe pool (NOT the full catalog) when no suitable candidates exist.
    /// 3. Macro-fit scoring — recipes are scored by weighted normalised deviation across
    ///    calories (40%), protein (35%), carbs (15%) and fat (10%). Protein is weighted
    ///    highest to honour body-composition goals.
    /// 4. Daily variety — the final selection rotates within the top-5 best-fitting candidates
    ///    so the same inputs produce the same plan on the same day, yet change day-to-day.
    static func plan(
        for date: Date,
        calorieTarget: Int,
        proteinTarget: Int,
        carbTarget: Int,
        fatTarget: Int,
        mealsPerDay: Int,
        dietaryStyles: [DietaryStyle],
        avoidTerms: [String],
        catalog: [Recipe]
    ) -> DayMealPlan {
        // 1. Hard allergy / avoid filter — applied once, never bypassed downstream.
        let safe     = avoidTerms.isEmpty ? catalog : catalog.filter { !$0.contains(anyOf: avoidTerms) }
        let suitable = safe.filter { $0.isSuitable(for: dietaryStyles) }
        let types    = mealTypes(for: mealsPerDay)
        let dayIndex = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1

        var slots: [MealSlot] = []

        for (i, type) in types.enumerated() {
            // Prefer dietary-suitable recipes; fall back to the allergen-safe pool (never full catalog).
            var candidates = suitable.filter { $0.category == type.rawValue }
            if candidates.isEmpty {
                candidates = safe.filter { $0.category == type.rawValue }
            }
            guard !candidates.isEmpty else { continue }

            let fraction       = targetCalorieFraction(for: type, totalSlots: types.count)
            let slotCalTarget  = Double(calorieTarget)  * fraction
            let slotProtTarget = Double(proteinTarget)  * fraction
            let slotCarbTarget = Double(carbTarget)     * fraction
            let slotFatTarget  = Double(fatTarget)      * fraction

            // Score each recipe by weighted normalised deviation from per-slot macro targets.
            // Lower score = better fit. Normalise by slot target to keep units comparable.
            let scored: [(Recipe, Double)] = candidates.map { recipe in
                let calDev  = abs(recipe.calories           - slotCalTarget)  / max(slotCalTarget,  1)
                let protDev = abs(recipe.proteinGrams       - slotProtTarget) / max(slotProtTarget, 1)
                let carbDev = abs(recipe.carbohydrateGrams  - slotCarbTarget) / max(slotCarbTarget, 1)
                let fatDev  = abs(recipe.fatGrams           - slotFatTarget)  / max(slotFatTarget,  1)
                let score   = 0.40 * calDev + 0.35 * protDev + 0.15 * carbDev + 0.10 * fatDev
                return (recipe, score)
            }

            // Sort ascending (best fit first), then rotate within the top-K for daily variety.
            let sorted = scored.sorted { $0.1 < $1.1 }.map(\.0)
            let K      = min(5, sorted.count)
            let index  = (dayIndex + i * 7) % K
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
