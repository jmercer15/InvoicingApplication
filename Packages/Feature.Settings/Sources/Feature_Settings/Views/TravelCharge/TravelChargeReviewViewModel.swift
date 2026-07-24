import Foundation
import Core
import Data
import Observation
import SwiftData

@Observable
@MainActor
public final class TravelChargeReviewViewModel {
    // MARK: - Dependencies
    // MARK: - Dependencies
    private let automationActor: TravelChargeAutomationActor
    private let mmmZoneLookup: any Core.MMMZoneLookupProtocol
    private let recurrenceRuleManager: RecurrenceRuleManager
    private let modelContext: ModelContext
    private let workflow: ReferenceDataWorkflowActor
    
    // MARK: - Published Properties
    // MARK: - Published Properties
    var filterStatus: ReviewStatusFilter = .all
    var isLoading: Bool = false
    var isProcessing: Bool = false
    public private(set) var reviewItemEntities: [TravelChargeReviewItem] = []
    
    public enum ReviewStatusFilter: String, CaseIterable {
        case all = "All"
        case pending = "Pending"
        case resolved = "Resolved"
        case overridden = "Overridden"
        case skipped = "Skipped"
    }
    
    // MARK: - Initialization
    public init(
        automationActor: TravelChargeAutomationActor,
        mmmZoneLookup: any Core.MMMZoneLookupProtocol,
        recurrenceRuleManager: RecurrenceRuleManager,
        modelContext: ModelContext,
        modelContainer: ModelContainer
    ) {
        self.automationActor = automationActor
        self.mmmZoneLookup = mmmZoneLookup
        self.recurrenceRuleManager = recurrenceRuleManager
        self.modelContext = modelContext
        self.workflow = ReferenceDataWorkflowActor(modelContainer: modelContainer)
    }

    public func refreshReviews() async {
        do {
            let descriptor = FetchDescriptor<TravelChargeReviewItem>()
            let reviews = try modelContext.fetch(descriptor)
            self.reviewItemEntities = reviews
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
            try await automationActor.resolveReviewBySkipping(reviewModelID: reviewModelID)
            await refreshReviews()
        } catch {
            print("❌ [TravelChargeReviewViewModel] Error skipping review: \(error)")
        }
    }
}
