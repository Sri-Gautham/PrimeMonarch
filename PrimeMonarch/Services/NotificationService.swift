import Foundation
import SwiftData
import UserNotifications

// MARK: - Notification Service
//
// Schedules / cancels local UNUserNotificationCenter reminders driven by
// UserPreference toggles. Purely additive — no server, no push certificate.

@MainActor
final class NotificationService {

    static let shared = NotificationService()
    private let center = UNUserNotificationCenter.current()

    // MARK: - Authorization

    /// Request permission the first time (no-op if already determined).
    func requestAuthorizationIfNeeded() async {
        let status = await center.notificationSettings().authorizationStatus
        guard status == .notDetermined else { return }
        try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    // MARK: - Reschedule from context

    /// Fetches the first UserPreference from context and reschedules accordingly.
    func rescheduleFromContext(_ context: ModelContext) {
        guard let pref = try? context.fetch(FetchDescriptor<UserPreference>()).first else { return }
        reschedule(from: pref)
    }

    // MARK: - Reschedule from preference

    /// Cancel all pending notifications then re-add based on current toggles.
    func reschedule(from preference: UserPreference) {
        center.removeAllPendingNotificationRequests()

        if preference.waterRemindersEnabled {
            scheduleWaterReminders(
                wakeHour: preference.wakeHour,
                sleepHour: preference.sleepHour
            )
        }
        if preference.mealRemindersEnabled {
            scheduleMealReminders(
                mealsPerDay: preference.mealsPerDay,
                wakeHour: preference.wakeHour
            )
        }
        if preference.workoutRemindersEnabled {
            scheduleWorkoutReminder(
                hour: preference.workoutTimeHour,
                minute: preference.workoutTimeMinute
            )
        }
        if preference.stepRemindersEnabled {
            scheduleStepReminder()
        }
        if preference.weeklyReviewReminderEnabled {
            scheduleWeeklyReview(hour: min(preference.wakeHour + 1, 10))
        }
    }

    // MARK: - Private scheduling

    private func scheduleWaterReminders(wakeHour: Int, sleepHour: Int) {
        let span = Double(max(sleepHour - wakeHour, 4))
        let fractions = [0.25, 0.5, 0.75]
        for (i, fraction) in fractions.enumerated() {
            schedule(
                id: "water_\(i)",
                title: "Stay hydrated",
                body: "Time for a glass of water — every sip counts.",
                hour: wakeHour + Int(span * fraction),
                minute: 0
            )
        }
    }

    private func scheduleMealReminders(mealsPerDay: Int, wakeHour: Int) {
        let slots: [(hour: Int, minute: Int)] = [
            (wakeHour + 1, 0),
            (12, 30),
            (18, 30),
            (21, 0)
        ]
        for i in 0..<min(mealsPerDay, slots.count) {
            schedule(
                id: "meal_\(i)",
                title: "Meal time",
                body: "Don't forget to log what you eat.",
                hour: slots[i].hour,
                minute: slots[i].minute
            )
        }
    }

    private func scheduleWorkoutReminder(hour: Int, minute: Int) {
        schedule(
            id: "workout",
            title: "Workout time",
            body: "Your scheduled session is coming up. You've got this.",
            hour: hour,
            minute: minute
        )
    }

    private func scheduleStepReminder() {
        // Mid-afternoon nudge — fires at 3 pm daily.
        schedule(
            id: "steps",
            title: "Get moving",
            body: "Behind on your step goal? A short walk can help.",
            hour: 15,
            minute: 0
        )
    }

    private func scheduleWeeklyReview(hour: Int) {
        let content   = UNMutableNotificationContent()
        content.title = "Weekly review"
        content.body  = "Check out your progress from this week."
        content.sound = .default

        var components     = DateComponents()
        components.weekday = 1  // Sunday
        components.hour    = clampedHour(hour)
        components.minute  = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        center.add(UNNotificationRequest(identifier: "weekly_review", content: content, trigger: trigger))
    }

    // MARK: - Helpers

    private func schedule(id: String, title: String, body: String, hour: Int, minute: Int) {
        let content   = UNMutableNotificationContent()
        content.title = title
        content.body  = body
        content.sound = .default

        var components  = DateComponents()
        components.hour   = clampedHour(hour)
        components.minute = min(max(minute, 0), 59)

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    private func clampedHour(_ h: Int) -> Int { min(max(h, 0), 23) }
}
