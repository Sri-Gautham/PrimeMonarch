import Foundation

// MARK: - Goal

enum GoalType: String, CaseIterable, Codable, Identifiable {
    case loseWeight = "lose_weight"
    case reduceFat = "reduce_fat"
    case maintainMuscle = "maintain_muscle"
    case buildMuscle = "build_muscle"
    case improveEndurance = "improve_endurance"
    case increaseActivity = "increase_activity"
    case improveHydration = "improve_hydration"
    case improveSleep = "improve_sleep"
    case maintainHealth = "maintain_health"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .loseWeight: "Lose weight"
        case .reduceFat: "Reduce body fat"
        case .maintainMuscle: "Maintain muscle"
        case .buildMuscle: "Build muscle"
        case .improveEndurance: "Improve endurance"
        case .increaseActivity: "Increase daily movement"
        case .improveHydration: "Improve hydration"
        case .improveSleep: "Improve sleep"
        case .maintainHealth: "Maintain current health"
        }
    }

    var icon: String {
        switch self {
        case .loseWeight: "scalemass"
        case .reduceFat: "flame"
        case .maintainMuscle: "figure.strengthtraining.traditional"
        case .buildMuscle: "dumbbell"
        case .improveEndurance: "figure.run"
        case .increaseActivity: "figure.walk"
        case .improveHydration: "drop"
        case .improveSleep: "moon.zzz"
        case .maintainHealth: "heart"
        }
    }

    var shortDescription: String {
        switch self {
        case .loseWeight: "Reach a lighter, healthier weight"
        case .reduceFat: "Lower body fat percentage"
        case .maintainMuscle: "Keep your current muscle mass"
        case .buildMuscle: "Gain strength and size"
        case .improveEndurance: "Build cardiovascular fitness"
        case .increaseActivity: "Move more every day"
        case .improveHydration: "Stay consistently hydrated"
        case .improveSleep: "Build a consistent sleep routine"
        case .maintainHealth: "Stay healthy and feel good"
        }
    }
}

// MARK: - Activity

enum ActivityLevel: String, CaseIterable, Codable {
    case sedentary = "sedentary"
    case lightlyActive = "lightly_active"
    case moderatelyActive = "moderately_active"
    case veryActive = "very_active"
    case athlete = "athlete"

    var displayName: String {
        switch self {
        case .sedentary: "Sedentary"
        case .lightlyActive: "Lightly active"
        case .moderatelyActive: "Moderately active"
        case .veryActive: "Very active"
        case .athlete: "Athlete / highly active"
        }
    }

    var description: String {
        switch self {
        case .sedentary: "Desk job, little or no exercise"
        case .lightlyActive: "Light exercise 1–3 days per week"
        case .moderatelyActive: "Moderate exercise 3–5 days per week"
        case .veryActive: "Hard exercise 6–7 days per week"
        case .athlete: "Very intense daily exercise or physical job"
        }
    }

    // Mifflin-St Jeor TDEE multiplier
    var tdeeMultiplier: Double {
        switch self {
        case .sedentary: 1.2
        case .lightlyActive: 1.375
        case .moderatelyActive: 1.55
        case .veryActive: 1.725
        case .athlete: 1.9
        }
    }
}

enum Equipment: String, CaseIterable, Codable, Identifiable {
    case noEquipment = "none"
    case dumbbells = "dumbbells"
    case barbell = "barbell"
    case resistanceBands = "resistance_bands"
    case pullupBar = "pullup_bar"
    case bench = "bench"
    case cables = "cables"
    case machine = "machine"
    case treadmill = "treadmill"
    case kettlebell = "kettlebell"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .noEquipment: "No equipment"
        case .dumbbells: "Dumbbells"
        case .barbell: "Barbell"
        case .resistanceBands: "Resistance bands"
        case .pullupBar: "Pull-up bar"
        case .bench: "Bench"
        case .cables: "Cable machine"
        case .machine: "Weight machines"
        case .treadmill: "Treadmill / cardio equipment"
        case .kettlebell: "Kettlebells"
        }
    }
}

// MARK: - Units

enum WeightUnit: String, CaseIterable, Codable {
    case kilograms = "kg"
    case pounds = "lbs"

    var displayName: String { rawValue }

    func convert(_ value: Double, to target: WeightUnit) -> Double {
        guard self != target else { return value }
        return self == .kilograms ? value * 2.20462 : value / 2.20462
    }
}

enum DistanceUnit: String, CaseIterable, Codable {
    case kilometers = "km"
    case miles = "miles"

    var displayName: String { rawValue }
}

enum HeightUnit: String, CaseIterable, Codable {
    case centimeters = "cm"
    case feetInches = "ft/in"
}

// MARK: - Biological Sex

enum BiologicalSex: String, CaseIterable, Codable {
    case male = "male"
    case female = "female"

    var displayName: String {
        switch self {
        case .male: "Male"
        case .female: "Female"
        }
    }
}

// MARK: - Meals

enum MealType: String, CaseIterable, Codable {
    case breakfast = "breakfast"
    case lunch = "lunch"
    case dinner = "dinner"
    case snack = "snack"
    case preworkout = "pre_workout"
    case postworkout = "post_workout"

    var displayName: String {
        switch self {
        case .breakfast: "Breakfast"
        case .lunch: "Lunch"
        case .dinner: "Dinner"
        case .snack: "Snack"
        case .preworkout: "Pre-workout"
        case .postworkout: "Post-workout"
        }
    }

    var icon: String {
        switch self {
        case .breakfast: "sunrise"
        case .lunch: "sun.max"
        case .dinner: "moon"
        case .snack: "apple"
        case .preworkout: "bolt.circle"
        case .postworkout: "checkmark.circle"
        }
    }
}

enum MealEntrySource: String, Codable {
    case photo = "photo"
    case predefined = "predefined"
    case saved = "saved"
    case recipe = "recipe"
    case manual = "manual"
    case copied = "copied"
}

// MARK: - Diet

enum DietaryStyle: String, CaseIterable, Codable, Identifiable {
    case noRestrictions = "none"
    case vegetarian = "vegetarian"
    case vegan = "vegan"
    case pescatarian = "pescatarian"
    case glutenFree = "gluten_free"
    case dairyFree = "dairy_free"
    case keto = "keto"
    case paleo = "paleo"
    case mediterranean = "mediterranean"
    case halal = "halal"
    case kosher = "kosher"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .noRestrictions: "No restrictions"
        case .vegetarian: "Vegetarian"
        case .vegan: "Vegan"
        case .pescatarian: "Pescatarian"
        case .glutenFree: "Gluten-free"
        case .dairyFree: "Dairy-free"
        case .keto: "Keto"
        case .paleo: "Paleo"
        case .mediterranean: "Mediterranean"
        case .halal: "Halal"
        case .kosher: "Kosher"
        }
    }

    var icon: String {
        switch self {
        case .noRestrictions: "checkmark.circle"
        case .vegetarian:     "leaf"
        case .vegan:          "leaf.fill"
        case .pescatarian:    "fish"
        case .glutenFree:     "minus.circle"
        case .dairyFree:      "drop"
        case .keto:           "bolt"
        case .paleo:          "flame"
        case .mediterranean:  "sun.max"
        case .halal:          "moon.stars"
        case .kosher:         "star"
        }
    }

    /// Plain-English constraints — used in the meal plan combination summary
    var mealConstraints: [String] {
        switch self {
        case .noRestrictions: []
        case .vegetarian:     ["no meat", "no poultry"]
        case .vegan:          ["no meat", "no dairy", "no eggs"]
        case .pescatarian:    ["no meat, poultry", "fish OK"]
        case .glutenFree:     ["no wheat/gluten"]
        case .dairyFree:      ["no dairy"]
        case .keto:           ["very low carb", "high fat"]
        case .paleo:          ["no grains", "no legumes"]
        case .mediterranean:  ["whole foods", "olive oil focus"]
        case .halal:          ["halal-certified"]
        case .kosher:         ["kosher-certified"]
        }
    }
}

// MARK: - Workout

enum WorkoutIntensity: String, CaseIterable, Codable {
    case reduced  = "reduced"
    case standard = "standard"
    case extended = "extended"

    var displayName: String {
        switch self {
        case .reduced:  "Reduced session"
        case .standard: "Standard session"
        case .extended: "Extended session"
        }
    }

    var burnMultiplier: Double {
        switch self {
        case .reduced:  0.75
        case .standard: 1.0
        case .extended: 1.30
        }
    }
}

enum WorkoutGoalType: String, CaseIterable, Codable {
    case beginnerMovement = "beginner_movement"
    case generalFitness = "general_fitness"
    case strength = "strength"
    case muscleBuilding = "muscle_building"
    case fatLossSupport = "fat_loss"
    case running = "running"
    case walking = "walking"
    case mobility = "mobility"
    case homeWorkout = "home_workout"
    case gymWorkout = "gym_workout"
    case recovery = "recovery"

    var displayName: String {
        switch self {
        case .beginnerMovement: "Beginner movement"
        case .generalFitness: "General fitness"
        case .strength: "Strength"
        case .muscleBuilding: "Muscle building"
        case .fatLossSupport: "Fat-loss support"
        case .running: "Running"
        case .walking: "Walking"
        case .mobility: "Mobility"
        case .homeWorkout: "Home workout"
        case .gymWorkout: "Gym workout"
        case .recovery: "Recovery session"
        }
    }
}

// MARK: - Progression

enum RankTier: String, CaseIterable, Codable {
    case initiate = "initiate"
    case vanguard = "vanguard"
    case ascendant = "ascendant"
    case sovereign = "sovereign"
    case prime = "prime"
    case monarch = "monarch"

    var displayName: String {
        switch self {
        case .initiate: "Initiate"
        case .vanguard: "Vanguard"
        case .ascendant: "Ascendant"
        case .sovereign: "Sovereign"
        case .prime: "Prime"
        case .monarch: "Monarch"
        }
    }

    // Minimum level to achieve this rank
    var minimumLevel: Int {
        switch self {
        case .initiate: 1
        case .vanguard: 10
        case .ascendant: 25
        case .sovereign: 50
        case .prime: 80
        case .monarch: 100
        }
    }

    static func rank(for level: Int) -> RankTier {
        RankTier.allCases.reversed().first { level >= $0.minimumLevel } ?? .initiate
    }
}

enum StreakType: String, CaseIterable, Codable {
    case activity = "activity"
    case hydration = "hydration"
    case workout = "workout"
    case logging = "logging"
    case weeklyPlanning = "weekly_planning"

    var displayName: String {
        switch self {
        case .activity: "Activity"
        case .hydration: "Hydration"
        case .workout: "Workout"
        case .logging: "Logging"
        case .weeklyPlanning: "Weekly planning"
        }
    }
}

// MARK: - Measurements

enum MeasurementSite: String, CaseIterable, Codable, Identifiable {
    case waist = "waist"
    case chest = "chest"
    case hips = "hips"
    case neck = "neck"
    case upperArm = "upper_arm"
    case thigh = "thigh"
    case calf = "calf"
    case custom = "custom"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .waist: "Waist"
        case .chest: "Chest"
        case .hips: "Hips"
        case .neck: "Neck"
        case .upperArm: "Upper arm"
        case .thigh: "Thigh"
        case .calf: "Calf"
        case .custom: "Custom"
        }
    }
}

enum PhotoAngle: String, CaseIterable, Codable {
    case front = "front"
    case side = "side"
    case back = "back"
    case custom = "custom"

    var displayName: String {
        switch self {
        case .front: "Front"
        case .side: "Side"
        case .back: "Back"
        case .custom: "Custom"
        }
    }
}

// MARK: - XP

func requiredXP(for level: Int) -> Int {
    Int(100 * pow(Double(max(level, 1)), 1.35))
}
