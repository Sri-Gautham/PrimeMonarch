import Foundation
import SwiftData

// MARK: - Export Service

@MainActor
final class DataExportService {

    static let shared = DataExportService()
    private init() {}

    /// Fetches all user data from SwiftData, serialises it to JSON, writes to a temp file,
    /// and returns the URL for sharing.
    func export(from context: ModelContext) throws -> URL {
        let profiles = try context.fetch(FetchDescriptor<UserProfile>())
        let meals    = try context.fetch(FetchDescriptor<MealEntry>(sortBy: [SortDescriptor(\.consumedAt)]))
        let water    = try context.fetch(FetchDescriptor<WaterEntry>(sortBy: [SortDescriptor(\.loggedAt)]))
        let weight   = try context.fetch(FetchDescriptor<WeightEntry>(sortBy: [SortDescriptor(\.loggedAt)]))
        let workouts = try context.fetch(FetchDescriptor<WorkoutSession>(sortBy: [SortDescriptor(\.startedAt)]))

        let payload = HealthDataExport(
            exportedAt: Date(),
            exportVersion: "1.0",
            profile: profiles.first.map(ProfileExport.init),
            meals: meals.map(MealExport.init),
            water: water.map(WaterExport.init),
            weight: weight.map(WeightExport.init),
            workouts: workouts.map(WorkoutExport.init)
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(payload)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let filename = "PrimeMonarch_Export_\(formatter.string(from: Date())).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try data.write(to: url)
        return url
    }
}

// MARK: - Export DTOs (private)

private struct HealthDataExport: Codable {
    let exportedAt: Date
    let exportVersion: String
    let profile: ProfileExport?
    let meals: [MealExport]
    let water: [WaterExport]
    let weight: [WeightExport]
    let workouts: [WorkoutExport]
}

private struct ProfileExport: Codable {
    let displayName: String?
    let ageYears: Int?
    let biologicalSex: String
    let heightCentimeters: Double?
    let currentWeightKilograms: Double?
    let targetWeightKilograms: Double?

    init(_ p: UserProfile) {
        displayName = p.displayName
        ageYears = p.ageYears
        biologicalSex = p.biologicalSexRawValue
        heightCentimeters = p.heightCentimeters
        currentWeightKilograms = p.currentWeightKilograms
        targetWeightKilograms = p.targetWeightKilograms
    }
}

private struct MealExport: Codable {
    let date: Date
    let mealType: String
    let title: String
    let calories: Double
    let proteinGrams: Double?
    let carbohydrateGrams: Double?
    let fatGrams: Double?

    init(_ e: MealEntry) {
        date = e.consumedAt
        mealType = e.mealTypeRawValue
        title = e.title
        calories = e.calories
        proteinGrams = e.proteinGrams
        carbohydrateGrams = e.carbohydrateGrams
        fatGrams = e.fatGrams
    }
}

private struct WaterExport: Codable {
    let date: Date
    let amountMilliliters: Double

    init(_ e: WaterEntry) {
        date = e.loggedAt
        amountMilliliters = e.amountMilliliters
    }
}

private struct WeightExport: Codable {
    let date: Date
    let weightKilograms: Double
    let notes: String?

    init(_ e: WeightEntry) {
        date = e.loggedAt
        weightKilograms = e.weightKilograms
        notes = e.notes
    }
}

private struct WorkoutExport: Codable {
    let date: Date
    let title: String
    let durationSeconds: Double?
    let caloriesBurned: Double?
    let exercises: [ExerciseExport]

    @MainActor
    init(_ s: WorkoutSession) {
        date = s.startedAt
        title = s.title
        durationSeconds = s.durationSeconds
        caloriesBurned = s.totalEnergyKilocalories
        exercises = s.exerciseLogs
            .sorted { $0.orderIndex < $1.orderIndex }
            .map { ExerciseExport($0) }
    }
}

private struct ExerciseExport: Codable {
    let name: String
    let sets: [SetExport]

    @MainActor
    init(_ log: ExerciseLog) {
        name = log.exerciseName
        sets = log.sets
            .sorted { $0.setNumber < $1.setNumber }
            .map { SetExport($0) }
    }
}

private struct SetExport: Codable {
    let setNumber: Int
    let reps: Int?
    let weightKilograms: Double?
    let durationSeconds: Double?
    let isCompleted: Bool

    init(_ s: ExerciseSetLog) {
        setNumber = s.setNumber
        reps = s.reps
        weightKilograms = s.weightKilograms
        durationSeconds = s.durationSeconds
        isCompleted = s.isCompleted
    }
}
