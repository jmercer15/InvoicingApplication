import Core
import Foundation

/// Background NDIS catalogue reads and versioning analysis.
///
/// Implemented by `NDISVersioningActor` in the Data package.
public protocol NDISCatalogueFetching: Sendable {
    func fetchNDISItemSnapshots() async throws -> [NDISItemSnapshot]
    func getChangesSummary() async throws -> NDISChangesSummary
    func analyzeItemChanges(itemNumber: String) async throws -> [NDISItemChange]
}
