import Foundation
import SwiftData
import Core

/// Background actor for executing potentially heavy NDIS versioning operations off the main thread.
@ModelActor
public actor NDISVersioningActor {
    
    /// Retrieves a summary of all NDIS item changes over time.
    public func getChangesSummary() throws -> NDISChangesSummary {
        try NDISVersioningService.getChangesSummary(in: modelContext)
    }
    
    /// Analyzes how an NDIS item has changed over time.
    public func analyzeItemChanges(itemNumber: String) throws -> [NDISItemChange] {
        try NDISVersioningService.analyzeItemChanges(itemNumber: itemNumber, in: modelContext)
    }

    /// Fetches all NDIS catalogue items and maps them to thread-safe snapshots.
    public func fetchNDISItemSnapshots() throws -> [NDISItemSnapshot] {
        let descriptor = FetchDescriptor<NDISItem>()
        let items = try modelContext.fetch(descriptor)
        return items.map { $0.snapshot() }
    }
}
