import Foundation
import FoundationModels
import SwiftData

// MARK: - Generable types for structured workout output

@Generable
struct DailyWorkoutPlan {
    @Guide(description: "5 to 6 exercises for today's workout session")
    var exercises: [GeneratedExercise]
}

@Generable
struct GeneratedExercise {
    @Guide(description: "Exercise name using clear, common fitness terminology")
    var name: String
    @Guide(description: "Primary muscle group targeted (e.g., Chest, Back, Legs, Core, Shoulders)")
    var muscleGroup: String
    @Guide(description: "Number of sets, between 2 and 5")
    var sets: Int
    @Guide(description: "Target reps per set, between 6 and 60. Use higher values for timed exercises like Plank Hold measured in seconds")
    var reps: Int
    @Guide(description: "Weight in kilograms. Use 0.0 for bodyweight exercises requiring no equipment")
    var weightKg: Double
}

// MARK: - Storage bridge (private Codable ↔ WorkoutPlanExercise)

private struct StoredExercise: Codable {
    var name: String
    var muscleGroup: String
    var sets: Int
    var defaultReps: Int
    var defaultWeightKg: Double

    var asWorkoutPlanExercise: WorkoutPlanExercise {
        WorkoutPlanExercise(name: name, muscleGroup: muscleGroup, sets: sets,
                            defaultReps: defaultReps, defaultWeightKg: defaultWeightKg,
                            requiredEquipment: nil)
    }
}

// MARK: - Service

@MainActor
final class WorkoutVarietyService {

    /// Generates today's exercise list using on-device AI and stores the result in
    /// `target.generatedWorkoutJSON`. No-op when already generated or model unavailable.
    static func generateIfNeeded(
        for target: DailyTarget,
        goal: GoalType?,
        equipment: [Equipment],
        intensity: WorkoutIntensity,
        context: ModelContext
    ) async {
        guard target.generatedWorkoutJSON == nil else { return }
        guard SystemLanguageModel.default.isAvailable else { return }
        guard UserDefaults.standard.object(forKey: "pm_ai_workout_enabled") == nil ||
              UserDefaults.standard.bool(forKey: "pm_ai_workout_enabled") else { return }

        let weekdayIndex = Calendar.current.component(.weekday, from: Date()) - 1
        let weekday = Calendar.current.weekdaySymbols[weekdayIndex]

        let session = LanguageModelSession(instructions: """
            You are a personal fitness coach creating safe, effective daily workout plans.
            Only suggest exercises the user can perform with their available equipment.
            Bodyweight exercises like push-ups, squats, and planks require no equipment.
            Vary muscle groups across the session to avoid redundancy.
            """)

        let prompt = """
            Today is \(weekday). Generate a \(intensityDescription(for: intensity)) workout.
            Goal: \(goalDescription(for: goal)).
            Available equipment: \(equipmentDescription(for: equipment)).
            Create 5 to 6 exercises targeting different muscle groups.
            """

        do {
            let response = try await session.respond(to: prompt, generating: DailyWorkoutPlan.self)
            let stored = response.content.exercises.map { ex in
                StoredExercise(
                    name: ex.name,
                    muscleGroup: ex.muscleGroup,
                    sets: max(1, min(6, ex.sets)),
                    defaultReps: max(1, min(90, ex.reps)),
                    defaultWeightKg: max(0, ex.weightKg)
                )
            }
            guard !stored.isEmpty else { return }
            let data = try JSONEncoder().encode(stored)
            target.generatedWorkoutJSON = String(data: data, encoding: .utf8)
            try? context.save()
        } catch {
            // Generation failed or model unavailable — static plan is the silent fallback
        }
    }

    /// Decodes a JSON exercise list stored in a DailyTarget back to WorkoutPlanExercise values.
    /// Returns nil when the JSON is absent, empty, or malformed — callers fall back to WorkoutPlans.
    static func decodeExercises(from json: String?) -> [WorkoutPlanExercise]? {
        guard let json,
              let data = json.data(using: .utf8),
              let stored = try? JSONDecoder().decode([StoredExercise].self, from: data),
              !stored.isEmpty else { return nil }
        return stored.map(\.asWorkoutPlanExercise)
    }

    // MARK: - Prompt helpers

    private static func goalDescription(for goal: GoalType?) -> String {
        switch goal {
        case .buildMuscle:      return "build muscle and increase strength"
        case .maintainMuscle:   return "maintain muscle mass and fitness"
        case .loseWeight:       return "lose weight through consistent calorie burn"
        case .reduceFat:        return "reduce body fat with metabolic training"
        case .improveEndurance: return "improve cardiovascular endurance"
        default:                return "general fitness and wellbeing"
        }
    }

    private static func equipmentDescription(for equipment: [Equipment]) -> String {
        let gear = equipment.filter { $0 != .noEquipment }
        guard !gear.isEmpty else { return "bodyweight only, no equipment" }
        return gear.map(\.displayName).joined(separator: ", ")
    }

    private static func intensityDescription(for intensity: WorkoutIntensity) -> String {
        switch intensity {
        case .reduced:  return "lighter, recovery-focused"
        case .standard: return "standard intensity"
        case .extended: return "higher intensity with extended volume"
        }
    }
}
