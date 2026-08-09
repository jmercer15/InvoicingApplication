import Core
import Data
import PersistenceModels
import SharedUI
@testable import AppShell
import SwiftData
import Foundation
import Testing
@MainActor
@Suite struct WorkspaceNavigationRestorationTests {
    @Test func SanitizedPathTruncatesAtFirstMissingEntity() throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let context = ModelContext(container)
        let invoice = Invoice(invoiceNumber: "TEST-1")
        context.insert(invoice)
        try context.save()

        let missingID = UUID()
        let path: [WorkspaceRoute] = [.invoice(invoice.id), .client(missingID)]

        let sanitized = WorkspaceNavigationRestoration.sanitizedPath(path, modelContext: context)

        #expect(sanitized == [.invoice(invoice.id)])
    }

    @Test func SanitizedSelectionReturnsNilForDeletedEntity() throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let context = ModelContext(container)

        let selection = WorkspaceNavigationRestoration.sanitizedSelection(
            .invoice(UUID()),
            modelContext: context
        )

        #expect(selection == nil)
    }
}
