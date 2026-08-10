import Foundation
import SwiftData

// MARK: - Daily Summary Service
//
// Rolls up yesterday's logged data into a DailySummary record.
// Called from AppCoordinator.seedDailyTarget() each time the app
// foregrounds on a new calendar day — never on first launch.

@MainActor
final class DailySummaryService {

    static func rollupYesterday(in context: ModelContext) {
        let cal       = Calendar.current
        let today     = cal.startOfDay(for: Date())
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!

        // Guard: skip if this is the very first launch (no DailyTarget for yesterday)
        let targetDesc = FetchDescriptor<DailyTarget>(
            predicate: #Predicate { $0.date >= yesterday && $0.date < today }
        )
        guard let target = (try? context.fetch(targetDesc))?.first else { return }

        // Guard: skip if a summary for yesterday already exists
        let existingDesc = FetchDescriptor<DailySummary>(
            predicate: #Predicate { $0.date >= yesterday && $0.date < today }
        )
        guard (try? context.fetch(existingDesc))?.isEmpty == true else { return }

        // Calories consumed yesterday
        let mealDesc = FetchDescriptor<MealEntry>(
            predicate: #Predicate { $0.consumedAt >= yesterday && $0.consumedAt < today }
        )
        let meals = (try? context.fetch(mealDesc)) ?? []
        let caloriesConsumed = meals.reduce(0.0) { $0 + $1.calories }

        // Water consumed yesterday
        let waterDesc = FetchDescriptor<WaterEntry>(
            predicate: #Predicate { $0.loggedAt >= yesterday && $0.loggedAt < today }
        )
        let water = (try? context.fetch(waterDesc)) ?? []
        let waterConsumed = water.reduce(0.0) { $0 + $1.amountMilliliters }

        // Completed workouts yesterday
        let completedTrue = true
        let workoutDesc = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate {
                $0.startedAt >= yesterday && $0.startedAt < today && $0.isCompleted == completedTrue
            }
        )
        let workouts = (try? context.fetch(workoutDesc)) ?? []

        // Build summary from target + logged data
        let summary = DailySummary(date: yesterday)
        summary.caloriesConsumed          = caloriesConsumed
        summary.waterConsumedMilliliters  = waterConsumed
        summary.stepsCompleted            = target.healthKitStepsToday
        summary.workoutsCompleted         = workouts.count
        summary.activeEnergyKilocalories  = target.healthKitActiveKcalToday
        summary.calorieTargetAtClose      = target.calorieTarget
        summary.waterTargetAtClose        = target.waterTargetMilliliters
        summary.stepTargetAtClose         = target.stepTarget
        summary.xpAwarded                 = xp(for: summary)
        summary.motivationalSummary       = motivationalMessage(for: summary)
        summary.isRestDay                 = false  // per-day rest scheduling is Phase 2

        context.insert(summary)
        try? context.save()

        XPLedgerService.credit(summary.xpAwarded, in: context)
    }

    // MARK: - XP

    // 100 XP total: 30 nutrition + 20 hydration + 30 movement + 20 workout
    private static func xp(for s: DailySummary) -> Int {
        var points = 0

        let calRatio = s.calorieTargetAtClose > 0
            ? s.caloriesConsumed / Double(s.calorieTargetAtClose) : 0
        if calRatio >= 0.85 && calRatio <= 1.10 { points += 30 }
        else if calRatio >= 0.70 && calRatio <= 1.20 { points += 15 }

        if s.waterTargetAtClose > 0,
           s.waterConsumedMilliliters >= Double(s.waterTargetAtClose) * 0.9 {
            points += 20
        }

        if s.stepTargetAtClose > 0,
           Double(s.stepsCompleted) >= Double(s.stepTargetAtClose) * 0.9 {
            points += 30
        }

        if s.workoutsCompleted > 0 { points += 20 }

        return points
    }

    // MARK: - Message

    private static func motivationalMessage(for s: DailySummary) -> String? {
        let earned = xp(for: s)
        switch earned {
        case 90...:
            return "Perfect day — nutrition, hydration, movement, and workout all on point."
        case 70...:
            return "Strong day. You hit most of your targets; one more habit away from perfect."
        case 40...:
            return "Solid effort. Every consistent day compounds — keep going."
        case 1...:
            return "You showed up. Progress is built one small win at a time."
        default:
            return nil
        }
    }
}
