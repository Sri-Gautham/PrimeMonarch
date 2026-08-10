import SwiftData
import SwiftUI

struct LogView: View {
    @Environment(\.modelContext) private var context
    @Query private var todayMeals: [MealEntry]
    @Query private var todayTargets: [DailyTarget]
    @Query private var profiles: [UserProfile]

    @State private var showLogFood        = false
    @State private var showLogWater       = false
    @State private var showLogWeight      = false
    @State private var showLogMeasurement = false

    init() {
        let start = Calendar.current.startOfDay(for: Date())
        let end   = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        _todayMeals = Query(
            filter: #Predicate<MealEntry> { $0.consumedAt >= start && $0.consumedAt < end },
            sort: \.consumedAt
        )
        _todayTargets = Query(
            filter: #Predicate<DailyTarget> { $0.date >= start && $0.date < end }
        )
    }

    private var profile: UserProfile?  { profiles.first }
    private var target: DailyTarget?   { todayTargets.first }
    private var calorieTarget: Int     { target?.calorieTarget ?? 2000 }
    private var totalCalories: Double  { todayMeals.reduce(0) { $0 + $1.calories } }
    private var calorieProgress: Double {
        calorieTarget > 0 ? min(totalCalories / Double(calorieTarget), 1.0) : 0
    }

    private var totalProtein: Double  { todayMeals.compactMap(\.proteinGrams).reduce(0, +) }
    private var totalCarbs: Double    { todayMeals.compactMap(\.carbohydrateGrams).reduce(0, +) }
    private var totalFat: Double      { todayMeals.compactMap(\.fatGrams).reduce(0, +) }
    private var hasMacros: Bool       { totalProtein > 0 || totalCarbs > 0 || totalFat > 0 }

    private var breakfastMeals: [MealEntry] { todayMeals.filter { $0.mealType == .breakfast } }
    private var lunchMeals: [MealEntry]     { todayMeals.filter { $0.mealType == .lunch } }
    private var dinnerMeals: [MealEntry]    { todayMeals.filter { $0.mealType == .dinner } }
    private var snackMeals: [MealEntry]     {
        todayMeals.filter { $0.mealType == .snack || $0.mealType == .preworkout || $0.mealType == .postworkout }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: PMSpacing.lg) {
                    // Calorie summary
                    calorieSummaryCard
                        .padding(.horizontal, PMSpacing.screenEdge)
                        .padding(.top, PMSpacing.xs)

                    // Meals by type
                    if todayMeals.isEmpty {
                        PMCard {
                            PMEmptyState(
                                icon: "fork.knife",
                                title: "No meals logged",
                                message: "Tap + to log your first meal of the day."
                            )
                        }
                        .padding(.horizontal, PMSpacing.screenEdge)
                    } else {
                        mealsContent
                            .padding(.horizontal, PMSpacing.screenEdge)
                    }

                    Spacer().frame(height: PMSpacing.xxl)
                }
            }
            .scrollIndicators(.hidden)
            .background(Color.pmBackgroundPrimary.ignoresSafeArea())
            .navigationTitle("Meals")
            .pmLargeNavTitle()
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button { showLogFood        = true } label: { Label("Log Food",        systemImage: "fork.knife") }
                        Button { showLogWater       = true } label: { Label("Log Water",       systemImage: "drop.fill") }
                        Button { showLogWeight      = true } label: { Label("Log Weight",      systemImage: "scalemass.fill") }
                        Button { showLogMeasurement = true } label: { Label("Log Measurement", systemImage: "ruler") }
                    } label: {
                        Circle()
                            .fill(Color.pmAccentPurpleBright)
                            .frame(width: 34, height: 34)
                            .overlay(
                                Image(systemName: "plus")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(Color.pmBackgroundPrimary)
                            )
                    }
                }
            }
        }
        .sheet(isPresented: $showLogFood)        { LogFoodSheet() }
        .sheet(isPresented: $showLogWater)       { LogWaterSheet() }
        .sheet(isPresented: $showLogWeight)      { LogWeightSheet(weightUnit: profile?.preferredWeightUnit ?? .kilograms) }
        .sheet(isPresented: $showLogMeasurement) { LogMeasurementSheet(weightUnit: profile?.preferredWeightUnit ?? .kilograms) }
    }

    // MARK: - Calorie Summary

    private var calorieSummaryCard: some View {
        PMCard(elevated: true) {
            VStack(alignment: .leading, spacing: PMSpacing.sm) {
                HStack {
                    VStack(alignment: .leading, spacing: PMSpacing.xs) {
                        Text("CALORIES TODAY")
                            .font(.pmKicker)
                            .tracking(0.6)
                            .foregroundStyle(.pmTextSecondary)
                        Text("\(Int(totalCalories).formatted(.number)) / \(calorieTarget.formatted(.number)) kcal")
                            .font(.system(.title3, design: .default, weight: .heavy))
                            .foregroundStyle(.pmTextPrimary)
                    }
                    Spacer()
                    CalorieRing(progress: calorieProgress)
                }

                if hasMacros {
                    PMDivider()
                    HStack(spacing: 0) {
                        MacroCell(label: "Protein", value: totalProtein, color: .pmRingEnergy)
                        MacroCell(label: "Carbs",   value: totalCarbs,   color: .pmRingMovement)
                        MacroCell(label: "Fat",     value: totalFat,     color: .pmRingHydration)
                    }
                }
            }
            .padding(PMSpacing.md)
        }
    }

    // MARK: - Meals content

    @ViewBuilder
    private var mealsContent: some View {
        VStack(spacing: PMSpacing.sm) {
            if !breakfastMeals.isEmpty { MealGroupCard(kicker: "Breakfast", meals: breakfastMeals) }
            if !lunchMeals.isEmpty     { MealGroupCard(kicker: "Lunch",     meals: lunchMeals) }
            if !dinnerMeals.isEmpty    { MealGroupCard(kicker: "Dinner",    meals: dinnerMeals) }
            if !snackMeals.isEmpty     { MealGroupCard(kicker: "Snack",     meals: snackMeals) }
        }
    }
}

// MARK: - Macro Cell

private struct MacroCell: View {
    let label: String
    let value: Double
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text("\(Int(value))g")
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(color)
            Text(label)
                .font(.pmCaption)
                .foregroundStyle(.pmTextSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Calorie Ring

private struct CalorieRing: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.pmPillOrangeBg, lineWidth: 7)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    Color.pmRingEnergy,
                    style: StrokeStyle(lineWidth: 7, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 56, height: 56)
    }
}

// MARK: - Meal Group Card

private struct MealGroupCard: View {
    let kicker: String
    let meals: [MealEntry]

    var body: some View {
        PMCard(elevated: true) {
            VStack(alignment: .leading, spacing: 0) {
                Text(kicker)
                    .font(.pmKicker)
                    .tracking(0.6)
                    .foregroundStyle(.pmTextSecondary)
                    .padding(.horizontal, PMSpacing.md)
                    .padding(.top, PMSpacing.sm)
                    .padding(.bottom, PMSpacing.xs)

                ForEach(Array(meals.enumerated()), id: \.element.id) { i, meal in
                    if i > 0 { PMDivider().padding(.horizontal, PMSpacing.md) }
                    MealDetailRow(meal: meal)
                }
            }
            .padding(.bottom, PMSpacing.sm)
        }
    }
}

// MARK: - Meal Detail Row

private struct MealDetailRow: View {
    let meal: MealEntry

    var body: some View {
        HStack(spacing: PMSpacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(meal.title)
                    .font(.pmBodyMedium)
                    .foregroundStyle(.pmTextPrimary)
                HStack(spacing: 4) {
                    Text("\(Int(meal.calories)) kcal")
                    if let p = meal.proteinGrams      { Text("· \(Int(p))g P") }
                    if let c = meal.carbohydrateGrams { Text("· \(Int(c))g C") }
                    if let f = meal.fatGrams          { Text("· \(Int(f))g F") }
                }
                .font(.pmCaption)
                .foregroundStyle(.pmTextSecondary)
                .lineLimit(1)
                Text(meal.consumedAt.formatted(.dateTime.hour().minute()))
                    .font(.pmCaption)
                    .foregroundStyle(.pmTextTertiary)
            }
            Spacer()
        }
        .padding(.horizontal, PMSpacing.md)
        .padding(.vertical, PMSpacing.sm)
    }
}

// MARK: - Log Food Sheet

private struct LogFoodSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss)      private var dismiss

    @State private var foodTitle           = ""
    @State private var caloriesText        = ""
    @State private var selectedMealType: MealType = .snack
    @State private var proteinText         = ""
    @State private var carbsText           = ""
    @State private var fatText             = ""
    @State private var searchText          = ""
    @State private var searchResults: [PredefinedMeal] = []
    @State private var selectedPredefined: PredefinedMeal? = nil

    private let mealService = PredefinedMealService.shared

    private var calories: Double? { Double(caloriesText) }
    private var canSave: Bool {
        !foodTitle.trimmingCharacters(in: .whitespaces).isEmpty && (calories ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: PMSpacing.lg) {
                    mealTypeChips
                    searchSection
                    manualFields
                }
                .padding(.top, PMSpacing.md)
                .padding(.bottom, PMSpacing.xxl)
            }
            .background(Color.pmBackgroundPrimary.ignoresSafeArea())
            .navigationTitle("Log Food")
            .pmLargeNavTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(.pmTextSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .font(.pmButtonLabel)
                        .disabled(!canSave)
                }
            }
        }
    }

    // MARK: - Meal type chips

    private var mealTypeChips: some View {
        VStack(alignment: .leading, spacing: PMSpacing.xs) {
            Text("Meal type")
                .font(.pmCaptionMedium)
                .foregroundStyle(.pmTextSecondary)
                .padding(.horizontal, PMSpacing.screenEdge)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: PMSpacing.xs) {
                    ForEach(MealType.allCases, id: \.rawValue) { type in
                        let selected = selectedMealType == type
                        Button { selectedMealType = type } label: {
                            Label(type.displayName, systemImage: type.icon)
                                .font(.pmCaptionMedium)
                                .padding(.horizontal, PMSpacing.sm)
                                .padding(.vertical, PMSpacing.xs)
                                .background(selected ? Color.pmAccentPurpleBright : Color.pmSurfacePrimary)
                                .foregroundStyle(selected ? Color.pmBackgroundPrimary : Color.pmTextSecondary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, PMSpacing.screenEdge)
            }
        }
    }

    // MARK: - Search section

    @ViewBuilder
    private var searchSection: some View {
        VStack(alignment: .leading, spacing: PMSpacing.sm) {
            // Search field
            HStack(spacing: PMSpacing.xs) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.pmTextSecondary)
                    .frame(width: 18)
                TextField("Search foods…", text: $searchText)
                    .font(.pmBody)
                    .foregroundStyle(.pmTextPrimary)
                    .autocorrectionDisabled()
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.pmTextSecondary)
                    }
                }
            }
            .padding(PMSpacing.sm)
            .background(Color.pmSurfacePrimary)
            .clipShape(RoundedRectangle(cornerRadius: PMSpacing.buttonRadius))
            .padding(.horizontal, PMSpacing.screenEdge)
            .onChange(of: searchText) { _, query in
                searchResults = query.trimmingCharacters(in: .whitespaces).isEmpty
                    ? []
                    : Array(mealService.search(query).prefix(6))
            }

            // Selected predefined pill
            if let selected = selectedPredefined {
                HStack(spacing: PMSpacing.xs) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.pmRingMovement)
                    Text(selected.name)
                        .font(.pmCaptionMedium)
                        .foregroundStyle(.pmTextPrimary)
                    Spacer()
                    Button { clearPredefined() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.pmTextSecondary)
                    }
                }
                .padding(.horizontal, PMSpacing.screenEdge)
            }

            // Search results list
            if !searchResults.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(searchResults.enumerated()), id: \.element.id) { i, meal in
                        if i > 0 { PMDivider().padding(.horizontal, PMSpacing.md) }
                        Button { applyPredefined(meal) } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(meal.name)
                                        .font(.pmBodyMedium)
                                        .foregroundStyle(.pmTextPrimary)
                                    Text(meal.macroSummary)
                                        .font(.pmCaption)
                                        .foregroundStyle(.pmTextSecondary)
                                }
                                Spacer()
                                Text(meal.serving)
                                    .font(.pmCaption)
                                    .foregroundStyle(.pmTextSecondary)
                                    .multilineTextAlignment(.trailing)
                            }
                            .padding(.horizontal, PMSpacing.md)
                            .padding(.vertical, PMSpacing.sm)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(Color.pmSurfacePrimary)
                .clipShape(RoundedRectangle(cornerRadius: PMSpacing.cardRadius))
                .shadow(
                    color: Color(red: 0.180, green: 0.169, blue: 0.145).opacity(0.10),
                    radius: 6, x: 0, y: 2
                )
                .padding(.horizontal, PMSpacing.screenEdge)
            }

            // Divider kicker
            Text(searchResults.isEmpty && selectedPredefined == nil ? "OR ENTER MANUALLY" : "EDIT DETAILS BELOW")
                .font(.pmKicker)
                .tracking(0.6)
                .foregroundStyle(.pmTextSecondary)
                .padding(.horizontal, PMSpacing.screenEdge)
        }
    }

    // MARK: - Manual fields

    private var manualFields: some View {
        VStack(spacing: PMSpacing.sm) {
            PMFormField(label: "Food name",               text: $foodTitle,    placeholder: "e.g. Grilled chicken breast")
            PMFormField(label: "Calories (kcal)",         text: $caloriesText, placeholder: "e.g. 350",  isNumeric: true)
            PMFormField(label: "Protein (g) — optional", text: $proteinText,  placeholder: "e.g. 32",   isNumeric: true)
            PMFormField(label: "Carbs (g) — optional",   text: $carbsText,    placeholder: "e.g. 45",   isNumeric: true)
            PMFormField(label: "Fat (g) — optional",     text: $fatText,      placeholder: "e.g. 12",   isNumeric: true)
        }
        .padding(.horizontal, PMSpacing.screenEdge)
    }

    // MARK: - Helpers

    private func applyPredefined(_ meal: PredefinedMeal) {
        foodTitle          = meal.name
        caloriesText       = "\(Int(meal.calories))"
        proteinText        = meal.proteinGrams.map      { "\(Int($0))" } ?? ""
        carbsText          = meal.carbohydrateGrams.map { "\(Int($0))" } ?? ""
        fatText            = meal.fatGrams.map          { "\(Int($0))" } ?? ""
        selectedMealType   = meal.mealType
        selectedPredefined = meal
        searchText         = ""
        searchResults      = []
    }

    private func clearPredefined() {
        selectedPredefined = nil
        foodTitle          = ""
        caloriesText       = ""
        proteinText        = ""
        carbsText          = ""
        fatText            = ""
    }

    private func save() {
        guard let cal = calories else { return }
        let entry = MealEntry(
            title: foodTitle.trimmingCharacters(in: .whitespaces),
            calories: cal,
            mealType: selectedMealType
        )
        if let p = Double(proteinText) { entry.proteinGrams = p }
        if let c = Double(carbsText)   { entry.carbohydrateGrams = c }
        if let f = Double(fatText)     { entry.fatGrams = f }
        context.insert(entry)
        StreakService.creditLoggingStreak(in: context)
        AdaptationEngine.recompute(in: context)
        dismiss()
    }
}

// MARK: - Log Water Sheet

private struct LogWaterSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss)      private var dismiss

    @State private var selectedAmount: Double = 250
    @State private var customText = ""

    private let presets: [(label: String, icon: String, amount: Double)] = [
        ("Small glass", "cup.and.saucer",      200),
        ("Glass",       "cup.and.saucer.fill",  250),
        ("Bottle",      "waterbottle",          500),
        ("Large bottle","waterbottle.fill",     750),
        ("1 litre",     "drop.fill",           1000),
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: PMSpacing.lg) {
                VStack(alignment: .leading, spacing: PMSpacing.sm) {
                    Text("Select amount")
                        .font(.pmCaptionMedium)
                        .foregroundStyle(.pmTextSecondary)
                        .padding(.horizontal, PMSpacing.screenEdge)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: PMSpacing.sm) {
                        ForEach(presets, id: \.amount) { preset in
                            let selected = selectedAmount == preset.amount
                            Button {
                                selectedAmount = preset.amount
                                customText = ""
                            } label: {
                                VStack(spacing: PMSpacing.xxs) {
                                    Image(systemName: preset.icon).font(.system(size: 20, weight: .light))
                                    Text(preset.label).font(.pmBodyMedium)
                                    Text("\(Int(preset.amount)) ml")
                                        .font(.pmCaption)
                                        .foregroundStyle(selected ? Color.pmBackgroundPrimary.opacity(0.8) : .pmTextSecondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, PMSpacing.sm)
                                .background(selected ? Color.pmAccentPurpleBright : Color.pmSurfacePrimary)
                                .foregroundStyle(selected ? Color.pmBackgroundPrimary : Color.pmTextPrimary)
                                .clipShape(RoundedRectangle(cornerRadius: PMSpacing.cardRadius))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, PMSpacing.screenEdge)
                }

                PMFormField(label: "Custom amount (ml)", text: $customText, placeholder: "Enter ml", isNumeric: true)
                    .padding(.horizontal, PMSpacing.screenEdge)
                    .onChange(of: customText) { _, new in
                        if let val = Double(new), val > 0 { selectedAmount = val }
                    }

                Spacer()

                Button("Add \(Int(selectedAmount)) ml") {
                    context.insert(WaterEntry(amountMilliliters: selectedAmount))
                    dismiss()
                }
                .pmPrimaryStyle()
                .padding(.horizontal, PMSpacing.screenEdge)
                .padding(.bottom, PMSpacing.lg)
            }
            .padding(.top, PMSpacing.md)
            .background(Color.pmBackgroundPrimary.ignoresSafeArea())
            .navigationTitle("Log Water")
            .pmLargeNavTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(.pmTextSecondary)
                }
            }
        }
    }
}

// MARK: - Log Weight Sheet

private struct LogWeightSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss)      private var dismiss

    let weightUnit: WeightUnit
    @State private var weightText = ""

    private var weight: Double? { Double(weightText) }
    private var canSave: Bool   { (weight ?? 0) > 0 }

    var body: some View {
        NavigationStack {
            VStack(spacing: PMSpacing.lg) {
                PMFormField(
                    label: "Weight (\(weightUnit.displayName))",
                    text: $weightText,
                    placeholder: weightUnit == .kilograms ? "e.g. 75.5" : "e.g. 166",
                    isNumeric: true
                )
                .padding(.horizontal, PMSpacing.screenEdge)

                Spacer()

                Button("Save") { save() }
                    .pmPrimaryStyle()
                    .disabled(!canSave)
                    .padding(.horizontal, PMSpacing.screenEdge)
                    .padding(.bottom, PMSpacing.lg)
            }
            .padding(.top, PMSpacing.lg)
            .background(Color.pmBackgroundPrimary.ignoresSafeArea())
            .navigationTitle("Log Weight")
            .pmLargeNavTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(.pmTextSecondary)
                }
            }
        }
    }

    private func save() {
        guard let w = weight else { return }
        let kg = weightUnit == .kilograms ? w : w / 2.20462
        context.insert(WeightEntry(weightKilograms: kg))
        dismiss()
    }
}

// MARK: - Log Measurement Sheet

private struct LogMeasurementSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss)      private var dismiss

    let weightUnit: WeightUnit

    @State private var selectedSite: MeasurementSite = .waist
    @State private var valueText = ""
    @State private var notesText = ""

    private var usesImperial: Bool { weightUnit == .pounds }
    private var unitLabel: String  { usesImperial ? "in" : "cm" }
    private var canSave: Bool      { (Double(valueText) ?? 0) > 0 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: PMSpacing.lg) {
                    VStack(alignment: .leading, spacing: PMSpacing.xs) {
                        Text("Measurement site")
                            .font(.pmCaptionMedium)
                            .foregroundStyle(.pmTextSecondary)
                            .padding(.horizontal, PMSpacing.screenEdge)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: PMSpacing.xs) {
                                ForEach(MeasurementSite.allCases.filter { $0 != .custom }, id: \.rawValue) { site in
                                    let selected = selectedSite == site
                                    Button { selectedSite = site } label: {
                                        Text(site.displayName)
                                            .font(.pmCaptionMedium)
                                            .padding(.horizontal, PMSpacing.sm)
                                            .padding(.vertical, PMSpacing.xs)
                                            .background(selected ? Color.pmAccentPurpleBright : Color.pmSurfacePrimary)
                                            .foregroundStyle(selected ? Color.pmBackgroundPrimary : Color.pmTextSecondary)
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, PMSpacing.screenEdge)
                        }
                    }

                    VStack(spacing: PMSpacing.sm) {
                        PMFormField(label: "Value (\(unitLabel))", text: $valueText, placeholder: usesImperial ? "e.g. 32" : "e.g. 82", isNumeric: true)
                        PMFormField(label: "Notes — optional", text: $notesText, placeholder: "Any context…")
                    }
                    .padding(.horizontal, PMSpacing.screenEdge)

                    Spacer()

                    Button("Save") { save() }
                        .pmPrimaryStyle()
                        .disabled(!canSave)
                        .padding(.horizontal, PMSpacing.screenEdge)
                        .padding(.bottom, PMSpacing.lg)
                }
                .padding(.top, PMSpacing.md)
            }
            .background(Color.pmBackgroundPrimary.ignoresSafeArea())
            .navigationTitle("Log Measurement")
            .pmLargeNavTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(.pmTextSecondary)
                }
            }
        }
    }

    private func save() {
        guard let raw = Double(valueText), raw > 0 else { return }
        let cm = usesImperial ? raw * 2.54 : raw
        let entry = BodyMeasurement(site: selectedSite, valueCentimeters: cm)
        entry.notes = notesText.isEmpty ? nil : notesText
        context.insert(entry)
        try? context.save()
        dismiss()
    }
}

// MARK: - Shared form field

struct PMFormField: View {
    let label: String
    @Binding var text: String
    let placeholder: String
    var isNumeric: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: PMSpacing.xs) {
            Text(label)
                .font(.pmCaptionMedium)
                .foregroundStyle(.pmTextSecondary)
            TextField(placeholder, text: $text)
                .pmKeyboardType(isNumeric: isNumeric)
                .font(.pmBody)
                .foregroundStyle(.pmTextPrimary)
                .padding(PMSpacing.sm)
                .background(Color.pmSurfacePrimary)
                .clipShape(RoundedRectangle(cornerRadius: PMSpacing.buttonRadius))
        }
    }
}
