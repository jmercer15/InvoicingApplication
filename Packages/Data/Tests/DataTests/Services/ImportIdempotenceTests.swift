import Foundation
import PersistenceModels
import SwiftData
import Testing
@testable import Data

@MainActor
@Suite struct ImportIdempotenceTests {
    @Test func sessionImportUpdatesMatchingClientAndStartTime() throws {
        let (_, context) = try ModelContainerFactory.makeInMemoryContext()
        let client = Client(fullName: "Taylor Example")
        context.insert(client)
        try context.save()

        let first = "[{\"title\":\"Original\",\"date\":\"2026-07-31\",\"startTime\":\"09:00\",\"endTime\":\"10:00\",\"clientName\":\"Taylor Example\",\"location\":\"Office\",\"notes\":\"first\",\"status\":\"scheduled\"}]"
        let second = "[{\"title\":\"Updated\",\"date\":\"2026-07-31\",\"startTime\":\"09:00\",\"endTime\":\"11:00\",\"clientName\":\"Taylor Example\",\"location\":\"Home\",\"notes\":\"second\",\"status\":\"cancelled\"}]"

        _ = try SessionImport.importSessions(data: Data(first.utf8), fileName: "sessions.json", context: context)
        let result = try SessionImport.importSessions(data: Data(second.utf8), fileName: "sessions.json", context: context)

        let sessions = try context.fetch(FetchDescriptor<Session>())
        #expect(sessions.count == 1)
        #expect(result.successful == 1)
        #expect(result.messages.contains { $0.contains("Updated session") })
        #expect(sessions[0].title == "Updated")
        #expect(sessions[0].location == "Home")
        #expect(sessions[0].notes == "second")
        #expect(sessions[0].status == .cancelled)
    }

    @Test func ndisJSONImportReplacesRegionalPricesForExistingVersion() throws {
        let (_, context) = try ModelContainerFactory.makeInMemoryContext()
        let initial = "[{\"itemNumber\":\"01_001_0101_1_1\",\"description\":\"Support\",\"rate\":\"$12.50\",\"unit\":\"hr\"}]"
        let updated = "[{\"itemNumber\":\"01_001_0101_1_1\",\"description\":\"Support\",\"rate\":\"$20.00\",\"unit\":\"hr\"}]"

        _ = try NDISItemImport.importNDISItems(data: Data(initial.utf8), fileName: "ndis.json", context: context)
        _ = try NDISItemImport.importNDISItems(data: Data(updated.utf8), fileName: "ndis.json", context: context)

        let items = try context.fetch(FetchDescriptor<NDISItem>())
        #expect(items.count == 1)
        #expect(items[0].regionalPrices?.count == 1)
        #expect(items[0].regionalPrices?.first?.regionIdentifier == "NATIONAL")
        #expect(items[0].regionalPrices?.first?.amount == Decimal(20))
    }
}
