import SwiftUI
import SwiftData
import Supabase

@main
struct PrimeMonarchApp: App {

    @State private var appEnvironment: AppEnvironment?
    @State private var storageError: String?

    var body: some Scene {
        WindowGroup {
            Group {
                if let env = appEnvironment {
                    AppRootView(environment: env)
                        .modelContainer(env.modelContainer)
                } else if let message = storageError {
                    StorageFailureView(message: message)
                } else {
                    LaunchView()
                }
            }
            .task(id: "bootstrap", priority: .userInitiated) {
                guard appEnvironment == nil && storageError == nil else { return }
                initializeStorage()
            }
            .onOpenURL { url in
                // Handles Supabase email-confirmation and magic-link deep links.
                // iOS opens the app with the primemonarch:// URL after the user taps
                // the link in their email. session(from:) extracts the tokens from the
                // URL fragment/query, persists the Supabase session to Keychain, then
                // checkExistingSession() updates the in-memory AuthSession so the UI
                // transitions from "awaiting confirmation" to "signed in".
                Task {
                    do {
                        try await SupabaseClient.shared.auth.session(from: url)
                    } catch {
                        // URL was not a valid Supabase auth callback — safe to ignore.
                        return
                    }
                    await appEnvironment?.authService.checkExistingSession()
                }
            }
        }
    }

    @MainActor
    private func initializeStorage() {
        do {
            let container = try makeContainer()
            appEnvironment = AppEnvironment(modelContainer: container)
        } catch {
#if DEBUG
            // Schema changed during development — wipe the local store and retry.
            // Production builds surface the error screen instead.
            Self.deleteLocalSwiftDataStore()
            do {
                let container = try makeContainer()
                appEnvironment = AppEnvironment(modelContainer: container)
            } catch let retryError {
                storageError = "The app database could not be opened.\n\n\(retryError.localizedDescription)"
            }
#else
            storageError = "The app database could not be opened.\n\n\(error.localizedDescription)"
#endif
        }
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(PrimeMonarchSchemaV1.models)
        // cloudKitDatabase: .none — health/fitness data must not sync to CloudKit per App Store Guidelines
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )
        return try ModelContainer(
            for: schema,
            migrationPlan: PrimeMonarchMigrationPlan.self,
            configurations: [config]
        )
    }

#if DEBUG
    private static func deleteLocalSwiftDataStore() {
        guard let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first else { return }
        let fm = FileManager.default
        // SwiftData writes default.store, default.store-wal, default.store-shm
        for suffix in ["", "-wal", "-shm"] {
            let url = appSupport.appendingPathComponent("default.store\(suffix)")
            try? fm.removeItem(at: url)
        }
    }
#endif
}
