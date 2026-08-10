import SwiftData
import SwiftUI

struct NotificationsSettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss)      private var dismiss

    @Query private var preferences: [UserPreference]
    private var preference: UserPreference? { preferences.first }

    @State private var waterEnabled         = false
    @State private var stepEnabled          = false
    @State private var mealEnabled          = false
    @State private var workoutEnabled       = false
    @State private var weeklyReviewEnabled  = false
    @State private var loaded               = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: PMSpacing.lg) {
                    // Info banner
                    PMCard {
                        HStack(alignment: .top, spacing: PMSpacing.sm) {
                            Image(systemName: "bell.badge")
                                .font(.system(size: 15))
                                .foregroundStyle(.pmAccentPurpleBright)
                                .padding(.top, 1)
                            Text("iOS notification permission is required for reminders to appear. If you haven't granted it yet, go to Settings → PrimeMonarch → Notifications.")
                                .font(.pmCaption)
                                .foregroundStyle(.pmTextSecondary)
                        }
                        .padding(PMSpacing.md)
                    }
                    .padding(.horizontal, PMSpacing.screenEdge)

                    // Reminder toggles
                    NotifSection(title: "REMINDERS") {
                        NotifToggleRow(
                            label: "Water reminders",
                            detail: "Periodic hydration nudges throughout the day",
                            icon: "drop.fill",
                            isOn: $waterEnabled
                        )
                        PMDivider().padding(.horizontal, PMSpacing.md)
                        NotifToggleRow(
                            label: "Step reminders",
                            detail: "Gentle push when you're behind on your daily goal",
                            icon: "figure.walk",
                            isOn: $stepEnabled
                        )
                        PMDivider().padding(.horizontal, PMSpacing.md)
                        NotifToggleRow(
                            label: "Meal reminders",
                            detail: "Reminders to log meals at your scheduled times",
                            icon: "fork.knife",
                            isOn: $mealEnabled
                        )
                        PMDivider().padding(.horizontal, PMSpacing.md)
                        NotifToggleRow(
                            label: "Workout reminders",
                            detail: "Alert before your scheduled workout time",
                            icon: "dumbbell",
                            isOn: $workoutEnabled
                        )
                        PMDivider().padding(.horizontal, PMSpacing.md)
                        NotifToggleRow(
                            label: "Weekly review",
                            detail: "Sunday summary of your progress and streak",
                            icon: "chart.bar.fill",
                            isOn: $weeklyReviewEnabled
                        )
                    }
                    .padding(.horizontal, PMSpacing.screenEdge)

                    Spacer().frame(height: PMSpacing.xxl)
                }
                .padding(.top, PMSpacing.md)
            }
            .background(Color.pmBackgroundPrimary.ignoresSafeArea())
            .navigationTitle("Notifications")
            .pmLargeNavTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(.pmTextSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.font(.pmButtonLabel)
                }
            }
        }
        .onAppear { loadCurrentValues() }
    }

    // MARK: - Load / Save

    private func loadCurrentValues() {
        guard !loaded, let pref = preference else { return }
        waterEnabled        = pref.waterRemindersEnabled
        stepEnabled         = pref.stepRemindersEnabled
        mealEnabled         = pref.mealRemindersEnabled
        workoutEnabled      = pref.workoutRemindersEnabled
        weeklyReviewEnabled = pref.weeklyReviewReminderEnabled
        loaded = true
    }

    private func save() {
        guard let pref = preference else { return }
        pref.waterRemindersEnabled        = waterEnabled
        pref.stepRemindersEnabled         = stepEnabled
        pref.mealRemindersEnabled         = mealEnabled
        pref.workoutRemindersEnabled      = workoutEnabled
        pref.weeklyReviewReminderEnabled  = weeklyReviewEnabled
        pref.updatedAt                    = Date()
        try? context.save()
        NotificationService.shared.reschedule(from: pref)
        Task { await NotificationService.shared.requestAuthorizationIfNeeded() }
        dismiss()
    }
}

// MARK: - Toggle Row

private struct NotifToggleRow: View {
    let label: String
    let detail: String
    let icon: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: PMSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundStyle(.pmAccentPurpleBright)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.pmBodyMedium)
                        .foregroundStyle(.pmTextPrimary)
                    Text(detail)
                        .font(.pmCaption)
                        .foregroundStyle(.pmTextSecondary)
                }
            }
        }
        .tint(.pmAccentPurpleBright)
        .padding(.horizontal, PMSpacing.md)
        .padding(.vertical, PMSpacing.sm)
    }
}

// MARK: - Section wrapper

private struct NotifSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: PMSpacing.xs) {
            Text(title)
                .font(.pmKicker)
                .tracking(0.6)
                .foregroundStyle(.pmTextSecondary)
                .padding(.horizontal, 2)
            PMCard(elevated: true) { content() }
        }
    }
}
