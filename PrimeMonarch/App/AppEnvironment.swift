import SwiftData
import Foundation

@Observable @MainActor
final class AppEnvironment {
    let modelContainer: ModelContainer
    let authService: any AuthenticationServiceProtocol
    let profileRepository: any ProfileRepositoryProtocol
    /// Remote sync service. Defaults to SupabaseSyncService.
    /// Inject NullRemoteSyncService in tests or pre-Supabase builds.
    let syncService: any RemoteSyncServiceProtocol
    let healthKitService: HealthKitService

    init(
        modelContainer: ModelContainer,
        authService: (any AuthenticationServiceProtocol)? = nil,
        profileRepository: (any ProfileRepositoryProtocol)? = nil,
        syncService: (any RemoteSyncServiceProtocol)? = nil,
        healthKitService: HealthKitService? = nil
    ) {
        self.modelContainer    = modelContainer
        self.authService       = authService       ?? AuthenticationService()
        self.profileRepository = profileRepository ?? ProfileRepository()
        self.syncService       = syncService       ?? SupabaseSyncService()
        self.healthKitService  = healthKitService  ?? HealthKitService()
    }
}
