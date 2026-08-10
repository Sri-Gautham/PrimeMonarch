import SwiftData
import SwiftUI

// MARK: - Plan Tab

private enum PlanTab: String, CaseIterable {
    case workout   = "Workout"
    case nutrition = "Nutrition"
}

// MARK: - Plan View

struct PlanView: View {
    @Environment(\.modelContext) private var context
    @Query private var goalProfiles: [GoalProfile]
    @Query(sort: \DailyTarget.date, order: .reverse) private var allTargets: [DailyTarget]
    @Query private var preferences: [UserPreference]

    private var goalProfile: GoalProfile? { goalProfiles.first }
    private var preference: UserPreference? { preferences.first }
    private var workoutDaysPerWeek: Int { goalProfile?.workoutDaysPerWeek ?? 3 }

    private var todayTarget: DailyTarget? {
        let today = Calendar.current.startOfDay(for: Date())
        return allTargets.first { Calendar.current.isDate($0.date, inSameDayAs: today) }
    }

    private var intensity: WorkoutIntensity { todayTarget?.adaptationIntensity ?? .standard }

    private var exercises: [WorkoutPlanExercise] {
        if let generated = WorkoutVarietyService.decodeExercises(from: todayTarget?.generatedWorkoutJSON) {
            return generated.map { $0.adjusted(for: intensity) }
        }
        return WorkoutPlans.exercises(for: goalProfile?.primaryGoal,
                                      intensity: intensity,
                                      equipment: goalProfile?.availableEquipment ?? [])
    }

    private var workoutTitle: String { WorkoutPlans.title(for: goalProfile?.primaryGoal) }

    private var todayWeekdayIndex: Int {
        Calendar.current.component(.weekday, from: Date()) - 1
    }

    private var weekSchedule: [Bool] {
        let preferred = [1, 3, 5, 2, 4, 6, 0]
        var schedule  = Array(repeating: false, count: 7)
        for i in 0..<min(workoutDaysPerWeek, 7) { schedule[preferred[i]] = true }
        return schedule
    }

    private var isTodayWorkout: Bool { weekSchedule[todayWeekdayIndex] }
    private let dayLabels = ["S", "M", "T", "W", "T", "F", "S"]

    // MARK: - Nutrition plan

    private var dayMealPlan: DayMealPlan {
        let base = MealPlanEngine.plan(
            for: selectedNutritionDate,
            calorieTarget: todayTarget?.calorieTarget ?? 2000,
            mealsPerDay: preference?.mealsPerDay ?? 3,
            dietaryStyles: preference?.dietaryStyles ?? [.noRestrictions],
            catalog: RecipeCatalogService.shared.allRecipes
        )
        guard !swappedRecipes.isEmpty else { return base }
        let adjusted = base.slots.map { slot in
            swappedRecipes[slot.id].map { MealSlot(id: slot.id, mealType: slot.mealType, recipe: $0) } ?? slot
        }
        return DayMealPlan(date: base.date, slots: adjusted)
    }

    private var groceryGroups: [(category: String, items: [GroceryItem])] {
        GroceryAggregationEngine.aggregate(from: dayMealPlan.slots.map(\.recipe))
    }

    private func swapAlternatives(for slot: MealSlot) -> [Recipe] {
        let styles  = preference?.dietaryStyles ?? [.noRestrictions]
        let current = swappedRecipes[slot.id] ?? slot.recipe
        return RecipeCatalogService.shared
            .recipes(for: slot.mealType, suitableFor: styles)
            .filter { $0.id != current.id }
            .sorted { abs($0.calories - current.calories) < abs($1.calories - current.calories) }
    }

    // MARK: - State

    @State private var planTab: PlanTab = .workout
    @State private var showLiveWorkout = false
    @State private var showGroceryList = false
    @State private var selectedRecipe: Recipe? = nil
    @State private var swappedRecipes: [String: Recipe] = [:]
    @State private var swapSlot: MealSlot? = nil
    @State private var selectedNutritionDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var selectedWorkoutDayIndex: Int = Calendar.current.component(.weekday, from: Date()) - 1

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: PMSpacing.lg) {

                    // Tab picker
                    Picker("Plan section", selection: $planTab) {
                        ForEach(PlanTab.allCases, id: \.self) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, PMSpacing.screenEdge)
                    .padding(.top, PMSpacing.xs)

                    if planTab == .workout {
                        workoutSection
                    } else {
                        nutritionSection
                    }
                }
            }
            .scrollIndicators(.hidden)
            .background(Color.pmBackgroundPrimary.ignoresSafeArea())
            .navigationTitle("Plan")
            .pmLargeNavTitle()
        }
        .task(id: todayTarget?.id) {
            guard let target = todayTarget else { return }
            await WorkoutVarietyService.generateIfNeeded(
                for: target,
                goal: goalProfile?.primaryGoal,
                equipment: goalProfile?.availableEquipment ?? [],
                intensity: intensity,
                context: context
            )
        }
        .fullScreenCover(isPresented: $showLiveWorkout) {
            LiveWorkoutView(goalProfile: goalProfile, intensity: intensity,
                            precomputedExercises: exercises)
        }
        .sheet(isPresented: $showGroceryList) {
            GroceryListSheet(groups: groceryGroups)
        }
        .sheet(item: $selectedRecipe) { recipe in
            RecipeDetailSheet(recipe: recipe)
        }
        .sheet(item: $swapSlot) { slot in
            SwapRecipeSheet(
                slot: slot,
                alternatives: swapAlternatives(for: slot)
            ) { picked in
                swappedRecipes[slot.id] = picked
            }
        }
    }

    // MARK: - Workout Section

    private var workoutSection: some View {
        let isSelectedToday   = selectedWorkoutDayIndex == todayWeekdayIndex
        let isSelectedWorkout = weekSchedule[selectedWorkoutDayIndex]
        let selectedDayName   = Calendar.current.weekdaySymbols[selectedWorkoutDayIndex]

        return VStack(alignment: .leading, spacing: PMSpacing.lg) {
            // Subtitle
            let mins = WorkoutPlans.estimatedMinutes(for: goalProfile?.primaryGoal, intensity: intensity)
            VStack(alignment: .leading, spacing: 2) {
                Text(workoutTitle)
                    .font(.pmBodyMedium)
                    .foregroundStyle(.pmTextPrimary)
                if isSelectedWorkout {
                    Text("\(mins) min · \(exercises.count) exercises")
                        .font(.pmCaption)
                        .foregroundStyle(.pmTextSecondary)
                } else {
                    Text("Rest day · \(selectedDayName)")
                        .font(.pmCaption)
                        .foregroundStyle(.pmTextSecondary)
                }
            }
            .padding(.horizontal, PMSpacing.screenEdge)

            if isSelectedWorkout {
                burnCard(showStart: isSelectedToday)
                    .padding(.horizontal, PMSpacing.screenEdge)

                if isSelectedToday, let msg = todayTarget?.adaptationMessage {
                    adaptationBanner(message: msg).padding(.horizontal, PMSpacing.screenEdge)
                }
            } else {
                restDayCard(dayName: selectedDayName)
                    .padding(.horizontal, PMSpacing.screenEdge)
            }

            weekStrip.padding(.horizontal, PMSpacing.screenEdge)

            if isSelectedWorkout {
                exercisesSection
                    .padding(.horizontal, PMSpacing.screenEdge)
                    .padding(.bottom, PMSpacing.xxl)
            } else {
                Spacer().frame(height: PMSpacing.xxl)
            }
        }
    }

    // MARK: - Nutrition Section

    private var nutritionSection: some View {
        VStack(alignment: .leading, spacing: PMSpacing.lg) {
            // 7-day date selector
            nutritionDateStrip
                .padding(.horizontal, PMSpacing.screenEdge)

            // Calorie overview
            nutritionSummaryCard
                .padding(.horizontal, PMSpacing.screenEdge)

            // Meal slots
            VStack(spacing: PMSpacing.sm) {
                ForEach(dayMealPlan.slots) { slot in
                    MealSlotCard(
                        slot: slot,
                        onTap:  { selectedRecipe = slot.recipe },
                        onSwap: { swapSlot = slot }
                    )
                }
            }
            .padding(.horizontal, PMSpacing.screenEdge)

            // Grocery list button
            if !groceryGroups.isEmpty {
                Button {
                    showGroceryList = true
                } label: {
                    HStack {
                        Image(systemName: "cart.fill")
                            .font(.system(size: 15))
                        Text("View Grocery List")
                            .font(.pmButtonLabel)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(.pmAccentPurpleBright)
                    .padding(PMSpacing.md)
                    .background(Color.pmPillOrangeBg)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, PMSpacing.screenEdge)
            }

            Spacer().frame(height: PMSpacing.xxl)
        }
    }

    // MARK: - Nutrition Date Strip

    private var nutritionDateStrip: some View {
        let today = Calendar.current.startOfDay(for: Date())
        let dates = (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: today) }
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: PMSpacing.xs) {
                ForEach(dates, id: \.self) { date in
                    let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedNutritionDate)
                    let isToday    = Calendar.current.isDateInToday(date)
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            selectedNutritionDate = date
                        }
                    } label: {
                        VStack(spacing: 3) {
                            Text(date.formatted(.dateTime.weekday(.narrow)))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(isSelected ? .pmAccentPurpleBright : .pmTextSecondary)
                            Text(date.formatted(.dateTime.day()))
                                .font(.system(size: 15, weight: isSelected ? .bold : .regular))
                                .foregroundStyle(isSelected ? .pmAccentPurpleBright : .pmTextPrimary)
                            Circle()
                                .fill(isToday
                                    ? (isSelected ? Color.pmAccentPurpleBright : Color.pmTextTertiary)
                                    : Color.clear)
                                .frame(width: 4, height: 4)
                        }
                        .frame(width: 38, height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(isSelected ? Color.pmPillOrangeBg : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: - Nutrition Summary Card

    private var nutritionSummaryCard: some View {
        let plan       = dayMealPlan
        let target     = todayTarget?.calorieTarget ?? 2000
        let planned    = plan.totalCalories
        let fraction   = min(Double(planned) / Double(max(target, 1)), 1.0)
        let isToday    = Calendar.current.isDateInToday(selectedNutritionDate)
        let dateHeader = isToday
            ? "TODAY'S PLAN"
            : selectedNutritionDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()).uppercased()

        return PMCard(elevated: true) {
            VStack(alignment: .leading, spacing: PMSpacing.sm) {
                HStack {
                    Text(dateHeader)
                        .font(.pmKicker)
                        .tracking(0.6)
                        .foregroundStyle(.pmTextSecondary)
                    Spacer()
                    Text("\(planned) / \(target) kcal")
                        .font(.pmCaption)
                        .foregroundStyle(.pmTextSecondary)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.pmDivider)
                            .frame(height: 6)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.pmAccentPurpleBright)
                            .frame(width: geo.size.width * fraction, height: 6)
                    }
                }
                .frame(height: 6)

                HStack(spacing: PMSpacing.lg) {
                    MacroLabel(label: "Protein", value: "\(Int(plan.totalProtein))g", color: .pmAccentPurple)
                    MacroLabel(label: "Carbs",   value: "\(Int(plan.totalCarbs))g",   color: .pmRingMovement)
                    MacroLabel(label: "Fat",     value: "\(Int(plan.totalFat))g",     color: .pmRingEnergy)
                }
            }
            .padding(PMSpacing.md)
        }
    }

    // MARK: - Burn card

    private func burnCard(showStart: Bool) -> some View {
        let burn = WorkoutPlans.estimatedBurnKcal(for: goalProfile?.primaryGoal, intensity: intensity)
        return PMCard(elevated: true) {
            HStack {
                VStack(alignment: .leading, spacing: PMSpacing.xs) {
                    HStack(spacing: 4) {
                        Text("ESTIMATED BURN")
                            .font(.pmKicker)
                            .tracking(0.6)
                            .foregroundStyle(.pmTextSecondary)
                        if intensity != .standard {
                            Text(intensity == .extended ? "▲" : "▼")
                                .font(.pmKicker)
                                .foregroundStyle(.pmAccentPurpleBright)
                        }
                    }
                    Text("~\(burn) kcal")
                        .font(.system(.title2, design: .default, weight: .heavy))
                        .foregroundStyle(.pmTextPrimary)
                }
                Spacer()
                if showStart {
                    Button("Start") { showLiveWorkout = true }
                        .pmPrimaryStyle(fullWidth: false)
                }
            }
            .padding(PMSpacing.md)
        }
    }

    // MARK: - Rest Day card

    private func restDayCard(dayName: String) -> some View {
        PMCard {
            HStack(spacing: PMSpacing.md) {
                Image(systemName: "moon.zzz.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.pmTextTertiary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(dayName) is a rest day")
                        .font(.pmBodyMedium)
                        .foregroundStyle(.pmTextPrimary)
                    Text("Recovery helps your body adapt and grow stronger.")
                        .font(.pmCaption)
                        .foregroundStyle(.pmTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(PMSpacing.md)
        }
    }

    // MARK: - Adaptation banner

    private func adaptationBanner(message: String) -> some View {
        PMCard {
            HStack(alignment: .top, spacing: PMSpacing.sm) {
                Image(systemName: intensity == .extended ? "arrow.up.circle" : "arrow.down.circle")
                    .font(.system(size: 15))
                    .foregroundStyle(.pmAccentPurpleBright)
                    .padding(.top, 1)
                Text(message)
                    .font(.pmCaption)
                    .foregroundStyle(.pmTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(PMSpacing.md)
        }
    }

    // MARK: - Week strip

    private var weekStrip: some View {
        PMCard {
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { day in
                    WorkoutDayCell(
                        label: dayLabels[day],
                        isWorkout: weekSchedule[day],
                        isToday: day == todayWeekdayIndex,
                        isSelected: day == selectedWorkoutDayIndex
                    ) {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            selectedWorkoutDayIndex = day
                        }
                    }
                }
            }
            .padding(.vertical, PMSpacing.md)
        }
    }

    // MARK: - Exercises

    private var exercisesSection: some View {
        VStack(spacing: PMSpacing.sm) {
            ForEach(Array(exercises.enumerated()), id: \.offset) { i, ex in
                let status: PlanExerciseStatus = i == 0 ? .upNext : .upcoming
                PlanExerciseCard(number: i + 1, exercise: ex, status: status)
            }
        }
    }
}

// MARK: - Meal Slot Card

private struct MealSlotCard: View {
    let slot: MealSlot
    let onTap: () -> Void
    let onSwap: () -> Void

    var body: some View {
        PMCard {
            VStack(alignment: .leading, spacing: PMSpacing.sm) {
                HStack {
                    Image(systemName: mealIcon)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.pmAccentPurpleBright)
                    Text(slot.mealType.displayName.uppercased())
                        .font(.pmKicker)
                        .tracking(0.6)
                        .foregroundStyle(.pmTextSecondary)
                    Spacer()
                    if slot.recipe.totalMinutes > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "clock")
                                .font(.system(size: 11))
                            Text("\(slot.recipe.totalMinutes) min")
                                .font(.pmCaption)
                        }
                        .foregroundStyle(.pmTextTertiary)
                    }
                    Button(action: onSwap) {
                        Image(systemName: "arrow.2.squarepath")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.pmTextTertiary)
                            .padding(.horizontal, PMSpacing.xxs)
                    }
                    .buttonStyle(.plain)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.pmTextTertiary)
                }

                Text(slot.recipe.name)
                    .font(.pmBodyMedium)
                    .foregroundStyle(.pmTextPrimary)

                Text(slot.recipe.macroSummary)
                    .font(.pmCaption)
                    .foregroundStyle(.pmTextSecondary)
            }
            .padding(PMSpacing.md)
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }

    private var mealIcon: String {
        switch slot.mealType {
        case .breakfast:   return "sunrise"
        case .lunch:       return "sun.max"
        case .dinner:      return "moon"
        case .snack:       return "leaf"
        case .preworkout:  return "bolt.circle"
        case .postworkout: return "checkmark.circle"
        }
    }
}

// MARK: - Grocery List Sheet

private struct GroceryListSheet: View {
    let groups: [(category: String, items: [GroceryItem])]
    @Environment(\.dismiss) private var dismiss
    @State private var checkedIds: Set<String> = []

    private var totalItems: Int  { groups.reduce(0) { $0 + $1.items.count } }
    private var checkedCount: Int { checkedIds.count }

    var body: some View {
        NavigationStack {
            List {
                ForEach(groups, id: \.category) { group in
                    Section(GroceryAggregationEngine.categoryDisplayName(group.category)) {
                        ForEach(group.items) { item in
                            let isChecked = checkedIds.contains(item.id)
                            Button {
                                if isChecked { checkedIds.remove(item.id) }
                                else         { checkedIds.insert(item.id) }
                            } label: {
                                HStack(spacing: PMSpacing.sm) {
                                    Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 20))
                                        .foregroundStyle(isChecked ? Color.pmRingMovement : Color.pmTextTertiary)
                                    Text(item.name)
                                        .font(.pmBody)
                                        .foregroundStyle(isChecked ? .pmTextTertiary : .pmTextPrimary)
                                        .strikethrough(isChecked, color: .pmTextTertiary)
                                    Spacer()
                                    Text(item.displayAmount)
                                        .font(.pmCaption)
                                        .foregroundStyle(.pmTextSecondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .background(Color.pmBackgroundPrimary.ignoresSafeArea())
            .navigationTitle("Grocery List")
            .pmLargeNavTitle()
            .toolbar {
                ToolbarItem(placement: .principal) {
                    if checkedCount > 0 {
                        Text("\(checkedCount) / \(totalItems) checked")
                            .font(.pmCaption)
                            .foregroundStyle(.pmTextSecondary)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(.pmButtonLabel)
                }
            }
        }
    }
}

// MARK: - Swap Recipe Sheet

private struct SwapRecipeSheet: View {
    let slot: MealSlot
    let alternatives: [Recipe]
    let onSelect: (Recipe) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: PMSpacing.sm) {
                    if alternatives.isEmpty {
                        PMEmptyState(
                            icon: "arrow.2.squarepath",
                            title: "No alternatives",
                            message: "No other \(slot.mealType.displayName.lowercased()) recipes match your dietary preferences."
                        )
                        .padding(.top, PMSpacing.xxl)
                    } else {
                        ForEach(alternatives) { recipe in
                            Button {
                                onSelect(recipe)
                                dismiss()
                            } label: {
                                PMCard {
                                    VStack(alignment: .leading, spacing: PMSpacing.xs) {
                                        Text(recipe.name)
                                            .font(.pmBodyMedium)
                                            .foregroundStyle(.pmTextPrimary)
                                        Text(recipe.macroSummary)
                                            .font(.pmCaption)
                                            .foregroundStyle(.pmTextSecondary)
                                        if recipe.totalMinutes > 0 {
                                            HStack(spacing: 3) {
                                                Image(systemName: "clock")
                                                    .font(.system(size: 11))
                                                Text("\(recipe.totalMinutes) min")
                                                    .font(.pmCaption)
                                            }
                                            .foregroundStyle(.pmTextTertiary)
                                        }
                                    }
                                    .padding(PMSpacing.md)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, PMSpacing.screenEdge)
                .padding(.top, PMSpacing.md)
                .padding(.bottom, PMSpacing.xxl)
            }
            .scrollIndicators(.hidden)
            .background(Color.pmBackgroundPrimary.ignoresSafeArea())
            .navigationTitle("Swap \(slot.mealType.displayName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.pmTextSecondary)
                }
            }
        }
    }
}

// MARK: - Recipe Detail Sheet

private struct RecipeDetailSheet: View {
    let recipe: Recipe
    @Environment(\.dismiss)      private var dismiss
    @Environment(\.modelContext) private var context
    @State private var didLog = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: PMSpacing.lg) {
                    recipeMetaBar
                    recipeMacroCard
                    ingredientsSection
                    instructionsSection

                    Button(didLog ? "Meal Logged" : "Log This Meal") { logMeal() }
                        .pmPrimaryStyle()
                        .disabled(didLog)
                        .animation(.easeInOut(duration: 0.2), value: didLog)
                }
                .padding(.horizontal, PMSpacing.screenEdge)
                .padding(.top, PMSpacing.md)
                .padding(.bottom, PMSpacing.xxl)
            }
            .background(Color.pmBackgroundPrimary.ignoresSafeArea())
            .navigationTitle(recipe.name)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.font(.pmButtonLabel)
                }
            }
        }
    }

    private func logMeal() {
        let entry = MealEntry(
            title: recipe.name,
            calories: recipe.calories,
            mealType: recipe.mealType
        )
        entry.proteinGrams      = recipe.proteinGrams
        entry.carbohydrateGrams = recipe.carbohydrateGrams
        entry.fatGrams          = recipe.fatGrams
        context.insert(entry)
        try? context.save()
        StreakService.creditLoggingStreak(in: context)
        AdaptationEngine.recompute(in: context)
        didLog = true
    }

    // MARK: Meta bar

    private var recipeMetaBar: some View {
        HStack(spacing: PMSpacing.lg) {
            if recipe.prepMinutes > 0 {
                RecipeMetaStat(icon: "clock", label: "Prep", value: "\(recipe.prepMinutes) min")
            }
            if recipe.cookMinutes > 0 {
                RecipeMetaStat(icon: "flame", label: "Cook", value: "\(recipe.cookMinutes) min")
            }
            RecipeMetaStat(icon: "person.2", label: "Serves", value: "\(recipe.servings)")
        }
    }

    // MARK: Macro card

    private var recipeMacroCard: some View {
        PMCard(elevated: true) {
            HStack(spacing: 0) {
                RecipeMacroCell(label: "Calories", value: "\(Int(recipe.calories))",            unit: "kcal", color: .pmRingEnergy)
                RecipeMacroCell(label: "Protein",  value: "\(Int(recipe.proteinGrams))",        unit: "g",    color: .pmAccentPurple)
                RecipeMacroCell(label: "Carbs",    value: "\(Int(recipe.carbohydrateGrams))",   unit: "g",    color: .pmRingMovement)
                RecipeMacroCell(label: "Fat",      value: "\(Int(recipe.fatGrams))",            unit: "g",    color: .pmRingHydration)
            }
            .padding(PMSpacing.md)
        }
    }

    // MARK: Ingredients

    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: PMSpacing.sm) {
            Text("INGREDIENTS")
                .font(.pmKicker)
                .tracking(0.6)
                .foregroundStyle(.pmTextSecondary)

            PMCard(elevated: true) {
                VStack(spacing: 0) {
                    ForEach(Array(recipe.ingredients.enumerated()), id: \.element.id) { i, ing in
                        if i > 0 { PMDivider().padding(.horizontal, PMSpacing.md) }
                        HStack {
                            Text(ing.name)
                                .font(.pmBody)
                                .foregroundStyle(.pmTextPrimary)
                            Spacer()
                            Text(formattedAmount(ing))
                                .font(.pmCaption)
                                .foregroundStyle(.pmTextSecondary)
                        }
                        .padding(.horizontal, PMSpacing.md)
                        .padding(.vertical, PMSpacing.sm)
                    }
                }
            }
        }
    }

    // MARK: Instructions

    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: PMSpacing.sm) {
            Text("INSTRUCTIONS")
                .font(.pmKicker)
                .tracking(0.6)
                .foregroundStyle(.pmTextSecondary)

            VStack(spacing: PMSpacing.sm) {
                ForEach(Array(recipe.instructions.enumerated()), id: \.offset) { i, step in
                    HStack(alignment: .top, spacing: PMSpacing.sm) {
                        Circle()
                            .fill(Color.pmAccentPurpleBright)
                            .frame(width: 26, height: 26)
                            .overlay(
                                Text("\(i + 1)")
                                    .font(.system(size: 12, weight: .heavy))
                                    .foregroundStyle(Color.pmBackgroundPrimary)
                            )
                        Text(step)
                            .font(.pmBody)
                            .foregroundStyle(.pmTextPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                    }
                }
            }
        }
    }

    // MARK: Helpers

    private func formattedAmount(_ ingredient: Ingredient) -> String {
        let rounded = ingredient.amount.rounded()
        if ingredient.amount == rounded {
            return "\(Int(ingredient.amount)) \(ingredient.unit)"
        }
        return String(format: "%.1f \(ingredient.unit)", ingredient.amount)
    }
}

// MARK: - Recipe detail sub-views

private struct RecipeMetaStat: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(.pmTextSecondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.pmCaptionMedium)
                    .foregroundStyle(.pmTextPrimary)
                Text(label)
                    .font(.system(size: 10))
                    .foregroundStyle(.pmTextTertiary)
            }
        }
    }
}

private struct RecipeMacroCell: View {
    let label: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(spacing: 3) {
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(color)
                Text(unit)
                    .font(.system(size: 10))
                    .foregroundStyle(.pmTextTertiary)
            }
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.pmTextSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Macro Label

private struct MacroLabel: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.pmCaptionMedium)
                    .foregroundStyle(.pmTextPrimary)
                Text(label)
                    .font(.system(size: 10))
                    .foregroundStyle(.pmTextTertiary)
            }
        }
    }
}

// MARK: - Plan Exercise Status

private enum PlanExerciseStatus { case upNext, upcoming }

// MARK: - Plan Exercise Card

private struct PlanExerciseCard: View {
    let number: Int
    let exercise: WorkoutPlanExercise
    let status: PlanExerciseStatus

    private var detail: String {
        let weight = exercise.defaultWeightKg > 0 ? " · \(Int(exercise.defaultWeightKg)) kg" : ""
        return "\(exercise.sets) sets × \(exercise.defaultReps) reps\(weight)"
    }

    var body: some View {
        PMCard {
            HStack(alignment: .center, spacing: PMSpacing.md) {
                numberBadge
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.name)
                        .font(.pmBodyMedium)
                        .foregroundStyle(.pmTextPrimary)
                    Text(detail)
                        .font(.pmCaption)
                        .foregroundStyle(.pmTextSecondary)
                }
                Spacer()
                statusBadge
            }
            .padding(PMSpacing.md)
            .opacity(status == .upcoming ? 0.55 : 1.0)
        }
    }

    private var numberBadge: some View {
        let (bg, fg): (Color, Color) = status == .upNext
            ? (.pmPillOrangeBg, .pmAccentPurple)
            : (.pmPillNeutralBg, .pmTextSecondary)
        return Circle()
            .fill(bg)
            .frame(width: 40, height: 40)
            .overlay(
                Text("\(number)")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(fg)
            )
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch status {
        case .upNext:
            Text("Up next")
                .font(.pmCaption)
                .foregroundStyle(.pmAccentPurple)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .overlay(Capsule().stroke(Color.pmDivider, lineWidth: 1))
        case .upcoming:
            EmptyView()
        }
    }
}

// MARK: - Workout Day Cell

private struct WorkoutDayCell: View {
    let label: String
    let isWorkout: Bool
    let isToday: Bool
    var isSelected: Bool = false
    var onTap: (() -> Void)? = nil

    private var accent: Color {
        isSelected ? .pmAccentPurpleBright : (isWorkout ? .pmRingMovement : .pmTextTertiary)
    }

    var body: some View {
        Button { onTap?() } label: {
            VStack(spacing: PMSpacing.xs) {
                Text(label)
                    .font(.pmCaptionMedium)
                    .foregroundStyle(isSelected ? .pmAccentPurpleBright : .pmTextSecondary)

                Circle()
                    .fill(accent.opacity(isWorkout ? 0.18 : 0.08))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: isWorkout ? "bolt.fill" : "moon.zzz")
                            .font(.system(size: 13, weight: .light))
                            .foregroundStyle(accent)
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.pmAccentPurpleBright, lineWidth: 1.5)
                            .opacity(isSelected ? 1 : 0)
                    )
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}
