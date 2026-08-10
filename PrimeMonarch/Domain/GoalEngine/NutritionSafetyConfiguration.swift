import Foundation

// MARK: - Nutrition Safety Configuration
//
// Hard limits that the goal engine must never violate.
// A single source of truth — reviewed before each release.

struct NutritionSafetyConfiguration {
    let minimumCaloriesMale: Double
    let minimumCaloriesFemale: Double
    let maximumDailyDeficit: Double
    let maximumDailySurplus: Double
    let maximumWeightLossRateKgPerWeek: Double
    let maximumWeightGainRateKgPerWeek: Double

    // SAFETY: Floors and caps below require professional nutrition review before shipping.
    static let `default` = NutritionSafetyConfiguration(
        minimumCaloriesMale: 1500,
        minimumCaloriesFemale: 1200,
        maximumDailyDeficit: 1000,
        maximumDailySurplus: 500,
        maximumWeightLossRateKgPerWeek: 0.9,
        maximumWeightGainRateKgPerWeek: 0.45
    )

    func minimumCalories(for sex: BiologicalSex) -> Double {
        sex == .male ? minimumCaloriesMale : minimumCaloriesFemale
    }
}
