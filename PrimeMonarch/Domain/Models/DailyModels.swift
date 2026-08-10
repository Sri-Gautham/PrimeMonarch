import Foundation
import SwiftData

// MARK: - Daily Target

@Model
final class DailyTarget {
    @Attribute(.unique) var id: UUID
    var date: Date
    var createdAt: Date

    var calorieTarget: Int
    var waterTargetMilliliters: Int
    var stepTarget: Int

    // Explanation strings shown to user
    var calorieExplanation: String?
    var waterExplanation: String?
    var stepExplanation: String?

    var engineVersion: String
    var dataConfidence: Double  // 0.0 – 1.0

    // Adaptation fields — updated intra-day by AdaptationEngine
    var workoutBurnTarget: Int
    var adaptationIntensityRawValue: String
    var adaptationMessage: String?
    var adaptedAt: Date?

    // HealthKit data — written by HealthKitService on each foreground refresh
    var healthKitStepsToday: Int
    var healthKitActiveKcalToday: Double
    var healthKitSleepMinutesLastNight: Int

    // AI-generated exercise list for today — nil until WorkoutVarietyService populates it
    var generatedWorkoutJSON: String?

    init(date: Date = Date()) {
        self.id = UUID()
        self.date = Calendar.current.startOfDay(for: date)
        self.createdAt = Date()
        self.calorieTarget = 2000
        self.waterTargetMilliliters = 2500
        self.stepTarget = 8000
        self.engineVersion = "1.0"
        self.dataConfidence = 0.5
        self.workoutBurnTarget = 300
        self.adaptationIntensityRawValue = WorkoutIntensity.standard.rawValue
        self.healthKitStepsToday = 0
        self.healthKitActiveKcalToday = 0
        self.healthKitSleepMinutesLastNight = 0
    }

    var adaptationIntensity: WorkoutIntensity {
        get { WorkoutIntensity(rawValue: adaptationIntensityRawValue) ?? .standard }
        set { adaptationIntensityRawValue = newValue.rawValue }
    }
}

// MARK: - Daily Summary

@Model
final class DailySummary {
    @Attribute(.unique) var id: UUID
    var date: Date
    var createdAt: Date

    var caloriesConsumed: Double
    var waterConsumedMilliliters: Double
    var stepsCompleted: Int
    var workoutsCompleted: Int
    var activeEnergyKilocalories: Double

    var calorieTargetAtClose: Int
    var waterTargetAtClose: Int
    var stepTargetAtClose: Int

    var xpAwarded: Int
    var motivationalSummary: String?

    var isRestDay: Bool

    init(date: Date = Date()) {
        self.id = UUID()
        self.date = Calendar.current.startOfDay(for: date)
        self.createdAt = Date()
        self.caloriesConsumed = 0
        self.waterConsumedMilliliters = 0
        self.stepsCompleted = 0
        self.workoutsCompleted = 0
        self.activeEnergyKilocalories = 0
        self.calorieTargetAtClose = 2000
        self.waterTargetAtClose = 2500
        self.stepTargetAtClose = 8000
        self.xpAwarded = 0
        self.isRestDay = false
    }

    var calorieCompletionPercent: Double {
        guard calorieTargetAtClose > 0 else { return 0 }
        return min(caloriesConsumed / Double(calorieTargetAtClose), 1.0)
    }

    var waterCompletionPercent: Double {
        guard waterTargetAtClose > 0 else { return 0 }
        return min(waterConsumedMilliliters / Double(waterTargetAtClose), 1.0)
    }

    var stepCompletionPercent: Double {
        guard stepTargetAtClose > 0 else { return 0 }
        return min(Double(stepsCompleted) / Double(stepTargetAtClose), 1.0)
    }
}
