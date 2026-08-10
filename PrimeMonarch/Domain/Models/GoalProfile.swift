import Foundation
import SwiftData

@Model
final class GoalProfile {
    @Attribute(.unique) var id: UUID
    var updatedAt: Date

    var goalRawValues: [String]
    var primaryGoalRawValue: String

    var activityLevelRawValue: String
    var typicalDailySteps: Int
    var workoutDaysPerWeek: Int
    var preferredWorkoutDurationMinutes: Int
    var availableEquipmentRawValues: [String]
    var injuryNotes: String

    init() {
        self.id = UUID()
        self.updatedAt = Date()
        self.goalRawValues = []
        self.primaryGoalRawValue = GoalType.maintainHealth.rawValue
        self.activityLevelRawValue = ActivityLevel.moderatelyActive.rawValue
        self.typicalDailySteps = 7000
        self.workoutDaysPerWeek = 3
        self.preferredWorkoutDurationMinutes = 45
        self.availableEquipmentRawValues = []
        self.injuryNotes = ""
    }

    var goals: [GoalType] {
        get { goalRawValues.compactMap { GoalType(rawValue: $0) } }
        set { goalRawValues = newValue.map(\.rawValue) }
    }

    var primaryGoal: GoalType {
        get { GoalType(rawValue: primaryGoalRawValue) ?? .maintainHealth }
        set { primaryGoalRawValue = newValue.rawValue }
    }

    var activityLevel: ActivityLevel {
        get { ActivityLevel(rawValue: activityLevelRawValue) ?? .moderatelyActive }
        set { activityLevelRawValue = newValue.rawValue }
    }

    var availableEquipment: [Equipment] {
        get { availableEquipmentRawValues.compactMap { Equipment(rawValue: $0) } }
        set { availableEquipmentRawValues = newValue.map(\.rawValue) }
    }
}
