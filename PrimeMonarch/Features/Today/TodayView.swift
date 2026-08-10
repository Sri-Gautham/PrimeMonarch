import SwiftData
import SwiftUI

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Query private var todayMeals: [MealEntry]
    @Query private var todayWater: [WaterEntry]
    @Query private var profiles: [UserProfile]
    @Query private var goalProfiles: [GoalProfile]
    @Query private var targets: [DailyTarget]
    @Query private var streaks: [Streak]
    @Query private var todayWorkouts: [WorkoutSession]

    init() {
        let start = Calendar.current.startOfDay(for: Date())
        let end   = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        _todayMeals = Query(
            filter: #Predicate<MealEntry> { $0.consumedAt >= start && $0.consumedAt < end },
            sort: \.consumedAt
        )
        _todayWater = Query(
            filter: #Predicate<WaterEntry> { $0.loggedAt >= start && $0.loggedAt < end },
            sort: \.loggedAt
        )
        _targets = Query(
            filter: #Predicate<DailyTarget> { $0.date >= start && $0.date < end }
        )
        _todayWorkouts = Query(
            filter: #Predicate<WorkoutSession> { $0.startedAt >= start && $0.startedAt < end && $0.isCompleted == true }
        )
    }

    private var profile: UserProfile?     { profiles.first }
    private var goalProfile: GoalProfile? { goalProfiles.first }
    private var target: DailyTarget?      { targets.first }

    private var caloriesConsumed: Double { todayMeals.reduce(0) { $0 + $1.calories } }
    private var waterConsumedMl: Double  { todayWater.reduce(0) { $0 + $1.amountMilliliters } }
    private var calorieTarget: Int       { target?.calorieTarget ?? 2000 }
    private var waterTargetMl: Int       { target?.waterTargetMilliliters ?? 2500 }
    private var stepTarget: Int          { target?.stepTarget ?? 9000 }
    private var waterCups: Int           { Int(waterConsumedMl / 250) }
    private var waterTargetCups: Int     { max(1, Int(Double(waterTargetMl) / 250.0)) }

    private var stepsToday: Int        { target?.healthKitStepsToday ?? 0 }

    private var calorieProgress: Double {
        calorieTarget > 0 ? min(caloriesConsumed / Double(calorieTarget), 1.0) : 0
    }
    private var waterProgress: Double {
        waterTargetMl > 0 ? min(waterConsumedMl / Double(waterTargetMl), 1.0) : 0
    }
    private var stepProgress: Double {
        stepTarget > 0 ? min(Double(stepsToday) / Double(stepTarget), 1.0) : 0
    }

    private var loggingStreak: Streak? { streaks.first(where: { $0.streakType == .logging }) }

    // Show rest-day option when: streak is worth preserving, afternoon, nothing logged yet, and grace available
    private var shouldShowRestDayOption: Bool {
        guard let streak = loggingStreak, streak.currentCount >= 2 else { return false }
        guard caloriesConsumed < 50 else { return false }  // haven't really logged yet
        guard Calendar.current.component(.hour, from: Date()) >= 14 else { return false }
        guard let graceDate = streak.graceUsedDate else { return true }
        let daysSince = Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: graceDate),
            to: Calendar.current.startOfDay(for: Date())
        ).day ?? 0
        return daysSince >= 7
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default:      return "Good evening"
        }
    }

    private var firstName: String? {
        profile?.displayName?.components(separatedBy: " ").first
    }

    private var initials: String {
        guard let name = profile?.displayName else { return "?" }
        let parts = name.components(separatedBy: " ")
        let f = parts.first?.first.map(String.init) ?? ""
        let l = parts.dropFirst().first?.first.map(String.init) ?? ""
        return (f + l).uppercased()
    }

    @State private var showLiveWorkout = false
    @State private var expandedMetric: MetricKind? = nil
    @State private var showRestDayConfirm = false

    enum MetricKind: Equatable { case calories, steps, water }

    private var todayIntensity: WorkoutIntensity { target?.adaptationIntensity ?? .standard }

    // A deterministic today-facing status string (no AI required).
    private var todayMotivation: String? {
        guard let target else { return nil }
        let remaining = max(0.0, Double(target.calorieTarget) - caloriesConsumed)
        let workoutDone = !todayWorkouts.isEmpty
        if caloriesConsumed == 0 && waterConsumedMl == 0 && stepsToday == 0 {
            return "Log your first meal to kick off today's goals."
        }
        if calorieProgress >= 1.0 && waterProgress >= 1.0 && stepProgress >= 1.0 {
            return workoutDone ? "All goals hit and workout done — outstanding day!" : "All three goals hit — great day!"
        }
        if workoutDone && calorieProgress < 1.0 {
            return "Workout done — fuel your recovery with \(Int(remaining)) kcal still on the table."
        }
        if remaining > 0 && remaining < 300 {
            return "Almost there — just \(Int(remaining)) kcal left for your calorie goal."
        }
        if waterProgress < 0.5 && Calendar.current.component(.hour, from: Date()) >= 14 {
            return "Afternoon check-in: you're under half your water goal."
        }
        return nil
    }

    private var todayExercises: [WorkoutPlanExercise] {
        if let generated = WorkoutVarietyService.decodeExercises(from: target?.generatedWorkoutJSON) {
            return generated.map { $0.adjusted(for: todayIntensity) }
        }
        return WorkoutPlans.exercises(for: goalProfile?.primaryGoal,
                                      intensity: todayIntensity,
                                      equipment: goalProfile?.availableEquipment ?? [])
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: PMSpacing.lg) {
                    headerRow
                        .padding(.top, PMSpacing.sm)
                        .padding(.horizontal, PMSpacing.screenEdge)

                    goalsCard
                        .padding(.horizontal, PMSpacing.screenEdge)

                    if let motivation = todayMotivation {
                        motivationCard(motivation)
                            .padding(.horizontal, PMSpacing.screenEdge)
                    }

                    if (target?.healthKitSleepMinutesLastNight ?? 0) > 0 {
                        sleepCard
                            .padding(.horizontal, PMSpacing.screenEdge)
                    }

                    workoutCard
                        .padding(.horizontal, PMSpacing.screenEdge)

                    mealsSection
                        .padding(.horizontal, PMSpacing.screenEdge)

                    if shouldShowRestDayOption {
                        restDayCard
                            .padding(.horizontal, PMSpacing.screenEdge)
                    }

                    Spacer().frame(height: PMSpacing.xxl)
                }
            }
            .scrollIndicators(.hidden)
            .background(Color.pmBackgroundPrimary.ignoresSafeArea())
            .pmHideNavBar()
        }
        .task {
            DailyTargetService.ensureTodayTarget(in: context)
        }
        .task(id: target?.id) {
            guard let t = target else { return }
            await WorkoutVarietyService.generateIfNeeded(
                for: t,
                goal: goalProfile?.primaryGoal,
                equipment: goalProfile?.availableEquipment ?? [],
                intensity: todayIntensity,
                context: context
            )
        }
        .fullScreenCover(isPresented: $showLiveWorkout) {
            LiveWorkoutView(goalProfile: goalProfile, intensity: todayIntensity,
                            precomputedExercises: todayExercises)
        }
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(greeting)\(firstName.map { ", \($0)" } ?? "")")
                    .font(.pmScreenTitle)
                    .foregroundStyle(.pmTextPrimary)
                Text(Date().formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(.pmSecondaryBody)
                    .foregroundStyle(.pmTextSecondary)
            }
            Spacer()
            Circle()
                .fill(Color.pmAccentPurpleBright)
                .frame(width: 44, height: 44)
                .overlay(
                    Text(initials)
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(Color.pmBackgroundPrimary)
                )
        }
    }

    // MARK: - Goals card

    private var goalsCard: some View {
        PMCard(elevated: true) {
            VStack(alignment: .leading, spacing: PMSpacing.md) {
                HStack {
                    Text("TODAY'S GOALS")
                        .font(.pmKicker)
                        .tracking(0.6)
                        .foregroundStyle(.pmTextSecondary)
                    Spacer()
                    if let confidence = target?.dataConfidence, confidence < 0.6 {
                        HStack(spacing: 3) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 11))
                            Text("Estimated")
                                .font(.pmKicker)
                                .tracking(0.4)
                        }
                        .foregroundStyle(.pmAccentPurpleBright.opacity(0.8))
                    }
                }

                HStack(spacing: PMSpacing.sm) {
                    GoalMetricColumn(
                        value: "\(Int(caloriesConsumed).formatted(.number))",
                        subtext: "/ \(calorieTarget.formatted(.number)) kcal",
                        progress: calorieProgress,
                        trackColor: .pmPillOrangeBg,
                        fillColor: .pmRingEnergy,
                        explanation: target?.calorieExplanation,
                        isExpanded: expandedMetric == .calories
                    )
                    .onTapGesture { toggleMetric(.calories) }

                    GoalMetricColumn(
                        value: "\(stepsToday.formatted(.number))",
                        subtext: "/ \(stepTarget.formatted(.number)) steps",
                        progress: stepProgress,
                        trackColor: .pmPillGreenBg,
                        fillColor: .pmRingMovement,
                        explanation: target?.stepExplanation,
                        isExpanded: expandedMetric == .steps
                    )
                    .onTapGesture { toggleMetric(.steps) }

                    GoalMetricColumn(
                        value: "\(waterCups)",
                        subtext: "/ \(waterTargetCups) cups",
                        progress: waterProgress,
                        trackColor: .pmPillNeutralBg,
                        fillColor: .pmRingHydration,
                        explanation: target?.waterExplanation,
                        isExpanded: expandedMetric == .water
                    )
                    .onTapGesture { toggleMetric(.water) }
                }
            }
            .padding(PMSpacing.md)
        }
    }

    private func toggleMetric(_ kind: MetricKind) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            expandedMetric = expandedMetric == kind ? nil : kind
        }
    }

    // MARK: - Rest day card

    private var restDayCard: some View {
        PMCard {
            HStack(spacing: PMSpacing.sm) {
                Image(systemName: "moon.zzz.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.pmRingHydration)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Taking a rest day?")
                        .font(.pmBodyMedium)
                        .foregroundStyle(.pmTextPrimary)
                    Text("Mark today as a rest day to preserve your \(loggingStreak?.currentCount ?? 0)-day streak. Grace days: 1 per 7 days.")
                        .font(.pmCaption)
                        .foregroundStyle(.pmTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Button("Rest Day") { showRestDayConfirm = true }
                    .font(.pmCaptionMedium)
                    .foregroundStyle(.pmAccentPurpleBright)
                    .padding(.horizontal, PMSpacing.xs)
                    .padding(.vertical, 4)
                    .overlay(Capsule().stroke(Color.pmAccentPurpleBright.opacity(0.5), lineWidth: 1))
            }
            .padding(PMSpacing.md)
        }
        .confirmationDialog("Mark today as a rest day?", isPresented: $showRestDayConfirm, titleVisibility: .visible) {
            Button("Mark Rest Day") {
                StreakService.markRestDay(in: context)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your streak will be preserved. You have 1 grace day available per 7-day window.")
        }
    }

    // MARK: - Motivation card

    private func motivationCard(_ text: String) -> some View {
        PMCard {
            HStack(alignment: .top, spacing: PMSpacing.sm) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14))
                    .foregroundStyle(.pmAccentPurpleBright)
                    .padding(.top, 1)
                Text(text)
                    .font(.pmCaption)
                    .foregroundStyle(.pmTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(PMSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Sleep card

    private var sleepCard: some View {
        let mins = target?.healthKitSleepMinutesLastNight ?? 0
        let hours = mins / 60
        let rem   = mins % 60
        let durationText = rem > 0 ? "\(hours)h \(rem)m" : "\(hours)h"
        let (label, labelColor): (String, Color) = {
            if hours >= 7 { return ("Good recovery", .pmStatusSuccess) }
            if hours >= 6 { return ("Slightly short", .pmStatusWarning) }
            return ("Consider more rest", .pmStatusError)
        }()

        return PMCard {
            HStack(spacing: PMSpacing.md) {
                Image(systemName: "bed.double.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.pmRingHydration)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text("LAST NIGHT'S SLEEP")
                        .font(.pmKicker)
                        .tracking(0.6)
                        .foregroundStyle(.pmTextSecondary)
                    HStack(alignment: .firstTextBaseline, spacing: PMSpacing.xs) {
                        Text(durationText)
                            .font(.pmCardTitle)
                            .foregroundStyle(.pmTextPrimary)
                        Text(label)
                            .font(.pmCaption)
                            .foregroundStyle(labelColor)
                    }
                }
                Spacer()
            }
            .padding(PMSpacing.md)
        }
    }

    // MARK: - Workout card

    private var workoutCard: some View {
        let exs     = todayExercises
        let mins    = WorkoutPlans.estimatedMinutes(for: goalProfile?.primaryGoal, intensity: todayIntensity)
        let title   = WorkoutPlans.title(for: goalProfile?.primaryGoal)
        let first2  = exs.prefix(2).map(\.name)
        let extras  = max(0, exs.count - 2)

        return PMCard(elevated: true) {
            VStack(alignment: .leading, spacing: PMSpacing.sm) {
                HStack {
                    Text("TODAY'S WORKOUT")
                        .font(.pmKicker)
                        .tracking(0.6)
                        .foregroundStyle(.pmTextSecondary)
                    Spacer()
                    // Adaptation badge
                    if todayIntensity != .standard {
                        HStack(spacing: 3) {
                            Image(systemName: todayIntensity == .extended ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                                .font(.system(size: 11))
                            Text(todayIntensity == .extended ? "EXTENDED" : "LIGHTENED")
                                .font(.pmKicker)
                                .tracking(0.5)
                        }
                        .foregroundStyle(.pmAccentPurpleBright)
                    }
                }

                Text(title)
                    .font(.pmCardTitle)
                    .foregroundStyle(.pmTextPrimary)

                Text("\(mins) min · \(exs.count) exercises")
                    .font(.pmSecondaryBody)
                    .foregroundStyle(.pmTextSecondary)

                HStack(spacing: PMSpacing.xs) {
                    ForEach(first2, id: \.self) { name in
                        WorkoutTag(label: name, style: .orange)
                    }
                    if extras > 0 {
                        WorkoutTag(label: "+\(extras) more", style: .neutral)
                    }
                }

                if let msg = target?.adaptationMessage {
                    Text(msg)
                        .font(.pmCaption)
                        .foregroundStyle(.pmTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button("Start Workout") { showLiveWorkout = true }
                    .pmPrimaryStyle()
                    .padding(.top, PMSpacing.xxs)
            }
            .padding(PMSpacing.md)
        }
    }

    // MARK: - Meals section

    private var mealsSection: some View {
        VStack(alignment: .leading, spacing: PMSpacing.sm) {
            Text("TODAY'S MEALS")
                .font(.pmKicker)
                .tracking(0.6)
                .foregroundStyle(.pmTextSecondary)
                .padding(.horizontal, 2)

            if todayMeals.isEmpty {
                PMCard {
                    PMEmptyState(
                        icon: "fork.knife",
                        title: "No meals logged",
                        message: "Use the Meals tab to track what you eat."
                    )
                }
            } else {
                PMCard(elevated: true) {
                    VStack(spacing: 0) {
                        ForEach(Array(todayMeals.enumerated()), id: \.element.id) { i, meal in
                            if i > 0 {
                                PMDivider()
                                    .padding(.horizontal, PMSpacing.md)
                            }
                            HomeMealRow(meal: meal)
                        }
                    }
                    .padding(.vertical, PMSpacing.xxs)
                }
            }
        }
    }
}

// MARK: - Goal Metric Column

private struct GoalMetricColumn: View {
    let value: String
    let subtext: String
    let progress: Double
    let trackColor: Color
    let fillColor: Color
    var explanation: String? = nil
    var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(.pmTextPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(subtext)
                .font(.system(size: 11))
                .foregroundStyle(.pmTextSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(trackColor).frame(height: 6)
                    Capsule()
                        .fill(fillColor)
                        .frame(width: geo.size.width * max(0, min(progress, 1)), height: 6)
                }
            }
            .frame(height: 6)

            if explanation != nil {
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.pmTextTertiary)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isExpanded)
            }

            if isExpanded, let explanation {
                Text(explanation)
                    .font(.system(size: 10))
                    .foregroundStyle(.pmTextTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

// MARK: - Workout Tag

private struct WorkoutTag: View {
    enum Style { case orange, green, neutral }
    let label: String
    let style: Style

    private var bg: Color {
        switch style {
        case .orange:  return .pmPillOrangeBg
        case .green:   return .pmPillGreenBg
        case .neutral: return .pmPillNeutralBg
        }
    }
    private var fg: Color {
        switch style {
        case .orange:  return .pmAccentPurple
        case .green:   return Color(red: 0.337, green: 0.388, blue: 0.247)
        case .neutral: return .pmTextPrimary
        }
    }

    var body: some View {
        Text(label)
            .font(.pmCaption)
            .foregroundStyle(fg)
            .padding(.horizontal, PMSpacing.sm)
            .padding(.vertical, 5)
            .background(bg)
            .clipShape(Capsule())
    }
}

// MARK: - Home Meal Row

private struct HomeMealRow: View {
    let meal: MealEntry

    var body: some View {
        HStack(spacing: PMSpacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(meal.mealType.displayName) · \(meal.title)")
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
            }
            Spacer()
            Text("Logged")
                .font(.pmCaption)
                .foregroundStyle(.pmAccentPurple)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .overlay(Capsule().stroke(Color.pmDivider, lineWidth: 1))
        }
        .padding(.horizontal, PMSpacing.md)
        .padding(.vertical, PMSpacing.sm)
    }
}
