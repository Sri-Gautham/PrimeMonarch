import SwiftData

// MARK: - V1 Schema (baseline — all models at first release)
// When adding new @Model types or changing existing ones:
//   1. Create PrimeMonarchSchemaV2 with the updated models list
//   2. Add a MigrationStage (lightweight or custom) from V1 → V2
//   3. Append V2 to PrimeMonarchMigrationPlan.schemas and the stage to .stages

enum PrimeMonarchSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { .init(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [
            UserProfile.self,
            GoalProfile.self,
            UserPreference.self,
            DailyTarget.self,
            DailySummary.self,
            WeightEntry.self,
            WaterEntry.self,
            MealEntry.self,
            WorkoutSession.self,
            ExerciseLog.self,
            ExerciseSetLog.self,
            Streak.self,
            Achievement.self,
            UserAchievement.self,
            XPLedger.self,
            BodyMeasurement.self,
            ProgressPhoto.self,
        ]
    }
}

// MARK: - Migration Plan

enum PrimeMonarchMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [PrimeMonarchSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}
