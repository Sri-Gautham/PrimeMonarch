import Foundation

// MARK: - Plan Exercise

struct WorkoutPlanExercise: Identifiable {
    let id = UUID()
    let name: String
    let muscleGroup: String
    let sets: Int
    let defaultReps: Int
    let defaultWeightKg: Double      // 0 = bodyweight
    let requiredEquipment: Equipment? // nil = bodyweight / no equipment needed

    func adjusted(for intensity: WorkoutIntensity) -> WorkoutPlanExercise {
        switch intensity {
        case .standard:
            return self
        case .reduced:
            return WorkoutPlanExercise(name: name, muscleGroup: muscleGroup,
                                       sets: max(1, sets - 1),
                                       defaultReps: defaultReps,
                                       defaultWeightKg: defaultWeightKg,
                                       requiredEquipment: requiredEquipment)
        case .extended:
            return WorkoutPlanExercise(name: name, muscleGroup: muscleGroup,
                                       sets: sets + 1,
                                       defaultReps: defaultReps,
                                       defaultWeightKg: defaultWeightKg,
                                       requiredEquipment: requiredEquipment)
        }
    }
}

// MARK: - Set Tracking State

struct SetRecord {
    var reps: String
    var weightKg: String
    var isCompleted: Bool = false

    init(defaultReps: Int, defaultWeightKg: Double) {
        self.reps     = "\(defaultReps)"
        self.weightKg = defaultWeightKg > 0 ? String(format: "%.0f", defaultWeightKg) : ""
    }
}

// MARK: - Plans Factory

enum WorkoutPlans {

    // MARK: Selection

    /// Returns exercises for the given goal, adjusted for intensity and filtered by available equipment.
    /// Pass an empty array (default) to skip equipment filtering — useful when the profile isn't loaded yet.
    static func exercises(
        for goal: GoalType?,
        intensity: WorkoutIntensity = .standard,
        equipment: [Equipment] = []
    ) -> [WorkoutPlanExercise] {
        let base: [WorkoutPlanExercise]
        switch goal {
        case .buildMuscle, .maintainMuscle: base = upperBodyStrength
        case .improveEndurance:             base = cardioCircuit
        case .loseWeight, .reduceFat:       base = fatBurnInterval
        default:                            base = generalFitness
        }
        let adjusted = base.map { $0.adjusted(for: intensity) }

        // No preference set yet → show everything
        guard !equipment.isEmpty else { return adjusted }

        let userGear = Set(equipment.map(\.rawValue))
        let filtered = adjusted.filter { ex in
            guard let req = ex.requiredEquipment else { return true }  // bodyweight always OK
            return userGear.contains(req.rawValue)
        }

        // If filtering strips the list to fewer than 3, fall back to bodyweight-only exercises
        return filtered.count >= 3 ? filtered : adjusted.filter { $0.requiredEquipment == nil }
    }

    static func title(for goal: GoalType?) -> String {
        switch goal {
        case .buildMuscle, .maintainMuscle: return "Upper Body Strength"
        case .improveEndurance:             return "Cardio Circuit"
        case .loseWeight, .reduceFat:       return "Fat-Burn Interval"
        default:                            return "Fitness Training"
        }
    }

    static func workoutGoalType(for goal: GoalType?) -> WorkoutGoalType {
        switch goal {
        case .buildMuscle, .maintainMuscle: return .muscleBuilding
        case .improveEndurance:             return .running
        case .loseWeight, .reduceFat:       return .fatLossSupport
        default:                            return .generalFitness
        }
    }

    // MARK: Estimates

    /// Rough duration based on total sets × ~3 min (work + rest) plus a 5-min warmup.
    static func estimatedMinutes(for goal: GoalType?, intensity: WorkoutIntensity = .standard) -> Int {
        let totalSets = exercises(for: goal, intensity: intensity).reduce(0) { $0 + $1.sets }
        return max(20, totalSets * 3 + 5)
    }

    /// Estimated calorie burn at a given intensity, tuned per plan type.
    static func estimatedBurnKcal(for goal: GoalType?, intensity: WorkoutIntensity = .standard) -> Int {
        let base: Double
        switch goal {
        case .buildMuscle, .maintainMuscle: base = 340
        case .improveEndurance:             base = 480
        case .loseWeight, .reduceFat:       base = 420
        default:                            base = 300
        }
        return Int((base * intensity.burnMultiplier).rounded())
    }

    /// Returns exercises with the same muscle group as a replacement candidate.
    static func alternatives(
        for muscleGroup: String,
        excluding currentName: String,
        equipment: [Equipment] = []
    ) -> [WorkoutPlanExercise] {
        let all = upperBodyStrength + cardioCircuit + fatBurnInterval + generalFitness
        let userGear = Set(equipment.map(\.rawValue))
        return all.filter { ex in
            guard ex.muscleGroup == muscleGroup, ex.name != currentName else { return false }
            if equipment.isEmpty { return true }
            guard let req = ex.requiredEquipment else { return true }
            return userGear.contains(req.rawValue)
        }
    }

    // MARK: Exercise lists
    // requiredEquipment: nil = bodyweight (no equipment needed)

    private static let upperBodyStrength: [WorkoutPlanExercise] = [
        WorkoutPlanExercise(name: "Push-ups",        muscleGroup: "Chest",      sets: 4, defaultReps: 12, defaultWeightKg: 0,  requiredEquipment: nil),
        WorkoutPlanExercise(name: "Bent-over Rows",  muscleGroup: "Back",       sets: 4, defaultReps: 10, defaultWeightKg: 12, requiredEquipment: .dumbbells),
        WorkoutPlanExercise(name: "Shoulder Press",  muscleGroup: "Shoulders",  sets: 3, defaultReps: 10, defaultWeightKg: 8,  requiredEquipment: .dumbbells),
        WorkoutPlanExercise(name: "Bicep Curls",     muscleGroup: "Biceps",     sets: 3, defaultReps: 12, defaultWeightKg: 8,  requiredEquipment: .dumbbells),
        WorkoutPlanExercise(name: "Tricep Dips",     muscleGroup: "Triceps",    sets: 3, defaultReps: 15, defaultWeightKg: 0,  requiredEquipment: nil),
        WorkoutPlanExercise(name: "Face Pulls",      muscleGroup: "Rear Delts", sets: 3, defaultReps: 15, defaultWeightKg: 5,  requiredEquipment: .resistanceBands),
    ]

    private static let cardioCircuit: [WorkoutPlanExercise] = [
        WorkoutPlanExercise(name: "Jumping Jacks",     muscleGroup: "Full body", sets: 3, defaultReps: 40, defaultWeightKg: 0, requiredEquipment: nil),
        WorkoutPlanExercise(name: "High Knees",        muscleGroup: "Legs",      sets: 3, defaultReps: 30, defaultWeightKg: 0, requiredEquipment: nil),
        WorkoutPlanExercise(name: "Burpees",           muscleGroup: "Full body", sets: 3, defaultReps: 10, defaultWeightKg: 0, requiredEquipment: nil),
        WorkoutPlanExercise(name: "Mountain Climbers", muscleGroup: "Core",      sets: 3, defaultReps: 20, defaultWeightKg: 0, requiredEquipment: nil),
        WorkoutPlanExercise(name: "Box Step-ups",      muscleGroup: "Legs",      sets: 3, defaultReps: 15, defaultWeightKg: 0, requiredEquipment: nil),
        WorkoutPlanExercise(name: "Plank Hold",        muscleGroup: "Core",      sets: 3, defaultReps: 45, defaultWeightKg: 0, requiredEquipment: nil),
    ]

    private static let fatBurnInterval: [WorkoutPlanExercise] = [
        WorkoutPlanExercise(name: "Jump Squats",    muscleGroup: "Legs",      sets: 4, defaultReps: 15, defaultWeightKg: 0, requiredEquipment: nil),
        WorkoutPlanExercise(name: "Push-ups",       muscleGroup: "Chest",     sets: 3, defaultReps: 12, defaultWeightKg: 0, requiredEquipment: nil),
        WorkoutPlanExercise(name: "Reverse Lunges", muscleGroup: "Legs",      sets: 3, defaultReps: 12, defaultWeightKg: 0, requiredEquipment: nil),
        WorkoutPlanExercise(name: "Dumbbell Rows",  muscleGroup: "Back",      sets: 3, defaultReps: 12, defaultWeightKg: 8, requiredEquipment: .dumbbells),
        WorkoutPlanExercise(name: "Burpees",        muscleGroup: "Full body", sets: 3, defaultReps: 10, defaultWeightKg: 0, requiredEquipment: nil),
        WorkoutPlanExercise(name: "Plank Hold",     muscleGroup: "Core",      sets: 3, defaultReps: 45, defaultWeightKg: 0, requiredEquipment: nil),
    ]

    private static let generalFitness: [WorkoutPlanExercise] = [
        WorkoutPlanExercise(name: "Squats",         muscleGroup: "Legs",      sets: 3, defaultReps: 15, defaultWeightKg: 0,  requiredEquipment: nil),
        WorkoutPlanExercise(name: "Push-ups",       muscleGroup: "Chest",     sets: 3, defaultReps: 12, defaultWeightKg: 0,  requiredEquipment: nil),
        WorkoutPlanExercise(name: "Dumbbell Rows",  muscleGroup: "Back",      sets: 3, defaultReps: 12, defaultWeightKg: 10, requiredEquipment: .dumbbells),
        WorkoutPlanExercise(name: "Shoulder Press", muscleGroup: "Shoulders", sets: 3, defaultReps: 10, defaultWeightKg: 6,  requiredEquipment: .dumbbells),
        WorkoutPlanExercise(name: "Plank Hold",     muscleGroup: "Core",      sets: 3, defaultReps: 45, defaultWeightKg: 0,  requiredEquipment: nil),
        WorkoutPlanExercise(name: "Glute Bridge",   muscleGroup: "Glutes",    sets: 3, defaultReps: 15, defaultWeightKg: 0,  requiredEquipment: nil),
    ]
}
