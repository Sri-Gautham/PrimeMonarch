import SwiftUI

struct EmailAuthView: View {
    @Environment(AppCoordinator.self)  private var coordinator
    @Environment(AppEnvironment.self)  private var environment
    @Environment(\.dismiss)            private var dismiss

    @State private var isSignUp        = false
    @State private var email           = ""
    @State private var password        = ""
    @State private var confirmPassword = ""
    @State private var isLoading       = false
    @State private var errorMessage: String?
    @State private var confirmationSent = false

    private var isFormValid: Bool {
        let emailOK = email.contains("@") && email.contains(".")
        let passwordOK = password.count >= 6
        let confirmOK = !isSignUp || password == confirmPassword
        return emailOK && passwordOK && confirmOK
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: PMSpacing.lg) {
                    if confirmationSent {
                        confirmationView
                    } else {
                        formView
                    }
                }
                .padding(.horizontal, PMSpacing.screenEdge)
                .padding(.top, PMSpacing.xl)
            }
            .background(Color.pmBackgroundPrimary.ignoresSafeArea())
            .navigationTitle(isSignUp ? "Create Account" : "Sign In")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.pmTextSecondary)
                }
            }
        }
    }

    // MARK: - Form

    private var formView: some View {
        VStack(spacing: PMSpacing.lg) {
            // Fields
            PMCard(elevated: true) {
                VStack(spacing: 0) {
                    PMFormField(label: "Email", text: $email, placeholder: "you@example.com")
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .padding(PMSpacing.md)

                    PMDivider().padding(.horizontal, PMSpacing.md)

                    SecureFormField(label: "Password", text: $password, placeholder: "Min. 6 characters")
                        .padding(PMSpacing.md)

                    if isSignUp {
                        PMDivider().padding(.horizontal, PMSpacing.md)
                        SecureFormField(label: "Confirm Password", text: $confirmPassword, placeholder: "Re-enter password")
                            .padding(PMSpacing.md)
                    }
                }
            }

            // Error
            if let error = errorMessage {
                Text(error)
                    .font(.pmCaption)
                    .foregroundStyle(.pmStatusError)
                    .multilineTextAlignment(.center)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Submit button
            Button {
                Task { await submit() }
            } label: {
                Group {
                    if isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text(isSignUp ? "Create Account" : "Sign In")
                            .font(.pmButtonLabel)
                            .foregroundStyle(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(isFormValid ? LinearGradient.pmPurpleGradient : LinearGradient(colors: [Color.pmSurfaceElevated], startPoint: .leading, endPoint: .trailing))
                .clipShape(RoundedRectangle(cornerRadius: PMSpacing.buttonRadius))
            }
            .disabled(!isFormValid || isLoading)

            // Toggle mode
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isSignUp.toggle()
                    errorMessage = nil
                    confirmPassword = ""
                }
            } label: {
                Text(isSignUp ? "Already have an account? Sign in" : "New here? Create an account")
                    .font(.pmCaption)
                    .foregroundStyle(.pmAccentPurple)
            }

            Text("Your data stays on your device and is never sold.")
                .font(.pmCaption)
                .foregroundStyle(.pmTextTertiary)
                .multilineTextAlignment(.center)
        }
        .animation(.easeInOut(duration: 0.2), value: errorMessage)
        .animation(.easeInOut(duration: 0.2), value: isSignUp)
    }

    // MARK: - Confirmation state

    private var confirmationView: some View {
        VStack(spacing: PMSpacing.lg) {
            Image(systemName: "envelope.badge.checkmark")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(LinearGradient.pmPurpleGradient)

            VStack(spacing: PMSpacing.xs) {
                Text("Check your email")
                    .font(.pmScreenTitle)
                    .foregroundStyle(.pmTextPrimary)

                Text("We've sent a confirmation link to\n**\(email)**\n\nClick the link to activate your account, then come back and sign in.")
                    .font(.pmBody)
                    .foregroundStyle(.pmTextSecondary)
                    .multilineTextAlignment(.center)
            }

            Button("Back to Sign In") {
                withAnimation {
                    confirmationSent = false
                    isSignUp = false
                    password = ""
                    confirmPassword = ""
                }
            }
            .buttonStyle(PMSecondaryButtonStyle())
        }
        .padding(.top, PMSpacing.xxl)
    }

    // MARK: - Actions

    private func submit() async {
        isLoading = true
        errorMessage = nil
        do {
            if isSignUp {
                let needsConfirmation = try await environment.authService.signUpWithEmail(
                    email: email.trimmingCharacters(in: .whitespaces),
                    password: password
                )
                if needsConfirmation {
                    withAnimation { confirmationSent = true }
                } else {
                    await coordinator.handleAuthComplete()
                    dismiss()
                }
            } else {
                try await environment.authService.signInWithEmail(
                    email: email.trimmingCharacters(in: .whitespaces),
                    password: password
                )
                await coordinator.handleAuthComplete()
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Secure field helper

private struct SecureFormField: View {
    let label: String
    @Binding var text: String
    let placeholder: String

    @State private var isVisible = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.pmCaption)
                    .foregroundStyle(.pmTextTertiary)
                Group {
                    if isVisible {
                        TextField(placeholder, text: $text)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    } else {
                        SecureField(placeholder, text: $text)
                            .textInputAutocapitalization(.never)
                    }
                }
                .font(.pmBody)
                .foregroundStyle(.pmTextPrimary)
            }
            Spacer()
            Button {
                isVisible.toggle()
            } label: {
                Image(systemName: isVisible ? "eye.slash" : "eye")
                    .font(.pmCaption)
                    .foregroundStyle(.pmTextTertiary)
            }
        }
    }
}
