import Foundation
import SwiftData

@Model
final class UserProfile {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var updatedAt: Date

    // Auth
    var appleUserIdentifier: String?
    var supabaseUserId: String?         // Supabase auth user UUID — links row to remote
    var displayName: String?            // from Apple Sign In or manual entry
    var isGuest: Bool

    // Physical
    var dateOfBirth: Date?
    var biologicalSexRawValue: String
    var heightCentimeters: Double?
    var currentWeightKilograms: Double?
    var preferredWeightUnitRawValue: String
    var preferredDistanceUnitRawValue: String

    // Goal targets
    var targetWeightKilograms: Double?
    var targetCompletionDate: Date?

    // Onboarding state
    var onboardingCompleted: Bool
    var onboardingStep: Int

    init() {
        self.id = UUID()
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isGuest = true
        self.biologicalSexRawValue = BiologicalSex.male.rawValue
        self.preferredWeightUnitRawValue = WeightUnit.kilograms.rawValue
        self.preferredDistanceUnitRawValue = DistanceUnit.kilometers.rawValue
        self.onboardingCompleted = false
        self.onboardingStep = 0
    }

    // MARK: Computed helpers

    var biologicalSex: BiologicalSex {
        get { BiologicalSex(rawValue: biologicalSexRawValue) ?? .male }
        set { biologicalSexRawValue = newValue.rawValue }
    }

    var preferredWeightUnit: WeightUnit {
        get { WeightUnit(rawValue: preferredWeightUnitRawValue) ?? .kilograms }
        set { preferredWeightUnitRawValue = newValue.rawValue }
    }

    var preferredDistanceUnit: DistanceUnit {
        get { DistanceUnit(rawValue: preferredDistanceUnitRawValue) ?? .kilometers }
        set { preferredDistanceUnitRawValue = newValue.rawValue }
    }

    var ageYears: Int? {
        guard let dob = dateOfBirth else { return nil }
        return Calendar.current.dateComponents([.year], from: dob, to: Date()).year
    }

    var displayWeight: Double? {
        guard let kg = currentWeightKilograms else { return nil }
        return preferredWeightUnit == .kilograms ? kg : kg * 2.20462
    }

    var displayTargetWeight: Double? {
        guard let kg = targetWeightKilograms else { return nil }
        return preferredWeightUnit == .kilograms ? kg : kg * 2.20462
    }

    // Mifflin-St Jeor BMR in kcal/day — delegates to the canonical engine implementation.
    var estimatedBMR: Double? {
        guard let weight = currentWeightKilograms,
              let height = heightCentimeters,
              let age = ageYears else { return nil }
        return MetabolicCalculationEngine.bmr(
            weightKg: weight, heightCm: height, ageYears: age, sex: biologicalSex
        )
    }
}
