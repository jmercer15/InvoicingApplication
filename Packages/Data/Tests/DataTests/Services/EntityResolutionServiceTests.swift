import Core
import SwiftData
@testable import Data
import XCTest

@MainActor
final class EntityResolutionServiceTests: XCTestCase {
    func testPersistentIdentifierResolutionReturnsNilAfterDeletion() throws {
        let (_, context) = try ModelContainerFactory.makeInMemoryContext()
        let session = Session(title: "Deleted session")
        context.insert(session)
        try context.save()
        let deletedModelID = session.persistentModelID
        context.delete(session)
        try context.save()

        let resolver = EntityResolutionService(context: context)
        let resolved: Session? = resolver.resolve(persistentModelID: deletedModelID)

        XCTAssertNil(resolved)
    }
}
