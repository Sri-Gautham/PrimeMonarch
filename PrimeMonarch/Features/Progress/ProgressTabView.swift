import Charts
import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct ProgressTabView: View {
    @Query(sort: \WeightEntry.loggedAt, order: .reverse) private var weightEntries: [WeightEntry]
    @Query private var streaks: [Streak]
    @Query private var goalProfiles: [GoalProfile]
    @Query private var profiles: [UserProfile]
    @Query private var thisWeekMeals: [MealEntry]
    @Query private var thisWeekWorkouts: [WorkoutSession]
    @Query private var thisWeekTargets: [DailyTarget]
    @Query(sort: \DailySummary.date, order: .reverse) private var summaries: [DailySummary]
    @Query(sort: \BodyMeasurement.loggedAt, order: .reverse) private var measurements: [BodyMeasurement]
    @Query(sort: \ProgressPhoto.takenAt, order: .reverse) private var progressPhotos: [ProgressPhoto]
    @Query private var recentWorkouts: [WorkoutSession]

    init() {
        let cal      = Calendar.current
        let today    = cal.startOfDay(for: Date())
        let weekAgo  = cal.date(byAdding: .day, value: -7, to: today)!
        let tomorrow = cal.date(byAdding: .day, value: 1, to: today)!
        _thisWeekMeals = Query(
            filter: #Predicate<MealEntry> { $0.consumedAt >= weekAgo && $0.consumedAt < tomorrow }
        )
        let completed = true
        _thisWeekWorkouts = Query(
            filter: #Predicate<WorkoutSession> {
                $0.isCompleted == completed && $0.startedAt >= weekAgo && $0.startedAt < tomorrow
            }
        )
        _thisWeekTargets = Query(
            filter: #Predicate<DailyTarget> { $0.date >= weekAgo && $0.date < tomorrow }
        )
        _recentWorkouts = Query(
            filter: #Predicate<WorkoutSession> { $0.isCompleted == completed },
            sort: \WorkoutSession.startedAt,
            order: .reverse
        )
    }

    private var profile: UserProfile?     { profiles.first }
    private var goalProfile: GoalProfile? { goalProfiles.first }
    private var weightUnit: WeightUnit    { profile?.preferredWeightUnit ?? .kilograms }

    private var avgDailyStepsText: String {
        let daysWithData = thisWeekTargets.filter { $0.healthKitStepsToday > 0 }
        guard !daysWithData.isEmpty else { return "—" }
        let avg = daysWithData.reduce(0) { $0 + $1.healthKitStepsToday } / daysWithData.count
        return avg.formatted(.number)
    }

    private var streak: Streak? {
        streaks.first(where: { $0.streakType == .logging }) ?? streaks.first
    }
    private var streakCount: Int { streak?.currentCount ?? 0 }

    // Oldest → newest (last 30 entries)
    private var chartEntries: [WeightEntry] { Array(weightEntries.prefix(30).reversed()) }

    private func movingAverage(at index: Int) -> Double? {
        let window = min(7, index + 1)
        let slice  = chartEntries[max(0, index - window + 1)...index]
        guard !slice.isEmpty else { return nil }
        return slice.reduce(0) { $0 + $1.weightKilograms } / Double(slice.count)
    }

    private var trendDelta: Double? {
        guard chartEntries.count >= 2 else { return nil }
        return chartEntries.last!.weightKilograms - chartEntries.first!.weightKilograms
    }

    private var trendColor: Color {
        guard let d = trendDelta else { return .pmTextPrimary }
        return d < 0 ? .pmStatusSuccess : .pmStatusError
    }

    private var trendText: String {
        guard let d = trendDelta else { return "" }
        let display = weightUnit == .kilograms ? abs(d) : abs(d) * 2.20462
        let unit    = weightUnit == .kilograms ? "kg" : "lb"
        return String(format: "%@%.1f %@", d < 0 ? "↓ " : "↑ ", display, unit)
    }

    private var weightChange: Double? {
        guard weightEntries.count >= 2 else { return nil }
        return weightEntries.first!.weightKilograms - weightEntries.last!.weightKilograms
    }

    private var weightChangeText: String {
        guard let change = weightChange else { return "—" }
        let abs_kg = abs(change)
        let display = weightUnit == .kilograms ? abs_kg : abs_kg * 2.20462
        let unit    = weightUnit == .kilograms ? "kg" : "lb"
        return String(format: "%@%.1f %@", change < 0 ? "-" : "+", display, unit)
    }

    private var weightChangeColor: Color {
        guard let change = weightChange else { return .pmTextPrimary }
        return change < 0 ? .pmStatusSuccess : .pmStatusError
    }

    private var totalXP: Int { summaries.reduce(0) { $0 + $1.xpAwarded } }

    private var yesterdaySummary: DailySummary? { summaries.first }

    private var milestoneText: String? {
        if streakCount >= 7 {
            return "You've built a \(streakCount)-day streak — keep the momentum going!"
        }
        if let change = weightChange, change < -0.9 {
            let abs_kg = abs(change)
            let display = weightUnit == .kilograms ? abs_kg : abs_kg * 2.20462
            let unit    = weightUnit == .kilograms ? "kg" : "lb"
            return String(format: "You've lost %.1f %@ since you started!", display, unit)
        }
        return nil
    }

    @State private var selectedPhoto: ProgressPhoto? = nil
    @State private var showAddPhoto: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: PMSpacing.lg) {
                    statsGrid
                        .padding(.horizontal, PMSpacing.screenEdge)

                    if !chartEntries.isEmpty {
                        weightChartCard
                            .padding(.horizontal, PMSpacing.screenEdge)
                    }

                    activityCard
                        .padding(.horizontal, PMSpacing.screenEdge)

                    if let summary = yesterdaySummary {
                        yesterdaySummaryCard(summary: summary)
                            .padding(.horizontal, PMSpacing.screenEdge)
                    }

                    if let milestone = milestoneText {
                        highlightCard(text: milestone)
                            .padding(.horizontal, PMSpacing.screenEdge)
                    }

                    if !recentWorkouts.isEmpty {
                        workoutHistoryCard
                            .padding(.horizontal, PMSpacing.screenEdge)
                    }

                    if !latestMeasurements.isEmpty {
                        measurementsCard
                            .padding(.horizontal, PMSpacing.screenEdge)
                    }

                    if !progressPhotos.isEmpty {
                        progressPhotosCard
                            .padding(.horizontal, PMSpacing.screenEdge)
                    }

                    Spacer().frame(height: PMSpacing.xxl)
                }
                .padding(.top, PMSpacing.md)
            }
            .scrollIndicators(.hidden)
            .background(Color.pmBackgroundPrimary.ignoresSafeArea())
            .navigationTitle("Progress")
            .pmLargeNavTitle()
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddPhoto = true
                    } label: {
                        Image(systemName: "camera")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.pmAccentPurpleBright)
                    }
                }
            }
        }
        .sheet(item: $selectedPhoto) { photo in
            FullScreenPhotoView(photo: photo)
        }
        .sheet(isPresented: $showAddPhoto) {
            AddProgressPhotoSheet()
        }
    }

    // MARK: - Stats grid

    private var statsGrid: some View {
        VStack(spacing: PMSpacing.sm) {
            HStack(spacing: PMSpacing.sm) {
                ProgressStatCard(
                    kicker: "Streak",
                    value: "\(streakCount) days",
                    valueColor: streakCount > 0 ? .pmRingEnergy : .pmTextPrimary
                )
                ProgressStatCard(
                    kicker: "Weight change",
                    value: weightChangeText,
                    valueColor: weightChangeColor
                )
            }
            if totalXP > 0 {
                ProgressStatCard(
                    kicker: "Total XP earned",
                    value: "\(totalXP.formatted(.number)) XP",
                    valueColor: .pmAccentPurpleBright
                )
            }
        }
    }

    // MARK: - Weight chart

    private var weightChartCard: some View {
        PMCard(elevated: true) {
            VStack(alignment: .leading, spacing: PMSpacing.sm) {
                HStack(alignment: .firstTextBaseline) {
                    Text("WEIGHT TREND · \(chartEntries.count) ENTRIES")
                        .font(.pmKicker)
                        .tracking(0.6)
                        .foregroundStyle(.pmTextSecondary)
                    Spacer()
                    if !trendText.isEmpty {
                        Text(trendText)
                            .font(.pmKicker)
                            .tracking(0.4)
                            .foregroundStyle(trendColor)
                    }
                }

                Chart {
                    ForEach(Array(chartEntries.enumerated()), id: \.element.id) { i, entry in
                        let displayWeight = weightUnit == .kilograms
                            ? entry.weightKilograms
                            : entry.weightKilograms * 2.20462

                        LineMark(
                            x: .value("Date", entry.loggedAt),
                            y: .value("Weight", displayWeight)
                        )
                        .foregroundStyle(Color.pmRingMovement)
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Date", entry.loggedAt),
                            y: .value("Weight", displayWeight)
                        )
                        .foregroundStyle(Color.pmRingMovement)
                        .symbolSize(24)

                        if let avg = movingAverage(at: i) {
                            let displayAvg = weightUnit == .kilograms ? avg : avg * 2.20462
                            LineMark(
                                x: .value("Date", entry.loggedAt),
                                y: .value("7-day avg", displayAvg)
                            )
                            .foregroundStyle(Color.pmRingEnergy.opacity(0.6))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                            .interpolationMethod(.catmullRom)
                        }
                    }
                }
                .frame(height: 130)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 3)) { value in
                        if let date = value.as(Date.self) {
                            AxisValueLabel {
                                Text(date.formatted(.dateTime.month(.abbreviated).day()))
                                    .font(.pmCaption)
                                    .foregroundStyle(Color.pmTextSecondary)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(Color.pmDivider)
                        if let v = value.as(Double.self) {
                            AxisValueLabel {
                                Text(String(format: "%.0f", v))
                                    .font(.pmCaption)
                                    .foregroundStyle(Color.pmTextSecondary)
                            }
                        }
                    }
                }

                // Legend
                HStack(spacing: PMSpacing.sm) {
                    HStack(spacing: 4) {
                        Circle().fill(Color.pmRingMovement).frame(width: 8, height: 8)
                        Text("Weight").font(.pmCaption).foregroundStyle(.pmTextSecondary)
                    }
                    HStack(spacing: 4) {
                        Rectangle()
                            .fill(Color.pmRingEnergy.opacity(0.6))
                            .frame(width: 14, height: 2)
                        Text("7-day avg").font(.pmCaption).foregroundStyle(.pmTextSecondary)
                    }
                }
            }
            .padding(PMSpacing.md)
        }
    }

    // MARK: - Activity card

    private var activityCard: some View {
        PMCard(elevated: true) {
            VStack(alignment: .leading, spacing: PMSpacing.md) {
                Text("THIS WEEK'S ACTIVITY")
                    .font(.pmKicker)
                    .tracking(0.6)
                    .foregroundStyle(.pmTextSecondary)

                VStack(spacing: PMSpacing.sm) {
                    ActivityRow(label: "Workouts completed",
                                value: "\(thisWeekWorkouts.count) / \(goalProfile?.workoutDaysPerWeek ?? 3)")
                    PMDivider()
                    ActivityRow(label: "Avg. daily steps", value: avgDailyStepsText)
                    PMDivider()
                    ActivityRow(label: "Meals logged", value: "\(thisWeekMeals.count) / 21")
                }
            }
            .padding(PMSpacing.md)
        }
    }

    // MARK: - Yesterday summary card

    private func yesterdaySummaryCard(summary: DailySummary) -> some View {
        PMCard(elevated: true) {
            VStack(alignment: .leading, spacing: PMSpacing.md) {
                HStack {
                    Text("YESTERDAY'S SUMMARY")
                        .font(.pmKicker)
                        .tracking(0.6)
                        .foregroundStyle(.pmTextSecondary)
                    Spacer()
                    Text("+\(summary.xpAwarded) XP")
                        .font(.pmKicker)
                        .tracking(0.4)
                        .foregroundStyle(.pmAccentPurpleBright)
                }

                VStack(spacing: PMSpacing.sm) {
                    SummaryRow(
                        label: "Calories",
                        value: "\(Int(summary.caloriesConsumed)) / \(summary.calorieTargetAtClose) kcal",
                        complete: summary.calorieCompletionPercent >= 0.85
                    )
                    PMDivider()
                    SummaryRow(
                        label: "Water",
                        value: "\(Int(summary.waterConsumedMilliliters / 250)) / \(Int(Double(summary.waterTargetAtClose) / 250)) cups",
                        complete: summary.waterCompletionPercent >= 0.9
                    )
                    PMDivider()
                    SummaryRow(
                        label: "Steps",
                        value: summary.stepsCompleted > 0
                            ? "\(summary.stepsCompleted.formatted(.number)) / \(summary.stepTargetAtClose.formatted(.number))"
                            : "—",
                        complete: summary.stepCompletionPercent >= 0.9
                    )
                    PMDivider()
                    SummaryRow(
                        label: "Workout",
                        value: summary.workoutsCompleted > 0 ? "Completed" : "Skipped",
                        complete: summary.workoutsCompleted > 0
                    )
                }

                if let msg = summary.motivationalSummary {
                    Text(msg)
                        .font(.pmCaption)
                        .foregroundStyle(.pmTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(PMSpacing.md)
        }
    }

    // MARK: - Workout history card

    @State private var expandedWorkoutId: UUID? = nil

    private var workoutHistoryCard: some View {
        PMCard(elevated: true) {
            VStack(alignment: .leading, spacing: PMSpacing.md) {
                HStack {
                    Text("WORKOUT HISTORY")
                        .font(.pmKicker)
                        .tracking(0.6)
                        .foregroundStyle(.pmTextSecondary)
                    Spacer()
                    Text("\(recentWorkouts.count)")
                        .font(.pmKicker)
                        .tracking(0.4)
                        .foregroundStyle(.pmAccentPurpleBright)
                }

                VStack(spacing: PMSpacing.sm) {
                    ForEach(Array(recentWorkouts.prefix(8).enumerated()), id: \.element.id) { i, session in
                        if i > 0 { PMDivider() }
                        WorkoutHistoryRow(
                            session: session,
                            weightUnit: weightUnit,
                            isExpanded: expandedWorkoutId == session.id
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                expandedWorkoutId = expandedWorkoutId == session.id ? nil : session.id
                            }
                        }
                    }
                }
            }
            .padding(PMSpacing.md)
        }
    }

    // MARK: - Measurements helpers

    private var latestMeasurements: [(site: String, valueCm: Double, date: Date)] {
        var seen = Set<String>()
        var result: [(site: String, valueCm: Double, date: Date)] = []
        for m in measurements where !seen.contains(m.siteRawValue) {
            seen.insert(m.siteRawValue)
            result.append((site: m.displayName, valueCm: m.valueCentimeters, date: m.loggedAt))
        }
        return result
    }

    private var usesImperial: Bool { profile?.preferredWeightUnit == .pounds }

    private func formatMeasurement(_ cm: Double) -> String {
        if usesImperial {
            return String(format: "%.1f in", cm / 2.54)
        }
        return String(format: "%.1f cm", cm)
    }

    // MARK: - Measurements card

    private var measurementsCard: some View {
        PMCard(elevated: true) {
            VStack(alignment: .leading, spacing: PMSpacing.md) {
                Text("BODY MEASUREMENTS")
                    .font(.pmKicker)
                    .tracking(0.6)
                    .foregroundStyle(.pmTextSecondary)

                VStack(spacing: PMSpacing.sm) {
                    ForEach(Array(latestMeasurements.enumerated()), id: \.offset) { i, entry in
                        if i > 0 { PMDivider() }
                        HStack {
                            Text(entry.site)
                                .font(.pmSecondaryBody)
                                .foregroundStyle(.pmTextPrimary)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(formatMeasurement(entry.valueCm))
                                    .font(.pmBodyMedium)
                                    .foregroundStyle(.pmTextPrimary)
                                Text(entry.date.formatted(.dateTime.month(.abbreviated).day()))
                                    .font(.pmCaption)
                                    .foregroundStyle(.pmTextSecondary)
                            }
                        }
                    }
                }
            }
            .padding(PMSpacing.md)
        }
    }

    // MARK: - Progress photos card

    private var progressPhotosCard: some View {
        PMCard(elevated: true) {
            VStack(alignment: .leading, spacing: PMSpacing.md) {
                Text("PROGRESS PHOTOS · \(progressPhotos.count)")
                    .font(.pmKicker)
                    .tracking(0.6)
                    .foregroundStyle(.pmTextSecondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: PMSpacing.sm) {
                        ForEach(progressPhotos.prefix(8), id: \.id) { photo in
                            ProgressPhotoThumb(photo: photo)
                                .onTapGesture { selectedPhoto = photo }
                        }
                    }
                }
            }
            .padding(PMSpacing.md)
        }
    }

    // MARK: - Highlight / milestone card

    private func highlightCard(text: String) -> some View {
        PMCard {
            HStack(alignment: .top, spacing: PMSpacing.sm) {
                Text("🎉")
                    .font(.system(size: 22))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Milestone")
                        .font(.pmKicker)
                        .tracking(0.6)
                        .foregroundStyle(.pmAccentPurple)
                    Text(text)
                        .font(.pmBodyMedium)
                        .foregroundStyle(.pmTextPrimary)
                }
            }
            .padding(PMSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Progress Stat Card

private struct ProgressStatCard: View {
    let kicker: String
    let value: String
    var valueColor: Color = .pmTextPrimary

    var body: some View {
        PMCard(elevated: true) {
            VStack(alignment: .leading, spacing: PMSpacing.xs) {
                Text(kicker)
                    .font(.pmKicker)
                    .tracking(0.6)
                    .foregroundStyle(.pmTextSecondary)
                Text(value)
                    .font(.system(.title2, design: .rounded, weight: .heavy))
                    .foregroundStyle(valueColor)
            }
            .padding(PMSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Activity Row

private struct ActivityRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.pmSecondaryBody)
                .foregroundStyle(.pmTextPrimary)
            Spacer()
            Text(value)
                .font(.pmBodyMedium)
                .foregroundStyle(.pmTextPrimary)
        }
    }
}

// MARK: - Summary Row

private struct SummaryRow: View {
    let label: String
    let value: String
    let complete: Bool

    var body: some View {
        HStack {
            Text(label)
                .font(.pmSecondaryBody)
                .foregroundStyle(.pmTextPrimary)
            Spacer()
            HStack(spacing: 4) {
                if complete {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.pmStatusSuccess)
                }
                Text(value)
                    .font(.pmBodyMedium)
                    .foregroundStyle(complete ? .pmStatusSuccess : .pmTextPrimary)
            }
        }
    }
}

// MARK: - Progress Photo Thumbnail

private struct ProgressPhotoThumb: View {
    let photo: ProgressPhoto

    @State private var image: UIImage? = nil

    var body: some View {
        VStack(spacing: PMSpacing.xxs) {
            ZStack {
                RoundedRectangle(cornerRadius: PMSpacing.cardRadius)
                    .fill(Color.pmSurfacePrimary)
                    .frame(width: 100, height: 130)
                if let img = image {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 100, height: 130)
                        .clipShape(RoundedRectangle(cornerRadius: PMSpacing.cardRadius))
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: 24, weight: .light))
                        .foregroundStyle(.pmTextTertiary)
                }
            }
            Text(photo.displayLabel)
                .font(.pmCaption)
                .foregroundStyle(.pmTextSecondary)
        }
        .task {
            image = PhotoStorageService.shared.load(identifier: photo.localFileIdentifier)
        }
    }
}

// MARK: - Workout History Row

private struct WorkoutHistoryRow: View {
    let session: WorkoutSession
    let weightUnit: WeightUnit
    let isExpanded: Bool
    let onTap: () -> Void

    private var durationText: String {
        guard let secs = session.durationSeconds, secs > 0 else { return "" }
        let m = Int(secs) / 60
        let s = Int(secs) % 60
        return m > 0 ? "\(m)m \(s)s" : "\(s)s"
    }

    private var kcalText: String {
        guard let k = session.totalEnergyKilocalories, k > 0 else { return "" }
        return "~\(Int(k)) kcal"
    }

    private var completedSets: Int {
        session.exerciseLogs.reduce(0) { $0 + $1.sets.filter(\.isCompleted).count }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PMSpacing.xs) {
            Button(action: onTap) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.title)
                            .font(.pmBodyMedium)
                            .foregroundStyle(.pmTextPrimary)
                        HStack(spacing: PMSpacing.xs) {
                            if !durationText.isEmpty {
                                Label(durationText, systemImage: "timer")
                                    .font(.pmCaption)
                                    .foregroundStyle(.pmTextSecondary)
                            }
                            if !kcalText.isEmpty {
                                Text("·")
                                    .font(.pmCaption)
                                    .foregroundStyle(.pmTextTertiary)
                                Text(kcalText)
                                    .font(.pmCaption)
                                    .foregroundStyle(.pmTextSecondary)
                            }
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(session.startedAt.formatted(.dateTime.month(.abbreviated).day()))
                            .font(.pmCaption)
                            .foregroundStyle(.pmTextSecondary)
                        if !session.exerciseLogs.isEmpty {
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.pmTextTertiary)
                        }
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded && !session.exerciseLogs.isEmpty {
                VStack(spacing: PMSpacing.xxs) {
                    ForEach(session.exerciseLogs.sorted { $0.orderIndex < $1.orderIndex }) { log in
                        HStack {
                            Text(log.exerciseName)
                                .font(.pmCaption)
                                .foregroundStyle(.pmTextSecondary)
                            Spacer()
                            let done = log.sets.filter(\.isCompleted)
                            if !done.isEmpty {
                                let avgReps   = done.compactMap(\.reps).reduce(0, +) / max(1, done.count)
                                let avgWeight = done.compactMap(\.weightKilograms).reduce(0, +) / Double(max(1, done.count))
                                let detail = avgWeight > 0
                                    ? "\(done.count)×\(avgReps) @ \(Int(weightUnit == .kilograms ? avgWeight : avgWeight * 2.20462)) \(weightUnit == .kilograms ? "kg" : "lb")"
                                    : "\(done.count)×\(avgReps)"
                                Text(detail)
                                    .font(.pmCaption)
                                    .foregroundStyle(.pmTextTertiary)
                            }
                        }
                    }
                }
                .padding(.top, PMSpacing.xxs)
                .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
            }
        }
    }
}

// MARK: - Full Screen Photo View

private struct FullScreenPhotoView: View {
    let photo: ProgressPhoto
    @State private var image: UIImage? = nil
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let img = image {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .ignoresSafeArea()
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(PMSpacing.md)
            }
        }
        .overlay(alignment: .bottom) {
            VStack(spacing: 4) {
                Text(photo.displayLabel)
                    .font(.pmBodyMedium)
                    .foregroundStyle(.white)
                Text(photo.takenAt.formatted(.dateTime.month(.wide).day().year()))
                    .font(.pmCaption)
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.bottom, PMSpacing.xxxl)
        }
        .task {
            image = PhotoStorageService.shared.load(identifier: photo.localFileIdentifier)
        }
    }
}

// MARK: - Add Progress Photo Sheet

private struct AddProgressPhotoSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss)      private var dismiss

    @State private var pickerItem: PhotosPickerItem? = nil
    @State private var selectedImage: UIImage? = nil
    @State private var selectedAngle: PhotoAngle = .front
    @State private var notesText = ""
    @State private var isSaving = false

    private let storage = PhotoStorageService.shared
    private var canSave: Bool { selectedImage != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: PMSpacing.lg) {
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        ZStack {
                            RoundedRectangle(cornerRadius: PMSpacing.cardRadius)
                                .fill(Color.pmSurfacePrimary)
                                .frame(height: 200)
                            if let image = selectedImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 200)
                                    .clipShape(RoundedRectangle(cornerRadius: PMSpacing.cardRadius))
                            } else {
                                VStack(spacing: PMSpacing.xs) {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 30, weight: .light))
                                        .foregroundStyle(.pmTextSecondary)
                                    Text("Tap to select photo")
                                        .font(.pmSecondaryBody)
                                        .foregroundStyle(.pmTextSecondary)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, PMSpacing.screenEdge)
                    .onChange(of: pickerItem) { _, item in
                        Task {
                            if let data = try? await item?.loadTransferable(type: Data.self),
                               let image = UIImage(data: data) {
                                selectedImage = image
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: PMSpacing.xs) {
                        Text("Angle")
                            .font(.pmCaptionMedium)
                            .foregroundStyle(.pmTextSecondary)
                            .padding(.horizontal, PMSpacing.screenEdge)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: PMSpacing.xs) {
                                ForEach(PhotoAngle.allCases.filter { $0 != .custom }, id: \.rawValue) { angle in
                                    let selected = selectedAngle == angle
                                    Button { selectedAngle = angle } label: {
                                        Text(angle.displayName)
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

                    PMFormField(label: "Notes — optional", text: $notesText, placeholder: "Any context…")
                        .padding(.horizontal, PMSpacing.screenEdge)

                    Spacer()

                    Button(isSaving ? "Saving…" : "Save Photo") { savePhoto() }
                        .pmPrimaryStyle()
                        .disabled(!canSave || isSaving)
                        .padding(.horizontal, PMSpacing.screenEdge)
                        .padding(.bottom, PMSpacing.lg)
                }
                .padding(.top, PMSpacing.md)
            }
            .background(Color.pmBackgroundPrimary.ignoresSafeArea())
            .navigationTitle("Progress Photo")
            .pmLargeNavTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(.pmTextSecondary)
                }
            }
        }
    }

    private func savePhoto() {
        guard let image = selectedImage else { return }
        isSaving = true
        let identifier = UUID().uuidString + ".jpg"
        Task {
            try? storage.save(image, identifier: identifier)
            let record = ProgressPhoto(angleRawValue: selectedAngle.rawValue, localFileIdentifier: identifier)
            record.notes = notesText.isEmpty ? nil : notesText
            context.insert(record)
            try? context.save()
            isSaving = false
            dismiss()
        }
    }
}
