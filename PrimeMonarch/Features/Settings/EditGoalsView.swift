import SwiftData
import SwiftUI

struct EditGoalsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss)      private var dismiss

    @Query private var goalProfiles: [GoalProfile]
    @Query private var profiles:     [UserProfile]

    @State private var selectedGoal:     GoalType     = .maintainHealth
    @State private var selectedActivity: ActivityLevel = .moderatelyActive
    @State private var targetWeightText  = ""
    @State private var stepGoal          = 8000
    @State private var loaded            = false

    private var goalProfile: GoalProfile? { goalProfiles.first }
    private var profile:     UserProfile? { profiles.first }

    private var showTargetWeight: Bool {
        selectedGoal == .loseWeight || selectedGoal == .reduceFat || selectedGoal == .buildMuscle
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: PMSpacing.lg) {
                    // Primary goal
                    FormSection(title: "PRIMARY GOAL") {
                        VStack(spacing: 0) {
                            ForEach(Array(GoalType.allCases.enumerated()), id: \.element.id) { i, goal in
                                if i > 0 { PMDivider().padding(.horizontal, PMSpacing.md) }
                                GoalOptionRow(
                                    goal: goal,
                                    isSelected: selectedGoal == goal
                                ) { selectedGoal = goal }
                            }
                        }
                    }

                    // Activity level
                    FormSection(title: "ACTIVITY LEVEL") {
                        VStack(spacing: 0) {
                            ForEach(Array(ActivityLevel.allCases.enumerated()), id: \.element.rawValue) { i, level in
                                if i > 0 { PMDivider().padding(.horizontal, PMSpacing.md) }
                                ActivityOptionRow(
                                    level: level,
                                    isSelected: selectedActivity == level
                                ) { selectedActivity = level }
                            }
                        }
                    }

                    // Target weight (conditional)
                    if showTargetWeight {
                        FormSection(title: "TARGET WEIGHT") {
                            PMFormField(
                                label: "Target (\(profile?.preferredWeightUnit.displayName ?? "kg"))",
                                text: $targetWeightText,
                                placeholder: "e.g. 75",
                                isNumeric: true
                            )
                            .padding(PMSpacing.md)
                        }
                    }

                    // Daily step goal
                    FormSection(title: "DAILY STEP GOAL") {
                        VStack(spacing: PMSpacing.xs) {
                            HStack {
                                Text("\(stepGoal.formatted(.number)) steps")
                                    .font(.system(size: 18, weight: .heavy))
                                    .foregroundStyle(.pmTextPrimary)
                                Spacer()
                            }
                            Slider(value: Binding(
                                get:  { Double(stepGoal) },
                                set:  { stepGoal = Int($0) }
                            ), in: 3000...25000, step: 500)
                            .tint(.pmAccentPurpleBright)
                            HStack {
                                Text("3,000").font(.pmCaption).foregroundStyle(.pmTextSecondary)
                                Spacer()
                                Text("25,000").font(.pmCaption).foregroundStyle(.pmTextSecondary)
                            }
                        }
                        .padding(PMSpacing.md)
                    }

                    Spacer().frame(height: PMSpacing.xxl)
                }
                .padding(.horizontal, PMSpacing.screenEdge)
                .padding(.top, PMSpacing.md)
            }
            .background(Color.pmBackgroundPrimary.ignoresSafeArea())
            .navigationTitle("Edit Goals")
            .pmLargeNavTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(.pmTextSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .font(.pmButtonLabel)
                }
            }
        }
        .onAppear { loadCurrentValues() }
    }

    // MARK: - Layout helpers (calls forwarded to private view below)

    // MARK: - Load / Save

    private func loadCurrentValues() {
        guard !loaded, let gp = goalProfile else { return }
        selectedGoal     = gp.primaryGoal
        selectedActivity = gp.activityLevel
        stepGoal         = gp.typicalDailySteps
        if let tw = profile?.targetWeightKilograms {
            let unit = profile?.preferredWeightUnit ?? .kilograms
            targetWeightText = unit == .kilograms
                ? String(format: "%.1f", tw)
                : String(format: "%.0f", tw * 2.20462)
        }
        loaded = true
    }

    private func save() {
        // Update GoalProfile
        if let gp = goalProfile {
            gp.primaryGoal     = selectedGoal
            gp.activityLevel   = selectedActivity
            gp.typicalDailySteps = stepGoal
            gp.updatedAt       = Date()
        }

        // Update target weight on UserProfile
        if showTargetWeight, let w = Double(targetWeightText), w > 0 {
            let unit = profile?.preferredWeightUnit ?? .kilograms
            let kg   = unit == .kilograms ? w : w / 2.20462
            profile?.targetWeightKilograms = kg
        }

        // Recalculate today's DailyTarget with the new values
        let today    = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        if let existing = try? context.fetch(FetchDescriptor<DailyTarget>(
            predicate: #Predicate { $0.date >= today && $0.date < tomorrow }
        )) {
            existing.forEach { context.delete($0) }
        }

        try? context.save()
        DailyTargetService.ensureTodayTarget(in: context)
        dismiss()
    }
}

// MARK: - Goal Option Row

private struct GoalOptionRow: View {
    let goal: GoalType
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: PMSpacing.sm) {
                Image(systemName: goal.icon)
                    .font(.system(size: 16))
                    .foregroundStyle(isSelected ? .pmAccentPurpleBright : .pmTextSecondary)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.displayName)
                        .font(.pmBodyMedium)
                        .foregroundStyle(.pmTextPrimary)
                    Text(goal.shortDescription)
                        .font(.pmCaption)
                        .foregroundStyle(.pmTextSecondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.pmAccentPurpleBright)
                }
            }
            .padding(.horizontal, PMSpacing.md)
            .padding(.vertical, PMSpacing.sm)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Activity Option Row

private struct ActivityOptionRow: View {
    let level: ActivityLevel
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: PMSpacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(level.displayName)
                        .font(.pmBodyMedium)
                        .foregroundStyle(.pmTextPrimary)
                    Text(level.description)
                        .font(.pmCaption)
                        .foregroundStyle(.pmTextSecondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.pmAccentPurpleBright)
                }
            }
            .padding(.horizontal, PMSpacing.md)
            .padding(.vertical, PMSpacing.sm)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Shared section wrapper

private struct FormSection<Content: View>: View {
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
