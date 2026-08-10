import SwiftData
import SwiftUI
import UIKit

struct AccountSettingsView: View {
    @Environment(\.modelContext)       private var context
    @Environment(\.dismiss)            private var dismiss
    @Environment(AppCoordinator.self)  private var coordinator
    @Environment(AppEnvironment.self)  private var environment

    @Query private var profiles: [UserProfile]
    private var profile: UserProfile? { profiles.first }

    // Existing account state
    @State private var displayName       = ""
    @State private var weightUnit        = WeightUnit.kilograms
    @State private var distanceUnit      = DistanceUnit.kilometers
    @State private var currentWeightText = ""
    @State private var loaded            = false

    // Privacy
    @AppStorage("pm_biometric_lock_enabled") private var biometricLockEnabled = false
    @AppStorage("pm_ai_workout_enabled")     private var aiWorkoutEnabled = true

    // Data actions
    @State private var isExporting            = false
    @State private var exportURL: URL?        = nil
    @State private var showExportSheet        = false
    @State private var showExportError        = false
    @State private var showClearActivityAlert = false
    @State private var showDeleteAccountAlert = false
    @State private var showUpgradeSheet       = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: PMSpacing.lg) {

                    // MARK: Display name
                    AccountSection(title: "DISPLAY NAME") {
                        PMFormField(label: "Name", text: $displayName, placeholder: "Your name")
                            .padding(PMSpacing.md)
                    }

                    // MARK: Units
                    AccountSection(title: "PREFERRED UNITS") {
                        VStack(spacing: 0) {
                            HStack {
                                Text("Weight")
                                    .font(.pmBodyMedium)
                                    .foregroundStyle(.pmTextPrimary)
                                Spacer()
                                Picker("", selection: $weightUnit) {
                                    ForEach(WeightUnit.allCases, id: \.self) {
                                        Text($0.displayName).tag($0)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 100)
                            }
                            .padding(.horizontal, PMSpacing.md)
                            .padding(.vertical, PMSpacing.sm)

                            PMDivider().padding(.horizontal, PMSpacing.md)

                            HStack {
                                Text("Distance")
                                    .font(.pmBodyMedium)
                                    .foregroundStyle(.pmTextPrimary)
                                Spacer()
                                Picker("", selection: $distanceUnit) {
                                    ForEach(DistanceUnit.allCases, id: \.self) {
                                        Text($0.displayName).tag($0)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 100)
                            }
                            .padding(.horizontal, PMSpacing.md)
                            .padding(.vertical, PMSpacing.sm)
                        }
                    }

                    // MARK: Current weight
                    AccountSection(title: "CURRENT WEIGHT") {
                        PMFormField(
                            label: "Weight (\(weightUnit.displayName))",
                            text: $currentWeightText,
                            placeholder: weightUnit == .kilograms ? "e.g. 80" : "e.g. 176",
                            isNumeric: true
                        )
                        .padding(PMSpacing.md)
                    }

                    // MARK: Account type
                    AccountSection(title: "ACCOUNT") {
                        VStack(spacing: 0) {
                            HStack {
                                Text("Account type")
                                    .font(.pmBodyMedium)
                                    .foregroundStyle(.pmTextPrimary)
                                Spacer()
                                Text(profile?.isGuest == true ? "Guest" : "Signed in")
                                    .font(.pmCaption)
                                    .foregroundStyle(.pmTextSecondary)
                            }
                            .padding(.horizontal, PMSpacing.md)
                            .padding(.vertical, PMSpacing.sm)

                            if profile?.isGuest == true {
                                PMDivider().padding(.horizontal, PMSpacing.md)
                                Button { showUpgradeSheet = true } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Create a free account")
                                                .font(.pmBodyMedium)
                                                .foregroundStyle(.pmAccentPurpleBright)
                                            Text("Sync your progress and keep it safe")
                                                .font(.pmCaption)
                                                .foregroundStyle(.pmTextSecondary)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12))
                                            .foregroundStyle(.pmTextTertiary)
                                    }
                                    .padding(.horizontal, PMSpacing.md)
                                    .padding(.vertical, PMSpacing.sm)
                                }
                            }
                        }
                    }

                    // MARK: Privacy
                    AccountSection(title: "PRIVACY") {
                        VStack(spacing: 0) {
                            if BiometricService.isAvailable {
                                Toggle(isOn: $biometricLockEnabled) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(BiometricService.biometricType == .faceID ? "Require Face ID" : "Require Touch ID")
                                            .font(.pmBodyMedium)
                                            .foregroundStyle(.pmTextPrimary)
                                        Text("Lock app when resuming from background")
                                            .font(.pmCaption)
                                            .foregroundStyle(.pmTextSecondary)
                                    }
                                }
                                .padding(.horizontal, PMSpacing.md)
                                .padding(.vertical, PMSpacing.sm)
                                .tint(.pmAccentPurple)

                                PMDivider().padding(.horizontal, PMSpacing.md)
                            }

                            Toggle(isOn: $aiWorkoutEnabled) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("AI workout suggestions")
                                        .font(.pmBodyMedium)
                                        .foregroundStyle(.pmTextPrimary)
                                    Text("Uses on-device Apple Intelligence")
                                        .font(.pmCaption)
                                        .foregroundStyle(.pmTextSecondary)
                                }
                            }
                            .padding(.horizontal, PMSpacing.md)
                            .padding(.vertical, PMSpacing.sm)
                            .tint(.pmAccentPurple)

                            PMDivider().padding(.horizontal, PMSpacing.md)

                            Button {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("HealthKit data access")
                                            .font(.pmBodyMedium)
                                            .foregroundStyle(.pmTextPrimary)
                                        Text("Manage permissions in iOS Settings")
                                            .font(.pmCaption)
                                            .foregroundStyle(.pmTextSecondary)
                                    }
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                        .font(.pmCaption)
                                        .foregroundStyle(.pmTextTertiary)
                                }
                                .padding(.horizontal, PMSpacing.md)
                                .padding(.vertical, PMSpacing.sm)
                            }
                        }
                    }

                    // MARK: Your data
                    AccountSection(title: "YOUR DATA") {
                        VStack(spacing: 0) {
                            Button {
                                exportData()
                            } label: {
                                HStack {
                                    if isExporting {
                                        ProgressView().scaleEffect(0.8).padding(.trailing, 4)
                                    }
                                    Text(isExporting ? "Preparing export…" : "Export my data")
                                        .font(.pmBodyMedium)
                                        .foregroundStyle(.pmTextPrimary)
                                    Spacer()
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.pmCaption)
                                        .foregroundStyle(.pmTextTertiary)
                                }
                                .padding(.horizontal, PMSpacing.md)
                                .padding(.vertical, PMSpacing.sm)
                            }
                            .disabled(isExporting)

                            PMDivider().padding(.horizontal, PMSpacing.md)

                            Button(role: .destructive) {
                                showClearActivityAlert = true
                            } label: {
                                HStack {
                                    Text("Clear activity data")
                                        .font(.pmBodyMedium)
                                        .foregroundStyle(.pmStatusError)
                                    Spacer()
                                    Image(systemName: "trash")
                                        .font(.pmCaption)
                                        .foregroundStyle(.pmStatusError)
                                }
                                .padding(.horizontal, PMSpacing.md)
                                .padding(.vertical, PMSpacing.sm)
                            }

                            PMDivider().padding(.horizontal, PMSpacing.md)

                            Button(role: .destructive) {
                                showDeleteAccountAlert = true
                            } label: {
                                HStack {
                                    Text("Delete account & all data")
                                        .font(.pmBodyMedium)
                                        .foregroundStyle(.pmStatusError)
                                    Spacer()
                                    Image(systemName: "person.crop.circle.badge.minus")
                                        .font(.pmCaption)
                                        .foregroundStyle(.pmStatusError)
                                }
                                .padding(.horizontal, PMSpacing.md)
                                .padding(.vertical, PMSpacing.sm)
                            }
                        }
                    }

                    // MARK: Legal
                    AccountSection(title: "LEGAL") {
                        VStack(spacing: 0) {
                            Button {
                                UIApplication.shared.open(AppLinks.privacyPolicy)
                            } label: {
                                HStack {
                                    Text("Privacy Policy")
                                        .font(.pmBodyMedium)
                                        .foregroundStyle(.pmTextPrimary)
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                        .font(.pmCaption)
                                        .foregroundStyle(.pmTextTertiary)
                                }
                                .padding(.horizontal, PMSpacing.md)
                                .padding(.vertical, PMSpacing.sm)
                            }

                            PMDivider().padding(.horizontal, PMSpacing.md)

                            Button {
                                UIApplication.shared.open(AppLinks.termsOfService)
                            } label: {
                                HStack {
                                    Text("Terms of Service")
                                        .font(.pmBodyMedium)
                                        .foregroundStyle(.pmTextPrimary)
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                        .font(.pmCaption)
                                        .foregroundStyle(.pmTextTertiary)
                                }
                                .padding(.horizontal, PMSpacing.md)
                                .padding(.vertical, PMSpacing.sm)
                            }
                        }
                    }

                    Spacer().frame(height: PMSpacing.xxl)
                }
                .padding(.horizontal, PMSpacing.screenEdge)
                .padding(.top, PMSpacing.md)
            }
            .background(Color.pmBackgroundPrimary.ignoresSafeArea())
            .navigationTitle("Account")
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
        .onChange(of: weightUnit) { _, newUnit in
            guard let kg = Double(currentWeightText) else { return }
            let asKg = (loaded && weightUnit != newUnit)
                ? (weightUnit == .kilograms ? kg : kg / 2.20462)
                : kg
            let converted = newUnit == .kilograms ? asKg : asKg * 2.20462
            currentWeightText = String(format: "%.1f", converted)
        }
        .sheet(isPresented: $showUpgradeSheet) {
            GuestUpgradeSheet()
                .environment(coordinator)
                .environment(environment)
        }
        .sheet(isPresented: $showExportSheet) {
            if let url = exportURL {
                PMShareSheet(url: url)
            }
        }
        .alert("Export failed", isPresented: $showExportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Could not prepare your data for export. Please try again.")
        }
        .confirmationDialog(
            "Clear activity data?",
            isPresented: $showClearActivityAlert,
            titleVisibility: .visible
        ) {
            Button("Clear Activity Data", role: .destructive) { clearActivityData() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Permanently deletes all meals, workouts, weight entries, water logs, measurements, and progress photos. Your profile and goal settings are kept.")
        }
        .confirmationDialog(
            "Delete account and all data?",
            isPresented: $showDeleteAccountAlert,
            titleVisibility: .visible
        ) {
            Button("Delete Everything", role: .destructive) { deleteAccount() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Permanently deletes your profile, goals, all activity history, and progress photos from this device. This cannot be undone.")
        }
    }

    // MARK: - Load / Save

    private func loadCurrentValues() {
        guard !loaded, let p = profile else { return }
        displayName  = p.displayName ?? ""
        weightUnit   = p.preferredWeightUnit
        distanceUnit = p.preferredDistanceUnit
        if let kg = p.currentWeightKilograms {
            let display = p.preferredWeightUnit == .kilograms ? kg : kg * 2.20462
            currentWeightText = String(format: "%.1f", display)
        }
        loaded = true
    }

    private func save() {
        guard let p = profile else { return }
        p.displayName           = displayName.trimmingCharacters(in: .whitespaces).isEmpty ? nil : displayName
        p.preferredWeightUnit   = weightUnit
        p.preferredDistanceUnit = distanceUnit
        if let w = Double(currentWeightText), w > 0 {
            p.currentWeightKilograms = weightUnit == .kilograms ? w : w / 2.20462
        }
        p.updatedAt = Date()
        try? context.save()
        dismiss()
    }

    // MARK: - Data Actions

    private func exportData() {
        isExporting = true
        Task {
            do {
                exportURL = try DataExportService.shared.export(from: context)
                showExportSheet = true
            } catch {
                showExportError = true
            }
            isExporting = false
        }
    }

    private func clearActivityData() {
        try? DataDeletionService.shared.deleteActivityData(in: context)
        dismiss()
    }

    private func deleteAccount() {
        try? DataDeletionService.shared.deleteAllLocalData(in: context)
        Task { await coordinator.handleSignOut() }
    }
}

// MARK: - Guest Upgrade Sheet

private struct GuestUpgradeSheet: View {
    @Environment(AppCoordinator.self)  private var coordinator
    @Environment(AppEnvironment.self)  private var environment
    @Environment(\.modelContext)       private var context
    @Environment(\.dismiss)            private var dismiss

    @State private var email            = ""
    @State private var password         = ""
    @State private var confirmPassword  = ""
    @State private var isLoading        = false
    @State private var errorMessage: String?
    @State private var confirmationSent = false
    @State private var showEmailForm    = false

    private var isFormValid: Bool {
        email.contains("@") && email.contains(".") &&
        password.count >= 6 &&
        password == confirmPassword
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: PMSpacing.lg) {
                    if confirmationSent {
                        confirmationView
                    } else {
                        upgradeOptions
                    }
                }
                .padding(.horizontal, PMSpacing.screenEdge)
                .padding(.top, PMSpacing.xl)
            }
            .background(Color.pmBackgroundPrimary.ignoresSafeArea())
            .navigationTitle("Create Account")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(.pmTextSecondary)
                }
            }
        }
    }

    private var upgradeOptions: some View {
        VStack(spacing: PMSpacing.lg) {
            // Context banner
            PMCard {
                HStack(spacing: PMSpacing.sm) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.pmStatusSuccess)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Your data stays on this device")
                            .font(.pmBodyMedium)
                            .foregroundStyle(.pmTextPrimary)
                        Text("Creating an account lets you sync and restore it if you switch devices.")
                            .font(.pmCaption)
                            .foregroundStyle(.pmTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(PMSpacing.md)
            }

            // Apple button
            Button {
                Task { await upgradeWithApple() }
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

            // Email form
            if showEmailForm {
                emailForm
            } else {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { showEmailForm = true }
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
            }

            if let error = errorMessage {
                Text(error)
                    .font(.pmCaption)
                    .foregroundStyle(.pmStatusError)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: errorMessage)
        .animation(.easeInOut(duration: 0.2), value: showEmailForm)
    }

    private var emailForm: some View {
        VStack(spacing: PMSpacing.md) {
            PMCard(elevated: true) {
                VStack(spacing: 0) {
                    PMFormField(label: "Email", text: $email, placeholder: "you@example.com")
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .padding(PMSpacing.md)

                    PMDivider().padding(.horizontal, PMSpacing.md)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Password")
                            .font(.pmCaption)
                            .foregroundStyle(.pmTextTertiary)
                        SecureField("Min. 6 characters", text: $password)
                            .textInputAutocapitalization(.never)
                            .font(.pmBody)
                            .foregroundStyle(.pmTextPrimary)
                    }
                    .padding(PMSpacing.md)

                    PMDivider().padding(.horizontal, PMSpacing.md)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Confirm Password")
                            .font(.pmCaption)
                            .foregroundStyle(.pmTextTertiary)
                        SecureField("Re-enter password", text: $confirmPassword)
                            .textInputAutocapitalization(.never)
                            .font(.pmBody)
                            .foregroundStyle(.pmTextPrimary)
                    }
                    .padding(PMSpacing.md)
                }
            }

            Button {
                Task { await upgradeWithEmail() }
            } label: {
                Group {
                    if isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text("Create Account")
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
        }
    }

    private var confirmationView: some View {
        VStack(spacing: PMSpacing.lg) {
            Image(systemName: "envelope.badge.checkmark")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(LinearGradient.pmPurpleGradient)

            VStack(spacing: PMSpacing.xs) {
                Text("Check your email")
                    .font(.pmScreenTitle)
                    .foregroundStyle(.pmTextPrimary)
                Text("We've sent a confirmation link to\n**\(email)**\n\nOnce confirmed your account is fully activated.")
                    .font(.pmBody)
                    .foregroundStyle(.pmTextSecondary)
                    .multilineTextAlignment(.center)
            }

            Button("Done") { dismiss() }
                .pmPrimaryStyle()
        }
        .padding(.top, PMSpacing.xxl)
    }

    private func upgradeWithApple() async {
        isLoading = true
        errorMessage = nil
        do {
            try await environment.authService.upgradeGuestWithApple()
            coordinator.handleGuestUpgradeComplete(in: context)
            dismiss()
        } catch AuthError.cancelled {
            // user cancelled — silent
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func upgradeWithEmail() async {
        isLoading = true
        errorMessage = nil
        do {
            let needsConfirmation = try await environment.authService.upgradeGuestWithEmail(
                email: email.trimmingCharacters(in: .whitespaces),
                password: password
            )
            if needsConfirmation {
                withAnimation { confirmationSent = true }
            } else {
                coordinator.handleGuestUpgradeComplete(in: context)
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Share Sheet

private struct PMShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Section wrapper

private struct AccountSection<Content: View>: View {
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
