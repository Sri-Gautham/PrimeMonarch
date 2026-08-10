import Foundation
import SwiftData

@Model
final class UserPreference {
    @Attribute(.unique) var id: UUID
    var updatedAt: Date

    // Food preferences
    var dietaryStyleRawValues: [String]   // supports multi-select combinations
    var allergies: [String]
    var foodsToAvoid: [String]
    var preferredCuisines: [String]
    var cookingSkillLevel: Int       // 1 (beginner) to 5 (advanced)
    var mealsPerDay: Int
    var householdServings: Int
    var weeklyGroceryBudget: Double?
    var availableAppliances: [String]
    var mealPrepDay: Int             // 0 = Sunday ... 6 = Saturday
    var maxCookingMinutes: Int

    // Schedule
    var wakeHour: Int
    var wakeMinute: Int
    var sleepHour: Int
    var sleepMinute: Int
    var workoutTimeHour: Int
    var workoutTimeMinute: Int
    var workdays: [Int]              // 0 = Sunday … 6 = Saturday

    // Notifications
    var waterRemindersEnabled: Bool
    var stepRemindersEnabled: Bool
    var mealRemindersEnabled: Bool
    var workoutRemindersEnabled: Bool
    var weeklyReviewReminderEnabled: Bool

    // Appearance
    var useDarkMode: Bool

    init() {
        self.id = UUID()
        self.updatedAt = Date()
        self.dietaryStyleRawValues = [DietaryStyle.noRestrictions.rawValue]
        self.allergies = []
        self.foodsToAvoid = []
        self.preferredCuisines = []
        self.cookingSkillLevel = 2
        self.mealsPerDay = 3
        self.householdServings = 1
        self.availableAppliances = ["oven", "stovetop", "microwave"]
        self.mealPrepDay = 0   // Sunday
        self.maxCookingMinutes = 60
        self.wakeHour = 7
        self.wakeMinute = 0
        self.sleepHour = 23
        self.sleepMinute = 0
        self.workoutTimeHour = 8
        self.workoutTimeMinute = 0
        self.workdays = [1, 2, 3, 4, 5]  // Mon–Fri
        self.waterRemindersEnabled = false
        self.stepRemindersEnabled = false
        self.mealRemindersEnabled = false
        self.workoutRemindersEnabled = false
        self.weeklyReviewReminderEnabled = false
        self.useDarkMode = true
    }

    var dietaryStyles: [DietaryStyle] {
        get { dietaryStyleRawValues.compactMap { DietaryStyle(rawValue: $0) } }
        set { dietaryStyleRawValues = newValue.map { $0.rawValue } }
    }

    var wakeTime: DateComponents {
        DateComponents(hour: wakeHour, minute: wakeMinute)
    }

    var sleepTime: DateComponents {
        DateComponents(hour: sleepHour, minute: sleepMinute)
    }
}
