import Foundation
import Core
import DataInterfaces
import PersistenceModels
import SwiftData
import os

public enum TravelChargeAutomationActorError: LocalizedError, Sendable, Equatable {
    case reviewItemModelNotFound

    public var errorDescription: String? {
        switch self {
        case .reviewItemModelNotFound:
            return "Travel charge review item not found for the provided model identifier."
        }
    }
}

/// Background SwiftData actor for travel-charge automation (MapKit + rule evaluation off the main `@ModelContext`).
public actor TravelChargeAutomationActor: ModelActor {
    nonisolated public let modelContainer: ModelContainer
    nonisolated public let modelExecutor: any ModelExecutor

    private static let automationSignpostLog = OSLog(subsystem: "com.invoicingapplication.app", category: "travel-charge")

    public init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        let context = ModelContext(modelContainer)
        context.autosaveEnabled = false
        self.modelExecutor = DefaultSerialModelExecutor(modelContext: context)
    }

    /// Runs automation by resolving `Session` models from persistent identifiers inside this actor's isolated context.
    public func runAutomation(
        sessionModelIDs: [PersistentIdentifier],
        dateRange: ClosedRange<Date>?,
        testingMode: Bool,
        mmmZoneLookup: any Core.MMMZoneLookupProtocol,
        recurrenceRuleManager: RecurrenceRuleManager
    ) async -> (charges: [String], reviews: [String], detailedReviews: [DetailedReviewItem]) {
        #if DEBUG
        let signpostID = OSSignpostID(log: Self.automationSignpostLog)
        os_signpost(.begin, log: Self.automationSignpostLog, name: "TravelChargeAutomationActor.runAutomation", signpostID: signpostID, "ids=%{public}d", sessionModelIDs.count)
        #endif
        let sessions: [Session]
        if sessionModelIDs.isEmpty {
            sessions = []
        } else {
            let ids = sessionModelIDs
            let descriptor = FetchDescriptor<Session>(
                predicate: #Predicate { ids.contains($0.persistentModelID) }
            )
            sessions = (try? modelContext.fetch(descriptor)) ?? []
        }
        let result = await runAutomation(
            sessions: sessions,
            dateRange: dateRange,
            testingMode: testingMode,
            mmmZoneLookup: mmmZoneLookup,
            recurrenceRuleManager: recurrenceRuleManager
        )
        #if DEBUG
        os_signpost(.end, log: Self.automationSignpostLog, name: "TravelChargeAutomationActor.runAutomation", signpostID: signpostID, "sessions=%{public}d", sessions.count)
        #endif
        return result
    }

    /// Resolves models locally, then sends immutable snapshots to an independently context-owning service actor.
    private func runAutomation(
        sessions: [Session],
        dateRange: ClosedRange<Date>?,
        testingMode: Bool,
        mmmZoneLookup: any Core.MMMZoneLookupProtocol,
        recurrenceRuleManager: RecurrenceRuleManager
    ) async -> (charges: [String], reviews: [String], detailedReviews: [DetailedReviewItem]) {
        let service = TravelChargeAutomationService(
            modelContainer: modelContainer,
            businessRules: BusinessRules(),
            userPreferences: UserPreferences(),
            mmmZoneTable: MMMZoneTable(mmmZoneLookup: mmmZoneLookup),
            recurrenceRuleManager: recurrenceRuleManager,
            testingMode: testingMode
        )
        let sessionSnapshots = sessions.map { $0.snapshot() }
        await service.automateTravelChargesFromSnapshots(for: sessionSnapshots, dateRange: dateRange)
        return await service.getTestResults()
    }

    /// Resolves a review item with an override using this actor's isolated context.
    public func resolveReviewWithOverride(
        reviewModelID: PersistentIdentifier,
        overrideType: String,
        overrideReason: String?,
        mmmZoneLookup: any Core.MMMZoneLookupProtocol,
        recurrenceRuleManager: RecurrenceRuleManager
    ) async throws {
        let reviewItem = try resolveReviewEntity(reviewModelID: reviewModelID)
        let service = TravelChargeAutomationService(
            modelContainer: modelContainer,
            businessRules: BusinessRules(),
            userPreferences: UserPreferences(),
            mmmZoneTable: MMMZoneTable(mmmZoneLookup: mmmZoneLookup),
            recurrenceRuleManager: recurrenceRuleManager,
            testingMode: false
        )
        try await service.resolveReviewWithOverride(
            reviewItemId: reviewItem.id,
            overrideType: overrideType,
            overrideReason: overrideReason
        )
    }

    /// Resolves a review item by skipping creation of a travel charge.
    public func resolveReviewBySkipping(
        reviewModelID: PersistentIdentifier,
        reason: String? = nil
    ) throws {
        let reviewItem = try resolveReviewEntity(reviewModelID: reviewModelID)
        try markReviewSkipped(reviewItem, reason: reason)
    }

    private func resolveReviewEntity(reviewModelID: PersistentIdentifier) throws -> TravelChargeReviewItem {
        var descriptor = FetchDescriptor<TravelChargeReviewItem>(
            predicate: #Predicate { $0.persistentModelID == reviewModelID }
        )
        descriptor.fetchLimit = 1
        guard let reviewItem = try modelContext.fetch(descriptor).first else {
            throw TravelChargeAutomationActorError.reviewItemModelNotFound
        }
        return reviewItem
    }

    private func markReviewSkipped(_ reviewItem: TravelChargeReviewItem, reason: String?) throws {
        reviewItem.status = "resolved"
        reviewItem.resolutionNotes = "Skipped by user. Reason: \(reason ?? "None")"
        reviewItem.timestamp = Date()
        try modelContext.save()
    }
}

extension TravelChargeAutomationActor: TravelChargeAutomating {}
