import SwiftUI

struct AppRootView: View {
    @State private var coordinator: AppCoordinator
    private let environment: AppEnvironment
    @Environment(\.scenePhase) private var scenePhase

    init(environment: AppEnvironment) {
        self.environment = environment
        _coordinator = State(initialValue: AppCoordinator(environment: environment))
    }

    var body: some View {
        Group {
            switch coordinator.phase {
            case .launching:
                LaunchView()
            case .welcome:
                WelcomeView()
                    .environment(coordinator)
            case .authentication:
                AuthView()
                    .environment(coordinator)
            case .onboarding:
                OnboardingCoordinatorView()
                    .environment(coordinator)
            case .locked:
                LockScreenView()
                    .environment(coordinator)
            case .main:
                MainTabView()
                    .environment(coordinator)
            case .storageFailure(let message):
                StorageFailureView(message: message)
            }
        }
        .environment(environment)
        .environment(environment.healthKitService)
        .task {
            await coordinator.bootstrap()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                coordinator.handleAppForeground()
            }
        }
    }
}

// MARK: - Launch Screen

struct LaunchView: View {
    var body: some View {
        ZStack {
            LinearGradient.pmHeroGradient.ignoresSafeArea()
            VStack(spacing: PMSpacing.sm) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 64, weight: .bold))
                    .foregroundStyle(LinearGradient.pmPurpleGradient)
                Text("PrimeMonarch")
                    .font(.pmLargeTitle)
                    .foregroundStyle(.pmTextPrimary)
            }
        }
    }
}

// MARK: - Storage Failure Screen

struct StorageFailureView: View {
    let message: String

    var body: some View {
        ZStack {
            Color.pmBackgroundPrimary.ignoresSafeArea()
            VStack(spacing: PMSpacing.lg) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(.pmStatusWarning)

                Text("Storage Error")
                    .font(.pmScreenTitle)
                    .foregroundStyle(.pmTextPrimary)

                Text(message)
                    .font(.pmBody)
                    .foregroundStyle(.pmTextSecondary)
                    .multilineTextAlignment(.center)

                Text("Please restart the app. If this issue persists, reinstall or contact support.")
                    .font(.pmCaption)
                    .foregroundStyle(.pmTextTertiary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, PMSpacing.screenEdge)
        }
    }
}
