import SwiftData
import SwiftUI

struct WorkoutPreferencesView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss)      private var dismiss

    @Query private var goalProfiles: [GoalProfile]

    @State private var daysPerWeek  = 3
    @State private var durationMins = 45
    @State private var equipment: Set<Equipment> = []
    @State private var injuryNotes  = ""
    @State private var loaded       = false

    private var goalProfile: GoalProfile? { goalProfiles.first }

    private let durationOptions = [20, 30, 45, 60, 75, 90]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: PMSpacing.lg) {
                    // Days per week
                    FormSection(title: "WORKOUT DAYS PER WEEK") {
                        HStack {
                            Text("\(daysPerWeek) day\(daysPerWeek == 1 ? "" : "s")")
                                .font(.system(size: 22, weight: .heavy))
                                .foregroundStyle(.pmTextPrimary)
                            Spacer()
                            Stepper("", value: $daysPerWeek, in: 1...7)
                                .labelsHidden()
                        }
                        .padding(PMSpacing.md)
                    }

                    // Session duration
                    FormSection(title: "SESSION DURATION") {
                        HStack(spacing: PMSpacing.xs) {
                            ForEach(durationOptions, id: \.self) { mins in
                                let selected = durationMins == mins
                                Button { durationMins = mins } label: {
                                    VStack(spacing: 2) {
                                        Text("\(mins)")
                                            .font(.system(size: 15, weight: .heavy))
                                        Text("min")
                                            .font(.pmCaption)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, PMSpacing.sm)
                                    .background(selected ? Color.pmAccentPurpleBright : Color.pmPillNeutralBg)
                                    .foregroundStyle(selected ? Color.pmBackgroundPrimary : Color.pmTextPrimary)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(PMSpacing.md)
                    }

                    // Available equipment
                    FormSection(title: "AVAILABLE EQUIPMENT") {
                        VStack(spacing: 0) {
                            ForEach(Array(Equipment.allCases.enumerated()), id: \.element.id) { i, item in
                                if i > 0 { PMDivider().padding(.horizontal, PMSpacing.md) }
                                EquipmentRow(
                                    item: item,
                                    isSelected: equipment.contains(item)
                                ) {
                                    if equipment.contains(item) {
                                        equipment.remove(item)
                                    } else {
                                        equipment.insert(item)
                                    }
                                }
                            }
                        }
                    }

                    // Injury notes
                    FormSection(title: "INJURY / LIMITATION NOTES") {
                        VStack(alignment: .leading, spacing: PMSpacing.xs) {
                            TextField(
                                "e.g. Bad lower back — avoid deadlifts",
                                text: $injuryNotes,
                                axis: .vertical
                            )
                            .font(.pmBody)
                            .foregroundStyle(.pmTextPrimary)
                            .lineLimit(3...6)
                            .padding(PMSpacing.sm)
                        }
                        .padding(.horizontal, PMSpacing.xs)
                        .padding(.vertical, PMSpacing.xs)
                    }

                    Spacer().frame(height: PMSpacing.xxl)
                }
                .padding(.horizontal, PMSpacing.screenEdge)
                .padding(.top, PMSpacing.md)
            }
            .background(Color.pmBackgroundPrimary.ignoresSafeArea())
            .navigationTitle("Workout Preferences")
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

    // MARK: - Layout helpers


    // MARK: - Load / Save

    private func loadCurrentValues() {
        guard !loaded, let gp = goalProfile else { return }
        daysPerWeek  = gp.workoutDaysPerWeek
        durationMins = gp.preferredWorkoutDurationMinutes
        equipment    = Set(gp.availableEquipment)
        injuryNotes  = gp.injuryNotes
        loaded = true
    }

    private func save() {
        guard let gp = goalProfile else { return }
        gp.workoutDaysPerWeek               = daysPerWeek
        gp.preferredWorkoutDurationMinutes  = durationMins
        gp.availableEquipment               = Array(equipment)
        gp.injuryNotes                      = injuryNotes
        gp.updatedAt                        = Date()
        try? context.save()
        dismiss()
    }
}

// MARK: - Equipment Row

private struct EquipmentRow: View {
    let item: Equipment
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(item.displayName)
                    .font(.pmBodyMedium)
                    .foregroundStyle(.pmTextPrimary)
                Spacer()
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 18))
                    .foregroundStyle(isSelected ? .pmAccentPurpleBright : .pmTextSecondary)
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
