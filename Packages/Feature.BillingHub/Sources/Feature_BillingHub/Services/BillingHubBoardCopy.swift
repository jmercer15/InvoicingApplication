enum BillingHubBoardCopy {
    static func itemCount(_ count: Int) -> String {
        "\(count) item\(count == 1 ? "" : "s")"
    }

    static func movedRecord(
        _ record: String,
        to column: KanbanCardData.BillingColumnType
    ) -> String {
        "\(record) moved to \(column.laneTitle)."
    }

    static func movedInvoiceWithComplianceWarnings(
        to column: KanbanCardData.BillingColumnType
    ) -> String {
        "Invoice moved to \(column.laneTitle) with compliance warnings. Review details before the next step."
    }

    static func emptyLaneMessage(
        for column: KanbanCardData.BillingColumnType,
        hasActiveFilters: Bool
    ) -> String {
        guard hasActiveFilters else { return column.emptyStateMessage }
        return "No matching \(column.laneTitle.lowercased()) work. Clear filters to see all billing work."
    }

    static func offersClearFiltersRecovery(for feedback: String) -> Bool {
        feedback.localizedCaseInsensitiveContains("clear filters")
    }
}
