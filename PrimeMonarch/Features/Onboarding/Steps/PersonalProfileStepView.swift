import SwiftUI

struct PersonalProfileStepView: View {
    @Binding var dateOfBirth: Date
    @Binding var biologicalSex: BiologicalSex
    @Binding var heightCm: Double
    @Binding var weightKg: Double
    @Binding var targetWeightKg: Double?
    @Binding var weightUnit: WeightUnit

    @State private var heightText: String = ""
    @State private var weightText: String = ""
    @State private var targetWeightText: String = ""
    @State private var hasTargetWeight: Bool = false

    private var maxDOB: Date { Calendar.current.date(byAdding: .year, value: -13, to: Date()) ?? Date() }
    private var minDOB: Date { Calendar.current.date(byAdding: .year, value: -120, to: Date()) ?? Date() }

    // MARK: IBW calculations

    private var ageYears: Int? {
        Calendar.current.dateComponents([.year], from: dateOfBirth, to: Date()).year
    }

    /// Age-adjusted target BMI midpoint (WHO / NHLBI guidelines)
    private var recommendedBMI: Double {
        (ageYears ?? 30) >= 65 ? 25.0 : 22.0
    }

    /// Ideal body weight in kg using BMI method
    private var ibwKg: Double? {
        guard heightCm >= 100 else { return nil }
        let h = heightCm / 100
        return recommendedBMI * h * h
    }

    private var currentBMI: Double? {
        guard heightCm > 0, weightKg > 0 else { return nil }
        let h = heightCm / 100
        return weightKg / (h * h)
    }

    // MARK: Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PMSpacing.md) {
                OnboardingStepHeader(
                    title: "About you",
                    subtitle: "Used to calculate your personalized targets"
                )
                .padding(.bottom, PMSpacing.xs)

                // Date of birth
                OnboardingFieldRow(label: "Date of birth") {
                    DatePicker(
                        "",
                        selection: $dateOfBirth,
                        in: minDOB...maxDOB,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                    .tint(Color.pmAccentPurpleBright)
                    .labelsHidden()
                    Spacer()
                }

                // Biological sex
                OnboardingFieldRow(label: "Biological sex") {
                    Picker("Biological sex", selection: $biologicalSex) {
                        ForEach(BiologicalSex.allCases, id: \.self) { sex in
                            Text(sex.displayName).tag(sex)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Text("Used for metabolic estimation only, not for identity.")
                    .font(.pmCaption)
                    .foregroundStyle(.pmTextTertiary)
                    .padding(.top, -PMSpacing.xs)

                // Height
                OnboardingFieldRow(label: "Height") {
                    TextField("e.g. 170", text: $heightText)
                        .pmNumberPad()
                        .multilineTextAlignment(.trailing)
                        .onChange(of: heightText) { _, new in
                            if let v = Double(new), v > 0 { heightCm = v }
                        }
                    Text("cm")
                        .font(.pmBody)
                        .foregroundStyle(.pmTextSecondary)
                }

                // Current weight
                OnboardingFieldRow(label: "Current weight") {
                    TextField("0", text: $weightText)
                        .pmDecimalPad()
                        .multilineTextAlignment(.trailing)
                        .onChange(of: weightText) { _, new in
                            if let v = Double(new), v > 0 {
                                weightKg = weightUnit == .kilograms ? v : v / 2.20462
                            }
                        }
                    Picker("Unit", selection: $weightUnit) {
                        ForEach(WeightUnit.allCases, id: \.self) { u in
                            Text(u.rawValue).tag(u)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 90)
                    .onChange(of: weightUnit) { syncWeightText() }
                }

                // Target weight toggle
                Toggle("Set a target weight", isOn: $hasTargetWeight)
                    .font(.pmBodyMedium)
                    .foregroundStyle(.pmTextPrimary)
                    .tint(Color.pmAccentPurpleBright)
                    .onChange(of: hasTargetWeight) { _, on in
                        handleTargetWeightToggle(on)
                    }

                if hasTargetWeight {
                    // Label shows "suggested" badge when auto-filled from IBW
                    VStack(alignment: .leading, spacing: PMSpacing.xxs) {
                        HStack(spacing: PMSpacing.xs) {
                            Text("Target weight")
                                .font(.pmSecondaryBody)
                                .foregroundStyle(.pmTextSecondary)
                            if ibwKg != nil {
                                Text("Suggested")
                                    .font(.pmCaption)
                                    .foregroundStyle(Color.pmAccentPurpleBright)
                                    .padding(.horizontal, PMSpacing.xs)
                                    .padding(.vertical, 2)
                                    .background(Color.pmAccentPurple.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                        }
                        HStack {
                            TextField("0", text: $targetWeightText)
                                .pmDecimalPad()
                                .multilineTextAlignment(.trailing)
                                .onChange(of: targetWeightText) { _, new in
                                    if let v = Double(new), v > 0 {
                                        targetWeightKg = weightUnit == .kilograms ? v : v / 2.20462
                                    } else {
                                        targetWeightKg = nil
                                    }
                                }
                            Text(weightUnit.rawValue)
                                .font(.pmBody)
                                .foregroundStyle(.pmTextSecondary)
                        }
                        .padding(PMSpacing.sm)
                        .background(Color.pmSurfacePrimary)
                        .clipShape(RoundedRectangle(cornerRadius: PMSpacing.cardRadius))
                    }

                    // Clinical explanation card
                    if let ibw = ibwKg {
                        IBWExplanationView(
                            heightCm: heightCm,
                            weightKg: weightKg,
                            ageYears: ageYears ?? 30,
                            weightUnit: weightUnit,
                            ibwKg: ibw
                        )
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .animation(.easeInOut(duration: 0.25), value: hasTargetWeight)
                    }
                }
            }
            .padding(PMSpacing.screenEdge)
        }
        .onAppear { syncFromBindings() }
    }

    // MARK: Helpers

    private func handleTargetWeightToggle(_ isOn: Bool) {
        if isOn {
            // Pre-fill with IBW suggestion only on first activation
            if targetWeightKg == nil, let ibw = ibwKg {
                targetWeightKg = ibw
                let display = weightUnit == .kilograms ? ibw : ibw * 2.20462
                targetWeightText = String(format: "%.1f", display)
            }
        } else {
            targetWeightKg = nil
            targetWeightText = ""
        }
    }

    private func syncFromBindings() {
        heightText = heightCm > 0 ? String(format: "%.0f", heightCm) : ""
        syncWeightText()
        if targetWeightKg != nil { hasTargetWeight = true }
    }

    private func syncWeightText() {
        let display = weightUnit == .kilograms ? weightKg : weightKg * 2.20462
        weightText = String(format: "%.1f", display)
        if let tkg = targetWeightKg {
            let td = weightUnit == .kilograms ? tkg : tkg * 2.20462
            targetWeightText = String(format: "%.1f", td)
        }
    }
}

// MARK: - IBW Explanation Card

private struct IBWExplanationView: View {
    let heightCm: Double
    let weightKg: Double
    let ageYears: Int
    let weightUnit: WeightUnit
    let ibwKg: Double

    private var isOlderAdult: Bool { ageYears >= 65 }

    private var currentBMI: Double? {
        guard heightCm > 0, weightKg > 0 else { return nil }
        let h = heightCm / 100
        return weightKg / (h * h)
    }

    private var ibwBMI: Double {
        guard heightCm > 0 else { return 22.0 }
        let h = heightCm / 100
        return ibwKg / (h * h)
    }

    private var healthyBMIRange: String { isOlderAdult ? "23 – 27" : "18.5 – 24.9" }

    private var isCurrentWeightHealthy: Bool {
        guard let bmi = currentBMI else { return false }
        return isOlderAdult ? (bmi >= 23 && bmi <= 27) : (bmi >= 18.5 && bmi <= 24.9)
    }

    private var ibwDisplay: String {
        let d = weightUnit == .kilograms ? ibwKg : ibwKg * 2.20462
        return String(format: "%.1f %@", d, weightUnit.rawValue)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PMSpacing.sm) {
            // Header
            HStack(spacing: PMSpacing.xs) {
                Image(systemName: "chart.bar.doc.horizontal.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.pmAccentPurpleBright)
                Text("How this suggestion was calculated")
                    .font(.pmCardTitle)
                    .foregroundStyle(.pmTextPrimary)
            }

            // Stats
            VStack(spacing: 6) {
                if let bmi = currentBMI {
                    statRow(
                        label: "Your current BMI",
                        value: String(format: "%.1f", bmi),
                        badge: bmiCategory(bmi)
                    )
                }
                statRow(label: "Healthy BMI range (age \(ageYears))", value: healthyBMIRange, badge: nil)
                statRow(label: "Suggested target BMI", value: String(format: "%.1f", ibwBMI), badge: nil)
                statRow(label: "Estimated ideal weight", value: ibwDisplay, badge: nil)
            }
            .padding(.vertical, PMSpacing.xxs)

            // Already healthy note
            if isCurrentWeightHealthy {
                HStack(alignment: .top, spacing: PMSpacing.xs) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.pmStatusSuccess)
                        .font(.system(size: 13))
                        .padding(.top, 1)
                    Text("Your current weight is already within the healthy range for your age group. The suggestion reflects the BMI midpoint as a maintenance reference.")
                        .font(.pmCaption)
                        .foregroundStyle(.pmTextSecondary)
                }
                .padding(.vertical, PMSpacing.xxs)
            }

            Divider().overlay(Color.pmDivider)

            // Clinical explanation
            Text(clinicalNote)
                .font(.pmCaption)
                .foregroundStyle(.pmTextSecondary)
                .fixedSize(horizontal: false, vertical: true)

            // Reference + disclaimer
            VStack(alignment: .leading, spacing: PMSpacing.xxs) {
                Text("Reference: WHO BMI classification · \(isOlderAdult ? "NHLBI older adult guidelines" : "Standard adult population norms")")
                    .font(.pmCaption)
                    .foregroundStyle(.pmTextTertiary)
                Text("Consult a healthcare professional before making significant weight changes.")
                    .font(.pmCaption)
                    .foregroundStyle(.pmTextTertiary)
                    .italic()
            }
        }
        .padding(PMSpacing.md)
        .background(Color.pmAccentPurple.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: PMSpacing.cardRadius))
        .overlay {
            RoundedRectangle(cornerRadius: PMSpacing.cardRadius)
                .stroke(Color.pmAccentPurple.opacity(0.25), lineWidth: 1)
        }
    }

    // MARK: Private helpers

    @ViewBuilder
    private func statRow(label: String, value: String, badge: String?) -> some View {
        HStack(alignment: .center) {
            Text(label)
                .font(.pmCaption)
                .foregroundStyle(.pmTextSecondary)
            Spacer(minLength: PMSpacing.xs)
            if let badge {
                Text(badge)
                    .font(.pmCaption)
                    .foregroundStyle(badgeColor(badge))
                    .padding(.trailing, PMSpacing.xxs)
            }
            Text(value)
                .font(.pmCaptionMedium)
                .foregroundStyle(.pmTextPrimary)
        }
    }

    private func bmiCategory(_ bmi: Double) -> String {
        if isOlderAdult {
            if bmi < 23 { return "below range" }
            if bmi > 27 { return "above range" }
            return "in range"
        } else {
            if bmi < 18.5 { return "underweight" }
            if bmi < 25.0 { return "healthy" }
            if bmi < 30.0 { return "overweight" }
            return "obese"
        }
    }

    private func badgeColor(_ badge: String) -> Color {
        switch badge {
        case "healthy", "in range": return .pmStatusSuccess
        case "underweight", "below range", "overweight", "above range": return .pmStatusWarning
        default: return .pmStatusError
        }
    }

    private var clinicalNote: String {
        if isOlderAdult {
            return "For adults aged 65+, evidence shows that a slightly higher BMI (23–27) is associated with better survival and reduced frailty risk. Modest weight reserves protect against nutrient deficits and complications during illness or recovery. The suggested target uses BMI 25 — the midpoint of this age-specific healthy range."
        } else {
            return "The World Health Organization classifies a healthy BMI as 18.5–24.9 for adults under 65. A target BMI of 22 — the range midpoint — is used as a balanced default.\n\nImportant: BMI is a population-level screening metric. It does not account for muscle mass, bone density, body composition, or ethnicity-specific norms. Athletes and individuals with high muscle mass often have elevated BMI without excess fat."
        }
    }
}
