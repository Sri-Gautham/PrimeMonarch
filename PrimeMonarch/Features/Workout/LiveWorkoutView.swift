import SwiftData
import SwiftUI

// MARK: - Live Workout View

struct LiveWorkoutView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss)      private var dismiss

    let goalProfile: GoalProfile?
    var intensity: WorkoutIntensity = .standard
    var precomputedExercises: [WorkoutPlanExercise]? = nil

    @State private var elapsedSeconds = 0
    @State private var records: [[SetRecord]] = []
    @State private var showSummary         = false
    @State private var showEndConfirm      = false
    @State private var exerciseList: [WorkoutPlanExercise] = []
    @State private var restSecondsRemaining = 0
    @State private var previousPerformance: [String: String] = [:]  // name → "3×10 @ 50 kg"
    @State private var replaceExerciseIndex: Int? = nil

    private var workoutTitle: String {
        WorkoutPlans.title(for: goalProfile?.primaryGoal)
    }

    private var equipment: [Equipment] { goalProfile?.availableEquipment ?? [] }

    private var timerLabel: String {
        String(format: "%d:%02d", elapsedSeconds / 60, elapsedSeconds % 60)
    }

    private var completedSetsCount: Int {
        records.flatMap { $0 }.filter(\.isCompleted).count
    }

    private var totalSetsCount: Int {
        exerciseList.reduce(0) { $0 + $1.sets }
    }

    private var completedExercisesCount: Int {
        records.filter { row in row.allSatisfy(\.isCompleted) }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: PMSpacing.md) {
                    progressCard
                        .padding(.top, PMSpacing.xs)

                    if restSecondsRemaining > 0 {
                        restTimerBanner
                    }

                    ForEach(Array(exerciseList.enumerated()), id: \.element.id) { i, exercise in
                        if i < records.count {
                            ExerciseSessionCard(
                                exercise: exercise,
                                records: $records[i],
                                previousPerformance: previousPerformance[exercise.name],
                                onSkip: { skipExercise(at: i) },
                                onReplace: { replaceExerciseIndex = i }
                            )
                        }
                    }

                    Button("Complete Workout") { showSummary = true }
                        .pmPrimaryStyle()
                        .padding(.top, PMSpacing.xs)
                        .padding(.bottom, PMSpacing.xxl)
                }
                .padding(.horizontal, PMSpacing.screenEdge)
            }
            .scrollIndicators(.hidden)
            .background(Color.pmBackgroundPrimary.ignoresSafeArea())
            .navigationTitle(workoutTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("End") { showEndConfirm = true }
                        .foregroundStyle(.pmTextSecondary)
                }
                ToolbarItem(placement: .principal) {
                    Text(timerLabel)
                        .font(.system(size: 17, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.pmTextPrimary)
                }
            }
            .confirmationDialog("End workout early?", isPresented: $showEndConfirm) {
                Button("Save & Exit", role: .destructive) {
                    saveSession(completed: false)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your progress so far will be saved.")
            }
        }
        .sheet(isPresented: $showSummary) {
            WorkoutSummaryView(
                title: workoutTitle,
                durationSeconds: elapsedSeconds,
                completedExercises: completedExercisesCount,
                completedSets: completedSetsCount,
                totalSets: totalSetsCount
            ) {
                saveSession(completed: true)
                dismiss()
            }
        }
        .onAppear { initExerciseList(); initRecords(); loadPreviousPerformance() }
        .task { await runTimer() }
        .onChange(of: completedSetsCount) { old, new in
            if new > old { triggerRestTimer() }
        }
        .confirmationDialog(
            replaceExerciseIndex.map { "Replace \(exerciseList[$0].name)?" } ?? "Replace exercise?",
            isPresented: Binding(get: { replaceExerciseIndex != nil }, set: { if !$0 { replaceExerciseIndex = nil } }),
            titleVisibility: .visible
        ) {
            if let idx = replaceExerciseIndex {
                let alts = WorkoutPlans.alternatives(
                    for: exerciseList[idx].muscleGroup,
                    excluding: exerciseList[idx].name,
                    equipment: equipment
                ).prefix(4)
                ForEach(Array(alts), id: \.name) { alt in
                    Button(alt.name) { replace(at: idx, with: alt) }
                }
            }
            Button("Cancel", role: .cancel) { replaceExerciseIndex = nil }
        }
    }

    // MARK: - Progress card

    private var progressCard: some View {
        PMCard(elevated: true) {
            HStack(spacing: 0) {
                LiveStatCell(value: timerLabel,                                label: "Elapsed")
                LiveStatCell(value: "\(completedSetsCount)/\(totalSetsCount)", label: "Sets done")
                LiveStatCell(value: "\(completedExercisesCount)/\(exerciseList.count)", label: "Exercises")
            }
            .padding(.vertical, PMSpacing.sm)
        }
    }

    // MARK: - Rest timer banner

    private var restTimerBanner: some View {
        PMCard {
            HStack(spacing: PMSpacing.sm) {
                Image(systemName: "timer")
                    .font(.system(size: 14))
                    .foregroundStyle(.pmAccentPurpleBright)
                Text("Rest  \(restSecondsRemaining)s")
                    .font(.system(.body, design: .monospaced, weight: .semibold))
                    .foregroundStyle(.pmTextPrimary)
                Spacer()
                Button("Skip rest") { restSecondsRemaining = 0 }
                    .font(.pmCaption)
                    .foregroundStyle(.pmTextSecondary)
            }
            .padding(PMSpacing.sm)
        }
    }

    // MARK: - Helpers

    private func initExerciseList() {
        guard exerciseList.isEmpty else { return }
        if let precomputed = precomputedExercises, !precomputed.isEmpty {
            exerciseList = precomputed
        } else {
            exerciseList = WorkoutPlans.exercises(
                for: goalProfile?.primaryGoal,
                intensity: intensity,
                equipment: equipment
            )
        }
    }

    private func initRecords() {
        records = exerciseList.map { ex in
            (0..<ex.sets).map { _ in
                SetRecord(defaultReps: ex.defaultReps, defaultWeightKg: ex.defaultWeightKg)
            }
        }
    }

    private func loadPreviousPerformance() {
        // Fetch the last completed session to show previous reps/weight per exercise
        let completedTrue = true
        let desc = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.isCompleted == completedTrue },
            sortBy: [SortDescriptor(\WorkoutSession.startedAt, order: .reverse)]
        )
        guard let sessions = try? context.fetch(desc), let last = sessions.first else { return }
        for log in last.exerciseLogs {
            let completedSets = log.sets.filter(\.isCompleted)
            guard !completedSets.isEmpty else { continue }
            let avgReps = completedSets.compactMap(\.reps).reduce(0, +) / max(1, completedSets.count)
            let avgWeight = completedSets.compactMap(\.weightKilograms).reduce(0, +) / Double(max(1, completedSets.count))
            let detail = avgWeight > 0
                ? "\(completedSets.count)×\(avgReps) @ \(Int(avgWeight)) kg"
                : "\(completedSets.count)×\(avgReps)"
            previousPerformance[log.exerciseName] = detail
        }
    }

    private func triggerRestTimer(duration: Int = 60) {
        restSecondsRemaining = duration
        Task {
            while restSecondsRemaining > 0 && !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                if restSecondsRemaining > 0 { restSecondsRemaining -= 1 }
            }
        }
    }

    private func skipExercise(at index: Int) {
        guard index < records.count else { return }
        for i in records[index].indices {
            records[index][i].isCompleted = true
        }
    }

    private func replace(at index: Int, with alternative: WorkoutPlanExercise) {
        guard index < exerciseList.count else { return }
        exerciseList[index] = alternative
        records[index] = (0..<alternative.sets).map { _ in
            SetRecord(defaultReps: alternative.defaultReps, defaultWeightKg: alternative.defaultWeightKg)
        }
        replaceExerciseIndex = nil
    }

    private func runTimer() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(1))
            elapsedSeconds += 1
        }
    }

    private func saveSession(completed: Bool) {
        let session = WorkoutSession(
            title: workoutTitle,
            workoutGoal: WorkoutPlans.workoutGoalType(for: goalProfile?.primaryGoal)
        )
        session.endedAt                  = Date()
        session.isCompleted              = completed
        session.durationSeconds          = Double(elapsedSeconds)
        session.totalEnergyKilocalories  = Double(elapsedSeconds) / 60.0 * 5.5  // ~5.5 kcal/min

        context.insert(session)

        for (exIdx, exercise) in exerciseList.enumerated() {
            let exLog = ExerciseLog(exerciseName: exercise.name, orderIndex: exIdx)
            context.insert(exLog)

            if exIdx < records.count {
                for (setIdx, record) in records[exIdx].enumerated() {
                    let setLog = ExerciseSetLog(setNumber: setIdx + 1)
                    setLog.reps             = Int(record.reps)
                    setLog.weightKilograms  = Double(record.weightKg)
                    setLog.isCompleted      = record.isCompleted
                    if record.isCompleted { setLog.completedAt = Date() }
                    context.insert(setLog)
                    exLog.sets.append(setLog)
                }
            }
            session.exerciseLogs.append(exLog)
        }

        try? context.save()

        if completed {
            AdaptationEngine.recompute(in: context)
            AchievementService.evaluate(in: context)
        }
    }
}

// MARK: - Exercise Session Card

private struct ExerciseSessionCard: View {
    let exercise: WorkoutPlanExercise
    @Binding var records: [SetRecord]
    var previousPerformance: String? = nil
    var onSkip: (() -> Void)? = nil
    var onReplace: (() -> Void)? = nil

    private var isDone: Bool { records.allSatisfy(\.isCompleted) }
    private var isBodyweight: Bool { exercise.defaultWeightKg == 0 }

    var body: some View {
        PMCard(elevated: true) {
            VStack(alignment: .leading, spacing: PMSpacing.sm) {
                // Header row
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(exercise.name)
                            .font(.pmCardTitle)
                            .foregroundStyle(.pmTextPrimary)
                        HStack(spacing: PMSpacing.xs) {
                            Text(exercise.muscleGroup)
                                .font(.pmCaption)
                                .foregroundStyle(.pmTextSecondary)
                            if let prev = previousPerformance {
                                Text("·")
                                    .font(.pmCaption)
                                    .foregroundStyle(.pmTextTertiary)
                                Text("Last: \(prev)")
                                    .font(.pmCaption)
                                    .foregroundStyle(.pmTextTertiary)
                            }
                        }
                    }
                    Spacer()
                    if isDone {
                        Text("Done")
                            .font(.pmCaption)
                            .foregroundStyle(Color(red: 0.337, green: 0.388, blue: 0.247))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(Color.pmPillGreenBg)
                            .clipShape(Capsule())
                    } else {
                        Menu {
                            Button { onSkip?() }    label: { Label("Skip exercise", systemImage: "forward.fill") }
                            Button { onReplace?() } label: { Label("Replace exercise", systemImage: "arrow.2.squarepath") }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.pmTextSecondary)
                                .frame(width: 32, height: 32)
                        }
                    }
                }

                if isDone {
                    Text("\(records.filter(\.isCompleted).count) of \(exercise.sets) sets completed")
                        .font(.pmSecondaryBody)
                        .foregroundStyle(.pmTextSecondary)
                } else {
                    // Column headers
                    HStack {
                        Text("SET").font(.pmKicker).tracking(0.4)
                            .frame(width: 28, alignment: .leading)
                        Text(isBodyweight ? "BODYWEIGHT" : "KG").font(.pmKicker).tracking(0.4)
                            .frame(maxWidth: .infinity)
                        Text("REPS").font(.pmKicker).tracking(0.4)
                            .frame(maxWidth: .infinity)
                        Spacer().frame(width: 36)
                    }
                    .foregroundStyle(.pmTextSecondary)

                    PMDivider()

                    ForEach(records.indices, id: \.self) { i in
                        if i > 0 { PMDivider() }
                        SetInputRow(
                            setNumber: i + 1,
                            record: $records[i],
                            isBodyweight: isBodyweight
                        )
                    }
                }
            }
            .padding(PMSpacing.md)
        }
    }
}

// MARK: - Set Input Row

private struct SetInputRow: View {
    let setNumber: Int
    @Binding var record: SetRecord
    let isBodyweight: Bool

    var body: some View {
        HStack(spacing: PMSpacing.xs) {
            Text("\(setNumber)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.pmTextSecondary)
                .frame(width: 28, alignment: .leading)

            if isBodyweight {
                Text("BW")
                    .font(.pmCaption)
                    .foregroundStyle(.pmTextSecondary)
                    .frame(maxWidth: .infinity)
            } else {
                TextField("kg", text: $record.weightKg)
                    .pmKeyboardType(isNumeric: true)
                    .font(.pmBody)
                    .foregroundStyle(.pmTextPrimary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5)
                    .background(Color.pmPillNeutralBg)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            TextField("reps", text: $record.reps)
                .pmKeyboardType(isNumeric: true)
                .font(.pmBody)
                .foregroundStyle(.pmTextPrimary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(Color.pmPillNeutralBg)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            Button {
                record.isCompleted.toggle()
            } label: {
                Circle()
                    .fill(record.isCompleted ? Color.pmRingMovement : Color.pmPillNeutralBg)
                    .frame(width: 34, height: 34)
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.pmBackgroundPrimary)
                            .opacity(record.isCompleted ? 1 : 0.25)
                    )
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Live Stat Cell

private struct LiveStatCell: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 17, weight: .heavy))
                .foregroundStyle(.pmTextPrimary)
                .minimumScaleFactor(0.8)
                .lineLimit(1)
            Text(label)
                .font(.pmCaption)
                .foregroundStyle(.pmTextSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Workout Summary View

struct WorkoutSummaryView: View {
    let title: String
    let durationSeconds: Int
    let completedExercises: Int
    let completedSets: Int
    let totalSets: Int
    let onDone: () -> Void

    private var durationString: String {
        let m = durationSeconds / 60
        let s = durationSeconds % 60
        return m > 0 ? "\(m)m \(s)s" : "\(s)s"
    }

    private var estimatedKcal: Int {
        max(1, Int(Double(durationSeconds) / 60.0 * 5.5))
    }

    var body: some View {
        VStack(spacing: PMSpacing.lg) {
            Spacer()

            Circle()
                .fill(Color.pmPillOrangeBg)
                .frame(width: 80, height: 80)
                .overlay(
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(.pmAccentPurpleBright)
                )

            VStack(spacing: PMSpacing.xs) {
                Text("Workout Complete!")
                    .font(.pmScreenTitle)
                    .foregroundStyle(.pmTextPrimary)
                Text(title)
                    .font(.pmSecondaryBody)
                    .foregroundStyle(.pmTextSecondary)
            }

            PMCard(elevated: true) {
                HStack(spacing: 0) {
                    SummaryStatCell(value: durationString,       label: "Duration")
                    SummaryStatCell(value: "\(completedSets)/\(totalSets)", label: "Sets")
                    SummaryStatCell(value: "~\(estimatedKcal) kcal", label: "Burned")
                }
                .padding(.vertical, PMSpacing.md)
            }
            .padding(.horizontal, PMSpacing.screenEdge)

            Spacer()

            Button("Done") { onDone() }
                .pmPrimaryStyle()
                .padding(.horizontal, PMSpacing.screenEdge)
                .padding(.bottom, PMSpacing.xl)
        }
        .background(Color.pmBackgroundPrimary.ignoresSafeArea())
        .interactiveDismissDisabled()
    }
}

private struct SummaryStatCell: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 16, weight: .heavy))
                .foregroundStyle(.pmTextPrimary)
                .minimumScaleFactor(0.75)
                .lineLimit(1)
            Text(label)
                .font(.pmCaption)
                .foregroundStyle(.pmTextSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}
