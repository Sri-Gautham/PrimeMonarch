import SwiftUI

struct GoalsStepView: View {
    @Binding var selectedGoals: Set<GoalType>
    @Binding var primaryGoal: GoalType

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PMSpacing.lg) {
                OnboardingStepHeader(
                    title: "What are your goals?",
                    subtitle: "Select everything that applies to you"
                )

                LazyVGrid(columns: columns, spacing: PMSpacing.sm) {
                    ForEach(GoalType.allCases) { goal in
                        GoalCard(
                            goal: goal,
                            isSelected: selectedGoals.contains(goal),
                            action: { toggleGoal(goal) }
                        )
                    }
                }

                if !selectedGoals.isEmpty {
                    Divider().overlay(Color.pmDivider)

                    Text("Which is your main focus?")
                        .font(.pmSectionTitle)
                        .foregroundStyle(.pmTextPrimary)

                    ForEach(GoalType.allCases.filter { selectedGoals.contains($0) }) { goal in
                        RadioRow(title: goal.displayName, isSelected: primaryGoal == goal) {
                            primaryGoal = goal
                        }
                    }
                }
            }
            .padding(.horizontal, PMSpacing.screenEdge)
            .padding(.top, PMSpacing.md)
            .padding(.bottom, PMSpacing.xl)
        }
    }

    private func toggleGoal(_ goal: GoalType) {
        if selectedGoals.contains(goal) {
            selectedGoals.remove(goal)
            if primaryGoal == goal {
                primaryGoal = selectedGoals.first ?? .maintainHealth
            }
        } else {
            selectedGoals.insert(goal)
            if selectedGoals.count == 1 { primaryGoal = goal }
        }
    }
}

// MARK: - Goal Card

private struct GoalCard: View {
    let goal: GoalType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: PMSpacing.xs) {
                Image(systemName: goal.icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.pmAccentPurpleBright : Color.pmTextSecondary)

                Text(goal.displayName)
                    .font(.pmCardTitle)
                    .foregroundStyle(.pmTextPrimary)
                    .multilineTextAlignment(.leading)

                Text(goal.shortDescription)
                    .font(.pmCaption)
                    .foregroundStyle(.pmTextSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .padding(PMSpacing.sm)
            .frame(maxWidth: .infinity, minHeight: 90, alignment: .topLeading)
            .background(isSelected ? Color.pmAccentPurple.opacity(0.15) : Color.pmSurfacePrimary)
            .clipShape(RoundedRectangle(cornerRadius: PMSpacing.cardRadius))
            .overlay {
                RoundedRectangle(cornerRadius: PMSpacing.cardRadius)
                    .stroke(isSelected ? Color.pmAccentPurple : Color.clear, lineWidth: 1.5)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(goal.displayName)
        .accessibilityHint(goal.shortDescription)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
