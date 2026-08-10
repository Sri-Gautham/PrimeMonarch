import SwiftUI

struct AuthView: View {
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(AppEnvironment.self) private var environment

    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showEmailAuth = false

    var body: some View {
        ZStack {
            Color.pmBackgroundPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                navigationBar
                Spacer()
                headerSection
                Spacer()
                authButtons
            }
        }
        .overlay {
            if isLoading {
                ZStack {
                    Color.black.opacity(0.5).ignoresSafeArea()
                    ProgressView()
                        .tint(Color.pmAccentPurpleBright)
                        .scaleEffect(1.4)
                }
            }
        }
    }

    // MARK: Navigation bar

    private var navigationBar: some View {
        HStack {
            Button {
                coordinator.handleBackToWelcome()
            } label: {
                HStack(spacing: PMSpacing.xxs) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Back")
                        .font(.pmBodyMedium)
                }
                .foregroundStyle(.pmTextSecondary)
                .padding(PMSpacing.sm)
                .contentShape(Rectangle())
            }
            Spacer()
        }
        .padding(.horizontal, PMSpacing.xs)
        .padding(.top, PMSpacing.xs)
    }

    // MARK: Header

    private var headerSection: some View {
        VStack(spacing: PMSpacing.sm) {
            Image(systemName: "crown.fill")
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(LinearGradient.pmPurpleGradient)
                .padding(.bottom, PMSpacing.xs)

            Text("Get started")
                .font(.pmScreenTitle)
                .foregroundStyle(.pmTextPrimary)

            Text("Choose how you'd like to continue")
                .font(.pmSecondaryBody)
                .foregroundStyle(.pmTextSecondary)
        }
        .padding(.horizontal, PMSpacing.screenEdge)
    }

    // MARK: Auth buttons

    private var authButtons: some View {
        VStack(spacing: PMSpacing.sm) {
            if let error = errorMessage {
                Text(error)
                    .font(.pmCaption)
                    .foregroundStyle(.pmStatusError)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, PMSpacing.md)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Sign in with Apple
            Button {
                Task { await signInWithApple() }
            } label: {
                HStack(spacing: PMSpacing.sm) {
                    Image(systemName: "apple.logo")
                        .font(.system(size: 18, weight: .medium))
                    Text("Continue with Apple")
                        .font(.pmButtonLabel)
                }
                .foregroundStyle(.pmTextPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.pmSurfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: PMSpacing.buttonRadius))
                .overlay {
                    RoundedRectangle(cornerRadius: PMSpacing.buttonRadius)
                        .stroke(Color.pmDivider, lineWidth: 1)
                }
            }
            .disabled(isLoading)

            // Sign in / up with Email
            Button {
                showEmailAuth = true
            } label: {
                HStack(spacing: PMSpacing.sm) {
                    Image(systemName: "envelope")
                        .font(.system(size: 16, weight: .medium))
                    Text("Continue with Email")
                        .font(.pmButtonLabel)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(LinearGradient.pmPurpleGradient)
                .clipShape(RoundedRectangle(cornerRadius: PMSpacing.buttonRadius))
            }
            .disabled(isLoading)

            Button("Continue as Guest") {
                Task { await continueAsGuest() }
            }
            .buttonStyle(PMSecondaryButtonStyle())
            .disabled(isLoading)

            Text(legalFooterText)
                .font(.pmCaption)
                .foregroundStyle(.pmTextTertiary)
                .tint(.pmAccentPurple)
                .multilineTextAlignment(.center)
                .padding(.horizontal, PMSpacing.lg)
                .padding(.top, PMSpacing.xxs)
        }
        .padding(.horizontal, PMSpacing.screenEdge)
        .padding(.bottom, PMSpacing.xxxl)
        .animation(.easeInOut(duration: 0.2), value: errorMessage)
        .sheet(isPresented: $showEmailAuth) {
            EmailAuthView()
                .environment(coordinator)
                .environment(environment)
        }
    }

    // MARK: Legal footer

    private var legalFooterText: AttributedString {
        let terms   = AppLinks.termsOfService.absoluteString
        let privacy = AppLinks.privacyPolicy.absoluteString
        return (try? AttributedString(markdown:
            "By continuing, you agree to our [Terms of Service](\(terms)) and [Privacy Policy](\(privacy))."))
            ?? AttributedString("By continuing, you agree to our Terms of Service and Privacy Policy.")
    }

    // MARK: Actions

    private func signInWithApple() async {
        isLoading = true
        errorMessage = nil
        do {
            try await environment.authService.signInWithApple()
            await coordinator.handleAuthComplete()
        } catch AuthError.cancelled {
            // Silent — user tapped cancel in the system sheet
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func continueAsGuest() async {
        isLoading = true
        await environment.authService.continueAsGuest()
        await coordinator.handleAuthComplete()
        isLoading = false
    }
}
