import Foundation
import SwiftData

// MARK: - Adaptation Engine
//
// Recomputes today's workout intensity based on current caloric balance.
// Called after each meal log and after each completed workout session.
// Updates DailyTarget in place — views observing it via @Query update automatically.

@MainActor
final class AdaptationEngine {

    /// Recompute workout intensity for today and write the result back to DailyTarget.
    /// Safe to call multiple times — exits early if a workout is already done today,
    /// or if no meals have been logged yet (not enough signal).
    static func recompute(in context: ModelContext) {
        let today    = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!

        guard let target = fetchTodayTarget(today: today, tomorrow: tomorrow, in: context) else { return }

        let goalProfile = (try? context.fetch(FetchDescriptor<GoalProfile>()))?.first

        // Calories consumed today from logged meals
        let caloriesConsumed = fetchCaloriesConsumed(today: today, tomorrow: tomorrow, in: context)
        guard caloriesConsumed > 0 else { return }  // no signal yet

        // Skip adaptation if today's workout is already complete
        let workoutsDoneToday = fetchCompletedWorkouts(today: today, tomorrow: tomorrow, in: context)
        guard workoutsDoneToday.isEmpty else { return }

        // Pro-rate consumed calories across the day to project end-of-day intake.
        // Uses the number of active hours elapsed; avoids wild early-morning projections.
        let hour         = max(6, Calendar.current.component(.hour, from: Date()))
        let dayFraction  = min(0.95, Double(hour) / 16.0)  // 16-hour active window
        let projectedConsumed = caloriesConsumed / dayFraction

        // Extra active energy from walking/general movement (HealthKit) offsets intake.
        // This is non-workout burn — the planned workout isn't done yet (guard above).
        let extraBurn = target.healthKitActiveKcalToday

        // Deviation: positive = user is over-target (extend workout); negative = under (reduce)
        let deviation = projectedConsumed - Double(target.calorieTarget) - extraBurn

        let threshold = 200.0  // kcal buffer before adjusting

        let intensity: WorkoutIntensity
        let message: String?

        if deviation > threshold {
            intensity = .extended
            message   = "You're tracking \(Int(deviation)) kcal over today's target — your workout has been extended to compensate."
        } else if deviation < -threshold {
            intensity = .reduced
            message   = "You're \(Int(abs(deviation))) kcal under today's target — your workout has been lightened. Well done!"
        } else {
            intensity = .standard
            message   = nil
        }

        target.adaptationIntensity  = intensity
        target.adaptationMessage    = message
        target.workoutBurnTarget    = WorkoutPlans.estimatedBurnKcal(for: goalProfile?.primaryGoal, intensity: intensity)
        target.adaptedAt            = Date()
        target.engineVersion        = "2.0"

        try? context.save()
    }

    // MARK: - Private fetch helpers
    // Isolate date-capture variables in let bindings so #Predicate can close over them.

    private static func fetchTodayTarget(today: Date, tomorrow: Date, in context: ModelContext) -> DailyTarget? {
        let desc = FetchDescriptor<DailyTarget>(
            predicate: #Predicate { $0.date >= today && $0.date < tomorrow }
        )
        return (try? context.fetch(desc))?.first
    }

    private static func fetchCaloriesConsumed(today: Date, tomorrow: Date, in context: ModelContext) -> Double {
        let desc = FetchDescriptor<MealEntry>(
            predicate: #Predicate { $0.consumedAt >= today && $0.consumedAt < tomorrow }
        )
        let meals = (try? context.fetch(desc)) ?? []
        return meals.reduce(0.0) { $0 + $1.calories }
    }

    private static func fetchCompletedWorkouts(today: Date, tomorrow: Date, in context: ModelContext) -> [WorkoutSession] {
        let completed = true
        let desc = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.startedAt >= today && $0.startedAt < tomorrow && $0.isCompleted == completed }
        )
        return (try? context.fetch(desc)) ?? []
    }
}
