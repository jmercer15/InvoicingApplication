//
//  InvoicesPolishAndAccessibilityTests.swift
//  Feature_InvoicesTests
//
//  Created by Jesse Mercer on 24/7/2026.
//

import XCTest
import SwiftData
import Core
import Data
@testable import Feature_Invoices

@MainActor
final class InvoicesPolishAndAccessibilityTests: XCTestCase {

    // MARK: - 1. Active Filter Summary Generation Tests

    func testActiveFilterDescriptionsAndSummaryGeneration() {
        let container = try! ModelContainer(
            for: Invoice.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let viewModel = InvoicesContainerViewModel(modelContext: container.mainContext)

        // Baseline: no active filters
        XCTAssertTrue(viewModel.activeFilterDescriptions.isEmpty)
        XCTAssertEqual(viewModel.activeFilterSummaryText, "")
        XCTAssertTrue(viewModel.activeFilterTags.isEmpty)

        // Add search text filter
        viewModel.invoiceSearchText = "Acme"
        XCTAssertEqual(viewModel.activeFilterDescriptions, ["Search \"Acme\""])
        XCTAssertEqual(viewModel.activeFilterSummaryText, "Active filters: Search \"Acme\"")
        XCTAssertEqual(viewModel.activeFilterTags, [
            InvoiceFilterTag(id: .search, label: "Search: \"Acme\"")
        ])

        // Add status filter
        viewModel.invoiceFilterStatus = [InvoiceStatus.pending.rawValue]
        XCTAssertEqual(viewModel.activeFilterTags.count, 2)
        XCTAssertEqual(viewModel.activeFilterTags[1], InvoiceFilterTag(id: .status, label: "Status: Pending"))

        // Add date filter
        let startDate = Date(timeIntervalSince1970: 1_700_000_000)
        let endDate = Date(timeIntervalSince1970: 1_705_000_000)
        viewModel.filterStartDate = startDate
        viewModel.filterEndDate = endDate
        XCTAssertTrue(viewModel.activeFilterTags.contains(where: { $0.id == .date }))

        // Add amount filter
        viewModel.filterMinAmount = 100.0
        viewModel.filterMaxAmount = 500.0
        XCTAssertTrue(viewModel.activeFilterTags.contains(where: { $0.id == .amount }))

        // Add client filter
        viewModel.filterClients = ["Acme Corp"]
        XCTAssertTrue(viewModel.activeFilterTags.contains(where: { $0.id == .client }))

        XCTAssertEqual(viewModel.activeFilterTags.count, 5)
    }

    // MARK: - 2. Zero-State Filter Clear Actions Tests

    func testZeroStateFilterPolicyAndClearActions() {
        let container = try! ModelContainer(
            for: Invoice.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let viewModel = InvoicesContainerViewModel(modelContext: container.mainContext)

        // Setup active filters
        viewModel.invoiceSearchText = "Nonexistent"
        viewModel.invoiceFilterStatus = [InvoiceStatus.reviewDraft.rawValue]
        viewModel.filterMinAmount = 500.0
        viewModel.filterClients = ["Client X"]

        XCTAssertTrue(viewModel.hasActiveListFilters)

        // Verify zero-state empty state policy resolves to .noMatches
        let statePolicy = InvoicesListEmptyStatePolicy.resolve(
            totalInvoiceCount: 10,
            filteredCount: 0,
            hasActiveFilters: viewModel.hasActiveListFilters
        )
        XCTAssertEqual(statePolicy, .noMatches)

        // Test clearing individual filter tag
        viewModel.clearFilter(category: .search)
        XCTAssertEqual(viewModel.invoiceSearchText, "")
        XCTAssertTrue(viewModel.hasActiveListFilters)

        viewModel.clearFilter(category: .client)
        XCTAssertTrue(viewModel.filterClients.isEmpty)

        viewModel.clearFilter(category: .amount)
        XCTAssertNil(viewModel.filterMinAmount)

        viewModel.clearFilter(category: .status)
        XCTAssertTrue(viewModel.invoiceFilterStatus.isEmpty)
        XCTAssertFalse(viewModel.hasActiveListFilters)

        // Re-apply filters and test clearListFilters() reset
        viewModel.invoiceSearchText = "Test"
        viewModel.invoiceFilterStatus = [InvoiceStatus.received.rawValue]
        XCTAssertTrue(viewModel.hasActiveListFilters)

        viewModel.clearListFilters()
        XCTAssertFalse(viewModel.hasActiveListFilters)
        XCTAssertEqual(viewModel.invoiceSearchText, "")
        XCTAssertTrue(viewModel.invoiceFilterStatus.isEmpty)
        XCTAssertNil(viewModel.filterStartDate)
        XCTAssertNil(viewModel.filterEndDate)
        XCTAssertNil(viewModel.filterMinAmount)
        XCTAssertNil(viewModel.filterMaxAmount)
        XCTAssertTrue(viewModel.filterClients.isEmpty)
    }

    // MARK: - 3. Batch Deletion Shortcut Triggers & State Handling Tests

    func testBatchDeletionShortcutTriggersAndStateHandling() async throws {
        let container = try! ModelContainer(
            for: Invoice.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext

        let inv1 = Invoice(invoiceNumber: "INV-101")
        let inv2 = Invoice(invoiceNumber: "INV-102")
        let inv3 = Invoice(invoiceNumber: "INV-103")
        context.insert(inv1)
        context.insert(inv2)
        context.insert(inv3)
        try context.save()

        let viewModel = InvoicesContainerViewModel(modelContext: context)

        // Test static helper canBatchDelete
        XCTAssertTrue(InvoicesView.canBatchDelete(
            isMultiSelectMode: true,
            selectedInvoiceIDs: [inv1.id, inv2.id],
            selectedInvoiceID: nil,
            isPerformingBulkAction: false
        ))

        XCTAssertFalse(InvoicesView.canBatchDelete(
            isMultiSelectMode: true,
            selectedInvoiceIDs: [],
            selectedInvoiceID: nil,
            isPerformingBulkAction: false
        ))

        XCTAssertTrue(InvoicesView.canBatchDelete(
            isMultiSelectMode: false,
            selectedInvoiceIDs: [],
            selectedInvoiceID: inv1.id,
            isPerformingBulkAction: false
        ))

        XCTAssertFalse(InvoicesView.canBatchDelete(
            isMultiSelectMode: false,
            selectedInvoiceIDs: [],
            selectedInvoiceID: nil,
            isPerformingBulkAction: false
        ))

        XCTAssertFalse(InvoicesView.canBatchDelete(
            isMultiSelectMode: true,
            selectedInvoiceIDs: [inv1.id],
            selectedInvoiceID: nil,
            isPerformingBulkAction: true
        ))

        // Test deleteInvoices empty array handling
        let deletedZero = try await viewModel.deleteInvoices(ids: [])
        XCTAssertEqual(deletedZero, 0)

        // Test deleteInvoices batch deletion execution
        viewModel.selectedInvoice = inv1
        let deletedCount = try await viewModel.deleteInvoices(ids: [inv1.id, inv2.id])
        XCTAssertEqual(deletedCount, 2)
        XCTAssertNil(viewModel.selectedInvoice)
    }

    // MARK: - 4. Accessibility Announcement Text Generation Tests

    func testAccessibilityAnnouncementTextGeneration() {
        // Filter changes
        XCTAssertEqual(
            InvoiceAccessibilityAnnouncement.filterChanged(filteredCount: 4, totalCount: 15),
            "Filtered to 4 invoices"
        )
        XCTAssertEqual(
            InvoiceAccessibilityAnnouncement.filterChanged(filteredCount: 1, totalCount: 10),
            "Filtered to 1 invoice"
        )

        // Filters cleared
        XCTAssertEqual(
            InvoiceAccessibilityAnnouncement.filtersCleared(totalCount: 15),
            "Filters cleared, showing 15 invoices"
        )
        XCTAssertEqual(
            InvoiceAccessibilityAnnouncement.filtersCleared(totalCount: 1),
            "Filters cleared, showing 1 invoice"
        )

        // Empty states
        XCTAssertEqual(
            InvoiceAccessibilityAnnouncement.emptyState(state: .noMatches),
            "No matching invoices"
        )
        XCTAssertEqual(
            InvoiceAccessibilityAnnouncement.emptyState(state: .noInvoices),
            "No invoices yet"
        )
        XCTAssertEqual(
            InvoiceAccessibilityAnnouncement.emptyState(state: .needsRefresh),
            "Invoices need refresh"
        )
        XCTAssertEqual(
            InvoiceAccessibilityAnnouncement.emptyState(state: .content),
            ""
        )

        // Selection changed
        XCTAssertEqual(
            InvoiceAccessibilityAnnouncement.selectionChanged(selectedCount: 3),
            "3 invoices selected"
        )
        XCTAssertEqual(
            InvoiceAccessibilityAnnouncement.selectionChanged(selectedCount: 1),
            "1 invoice selected"
        )
        XCTAssertEqual(
            InvoiceAccessibilityAnnouncement.selectionChanged(selectedCount: 0),
            "Selection cleared"
        )

        // Action / refresh failure banners
        XCTAssertEqual(
            InvoiceAccessibilityAnnouncement.actionFailed("Duplicate failed"),
            "Invoice action failed. Duplicate failed"
        )
        XCTAssertEqual(
            InvoiceAccessibilityAnnouncement.actionFailed("   "),
            "Invoice action failed"
        )
        XCTAssertEqual(
            InvoiceAccessibilityAnnouncement.refreshFailed("Network unavailable"),
            "Invoices couldn't refresh. Network unavailable"
        )
        XCTAssertEqual(
            InvoiceAccessibilityAnnouncement.refreshFailed(""),
            "Invoices couldn't refresh"
        )
    }

    // MARK: - 5. Edge Case: Clearing Filters With No Active Filters

    func testClearingFiltersWithNoActiveFilters() {
        let container = try! ModelContainer(
            for: Invoice.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let viewModel = InvoicesContainerViewModel(modelContext: container.mainContext)

        // Verify baseline has no active filters
        XCTAssertFalse(viewModel.hasActiveListFilters)
        let initialRevision = viewModel.filterInputResetRevision

        // Clear all filters when already clear
        viewModel.clearListFilters()

        XCTAssertFalse(viewModel.hasActiveListFilters)
        XCTAssertTrue(viewModel.activeFilterDescriptions.isEmpty)
        XCTAssertTrue(viewModel.activeFilterTags.isEmpty)
        XCTAssertEqual(viewModel.activeFilterSummaryText, "")
        XCTAssertEqual(viewModel.filterInputResetRevision, initialRevision + 1)

        // Clear individual filter categories when already clear
        viewModel.clearSearchFilter()
        viewModel.clearStatusFilters()
        viewModel.clearDateFilters()
        viewModel.clearClientFilters()
        viewModel.clearAmountFilters()

        XCTAssertFalse(viewModel.hasActiveListFilters)
        XCTAssertEqual(viewModel.filterInputResetRevision, initialRevision + 6)
    }

    // MARK: - 6. Edge Case: Batch Deleting 0 Items

    func testBatchDeletingZeroItemsEdgeCase() async throws {
        let container = try! ModelContainer(
            for: Invoice.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let inv1 = Invoice(invoiceNumber: "INV-201")
        context.insert(inv1)
        try context.save()

        let viewModel = InvoicesContainerViewModel(modelContext: context)
        viewModel.totalInvoiceCount = 1

        let deletedCount = try await viewModel.deleteInvoices(ids: [])

        XCTAssertEqual(deletedCount, 0)
        XCTAssertEqual(viewModel.totalInvoiceCount, 1)
        XCTAssertFalse(InvoicesView.canBatchDelete(
            isMultiSelectMode: true,
            selectedInvoiceIDs: [],
            selectedInvoiceID: nil,
            isPerformingBulkAction: false
        ))
    }

    // MARK: - 7. Edge Case: Batch Deleting All Items

    func testBatchDeletingAllItemsEdgeCase() async throws {
        let container = try! ModelContainer(
            for: Invoice.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext

        let inv1 = Invoice(invoiceNumber: "INV-ALL-1")
        let inv2 = Invoice(invoiceNumber: "INV-ALL-2")
        let inv3 = Invoice(invoiceNumber: "INV-ALL-3")
        context.insert(inv1)
        context.insert(inv2)
        context.insert(inv3)
        try context.save()

        let viewModel = InvoicesContainerViewModel(modelContext: context)
        viewModel.invoiceEntities = [inv1, inv2, inv3]
        viewModel.totalInvoiceCount = 3
        viewModel.selectedInvoice = inv2

        let deletedCount = try await viewModel.deleteInvoices(ids: [inv1.id, inv2.id, inv3.id])

        XCTAssertEqual(deletedCount, 3)
        XCTAssertEqual(viewModel.totalInvoiceCount, 0)
        XCTAssertTrue(viewModel.invoiceEntities.isEmpty)
        XCTAssertNil(viewModel.selectedInvoice)

        let statePolicy = InvoicesListEmptyStatePolicy.resolve(
            totalInvoiceCount: viewModel.totalInvoiceCount,
            filteredCount: viewModel.invoiceEntities.count,
            hasActiveFilters: viewModel.hasActiveListFilters
        )
        XCTAssertEqual(statePolicy, .noInvoices)
        XCTAssertEqual(InvoiceAccessibilityAnnouncement.emptyState(state: statePolicy), "No invoices yet")
    }

    // MARK: - 8. Edge Case: Hidden Selection Reconciliation When Filters Change

    func testHiddenSelectionReconciliationWhenFiltersChange() throws {
        let container = try! ModelContainer(
            for: Invoice.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext

        let inv1 = Invoice(invoiceNumber: "INV-RECON-1")
        let inv2 = Invoice(invoiceNumber: "INV-RECON-2")
        context.insert(inv1)
        context.insert(inv2)
        try context.save()

        let viewModel = InvoicesContainerViewModel(modelContext: context)
        viewModel.requestSelectInvoice(inv1)

        // 1. When filters ARE active: selection is preserved even if invoice is hidden from list
        viewModel.invoiceSearchText = "Nonexistent Search"
        XCTAssertTrue(viewModel.hasActiveListFilters)

        viewModel.reconcileSelection(visibleInvoiceIDs: [inv2.id])
        XCTAssertEqual(viewModel.selectedInvoice?.id, inv1.id, "Selected invoice hidden by active filter must remain open")

        // 2. Clear filters: selection stays intact when invoice becomes visible again
        viewModel.clearListFilters()
        XCTAssertFalse(viewModel.hasActiveListFilters)

        viewModel.reconcileSelection(visibleInvoiceIDs: [inv1.id, inv2.id])
        XCTAssertEqual(viewModel.selectedInvoice?.id, inv1.id)

        // 3. When filters ARE NOT active: selection is cleared if invoice is no longer visible
        viewModel.reconcileSelection(visibleInvoiceIDs: [inv2.id])
        XCTAssertNil(viewModel.selectedInvoice, "Selected invoice missing without active filters must clear selection")
    }

    // MARK: - 9. Edge Case: VoiceOver Announcements With Special Characters and Zero Counts

    func testVoiceOverAnnouncementsWithSpecialCharactersAndZeroCounts() {
        // Zero counts formatting
        XCTAssertEqual(
            InvoiceAccessibilityAnnouncement.filterChanged(filteredCount: 0, totalCount: 0),
            "Filtered to 0 invoices"
        )
        XCTAssertEqual(
            InvoiceAccessibilityAnnouncement.filterChanged(filteredCount: 0, totalCount: 5),
            "Filtered to 0 invoices"
        )
        XCTAssertEqual(
            InvoiceAccessibilityAnnouncement.filtersCleared(totalCount: 0),
            "Filters cleared, showing 0 invoices"
        )
        XCTAssertEqual(
            InvoiceAccessibilityAnnouncement.selectionChanged(selectedCount: 0),
            "Selection cleared"
        )

        // Special characters in filter search and tags
        let container = try! ModelContainer(
            for: Invoice.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let viewModel = InvoicesContainerViewModel(modelContext: container.mainContext)

        let specialSearch = "Acme & Co. \"Special\" <100%>"
        viewModel.invoiceSearchText = specialSearch
        XCTAssertEqual(viewModel.activeFilterDescriptions, ["Search \"\(specialSearch)\""])
        XCTAssertEqual(viewModel.activeFilterSummaryText, "Active filters: Search \"\(specialSearch)\"")
        XCTAssertEqual(viewModel.activeFilterTags.first?.label, "Search: \"\(specialSearch)\"")

        // Amount edge cases: zero amount, negative and non-finite normalization
        viewModel.updateFilterMinimumAmount(0.0)
        XCTAssertEqual(viewModel.filterMinAmount, 0.0)

        viewModel.updateFilterMinimumAmount(-100.0)
        XCTAssertNil(viewModel.filterMinAmount, "Negative amount should be normalized to nil")

        viewModel.updateFilterMinimumAmount(Double.nan)
        XCTAssertNil(viewModel.filterMinAmount, "NaN should be normalized to nil")

        viewModel.updateFilterMinimumAmount(Double.infinity)
        XCTAssertNil(viewModel.filterMinAmount, "Infinity should be normalized to nil")

        viewModel.updateFilterMinimumAmount(0.0)
        viewModel.updateFilterMaximumAmount(500.25)
        XCTAssertEqual(
            viewModel.activeFilterDescriptions,
            ["Search \"\(specialSearch)\"", "Amount: 0.00 – 500.25"]
        )
    }
}
