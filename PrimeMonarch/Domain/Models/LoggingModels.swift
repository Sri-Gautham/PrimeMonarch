import Foundation
import SwiftData

// MARK: - Weight Entry

@Model
final class WeightEntry {
    @Attribute(.unique) var id: UUID
    var loggedAt: Date
    var weightKilograms: Double
    var notes: String?
    var source: String  // "manual" | "healthkit"

    init(weightKilograms: Double, loggedAt: Date = Date(), notes: String? = nil) {
        self.id = UUID()
        self.loggedAt = loggedAt
        self.weightKilograms = weightKilograms
        self.notes = notes
        self.source = "manual"
    }

    func displayWeight(in unit: WeightUnit) -> Double {
        unit == .kilograms ? weightKilograms : weightKilograms * 2.20462
    }
}

// MARK: - Water Entry

@Model
final class WaterEntry {
    @Attribute(.unique) var id: UUID
    var loggedAt: Date
    var amountMilliliters: Double
    var source: String  // "manual" | "healthkit"

    init(amountMilliliters: Double, loggedAt: Date = Date()) {
        self.id = UUID()
        self.loggedAt = loggedAt
        self.amountMilliliters = amountMilliliters
        self.source = "manual"
    }

    // Convenience initializers for common amounts
    static func glass() -> WaterEntry { WaterEntry(amountMilliliters: 250) }
    static func bottle() -> WaterEntry { WaterEntry(amountMilliliters: 500) }
    static func largeBottle() -> WaterEntry { WaterEntry(amountMilliliters: 750) }
}

// MARK: - Meal Entry

@Model
final class MealEntry {
    @Attribute(.unique) var id: UUID
    var consumedAt: Date
    var mealTypeRawValue: String
    var title: String
    var calories: Double
    var proteinGrams: Double?
    var carbohydrateGrams: Double?
    var fatGrams: Double?
    var sourceRawValue: String
    var photoLocalIdentifier: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        title: String,
        calories: Double,
        mealType: MealType = .snack,
        consumedAt: Date = Date(),
        source: MealEntrySource = .manual
    ) {
        self.id = UUID()
        self.consumedAt = consumedAt
        self.mealTypeRawValue = mealType.rawValue
        self.title = title
        self.calories = calories
        self.sourceRawValue = source.rawValue
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var mealType: MealType {
        get { MealType(rawValue: mealTypeRawValue) ?? .snack }
        set { mealTypeRawValue = newValue.rawValue }
    }

    var entrySource: MealEntrySource {
        get { MealEntrySource(rawValue: sourceRawValue) ?? .manual }
        set { sourceRawValue = newValue.rawValue }
    }
}
