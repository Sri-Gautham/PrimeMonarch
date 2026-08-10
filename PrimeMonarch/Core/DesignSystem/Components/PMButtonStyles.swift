import SwiftUI

// MARK: - Primary Button

struct PMPrimaryButtonStyle: ButtonStyle {
    var isFullWidth: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.pmButtonLabel)
            .foregroundStyle(Color.pmBackgroundPrimary)
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .frame(height: 48)
            .padding(.horizontal, isFullWidth ? 0 : PMSpacing.lg)
            .background(
                Capsule()
                    .fill(LinearGradient.pmPurpleGradient)
                    .opacity(configuration.isPressed ? 0.80 : 1.0)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Secondary Button

struct PMSecondaryButtonStyle: ButtonStyle {
    var isFullWidth: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.pmButtonLabel)
            .foregroundStyle(.pmAccentPurpleBright)
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .frame(height: 48)
            .padding(.horizontal, isFullWidth ? 0 : PMSpacing.lg)
            .background(
                Capsule()
                    .stroke(Color.pmAccentPurple.opacity(0.5), lineWidth: 1.5)
                    .background(
                        Color.pmSurfacePrimary
                            .opacity(configuration.isPressed ? 0.6 : 1.0)
                            .clipShape(Capsule())
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Ghost Button

struct PMGhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.pmBodyMedium)
            .foregroundStyle(Color.pmTextSecondary.opacity(configuration.isPressed ? 0.5 : 1.0))
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Convenience extensions

extension Button {
    func pmPrimaryStyle(fullWidth: Bool = true) -> some View {
        self.buttonStyle(PMPrimaryButtonStyle(isFullWidth: fullWidth))
    }

    func pmSecondaryStyle(fullWidth: Bool = true) -> some View {
        self.buttonStyle(PMSecondaryButtonStyle(isFullWidth: fullWidth))
    }

    func pmGhostStyle() -> some View {
        self.buttonStyle(PMGhostButtonStyle())
    }
}
