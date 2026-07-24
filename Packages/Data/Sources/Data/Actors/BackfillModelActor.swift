import Foundation
import SwiftData
import Core
import os

/// Actor specifically designed for background data migrations and backfilling.
/// Prevents main-thread blocking during expensive legacy data fixes at UI launch.
public actor BackfillModelActor: ModelActor {
    nonisolated public let modelContainer: ModelContainer
    nonisolated public let modelExecutor: any ModelExecutor

    public init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        let context = ModelContext(modelContainer)
        context.autosaveEnabled = false
        self.modelExecutor = DefaultSerialModelExecutor(modelContext: context)
    }
    
    /// Backfills predicate-friendly status tokens added after early schema versions.
    ///
    /// SwiftData cannot predicate over encoded `statusData`, so billing surfaces use `statusToken`.
    public func backfillStatusTokensIfNeeded() async throws {
        let context = modelContext
        var didChange = false

        // Sessions: page to avoid loading large stores at once.
        while true {
            var sessionDescriptor = FetchDescriptor<Session>(
                predicate: #Predicate<Session> { $0.statusToken == "" },
                sortBy: [SortDescriptor(\.startTime, order: .forward)]
            )
            sessionDescriptor.fetchLimit = 1_000
            let sessions = try context.fetch(sessionDescriptor)
            guard !sessions.isEmpty else { break }
            for session in sessions {
                session.statusToken = session.status?.rawValue ?? ""
            }
            didChange = true
            try context.save()
            await Task.yield()
        }

        // Invoices: page similarly.
        while true {
            var invoiceDescriptor = FetchDescriptor<Invoice>(
                predicate: #Predicate<Invoice> { $0.statusToken == "" },
                sortBy: [SortDescriptor(\.issueDate, order: .forward)]
            )
            invoiceDescriptor.fetchLimit = 1_000
            let invoices = try context.fetch(invoiceDescriptor)
            guard !invoices.isEmpty else { break }
            for invoice in invoices {
                invoice.statusToken = invoice.status?.rawValue ?? InvoiceStatus.reviewDraft.rawValue
            }
            didChange = true
            try context.save()
            await Task.yield()
        }

        if didChange {
            // Ensure any pending autosave-disabled changes are persisted.
            try context.save()
        }
    }
}
