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
}
