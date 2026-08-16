import SwiftUI
import Core
import SharedUI

// MARK: - Invoice Filter Summary


enum InvoiceFilterSummary {
    static func amountRange(
        minimum: Double?,
        maximum: Double?,
        locale: Locale = .current
    ) -> String {
        let minimumText = formattedAmount(minimum, locale: locale)
        let maximumText = formattedAmount(maximum, locale: locale)
        return "Amount: \(minimumText) – \(maximumText)"
    }

    private static func formattedAmount(_ amount: Double?, locale: Locale) -> String {
        guard let amount else { return "–" }
        return InvoiceFilterAmountInput.string(for: amount, locale: locale)
    }
}

struct InvoicesContentToolbar: ToolbarContent {
    @Bindable private var viewModel: InvoicesContainerViewModel
    @Binding private var showingFilterPopover: Bool
    private let uniqueClientNames: [String]
    private let onCreateInvoice: @MainActor () -> Void


    init(
        viewModel: InvoicesContainerViewModel,
        showingFilterPopover: Binding<Bool>,
        uniqueClientNames: [String],
        onCreateInvoice: @escaping @MainActor () -> Void
    ) {
        self.viewModel = viewModel
        self._showingFilterPopover = showingFilterPopover
        self.uniqueClientNames = uniqueClientNames
        self.onCreateInvoice = onCreateInvoice
    }

    var body: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            AppToolbarPrimaryCreateButton(
                viewModel.invoiceCreationPhase.progressTitle,
                systemImage: viewModel.isCreatingInvoice ? "clock" : "plus.circle.fill",
                help: viewModel.isCreatingInvoice
                    ? viewModel.invoiceCreationPhase.progressTitle
                    : "Create a new invoice",
                action: onCreateInvoice
            )
            .disabled(viewModel.isCreatingInvoice)
        }

        AppToolbarUtilityGroup {
            organizeMenu
            filterButton
        }
    }

    private var organizeMenu: some View {
        Menu {
            Section("Group By") {
                ForEach(GroupBy.allCases) { option in
                    Button {
                        viewModel.groupBy = option
                    } label: {
                        HStack {
                            Label(option.rawValue, systemImage: groupByIcon(for: option))
                            Spacer()
                            AppToolbarMenuCheckmark(isSelected: viewModel.groupBy == option)
                        }
                    }
                }
            }

            Section("Sort By") {
                ForEach(SortField.allCases) { field in
                    Button {
                        if viewModel.sortField == field {
                            viewModel.sortDirection = viewModel.sortDirection == .ascending ? .descending : .ascending
                        } else {
                            viewModel.sortField = field
                        }
                    } label: {
                        HStack {
                            Label(field.rawValue, systemImage: sortFieldIcon(for: field))
                            Spacer()
                            if viewModel.sortField == field {
                                Image(systemName: viewModel.sortDirection == .ascending ? "chevron.up" : "chevron.down")
                                    .foregroundStyle(StyleGuide.Colors.primary)
                            }
                        }
                    }
                }

                Divider()

                Button {
                    viewModel.sortDirection = .ascending
                } label: {
                    Label("Ascending", systemImage: "arrow.up")
                }

                Button {
                    viewModel.sortDirection = .descending
                } label: {
                    Label("Descending", systemImage: "arrow.down")
                }
            }
        } label: {
            Label {
                Text(organizeMenuTitle)
            } icon: {
                Image(systemName: "arrow.up.arrow.down.circle")
            }
        }
        .appToolbarLinkStyle(help: "Group and sort invoices", compactLabels: false)
    }

    private var organizeMenuTitle: String {
        if viewModel.groupBy == .none {
            return viewModel.sortField.rawValue
        }
        return "\(viewModel.groupBy.rawValue) · \(viewModel.sortField.rawValue)"
    }

    private var filterButton: some View {
        Button {
            showingFilterPopover.toggle()
        } label: {
            AppToolbarFilterMenuLabel(
                "Filter",
                systemImage: "line.3.horizontal.decrease.circle",
                selectionCount: activeFilterCount
            )
        }
        .appToolbarLinkStyle(help: filterHelpText, compactLabels: false)
        .popover(isPresented: $showingFilterPopover, arrowEdge: .bottom) {
            InvoiceFilterPopoverContent(
                viewModel: viewModel,
                uniqueClientNames: uniqueClientNames,
                activeFilterCount: activeFilterCount,
                clearAllFilters: clearAllFilters
            )
        }
    }

    private var activeFilterCount: Int {
        (viewModel.isDateFilterActive ? 1 : 0)
            + (viewModel.isAmountFilterActive ? 1 : 0)
            + (viewModel.isClientFilterActive ? 1 : 0)
            + ((viewModel.invoiceFilterStatus.isEmpty || viewModel.invoiceFilterStatus.count == AppConstants.invoiceStatusOptions.count) ? 0 : 1)
    }

    private var filterHelpText: String {
        var parts: [String] = []
        if !viewModel.invoiceFilterStatus.isEmpty && viewModel.invoiceFilterStatus.count < AppConstants.invoiceStatusOptions.count {
            parts.append("Status: \(viewModel.invoiceFilterStatus.count)/\(AppConstants.invoiceStatusOptions.count)")
        }
        if viewModel.isDateFilterActive {
            let startStr = viewModel.filterStartDate.map { DateFormatting.shortDate($0) } ?? "-"
            let endStr = viewModel.filterEndDate.map { DateFormatting.shortDate($0) } ?? "-"
            parts.append("Date: \(startStr) - \(endStr)")
        }
        if viewModel.isAmountFilterActive {
            parts.append(InvoiceFilterSummary.amountRange(
                minimum: viewModel.filterMinAmount,
                maximum: viewModel.filterMaxAmount
            ))
        }
        if viewModel.isClientFilterActive {
            parts.append("Clients: \(viewModel.filterClients.count)")
        }
        return parts.isEmpty ? "Filter invoices" : parts.joined(separator: ", ")
    }

    private func clearAllFilters() {
        viewModel.clearListFilters()
    }

    private func groupByIcon(for option: GroupBy) -> String {
        switch option {
        case .none: return "list.bullet"
        case .status: return "tag"
        case .client: return "person"
        case .month: return "calendar"
        case .quarter: return "calendar.badge.clock"
        }
    }

    private func sortFieldIcon(for field: SortField) -> String {
        switch field {
        case .date: return "calendar"
        case .dueDate: return "calendar.badge.clock"
        case .amount: return "dollarsign.circle"
        case .clientName: return "person"
        case .invoiceNumber: return "number"
        }
    }
}

// MARK: - Invoices View Toolbar

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
