import Foundation
import SwiftData

// MARK: - Achievement Service
//
// Seeds a fixed achievement catalog and awards UserAchievement rows + XP
// when the player first meets each condition. All logic is deterministic and
// idempotent — safe to call multiple times per session.

@MainActor
final class AchievementService {

    // MARK: - Catalog definition

    private static let catalog: [(key: String, title: String, description: String, icon: String, xp: Int)] = [
        // First-time actions
        ("first_meal",              "First Bite",         "Logged your first meal.",                    "fork.knife",                     25),
        ("first_water",             "Hydrated",           "Logged your first water intake.",            "drop.fill",                      15),
        ("first_workout",           "First Rep",          "Completed your first workout.",              "dumbbell.fill",                  50),
        ("first_weight_entry",      "On the Scale",       "Logged your first weight entry.",            "scalemass.fill",                 25),
        ("first_progress_photo",    "Snapshot",           "Added your first progress photo.",           "camera.fill",                    30),
        ("first_measurement",       "Measuring Up",       "Logged your first body measurement.",        "ruler.fill",                     30),

        // Meal volume
        ("ten_meals",               "Well Fed",           "Logged 10 meals.",                           "fork.knife.circle",              40),
        ("fifty_meals",             "Meal Machine",       "Logged 50 meals.",                           "fork.knife.circle.fill",        100),
        ("hundred_meals",           "Nutritional Ninja",  "Logged 100 meals.",                          "chart.bar.fill",                200),

        // Hydration volume
        ("ten_water",               "Flow State",         "Logged water 10 times.",                     "drop.circle",                    40),
        ("fifty_water",             "Hydration Hero",     "Stayed consistently hydrated 50 times.",     "drop.circle.fill",              100),

        // Weight tracking
        ("five_weight_entries",     "Trend Tracker",      "Logged your weight 5 times.",                "chart.line.uptrend.xyaxis",      50),
        ("thirty_weight_entries",   "Scale Master",       "Logged your weight 30 times.",               "chart.xyaxis.line",             150),

        // Streaks
        ("three_day_streak",        "On a Roll",          "Kept a 3-day logging streak.",               "flame",                          30),
        ("seven_day_streak",        "Week Warrior",       "Hit a 7-day logging streak.",                "flame.fill",                    100),
        ("fourteen_day_streak",     "Two Week Streak",    "Hit a 14-day logging streak.",               "flame.circle.fill",             150),
        ("thirty_day_streak",       "Iron Discipline",    "Maintained a 30-day logging streak.",        "crown.fill",                    500),
        ("sixty_day_streak",        "Relentless",         "Maintained a 60-day logging streak.",        "bolt.circle.fill",              750),
        ("hundred_day_streak",      "Century Streak",     "Hit a 100-day logging streak.",              "star.fill",                    1500),

        // Workout volume
        ("five_workouts",           "Five & Counting",    "Completed 5 workouts.",                      "bolt.fill",                      75),
        ("ten_workouts",            "Building Habits",    "Completed 10 workouts.",                     "figure.strengthtraining.traditional", 100),
        ("twenty_workouts",         "Committed",          "Completed 20 workouts.",                     "trophy.fill",                   200),
        ("fifty_workouts",          "Fitness Fanatic",    "Completed 50 workouts.",                     "figure.run",                    300),
        ("hundred_workouts",        "Century Club",       "Completed 100 workouts.",                    "rosette",                       750),
    ]

    // MARK: - Seed catalog

    static func seedCatalog(in context: ModelContext) {
        let existing = Set((try? context.fetch(FetchDescriptor<Achievement>()))?.map(\.key) ?? [])
        var inserted = false
        for item in catalog where !existing.contains(item.key) {
            context.insert(Achievement(
                key: item.key,
                title: item.title,
                descriptionText: item.description,
                iconName: item.icon,
                xpReward: item.xp
            ))
            inserted = true
        }
        if inserted { try? context.save() }
    }

    // MARK: - Evaluate and award

    static func evaluate(in context: ModelContext) {
        seedCatalog(in: context)

        let earned = Set((try? context.fetch(FetchDescriptor<UserAchievement>()))?.map(\.achievementKey) ?? [])
        let achievements = (try? context.fetch(FetchDescriptor<Achievement>())) ?? []

        let mealCount        = (try? context.fetchCount(FetchDescriptor<MealEntry>())) ?? 0
        let waterCount       = (try? context.fetchCount(FetchDescriptor<WaterEntry>())) ?? 0
        let weightCount      = (try? context.fetchCount(FetchDescriptor<WeightEntry>())) ?? 0
        let photoCount       = (try? context.fetchCount(FetchDescriptor<ProgressPhoto>())) ?? 0
        let measurementCount = (try? context.fetchCount(FetchDescriptor<BodyMeasurement>())) ?? 0

        let completedTrue = true
        let workoutCount = (try? context.fetchCount(
            FetchDescriptor<WorkoutSession>(
                predicate: #Predicate { $0.isCompleted == completedTrue }
            )
        )) ?? 0

        let streakCount = (try? context.fetch(FetchDescriptor<Streak>()))?
            .first(where: { $0.streakType == .logging })?.currentCount ?? 0

        var didAward = false
        for achievement in achievements where !earned.contains(achievement.key) {
            let qualifies: Bool
            switch achievement.key {
            // First-time actions
            case "first_meal":              qualifies = mealCount        >= 1
            case "first_water":             qualifies = waterCount       >= 1
            case "first_workout":           qualifies = workoutCount     >= 1
            case "first_weight_entry":      qualifies = weightCount      >= 1
            case "first_progress_photo":    qualifies = photoCount       >= 1
            case "first_measurement":       qualifies = measurementCount >= 1
            // Meal volume
            case "ten_meals":               qualifies = mealCount        >= 10
            case "fifty_meals":             qualifies = mealCount        >= 50
            case "hundred_meals":           qualifies = mealCount        >= 100
            // Hydration volume
            case "ten_water":               qualifies = waterCount       >= 10
            case "fifty_water":             qualifies = waterCount       >= 50
            // Weight tracking
            case "five_weight_entries":     qualifies = weightCount      >= 5
            case "thirty_weight_entries":   qualifies = weightCount      >= 30
            // Streaks
            case "three_day_streak":        qualifies = streakCount      >= 3
            case "seven_day_streak":        qualifies = streakCount      >= 7
            case "fourteen_day_streak":     qualifies = streakCount      >= 14
            case "thirty_day_streak":       qualifies = streakCount      >= 30
            case "sixty_day_streak":        qualifies = streakCount      >= 60
            case "hundred_day_streak":      qualifies = streakCount      >= 100
            // Workout volume
            case "five_workouts":           qualifies = workoutCount     >= 5
            case "ten_workouts":            qualifies = workoutCount     >= 10
            case "twenty_workouts":         qualifies = workoutCount     >= 20
            case "fifty_workouts":          qualifies = workoutCount     >= 50
            case "hundred_workouts":        qualifies = workoutCount     >= 100
            default:                        qualifies = false
            }
            if qualifies {
                context.insert(UserAchievement(achievementKey: achievement.key, xpAwarded: achievement.xpReward))
                XPLedgerService.credit(achievement.xpReward, in: context)
                didAward = true
            }
        }
        if didAward { try? context.save() }
    }
}
