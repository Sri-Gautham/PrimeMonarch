import SwiftUI

struct HealthKitExplainerStepView: View {
    @Environment(HealthKitService.self) private var healthKitService
    @State private var didRequest = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PMSpacing.lg) {
                OnboardingStepHeader(
                    title: "Connect Apple Health",
                    subtitle: "Let PrimeMonarch read your steps and active energy"
                )

                HStack {
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(Color.pmStatusError.opacity(0.12))
                            .frame(width: 100, height: 100)
                        Image(systemName: "heart.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(.pmStatusError)
                    }
                    Spacer()
                }
                .padding(.vertical, PMSpacing.md)

                Text("Apple Health lets PrimeMonarch:")
                    .font(.pmBodyMedium)
                    .foregroundStyle(.pmTextPrimary)

                VStack(alignment: .leading, spacing: PMSpacing.sm) {
                    HealthKitBenefit(icon: "figure.walk",    text: "Read step counts to track your daily movement goal")
                    HealthKitBenefit(icon: "flame.fill",     text: "Read active energy to improve workout adaptation accuracy")
                    HealthKitBenefit(icon: "lock.shield.fill", text: "Keep all data on-device — nothing is uploaded to servers")
                }

                PMCard {
                    VStack(alignment: .leading, spacing: PMSpacing.xs) {
                        Text("Why this improves your plan")
                            .font(.pmCardTitle)
                            .foregroundStyle(.pmTextPrimary)
                        Text("When PrimeMonarch sees that you've already burned extra calories walking, it can lighten your workout so you hit your daily goal without overdoing it.")
                            .font(.pmCaption)
                            .foregroundStyle(.pmTextSecondary)
                    }
                }

                if healthKitService.isAvailable {
                    Button {
                        Task {
                            await healthKitService.requestAuthorization()
                            didRequest = true
                        }
                    } label: {
                        Label(didRequest ? "Permission requested" : "Connect Apple Health",
                              systemImage: didRequest ? "checkmark.circle.fill" : "heart.fill")
                    }
                    .pmPrimaryStyle()
                    .disabled(didRequest)
                } else {
                    Text("Apple Health is not available on this device.")
                        .font(.pmCaption)
                        .foregroundStyle(.pmTextTertiary)
                }

                Text("You can change this permission at any time in Settings → Health → PrimeMonarch.")
                    .font(.pmCaption)
                    .foregroundStyle(.pmTextTertiary)
                    .multilineTextAlignment(.leading)
            }
            .padding(.horizontal, PMSpacing.screenEdge)
            .padding(.top, PMSpacing.md)
            .padding(.bottom, PMSpacing.xl)
        }
    }
}

private struct HealthKitBenefit: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: PMSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.pmAccentPurpleBright)
                .frame(width: 24)
            Text(text)
                .font(.pmBody)
                .foregroundStyle(.pmTextSecondary)
        }
    }
}
