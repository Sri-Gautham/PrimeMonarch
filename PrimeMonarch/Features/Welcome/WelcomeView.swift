import SwiftUI

struct WelcomeView: View {
    @Environment(AppCoordinator.self) private var coordinator
    @State private var animate = false

    var body: some View {
        ZStack {
            LinearGradient.pmHeroGradient.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()
                heroSection
                Spacer()
                featureHighlights
                    .padding(.horizontal, PMSpacing.screenEdge)
                    .padding(.bottom, PMSpacing.xl)
                actionButtons
                    .padding(.horizontal, PMSpacing.screenEdge)
                    .padding(.bottom, PMSpacing.md)
                legalLinks
                    .padding(.horizontal, PMSpacing.screenEdge)
                    .padding(.bottom, PMSpacing.xxxl)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
    }

    // MARK: Hero

    private var heroSection: some View {
        VStack(spacing: PMSpacing.md) {
            ZStack {
                // Glow behind crown
                Circle()
                    .fill(Color.pmAccentPurple.opacity(0.25))
                    .frame(width: 120, height: 120)
                    .blur(radius: 30)
                    .scaleEffect(animate ? 1.15 : 0.9)

                Image(systemName: "crown.fill")
                    .font(.system(size: 72, weight: .bold))
                    .foregroundStyle(LinearGradient.pmPurpleGradient)
                    .offset(y: animate ? -6 : 6)
            }
            .frame(height: 110)

            Text("PrimeMonarch")
                .font(.pmLargeTitle)
                .foregroundStyle(.pmTextPrimary)

            Text("Adaptive fitness,\nintelligently personalized")
                .font(.pmSecondaryBody)
                .foregroundStyle(.pmTextSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, PMSpacing.screenEdge)
    }

    // MARK: Feature highlights

    private var featureHighlights: some View {
        VStack(spacing: PMSpacing.xs) {
            FeatureRow(
                icon: "bolt.fill",
                iconColor: .pmRingEnergy,
                title: "Adaptive Plans",
                detail: "Workouts and nutrition that evolve with you"
            )
            FeatureRow(
                icon: "fork.knife",
                iconColor: .pmRingHydration,
                title: "Smart Tracking",
                detail: "Log meals, water, and workouts in seconds"
            )
            FeatureRow(
                icon: "crown.fill",
                iconColor: .pmRingMovement,
                title: "Rank Up",
                detail: "Earn XP and climb from Initiate to Monarch"
            )
        }
    }

    // MARK: Legal links

    private var legalLinks: some View {
        HStack(spacing: 4) {
            Link("Privacy Policy", destination: AppLinks.privacyPolicy)
            Text("·").foregroundStyle(.pmTextTertiary)
            Link("Terms of Service", destination: AppLinks.termsOfService)
        }
        .font(.pmCaption)
        .foregroundStyle(.pmTextTertiary)
        .tint(.pmAccentPurple)
    }

    // MARK: Action buttons

    private var actionButtons: some View {
        VStack(spacing: PMSpacing.sm) {
            Button("Get Started") {
                coordinator.handleWelcomeContinue()
            }
            .buttonStyle(PMPrimaryButtonStyle())

            Button("I already have an account") {
                coordinator.handleWelcomeContinue()
            }
            .buttonStyle(PMGhostButtonStyle())
        }
    }
}

// MARK: - Feature Row

private struct FeatureRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: PMSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(iconColor)
                .frame(width: 40, height: 40)
                .background(iconColor.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.pmCardTitle)
                    .foregroundStyle(.pmTextPrimary)
                Text(detail)
                    .font(.pmCaption)
                    .foregroundStyle(.pmTextSecondary)
            }
            Spacer()
        }
        .padding(PMSpacing.sm)
        .background(Color.pmSurfacePrimary.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: PMSpacing.cardRadius))
    }
}
