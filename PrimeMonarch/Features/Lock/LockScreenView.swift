import SwiftUI

struct LockScreenView: View {
    @Environment(AppCoordinator.self) private var coordinator

    @State private var isAuthenticating = false
    @State private var errorMessage: String?

    private var biometricLabel: String {
        BiometricService.biometricType == .faceID ? "Unlock with Face ID" : "Unlock with Touch ID"
    }

    private var biometricIcon: String {
        BiometricService.biometricType == .faceID ? "faceid" : "touchid"
    }

    var body: some View {
        ZStack {
            LinearGradient.pmHeroGradient.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: PMSpacing.sm) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 60, weight: .bold))
                        .foregroundStyle(LinearGradient.pmPurpleGradient)

                    Text("PrimeMonarch")
                        .font(.pmLargeTitle)
                        .foregroundStyle(.pmTextPrimary)

                    Text("Your session is locked")
                        .font(.pmSecondaryBody)
                        .foregroundStyle(.pmTextSecondary)
                        .padding(.top, PMSpacing.xxs)
                }

                Spacer()

                VStack(spacing: PMSpacing.md) {
                    if let error = errorMessage {
                        Text(error)
                            .font(.pmCaption)
                            .foregroundStyle(.pmStatusError)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, PMSpacing.lg)
                            .transition(.opacity)
                    }

                    Button {
                        Task { await unlock() }
                    } label: {
                        HStack(spacing: PMSpacing.sm) {
                            Image(systemName: biometricIcon)
                                .font(.system(size: 20, weight: .medium))
                            Text(biometricLabel)
                                .font(.pmButtonLabel)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(LinearGradient.pmPurpleGradient)
                        .clipShape(RoundedRectangle(cornerRadius: PMSpacing.buttonRadius))
                    }
                    .disabled(isAuthenticating)
                    .padding(.horizontal, PMSpacing.screenEdge)
                }
                .padding(.bottom, PMSpacing.xxxl)
                .animation(.easeInOut(duration: 0.2), value: errorMessage)
            }
        }
        .task { await unlock() }
    }

    // MARK: - Actions

    private func unlock() async {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        errorMessage = nil
        do {
            try await BiometricService.authenticate(reason: "Unlock PrimeMonarch to access your health data")
            coordinator.handleBiometricUnlock()
        } catch BiometricError.userCancelled {
            // User dismissed the prompt — show the manual button
        } catch {
            errorMessage = "Authentication failed. Please try again."
        }
        isAuthenticating = false
    }
}
