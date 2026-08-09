import Foundation
import Observation

/// Bulk toolbar/panel progress isolated from board projection observation so Kanban rows
/// are not invalidated on every n-of-m progress tick.
@Observable
@MainActor
public final class BillingHubBulkProgressState {
    public var isCreatingDrafts: Bool = false
    public var isBulkProcessing: Bool = false
    public var bulkActionProgress: BillingHubBulkActionProgress?
    public var bulkActionProgressMessage: String? { bulkActionProgress?.message }

    public init() {}
}
