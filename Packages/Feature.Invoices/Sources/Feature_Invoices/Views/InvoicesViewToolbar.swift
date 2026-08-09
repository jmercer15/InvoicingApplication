//
//  InvoicesViewToolbar.swift
//  InvoicingApplication
//

import SwiftUI
import SharedUI

extension InvoicesView {
    var listContextBar: some View {
        HStack(spacing: StyleGuide.Dimensions.paddingMedium) {
            Text(resultSummary)
                .font(StyleGuide.Typography.caption)
                .foregroundStyle(StyleGuide.Colors.textSecondary)
                .monospacedDigit()

            if selectedInvoiceIsHiddenByFilters {
                Label("Selected invoice hidden", systemImage: "eye.slash")
                    .font(StyleGuide.Typography.caption)
                    .foregroundStyle(.orange)
                    .help("Current invoice remains open but is hidden by list filters")
            }

            Spacer()

            if selectedInvoiceIsHiddenByFilters {
                Button("Reveal Selected", systemImage: "eye") {
                    containerViewModel.clearListFilters()
                }
                .buttonStyle(.borderless)
                .help("Clear filters and reveal current invoice")
            } else if containerViewModel.hasActiveListFilters {
                Button("Clear Filters", systemImage: "line.3.horizontal.decrease.circle") {
                    containerViewModel.clearListFilters()
                }
                .buttonStyle(.borderless)
                .help("Show all invoices")
            }

            if !isMultiSelectMode, let selected = selectedInvoice {
                Button("Duplicate", systemImage: "doc.on.doc") {
                    duplicateInvoice(selected)
                }
                .buttonStyle(.borderless)
                .help("Duplicate current invoice")
            }

            if !isMultiSelectMode, !projection.filteredInvoices.isEmpty {
                Button("Select", systemImage: "checkmark.circle") {
                    isMultiSelectMode = true
                }
                .buttonStyle(.borderless)
                .help("Select multiple invoices")
            }
        }
        .padding(.horizontal, StyleGuide.Dimensions.paddingLarge)
        .padding(.vertical, StyleGuide.Dimensions.paddingSmall)
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
    }

    var multiSelectBar: some View {
        HStack(spacing: StyleGuide.Dimensions.paddingMedium) {
            if isPerformingBulkAction {
                bulkActionProgress
            }

            VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingXXSmall) {
                Text(isPerformingBulkAction ? bulkActionActivity.progressTitle : "\(selectedInvoiceIDs.count) selected")
                    .foregroundStyle(ColorSystem.Neutral.white)
                    .font(StyleGuide.Typography.bodyMedium)
                    .monospacedDigit()
                Text(multiSelectDetailText)
                    .foregroundStyle(ColorSystem.Neutral.white.opacity(0.8))
                    .font(StyleGuide.Typography.caption)
                    .lineLimit(1)
            }

            Spacer(minLength: StyleGuide.Dimensions.paddingSmall)

            Button(allVisibleInvoicesSelected ? "Clear Selection" : "Select All") {
                if allVisibleInvoicesSelected {
                    selectedInvoiceIDs.removeAll()
                } else {
                    selectedInvoiceIDs = visibleInvoiceIDs
                }
            }
            .buttonStyle(.borderless)
            .foregroundStyle(ColorSystem.Neutral.white)
            .disabled(isPerformingBulkAction)
            .help(allVisibleInvoicesSelected ? "Clear invoice selection" : "Select all visible invoices")

            Menu("Actions", systemImage: "ellipsis.circle") {
                Button("Export PDFs", systemImage: "square.and.arrow.up", action: bulkExportSelectedInvoices)
                Button("Export CSV", systemImage: "tablecells", action: bulkExportCSVSelectedInvoices)
                Button("Export JSON", systemImage: "arrow.triangle.2.circlepath", action: bulkExportJSONSelectedInvoices)
                Button("Email Selected", systemImage: "envelope", action: bulkEmailSelectedInvoices)

                Divider()

                Button("Delete Selected", systemImage: "trash", role: .destructive) {
                    deleteSelectedInvoices()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedInvoiceIDs.isEmpty || isPerformingBulkAction)

            if bulkActionActivity.canCancel {
                Button("Cancel") {
                    cancelActiveBulkAction()
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)
                .help("Cancel \(bulkActionActivity.progressTitle.lowercased())")
            } else {
                Button("Done") {
                    endMultiSelection()
                }
                .buttonStyle(.bordered)
                .disabled(isPerformingBulkAction)
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding(StyleGuide.Dimensions.paddingMedium)
        .glassEffect(
            .regular.interactive(true),
            in: .rect(cornerRadius: StyleGuide.Dimensions.cornerRadiusMedium)
        )
        .padding(.horizontal, StyleGuide.Dimensions.paddingLarge)
        .padding(.bottom, StyleGuide.Dimensions.paddingLarge)
    }

    @ViewBuilder
    var bulkActionProgress: some View {
        if bulkActionActivity.phase == .preparing,
           bulkActionActivity.totalCount > 0,
           bulkActionActivity.operation != .delete {
            ProgressView(
                value: Double(bulkActionActivity.completedCount),
                total: Double(bulkActionActivity.totalCount)
            )
            .progressViewStyle(.circular)
            .controlSize(.small)
            .accessibilityLabel(bulkActionActivity.progressTitle)
            .accessibilityValue(
                "\(bulkActionActivity.completedCount) of \(bulkActionActivity.totalCount)"
            )
        } else {
            ProgressView()
                .controlSize(.small)
                .accessibilityLabel(bulkActionActivity.progressTitle)
        }
    }

    var resultSummary: String {
        let count = projection.filteredInvoices.count
        if containerViewModel.isShowingPreviousQueryResults {
            let noun = count == 1 ? "result" : "results"
            return "\(count) previous \(noun)"
        }
        if containerViewModel.hasActiveListFilters {
            let totalNoun = containerViewModel.totalInvoiceCount == 1 ? "invoice" : "invoices"
            return "\(count) of \(containerViewModel.totalInvoiceCount) \(totalNoun)"
        }
        let noun = count == 1 ? "invoice" : "invoices"
        return "\(count) \(noun)"
    }

    var multiSelectDetailText: String {
        if bulkActionActivity.phase == .preparing,
           bulkActionActivity.totalCount > 0,
           bulkActionActivity.operation != .delete {
            return "\(bulkActionActivity.completedCount) of \(bulkActionActivity.totalCount) prepared"
        }
        if bulkActionActivity.phase == .sharing {
            return "Complete or cancel sharing in Mail"
        }
        if bulkActionActivity.operation == .delete {
            return "Removing selected invoices"
        }
        return selectedInvoiceIDs.isEmpty
            ? "Click invoices to select them"
            : "Choose an action or keep selecting"
    }
}
