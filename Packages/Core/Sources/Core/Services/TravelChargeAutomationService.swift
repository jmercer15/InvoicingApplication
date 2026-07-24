import Foundation
import os
import SwiftData

// Compliance models have been moved to Core package to be shared with features.
// Use Core.ComplianceViolation and Core.DetailedReviewItem.

/// Service for automated creation of travel charge sessions based on session data, business rules, and user preferences.
///
/// SwiftData `ModelContext` is not `Sendable`; instances are confined to one isolation domain (typically a `@ModelActor`
/// worker or `@MainActor`). `@unchecked Sendable` matches that single-owner convention—do not share across actors.
public final class TravelChargeAutomationService: @unchecked Sendable {
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
        modelContext: ModelContext,
        businessRules: BusinessRules,
        userPreferences: UserPreferences,
        mmmZoneTable: MMMZoneTable,
        recurrenceRuleManager: RecurrenceRuleManager,
        testingMode: Bool = false
    ) {
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

    /// Automate travel charges using domain models (awaitable; preferred for `ModelActor` callers).
    public func automateTravelCharges(for sessions: [Session], dateRange: ClosedRange<Date>?) async {
        let sessionContexts = prefetchContexts(for: sessions)
        await automateTravelChargesAwaitable(for: sessionContexts, dateRange: dateRange)
    }

    /// Automate travel charges from snapshots for callers that still resolve `SessionSnapshot` inputs.
    public func automateTravelChargesFromSnapshots(for sessions: [SessionSnapshot], dateRange: ClosedRange<Date>?) async {
        do {
            let sessionContexts = try await prefetchContexts(for: sessions)
            await automateTravelChargesAwaitable(for: sessionContexts, dateRange: dateRange)
        } catch {
            Logger.automation.error("TravelCharge automation failed context setup: \(error)")
        }
    }
}

