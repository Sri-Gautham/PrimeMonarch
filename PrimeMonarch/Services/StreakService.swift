import SwiftData
import Foundation

// MARK: - Streak Service
//
// Manages the lifetime of the logging Streak row.
// Rules:
//  • Credit: called after any MealEntry is saved. Extends the streak if
//    yesterday was the last credited day, starts a new streak (count = 1)
//    if the row is fresh or the gap is > 1 day.
//  • Already credited today → no-op (idempotent).
//  • Reset: called on each app foreground. If the last credited day was
//    2+ days ago the streak is broken and currentCount is zeroed.
//
// Grace-day mechanic (spec: "prompt next morning to mark yesterday as
// rest day") is tracked via graceUsedDate but the UI prompt is Phase 2.

@MainActor
final class StreakService {

    // MARK: - Ensure row exists

    static func ensureLoggingStreak(in context: ModelContext) {
        guard fetchLoggingStreak(in: context) == nil else { return }
        context.insert(Streak(streakType: .logging))
        try? context.save()
    }

    // MARK: - Credit today

    /// Call after successfully inserting a MealEntry.
    /// Idempotent — calling multiple times on the same day has no effect.
    static func creditLoggingStreak(in context: ModelContext) {
        ensureLoggingStreak(in: context)
        guard let streak = fetchLoggingStreak(in: context) else { return }

        let cal   = Calendar.current
        let today = cal.startOfDay(for: Date())

        // Already credited today
        if let last = streak.lastCompletedDate, cal.isDateInToday(last) { return }

        if streak.currentCount == 0 || streak.lastCompletedDate == nil {
            streak.currentCount = 1
        } else if let last = streak.lastCompletedDate,
                  cal.isDate(last, inSameDayAs: cal.date(byAdding: .day, value: -1, to: today)!) {
            streak.currentCount += 1
        } else {
            // Gap > 1 day — start fresh
            streak.currentCount = 1
        }

        streak.lastCompletedDate = Date()
        streak.longestCount      = max(streak.longestCount, streak.currentCount)
        try? context.save()
    }

    // MARK: - Reset check (call on app foreground)

    /// Zeros the streak if the last credited day was 2+ calendar days ago,
    /// unless a grace day was consumed yesterday (in which case the streak is preserved).
    static func checkAndResetIfNeeded(in context: ModelContext) {
        guard let streak = fetchLoggingStreak(in: context),
              let last   = streak.lastCompletedDate,
              streak.currentCount > 0 else { return }

        let cal           = Calendar.current
        let today         = cal.startOfDay(for: Date())
        let lastDay       = cal.startOfDay(for: last)
        let daysSinceLast = cal.dateComponents([.day], from: lastDay, to: today).day ?? 0

        if daysSinceLast >= 2 {
            // Check if a grace day covers the gap (grace used yesterday)
            if let grace = streak.graceUsedDate,
               cal.isDate(cal.startOfDay(for: grace),
                          inSameDayAs: cal.date(byAdding: .day, value: -1, to: today)!) {
                // Grace consumed yesterday — treat as credited; advance lastCompletedDate
                streak.lastCompletedDate = grace
            } else {
                streak.currentCount = 0
            }
            try? context.save()
        }
    }

    // MARK: - Rest day / grace

    /// Returns true if a grace day is available (no grace used in the trailing 7 days)
    /// and the streak is worth preserving (currentCount > 0).
    static func canMarkRestDay(in context: ModelContext) -> Bool {
        guard let streak = fetchLoggingStreak(in: context),
              streak.currentCount > 0 else { return false }
        guard let graceDate = streak.graceUsedDate else { return true }
        let cal       = Calendar.current
        let daysSince = cal.dateComponents(
            [.day],
            from: cal.startOfDay(for: graceDate),
            to: cal.startOfDay(for: Date())
        ).day ?? 0
        return daysSince >= 7
    }

    /// Marks today as a rest day, consuming one grace day and preserving the streak.
    /// Returns false if no grace is available (already used within 7 days).
    @discardableResult
    static func markRestDay(in context: ModelContext) -> Bool {
        guard canMarkRestDay(in: context),
              let streak = fetchLoggingStreak(in: context) else { return false }

        streak.graceUsedDate     = Date()
        streak.lastCompletedDate = Date()  // keeps checkAndResetIfNeeded from breaking it

        let today    = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        let summaryDesc = FetchDescriptor<DailySummary>(
            predicate: #Predicate { $0.date >= today && $0.date < tomorrow }
        )
        if let summary = (try? context.fetch(summaryDesc))?.first {
            summary.isRestDay = true
        }

        try? context.save()
        return true
    }

    // MARK: - Private

    private static func fetchLoggingStreak(in context: ModelContext) -> Streak? {
        let raw = StreakType.logging.rawValue
        let desc = FetchDescriptor<Streak>(
            predicate: #Predicate { $0.streakTypeRawValue == raw }
        )
        return try? context.fetch(desc).first
    }
}
