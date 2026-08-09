@testable import Data
import Core
import SwiftData
import Foundation
import Testing
import PersistenceModels
@MainActor
@Suite struct BackfillEventKitSyncMetadataV2MigrationTests {
    private let modelContext: ModelContext

    init() throws {
        let (_, context) = try ModelContainerFactory.makeInMemoryContext()
        self.modelContext = context
    }

    @Test func MigrationPromotesExistingStaleLinksToTwoPassThreshold() throws {
        let session = Session(id: UUID())
        session.title = "Test Session"
        session.isEventKitLinkStale = true
        session.eventKitConsecutiveWindowMisses = 0
        modelContext.insert(session)
        try modelContext.save()

        try BackfillEventKitSyncMetadata_v2.execute(modelContext: modelContext)

        let fetched = try modelContext.fetch(FetchDescriptor<Session>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.eventKitConsecutiveWindowMisses == 2)
        #expect(fetched.first?.isEventKitLinkStale == true)
    }

    @Test func MigrationNormalizesNegativeMissCounters() throws {
        let session = Session(id: UUID())
        session.title = "Negative Counter"
        session.eventKitConsecutiveWindowMisses = -1
        modelContext.insert(session)
        try modelContext.save()

        try BackfillEventKitSyncMetadata_v2.execute(modelContext: modelContext)

        let fetched = try modelContext.fetch(FetchDescriptor<Session>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.eventKitConsecutiveWindowMisses == 0)
    }
}
