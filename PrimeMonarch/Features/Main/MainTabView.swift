import SwiftData
import SwiftUI

struct MainTabView: View {
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(HealthKitService.self) private var healthKitService
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase

    // Tracks the current calendar day. When it changes (app foregrounded on a new day),
    // TodayView is destroyed and recreated so its @Query date ranges are re-computed.
    @State private var currentDay = Calendar.current.startOfDay(for: Date())

    var body: some View {
        TabView {
            Tab("Home", systemImage: "house.fill") {
                TodayView()
                    .id(currentDay)
            }
            Tab("Workout", systemImage: "figure.strengthtraining.traditional") {
                PlanView()
            }
            Tab("Meals", systemImage: "fork.knife") {
                LogView()
            }
            Tab("Progress", systemImage: "chart.line.uptrend.xyaxis") {
                ProgressTabView()
            }
            Tab("Profile", systemImage: "person.fill") {
                ProfileView()
            }
        }
        .tint(.pmAccentPurpleBright)
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            StreakService.checkAndResetIfNeeded(in: context)
            let today = Calendar.current.startOfDay(for: Date())
            if today != currentDay {
                currentDay = today
                coordinator.seedDailyTarget()
            }
            Task { await healthKitService.refreshTodayMetrics(in: context) }
        }
        .task {
            await healthKitService.refreshTodayMetrics(in: context)
        }
    }
}
