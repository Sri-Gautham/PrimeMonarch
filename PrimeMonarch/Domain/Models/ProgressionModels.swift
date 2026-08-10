import Foundation
import SwiftData

// MARK: - Streak

@Model
final class Streak {
    @Attribute(.unique) var id: UUID
    var streakTypeRawValue: String
    var currentCount: Int
    var longestCount: Int
    var lastCompletedDate: Date?
    var graceUsedDate: Date?    // date grace day was consumed

    init(streakType: StreakType) {
        self.id = UUID()
        self.streakTypeRawValue = streakType.rawValue
        self.currentCount = 0
        self.longestCount = 0
    }

    var streakType: StreakType {
        get { StreakType(rawValue: streakTypeRawValue) ?? .logging }
        set { streakTypeRawValue = newValue.rawValue }
    }

    var isActiveToday: Bool {
        guard let last = lastCompletedDate else { return false }
        return Calendar.current.isDateInToday(last) ||
               Calendar.current.isDateInYesterday(last)
    }
}

// MARK: - Achievement Definition

@Model
final class Achievement {
    @Attribute(.unique) var id: UUID
    var key: String         // e.g. "first_step", "seven_day_ascent"
    var title: String
    var descriptionText: String
    var iconName: String    // SF Symbol or asset name
    var xpReward: Int

    init(key: String, title: String, descriptionText: String, iconName: String, xpReward: Int) {
        self.id = UUID()
        self.key = key
        self.title = title
        self.descriptionText = descriptionText
        self.iconName = iconName
        self.xpReward = xpReward
    }
}

// MARK: - User Achievement (earned)

@Model
final class UserAchievement {
    @Attribute(.unique) var id: UUID
    var achievementKey: String
    var earnedAt: Date
    var xpAwarded: Int

    init(achievementKey: String, xpAwarded: Int) {
        self.id = UUID()
        self.achievementKey = achievementKey
        self.earnedAt = Date()
        self.xpAwarded = xpAwarded
    }
}

// MARK: - XP Ledger

@Model
final class XPLedger {
    @Attribute(.unique) var id: UUID
    var totalXP: Int
    var currentLevel: Int
    var rankRawValue: String
    var updatedAt: Date

    init() {
        self.id = UUID()
        self.totalXP = 0
        self.currentLevel = 1
        self.rankRawValue = RankTier.initiate.rawValue
        self.updatedAt = Date()
    }

    var rank: RankTier {
        get { RankTier(rawValue: rankRawValue) ?? .initiate }
        set { rankRawValue = newValue.rawValue }
    }

    var xpForNextLevel: Int { requiredXP(for: currentLevel + 1) }

    var xpInCurrentLevel: Int {
        let xpForCurrent = requiredXP(for: currentLevel)
        return max(0, totalXP - xpForCurrent)
    }

    var progressToNextLevel: Double {
        let needed = xpForNextLevel - requiredXP(for: currentLevel)
        guard needed > 0 else { return 1.0 }
        return min(Double(xpInCurrentLevel) / Double(needed), 1.0)
    }

    func addXP(_ amount: Int) {
        totalXP += amount
        updatedAt = Date()
        // Level up loop
        while totalXP >= requiredXP(for: currentLevel + 1) {
            currentLevel += 1
        }
        rank = RankTier.rank(for: currentLevel)
    }
}
