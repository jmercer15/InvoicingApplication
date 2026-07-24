import SwiftUI
import SharedUI

struct InvoiceFilterPopoverContent: View {
    @Bindable private var viewModel: InvoicesContainerViewModel
    private let uniqueClientNames: [String]
    private let activeFilterCount: Int
    private let clearAllFilters: () -> Void

    @ScaledMetric private var clientListMaxHeight: CGFloat = DetailSectionTokens.listMinHeight

    init(
        viewModel: InvoicesContainerViewModel,
        uniqueClientNames: [String],
        activeFilterCount: Int,
        clearAllFilters: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.uniqueClientNames = uniqueClientNames
        self.activeFilterCount = activeFilterCount
        self.clearAllFilters = clearAllFilters
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.bottom, StyleGuide.Dimensions.paddingMediumLarge)

            statusSection
                .padding(.bottom, StyleGuide.Dimensions.paddingLarge)

            Divider()
                .padding(.bottom, StyleGuide.Dimensions.paddingMediumLarge)

            dateRangeSection
                .padding(.bottom, StyleGuide.Dimensions.paddingLarge)

            Divider()
                .padding(.bottom, StyleGuide.Dimensions.paddingMediumLarge)

            amountRangeSection
                .padding(.bottom, StyleGuide.Dimensions.paddingLarge)

            Divider()
                .padding(.bottom, StyleGuide.Dimensions.paddingMediumLarge)

            clientSection
        }
        .padding(StyleGuide.Dimensions.paddingLarge)
        .frame(width: StyleGuide.Dimensions.filterPopoverWidth)
    }

    private var header: some View {
        HStack {
            Text("Filters")
                .font(StyleGuide.Typography.itemTitle)
            Spacer()
            if activeFilterCount > 0 {
                Button("Clear All", action: clearAllFilters)
                    .buttonStyle(.borderless)
                    .foregroundStyle(ColorSystem.Status.error)
            }
        }
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingMedium) {
            HStack {
                Label("Status", systemImage: "tag")
                    .font(StyleGuide.Typography.bodyMedium)
                    .foregroundStyle(StyleGuide.Colors.textSecondary)
                Spacer()
                if !viewModel.invoiceFilterStatus.isEmpty && viewModel.invoiceFilterStatus.count < AppConstants.invoiceStatusOptions.count {
                    Button("Reset") {
                        viewModel.invoiceFilterStatus.removeAll()
                    }
                    .font(StyleGuide.Typography.caption)
                    .buttonStyle(.borderless)
                }
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: StyleGuide.Dimensions.paddingSmall) {
                ForEach(AppConstants.invoiceStatusOptions, id: \.self) { status in
                    StatusFilterButton(
                        status: status,
                        isSelected: viewModel.invoiceFilterStatus.isEmpty
                            || viewModel.invoiceFilterStatus.contains(status),
                        action: {
                            let allStatuses = Set(AppConstants.invoiceStatusOptions)
                            var selectedStatuses = viewModel.invoiceFilterStatus.isEmpty
                                ? allStatuses
                                : viewModel.invoiceFilterStatus
                            if selectedStatuses.contains(status) {
                                selectedStatuses.remove(status)
                            } else {
                                selectedStatuses.insert(status)
                            }
                            viewModel.invoiceFilterStatus = selectedStatuses == allStatuses
                                ? []
                                : selectedStatuses
                        }
                    )
                }
            }
        }
    }

    private var dateRangeSection: some View {
        VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingMedium) {
            HStack {
                Label("Date Range", systemImage: "calendar")
                    .font(StyleGuide.Typography.bodyMedium)
                    .foregroundStyle(StyleGuide.Colors.textSecondary)
                Spacer()
                if viewModel.isDateFilterActive {
                    Button("Clear") {
                        viewModel.filterStartDate = nil
                        viewModel.filterEndDate = nil
                    }
                    .font(StyleGuide.Typography.caption)
                    .buttonStyle(.borderless)
                    .foregroundStyle(ColorSystem.Status.error)
                }
            }

            Grid(alignment: .leading, horizontalSpacing: StyleGuide.Dimensions.paddingMedium) {
                GridRow {
                    Toggle(
                        "From",
                        isOn: Binding(
                            get: { viewModel.filterStartDate != nil },
                            set: {
                                viewModel.updateFilterStartDate(
                                    $0 ? (viewModel.filterStartDate ?? Date()) : nil
                                )
                            }
                        )
                    )
                    .toggleStyle(.checkbox)

                    DatePicker(
                        "Start date",
                        selection: Binding(
                            get: { viewModel.filterStartDate ?? Date() },
                            set: viewModel.updateFilterStartDate
                        ),
                        displayedComponents: .date
                    )
                    .labelsHidden()
                    .datePickerStyle(.field)
                    .disabled(viewModel.filterStartDate == nil)
                }

                GridRow {
                    Toggle(
                        "To",
                        isOn: Binding(
                            get: { viewModel.filterEndDate != nil },
                            set: {
                                viewModel.updateFilterEndDate(
                                    $0 ? (viewModel.filterEndDate ?? Date()) : nil
                                )
                            }
                        )
                    )
                    .toggleStyle(.checkbox)

                    DatePicker(
                        "End date",
                        selection: Binding(
                            get: { viewModel.filterEndDate ?? Date() },
                            set: viewModel.updateFilterEndDate
                        ),
                        displayedComponents: .date
                    )
                    .labelsHidden()
                    .datePickerStyle(.field)
                    .disabled(viewModel.filterEndDate == nil)
                }
            }
        }
    }

    private var amountRangeSection: some View {
        VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingMedium) {
            HStack {
                Label("Amount Range", systemImage: "dollarsign.circle")
                    .font(StyleGuide.Typography.bodyMedium)
                    .foregroundStyle(StyleGuide.Colors.textSecondary)
                Spacer()
                if viewModel.isAmountFilterActive {
                    Button("Clear") {
                        viewModel.clearAmountFilters()
                    }
                    .font(StyleGuide.Typography.caption)
                    .buttonStyle(.borderless)
                    .foregroundStyle(ColorSystem.Status.error)
                }
            }

            HStack(spacing: StyleGuide.Dimensions.paddingMedium) {
                InvoiceFilterAmountField(
                    "Min",
                    value: minimumAmountBinding,
                    resetRevision: viewModel.filterInputResetRevision
                )
                .frame(width: StyleGuide.Dimensions.filterAmountFieldWidth)

                Text("-")
                    .foregroundStyle(StyleGuide.Colors.textSecondary)

                InvoiceFilterAmountField(
                    "Max",
                    value: maximumAmountBinding,
                    resetRevision: viewModel.filterInputResetRevision
                )
                .frame(width: StyleGuide.Dimensions.filterAmountFieldWidth)
            }

            Text("Compared using each invoice's currency.")
                .font(StyleGuide.Typography.caption)
                .foregroundStyle(StyleGuide.Colors.textSecondary)
        }
    }

    private var clientSection: some View {
        VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingMedium) {
            HStack {
                Label("Client", systemImage: "person")
                    .font(StyleGuide.Typography.bodyMedium)
                    .foregroundStyle(StyleGuide.Colors.textSecondary)
                Spacer()
                if viewModel.isClientFilterActive {
                    Button("Clear") {
                        viewModel.filterClients.removeAll()
                    }
                    .font(StyleGuide.Typography.caption)
                    .buttonStyle(.borderless)
                    .foregroundStyle(ColorSystem.Status.error)
                }
            }

            if uniqueClientNames.isEmpty {
                Text("No clients found")
                    .font(StyleGuide.Typography.caption)
                    .foregroundStyle(StyleGuide.Colors.textSecondary)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: StyleGuide.Dimensions.paddingSmall) {
                        ForEach(uniqueClientNames, id: \.self) { client in
                            ClientFilterButton(
                                client: client,
                                isSelected: viewModel.filterClients.contains(client),
                                action: {
                                    if viewModel.filterClients.contains(client) {
                                        viewModel.filterClients.remove(client)
                                    } else {
                                        viewModel.filterClients.insert(client)
                                    }
                                }
                            )
                        }
                    }
                }
                .frame(maxHeight: clientListMaxHeight)
            }
        }
    }

    private var minimumAmountBinding: Binding<Double?> {
        Binding(
            get: { viewModel.filterMinAmount },
            set: viewModel.updateFilterMinimumAmount
        )
    }

    private var maximumAmountBinding: Binding<Double?> {
        Binding(
            get: { viewModel.filterMaxAmount },
            set: viewModel.updateFilterMaximumAmount
        )
    }
}

private struct StatusFilterButton: View {
    let status: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            let shape = RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusCompact, style: .continuous)
            HStack(spacing: StyleGuide.Dimensions.paddingSmall) {
                Image(systemName: statusIcon)
                    .foregroundStyle(isSelected ? statusColor : StyleGuide.Colors.textSecondary)
                    .font(StyleGuide.Typography.itemSubtitle)
                Text(AppConstants.invoiceStatusDisplayName(for: status))
                    .font(StyleGuide.Typography.itemSubtitle)
                    .lineLimit(1)
            }
            .padding(.horizontal, StyleGuide.Dimensions.paddingXMedium)
            .padding(.vertical, StyleGuide.Dimensions.unsavedIndicatorSize)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isSelected
                ? statusColor.opacity(StyleGuide.Opacity.light)
                : StyleGuide.Colors.secondary.opacity(StyleGuide.Opacity.faint)
            )
            .clipShape(shape)
            .overlay(
                shape
                    .strokeBorder(isSelected ? statusColor.opacity(StyleGuide.Opacity.strong) : Color.clear, lineWidth: 1)
            )
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .pointerStyle(.link)
        .accessibilityAddTraits(.isButton)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var statusIcon: String {
        switch status {
        case AppConstants.invoiceStatusReviewDraft: return isSelected ? "doc.fill" : "doc"
        case AppConstants.invoiceStatusReadyToSend: return isSelected ? "checkmark.circle.fill" : "checkmark.circle"
        case AppConstants.invoiceStatusPending: return isSelected ? "paperplane.fill" : "paperplane"
        case AppConstants.invoiceStatusReceived: return isSelected ? "checkmark.seal.fill" : "checkmark.seal"
        case AppConstants.invoiceStatusOverdue: return isSelected ? "exclamationmark.triangle.fill" : "exclamationmark.triangle"
        case AppConstants.invoiceStatusCancelled: return isSelected ? "xmark.circle.fill" : "xmark.circle"
        case AppConstants.invoiceStatusVoided: return isSelected ? "slash.circle.fill" : "slash.circle"
        default: return isSelected ? "circle.fill" : "circle"
        }
    }

    private var statusColor: Color {
        ColorSystem.Invoice.statusColor(for: status)
    }
}

private struct ClientFilterButton: View {
    let client: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            let shape = RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusCompact, style: .continuous)
            HStack(spacing: StyleGuide.Dimensions.paddingXSmall) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? ColorSystem.Primary.blue : StyleGuide.Colors.textSecondary)
                    .font(StyleGuide.Typography.caption)
                Text(client)
                    .font(StyleGuide.Typography.caption)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .padding(.horizontal, StyleGuide.Dimensions.paddingMedium)
            .padding(.vertical, StyleGuide.Dimensions.paddingSmall)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isSelected
                ? ColorSystem.Primary.blue.opacity(StyleGuide.Opacity.light)
                : StyleGuide.Colors.secondary.opacity(StyleGuide.Opacity.faint)
            )
            .clipShape(shape)
            .overlay(
                shape
                    .strokeBorder(isSelected ? ColorSystem.Primary.blue.opacity(StyleGuide.Opacity.strong) : Color.clear, lineWidth: 1)
            )
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .pointerStyle(.link)
        .accessibilityAddTraits(.isButton)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
