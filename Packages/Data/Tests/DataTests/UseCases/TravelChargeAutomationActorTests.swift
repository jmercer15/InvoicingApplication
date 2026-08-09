import Foundation
import Testing
import SwiftData
import Core
import PersistenceModels
@testable import Data

@MainActor
@Suite struct TravelChargeAutomationActorTests {
    private let modelContainer: ModelContainer
    private let modelContext: ModelContext
    private let actor: TravelChargeAutomationActor

    init() throws {
        let (container, context) = try ModelContainerFactory.makeInMemoryContext()
        self.modelContainer = container
        self.modelContext = context
        self.actor = TravelChargeAutomationActor(modelContainer: container)
    }

    @Test func ResolveReviewBySkippingWithModelIDUpdatesStatus() async throws {
        let review = TravelChargeReviewItem(id: UUID(), reason: "MMM lookup missing")
        review.status = "pending"
        modelContext.insert(review)
        try modelContext.save()

        try await actor.resolveReviewBySkipping(
            reviewModelID: review.persistentModelID,
            reason: "manual override by tester"
        )

        let reviewID = review.id
        let descriptor = FetchDescriptor<TravelChargeReviewItem>(
            predicate: #Predicate { $0.id == reviewID }
        )
        let refreshed = try modelContext.fetch(descriptor).first

        #expect(refreshed?.status == "resolved")
        #expect((refreshed?.resolutionNotes ?? "").contains("Skipped by user"))
        #expect((refreshed?.resolutionNotes ?? "").contains("manual override by tester"))
    }

    @Test func ResolveDeletedReviewModelIDThrowsTypedNotFoundError() async throws {
        let review = TravelChargeReviewItem(id: UUID(), reason: "Deleted review")
        modelContext.insert(review)
        try modelContext.save()
        let deletedModelID = review.persistentModelID
        modelContext.delete(review)
        try modelContext.save()

        do {
            try await actor.resolveReviewBySkipping(reviewModelID: deletedModelID)
            Issue.record("Expected deleted review model identifier to throw.")
        } catch let error as TravelChargeAutomationActorError {
            #expect(error == .reviewItemModelNotFound)
        }
    }
}
