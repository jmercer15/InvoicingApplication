import Core
import Data
import SharedUI
@testable import AppShell
import SwiftData
import XCTest

@MainActor
final class WorkspaceNavigationRestorationTests: XCTestCase {
    func testSanitizedPathTruncatesAtFirstMissingEntity() throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let context = ModelContext(container)
        let invoice = Invoice(invoiceNumber: "TEST-1")
        context.insert(invoice)
        try context.save()

        let missingID = UUID()
        let path: [WorkspaceRoute] = [.invoice(invoice.id), .client(missingID)]

        let sanitized = WorkspaceNavigationRestoration.sanitizedPath(path, modelContext: context)

        XCTAssertEqual(sanitized, [.invoice(invoice.id)])
    }

    func testSanitizedSelectionReturnsNilForDeletedEntity() throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let context = ModelContext(container)

        let selection = WorkspaceNavigationRestoration.sanitizedSelection(
            .invoice(UUID()),
            modelContext: context
        )

        XCTAssertNil(selection)
    }
}
