import Foundation
import SwiftData
import UserNotifications

@MainActor
final class DataDeletionService {

    static let shared = DataDeletionService()
    private init() {}

    // MARK: - Public API

    /// Deletes all activity-related records: meals, water, weight, workouts,
    /// daily targets/summaries, body measurements, and progress photo files.
    func deleteActivityData(in context: ModelContext) throws {
        try deleteAll(MealEntry.self, in: context)
        try deleteAll(WaterEntry.self, in: context)
        try deleteAll(WeightEntry.self, in: context)
        try deleteAll(WorkoutSession.self, in: context)  // cascade removes ExerciseLog / ExerciseSetLog
        try deleteAll(DailyTarget.self, in: context)
        try deleteAll(DailySummary.self, in: context)
        try deleteAll(BodyMeasurement.self, in: context)
        PhotoStorageService.shared.deleteAll()
        try deleteAll(ProgressPhoto.self, in: context)
        try context.save()
    }

    /// Deletes progression records: streaks, achievements, and XP ledger.
    func deleteProgressionData(in context: ModelContext) throws {
        try deleteAll(Streak.self, in: context)
        try deleteAll(UserAchievement.self, in: context)
        try deleteAll(XPLedger.self, in: context)
        try context.save()
    }

    /// Full local reset — removes profile, goal, preferences, and all activity/progression data,
    /// and cancels all scheduled notifications.
    func deleteAllLocalData(in context: ModelContext) throws {
        try deleteActivityData(in: context)
        try deleteProgressionData(in: context)
        try deleteAll(UserProfile.self, in: context)
        try deleteAll(GoalProfile.self, in: context)
        try deleteAll(UserPreference.self, in: context)
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        try context.save()
    }

    // MARK: - Private

    private func deleteAll<T: PersistentModel>(_ type: T.Type, in context: ModelContext) throws {
        let records = try context.fetch(FetchDescriptor<T>())
        records.forEach { context.delete($0) }
    }
}
