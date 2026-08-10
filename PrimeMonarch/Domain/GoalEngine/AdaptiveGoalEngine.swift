import Foundation

// MARK: - Goal Engine I/O

struct GoalEngineInput {
    let weightKg: Double?
    let heightCm: Double?
    let ageYears: Int?
    let biologicalSex: BiologicalSex
    let activityLevel: ActivityLevel
    let primaryGoal: GoalType
    let typicalDailySteps: Int
}

struct GoalEngineOutput {
    let calorieTarget: Int
    let waterTargetMilliliters: Int
    let stepTarget: Int
    let workoutBurnTarget: Int
    let calorieExplanation: String
    let waterExplanation: String
    let stepExplanation: String
    let dataConfidence: Double   // 0.0 – 1.0
    let engineVersion: String
}

// MARK: - Adaptive Goal Engine

enum AdaptiveGoalEngine {

    static let currentVersion = "3.0"

    /// Computes all daily targets from a typed input.
    /// Always returns a value — falls back to safe defaults when bio data is missing.
    static func compute(
        input: GoalEngineInput,
        safety: NutritionSafetyConfiguration = .default
    ) -> GoalEngineOutput {
        let (calories, calorieExplanation, confidence) = computeCalories(input: input, safety: safety)
        let water = computeWater(weightKg: input.weightKg)
        let steps = input.typicalDailySteps > 0 ? input.typicalDailySteps : 8000
        let burn  = WorkoutPlans.estimatedBurnKcal(for: input.primaryGoal, intensity: .standard)

        return GoalEngineOutput(
            calorieTarget:          calories,
            waterTargetMilliliters: water,
            stepTarget:             steps,
            workoutBurnTarget:      burn,
            calorieExplanation:     calorieExplanation,
            waterExplanation:       "~35 ml per kg body weight",
            stepExplanation:        "Based on your activity level",
            dataConfidence:         confidence,
            engineVersion:          currentVersion
        )
    }

    // MARK: - Private

    private static func computeCalories(
        input: GoalEngineInput,
        safety: NutritionSafetyConfiguration
    ) -> (target: Int, explanation: String, confidence: Double) {
        guard let weight = input.weightKg,
              let height = input.heightCm,
              let age    = input.ageYears else {
            // Insufficient bio data — return safety minimum + modest buffer
            let fallback = Int(safety.minimumCalories(for: input.biologicalSex)) + 300
            return (fallback, "Add your body stats for a personalised target", 0.3)
        }

        let bmr  = MetabolicCalculationEngine.bmr(
            weightKg: weight, heightCm: height, ageYears: age, sex: input.biologicalSex
        )
        let tdee = MetabolicCalculationEngine.tdee(bmr: bmr, activityLevel: input.activityLevel)

        var goalAdjustment: Double = 0
        var explanation: String

        switch input.primaryGoal {
        case .loseWeight, .reduceFat:
            goalAdjustment = -min(500, safety.maximumDailyDeficit)
            explanation    = "500 kcal deficit from TDEE"
        case .buildMuscle:
            goalAdjustment = min(250, safety.maximumDailySurplus)
            explanation    = "250 kcal surplus from TDEE"
        default:
            explanation = "Matches your energy expenditure"
        }

        let raw     = tdee + goalAdjustment
        let floored = max(raw, safety.minimumCalories(for: input.biologicalSex))
        return (Int(floored), explanation, 0.9)
    }

    private static func computeWater(weightKg: Double?) -> Int {
        guard let kg = weightKg, kg > 0 else { return 2500 }
        return Int(min(max(kg * 35, 1_800), 4_000))
    }
}
