import Core
import Foundation
import SwiftData

/// Settings travel-charge automation actor surface.
public protocol TravelChargeAutomating: Sendable {
    func runAutomation(
        sessionModelIDs: [PersistentIdentifier],
        dateRange: ClosedRange<Date>?,
        testingMode: Bool,
        mmmZoneLookup: any Core.MMMZoneLookupProtocol,
        recurrenceRuleManager: RecurrenceRuleManager
    ) async -> (charges: [String], reviews: [String], detailedReviews: [DetailedReviewItem])

    func resolveReviewWithOverride(
        reviewModelID: PersistentIdentifier,
        overrideType: String,
        overrideReason: String?,
        mmmZoneLookup: any Core.MMMZoneLookupProtocol,
        recurrenceRuleManager: RecurrenceRuleManager
    ) async throws

    func resolveReviewBySkipping(
        reviewModelID: PersistentIdentifier,
        reason: String?
    ) async throws
}
