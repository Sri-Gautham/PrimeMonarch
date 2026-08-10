import Foundation
import SwiftData

// MARK: - Workout Session

@Model
final class WorkoutSession {
    @Attribute(.unique) var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var workoutGoalRawValue: String
    var title: String
    var notes: String?
    var totalEnergyKilocalories: Double?
    var durationSeconds: Double?
    var isCompleted: Bool
    var perceivedExertionLevel: Int?  // 1–10 RPE scale
    var source: String  // "primemonarch" | "healthkit"

    @Relationship(deleteRule: .cascade)
    var exerciseLogs: [ExerciseLog]

    init(title: String, workoutGoal: WorkoutGoalType = .generalFitness) {
        self.id = UUID()
        self.startedAt = Date()
        self.workoutGoalRawValue = workoutGoal.rawValue
        self.title = title
        self.isCompleted = false
        self.source = "primemonarch"
        self.exerciseLogs = []
    }

    var workoutGoal: WorkoutGoalType {
        get { WorkoutGoalType(rawValue: workoutGoalRawValue) ?? .generalFitness }
        set { workoutGoalRawValue = newValue.rawValue }
    }

    var computedDuration: TimeInterval? {
        guard let end = endedAt else { return nil }
        return end.timeIntervalSince(startedAt)
    }
}

// MARK: - Exercise Log

@Model
final class ExerciseLog {
    @Attribute(.unique) var id: UUID
    var exerciseName: String
    var orderIndex: Int
    var notes: String?

    @Relationship(deleteRule: .cascade)
    var sets: [ExerciseSetLog]

    init(exerciseName: String, orderIndex: Int = 0) {
        self.id = UUID()
        self.exerciseName = exerciseName
        self.orderIndex = orderIndex
        self.sets = []
    }
}

// MARK: - Exercise Set Log

@Model
final class ExerciseSetLog {
    @Attribute(.unique) var id: UUID
    var setNumber: Int
    var reps: Int?
    var weightKilograms: Double?
    var durationSeconds: Double?
    var distanceMeters: Double?
    var isCompleted: Bool
    var completedAt: Date?

    init(setNumber: Int) {
        self.id = UUID()
        self.setNumber = setNumber
        self.isCompleted = false
    }
}
