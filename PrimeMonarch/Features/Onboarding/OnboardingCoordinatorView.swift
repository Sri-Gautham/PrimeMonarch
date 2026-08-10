import SwiftUI
import SwiftData

struct OnboardingCoordinatorView: View {
    @Environment(AppCoordinator.self) private var appCoordinator
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.modelContext) private var modelContext

    // Navigation
    @State private var step = 0
    private let totalSteps = 7

    // Step 1 — Goals
    @State private var selectedGoals: Set<GoalType> = []
    @State private var primaryGoal: GoalType = .maintainHealth

    // Step 2 — Personal Profile
    @State private var dateOfBirth: Date = Self.yearsAgo(25)
    @State private var biologicalSex: BiologicalSex = .male
    @State private var heightCm: Double = 170
    @State private var weightKg: Double = 70
    @State private var targetWeightKg: Double? = nil
    @State private var weightUnit: WeightUnit = .kilograms

    // Step 3 — Activity
    @State private var activityLevel: ActivityLevel = .moderatelyActive
    @State private var selectedEquipment: Set<Equipment> = []
    @State private var workoutDaysPerWeek: Int = 3
    @State private var workoutDurationMinutes: Int = 45

    // Step 4 — Food Preferences
    @State private var selectedDietaryStyles: Set<DietaryStyle> = [.noRestrictions]
    @State private var mealsPerDay: Int = 3

    // Step 5 — Schedule
    @State private var wakeDate: Date = Self.makeTime(hour: 7)
    @State private var sleepDate: Date = Self.makeTime(hour: 23)
    @State private var workoutDate: Date = Self.makeTime(hour: 8)
    @State private var selectedWorkdays: Set<Int> = [1, 2, 3, 4, 5]

    var body: some View {
        ZStack {
            Color.pmBackgroundPrimary.ignoresSafeArea()
            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, PMSpacing.screenEdge)
                    .padding(.top, PMSpacing.sm)
                    .padding(.bottom, PMSpacing.sm)
                currentStepView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                continueButton
                    .padding(.horizontal, PMSpacing.screenEdge)
                    .padding(.bottom, PMSpacing.xxxl)
                    .padding(.top, PMSpacing.sm)
            }
        }
    }

    // MARK: Top bar

    @ViewBuilder
    private var topBar: some View {
        HStack(spacing: PMSpacing.sm) {
            if step > 0 {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) { step -= 1 }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.pmTextSecondary)
                        .frame(width: PMSpacing.minTapTarget, height: PMSpacing.minTapTarget)
                }
            } else {
                Spacer().frame(width: PMSpacing.minTapTarget)
            }
            ProgressView(value: Double(step + 1), total: Double(totalSteps))
                .tint(Color.pmAccentPurpleBright)
            Text("\(step + 1) of \(totalSteps)")
                .font(.pmCaption)
                .foregroundStyle(.pmTextTertiary)
                .frame(width: 48, alignment: .trailing)
        }
    }

    // MARK: Step routing

    @ViewBuilder
    private var currentStepView: some View {
        switch step {
        case 0:
            GoalsStepView(selectedGoals: $selectedGoals, primaryGoal: $primaryGoal)
        case 1:
            PersonalProfileStepView(
                dateOfBirth: $dateOfBirth, biologicalSex: $biologicalSex,
                heightCm: $heightCm, weightKg: $weightKg,
                targetWeightKg: $targetWeightKg, weightUnit: $weightUnit
            )
        case 2:
            ActivityStepView(
                activityLevel: $activityLevel, selectedEquipment: $selectedEquipment,
                workoutDaysPerWeek: $workoutDaysPerWeek, workoutDurationMinutes: $workoutDurationMinutes
            )
        case 3:
            FoodPreferencesStepView(selectedDietaryStyles: $selectedDietaryStyles, mealsPerDay: $mealsPerDay)
        case 4:
            ScheduleStepView(
                wakeDate: $wakeDate, sleepDate: $sleepDate,
                workoutDate: $workoutDate, selectedWorkdays: $selectedWorkdays
            )
        case 5:
            HealthKitExplainerStepView()
        default:
            InitialPlanStepView(
                bmr: bmr, tdee: tdee, calorieTarget: calorieTarget,
                primaryGoal: primaryGoal, biologicalSex: biologicalSex
            )
        }
    }

    // MARK: Continue button

    private var isContinueDisabled: Bool {
        switch step {
        case 0: return selectedGoals.isEmpty
        case 1: return heightCm < 100 || weightKg < 30
        default: return false
        }
    }

    private var continueLabel: String { step == totalSteps - 1 ? "Let's go!" : "Continue" }

    private var continueButton: some View {
        Button(continueLabel) { handleContinue() }
            .buttonStyle(PMPrimaryButtonStyle())
            .disabled(isContinueDisabled)
    }

    // MARK: Navigation

    private func handleContinue() {
        saveCurrentStep()
        if step < totalSteps - 1 {
            withAnimation(.easeInOut(duration: 0.25)) { step += 1 }
        } else {
            completeOnboarding()
        }
    }

    private func saveCurrentStep() {
        switch step {
        case 0: saveGoals()
        case 1: saveProfile()
        case 2: saveActivity()
        case 3: saveFoodPreferences()
        case 4: saveSchedule()
        default: break
        }
    }

    // MARK: Persistence helpers

    private func saveGoals() {
        let gp = fetchOrCreate(GoalProfile.self)
        let list = Array(selectedGoals)
        if !list.contains(primaryGoal), let first = list.first { primaryGoal = first }
        if !list.contains(primaryGoal) { primaryGoal = list.first ?? .maintainHealth }
        gp.goals = list
        gp.primaryGoal = primaryGoal
        gp.updatedAt = Date()
        try? modelContext.save()
    }

    private func saveProfile() {
        let p = fetchOrCreate(UserProfile.self)
        p.dateOfBirth = dateOfBirth
        p.biologicalSex = biologicalSex
        p.heightCentimeters = heightCm
        p.currentWeightKilograms = weightKg
        p.targetWeightKilograms = targetWeightKg
        p.preferredWeightUnit = weightUnit
        p.onboardingStep = max(p.onboardingStep, 2)
        p.updatedAt = Date()
        try? modelContext.save()
    }

    private func saveActivity() {
        let gp = fetchOrCreate(GoalProfile.self)
        gp.activityLevel = activityLevel
        gp.availableEquipment = Array(selectedEquipment)
        gp.workoutDaysPerWeek = workoutDaysPerWeek
        gp.preferredWorkoutDurationMinutes = workoutDurationMinutes
        gp.updatedAt = Date()
        try? modelContext.save()
    }

    private func saveFoodPreferences() {
        let prefs = fetchOrCreate(UserPreference.self)
        prefs.dietaryStyles = Array(selectedDietaryStyles)
        prefs.mealsPerDay = mealsPerDay
        prefs.updatedAt = Date()
        try? modelContext.save()
    }

    private func saveSchedule() {
        let prefs = fetchOrCreate(UserPreference.self)
        let cal = Calendar.current
        prefs.wakeHour = cal.component(.hour, from: wakeDate)
        prefs.wakeMinute = cal.component(.minute, from: wakeDate)
        prefs.sleepHour = cal.component(.hour, from: sleepDate)
        prefs.sleepMinute = cal.component(.minute, from: sleepDate)
        prefs.workoutTimeHour = cal.component(.hour, from: workoutDate)
        prefs.workoutTimeMinute = cal.component(.minute, from: workoutDate)
        prefs.workdays = Array(selectedWorkdays).sorted()
        prefs.updatedAt = Date()
        try? modelContext.save()
    }

    private func completeOnboarding() {
        saveGoals(); saveProfile(); saveActivity(); saveFoodPreferences(); saveSchedule()
        let p = fetchOrCreate(UserProfile.self)
        _ = fetchOrCreate(XPLedger.self)
        // Sync auth identity to the persistent profile record.
        // environment.authService.session holds the live session created in AuthView.
        let session = environment.authService.session
        p.isGuest = session.isGuest
        if let name  = session.displayName          { p.displayName          = name  }
        if let uid   = session.supabaseUserId        { p.supabaseUserId        = uid   }
        if let appleId = session.appleUserIdentifier { p.appleUserIdentifier  = appleId }
        p.onboardingCompleted = true
        p.onboardingStep = totalSteps
        p.updatedAt = Date()
        try? modelContext.save()
        appCoordinator.handleOnboardingComplete()
    }

    private func fetchOrCreate<T: PersistentModel & AnyObject>(_ type: T.Type) -> T where T: DefaultInit {
        if let existing = try? modelContext.fetch(FetchDescriptor<T>()).first { return existing }
        let new = T()
        modelContext.insert(new)
        return new
    }

    // MARK: Calculations

    var bmr: Double? {
        let age = Calendar.current.dateComponents([.year], from: dateOfBirth, to: Date()).year ?? 0
        guard age > 0 else { return nil }
        let base = (10 * weightKg) + (6.25 * heightCm) - (5 * Double(age))
        return biologicalSex == .male ? base + 5 : base - 161
    }

    var tdee: Double? {
        guard let b = bmr else { return nil }
        return b * activityLevel.tdeeMultiplier
    }

    var calorieTarget: Int {
        guard let t = tdee else { return 2000 }
        var target = t
        switch primaryGoal {
        case .loseWeight, .reduceFat: target = t - 500
        case .buildMuscle: target = t + 250
        default: break
        }
        // SAFETY: Requires professional nutrition review before shipping
        let minimum: Double = biologicalSex == .male ? 1500 : 1200
        return Int(max(target, minimum))
    }

    // MARK: Helpers

    private static func yearsAgo(_ n: Int) -> Date {
        Calendar.current.date(byAdding: .year, value: -n, to: Date()) ?? Date()
    }

    private static func makeTime(hour: Int, minute: Int = 0) -> Date {
        var c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        c.hour = hour; c.minute = minute; c.second = 0
        return Calendar.current.date(from: c) ?? Date()
    }
}

// Marker protocol so fetchOrCreate can call T()
protocol DefaultInit { init() }
extension UserProfile: DefaultInit {}
extension GoalProfile: DefaultInit {}
extension UserPreference: DefaultInit {}
extension XPLedger: DefaultInit {}
