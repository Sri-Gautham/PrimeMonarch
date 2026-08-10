import SwiftUI

struct FoodPreferencesStepView: View {
    @Binding var selectedDietaryStyles: Set<DietaryStyle>
    @Binding var mealsPerDay: Int

    private var hasRestrictions: Bool {
        !selectedDietaryStyles.isEmpty && !selectedDietaryStyles.contains(.noRestrictions)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PMSpacing.lg) {
                OnboardingStepHeader(
                    title: "Your eating style",
                    subtitle: "Select all that apply — we'll combine them for your meal suggestions"
                )

                // Dietary multi-select
                VStack(alignment: .leading, spacing: PMSpacing.sm) {
                    Text("Dietary preferences")
                        .font(.pmCardTitle)
                        .foregroundStyle(.pmTextSecondary)

                    // "No restrictions" is mutually exclusive with all others
                    DietaryStyleChip(
                        style: .noRestrictions,
                        isSelected: selectedDietaryStyles.contains(.noRestrictions),
                        isFullWidth: true
                    ) {
                        selectedDietaryStyles = [.noRestrictions]
                    }

                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible())],
                        spacing: PMSpacing.xs
                    ) {
                        ForEach(DietaryStyle.allCases.filter { $0 != .noRestrictions }) { style in
                            DietaryStyleChip(
                                style: style,
                                isSelected: selectedDietaryStyles.contains(style)
                            ) {
                                handleTap(style)
                            }
                        }
                    }
                }

                // Combination summary card — visible when any restriction is active
                if hasRestrictions {
                    combinationSummaryCard
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .animation(.easeInOut(duration: 0.2), value: selectedDietaryStyles.count)
                }

                Divider().overlay(Color.pmDivider)

                // Meals per day
                VStack(alignment: .leading, spacing: PMSpacing.xs) {
                    Text("Meal frequency")
                        .font(.pmCardTitle)
                        .foregroundStyle(.pmTextSecondary)

                    HStack {
                        VStack(alignment: .leading, spacing: PMSpacing.xxs) {
                            Text("Meals per day")
                                .font(.pmBodyMedium)
                                .foregroundStyle(.pmTextPrimary)
                            Text("Snacks count as meals")
                                .font(.pmCaption)
                                .foregroundStyle(.pmTextSecondary)
                        }
                        Spacer()
                        Stepper("\(mealsPerDay)", value: $mealsPerDay, in: 2...6)
                            .tint(Color.pmAccentPurpleBright)
                            .font(.pmBodyMedium)
                            .foregroundStyle(.pmTextPrimary)
                    }
                    .padding(PMSpacing.sm)
                    .background(Color.pmSurfacePrimary)
                    .clipShape(RoundedRectangle(cornerRadius: PMSpacing.cardRadius))
                }

                Text("Allergies, cuisines, and cooking preferences can be fine-tuned in Settings after setup.")
                    .font(.pmCaption)
                    .foregroundStyle(.pmTextTertiary)
                    .multilineTextAlignment(.leading)
            }
            .padding(.horizontal, PMSpacing.screenEdge)
            .padding(.top, PMSpacing.md)
            .padding(.bottom, PMSpacing.xl)
        }
    }

    // MARK: Tap logic

    private func handleTap(_ style: DietaryStyle) {
        if selectedDietaryStyles.contains(style) {
            selectedDietaryStyles.remove(style)
            if selectedDietaryStyles.isEmpty {
                selectedDietaryStyles = [.noRestrictions]
            }
        } else {
            selectedDietaryStyles.remove(.noRestrictions)
            selectedDietaryStyles.insert(style)
        }
    }

    // MARK: Combination summary

    private var combinationSummaryCard: some View {
        VStack(alignment: .leading, spacing: PMSpacing.sm) {
            HStack(spacing: PMSpacing.xs) {
                Image(systemName: "fork.knife.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.pmAccentPurpleBright)
                Text("Meal plan profile")
                    .font(.pmCardTitle)
                    .foregroundStyle(.pmTextPrimary)
            }

            // Active selection chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: PMSpacing.xs) {
                    ForEach(Array(selectedDietaryStyles).sorted(by: { $0.displayName < $1.displayName })) { style in
                        HStack(spacing: 4) {
                            Image(systemName: style.icon)
                                .font(.system(size: 11))
                            Text(style.displayName)
                                .font(.pmCaption)
                        }
                        .foregroundStyle(Color.pmAccentPurpleBright)
                        .padding(.horizontal, PMSpacing.xs)
                        .padding(.vertical, 4)
                        .background(Color.pmAccentPurple.opacity(0.12))
                        .clipShape(Capsule())
                    }
                }
            }

            // Deduplicated constraints
            let constraints = Array(
                Set(selectedDietaryStyles.flatMap { $0.mealConstraints })
            ).sorted()

            if !constraints.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Recipes will exclude:")
                        .font(.pmCaption)
                        .foregroundStyle(.pmTextSecondary)
                    PMFlowLayout(spacing: PMSpacing.xxs) {
                        ForEach(constraints, id: \.self) { constraint in
                            Text(constraint)
                                .font(.pmCaption)
                                .foregroundStyle(.pmTextTertiary)
                                .padding(.horizontal, PMSpacing.xs)
                                .padding(.vertical, 3)
                                .background(Color.pmSurfaceElevated)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .padding(PMSpacing.md)
        .background(Color.pmAccentPurple.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: PMSpacing.cardRadius))
        .overlay {
            RoundedRectangle(cornerRadius: PMSpacing.cardRadius)
                .stroke(Color.pmAccentPurple.opacity(0.2), lineWidth: 1)
        }
    }
}

// MARK: - Dietary Style Chip

private struct DietaryStyleChip: View {
    let style: DietaryStyle
    let isSelected: Bool
    var isFullWidth: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: PMSpacing.xs) {
                Image(systemName: style.icon)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(isSelected ? Color.pmAccentPurpleBright : Color.pmTextSecondary)
                    .frame(width: 18)

                Text(style.displayName)
                    .font(.pmSecondaryBody)
                    .foregroundStyle(isSelected ? .pmTextPrimary : .pmTextSecondary)
                    .lineLimit(1)

                if isFullWidth { Spacer() }

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.pmAccentPurpleBright)
                }
            }
            .padding(.horizontal, PMSpacing.sm)
            .padding(.vertical, PMSpacing.xs)
            .frame(maxWidth: isFullWidth ? .infinity : nil, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: PMSpacing.cardRadius)
                    .fill(isSelected ? Color.pmAccentPurple.opacity(0.12) : Color.pmSurfacePrimary)
            )
            .overlay {
                RoundedRectangle(cornerRadius: PMSpacing.cardRadius)
                    .stroke(isSelected ? Color.pmAccentPurple.opacity(0.5) : Color.clear, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.12), value: isSelected)
    }
}

// MARK: - Flow Layout (wrapping tag cloud)

struct PMFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                y += rowHeight + spacing; x = 0; rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                y += rowHeight + spacing; x = bounds.minX; rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
