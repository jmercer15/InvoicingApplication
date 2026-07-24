// swift-tools-version:5.9

import Foundation
import SwiftData
import Core
import Data
import InvoiceTableLayoutEditor

extension InvoicesContainerViewModel {

    enum InvoiceListReloadOutcome: Equatable {
        case published
        case superseded
        case failed
    }

    // MARK: - List Query

    var listQuerySpec: InvoicesListQuerySpec {
        InvoicesListQuerySpec(
            searchText: invoiceSearchText,
            statuses: invoiceFilterStatus,
            filterStartDate: filterStartDate,
            filterEndDate: filterEndDate,
            minimumAmount: filterMinAmount,
            maximumAmount: filterMaxAmount,
            clientNames: filterClients,
            sortField: sortField,
            sortDirection: sortDirection,
            groupBy: groupBy
        )
    }

    // MARK: - Fetch & Delete

    /// Feature-owned creation boundary. Keeps persistence, list materialization, and detail
    /// selection coherent before AppShell publishes navigation for created invoice.
    public func createInvoice() async throws -> UUID {
        try beginInvoiceCreation()
        defer { finishInvoiceCreation() }

        try await prepareCurrentInvoiceForCreation()

        let id = try await InvoiceEditorStore.createInvoice(in: modelContainer)
        guard let invoice = try persistenceCommands.fetchInvoice(
            matching: FetchDescriptor<Invoice>(
                predicate: #Predicate<Invoice> { $0.id == id }
            )
        ) else {
            throw InvoicesFeatureError.createdInvoiceUnavailable
        }
        invalidateListLoad()
        clearListFilters()
        revealInvoiceInList(invoice, countAsNew: true)
        requestSelectInvoice(invoice)
        dismissActionError()
        return id
    }

    public func duplicateInvoice(_ sourceInvoice: Invoice) async throws -> UUID {
        try beginInvoiceCreation()
        defer { finishInvoiceCreation() }

        try await prepareCurrentInvoiceForCreation()

        let sourceID = sourceInvoice.id
        let id = try await InvoiceEditorStore.duplicateInvoice(id: sourceID, in: modelContainer)
        guard let invoice = try persistenceCommands.fetchInvoice(
            matching: FetchDescriptor<Invoice>(
                predicate: #Predicate<Invoice> { $0.id == id }
            )
        ) else {
            throw InvoicesFeatureError.createdInvoiceUnavailable
        }
        invalidateListLoad()
        clearListFilters()
        revealInvoiceInList(invoice, countAsNew: true)
        requestSelectInvoice(invoice)
        dismissActionError()
        return id
    }

    @discardableResult
    func reloadInvoices(
        matching descriptor: FetchDescriptor<Invoice>
    ) async -> InvoiceListReloadOutcome {
        let requestedPersistenceSpec = InvoicesListQueryEngine.buildPersistenceQuerySpec(
            from: listQuerySpec
        )
        let requestID = beginListLoad()
        defer { finishListLoad(requestID) }

        do {
            try Task.checkCancellation()
            async let matchingIDs = listFetcher.invoiceIDs(matching: descriptor)
            async let storeCount = listFetcher.totalInvoiceCount()
            let (ids, totalCount) = try await (matchingIDs, storeCount)
            try Task.checkCancellation()

            let invoices = try persistenceCommands.fetchInvoices(ids: ids)
            try Task.checkCancellation()
            guard isCurrentListLoad(requestID) else { return .superseded }

            lastSuccessfulPersistenceSpec = requestedPersistenceSpec
            invoiceEntities = invoices
            totalInvoiceCount = totalCount
            updateLoadedInvoices(invoices)
            hasCompletedSuccessfulListLoad = true
            listLoadError = nil
            return .published
        } catch is CancellationError {
            return .superseded
        } catch {
            guard isCurrentListLoad(requestID) else { return .superseded }
            // Preserve last successful projection and selection during transient store failures.
            // Presentation keeps those rows interactive and adds a nonblocking retry banner.
            listLoadError = InvoiceOperationErrorPresentation.detail(
                for: error,
                fallback: "Invoice data could not be refreshed. Try again."
            )
            print("❌ [InvoicesContainerViewModel] Failed loading invoices: \(error)")
            return .failed
        }
    }

    @discardableResult
    func deleteInvoices(ids: [UUID]) async throws -> Int {
        guard !ids.isEmpty else { return 0 }
        let deletedIDs = Set(ids)
        let deletionLease = await editorSession.prepareForDeletingInvoices(deletedIDs)
        let invoices: [Invoice]
        do {
            try Task.checkCancellation()
            invoices = try persistenceCommands.fetchInvoices(ids: ids)
            try persistenceCommands.deleteInvoices(invoices)
        } catch {
            editorSession.cancelDeletingInvoices(deletionLease)
            throw error
        }
        editorSession.completeDeletingInvoices(
            deletionLease,
            deletedInvoiceIDs: deletedIDs
        )
        invoiceEntities.removeAll { deletedIDs.contains($0.id) }
        totalInvoiceCount = max(0, totalInvoiceCount - invoices.count)
        updateLoadedInvoices(invoiceEntities)
        if let selectedID = selectedInvoice?.id, deletedIDs.contains(selectedID) {
            applySelection(nil)
        }
        return invoices.count
    }

    // MARK: - Visible Rows & Deep Link

    /// Keeps the latest projection-backed invoice rows for deep-link selection decisions.
    func updateLoadedInvoices(_ invoices: [Invoice]) {
        loadedInvoicesByID = Dictionary(uniqueKeysWithValues: invoices.map { ($0.id, $0) })
        analyticsSummary = InvoiceAnalyticsEngine.calculateSummary(from: invoices)
        listContentRevision &+= 1
    }

    /// Keeps list and detail coherent without treating a filtered-out row as a deletion.
    /// Persisted drafts remain open while filters hide their list row; explicit mutation paths
    /// still clear selection when an invoice is actually deleted.
    func reconcileSelection(visibleInvoiceIDs: Set<UUID>) {
        guard let selectedID = selectedInvoice?.id,
              !visibleInvoiceIDs.contains(selectedID)
        else { return }
        guard !hasActiveListFilters else { return }
        requestClearSelection()
    }

    /// Cross-tab / inspector / Billing Hub: first check loaded query rows, then fallback to bounded fetch.
    public func selectInvoiceForDeepLink(id: UUID) {
        // Imperative reveal owns list state immediately. Any older filtered query must not publish
        // after this method materializes its destination but before SwiftUI starts replacement load.
        invalidateListLoad()
        if let invoice = loadedInvoicesByID[id] {
            if hasActiveListFilters {
                clearListFilters()
            }
            requestSelectInvoice(invoice)
            dismissActionError()
            return
        }

        var descriptor = FetchDescriptor<Invoice>(
            predicate: #Predicate<Invoice> { $0.id == id }
        )
        descriptor.fetchLimit = 1

        do {
            if let invoice = try persistenceCommands.fetchInvoice(matching: descriptor) {
                // Route navigation must reveal its destination. Clear filters only after the
                // destination is known to exist so failed routes preserve current list context.
                clearListFilters()
                revealInvoiceInList(invoice)
                requestSelectInvoice(invoice)
                dismissActionError()
            } else {
                requestClearSelection()
                reportActionError("Invoice couldn't be opened because it no longer exists.")
            }
        } catch {
            // A targeted navigation failure is not a list-load failure. Keep existing rows,
            // selection, filters, and refresh state intact so users can recover in place.
            let detail = InvoiceOperationErrorPresentation.detail(
                for: error,
                fallback: "Invoice data could not be read. Try again."
            )
            reportActionError("Invoice couldn't be opened. \(detail)")
            print("❌ [InvoicesContainerViewModel] Error selecting invoice for deep link: \(error)")
        }
    }

    func reconcileEditorMutation(_ mutation: InvoiceEditorMutation) async {
        switch mutation {
        case .inserted(let id):
            // Creation is a reveal workflow. Remove stale filters first, then materialize through
            // the same query path as every other list refresh so row membership and totals agree.
            clearListFilters()
            let outcome = await reloadInvoices(
                matching: InvoicesListQueryEngine.buildPersistenceDescriptor(from: listQuerySpec)
            )
            guard outcome == .published else {
                // A newer query now owns publication. It will reconcile this row; do not turn
                // normal supersession into a user-facing creation error.
                if let invoice = loadedInvoicesByID[id] {
                    applySelection(invoice)
                }
                return
            }
            guard let invoice = loadedInvoicesByID[id] else {
                reportActionError("Invoice was created, but its list row could not be refreshed.")
                return
            }
            applySelection(invoice)
        case .updated(let id):
            // An edit can move a row into or out of active status/date/amount filters. A targeted
            // fetch would bypass those constraints and can also observe a stale registered model
            // immediately after the editor actor saves.
            let outcome = await reloadInvoices(
                matching: InvoicesListQueryEngine.buildPersistenceDescriptor(from: listQuerySpec)
            )
            if outcome == .published,
               selectedInvoice?.id == id,
               let refreshedInvoice = loadedInvoicesByID[id] {
                applySelection(refreshedInvoice)
            }
        case .deleted(let id):
            invoiceEntities.removeAll { $0.id == id }
            totalInvoiceCount = max(0, totalInvoiceCount - 1)
            updateLoadedInvoices(invoiceEntities)
            if selectedInvoice?.id == id {
                requestClearSelection()
            }
        }
    }

    private func revealInvoiceInList(_ invoice: Invoice, countAsNew: Bool = false) {
        let wasLoaded = loadedInvoicesByID[invoice.id] != nil
        if let index = invoiceEntities.firstIndex(where: { $0.id == invoice.id }) {
            invoiceEntities[index] = invoice
        } else {
            invoiceEntities.append(invoice)
        }
        if countAsNew && !wasLoaded {
            totalInvoiceCount += 1
        }
        totalInvoiceCount = max(totalInvoiceCount, invoiceEntities.count)
        updateLoadedInvoices(invoiceEntities)
    }
}
