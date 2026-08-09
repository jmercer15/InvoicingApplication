import Core
import Foundation
import PersistenceModels
import os
import SwiftData

// Compliance models have been moved to Core package to be shared with features.
// Use Core.ComplianceViolation and Core.DetailedReviewItem.

/// Service for automated creation of travel charge sessions based on session data, business rules, and user preferences.
///
/// Actor-owned travel charge automation workflow. Each instance creates and confines its own SwiftData context.
public actor TravelChargeAutomationService {
    let businessRules: BusinessRules // Business rule configuration
    let userPreferences: UserPreferences // User preferences
    let mmmZoneTable: MMMZoneTable // MMM zone lookup
    let recurrenceRuleManager: RecurrenceRuleManager
    var testingMode: Bool = false
    // For testing mode: store results instead of saving
    private(set) var testTravelChargeSummaries: [String] = []
    private(set) var testReviewSummaries: [String] = []
    private var testDetailedReviewItems: [DetailedReviewItem] = []

    let modelContext: ModelContext
    let persistence: TravelChargeAutomationPersistence

    public init(
        modelContainer: ModelContainer,
        businessRules: BusinessRules,
        userPreferences: UserPreferences,
        mmmZoneTable: MMMZoneTable,
        recurrenceRuleManager: RecurrenceRuleManager,
        testingMode: Bool = false
    ) {
        let modelContext = ModelContext(modelContainer)
        modelContext.autosaveEnabled = false
        self.modelContext = modelContext
        self.persistence = TravelChargeAutomationPersistence(modelContext: modelContext)
        self.businessRules = businessRules
        self.userPreferences = userPreferences
        self.mmmZoneTable = mmmZoneTable
        self.recurrenceRuleManager = recurrenceRuleManager
        self.testingMode = testingMode
    }

    // MARK: - Testing helpers

    /// `testTravelChargeSummaries` is `private(set)` to keep it read-only outside this file.
    /// Use this helper from extension files when building test-only summaries.
    func appendTestTravelChargeSummary(_ summary: String) {
        testTravelChargeSummaries.append(summary)
    }

    /// `testReviewSummaries` is `private(set)` to keep it read-only outside this file.
    func appendTestReviewSummary(_ summary: String) {
        testReviewSummaries.append(summary)
    }

    /// `testDetailedReviewItems` is file-private; use this helper from extension files.
    func appendTestDetailedReviewItem(_ item: DetailedReviewItem) {
        testDetailedReviewItems.append(item)
    }

    func testDetailedReviewItemsSnapshot() -> [DetailedReviewItem] {
        testDetailedReviewItems
    }

    // MARK: - Domain Model Methods (Preferred)

    /// Automate travel charges from immutable snapshots. Live SwiftData models never cross this actor boundary.
    public func automateTravelChargesFromSnapshots(for sessions: [SessionSnapshot], dateRange: ClosedRange<Date>?) async {
        do {
            let sessionContexts = try await prefetchContexts(for: sessions)
            await automateTravelChargesAwaitable(for: sessionContexts, dateRange: dateRange)
        } catch {
            Logger.automation.error("TravelCharge automation failed context setup: \(error)")
        }
    }
}
