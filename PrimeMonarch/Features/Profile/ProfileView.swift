import SwiftData
import SwiftUI

struct ProfileView: View {
    @Environment(AppCoordinator.self) private var coordinator
    @Query private var profiles: [UserProfile]
    @Query private var goalProfiles: [GoalProfile]
    @Query private var preferences: [UserPreference]
    @Query private var ledgers: [XPLedger]
    @Query(sort: \UserAchievement.earnedAt, order: .reverse) private var earnedAchievements: [UserAchievement]
    @Query private var allAchievements: [Achievement]

    private var profile: UserProfile?       { profiles.first }
    private var goalProfile: GoalProfile?   { goalProfiles.first }
    private var preference: UserPreference? { preferences.first }
    private var ledger: XPLedger?           { ledgers.first }

    private func achievementDetail(for key: String) -> Achievement? {
        allAchievements.first { $0.key == key }
    }

    @State private var showSignOutConfirm   = false
    @State private var showEditGoals        = false
    @State private var showWorkoutPrefs     = false
    @State private var showNotifications    = false
    @State private var showAccountSettings  = false

    private var initials: String {
        guard let name = profile?.displayName else { return "?" }
        let parts = name.components(separatedBy: " ")
        let f = parts.first?.first.map(String.init) ?? ""
        let l = parts.dropFirst().first?.first.map(String.init) ?? ""
        return (f + l).uppercased()
    }

    private var memberSince: String {
        guard let date = profile?.createdAt else { return "" }
        return "Member since " + date.formatted(.dateTime.month(.wide).year())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: PMSpacing.lg) {
                    // Avatar + name block (centered)
                    avatarBlock
                        .padding(.horizontal, PMSpacing.screenEdge)

                    if let profile {
                        bodyStatsCard(profile: profile)
                            .padding(.horizontal, PMSpacing.screenEdge)
                    }

                    dietActivityCard
                        .padding(.horizontal, PMSpacing.screenEdge)

                    if !allAchievements.isEmpty {
                        badgesCard
                            .padding(.horizontal, PMSpacing.screenEdge)
                    }

                    settingsList
                        .padding(.horizontal, PMSpacing.screenEdge)

                    Button("Sign Out") { showSignOutConfirm = true }
                        .pmSecondaryStyle()
                        .padding(.horizontal, PMSpacing.screenEdge)
                        .padding(.bottom, PMSpacing.xxl)
                }
                .padding(.top, PMSpacing.md)
            }
            .scrollIndicators(.hidden)
            .background(Color.pmBackgroundPrimary.ignoresSafeArea())
            .navigationTitle("Profile")
            .pmLargeNavTitle()
            .confirmationDialog(
                "Are you sure you want to sign out?",
                isPresented: $showSignOutConfirm,
                titleVisibility: .visible
            ) {
                Button("Sign Out", role: .destructive) {
                    Task { await coordinator.handleSignOut() }
                }
                Button("Cancel", role: .cancel) {}
            }
        }
        .sheet(isPresented: $showEditGoals)        { EditGoalsView() }
        .sheet(isPresented: $showWorkoutPrefs)     { WorkoutPreferencesView() }
        .sheet(isPresented: $showNotifications)    { NotificationsSettingsView() }
        .sheet(isPresented: $showAccountSettings)  { AccountSettingsView() }
    }

    // MARK: - Avatar

    private var avatarBlock: some View {
        VStack(spacing: PMSpacing.xs) {
            Circle()
                .fill(Color.pmAccentPurpleBright)
                .frame(width: 76, height: 76)
                .overlay(
                    Text(initials)
                        .font(.system(size: 26, weight: .heavy))
                        .foregroundStyle(Color.pmBackgroundPrimary)
                )

            Text(profile?.displayName ?? "PrimeMonarch User")
                .font(.system(.title3, design: .default, weight: .bold))
                .foregroundStyle(.pmTextPrimary)

            if profile?.isGuest == true {
                Text("Guest account")
                    .font(.pmCaption)
                    .foregroundStyle(.pmTextSecondary)
                    .padding(.horizontal, PMSpacing.xs)
                    .padding(.vertical, 2)
                    .background(Color.pmPillNeutralBg)
                    .clipShape(Capsule())
            } else if !memberSince.isEmpty {
                Text(memberSince)
                    .font(.pmCaption)
                    .foregroundStyle(.pmTextSecondary)
            }

            if let ledger {
                rankProgressView(ledger: ledger)
                    .padding(.top, PMSpacing.xxs)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, PMSpacing.xs)
    }

    private func rankProgressView(ledger: XPLedger) -> some View {
        let xpInLevel  = ledger.xpInCurrentLevel
        let xpNeeded   = requiredXP(for: ledger.currentLevel + 1) - requiredXP(for: ledger.currentLevel)

        return VStack(spacing: PMSpacing.xs) {
            // Rank chip
            Text("\(ledger.rank.displayName) · Level \(ledger.currentLevel)")
                .font(.pmKicker)
                .tracking(0.5)
                .foregroundStyle(.pmAccentPurpleBright)
                .padding(.horizontal, PMSpacing.sm)
                .padding(.vertical, 4)
                .background(Color.pmPillOrangeBg)
                .clipShape(Capsule())

            // XP progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.pmPillNeutralBg).frame(height: 6)
                    Capsule()
                        .fill(Color.pmAccentPurpleBright)
                        .frame(width: geo.size.width * ledger.progressToNextLevel, height: 6)
                }
            }
            .frame(width: 180, height: 6)

            Text("\(xpInLevel) / \(xpNeeded) XP to Level \(ledger.currentLevel + 1)")
                .font(.pmCaption)
                .foregroundStyle(.pmTextSecondary)
        }
    }

    // MARK: - Body stats card

    private func bodyStatsCard(profile: UserProfile) -> some View {
        PMCard(elevated: true) {
            VStack(alignment: .leading, spacing: PMSpacing.md) {
                Text("BODY STATS")
                    .font(.pmKicker)
                    .tracking(0.6)
                    .foregroundStyle(.pmTextSecondary)

                HStack(spacing: 0) {
                    if let age = profile.ageYears {
                        BodyStatCell(value: "\(age)", label: "years")
                    }
                    if let h = profile.heightCentimeters {
                        BodyStatCell(value: "\(Int(h)) cm", label: "height")
                    }
                    if let w = profile.currentWeightKilograms {
                        let display = profile.preferredWeightUnit == .kilograms ? w : w * 2.20462
                        BodyStatCell(
                            value: String(format: "%.0f %@", display, profile.preferredWeightUnit.displayName),
                            label: "weight"
                        )
                    }
                    if profile.ageYears == nil && profile.heightCentimeters == nil && profile.currentWeightKilograms == nil {
                        Text("Complete your profile in onboarding to see body stats.")
                            .font(.pmCaption)
                            .foregroundStyle(.pmTextSecondary)
                    }
                }
            }
            .padding(PMSpacing.md)
        }
    }

    // MARK: - Diet & activity tags card

    @ViewBuilder
    private var dietActivityCard: some View {
        let dietStyles  = (preference?.dietaryStyles ?? []).filter { $0 != .noRestrictions }
        let activityTag = goalProfile?.activityLevel.displayName

        if !dietStyles.isEmpty || activityTag != nil {
            PMCard(elevated: true) {
                VStack(alignment: .leading, spacing: PMSpacing.md) {
                    Text("DIET & ACTIVITY")
                        .font(.pmKicker)
                        .tracking(0.6)
                        .foregroundStyle(.pmTextSecondary)

                    FlowLayout(spacing: PMSpacing.xs) {
                        if let tag = activityTag {
                            ProfileTag(label: tag, style: .green)
                        }
                        ForEach(dietStyles, id: \.id) { style in
                            ProfileTag(label: style.displayName, style: .orange)
                        }
                    }
                }
                .padding(PMSpacing.md)
            }
        }
    }

    // MARK: - Badges card

    private var earnedKeys: Set<String> { Set(earnedAchievements.map(\.achievementKey)) }

    private var badgesCard: some View {
        PMCard(elevated: true) {
            VStack(alignment: .leading, spacing: PMSpacing.md) {
                HStack {
                    Text("ACHIEVEMENTS")
                        .font(.pmKicker)
                        .tracking(0.6)
                        .foregroundStyle(.pmTextSecondary)
                    Spacer()
                    Text("\(earnedAchievements.count) / \(allAchievements.count)")
                        .font(.pmKicker)
                        .tracking(0.4)
                        .foregroundStyle(.pmAccentPurpleBright)
                }

                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                    spacing: PMSpacing.sm
                ) {
                    ForEach(allAchievements, id: \.id) { achievement in
                        BadgeTile(achievement: achievement, isEarned: earnedKeys.contains(achievement.key))
                    }
                }
            }
            .padding(PMSpacing.md)
        }
    }

    // MARK: - Settings list

    private var settingsList: some View {
        PMCard(elevated: true) {
            VStack(spacing: 0) {
                SettingsRow(label: "Edit goals & targets") { showEditGoals    = true }
                PMDivider().padding(.horizontal, PMSpacing.md)
                SettingsRow(label: "Workout preferences")  { showWorkoutPrefs = true }
                PMDivider().padding(.horizontal, PMSpacing.md)
                SettingsRow(label: "Notifications")   { showNotifications   = true }
                PMDivider().padding(.horizontal, PMSpacing.md)
                SettingsRow(label: "Account settings") { showAccountSettings = true }
            }
        }
    }
}

// MARK: - Body Stat Cell

private struct BodyStatCell: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 16, weight: .heavy))
                .foregroundStyle(.pmTextPrimary)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.pmTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Profile Tag

private struct ProfileTag: View {
    enum Style { case orange, green }
    let label: String
    let style: Style

    private var bg: Color  { style == .orange ? .pmPillOrangeBg : .pmPillGreenBg }
    private var fg: Color  {
        style == .orange
            ? Color(red: 0.549, green: 0.286, blue: 0.102)
            : Color(red: 0.337, green: 0.388, blue: 0.247)
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

// MARK: - Settings Row

private struct SettingsRow: View {
    let label: String
    var action: (() -> Void)? = nil

    var body: some View {
        Button {
            action?()
        } label: {
            HStack {
                Text(label)
                    .font(.pmBodyMedium)
                    .foregroundStyle(.pmTextPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(action != nil ? .pmTextSecondary : Color.pmTextSecondary.opacity(0.4))
            }
            .padding(.horizontal, PMSpacing.md)
            .padding(.vertical, PMSpacing.sm)
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }
}

// MARK: - Flow Layout (wrapping tag row)

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Badge Tile

private struct BadgeTile: View {
    let achievement: Achievement
    var isEarned: Bool = true

    var body: some View {
        VStack(spacing: PMSpacing.xxs) {
            ZStack {
                Circle()
                    .fill(isEarned ? Color.pmPillOrangeBg : Color.pmPillNeutralBg)
                    .frame(width: 44, height: 44)
                Image(systemName: isEarned ? achievement.iconName : "lock.fill")
                    .font(.system(size: isEarned ? 18 : 14, weight: .light))
                    .foregroundStyle(isEarned ? Color.pmAccentPurpleBright : Color.pmTextTertiary)
            }
            Text(achievement.title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(isEarned ? .pmTextSecondary : .pmTextTertiary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .opacity(isEarned ? 1.0 : 0.5)
    }
}

// MARK: - Shared stat row (kept for backward compat)

struct ProfileStatRow: View {
    let label: String
    let value: String
    var icon: String? = nil

    var body: some View {
        HStack(spacing: PMSpacing.sm) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(.pmAccentPurpleBright)
                    .frame(width: 20)
            }
            Text(label)
                .font(.pmBody)
                .foregroundStyle(.pmTextPrimary)
            Spacer()
            if !value.isEmpty {
                Text(value)
                    .font(.pmBodyMedium)
                    .foregroundStyle(.pmTextSecondary)
            }
        }
        .padding(.horizontal, PMSpacing.md)
        .padding(.vertical, PMSpacing.sm)
    }
}
