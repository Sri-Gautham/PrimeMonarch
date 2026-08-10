import SwiftData
import Foundation

// MARK: - Daily Target Service
//
// Ensures one DailyTarget exists for each calendar day.
// Called on app launch, onboarding completion, and when the app returns
// to the foreground on a new day.

@MainActor
final class DailyTargetService {

    // MARK: - Public API

    /// Creates a DailyTarget for today if one does not already exist.
    /// Safe to call multiple times — exits early when a target is present.
    static func ensureTodayTarget(in context: ModelContext) {
        let today    = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!

        let existing = FetchDescriptor<DailyTarget>(
            predicate: #Predicate<DailyTarget> { t in
                t.date >= today && t.date < tomorrow
            }
        )
        guard (try? context.fetch(existing))?.isEmpty == true else { return }

        let target = buildTarget(for: today, context: context)
        context.insert(target)
        try? context.save()
    }

    // MARK: - Target construction

    private static func buildTarget(for date: Date, context: ModelContext) -> DailyTarget {
        let profile     = try? context.fetch(FetchDescriptor<UserProfile>()).first
        let goalProfile = try? context.fetch(FetchDescriptor<GoalProfile>()).first

        let input = GoalEngineInput(
            weightKg:          profile?.currentWeightKilograms,
            heightCm:          profile?.heightCentimeters,
            ageYears:          profile?.ageYears,
            biologicalSex:     profile?.biologicalSex ?? .male,
            activityLevel:     goalProfile?.activityLevel ?? .moderatelyActive,
            primaryGoal:       goalProfile?.primaryGoal ?? .maintainHealth,
            typicalDailySteps: goalProfile?.typicalDailySteps ?? 8000
        )

        let output = AdaptiveGoalEngine.compute(input: input)
        let target = DailyTarget(date: date)

        target.calorieTarget          = output.calorieTarget
        target.calorieExplanation     = output.calorieExplanation
        target.waterTargetMilliliters = output.waterTargetMilliliters
        target.waterExplanation       = output.waterExplanation
        target.stepTarget             = output.stepTarget
        target.stepExplanation        = output.stepExplanation
        target.workoutBurnTarget      = output.workoutBurnTarget
        target.dataConfidence         = output.dataConfidence
        target.engineVersion          = output.engineVersion

        return target
    }
}
