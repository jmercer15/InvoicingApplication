import SwiftUI
import Core
import SharedUI

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

    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }()

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
            let startStr = viewModel.filterStartDate.map { Self.shortDateFormatter.string(from: $0) } ?? "-"
            let endStr = viewModel.filterEndDate.map { Self.shortDateFormatter.string(from: $0) } ?? "-"
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
