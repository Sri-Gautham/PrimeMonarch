import SwiftData
import Foundation

protocol ProfileRepositoryProtocol: AnyObject {
    func fetchProfile(in context: ModelContext) throws -> UserProfile?
    func getOrCreateProfile(in context: ModelContext) throws -> UserProfile
    func fetchGoalProfile(in context: ModelContext) throws -> GoalProfile?
    func getOrCreateGoalProfile(in context: ModelContext) throws -> GoalProfile
    func fetchXPLedger(in context: ModelContext) throws -> XPLedger?
    func getOrCreateXPLedger(in context: ModelContext) throws -> XPLedger
}

final class ProfileRepository: ProfileRepositoryProtocol {

    func fetchProfile(in context: ModelContext) throws -> UserProfile? {
        let descriptor = FetchDescriptor<UserProfile>()
        return try context.fetch(descriptor).first
    }

    func getOrCreateProfile(in context: ModelContext) throws -> UserProfile {
        if let existing = try fetchProfile(in: context) { return existing }
        let profile = UserProfile()
        context.insert(profile)
        return profile
    }

    func fetchGoalProfile(in context: ModelContext) throws -> GoalProfile? {
        let descriptor = FetchDescriptor<GoalProfile>()
        return try context.fetch(descriptor).first
    }

    func getOrCreateGoalProfile(in context: ModelContext) throws -> GoalProfile {
        if let existing = try fetchGoalProfile(in: context) { return existing }
        let goal = GoalProfile()
        context.insert(goal)
        return goal
    }

    func fetchXPLedger(in context: ModelContext) throws -> XPLedger? {
        let descriptor = FetchDescriptor<XPLedger>()
        return try context.fetch(descriptor).first
    }

    func getOrCreateXPLedger(in context: ModelContext) throws -> XPLedger {
        if let existing = try fetchXPLedger(in: context) { return existing }
        let ledger = XPLedger()
        context.insert(ledger)
        return ledger
    }
}
