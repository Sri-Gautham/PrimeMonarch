import SwiftUI

struct ActivityStepView: View {
    @Binding var activityLevel: ActivityLevel
    @Binding var selectedEquipment: Set<Equipment>
    @Binding var workoutDaysPerWeek: Int
    @Binding var workoutDurationMinutes: Int

    private let durationOptions = [20, 30, 45, 60, 90]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PMSpacing.lg) {
                OnboardingStepHeader(
                    title: "Your activity level",
                    subtitle: "This shapes your daily calorie and movement targets"
                )

                // Activity level radio list
                ForEach(ActivityLevel.allCases, id: \.self) { level in
                    RadioRow(title: level.displayName, subtitle: level.description,
                             isSelected: activityLevel == level) {
                        activityLevel = level
                    }
                }

                Divider().overlay(Color.pmDivider)

                // Equipment
                Text("Equipment available")
                    .font(.pmSectionTitle)
                    .foregroundStyle(.pmTextPrimary)

                Text("Select all you have access to")
                    .font(.pmSecondaryBody)
                    .foregroundStyle(.pmTextSecondary)
                    .padding(.top, -PMSpacing.md)

                ChipGrid(Equipment.allCases) { equip in
                    ToggleChip(
                        label: equip.displayName,
                        isSelected: selectedEquipment.contains(equip)
                    ) {
                        if selectedEquipment.contains(equip) { selectedEquipment.remove(equip) }
                        else { selectedEquipment.insert(equip) }
                    }
                }

                Divider().overlay(Color.pmDivider)

                // Workout days per week
                HStack {
                    Text("Workouts per week")
                        .font(.pmBodyMedium)
                        .foregroundStyle(.pmTextPrimary)
                    Spacer()
                    Stepper("\(workoutDaysPerWeek) days", value: $workoutDaysPerWeek, in: 1...7)
                        .tint(Color.pmAccentPurpleBright)
                        .font(.pmBodyMedium)
                        .foregroundStyle(.pmTextPrimary)
                }
                .padding(PMSpacing.sm)
                .background(Color.pmSurfacePrimary)
                .clipShape(RoundedRectangle(cornerRadius: PMSpacing.cardRadius))

                // Session duration
                Text("Preferred session length")
                    .font(.pmBodyMedium)
                    .foregroundStyle(.pmTextPrimary)

                HStack(spacing: PMSpacing.xs) {
                    ForEach(durationOptions, id: \.self) { minutes in
                        ToggleChip(
                            label: minutes < 90 ? "\(minutes)m" : "90m+",
                            isSelected: workoutDurationMinutes == minutes
                        ) {
                            workoutDurationMinutes = minutes
                        }
                    }
                }
            }
            .padding(.horizontal, PMSpacing.screenEdge)
            .padding(.top, PMSpacing.md)
            .padding(.bottom, PMSpacing.xl)
        }
    }
}
