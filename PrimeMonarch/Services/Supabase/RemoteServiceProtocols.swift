import SwiftData
import Foundation

// MARK: - Remote Sync Service Protocol
//
// This file has NO Supabase dependency — AppEnvironment and AppCoordinator
// reference only this protocol, so the app compiles even before the
// Supabase Swift package is installed.
// The concrete SupabaseSyncService (which imports Supabase) lives in
// SupabaseSyncService.swift and is wired up inside AppEnvironment.

@MainActor
protocol RemoteSyncServiceProtocol: AnyObject {
    /// Push every onboarding model (profile, goals, preferences) to remote.
    func pushFullProfile(userId: String, in context: ModelContext) async
    /// Pull the remote profile and merge it into SwiftData (returning-user sync).
    func pullAndApply(userId: String, in context: ModelContext) async
    /// Push a single profile update (e.g. after user edits profile settings).
    func pushProfile(_ profile: UserProfile, userId: String) async
    /// Push all local activity records (meals, water, weight, workouts) to remote.
    func pushActivityData(userId: String, in context: ModelContext) async
    /// Fetch all remote activity records and insert any missing ones locally (reinstall recovery).
    func pullActivityData(userId: String, in context: ModelContext) async
}

// MARK: - No-op implementation
// Used as default until the Supabase package is added and the real service is wired up.
// AppEnvironment instantiates this by default; swap it in tests or pre-integration builds.

@MainActor
final class NullRemoteSyncService: RemoteSyncServiceProtocol {
    func pushFullProfile(userId: String, in context: ModelContext) async {}
    func pullAndApply(userId: String, in context: ModelContext) async {}
    func pushProfile(_ profile: UserProfile, userId: String) async {}
    func pushActivityData(userId: String, in context: ModelContext) async {}
    func pullActivityData(userId: String, in context: ModelContext) async {}
}
