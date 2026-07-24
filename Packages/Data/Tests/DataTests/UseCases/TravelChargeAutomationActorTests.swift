import XCTest
import SwiftData
import Core
@testable import Data

@MainActor
final class TravelChargeAutomationActorTests: XCTestCase {
    private var modelContainer: ModelContainer!
    private var modelContext: ModelContext!
    private var actor: TravelChargeAutomationActor!

    override func setUp() async throws {
        try await super.setUp()
        let (container, context) = try ModelContainerFactory.makeInMemoryContext()
        modelContainer = container
        modelContext = context
        actor = TravelChargeAutomationActor(modelContainer: container)
    }

    override func tearDown() async throws {
        actor = nil
        modelContext = nil
        modelContainer = nil
        try await super.tearDown()
    }

    func testResolveReviewBySkippingWithModelIDUpdatesStatus() async throws {
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

        XCTAssertEqual(refreshed?.status, "resolved")
        XCTAssertTrue((refreshed?.resolutionNotes ?? "").contains("Skipped by user"))
        XCTAssertTrue((refreshed?.resolutionNotes ?? "").contains("manual override by tester"))
    }

    func testResolveDeletedReviewModelIDThrowsTypedNotFoundError() async throws {
        let review = TravelChargeReviewItem(id: UUID(), reason: "Deleted review")
        modelContext.insert(review)
        try modelContext.save()
        let deletedModelID = review.persistentModelID
        modelContext.delete(review)
        try modelContext.save()

        do {
            try await actor.resolveReviewBySkipping(reviewModelID: deletedModelID)
            XCTFail("Expected deleted review model identifier to throw.")
        } catch let error as TravelChargeAutomationActorError {
            XCTAssertEqual(error, .reviewItemModelNotFound)
        }
    }
}
