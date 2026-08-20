//
//  InvoicesPolishAndAccessibilityTests.swift
//  Feature_InvoicesTests
//
//  Created by Jesse Mercer on 24/7/2026.
//

import Foundation
import Testing
import SwiftData
import Core
import PersistenceModels
import Data
@testable import Feature_Invoices

@MainActor
@Suite struct InvoicesPolishAndAccessibilityTests {

    @Test func InvoiceListOmitsRevenueSummaryStrip() throws {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: packageRoot
                .appendingPathComponent("Sources/Feature_Invoices/Views/InvoicesViewList.swift"),
            encoding: .utf8
        )

        #expect(!source.contains("RevenueAnalyticsSummaryView"))
    }

    // MARK: - 1. Active Filter Summary Generation Tests

    @Test func ActiveFilterDescriptionsAndSummaryGeneration() {
        let container = try! ModelContainer(
            for: Invoice.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let viewModel = InvoicesContainerViewModel(modelContext: container.mainContext)

        // Baseline: no active filters
        #expect(viewModel.activeFilterDescriptions.isEmpty)
        #expect(viewModel.activeFilterSummaryText == "")
        #expect(viewModel.activeFilterTags.isEmpty)

        // Add search text filter
        viewModel.invoiceSearchText = "Acme"
        #expect(viewModel.activeFilterDescriptions == ["Search \"Acme\""])
        #expect(viewModel.activeFilterSummaryText == "Active filters: Search \"Acme\"")
        #expect(viewModel.activeFilterTags.count == 1)
        #expect(viewModel.activeFilterTags[0].id == .search)
        #expect(viewModel.activeFilterTags[0].label == "Search: \"Acme\"")

        // Add status filter
        viewModel.invoiceFilterStatus = [InvoiceStatus.pending.rawValue]
        #expect(viewModel.activeFilterTags.count == 2)
        #expect(viewModel.activeFilterTags[1] == InvoiceFilterTag(id: .status, label: "Status: Pending"))

        // Add date filter
        let startDate = Date(timeIntervalSince1970: 1_700_000_000)
        let endDate = Date(timeIntervalSince1970: 1_705_000_000)
        viewModel.filterStartDate = startDate
        viewModel.filterEndDate = endDate
        #expect(viewModel.activeFilterTags.contains(where: { $0.id == .date }))

        // Add amount filter
        viewModel.filterMinAmount = 100.0
        viewModel.filterMaxAmount = 500.0
        #expect(viewModel.activeFilterTags.contains(where: { $0.id == .amount }))

        // Add client filter
        viewModel.filterClients = ["Acme Corp"]
        #expect(viewModel.activeFilterTags.contains(where: { $0.id == .client }))

        #expect(viewModel.activeFilterTags.count == 5)
    }

    // MARK: - 2. Zero-State Filter Clear Actions Tests

    @Test func ZeroStateFilterPolicyAndClearActions() {
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

        #expect(viewModel.hasActiveListFilters)

        // Verify zero-state empty state policy resolves to .noMatches
        let statePolicy = InvoicesListEmptyStatePolicy.resolve(
            totalInvoiceCount: 10,
            filteredCount: 0,
            hasActiveFilters: viewModel.hasActiveListFilters
        )
        #expect(statePolicy == .noMatches)

        // Test clearing individual filter tag
        viewModel.clearFilter(category: .search)
        #expect(viewModel.invoiceSearchText == "")
        #expect(viewModel.hasActiveListFilters)

        viewModel.clearFilter(category: .client)
        #expect(viewModel.filterClients.isEmpty)

        viewModel.clearFilter(category: .amount)
        #expect(viewModel.filterMinAmount == nil)

        viewModel.clearFilter(category: .status)
        #expect(viewModel.invoiceFilterStatus.isEmpty)
        #expect(!(viewModel.hasActiveListFilters))

        // Re-apply filters and test clearListFilters() reset
        viewModel.invoiceSearchText = "Test"
        viewModel.invoiceFilterStatus = [InvoiceStatus.received.rawValue]
        #expect(viewModel.hasActiveListFilters)

        viewModel.clearListFilters()
        #expect(!(viewModel.hasActiveListFilters))
        #expect(viewModel.invoiceSearchText == "")
        #expect(viewModel.invoiceFilterStatus.isEmpty)
        #expect(viewModel.filterStartDate == nil)
        #expect(viewModel.filterEndDate == nil)
        #expect(viewModel.filterMinAmount == nil)
        #expect(viewModel.filterMaxAmount == nil)
        #expect(viewModel.filterClients.isEmpty)
    }

    // MARK: - 3. Batch Deletion Shortcut Triggers & State Handling Tests

    @Test func BatchDeletionShortcutTriggersAndStateHandling() async throws {
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
        #expect(InvoicesView.canBatchDelete(
            isMultiSelectMode: true,
            selectedInvoiceIDs: [inv1.id, inv2.id],
            selectedInvoiceID: nil,
            isPerformingBulkAction: false
        ))

        #expect(!(InvoicesView.canBatchDelete(
            isMultiSelectMode: true,
            selectedInvoiceIDs: [],
            selectedInvoiceID: nil,
            isPerformingBulkAction: false
        )))

        #expect(InvoicesView.canBatchDelete(
            isMultiSelectMode: false,
            selectedInvoiceIDs: [],
            selectedInvoiceID: inv1.id,
            isPerformingBulkAction: false
        ))

        #expect(!(InvoicesView.canBatchDelete(
            isMultiSelectMode: false,
            selectedInvoiceIDs: [],
            selectedInvoiceID: nil,
            isPerformingBulkAction: false
        )))

        #expect(!(InvoicesView.canBatchDelete(
            isMultiSelectMode: true,
            selectedInvoiceIDs: [inv1.id],
            selectedInvoiceID: nil,
            isPerformingBulkAction: true
        )))

        // Test deleteInvoices empty array handling
        let deletedZero = try await viewModel.deleteInvoices(ids: [])
        #expect(deletedZero == 0)

        // Test deleteInvoices batch deletion execution
        viewModel.selectedInvoice = inv1
        let deletedCount = try await viewModel.deleteInvoices(ids: [inv1.id, inv2.id])
        #expect(deletedCount == 2)
        #expect(viewModel.selectedInvoice == nil)
    }

    // MARK: - 4. Accessibility Announcement Text Generation Tests

    @Test func AccessibilityAnnouncementTextGeneration() {
        // Filter changes
        #expect(InvoiceAccessibilityAnnouncement.filterChanged(filteredCount: 4, totalCount: 15) == "Filtered to 4 invoices")
        #expect(InvoiceAccessibilityAnnouncement.filterChanged(filteredCount: 1, totalCount: 10) == "Filtered to 1 invoice")

        // Filters cleared
        #expect(InvoiceAccessibilityAnnouncement.filtersCleared(totalCount: 15) == "Filters cleared, showing 15 invoices")
        #expect(InvoiceAccessibilityAnnouncement.filtersCleared(totalCount: 1) == "Filters cleared, showing 1 invoice")

        // Empty states
        #expect(InvoiceAccessibilityAnnouncement.emptyState(state: .noMatches) == "No matching invoices")
        #expect(InvoiceAccessibilityAnnouncement.emptyState(state: .noInvoices) == "No invoices yet")
        #expect(InvoiceAccessibilityAnnouncement.emptyState(state: .needsRefresh) == "Invoices need refresh")
        #expect(InvoiceAccessibilityAnnouncement.emptyState(state: .content) == "")

        // Selection changed
        #expect(InvoiceAccessibilityAnnouncement.selectionChanged(selectedCount: 3) == "3 invoices selected")
        #expect(InvoiceAccessibilityAnnouncement.selectionChanged(selectedCount: 1) == "1 invoice selected")
        #expect(InvoiceAccessibilityAnnouncement.selectionChanged(selectedCount: 0) == "Selection cleared")

        // Action / refresh failure banners
        #expect(InvoiceAccessibilityAnnouncement.actionFailed("Duplicate failed") == "Invoice action failed. Duplicate failed")
        #expect(InvoiceAccessibilityAnnouncement.actionFailed("   ") == "Invoice action failed")
        #expect(InvoiceAccessibilityAnnouncement.refreshFailed("Network unavailable") == "Invoices couldn't refresh. Network unavailable")
        #expect(InvoiceAccessibilityAnnouncement.refreshFailed("") == "Invoices couldn't refresh")
    }

    // MARK: - 5. Edge Case: Clearing Filters With No Active Filters

    @Test func ClearingFiltersWithNoActiveFilters() {
        let container = try! ModelContainer(
            for: Invoice.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let viewModel = InvoicesContainerViewModel(modelContext: container.mainContext)

        // Verify baseline has no active filters
        #expect(!(viewModel.hasActiveListFilters))
        let initialRevision = viewModel.filterInputResetRevision

        // Clear all filters when already clear
        viewModel.clearListFilters()

        #expect(!(viewModel.hasActiveListFilters))
        #expect(viewModel.activeFilterDescriptions.isEmpty)
        #expect(viewModel.activeFilterTags.isEmpty)
        #expect(viewModel.activeFilterSummaryText == "")
        #expect(viewModel.filterInputResetRevision == initialRevision + 1)

        // Clear individual filter categories when already clear
        viewModel.clearSearchFilter()
        viewModel.clearStatusFilters()
        viewModel.clearDateFilters()
        viewModel.clearClientFilters()
        viewModel.clearAmountFilters()

        #expect(!(viewModel.hasActiveListFilters))
        #expect(viewModel.filterInputResetRevision == initialRevision + 6)
    }

    // MARK: - 6. Edge Case: Batch Deleting 0 Items

    @Test func BatchDeletingZeroItemsEdgeCase() async throws {
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

        #expect(deletedCount == 0)
        #expect(viewModel.totalInvoiceCount == 1)
        #expect(!(InvoicesView.canBatchDelete(
            isMultiSelectMode: true,
            selectedInvoiceIDs: [],
            selectedInvoiceID: nil,
            isPerformingBulkAction: false
        )))
    }

    // MARK: - 7. Edge Case: Batch Deleting All Items

    @Test func BatchDeletingAllItemsEdgeCase() async throws {
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

        #expect(deletedCount == 3)
        #expect(viewModel.totalInvoiceCount == 0)
        #expect(viewModel.invoiceEntities.isEmpty)
        #expect(viewModel.selectedInvoice == nil)

        let statePolicy = InvoicesListEmptyStatePolicy.resolve(
            totalInvoiceCount: viewModel.totalInvoiceCount,
            filteredCount: viewModel.invoiceEntities.count,
            hasActiveFilters: viewModel.hasActiveListFilters
        )
        #expect(statePolicy == .noInvoices)
        #expect(InvoiceAccessibilityAnnouncement.emptyState(state: statePolicy) == "No invoices yet")
    }

    // MARK: - 8. Edge Case: Hidden Selection Reconciliation When Filters Change

    @Test func HiddenSelectionReconciliationWhenFiltersChange() throws {
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
        #expect(viewModel.hasActiveListFilters)

        viewModel.reconcileSelection(visibleInvoiceIDs: [inv2.id])
        #expect(viewModel.selectedInvoice?.id == inv1.id, "Selected invoice hidden by active filter must remain open")

        // 2. Clear filters: selection stays intact when invoice becomes visible again
        viewModel.clearListFilters()
        #expect(!(viewModel.hasActiveListFilters))

        viewModel.reconcileSelection(visibleInvoiceIDs: [inv1.id, inv2.id])
        #expect(viewModel.selectedInvoice?.id == inv1.id)

        // 3. When filters ARE NOT active: selection is cleared if invoice is no longer visible
        viewModel.reconcileSelection(visibleInvoiceIDs: [inv2.id])
        #expect(viewModel.selectedInvoice == nil, "Selected invoice missing without active filters must clear selection")
    }

    // MARK: - 9. Edge Case: VoiceOver Announcements With Special Characters and Zero Counts

    @Test func VoiceOverAnnouncementsWithSpecialCharactersAndZeroCounts() {
        // Zero counts formatting
        #expect(InvoiceAccessibilityAnnouncement.filterChanged(filteredCount: 0, totalCount: 0) == "Filtered to 0 invoices")
        #expect(InvoiceAccessibilityAnnouncement.filterChanged(filteredCount: 0, totalCount: 5) == "Filtered to 0 invoices")
        #expect(InvoiceAccessibilityAnnouncement.filtersCleared(totalCount: 0) == "Filters cleared, showing 0 invoices")
        #expect(InvoiceAccessibilityAnnouncement.selectionChanged(selectedCount: 0) == "Selection cleared")

        // Special characters in filter search and tags
        let container = try! ModelContainer(
            for: Invoice.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let viewModel = InvoicesContainerViewModel(modelContext: container.mainContext)

        let specialSearch = "Acme & Co. \"Special\" <100%>"
        viewModel.invoiceSearchText = specialSearch
        #expect(viewModel.activeFilterDescriptions == ["Search \"\(specialSearch)\""])
        #expect(viewModel.activeFilterSummaryText == "Active filters: Search \"\(specialSearch)\"")
        #expect(viewModel.activeFilterTags.first?.label == "Search: \"\(specialSearch)\"")

        // Amount edge cases: zero amount, negative and non-finite normalization
        viewModel.updateFilterMinimumAmount(0.0)
        #expect(viewModel.filterMinAmount == 0.0)

        viewModel.updateFilterMinimumAmount(-100.0)
        #expect(viewModel.filterMinAmount == nil, "Negative amount should be normalized to nil")

        viewModel.updateFilterMinimumAmount(Double.nan)
        #expect(viewModel.filterMinAmount == nil, "NaN should be normalized to nil")

        viewModel.updateFilterMinimumAmount(Double.infinity)
        #expect(viewModel.filterMinAmount == nil, "Infinity should be normalized to nil")

        viewModel.updateFilterMinimumAmount(0.0)
        viewModel.updateFilterMaximumAmount(500.25)
        #expect(viewModel.activeFilterDescriptions == ["Search \"\(specialSearch)\"", "Amount: 0.00 – 500.25"])
    }
}
