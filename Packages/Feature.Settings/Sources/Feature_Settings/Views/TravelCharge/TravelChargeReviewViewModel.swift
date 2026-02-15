import SwiftUI
import Combine
import Data
import Core
import SharedUI

@MainActor
public final class TravelChargeReviewViewModel: ObservableObject {
    // MARK: - Dependencies
    private let unitOfWork: UnitOfWorkService
    private let automationService: TravelChargeAutomationService
    
    // MARK: - Published Properties
    @Published var reviewItems: [Core.TravelChargeReviewItem] = []
    @Published var filterStatus: ReviewStatusFilter = .all
    @Published var selectedReviewItem: Core.TravelChargeReviewItem?
    @Published var isLoading: Bool = false
    @Published var isProcessing: Bool = false
    
    public enum ReviewStatusFilter: String, CaseIterable {
        case all = "All"
        case pending = "Pending"
        case resolved = "Resolved"
        case overridden = "Overridden"
        case skipped = "Skipped"
    }
    
    var filteredReviewItems: [Core.TravelChargeReviewItem] {
        switch filterStatus {
        case .all:
            return reviewItems
        case .pending:
            return reviewItems.filter { $0.status == "pending" }
        case .resolved:
            return reviewItems.filter { $0.status == "resolved" }
        case .overridden:
            return reviewItems.filter { $0.status == "overridden" }
        case .skipped:
            return reviewItems.filter { $0.status == "skipped" }
        }
    }
    
    // MARK: - Initialization
    public init(unitOfWork: UnitOfWorkService) {
        self.unitOfWork = unitOfWork
        self.automationService = TravelChargeAutomationService(
            unitOfWork: unitOfWork,
            businessRules: BusinessRules(),
            userPreferences: UserPreferences(),
            mmmZoneTable: MMMZoneTable()
        )
    }
    
    // MARK: - Public API
    
    func loadReviewItems() {
        Task {
            await fetchReviewItems()
        }
    }
    
    func fetchReviewItems() async {
        isLoading = true
        defer { isLoading = false }

        do {
            self.reviewItems = try await unitOfWork.travelChargeReviewItems.fetchAll()
        } catch {
            print("❌ [TravelChargeReviewViewModel] Error fetching review items: \(error)")
        }
    }
    
    func resolveWithOverride(reviewItemId: UUID, overrideType: String, reason: String?) async {
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            try await automationService.resolveReviewWithOverride(
                reviewItemId: reviewItemId,
                overrideType: overrideType,
                overrideReason: reason
            )
            await fetchReviewItems()
        } catch {
            print("❌ [TravelChargeReviewViewModel] Error resolving with override: \(error)")
        }
    }
    
    func resolveBySkipping(reviewItemId: UUID) async {
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            try await automationService.resolveReviewBySkipping(reviewItemId: reviewItemId)
            await fetchReviewItems()
        } catch {
            print("❌ [TravelChargeReviewViewModel] Error skipping review: \(error)")
        }
    }
}
