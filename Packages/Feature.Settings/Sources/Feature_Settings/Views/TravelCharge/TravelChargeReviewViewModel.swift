import Foundation
import Core
import DataInterfaces
import Observation
import SwiftData

@Observable
@MainActor
public final class TravelChargeReviewViewModel {
    private let automationActor: any TravelChargeAutomating
    private let mmmZoneLookup: any Core.MMMZoneLookupProtocol
    private let recurrenceRuleManager: RecurrenceRuleManager
    private let reviewFetching: any TravelChargeReviewFetching

    var filterStatus: ReviewStatusFilter = .all
    var isLoading: Bool = false
    var isProcessing: Bool = false
    public private(set) var reviewItemEntities: [TravelChargeReviewRow] = []

    public enum ReviewStatusFilter: String, CaseIterable {
        case all = "All"
        case pending = "Pending"
        case resolved = "Resolved"
        case overridden = "Overridden"
        case skipped = "Skipped"
    }

    public init(
        automationActor: any TravelChargeAutomating,
        mmmZoneLookup: any Core.MMMZoneLookupProtocol,
        recurrenceRuleManager: RecurrenceRuleManager,
        reviewFetching: any TravelChargeReviewFetching
    ) {
        self.automationActor = automationActor
        self.mmmZoneLookup = mmmZoneLookup
        self.recurrenceRuleManager = recurrenceRuleManager
        self.reviewFetching = reviewFetching
    }

    public func refreshReviews() async {
        do {
            reviewItemEntities = try reviewFetching.fetchAllReviewItems()
        } catch {
            print("❌ [TravelChargeReviewViewModel] Error fetching reviews: \(error)")
        }
    }

    func resolveWithOverride(reviewModelID: PersistentIdentifier, overrideType: String, reason: String?) async {
        isProcessing = true
        defer { isProcessing = false }

        do {
            try await automationActor.resolveReviewWithOverride(
                reviewModelID: reviewModelID,
                overrideType: overrideType,
                overrideReason: reason,
                mmmZoneLookup: mmmZoneLookup,
                recurrenceRuleManager: recurrenceRuleManager
            )
            await refreshReviews()
        } catch {
            print("❌ [TravelChargeReviewViewModel] Error resolving with override: \(error)")
        }
    }

    func resolveBySkipping(reviewModelID: PersistentIdentifier) async {
        isProcessing = true
        defer { isProcessing = false }

        do {
            try await automationActor.resolveReviewBySkipping(reviewModelID: reviewModelID, reason: nil)
            await refreshReviews()
        } catch {
            print("❌ [TravelChargeReviewViewModel] Error skipping review: \(error)")
        }
    }
}
