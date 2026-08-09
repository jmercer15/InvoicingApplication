import Foundation

/// Read-only board display inputs passed into `KanbanBoardView` so the kanban tree does not
/// observe unrelated view-model mutations (toolbar bulk state, sheet presentation, etc.).
struct KanbanBoardDisplayState: Equatable {
    var searchText: String
    var hasActiveFilters: Bool
}

/// Board-level mutations and card context-menu actions without holding `@Bindable` view model
/// at the kanban root.
struct KanbanBoardActions {
    let formattedTotal: (KanbanCardData.BillingColumnType, BillingHubBoardProjection) -> String?
    let sortOption: (KanbanCardData.BillingColumnType) -> ColumnSortOption?
    let setSortOption: (ColumnSortOption, KanbanCardData.BillingColumnType) -> Void
    let reorderInvoices: (
        KanbanCardData.BillingColumnType,
        UUID,
        UUID?,
        BillingHubBoardProjection
    ) -> Void
    let moveSession: (UUID, KanbanCardData.BillingColumnType) async -> MoveResult?
    let moveInvoice: (UUID, KanbanCardData.BillingColumnType) async -> MoveResult?
    let addSessionToGroup: (UUID, UUID) async -> Void
    let canAddSessionToGroup: (UUID, UUID) -> Bool
    let groupSessionsSmooth: (UUID, UUID) async -> Void
}

/// Per-card menu actions extracted from the view model for kanban card rows.
struct KanbanCardActions {
    let nextColumn: (KanbanCardData) -> KanbanCardData.BillingColumnType?
    let advanceCard: (KanbanCardData) async -> Void
}
