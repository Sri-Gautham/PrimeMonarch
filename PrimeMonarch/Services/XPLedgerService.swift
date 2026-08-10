import Foundation
import SwiftData

@MainActor
final class XPLedgerService {

    /// Creates the XPLedger row if one does not already exist.
    static func ensureLedger(in context: ModelContext) {
        guard (try? context.fetch(FetchDescriptor<XPLedger>()))?.isEmpty == true else { return }
        context.insert(XPLedger())
        try? context.save()
    }

    /// Credits XP to the ledger. Idempotent-safe — exits early for 0 XP.
    static func credit(_ xp: Int, in context: ModelContext) {
        guard xp > 0 else { return }
        ensureLedger(in: context)
        guard let ledger = (try? context.fetch(FetchDescriptor<XPLedger>()))?.first else { return }
        ledger.addXP(xp)
        try? context.save()
    }
}
