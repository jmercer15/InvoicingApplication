import SwiftUI
import SwiftData
import AppKit
import SharedUI
import Data
import Core
import Feature_InvoiceTemplateEditor

public struct InvoicesContentColumn: View {
    @ObservedObject private var viewModel: InvoicesContainerViewModel
    @State private var showingFilterPopover = false

    public init(viewModel: InvoicesContainerViewModel) {
        self._viewModel = ObservedObject(wrappedValue: viewModel)
    }

    public var body: some View {
        invoiceList
            .onAppear(perform: syncContext)
            .toolbar(content: toolbarContent)

            .navigationTitle("Invoices")
            .searchable(text: $viewModel.invoiceSearchText, placement: .automatic, prompt: "Search invoices...")
    }

    private var invoiceList: some View {
        InvoicesView(
            searchText: $viewModel.invoiceSearchText,
            selectedInvoice: $viewModel.selectedInvoice,
            filterStatus: $viewModel.invoiceFilterStatus,
            groupBy: $viewModel.groupBy,
            sortField: $viewModel.sortField,
            sortDirection: $viewModel.sortDirection,
            containerViewModel: viewModel
        )
        .scrollContentBackground(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ToolbarContentBuilder
    private func toolbarContent() -> some ToolbarContent {
        // MARK: - Primary Action
        ToolbarItem(placement: .automatic) {
            Button(action: viewModel.prepareNewInvoice) {
                Label("New Invoice", systemImage: "plus")
            }
            .keyboardShortcut("n")
            .glassEffect(.regular.tint(.blue).interactive(), in: .buttonBorder)
            .help("Create a new invoice")
            .pointerStyle(.link)
        }

        // MARK: - Group & Sort & Filter
        ToolbarItemGroup(placement: .automatic) {
            // MARK: - Group Menu
            Menu {
                ForEach(GroupBy.allCases) { option in
                    Button {
                        viewModel.groupBy = option
                    } label: {
                        HStack {
                            Label(option.rawValue, systemImage: groupByIcon(for: option))
                            Spacer()
                            if viewModel.groupBy == option {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color("Primary", bundle: .sharedUI))
                            }
                        }
                    }
                }
            } label: {
                Label {
                    Text(viewModel.groupBy == .none ? "Group" : viewModel.groupBy.rawValue)
                } icon: {
                    Image(systemName: viewModel.groupBy == .none ? "square.stack" : "square.stack.fill")
                }
            }
            .help(viewModel.groupBy == .none ? "Group invoices" : "Grouped by \(viewModel.groupBy.rawValue)")
            .pointerStyle(.link)

            // MARK: - Sort Menu
            Menu {
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
                                    .foregroundStyle(Color("Primary", bundle: .sharedUI))
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
            } label: {
                Label {
                    Text(viewModel.sortField.rawValue)
                } icon: {
                    Image(systemName: viewModel.sortDirection == .ascending ? "arrow.up" : "arrow.down")
                }
            }
            .help("Sort by \(viewModel.sortField.rawValue), \(viewModel.sortDirection == .ascending ? "ascending" : "descending")")
            .pointerStyle(.link)

            // MARK: - Filter Button with Popover
            Button {
                showingFilterPopover.toggle()
            } label: {
                Label {
                    Text(activeFilterCount > 0 ? "Filter (\(activeFilterCount))" : "Filter")
                } icon: {
                    Image(systemName: activeFilterCount > 0 ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                }
            }
            .help(filterHelpText)
            .pointerStyle(.link)
            .popover(isPresented: $showingFilterPopover, arrowEdge: .bottom) {
                filterPopoverContent
            }
        }
    }

    private var activeFilterCount: Int {
        (viewModel.isDateFilterActive ? 1 : 0)
            + (viewModel.isAmountFilterActive ? 1 : 0)
            + (viewModel.isClientFilterActive ? 1 : 0)
            + ((viewModel.invoiceFilterStatus.isEmpty || viewModel.invoiceFilterStatus.count == AppConstants.invoiceStatusOptions.count) ? 0 : 1)
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

    @ViewBuilder
    private var filterPopoverContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Filters")
                    .font(.headline)
                Spacer()
                if activeFilterCount > 0 {
                    Button("Clear All") {
                        clearAllFilters()
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.red)
                }
            }
            .padding(.bottom, 12)

            // Status Section
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Status", systemImage: "tag")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if !viewModel.invoiceFilterStatus.isEmpty && viewModel.invoiceFilterStatus.count < AppConstants.invoiceStatusOptions.count {
                        Button("Reset") {
                            viewModel.invoiceFilterStatus = Set(AppConstants.invoiceStatusOptions)
                        }
                        .font(.caption)
                        .buttonStyle(.borderless)
                    }
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                    ForEach(AppConstants.invoiceStatusOptions, id: \.self) { status in
                        StatusFilterButton(
                            status: status,
                            isSelected: viewModel.invoiceFilterStatus.contains(status),
                            action: {
                                if viewModel.invoiceFilterStatus.contains(status) {
                                    viewModel.invoiceFilterStatus.remove(status)
                                } else {
                                    viewModel.invoiceFilterStatus.insert(status)
                                }
                            }
                        )
                    }
                }
            }
            .padding(.bottom, 16)

            Divider()
                .padding(.bottom, 12)

            // Date Range Section
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Date Range", systemImage: "calendar")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if viewModel.isDateFilterActive {
                        Button("Clear") {
                            viewModel.filterStartDate = nil
                            viewModel.filterEndDate = nil
                        }
                        .font(.caption)
                        .buttonStyle(.borderless)
                        .foregroundStyle(.red)
                    }
                }

                HStack(spacing: 8) {
                    DatePicker(
                        "From",
                        selection: Binding(
                            get: { viewModel.filterStartDate ?? Date() },
                            set: { viewModel.filterStartDate = $0 }
                        ),
                        displayedComponents: .date
                    )
                    .labelsHidden()
                    .datePickerStyle(.field)

                    Text("→")
                        .foregroundStyle(.tertiary)

                    DatePicker(
                        "To",
                        selection: Binding(
                            get: { viewModel.filterEndDate ?? Date() },
                            set: { viewModel.filterEndDate = $0 }
                        ),
                        displayedComponents: .date
                    )
                    .labelsHidden()
                    .datePickerStyle(.field)
                }
            }
            .padding(.bottom, 16)

            Divider()
                .padding(.bottom, 12)

            // Amount Range Section
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Amount Range", systemImage: "dollarsign.circle")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if viewModel.isAmountFilterActive {
                        Button("Clear") {
                            viewModel.filterMinAmount = nil
                            viewModel.filterMaxAmount = nil
                        }
                        .font(.caption)
                        .buttonStyle(.borderless)
                        .foregroundStyle(.red)
                    }
                }

                HStack(spacing: 8) {
                    HStack(spacing: 2) {
                        Text("$")
                            .foregroundStyle(.secondary)
                            .font(.callout)
                        TextField("Min", value: $viewModel.filterMinAmount, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 70)
                    }

                    Text("–")
                        .foregroundStyle(.tertiary)

                    HStack(spacing: 2) {
                        Text("$")
                            .foregroundStyle(.secondary)
                            .font(.callout)
                        TextField("Max", value: $viewModel.filterMaxAmount, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 70)
                    }
                }
            }
            .padding(.bottom, 16)

            Divider()
                .padding(.bottom, 12)

            // Client Filter Section
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Client", systemImage: "person")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if viewModel.isClientFilterActive {
                        Button("Clear") {
                            viewModel.filterClients.removeAll()
                        }
                        .font(.caption)
                        .buttonStyle(.borderless)
                        .foregroundStyle(.red)
                    }
                }

                if viewModel.uniqueClientNames.isEmpty {
                    Text("No clients found")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                            ForEach(viewModel.uniqueClientNames, id: \.self) { client in
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
                    .frame(maxHeight: 120)
                }
            }
        }
        .padding()
        .frame(width: 300)
    }

    private func clearAllFilters() {
        viewModel.invoiceFilterStatus = Set(AppConstants.invoiceStatusOptions)
        viewModel.filterStartDate = nil
        viewModel.filterEndDate = nil
        viewModel.filterMinAmount = nil
        viewModel.filterMaxAmount = nil
        viewModel.filterClients.removeAll()
    }

    private var filterHelpText: String {
        var parts: [String] = []
        if !viewModel.invoiceFilterStatus.isEmpty && viewModel.invoiceFilterStatus.count < AppConstants.invoiceStatusOptions.count {
            parts.append("Status: \(viewModel.invoiceFilterStatus.count)/\(AppConstants.invoiceStatusOptions.count)")
        }
        if viewModel.isDateFilterActive {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            let startStr = viewModel.filterStartDate.map { formatter.string(from: $0) } ?? "—"
            let endStr = viewModel.filterEndDate.map { formatter.string(from: $0) } ?? "—"
            parts.append("Date: \(startStr) – \(endStr)")
        }
        if viewModel.isAmountFilterActive {
            let minStr = viewModel.filterMinAmount.map { "$\(Int($0))" } ?? "—"
            let maxStr = viewModel.filterMaxAmount.map { "$\(Int($0))" } ?? "—"
            parts.append("Amount: \(minStr) – \(maxStr)")
        }
        if viewModel.isClientFilterActive {
            parts.append("Clients: \(viewModel.filterClients.count)")
        }
        return parts.isEmpty ? "Filter invoices" : parts.joined(separator: ", ")
    }

    private func syncContext() {
        // Note: updateContextIfNeeded removed - repositories handle persistence
        viewModel.initializeIfNeeded()
    }
}

public struct InvoicesDetailColumn: View {
    @ObservedObject private var viewModel: InvoicesContainerViewModel
    @Binding private var showInspector: Bool

    // Template services for invoice rendering
    @EnvironmentObject var templateDataService: TemplateDataService
    @EnvironmentObject var templateManager: TemplateManager

    public init(viewModel: InvoicesContainerViewModel, showInspector: Binding<Bool>) {
        self._viewModel = ObservedObject(wrappedValue: viewModel)
        self._showInspector = showInspector
    }

    public var body: some View {
        detailContent
            .onAppear(perform: syncContext)
            .toolbar(content: detailToolbar)
            .inspector(isPresented: $showInspector) {
                inspectorContent
            }
    }

    @ViewBuilder
    private var inspectorContent: some View {
        if let editorViewModel = viewModel.invoiceEditorViewModel,
           viewModel.isEditingInvoice {
            VStack(spacing: 0) {
                HStack {
                    Text("Edit Invoice")
                        .font(.headline)
                    Spacer()
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))

                ScrollView {
                    InvoiceEditorFormContent(viewModel: editorViewModel)
                        .padding()
                }
            }
            .inspectorColumnWidth(min: 350, ideal: 400, max: 500)
        } else {
            VStack {
                Text("No invoice selected for editing")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        ZStack {
            if viewModel.isTransitioningToBlack {
                Rectangle()
                    .fill(Color.clear)
                    .id("invoice_detail_transition")
            } else if let editorViewModel = viewModel.invoiceEditorViewModel {
                InvoiceEditor(
                    viewModel: editorViewModel,
                    isEditing: $viewModel.isEditingInvoice,
                    showInspector: $showInspector
                )
                .id("invoice-editor-\(editorViewModel.invoice.id.uuidString)")
                .environmentObject(templateDataService)
                .environmentObject(templateManager)
            } else {
                EmptyStateView(
                    icon: "doc.text.fill",
                    title: "No Invoice Selected",
                    message: "Select an invoice from the list or create a new one."
                )
                .id("invoice_detail_placeholder")
            }
        }
    }

    @ToolbarContentBuilder
    private func detailToolbar() -> some ToolbarContent {
        if viewModel.selectedInvoice != nil {
            ToolbarItem(placement: .automatic) {
                Button {
                    withAnimation(.easeInOut(duration: StyleGuide.Animations.durationMedium)) {
                        viewModel.isEditingInvoice.toggle()
                    }
                } label: {
                    Label(
                        viewModel.isEditingInvoice ? "Done Editing" : "Edit Invoice",
                        systemImage: viewModel.isEditingInvoice ? "checkmark" : "pencil"
                    )
                }
                .help(viewModel.isEditingInvoice ? "Finish editing" : "Edit the selected invoice")
                .pointerStyle(.link)
            }
        }

        if let editorViewModel = viewModel.invoiceEditorViewModel, !viewModel.isEditingInvoice {
            ToolbarItemGroup(placement: .automatic) {
                Button(action: editorViewModel.printInvoice) {
                    Label("Print", systemImage: "printer")
                }
                .help("Print invoice")
                .pointerStyle(.link)

                Button(action: editorViewModel.exportInvoiceToPDF) {
                    Label("Export PDF", systemImage: "square.and.arrow.down.on.square")
                }
                .help("Export invoice to PDF")
                .pointerStyle(.link)

                Button {
                    Task {
                        if let provider = await editorViewModel.itemProviderForPDFSharing() {
                            await MainActor.run {
                                let items: [Any] = [editorViewModel.shareBodyText() as NSString, provider]
                                let picker = NSSharingServicePicker(items: items)
                                if let keyWindow = NSApp.keyWindow, let contentView = keyWindow.contentView {
                                    picker.show(relativeTo: .zero, of: contentView, preferredEdge: .minY)
                                }
                            }
                        }
                    }
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .help("Share invoice")
                .pointerStyle(.link)

                // Status Quick Actions Menu
                Menu {
                    Button(action: editorViewModel.markAsSent) {
                        Label("Mark as Sent", systemImage: "paperplane.fill")
                    }
                    .disabled(!editorViewModel.canMarkAsSent)

                    Button(action: editorViewModel.markAsPaid) {
                        Label("Mark as Paid", systemImage: "checkmark.circle.fill")
                    }
                    .disabled(!editorViewModel.canMarkAsPaid)

                    Divider()

                    Text("Current: \(AppConstants.invoiceStatusDisplayName(for: editorViewModel.status))")
                        .foregroundStyle(.secondary)

                    if let complianceMessage = editorViewModel.complianceStatusMessage,
                       !complianceMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Divider()
                        Text(complianceMessage)
                            .font(.caption)
                            .foregroundStyle(editorViewModel.complianceStatusIsBlocker ? .red : .orange)
                    }
                } label: {
                    Label("Status", systemImage: "flag.fill")
                }
                .help("Change invoice status")
                .pointerStyle(.link)
            }
        }
    }

    private func syncContext() {
        // Note: updateContextIfNeeded removed - repositories handle persistence
        viewModel.initializeIfNeeded()
    }
}

// MARK: - Status Filter Button
private struct StatusFilterButton: View {
    let status: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
            HStack(spacing: 6) {
                Image(systemName: statusIcon)
                    .foregroundStyle(isSelected ? statusColor : .secondary)
                    .font(.system(size: 12))
                Text(AppConstants.invoiceStatusDisplayName(for: status))
                    .font(.system(size: 12))
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? statusColor.opacity(0.12) : Color.secondary.opacity(0.08))
            .cornerRadius(6)
            .overlay(
                shape
                    .strokeBorder(isSelected ? statusColor.opacity(0.3) : Color.clear, lineWidth: 1)
            )
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .pointerStyle(.link)
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
        switch status {
        case AppConstants.invoiceStatusReviewDraft: return .secondary
        case AppConstants.invoiceStatusReadyToSend: return .yellow
        case AppConstants.invoiceStatusPending: return .blue
        case AppConstants.invoiceStatusReceived: return .green
        case AppConstants.invoiceStatusOverdue: return .red
        case AppConstants.invoiceStatusCancelled: return .orange
        case AppConstants.invoiceStatusVoided: return .purple
        default: return .blue
        }
    }
}

// MARK: - Client Filter Button
private struct ClientFilterButton: View {
    let client: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
            HStack(spacing: 4) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .blue : .secondary)
                    .font(.system(size: 11))
                Text(client)
                    .font(.system(size: 11))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Color.blue.opacity(0.12) : Color.secondary.opacity(0.08))
            .cornerRadius(6)
            .overlay(
                shape
                    .strokeBorder(isSelected ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
            )
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .pointerStyle(.link)
    }
}
