import SwiftUI

struct InitialPlanStepView: View {
    let bmr: Double?
    let tdee: Double?
    let calorieTarget: Int
    let primaryGoal: GoalType
    let biologicalSex: BiologicalSex

    @State private var appeared = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PMSpacing.lg) {
                OnboardingStepHeader(
                    title: "Your plan is ready",
                    subtitle: "Here's what we calculated based on your profile"
                )

                // Rank reveal card
                rankCard
                    .scaleEffect(appeared ? 1 : 0.9)
                    .opacity(appeared ? 1 : 0)

                // Calorie target
                metricCard(
                    icon: "flame.fill",
                    iconColor: .pmRingEnergy,
                    title: "Daily calorie target",
                    value: "\(calorieTarget) kcal",
                    detail: calorieDetail
                )
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)

                // BMR / TDEE breakdown
                if let bmr, let tdee {
                    VStack(spacing: PMSpacing.xs) {
                        metricRow(label: "Basal metabolic rate (BMR)", value: "\(Int(bmr)) kcal")
                        metricRow(label: "Total daily energy (TDEE)", value: "\(Int(tdee)) kcal")
                    }
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)
                }

                // Safety disclaimer
                PMCard {
                    HStack(alignment: .top, spacing: PMSpacing.sm) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(.pmStatusWarning)
                            .font(.system(size: 16))
                            .padding(.top, 1)
                        Text("These are starting estimates. Your plan adapts as PrimeMonarch learns your patterns. Consult a healthcare professional before making major dietary changes.")
                            .font(.pmCaption)
                            .foregroundStyle(.pmTextSecondary)
                    }
                }
                .opacity(appeared ? 1 : 0)
            }
            .padding(.horizontal, PMSpacing.screenEdge)
            .padding(.top, PMSpacing.md)
            .padding(.bottom, PMSpacing.xl)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                appeared = true
            }
        }
    }

    // MARK: Subviews

    private var rankCard: some View {
        HStack(spacing: PMSpacing.md) {
            Image(systemName: "crown.fill")
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(LinearGradient.pmPurpleGradient)

            VStack(alignment: .leading, spacing: PMSpacing.xxs) {
                Text("Starting rank")
                    .font(.pmCaption)
                    .foregroundStyle(.pmTextSecondary)
                Text("Initiate  ·  Level 1")
                    .font(.pmSectionTitle)
                    .foregroundStyle(.pmTextPrimary)
                Text("Complete daily goals to earn XP and rank up")
                    .font(.pmCaption)
                    .foregroundStyle(.pmTextTertiary)
            }
            Spacer()
        }
        .padding(PMSpacing.md)
        .background(
            LinearGradient(
                colors: [Color.pmAccentPurple.opacity(0.25), Color.pmSurfacePrimary],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: PMSpacing.cardRadius))
        .overlay {
            RoundedRectangle(cornerRadius: PMSpacing.cardRadius)
                .stroke(Color.pmAccentPurple.opacity(0.4), lineWidth: 1)
        }
    }

    private func metricCard(icon: String, iconColor: Color, title: String, value: String, detail: String) -> some View {
        HStack(spacing: PMSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 44, height: 44)
                .background(iconColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: PMSpacing.xxs) {
                Text(title)
                    .font(.pmSecondaryBody)
                    .foregroundStyle(.pmTextSecondary)
                Text(value)
                    .font(.pmMetricValue)
                    .foregroundStyle(.pmTextPrimary)
                Text(detail)
                    .font(.pmCaption)
                    .foregroundStyle(.pmTextTertiary)
            }
            Spacer()
        }
        .padding(PMSpacing.md)
        .background(Color.pmSurfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: PMSpacing.cardRadius))
    }

    private func metricRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.pmSecondaryBody)
                .foregroundStyle(.pmTextSecondary)
            Spacer()
            Text(value)
                .font(.pmBodyMedium)
                .foregroundStyle(.pmTextPrimary)
        }
        .padding(.horizontal, PMSpacing.sm)
        .padding(.vertical, PMSpacing.xs)
        .background(Color.pmSurfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: PMSpacing.cardRadius))
    }

    private var calorieDetail: String {
        switch primaryGoal {
        case .loseWeight, .reduceFat: return "500 kcal deficit from TDEE · capped at safety minimum"
        case .buildMuscle: return "250 kcal surplus from TDEE for lean gaining"
        default: return "Matches your total daily energy expenditure"
        }
    }
}
