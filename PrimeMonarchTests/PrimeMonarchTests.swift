//
//  PrimeMonarchTests.swift
//  PrimeMonarchTests
//
//  Created by Sri Gautham Subramani on 8/2/26.
//

import Testing
@testable import PrimeMonarch

// MARK: - Metabolic Calculation Engine

struct MetabolicCalculationEngineTests {

    @Test func bmrMale() {
        // 80 kg, 175 cm, 30 yo male
        // (10×80) + (6.25×175) − (5×30) + 5 = 800 + 1093.75 − 150 + 5 = 1748.75
        let result = MetabolicCalculationEngine.bmr(
            weightKg: 80, heightCm: 175, ageYears: 30, sex: .male
        )
        #expect(abs(result - 1748.75) < 0.01)
    }

    @Test func bmrFemale() {
        // 60 kg, 165 cm, 25 yo female
        // (10×60) + (6.25×165) − (5×25) − 161 = 600 + 1031.25 − 125 − 161 = 1345.25
        let result = MetabolicCalculationEngine.bmr(
            weightKg: 60, heightCm: 165, ageYears: 25, sex: .female
        )
        #expect(abs(result - 1345.25) < 0.01)
    }

    @Test func tdeeModerate() {
        // BMR 1748.75 × 1.55 (moderately active) = 2710.5625
        let tdee = MetabolicCalculationEngine.tdee(bmr: 1748.75, activityLevel: .moderatelyActive)
        #expect(abs(tdee - 2710.5625) < 0.01)
    }

    @Test func tdeeSedentary() {
        let tdee = MetabolicCalculationEngine.tdee(bmr: 1500, activityLevel: .sedentary)
        #expect(abs(tdee - 1800.0) < 0.01)
    }
}

// MARK: - Nutrition Safety Configuration

struct NutritionSafetyConfigurationTests {

    @Test func defaultMaleFloor() {
        #expect(NutritionSafetyConfiguration.default.minimumCalories(for: .male) == 1500)
    }

    @Test func defaultFemaleFloor() {
        #expect(NutritionSafetyConfiguration.default.minimumCalories(for: .female) == 1200)
    }

    @Test func defaultMaxDeficit() {
        #expect(NutritionSafetyConfiguration.default.maximumDailyDeficit == 1000)
    }

    @Test func defaultMaxSurplus() {
        #expect(NutritionSafetyConfiguration.default.maximumDailySurplus == 500)
    }
}

// MARK: - Adaptive Goal Engine

struct AdaptiveGoalEngineTests {

    private let maleInput = GoalEngineInput(
        weightKg: 80, heightCm: 175, ageYears: 30,
        biologicalSex: .male,
        activityLevel: .moderatelyActive,
        primaryGoal: .maintainHealth,
        typicalDailySteps: 9000
    )

    @Test func confidenceHighWithFullProfile() {
        let output = AdaptiveGoalEngine.compute(input: maleInput)
        #expect(output.dataConfidence == 0.9)
    }

    @Test func confidenceLowWithoutBioData() {
        let input = GoalEngineInput(
            weightKg: nil, heightCm: nil, ageYears: nil,
            biologicalSex: .male,
            activityLevel: .moderatelyActive,
            primaryGoal: .maintainHealth,
            typicalDailySteps: 8000
        )
        let output = AdaptiveGoalEngine.compute(input: input)
        #expect(output.dataConfidence == 0.3)
    }

    @Test func caloriesMaintenanceMale() {
        // TDEE ≈ 2710 — maintenance means no goal adjustment
        let output = AdaptiveGoalEngine.compute(input: maleInput)
        #expect(output.calorieTarget > 2500)
        #expect(output.calorieTarget < 3000)
    }

    @Test func caloriesDeficitApplied() {
        // TDEE ≈ 2710, minus 500 deficit = ≈ 2210
        let input = GoalEngineInput(
            weightKg: 80, heightCm: 175, ageYears: 30,
            biologicalSex: .male,
            activityLevel: .moderatelyActive,
            primaryGoal: .loseWeight,
            typicalDailySteps: 8000
        )
        let output = AdaptiveGoalEngine.compute(input: input)
        #expect(output.calorieTarget > 2000)
        #expect(output.calorieTarget < 2500)
    }

    @Test func caloriesSurplusApplied() {
        // TDEE ≈ 2710, plus 250 surplus = ≈ 2960
        let input = GoalEngineInput(
            weightKg: 80, heightCm: 175, ageYears: 30,
            biologicalSex: .male,
            activityLevel: .moderatelyActive,
            primaryGoal: .buildMuscle,
            typicalDailySteps: 8000
        )
        let output = AdaptiveGoalEngine.compute(input: input)
        #expect(output.calorieTarget > 2700)
        #expect(output.calorieTarget < 3200)
    }

    @Test func safetyFloorClampsFemale() {
        // Very small/elderly female — raw TDEE − 500 falls below 1200
        let input = GoalEngineInput(
            weightKg: 38, heightCm: 148, ageYears: 75,
            biologicalSex: .female,
            activityLevel: .sedentary,
            primaryGoal: .loseWeight,
            typicalDailySteps: 4000
        )
        let output = AdaptiveGoalEngine.compute(input: input)
        #expect(output.calorieTarget >= 1200)
    }

    @Test func safetyFloorClampsMale() {
        let input = GoalEngineInput(
            weightKg: 45, heightCm: 155, ageYears: 80,
            biologicalSex: .male,
            activityLevel: .sedentary,
            primaryGoal: .loseWeight,
            typicalDailySteps: 3000
        )
        let output = AdaptiveGoalEngine.compute(input: input)
        #expect(output.calorieTarget >= 1500)
    }

    @Test func deficitCapRespected() {
        // Custom config with a tight max deficit (200 instead of 1000)
        let tightSafety = NutritionSafetyConfiguration(
            minimumCaloriesMale: 1500,
            minimumCaloriesFemale: 1200,
            maximumDailyDeficit: 200,
            maximumDailySurplus: 500,
            maximumWeightLossRateKgPerWeek: 0.9,
            maximumWeightGainRateKgPerWeek: 0.45
        )
        let input = GoalEngineInput(
            weightKg: 80, heightCm: 175, ageYears: 30,
            biologicalSex: .male,
            activityLevel: .moderatelyActive,
            primaryGoal: .loseWeight,
            typicalDailySteps: 8000
        )
        let standard = AdaptiveGoalEngine.compute(input: input)
        let tight    = AdaptiveGoalEngine.compute(input: input, safety: tightSafety)
        // Tighter cap → smaller deficit → higher calorie target
        #expect(tight.calorieTarget > standard.calorieTarget)
    }

    @Test func surplusCapRespected() {
        let tightSafety = NutritionSafetyConfiguration(
            minimumCaloriesMale: 1500,
            minimumCaloriesFemale: 1200,
            maximumDailyDeficit: 1000,
            maximumDailySurplus: 100,
            maximumWeightLossRateKgPerWeek: 0.9,
            maximumWeightGainRateKgPerWeek: 0.45
        )
        let input = GoalEngineInput(
            weightKg: 80, heightCm: 175, ageYears: 30,
            biologicalSex: .male,
            activityLevel: .moderatelyActive,
            primaryGoal: .buildMuscle,
            typicalDailySteps: 8000
        )
        let standard = AdaptiveGoalEngine.compute(input: input)
        let tight    = AdaptiveGoalEngine.compute(input: input, safety: tightSafety)
        // Tighter surplus cap → smaller surplus → lower calorie target
        #expect(tight.calorieTarget < standard.calorieTarget)
    }

    @Test func waterTargetScalesWithWeight() {
        // 80 kg × 35 ml = 2800 ml
        let output = AdaptiveGoalEngine.compute(input: maleInput)
        #expect(output.waterTargetMilliliters == 2800)
    }

    @Test func waterTargetDefaultsWhenNoWeight() {
        let input = GoalEngineInput(
            weightKg: nil, heightCm: nil, ageYears: nil,
            biologicalSex: .male,
            activityLevel: .moderatelyActive,
            primaryGoal: .maintainHealth,
            typicalDailySteps: 8000
        )
        let output = AdaptiveGoalEngine.compute(input: input)
        #expect(output.waterTargetMilliliters == 2500)
    }

    @Test func waterTargetClampsHigh() {
        // 200 kg × 35 ml = 7000 → clamped to 4000
        let input = GoalEngineInput(
            weightKg: 200, heightCm: 200, ageYears: 30,
            biologicalSex: .male,
            activityLevel: .moderatelyActive,
            primaryGoal: .maintainHealth,
            typicalDailySteps: 8000
        )
        let output = AdaptiveGoalEngine.compute(input: input)
        #expect(output.waterTargetMilliliters == 4000)
    }

    @Test func stepTargetFallsBackToDefault() {
        let input = GoalEngineInput(
            weightKg: 70, heightCm: 170, ageYears: 30,
            biologicalSex: .male,
            activityLevel: .moderatelyActive,
            primaryGoal: .maintainHealth,
            typicalDailySteps: 0
        )
        let output = AdaptiveGoalEngine.compute(input: input)
        #expect(output.stepTarget == 8000)
    }

    @Test func engineVersionTagged() {
        let output = AdaptiveGoalEngine.compute(input: maleInput)
        #expect(output.engineVersion == AdaptiveGoalEngine.currentVersion)
    }

    @Test func reduceFatGoalAppliesDeficit() {
        // reduceFat should behave identically to loseWeight
        let loseInput = GoalEngineInput(
            weightKg: 80, heightCm: 175, ageYears: 30,
            biologicalSex: .male, activityLevel: .moderatelyActive,
            primaryGoal: .loseWeight, typicalDailySteps: 8000
        )
        let reduceFatInput = GoalEngineInput(
            weightKg: 80, heightCm: 175, ageYears: 30,
            biologicalSex: .male, activityLevel: .moderatelyActive,
            primaryGoal: .reduceFat, typicalDailySteps: 8000
        )
        #expect(AdaptiveGoalEngine.compute(input: loseInput).calorieTarget ==
                AdaptiveGoalEngine.compute(input: reduceFatInput).calorieTarget)
    }

    @Test func stepTargetUsesUserValue() {
        let input = GoalEngineInput(
            weightKg: 70, heightCm: 170, ageYears: 30,
            biologicalSex: .male, activityLevel: .moderatelyActive,
            primaryGoal: .maintainHealth, typicalDailySteps: 12000
        )
        #expect(AdaptiveGoalEngine.compute(input: input).stepTarget == 12000)
    }

    @Test func veryActiveHigherThanModerate() {
        let moderate = GoalEngineInput(
            weightKg: 80, heightCm: 175, ageYears: 30,
            biologicalSex: .male, activityLevel: .moderatelyActive,
            primaryGoal: .maintainHealth, typicalDailySteps: 9000
        )
        let veryActive = GoalEngineInput(
            weightKg: 80, heightCm: 175, ageYears: 30,
            biologicalSex: .male, activityLevel: .veryActive,
            primaryGoal: .maintainHealth, typicalDailySteps: 9000
        )
        #expect(AdaptiveGoalEngine.compute(input: veryActive).calorieTarget >
                AdaptiveGoalEngine.compute(input: moderate).calorieTarget)
    }

    @Test func waterTargetClampsLow() {
        // 30 kg × 35 = 1050 → clamped to 1800
        let input = GoalEngineInput(
            weightKg: 30, heightCm: 150, ageYears: 16,
            biologicalSex: .female, activityLevel: .sedentary,
            primaryGoal: .maintainHealth, typicalDailySteps: 6000
        )
        #expect(AdaptiveGoalEngine.compute(input: input).waterTargetMilliliters == 1800)
    }
}

// MARK: - XP Progression

struct XPProgressionTests {

    @Test func level1RequiresHundredXP() {
        // Int(100 × pow(1, 1.35)) = 100
        #expect(requiredXP(for: 1) == 100)
    }

    @Test func requiredXPGrowsMonotonically() {
        for level in 1..<20 {
            #expect(requiredXP(for: level + 1) > requiredXP(for: level))
        }
    }

    @Test func level10XPThreshold() {
        // Int(100 × pow(10, 1.35)) — just verify it's larger than level 1
        #expect(requiredXP(for: 10) > requiredXP(for: 1))
    }
}

// MARK: - RankTier boundaries

struct RankTierTests {

    @Test func level1IsInitiate() {
        #expect(RankTier.rank(for: 1) == .initiate)
    }

    @Test func level9IsStillInitiate() {
        #expect(RankTier.rank(for: 9) == .initiate)
    }

    @Test func level10IsVanguard() {
        #expect(RankTier.rank(for: 10) == .vanguard)
    }

    @Test func level24IsVanguard() {
        #expect(RankTier.rank(for: 24) == .vanguard)
    }

    @Test func level25IsAscendant() {
        #expect(RankTier.rank(for: 25) == .ascendant)
    }

    @Test func level50IsSovereign() {
        #expect(RankTier.rank(for: 50) == .sovereign)
    }

    @Test func level79IsSovereign() {
        #expect(RankTier.rank(for: 79) == .sovereign)
    }

    @Test func level80IsPrime() {
        #expect(RankTier.rank(for: 80) == .prime)
    }

    @Test func level99IsPrime() {
        #expect(RankTier.rank(for: 99) == .prime)
    }

    @Test func level100IsMonarch() {
        #expect(RankTier.rank(for: 100) == .monarch)
    }

    @Test func rankBeyondMonarchStaysMonarch() {
        #expect(RankTier.rank(for: 200) == .monarch)
    }
}
