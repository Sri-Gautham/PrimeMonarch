import SwiftUI

struct ScheduleStepView: View {
    @Binding var wakeDate: Date
    @Binding var sleepDate: Date
    @Binding var workoutDate: Date
    @Binding var selectedWorkdays: Set<Int>

    // Day abbreviations: 0=Sun … 6=Sat
    private let dayLabels = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PMSpacing.lg) {
                OnboardingStepHeader(
                    title: "Your daily routine",
                    subtitle: "Helps schedule reminders and workout windows"
                )

                // Time pickers
                Group {
                    timeRow(label: "Wake up time", selection: $wakeDate)
                    timeRow(label: "Bedtime", selection: $sleepDate)
                    timeRow(label: "Preferred workout time", selection: $workoutDate)
                }

                Divider().overlay(Color.pmDivider)

                // Work / busy days
                Text("Work days")
                    .font(.pmSectionTitle)
                    .foregroundStyle(.pmTextPrimary)

                Text("Days when your schedule is tighter")
                    .font(.pmSecondaryBody)
                    .foregroundStyle(.pmTextSecondary)
                    .padding(.top, -PMSpacing.md)

                HStack(spacing: PMSpacing.xs) {
                    ForEach(0..<7, id: \.self) { day in
                        let isOn = selectedWorkdays.contains(day)
                        Button {
                            if isOn { selectedWorkdays.remove(day) }
                            else { selectedWorkdays.insert(day) }
                        } label: {
                            Text(dayLabels[day])
                                .font(.pmCaptionMedium)
                                .foregroundStyle(isOn ? Color.pmAccentPurpleBright : Color.pmTextSecondary)
                                .frame(width: 38, height: 38)
                                .background(isOn ? Color.pmAccentPurple.opacity(0.18) : Color.pmSurfacePrimary)
                                .clipShape(Circle())
                                .overlay {
                                    Circle().stroke(isOn ? Color.pmAccentPurple : Color.clear, lineWidth: 1)
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(fullDayName(day))
                        .accessibilityAddTraits(isOn ? .isSelected : [])
                    }
                }
            }
            .padding(.horizontal, PMSpacing.screenEdge)
            .padding(.top, PMSpacing.md)
            .padding(.bottom, PMSpacing.xl)
        }
    }

    @ViewBuilder
    private func timeRow(label: String, selection: Binding<Date>) -> some View {
        HStack {
            Text(label)
                .font(.pmBodyMedium)
                .foregroundStyle(.pmTextPrimary)
            Spacer()
            DatePicker("", selection: selection, displayedComponents: .hourAndMinute)
                .datePickerStyle(.compact)
                .tint(Color.pmAccentPurpleBright)
                .labelsHidden()
        }
        .padding(PMSpacing.sm)
        .background(Color.pmSurfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: PMSpacing.cardRadius))
    }

    private func fullDayName(_ index: Int) -> String {
        let symbols = Calendar.current.weekdaySymbols
        return index < symbols.count ? symbols[index] : "\(index)"
    }
}
