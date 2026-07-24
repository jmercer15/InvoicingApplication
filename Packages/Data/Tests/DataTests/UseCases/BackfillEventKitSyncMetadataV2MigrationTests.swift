@testable import Data
import Core
import SwiftData
import XCTest

@MainActor
final class BackfillEventKitSyncMetadataV2MigrationTests: XCTestCase {
    private var modelContext: ModelContext!

    override func setUp() async throws {
        try await super.setUp()
        let (_, context) = try ModelContainerFactory.makeInMemoryContext()
        modelContext = context
    }

    override func tearDown() async throws {
        modelContext = nil
        try await super.tearDown()
    }

    func testMigrationPromotesExistingStaleLinksToTwoPassThreshold() throws {
        let session = Session(id: UUID())
        session.title = "Test Session"
        session.isEventKitLinkStale = true
        session.eventKitConsecutiveWindowMisses = 0
        modelContext.insert(session)
        try modelContext.save()

        try BackfillEventKitSyncMetadata_v2.execute(modelContext: modelContext)

        let fetched = try modelContext.fetch(FetchDescriptor<Session>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.eventKitConsecutiveWindowMisses, 2)
        XCTAssertEqual(fetched.first?.isEventKitLinkStale, true)
    }

    func testMigrationNormalizesNegativeMissCounters() throws {
        let session = Session(id: UUID())
        session.title = "Negative Counter"
        session.eventKitConsecutiveWindowMisses = -1
        modelContext.insert(session)
        try modelContext.save()

        try BackfillEventKitSyncMetadata_v2.execute(modelContext: modelContext)

        let fetched = try modelContext.fetch(FetchDescriptor<Session>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.eventKitConsecutiveWindowMisses, 0)
    }
}
