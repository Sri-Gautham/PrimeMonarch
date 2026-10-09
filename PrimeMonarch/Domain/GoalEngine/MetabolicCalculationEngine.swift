import Foundation

// MARK: - Metabolic Calculation Engine
//
// Pure, side-effect-free Mifflin–St Jeor implementations.
// No SwiftData, no service dependencies — safe to call from tests directly.

enum MetabolicCalculationEngine {

    /// Basal Metabolic Rate in kcal/day using the Mifflin–St Jeor formula.
    static func bmr(
        weightKg: Double,
        heightCm: Double,
        ageYears: Int,
        sex: BiologicalSex
    ) -> Double {
        let base = (10 * weightKg) + (6.25 * heightCm) - (5 * Double(ageYears))
        return sex == .male ? base + 5 : base - 161
    }

    /// Total Daily Energy Expenditure = BMR × activity-level multiplier.
    static func tdee(bmr: Double, activityLevel: ActivityLevel) -> Double {
        bmr * activityLevel.tdeeMultiplier
    }

    /// Derives protein, carbohydrate and fat targets from a daily calorie goal.
    ///
    /// Protein uses grams-per-kilogram of body weight when weight is known
    /// (rate varies by goal: 2.0 g/kg cutting → 1.8 building → 1.6 else).
    /// Falls back to a percentage-of-calories approach when weight is unavailable.
    /// Fat is fixed at ~27% of calories (22% for endurance goals).
    /// Carbs take the remaining calories after protein and fat are accounted for.
    static func macros(
        calories: Int,
        weightKg: Double?,
        goal: GoalType,
        sex: BiologicalSex
    ) -> (protein: Int, carbs: Int, fat: Int) {
        let cal = Double(calories)

        // -- Protein --
        let proteinGrams: Double
        if let kg = weightKg, kg > 0 {
            let gPerKg: Double
            switch goal {
            case .loseWeight, .reduceFat:          gPerKg = 2.0
            case .buildMuscle, .maintainMuscle:    gPerKg = 1.8
            case .improveEndurance:                gPerKg = 1.6
            default:                               gPerKg = 1.6
            }
            proteinGrams = gPerKg * kg
        } else {
            // Fallback: percentage of calories ÷ 4 kcal/g
            let pct: Double
            switch goal {
            case .loseWeight, .reduceFat:          pct = 0.35
            case .buildMuscle, .maintainMuscle:    pct = 0.30
            default:                               pct = 0.25
            }
            proteinGrams = (cal * pct) / 4.0
        }

        // -- Fat --
        let fatPct: Double = goal == .improveEndurance ? 0.22 : 0.27
        let fatGrams = (cal * fatPct) / 9.0

        // -- Carbs (remainder, never negative) --
        let carbsCal  = cal - (proteinGrams * 4) - (fatGrams * 9)
        let carbGrams = max(0, carbsCal / 4.0)

        return (
            protein: Int(proteinGrams.rounded()),
            carbs:   Int(carbGrams.rounded()),
            fat:     Int(fatGrams.rounded())
        )
    }
}
