//
//  InvoicesView.swift
//  InvoicingApplication
//
//  Created by Jesse Mercer on 23/3/2025.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers
import InvoiceTableLayoutEditor
import Core
import PersistenceModels
import SharedUI

struct InvoicesView: View {
    @Binding var selectedInvoice: Invoice?
    // Container view model for toolbar actions
    @Bindable var containerViewModel: InvoicesContainerViewModel

    @State var isMultiSelectMode = false
    @State var selectedInvoiceIDs: Set<UUID> = []
    @State var bulkActionActivity = InvoiceBulkActionActivity()
    @State var bulkActionResult: BulkActionResult?
    @State var emailShareCoordinator: InvoiceEmailShareCoordinator?
    @State var bulkExportTask: Task<Void, Never>?
    @State var bulkEmailPreparationTask: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    // Add state variables for confirmation dialog
    @State var deleteBatch: InvoiceDeleteBatch?

    var isDeleteConfirmationPresented: Binding<Bool> {
        Binding(
            get: { deleteBatch != nil },
            set: { if !$0 { deleteBatch = nil } }
        )
    }

    struct InvoiceDeleteBatch: Identifiable {
        let id = UUID()
        let invoiceIDs: Set<UUID>
    }

    struct BulkActionResult: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    var isPerformingBulkAction: Bool {
        bulkActionActivity.isBusy
    }

    let projection: InvoicesListProjection
    let onSelectionChanged: ((AppSelection?) -> Void)?
    let onCreateInvoice: @MainActor () -> Void

    // Initializer
    init(selectedInvoice: Binding<Invoice?>,
         projection: InvoicesListProjection,
         containerViewModel: InvoicesContainerViewModel,
         onSelectionChanged: ((AppSelection?) -> Void)? = nil,
         onCreateInvoice: @escaping @MainActor () -> Void
    ) {
        self._selectedInvoice = selectedInvoice
        self.projection = projection
        self.containerViewModel = containerViewModel
        self.onSelectionChanged = onSelectionChanged
        self.onCreateInvoice = onCreateInvoice
    }

    var body: some View {
        VStack(spacing: 0) {
            // Invoice list with real-time filtering
            invoiceList
        }
        .background(Color.clear)
        .onChange(of: selectedInvoice) { _, newInvoice in
            onSelectionChanged?(newInvoice.map { .invoice($0.id) })
        }
        .confirmationDialog(
            InvoiceDeleteCopy.title(count: deleteBatch?.invoiceIDs.count ?? 0),
            isPresented: isDeleteConfirmationPresented,
            presenting: deleteBatch,
            actions: { batch in
                Button(
                    InvoiceDeleteCopy.actionTitle(count: batch.invoiceIDs.count),
                    role: .destructive
                ) {
                    performDeleteInvoices(batch.invoiceIDs)
                }
                Button("Cancel", role: .cancel) {}
            },
            message: { batch in
                Text(InvoiceDeleteCopy.message(
                    count: batch.invoiceIDs.count,
                    discardsUnsavedChanges: discardsOpenDraft(batch)
                ))
            }
        )
        .alert(item: $bulkActionResult) { result in
            Alert(
                title: Text(result.title),
                message: Text(result.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .onExitCommand(perform: handleMultiSelectExit)
        .onDisappear {
            bulkExportTask?.cancel()
            bulkExportTask = nil
            bulkEmailPreparationTask?.cancel()
            bulkEmailPreparationTask = nil
        }
        .onChange(of: visibleInvoiceIDs) { _, visibleIDs in
            let prunedSelection = selectedInvoiceIDs.intersection(visibleIDs)
            if prunedSelection != selectedInvoiceIDs {
                selectedInvoiceIDs = prunedSelection
            }
            containerViewModel.reconcileSelection(visibleInvoiceIDs: visibleIDs)
        }
        .onChange(of: selectedInvoiceIDs) { _, newIDs in
            if isMultiSelectMode {
                InvoiceAccessibilityAnnouncement.announce(
                    InvoiceAccessibilityAnnouncement.selectionChanged(selectedCount: newIDs.count)
                )
            }
        }
        .onChange(of: isMultiSelectMode) { _, isMulti in
            if isMulti {
                InvoiceAccessibilityAnnouncement.announce(
                    InvoiceAccessibilityAnnouncement.selectionChanged(selectedCount: selectedInvoiceIDs.count)
                )
            }
        }
        .onChange(of: containerViewModel.hasActiveListFilters) { oldValue, newValue in
            if oldValue && !newValue {
                InvoiceAccessibilityAnnouncement.announce(
                    InvoiceAccessibilityAnnouncement.filtersCleared(totalCount: containerViewModel.totalInvoiceCount)
                )
            }
        }
        .onChange(of: projection.filteredInvoices.count) { _, newCount in
            if containerViewModel.hasActiveListFilters {
                InvoiceAccessibilityAnnouncement.announce(
                    InvoiceAccessibilityAnnouncement.filterChanged(
                        filteredCount: newCount,
                        totalCount: containerViewModel.totalInvoiceCount
                    )
                )
            }
        }
        .onChange(of: currentEmptyState) { _, newState in
            if newState == .noMatches || newState == .noInvoices {
                InvoiceAccessibilityAnnouncement.announce(
                    InvoiceAccessibilityAnnouncement.emptyState(state: newState)
                )
            }
        }
        .background(
            Group {
                Button("Delete Selected Invoices", action: deleteSelectedInvoices)
                    .keyboardShortcut(.delete, modifiers: [.command])
                    .disabled(isDeleteShortcutDisabled)
                    .opacity(0)
                    .allowsHitTesting(false)

                Button("Delete Selected Invoices", action: deleteSelectedInvoices)
                    .keyboardShortcut(.delete, modifiers: [])
                    .disabled(isDeleteShortcutDisabled)
                    .opacity(0)
                    .allowsHitTesting(false)
            }
        )
    }

    private var currentEmptyState: InvoicesListEmptyState {
        InvoicesListEmptyStatePolicy.resolve(
            totalInvoiceCount: containerViewModel.totalInvoiceCount,
            filteredCount: projection.filteredInvoices.count,
            hasActiveFilters: containerViewModel.hasActiveListFilters
        )
    }

    public static func canBatchDelete(
        isMultiSelectMode: Bool,
        selectedInvoiceIDs: Set<UUID>,
        selectedInvoiceID: UUID?,
        isPerformingBulkAction: Bool
    ) -> Bool {
        guard !isPerformingBulkAction else { return false }
        if isMultiSelectMode {
            return !selectedInvoiceIDs.isEmpty
        } else {
            return selectedInvoiceID != nil
        }
    }

    var isDeleteShortcutDisabled: Bool {
        !Self.canBatchDelete(
            isMultiSelectMode: isMultiSelectMode,
            selectedInvoiceIDs: selectedInvoiceIDs,
            selectedInvoiceID: selectedInvoice?.id,
            isPerformingBulkAction: isPerformingBulkAction
        )
    }

    // MARK: - Helper Methods

    // Handle item tap from hierarchical list
    func handleItemTap(_ item: TreeItem) {
        guard let entityID = item.entityID,
              let uuid = UUID(uuidString: entityID) else { return }

        // Find the invoice by ID
        if let invoice = projection.filteredInvoices.first(where: { $0.id == uuid }) {
            handleInvoiceTap(invoice: invoice)
        }
    }

    // Update the deleteSelectedInvoices function to show confirmation dialog
    func deleteSelectedInvoices() {
        let targetIDs: Set<UUID>
        if isMultiSelectMode {
            targetIDs = selectedInvoiceIDs
        } else if let singleID = selectedInvoice?.id {
            targetIDs = [singleID]
        } else {
            targetIDs = []
        }
        guard !targetIDs.isEmpty, !isPerformingBulkAction else { return }
        deleteBatch = InvoiceDeleteBatch(invoiceIDs: targetIDs)
    }

    private func discardsOpenDraft(_ batch: InvoiceDeleteBatch) -> Bool {
        guard containerViewModel.editorSession.hasUnsavedChanges,
              let openInvoiceID = containerViewModel.editorSession.selectedInvoiceID
        else { return false }
        return batch.invoiceIDs.contains(openInvoiceID)
    }

}
