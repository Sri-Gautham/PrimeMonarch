import Foundation
import Supabase

// MARK: - Supabase Project Configuration
// Package is already installed via SPM.
// Run supabase/schema.sql in Supabase Dashboard → SQL Editor before first launch.

enum SupabaseConfig {
    static let projectURL = URL(string: "https://vgcblbtefvoylyrhxhof.supabase.co")!

    // Anon (public) key — safe to bundle in the client app.
    // Security is enforced by Row Level Security policies, not by keeping this key secret.
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZnY2JsYnRlZnZveWx5cmh4aG9mIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODU2OTkxNjAsImV4cCI6MjEwMTI3NTE2MH0.WoIcY3qtJMR87ZosjMj4kLQCkkSNBClLh0lXkCxDVH8"

    // MARK: Table names
    enum Tables {
        static let userProfiles    = "user_profiles"
        static let goalProfiles    = "goal_profiles"
        static let userPreferences = "user_preferences"
        // Activity — add matching tables in Supabase Dashboard before enabling sync
        static let mealEntries     = "meal_entries"
        static let waterEntries    = "water_entries"
        static let weightEntries   = "weight_entries"
        static let workoutSessions = "workout_sessions"
    }
}

// MARK: - Shared Supabase Client
// Defined here (not in SupabaseSyncService.swift) so it carries no @MainActor inference.
// emitLocalSessionAsInitialSession: true — opt in to the current-behavior fix recommended by
// the Supabase SDK (avoids the runtime fault logged on first launch).
extension SupabaseClient {
    static let shared = SupabaseClient(
        supabaseURL: SupabaseConfig.projectURL,
        supabaseKey: SupabaseConfig.anonKey,
        options: SupabaseClientOptions(
            auth: .init(emitLocalSessionAsInitialSession: true)
        )
    )
}
