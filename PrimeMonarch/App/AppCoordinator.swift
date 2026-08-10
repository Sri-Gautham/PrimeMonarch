import SwiftData
import Foundation

@Observable @MainActor
final class AppCoordinator {

    var phase: AppPhase = .launching

    private let environment: AppEnvironment

    init(environment: AppEnvironment) {
        self.environment = environment
    }

    // MARK: Startup

    func bootstrap() async {
        await environment.authService.checkExistingSession()

        guard environment.authService.session.isAuthenticated else {
            phase = .welcome
            return
        }

        await resolvePostAuthPhase()
    }

    // MARK: Transitions

    func handleWelcomeContinue() {
        phase = .authentication
    }

    func handleBackToWelcome() {
        phase = .welcome
    }

    func handleAuthComplete() async {
        await resolvePostAuthPhase()

        // Pull the remote profile so returning users pick up their last state.
        // Must happen AFTER resolvePostAuthPhase so the local profile row exists.
        if let userId = environment.authService.session.supabaseUserId {
            let context = ModelContext(environment.modelContainer)
            await environment.syncService.pullAndApply(userId: userId, in: context)
            // Re-resolve in case onboarding status changed remotely
            await resolvePostAuthPhase()
            // Restore activity history in the background (reinstall recovery), then push
            // any local-only records that weren't synced yet.
            Task {
                await environment.syncService.pullActivityData(userId: userId, in: context)
                await environment.syncService.pushActivityData(userId: userId, in: context)
            }
        }
    }

    func handleOnboardingComplete() {
        phase = .main
        seedDailyTarget()

        // Push the full onboarding result + any early activity to Supabase in the background.
        if let userId = environment.authService.session.supabaseUserId {
            let context = ModelContext(environment.modelContainer)
            Task {
                await environment.syncService.pushFullProfile(userId: userId, in: context)
                await environment.syncService.pushActivityData(userId: userId, in: context)
            }
        }
    }

    func handleSignOut() async {
        await environment.authService.signOut()
        phase = .welcome
    }

    /// Called after a successful guest → full-account upgrade.
    /// Updates the local profile and pushes it to Supabase.
    func handleGuestUpgradeComplete(in context: ModelContext) {
        do {
            if let profile = try environment.profileRepository.fetchProfile(in: context) {
                profile.isGuest = false
                try context.save()
            }
        } catch {}
        if let userId = environment.authService.session.supabaseUserId {
            Task {
                await environment.syncService.pushFullProfile(userId: userId, in: context)
            }
        }
    }

    func handleBiometricUnlock() {
        phase = .main
        seedDailyTarget()
        refreshHealthKit()
    }

    /// Called when the app returns to the foreground — refreshes HealthKit metrics,
    /// fires a rate-limited activity sync, and re-locks if biometric lock is enabled.
    func handleAppForeground() {
        guard phase == .main else { return }
        refreshHealthKit()
        syncActivityIfNeeded()
        if shouldLock() {
            phase = .locked
        }
    }

    // MARK: Private

    private func resolvePostAuthPhase() async {
        let context = ModelContext(environment.modelContainer)
        do {
            let profile = try environment.profileRepository.fetchProfile(in: context)
            if profile?.onboardingCompleted == true {
                if shouldLock() {
                    phase = .locked
                    // seedDailyTarget() is deferred to handleBiometricUnlock()
                } else {
                    phase = .main
                    seedDailyTarget()
                }
            } else {
                phase = .onboarding
            }
        } catch {
            phase = .onboarding
        }
    }

    private func shouldLock() -> Bool {
        UserDefaults.standard.bool(forKey: "pm_biometric_lock_enabled") && BiometricService.isAvailable
    }

    /// Rolls up yesterday, ensures today's target, and seeds progression rows.
    /// Uses a fresh ModelContext so the inserts are independent of any view context.
    func seedDailyTarget() {
        let context = ModelContext(environment.modelContainer)
        DailySummaryService.rollupYesterday(in: context)
        DailyTargetService.ensureTodayTarget(in: context)
        StreakService.ensureLoggingStreak(in: context)
        XPLedgerService.ensureLedger(in: context)
        AchievementService.evaluate(in: context)
        NotificationService.shared.rescheduleFromContext(context)
        Task { await NotificationService.shared.requestAuthorizationIfNeeded() }
    }

    private func refreshHealthKit() {
        let context = ModelContext(environment.modelContainer)
        Task {
            await environment.healthKitService.refreshTodayMetrics(in: context)
        }
    }

    // Pushes activity data at most once every 4 hours; skips for guest sessions.
    private func syncActivityIfNeeded() {
        guard let userId = environment.authService.session.supabaseUserId,
              !environment.authService.session.isGuest else { return }
        let lastSync = UserDefaults.standard.double(forKey: "pm_last_activity_sync")
        let hoursSinceLast = (Date().timeIntervalSince1970 - lastSync) / 3600
        guard hoursSinceLast >= 4 else { return }
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "pm_last_activity_sync")
        let context = ModelContext(environment.modelContainer)
        Task {
            await environment.syncService.pushActivityData(userId: userId, in: context)
        }
    }
}
