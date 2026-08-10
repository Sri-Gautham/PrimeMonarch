// SPM dependency required:
//   https://github.com/supabase/supabase-swift  (version 2.x.x)
//   Add "Supabase" library to the PrimeMonarch target.

import Supabase
import SwiftData
import Foundation

// MARK: - Sync Service

/// Implements RemoteSyncServiceProtocol using the Supabase Swift SDK.
/// All operations are fire-and-log — a network failure never surfaces to the user
/// because SwiftData is always the local source of truth.
@Observable @MainActor
final class SupabaseSyncService: RemoteSyncServiceProtocol {

    private let client: SupabaseClient

    // Nil means "use the shared singleton" — the resolution happens inside the
    // @MainActor init body, avoiding the default-parameter nonisolated-access warning.
    init(client: SupabaseClient? = nil) {
        self.client = client ?? .shared
    }

    // MARK: RemoteSyncServiceProtocol

    func pushFullProfile(userId: String, in context: ModelContext) async {
        // Fetch all models synchronously on the main actor, then push sequentially.
        // async let across non-Sendable ModelContext/PersistentModel is unsafe; the
        // push methods are @MainActor anyway so there is no real parallelism to lose.
        if let p  = try? context.fetch(FetchDescriptor<UserProfile>()).first  { await pushProfile(p, userId: userId) }
        if let g  = try? context.fetch(FetchDescriptor<GoalProfile>()).first  { await pushGoalProfile(g, userId: userId) }
        if let pr = try? context.fetch(FetchDescriptor<UserPreference>()).first { await pushPreferences(pr, userId: userId) }
    }

    func pullAndApply(userId: String, in context: ModelContext) async {
        guard let dto = await fetchProfileDTO(userId: userId) else { return }
        guard let profile = try? context.fetch(FetchDescriptor<UserProfile>()).first else { return }
        applyProfileDTO(dto, to: profile)
        profile.supabaseUserId = userId
        try? context.save()
    }

    // MARK: Activity sync

    func pushActivityData(userId: String, in context: ModelContext) async {
        let meals   = (try? context.fetch(FetchDescriptor<MealEntry>())) ?? []
        let water   = (try? context.fetch(FetchDescriptor<WaterEntry>())) ?? []
        let weights = (try? context.fetch(FetchDescriptor<WeightEntry>())) ?? []
        let completedTrue = true
        let sessions = (try? context.fetch(FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.isCompleted == completedTrue }
        ))) ?? []

        await batchUpsert(meals.map    { MealEntryDTO(from: $0, userId: userId) },    table: SupabaseConfig.Tables.mealEntries)
        await batchUpsert(water.map    { WaterEntryDTO(from: $0, userId: userId) },   table: SupabaseConfig.Tables.waterEntries)
        await batchUpsert(weights.map  { WeightEntryDTO(from: $0, userId: userId) },  table: SupabaseConfig.Tables.weightEntries)
        await batchUpsert(sessions.map { WorkoutSessionDTO(from: $0, userId: userId) }, table: SupabaseConfig.Tables.workoutSessions)
    }

    func pullActivityData(userId: String, in context: ModelContext) async {
        let existingMealIds    = Set((try? context.fetch(FetchDescriptor<MealEntry>()))?.map(\.id.uuidString)      ?? [])
        let existingWaterIds   = Set((try? context.fetch(FetchDescriptor<WaterEntry>()))?.map(\.id.uuidString)     ?? [])
        let existingWeightIds  = Set((try? context.fetch(FetchDescriptor<WeightEntry>()))?.map(\.id.uuidString)    ?? [])
        let existingWorkoutIds = Set((try? context.fetch(FetchDescriptor<WorkoutSession>()))?.map(\.id.uuidString) ?? [])

        await applyRemoteMeals(userId: userId, existingIds: existingMealIds, in: context)
        await applyRemoteWater(userId: userId, existingIds: existingWaterIds, in: context)
        await applyRemoteWeights(userId: userId, existingIds: existingWeightIds, in: context)
        await applyRemoteWorkouts(userId: userId, existingIds: existingWorkoutIds, in: context)
    }

    func pushProfile(_ profile: UserProfile, userId: String) async {
        let dto = UserProfileDTO(from: profile, userId: userId)
        do {
            try await client
                .from(SupabaseConfig.Tables.userProfiles)
                .upsert(dto)
                .execute()
        } catch {
            print("[Supabase] Profile push failed: \(error.localizedDescription)")
        }
    }

    // MARK: Internal push helpers

    private func pushGoalProfile(_ goals: GoalProfile, userId: String) async {
        let dto = GoalProfileDTO(from: goals, userId: userId)
        do {
            try await client
                .from(SupabaseConfig.Tables.goalProfiles)
                .upsert(dto, onConflict: "user_id")
                .execute()
        } catch {
            print("[Supabase] Goal profile push failed: \(error.localizedDescription)")
        }
    }

    private func pushPreferences(_ prefs: UserPreference, userId: String) async {
        let dto = UserPreferenceDTO(from: prefs, userId: userId)
        do {
            try await client
                .from(SupabaseConfig.Tables.userPreferences)
                .upsert(dto, onConflict: "user_id")
                .execute()
        } catch {
            print("[Supabase] Preferences push failed: \(error.localizedDescription)")
        }
    }

    // MARK: Fetch

    private func fetchProfileDTO(userId: String) async -> UserProfileDTO? {
        do {
            let results: [UserProfileDTO] = try await client
                .from(SupabaseConfig.Tables.userProfiles)
                .select()
                .eq("id", value: userId)
                .limit(1)
                .execute()
                .value
            return results.first
        } catch {
            print("[Supabase] Profile fetch failed: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: Batch upsert helper

    private func batchUpsert<T: Encodable>(_ items: [T], table: String) async {
        guard !items.isEmpty else { return }
        do {
            try await client.from(table).upsert(items, onConflict: "id").execute()
        } catch {
            print("[Supabase] Upsert to \(table) failed: \(error.localizedDescription)")
        }
    }

    // MARK: Remote pull helpers

    private func applyRemoteMeals(userId: String, existingIds: Set<String>, in context: ModelContext) async {
        let dtos: [MealEntryDTO]
        do {
            dtos = try await client.from(SupabaseConfig.Tables.mealEntries)
                .select().eq("user_id", value: userId).execute().value
        } catch {
            print("[Supabase] Meal pull failed: \(error.localizedDescription)")
            return
        }
        let iso = ISO8601DateFormatter()
        var dirty = false
        for dto in dtos where !existingIds.contains(dto.id) {
            guard let uuid = UUID(uuidString: dto.id),
                  let consumedAt = iso.date(from: dto.consumedAt) else { continue }
            let entry = MealEntry(title: dto.title, calories: dto.calories, consumedAt: consumedAt)
            entry.id               = uuid
            entry.mealTypeRawValue = dto.mealType
            entry.proteinGrams     = dto.proteinGrams
            entry.carbohydrateGrams = dto.carbohydrateGrams
            entry.fatGrams         = dto.fatGrams
            entry.sourceRawValue   = dto.source
            context.insert(entry)
            dirty = true
        }
        if dirty { try? context.save() }
    }

    private func applyRemoteWater(userId: String, existingIds: Set<String>, in context: ModelContext) async {
        let dtos: [WaterEntryDTO]
        do {
            dtos = try await client.from(SupabaseConfig.Tables.waterEntries)
                .select().eq("user_id", value: userId).execute().value
        } catch {
            print("[Supabase] Water pull failed: \(error.localizedDescription)")
            return
        }
        let iso = ISO8601DateFormatter()
        var dirty = false
        for dto in dtos where !existingIds.contains(dto.id) {
            guard let uuid = UUID(uuidString: dto.id),
                  let loggedAt = iso.date(from: dto.loggedAt) else { continue }
            let entry = WaterEntry(amountMilliliters: dto.amountMilliliters, loggedAt: loggedAt)
            entry.id     = uuid
            entry.source = dto.source
            context.insert(entry)
            dirty = true
        }
        if dirty { try? context.save() }
    }

    private func applyRemoteWeights(userId: String, existingIds: Set<String>, in context: ModelContext) async {
        let dtos: [WeightEntryDTO]
        do {
            dtos = try await client.from(SupabaseConfig.Tables.weightEntries)
                .select().eq("user_id", value: userId).execute().value
        } catch {
            print("[Supabase] Weight pull failed: \(error.localizedDescription)")
            return
        }
        let iso = ISO8601DateFormatter()
        var dirty = false
        for dto in dtos where !existingIds.contains(dto.id) {
            guard let uuid = UUID(uuidString: dto.id),
                  let loggedAt = iso.date(from: dto.loggedAt) else { continue }
            let entry = WeightEntry(weightKilograms: dto.weightKilograms, loggedAt: loggedAt, notes: dto.notes)
            entry.id     = uuid
            entry.source = dto.source
            context.insert(entry)
            dirty = true
        }
        if dirty { try? context.save() }
    }

    private func applyRemoteWorkouts(userId: String, existingIds: Set<String>, in context: ModelContext) async {
        let dtos: [WorkoutSessionDTO]
        do {
            dtos = try await client.from(SupabaseConfig.Tables.workoutSessions)
                .select().eq("user_id", value: userId).execute().value
        } catch {
            print("[Supabase] Workout pull failed: \(error.localizedDescription)")
            return
        }
        let iso = ISO8601DateFormatter()
        var dirty = false
        for dto in dtos where !existingIds.contains(dto.id) {
            guard let uuid = UUID(uuidString: dto.id),
                  let startedAt = iso.date(from: dto.startedAt) else { continue }
            let session = WorkoutSession(title: dto.title)
            session.id                      = uuid
            session.startedAt               = startedAt
            session.endedAt                 = dto.endedAt.flatMap { iso.date(from: $0) }
            session.workoutGoalRawValue     = dto.workoutGoal
            session.notes                   = dto.notes
            session.totalEnergyKilocalories = dto.totalEnergyKilocalories
            session.durationSeconds         = dto.durationSeconds
            session.isCompleted             = dto.isCompleted
            session.perceivedExertionLevel  = dto.perceivedExertionLevel
            session.source                  = dto.source
            context.insert(session)
            dirty = true
        }
        if dirty { try? context.save() }
    }

    // MARK: Apply (remote wins; onboarding step takes max to avoid regression)

    private func applyProfileDTO(_ dto: UserProfileDTO, to profile: UserProfile) {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withFullDate]
        if let dobStr = dto.dateOfBirth, let dob = iso.date(from: dobStr) {
            profile.dateOfBirth = dob
        }
        if let sex = dto.biologicalSex      { profile.biologicalSexRawValue = sex }
        if let h   = dto.heightCm           { profile.heightCentimeters = h }
        if let w   = dto.currentWeightKg    { profile.currentWeightKilograms = w }
        profile.targetWeightKilograms        = dto.targetWeightKg
        if let name = dto.displayName       { profile.displayName = name }
        if dto.onboardingCompleted          { profile.onboardingCompleted = true }
        profile.onboardingStep               = max(profile.onboardingStep, dto.onboardingStep)
        profile.updatedAt                    = Date()
    }
}
