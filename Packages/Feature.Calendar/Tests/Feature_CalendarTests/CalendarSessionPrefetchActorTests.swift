import Core
import Data
import SwiftData
@testable import Feature_Calendar
import XCTest

final class CalendarSessionPrefetchActorTests: XCTestCase {
    func testDisplayRefreshFingerprintInvalidatesForCrossFeatureStoreRevision() {
        let range = (start: Date(timeIntervalSinceReferenceDate: 100), end: Date(timeIntervalSinceReferenceDate: 200))
        let first = DisplayItemsRefreshFingerprint(
            viewRange: range,
            sessions: [],
            visibleCalendarIdentifiers: [],
            eventStoreChangeGeneration: 0,
            storeRevision: 1
        )
        let second = DisplayItemsRefreshFingerprint(
            viewRange: range,
            sessions: [],
            visibleCalendarIdentifiers: [],
            eventStoreChangeGeneration: 0,
            storeRevision: 2
        )

        XCTAssertNotEqual(first, second)
    }

    func testLoadsSupportLogThroughModelActorBoundary() async throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let context = ModelContext(container)
        context.autosaveEnabled = false

        let session = Session(title: "Support session")
        let log = SupportLog()
        log.participantName = "Alex"
        log.supportItemNumber = "01_001_0107_1_1"
        log.session = session
        session.supportLogs = [log]
        context.insert(session)
        try context.save()

        let actor = CalendarSessionPrefetchActor(modelContainer: container)
        let result = await actor.load(sessionID: session.id)

        XCTAssertNil(result.clientID)
        XCTAssertNil(result.clientServiceID)
        XCTAssertEqual(result.supportLog?.participantName, "Alex")
        XCTAssertEqual(result.supportLog?.supportItemNumber, "01_001_0107_1_1")
        XCTAssertTrue(result.supportLog?.isEnabled == true)
    }

    func testMissingSessionReturnsEmptySnapshot() async throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let deletedSession = Session(title: "Deleted")
        context.insert(deletedSession)
        try context.save()
        let deletedID = deletedSession.id
        context.delete(deletedSession)
        try context.save()

        let actor = CalendarSessionPrefetchActor(modelContainer: container)
        let result = await actor.load(sessionID: deletedID)

        XCTAssertNil(result.clientID)
        XCTAssertNil(result.clientServiceID)
        XCTAssertNil(result.supportLog)
    }
}
