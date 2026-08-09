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

extension InvoicesView {
    var invoiceList: some View {
        VStack(spacing: 0) {
            if containerViewModel.totalInvoiceCount > 0 {
                RevenueAnalyticsSummaryView(summary: containerViewModel.analyticsSummary)
                    .padding(.horizontal, StyleGuide.Dimensions.paddingLarge)
                    .padding(.top, StyleGuide.Dimensions.paddingSmall)
                listContextBar
            }

            ScrollableInvoicesList(
                totalInvoiceCount: containerViewModel.totalInvoiceCount,
                filteredCount: projection.filteredInvoices.count,
                groupedCount: projection.groupedInvoices.count,
                treeItems: projection.treeItems,
                selectedItemIDs: highlightedTreeItemIDs,
                hasActiveFilters: containerViewModel.hasActiveListFilters,
                activeFilterSummaryText: containerViewModel.activeFilterSummaryText,
                activeFilterTags: containerViewModel.activeFilterTags,
                isRefreshing: containerViewModel.isLoading,
                creationPhase: containerViewModel.invoiceCreationPhase,
                onItemTap: handleItemTap,
                makeContextMenu: { item in
                    if let entityID = item.entityID,
                       let uuid = UUID(uuidString: entityID),
                       let invoice = projection.filteredInvoices.first(where: { $0.id == uuid }) {
                        Button("Duplicate Invoice", systemImage: "doc.on.doc") {
                            duplicateInvoice(invoice)
                        }
                        Button("Export CSV", systemImage: "tablecells") {
                            exportSingleInvoiceCSV(invoice)
                        }
                        Button("Export JSON", systemImage: "arrow.triangle.2.circlepath") {
                            exportSingleInvoiceJSON(invoice)
                        }
                        Divider()
                        Button("Delete Invoice", systemImage: "trash", role: .destructive) {
                            deleteBatch = InvoiceDeleteBatch(invoiceIDs: [invoice.id])
                        }
                    }
                },
                onCreateInvoice: onCreateInvoice,
                onClearFilters: containerViewModel.clearListFilters,
                onClearFilterTag: { category in containerViewModel.clearFilter(category: category) },
                onRefresh: refreshInvoiceList
            )

            if isMultiSelectMode {
                multiSelectBar
            }
        }
        .background(.clear)
        .animation(
            reduceMotion
                ? nil
                : .easeInOut(duration: StyleGuide.Animations.durationMedium),
            value: isMultiSelectMode
        )
    }

    private var highlightedTreeItemIDs: Set<String> {
        let selectedIDs: [UUID]
        if isMultiSelectMode {
            selectedIDs = Array(selectedInvoiceIDs)
        } else {
            selectedIDs = selectedInvoice.map { [$0.id] } ?? []
        }
        return Set(selectedIDs.map { "invoice_\($0)" })
    }

    var selectedInvoiceEntities: [Invoice] {
        projection.filteredInvoices.filter { selectedInvoiceIDs.contains($0.id) }
    }

    var selectedDocumentRequests: [InvoiceBulkDocumentRequest] {
        selectedInvoiceEntities.map(InvoiceBulkDocumentRequest.init(invoice:))
    }

    var allVisibleInvoicesSelected: Bool {
        !visibleInvoiceIDs.isEmpty && selectedInvoiceIDs == visibleInvoiceIDs
    }

    var visibleInvoiceIDs: Set<UUID> {
        Set(projection.filteredInvoices.map(\.id))
    }

    var selectedInvoiceIsHiddenByFilters: Bool {
        guard let selectedID = selectedInvoice?.id else { return false }
        return containerViewModel.hasActiveListFilters && !visibleInvoiceIDs.contains(selectedID)
    }

    func duplicateInvoice(_ invoice: Invoice) {
        Task {
            do {
                _ = try await containerViewModel.duplicateInvoice(invoice)
                NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
            } catch {
                let detail = InvoiceOperationErrorPresentation.detail(
                    for: error,
                    fallback: "Invoice could not be duplicated. Try again."
                )
                containerViewModel.reportActionError("Duplicate failed. \(detail)")
            }
        }
    }

    func bulkExportCSVSelectedInvoices() {
        let selectedInvoices = selectedInvoiceEntities
        guard !selectedInvoices.isEmpty else { return }

        let panel = NSSavePanel()
        panel.title = "Export Invoices to CSV"
        panel.nameFieldStringValue = "Invoices.csv"
        panel.allowedContentTypes = [.commaSeparatedText]

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            let csvText = InvoiceDataExporter.exportCSV(invoices: selectedInvoices)
            do {
                try csvText.write(to: url, atomically: true, encoding: .utf8)
                NSWorkspace.shared.activateFileViewerSelecting([url])
                bulkActionResult = BulkActionResult(
                    title: "CSV Export Complete",
                    message: "Exported \(selectedInvoices.count) \(selectedInvoices.count == 1 ? "invoice" : "invoices") to CSV."
                )
            } catch {
                bulkActionResult = BulkActionResult(
                    title: "CSV Export Failed",
                    message: InvoiceOperationErrorPresentation.detail(
                        for: error,
                        fallback: "Invoices could not be exported to CSV. Try again."
                    )
                )
            }
        }
    }

    func bulkExportJSONSelectedInvoices() {
        let selectedInvoices = selectedInvoiceEntities
        guard !selectedInvoices.isEmpty else { return }

        let panel = NSSavePanel()
        panel.title = "Export Invoices to JSON"
        panel.nameFieldStringValue = "Invoices.json"
        panel.allowedContentTypes = [.json]

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                let data = try InvoiceDataExporter.exportJSONData(invoices: selectedInvoices)
                try data.write(to: url, options: .atomic)
                NSWorkspace.shared.activateFileViewerSelecting([url])
                bulkActionResult = BulkActionResult(
                    title: "JSON Export Complete",
                    message: "Exported \(selectedInvoices.count) \(selectedInvoices.count == 1 ? "invoice" : "invoices") to JSON."
                )
            } catch {
                bulkActionResult = BulkActionResult(
                    title: "JSON Export Failed",
                    message: InvoiceOperationErrorPresentation.detail(
                        for: error,
                        fallback: "Invoices could not be exported to JSON. Try again."
                    )
                )
            }
        }
    }

    private func exportSingleInvoiceCSV(_ invoice: Invoice) {
        let panel = NSSavePanel()
        panel.title = "Export Invoice to CSV"
        let number = invoice.invoiceNumber.isEmpty ? "Draft" : invoice.invoiceNumber
        panel.nameFieldStringValue = "\(number).csv"
        panel.allowedContentTypes = [.commaSeparatedText]

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            let csvText = InvoiceDataExporter.exportCSV(invoices: [invoice])
            do {
                try csvText.write(to: url, atomically: true, encoding: .utf8)
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } catch {
                let detail = InvoiceOperationErrorPresentation.detail(
                    for: error,
                    fallback: "Invoice could not be exported to CSV. Try again."
                )
                containerViewModel.reportActionError("Export failed. \(detail)")
            }
        }
    }

    private func exportSingleInvoiceJSON(_ invoice: Invoice) {
        let panel = NSSavePanel()
        panel.title = "Export Invoice to JSON"
        let number = invoice.invoiceNumber.isEmpty ? "Draft" : invoice.invoiceNumber
        panel.nameFieldStringValue = "\(number).json"
        panel.allowedContentTypes = [.json]

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                let data = try InvoiceDataExporter.exportJSONData(invoices: [invoice])
                try data.write(to: url, options: .atomic)
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } catch {
                let detail = InvoiceOperationErrorPresentation.detail(
                    for: error,
                    fallback: "Invoice could not be exported to JSON. Try again."
                )
                containerViewModel.reportActionError("Export failed. \(detail)")
            }
        }
    }

    private func refreshInvoiceList() {
        Task {
            await containerViewModel.reloadInvoices(
                matching: InvoicesListQueryEngine.buildPersistenceDescriptor(
                    from: containerViewModel.listQuerySpec
                )
            )
        }
    }

}

private struct ScrollableInvoicesList<ContextMenu: View>: View {
    let totalInvoiceCount: Int
    let filteredCount: Int
    let groupedCount: Int
    let treeItems: [TreeItem]
    let selectedItemIDs: Set<String>
    let hasActiveFilters: Bool
    let activeFilterSummaryText: String
    let activeFilterTags: [InvoiceFilterTag]
    let isRefreshing: Bool
    let creationPhase: InvoiceCreationPhase
    let onItemTap: (TreeItem) -> Void
    let makeContextMenu: (TreeItem) -> ContextMenu
    let onCreateInvoice: @MainActor () -> Void
    let onClearFilters: @MainActor () -> Void
    let onClearFilterTag: @MainActor (InvoiceFilterTag.FilterCategory) -> Void
    let onRefresh: @MainActor () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        totalInvoiceCount: Int,
        filteredCount: Int,
        groupedCount: Int,
        treeItems: [TreeItem],
        selectedItemIDs: Set<String>,
        hasActiveFilters: Bool,
        activeFilterSummaryText: String,
        activeFilterTags: [InvoiceFilterTag],
        isRefreshing: Bool,
        creationPhase: InvoiceCreationPhase,
        onItemTap: @escaping (TreeItem) -> Void,
        @ViewBuilder makeContextMenu: @escaping (TreeItem) -> ContextMenu,
        onCreateInvoice: @escaping @MainActor () -> Void,
        onClearFilters: @escaping @MainActor () -> Void,
        onClearFilterTag: @escaping @MainActor (InvoiceFilterTag.FilterCategory) -> Void,
        onRefresh: @escaping @MainActor () -> Void
    ) {
        self.totalInvoiceCount = totalInvoiceCount
        self.filteredCount = filteredCount
        self.groupedCount = groupedCount
        self.treeItems = treeItems
        self.selectedItemIDs = selectedItemIDs
        self.hasActiveFilters = hasActiveFilters
        self.activeFilterSummaryText = activeFilterSummaryText
        self.activeFilterTags = activeFilterTags
        self.isRefreshing = isRefreshing
        self.creationPhase = creationPhase
        self.onItemTap = onItemTap
        self.makeContextMenu = makeContextMenu
        self.onCreateInvoice = onCreateInvoice
        self.onClearFilters = onClearFilters
        self.onClearFilterTag = onClearFilterTag
        self.onRefresh = onRefresh
    }

    @ViewBuilder
    var body: some View {
        switch InvoicesListEmptyStatePolicy.resolve(
            totalInvoiceCount: totalInvoiceCount,
            filteredCount: filteredCount,
            hasActiveFilters: hasActiveFilters
        ) {
        case .noInvoices:
            VStack(spacing: StyleGuide.Dimensions.paddingLarge) {
                EmptyStateView(
                    icon: "doc.text.magnifyingglass",
                    title: "No Invoices Yet",
                    message: "Create your first invoice to start tracking billing."
                )
                if creationPhase.isActive {
                    ProgressView(creationPhase.progressTitle)
                        .controlSize(.small)
                } else {
                    Button("New Invoice", systemImage: "plus") {
                        onCreateInvoice()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .frame(maxHeight: .infinity)
            .standardContentPanelListInsets()
            .fluidTransition()
        case .noMatches:
            VStack(spacing: StyleGuide.Dimensions.paddingLarge) {
                EmptyStateView(
                    icon: "line.3.horizontal.decrease.circle",
                    title: "No Matching Invoices",
                    message: activeFilterSummaryText.isEmpty ? "Change search or filters to see more results." : activeFilterSummaryText
                )

                if !activeFilterTags.isEmpty {
                    VStack(spacing: StyleGuide.Dimensions.paddingSmall) {
                        Text("Active Filters")
                            .font(StyleGuide.Typography.caption)
                            .foregroundStyle(StyleGuide.Colors.textSecondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: StyleGuide.Dimensions.paddingSmall) {
                                ForEach(activeFilterTags, id: \.id) { tag in
                                    HStack(spacing: StyleGuide.Dimensions.paddingXXSmall) {
                                        Text(tag.label)
                                            .font(StyleGuide.Typography.caption)
                                            .foregroundStyle(.primary)
                                        Button {
                                            onClearFilterTag(tag.id)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.caption)
                                                .foregroundStyle(StyleGuide.Colors.textSecondary)
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel("Clear \(tag.label) filter")
                                    }
                                    .padding(.horizontal, StyleGuide.Dimensions.paddingSmall)
                                    .padding(.vertical, StyleGuide.Dimensions.paddingXXSmall)
                                    .background(
                                        Capsule()
                                            .fill(ColorSystem.Neutral.gray100)
                                            .overlay(Capsule().stroke(ColorSystem.Neutral.gray300, lineWidth: 1))
                                    )
                                }
                            }
                            .padding(.horizontal, StyleGuide.Dimensions.paddingSmall)
                        }
                    }
                    .padding(.horizontal, StyleGuide.Dimensions.paddingLarge)
                }

                Button("Clear Search and Filters", systemImage: "xmark.circle") {
                    onClearFilters()
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("Clear search and all active filters")
            }
            .frame(maxHeight: .infinity)
            .standardContentPanelListInsets()
            .fluidTransition()
        case .needsRefresh:
            VStack(spacing: StyleGuide.Dimensions.paddingLarge) {
                EmptyStateView(
                    icon: "arrow.clockwise.circle",
                    title: "Invoices Need Refresh",
                    message: "Invoice records changed while this list was updating."
                )
                if isRefreshing {
                    ProgressView("Refreshing invoices…")
                        .controlSize(.small)
                } else {
                    Button("Refresh Invoices", systemImage: "arrow.clockwise") {
                        onRefresh()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .frame(maxHeight: .infinity)
            .standardContentPanelListInsets()
            .fluidTransition()
        case .content:
            // Use hierarchical list
            FoldPaperContainer(
                items: .constant(treeItems),
                selectedItemIDs: selectedItemIDs,
                rootTitle: "All Invoices",
                onItemTap: onItemTap,
                makeContextMenu: makeContextMenu
            )
        }
    }
}
