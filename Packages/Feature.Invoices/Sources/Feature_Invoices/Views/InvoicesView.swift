//
//  InvoicesView.swift
//  InvoicingApplication
//
//  Created by Jesse Mercer on 23/3/2025.
//

import SwiftUI
import Combine
import AppKit  // Add this import for NSScreen
import PDFKit
import Core
import SharedUI
import Feature_InvoiceTemplateEditor

struct InvoicesView: View {
    @Binding var searchText: String
    @Binding var selectedInvoice: Invoice?

    // Bindings for filter and sort state, controlled by the parent container
    @Binding var filterStatus: Set<String> // Changed to Set<String> for multi-selection
    
    // Container view model for toolbar actions
    @ObservedObject var containerViewModel: InvoicesContainerViewModel

    // State for the ID-based selection used by UnifiedListView
    @State private var selectedInvoiceId: UUID? = nil

    // Use @Binding for groupBy from container
    @Binding var groupBy: GroupBy
    @State private var isMultiSelectMode = false
    @State private var selectedInvoices: Set<Invoice> = []
    @Binding var sortField: SortField
    @Binding var sortDirection: SortDirection
    
    // Add state variables for confirmation dialog
    @State private var showingDeleteConfirmation = false
    @State private var invoicesToDelete: Set<Invoice> = []
    @State private var expandedGroups: Set<String> = []
    @Namespace private var namespace
    
    // Tree items for hierarchical list
    @State private var treeItems: [TreeItem] = []
    
    // Filter state is now in containerViewModel, accessed via computed properties
    private var isDateFilterActive: Bool { containerViewModel.isDateFilterActive }
    private var filterStartDate: Date? { containerViewModel.filterStartDate }
    private var filterEndDate: Date? { containerViewModel.filterEndDate }
    private var isAmountFilterActive: Bool { containerViewModel.isAmountFilterActive }
    private var filterMinAmount: Double? { containerViewModel.filterMinAmount }
    private var filterMaxAmount: Double? { containerViewModel.filterMaxAmount }
    private var isClientFilterActive: Bool { containerViewModel.isClientFilterActive }
    private var filterClients: Set<String> { containerViewModel.filterClients }
    
    // Use invoices from container ViewModel (domain models)
    private var invoices: [Invoice] {
        containerViewModel.allInvoices
    }
    
    // Computed property for filtered invoices
    private var filteredInvoices: [Invoice] {
        var filtered = invoices

        // Apply search filter across multiple fields
        if !searchText.isEmpty {
            let q = searchText.localizedLowercase
            filtered = filtered.filter { invoice in
                let haystack = [
                    invoice.invoiceNumber,
                    invoice.clientName ?? "",
                    invoice.billToName ?? "",
                    invoice.billToEmail ?? "",
                    invoice.notes ?? ""
                ].joined(separator: " \u{2022} ").localizedLowercase
                return haystack.localizedStandardContains(q)
            }
        }

        // Apply status filter
        if !filterStatus.isEmpty {
            filtered = filtered.filter { invoice in
                filterStatus.contains(invoice.status)
            }
        }

        // Apply date range filter
        if isDateFilterActive {
            let calendar = Calendar.current
            filtered = filtered.filter { invoice in
                var matches = true
                if let start = filterStartDate {
                    let startOfDay = calendar.startOfDay(for: start)
                    matches = matches && invoice.date >= startOfDay
                }
                if let end = filterEndDate {
                    let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: end) ?? end
                    matches = matches && invoice.date <= endOfDay
                }
                return matches
            }
        }
        
        // Apply amount range filter
        if isAmountFilterActive {
            filtered = filtered.filter { invoice in
                var matches = true
                if let min = filterMinAmount {
                    matches = matches && invoice.totalAmount >= min
                }
                if let max = filterMaxAmount {
                    matches = matches && invoice.totalAmount <= max
                }
                return matches
            }
        }
        
        // Apply client filter
        if isClientFilterActive {
            filtered = filtered.filter { invoice in
                guard let clientName = invoice.clientName, !clientName.isEmpty else {
                    return false
                }
                return filterClients.contains(clientName)
            }
        }
        // Apply sorting
        let sortOrder = InvoicesSortOrder.from(field: sortField, direction: sortDirection)
        return filtered.sorted(by: { first, second in
            switch sortOrder {
            case .dateDesc:
                return first.date > second.date
            case .dateAsc:
                return first.date < second.date
            case .dueDateDesc:
                return (first.dueDate ?? Date.distantPast) > (second.dueDate ?? Date.distantPast)
            case .dueDateAsc:
                return (first.dueDate ?? Date.distantPast) < (second.dueDate ?? Date.distantPast)
            case .amountDesc:
                return first.totalAmount > second.totalAmount
            case .amountAsc:
                return first.totalAmount < second.totalAmount
            case .clientName:
                return (first.clientName ?? "") < (second.clientName ?? "")
            case .invoiceNumber:
                return first.invoiceNumber < second.invoiceNumber
            case .numberAsc:
                return first.invoiceNumber < second.invoiceNumber
            case .numberDesc:
                return first.invoiceNumber > second.invoiceNumber
            case .statusAsc:
                return first.status < second.status
            case .statusDesc:
                return first.status > second.status
            }
        })
    }
    

    

    
    // Initializer
    init(searchText: Binding<String>, 
         selectedInvoice: Binding<Invoice?>,
         filterStatus: Binding<Set<String>>,
         groupBy: Binding<GroupBy>,
         sortField: Binding<SortField>,
         sortDirection: Binding<SortDirection>,
         containerViewModel: InvoicesContainerViewModel
    ) {
        self._searchText = searchText
        self._selectedInvoice = selectedInvoice
        self._filterStatus = filterStatus
        self._groupBy = groupBy
        self._sortField = sortField
        self._sortDirection = sortDirection
        self.containerViewModel = containerViewModel
        
        // Initialize selectedInvoiceId from selectedInvoice's id property
        let initialInvoice: Invoice? = selectedInvoice.wrappedValue
        let initialId: UUID? = initialInvoice?.id
        self._selectedInvoiceId = State(initialValue: initialId)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Invoice list with real-time filtering
            invoiceList
        }
        .background(Color.clear)
        .onAppear {
            setupInitialState()
            updateTreeItems()
        }
        .onChange(of: searchText) { _, _ in updateTreeItems() }
        .onChange(of: filterStatus) { _, _ in updateTreeItems() }
        .onChange(of: sortField) { _, _ in updateTreeItems() }
        .onChange(of: sortDirection) { _, _ in updateTreeItems() }
        .onChange(of: groupBy) { _, _ in updateTreeItems() }
        .onChange(of: containerViewModel.allInvoices) { _, _ in updateTreeItems() }
        .onChange(of: selectedInvoiceId) { _, newIdUUID in syncSelectedInvoiceFromId(newIdUUID) }
        .onChange(of: selectedInvoice) { _, newInvoice in syncSelectedIdFromInvoice(newInvoice) }
        .onChange(of: filterStateHash) { _, _ in updateTreeItems() }
        .task {
            // Refresh invoices when view appears
            await containerViewModel.fetchAllInvoices()
        }
        .modifier(ConfirmationDialogModifier(
            showingDeleteConfirmation: $showingDeleteConfirmation,
            invoicesToDelete: invoicesToDelete,
            performDeleteInvoices: performDeleteInvoices
        ))
        .loadingOverlay(isLoading: containerViewModel.isLoading, message: "Loading invoices...")
    }
    
    // Combine all filter values into a single value for onChange
    private var filterStateHash: Int {
        var hasher = Hasher()
        hasher.combine(isDateFilterActive)
        hasher.combine(filterStartDate)
        hasher.combine(filterEndDate)
        hasher.combine(isAmountFilterActive)
        hasher.combine(filterMinAmount)
        hasher.combine(filterMaxAmount)
        hasher.combine(isClientFilterActive)
        hasher.combine(filterClients)
        return hasher.finalize()
    }
    
    // MARK: - Helper Methods
    
    private func setupInitialState() {
        // Sync ID selection if external selection exists and differs
        if let selectedInvoiceUUID = selectedInvoice?.id,
           selectedInvoiceId != selectedInvoiceUUID {
            selectedInvoiceId = selectedInvoiceUUID
        }
        
        // Initialize all groups as expanded by default
        expandedGroups = Set(groupedInvoices.keys)
    }
    
    private func syncSelectedInvoiceFromId(_ newIdUUID: UUID?) {
        if let selectedInvoiceUUID = selectedInvoice?.id,
           newIdUUID != selectedInvoiceUUID {
            if let id = newIdUUID {
                selectedInvoice = invoices.first { $0.id == id }
            } else {
                selectedInvoice = nil
            }
        } else if selectedInvoice?.id == nil && newIdUUID != nil {
            if let id = newIdUUID {
                selectedInvoice = invoices.first { $0.id == id }
            }
        } else if selectedInvoice?.id != nil && newIdUUID == nil {
            selectedInvoice = nil
        }
    }
    
    private func syncSelectedIdFromInvoice(_ newInvoice: Invoice?) {
        let newInvoiceUUID = newInvoice?.id
        if newInvoiceUUID != selectedInvoiceId {
            selectedInvoiceId = newInvoiceUUID
        }
    }
    
    private func handleEscapeKey() -> KeyPress.Result {
        if isMultiSelectMode {
            withAnimation(.easeInOut(duration: StyleGuide.Animations.durationMedium)) {
                isMultiSelectMode = false
                selectedInvoices.removeAll()
            }
            return .handled
        }
        return .ignored
    }
    

    
    // Ungrouped list view
    private var ungroupedInvoicesList: some View {
        LazyVStack(spacing: 8) {
            ForEach(Array(filteredInvoices), id: \.id) { invoice in
                InvoiceRowView(
                    invoice: invoice,
                    isSelected: selectedInvoices.contains(invoice),
                    isMultiSelectMode: isMultiSelectMode,
                    onSelect: {
                        if selectedInvoices.contains(invoice) {
                            selectedInvoices.remove(invoice)
                        } else {
                            selectedInvoices.insert(invoice)
                        }
                    },
                    onTap: {
                        if isMultiSelectMode {
                            if selectedInvoices.contains(invoice) {
                                selectedInvoices.remove(invoice)
                            } else {
                                selectedInvoices.insert(invoice)
                            }
                        } else {
                            handleInvoiceTap(invoice: invoice)
                        }
                    }
                )
            }
        }
    }
    
        // Grouped list view with dynamic sections
    private var groupedInvoicesList: some View {
        VStack(spacing: 16) {
            ForEach(groupedInvoices.keys.sorted(), id: \.self) { key in
                if let invoicesInGroup = groupedInvoices[key] {
                    invoiceGroupView(key: key, invoicesInGroup: invoicesInGroup)
                }
            }
        }
    }
    
    // MARK: - Invoice Group View
    private func invoiceGroupView(key: String, invoicesInGroup: [Invoice]) -> some View {
        GlassEffectContainer(spacing: 10.0) {
            VStack(spacing: 10.0) {
                groupHeaderView(key: key, invoicesInGroup: invoicesInGroup)
                
                if expandedGroups.contains(key) {
                    expandedInvoicesView(invoicesInGroup: invoicesInGroup)
                }
            }
        }
    }
    
    // MARK: - Group Header View
    private func groupHeaderView(key: String, invoicesInGroup: [Invoice]) -> some View {
        HStack(spacing: 12) {
            groupIconView(key: key)
            groupTitleView(key: key, count: invoicesInGroup.count)
            Spacer()
            chevronIconView(key: key)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.smooth) {
                if expandedGroups.contains(key) {
                    expandedGroups.remove(key)
                } else {
                    expandedGroups.insert(key)
                }
            }
        }
        .pointerStyle(.link)
        .padding(.horizontal, StyleGuide.Dimensions.paddingLarge)
        .padding(.vertical, StyleGuide.Dimensions.paddingMediumLarge)
        .frame(maxWidth: .infinity)
        .frame(height: 60.0)
        .glassEffect(.regular.interactive(true), in: .rect(cornerRadius: 12))
        .glassEffectID("invoice-group-\(key)", in: namespace)
    }
    
    // MARK: - Group Icon View
    private func groupIconView(key: String) -> some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            .white.opacity(StyleGuide.Opacity.strong),
                            .white.opacity(StyleGuide.Opacity.light)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 32, height: 32)
            
            Image(systemName: iconForGroup(key))
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color("Text", bundle: .sharedUI))
        }
    }
    
    // MARK: - Group Title View
    private func groupTitleView(key: String, count: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(key)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(Color("Text", bundle: .sharedUI))
            
            Text("\(count) \(count == 1 ? "invoice" : "invoices")")
                .font(.caption)
                .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
        }
    }
    
    // MARK: - Chevron Icon View
    private func chevronIconView(key: String) -> some View {
        Image(systemName: expandedGroups.contains(key) ? "chevron.up" : "chevron.down")
            .font(.caption)
            .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
    }
    
    // MARK: - Expanded Invoices View
    private func expandedInvoicesView(invoicesInGroup: [Invoice]) -> some View {
        ForEach(Array(invoicesInGroup.enumerated()), id: \.element.id) { index, invoice in
            invoiceRowView(invoice: invoice)
        }
    }
    
    // MARK: - Invoice Row View
    private func invoiceRowView(invoice: Invoice) -> some View {
        HStack(spacing: 12) {
            HStack {
                Text(invoice.invoiceNumber)
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(Color("Text", bundle: .sharedUI))

                Spacer()

                Text(AppConstants.invoiceStatusDisplayName(for: invoice.status))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(Color("Text", bundle: .sharedUI))
                    .padding(.horizontal, StyleGuide.Dimensions.paddingMedium)
                    .padding(.vertical, StyleGuide.Dimensions.paddingXSmall)
                    .background(Color("Gray40", bundle: .sharedUI))
                    .clipShape(RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusXSmall))
            }
        }
        .padding(.vertical, StyleGuide.Dimensions.paddingMediumLarge)
        .padding(.horizontal, StyleGuide.Dimensions.paddingLarge)
        .frame(maxWidth: .infinity)
        .frame(height: 60.0)
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
        .glassEffectID(invoice.id.uuidString, in: namespace)
        .padding(.leading, 12)
        .contentShape(Rectangle())
        .onTapGesture {
            if isMultiSelectMode {
                if selectedInvoices.contains(invoice) {
                    selectedInvoices.remove(invoice)
                } else {
                    selectedInvoices.insert(invoice)
                }
            } else {
                handleInvoiceTap(invoice: invoice)
            }
        }
    }
    

    
    // Computed property for grouped invoices
    private var groupedInvoices: [String: [Invoice]] {
        Dictionary(grouping: filteredInvoices) { invoice in
            switch groupBy {
            case .status:
                return AppConstants.invoiceStatusDisplayName(for: invoice.status)
            case .client:
                return invoice.clientName ?? "No Client"
            case .month:
                let date = invoice.date
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "MMMM yyyy"
                return dateFormatter.string(from: date)
            case .quarter:
                let date = invoice.date
                let calendar = Calendar.current
                let month = calendar.component(.month, from: date)
                let year = calendar.component(.year, from: date)
                let quarter = (month - 1) / 3 + 1
                return "Q\(quarter) \(year)"
            case .none:
                return "All Invoices"
            }
        }
    }
    


    // Helper function to determine icon for group
    private func iconForGroup(_ key: String) -> String {
        switch groupBy {
        case .status:
            switch key {
            case AppConstants.invoiceStatusDisplayName(for: AppConstants.invoiceStatusReviewDraft):
                return "doc.text"
            case AppConstants.invoiceStatusDisplayName(for: AppConstants.invoiceStatusReadyToSend):
                return "checkmark.circle"
            case AppConstants.invoiceStatusDisplayName(for: AppConstants.invoiceStatusPending):
                return "paperplane.fill"
            case AppConstants.invoiceStatusDisplayName(for: AppConstants.invoiceStatusReceived):
                return "checkmark.circle.fill"
            default: return "doc.text.fill"
            }
        case .client:
            return "person.2.fill"
        case .month, .quarter:
            return "calendar"
        case .none:
            return "doc.text.fill"
        }
    }
    
    // Update tree items for hierarchical list
    private func updateTreeItems() {
        var items: [TreeItem] = []
        
        if groupBy != .none {
            // Create grouped structure
            let grouped = groupedInvoices
            let sortedGroups = grouped.sorted(by: { $0.key < $1.key })
            
            // If only one group with few items, flatten it
            if sortedGroups.count == 1, let (_, invoicesInGroup) = sortedGroups.first, invoicesInGroup.count <= 5 {
                // Show as flat list instead of single section
                items = invoicesInGroup.map { invoice in
                    TreeItem(
                        id: "invoice_\(invoice.id)",
                        title: invoice.invoiceNumber,
                        subtitle: invoice.clientName ?? "No Client",
                        children: nil,
                        entityId: invoice.id.uuidString,
                        entityType: "invoice"
                    )
                }
            } else {
                for (key, invoicesInGroup) in sortedGroups {
                    let children = invoicesInGroup.map { invoice in
                        TreeItem(
                            id: "invoice_\(invoice.id)",
                            title: invoice.invoiceNumber,
                            subtitle: invoice.clientName ?? "No Client",
                            children: nil,
                            entityId: invoice.id.uuidString,
                            entityType: "invoice"
                        )
                    }
                    
                    items.append(TreeItem(
                        id: "section_\(key)",
                        title: key,
                        subtitle: "\(invoicesInGroup.count) \(invoicesInGroup.count == 1 ? "invoice" : "invoices")",
                        children: children
                    ))
                }
            }
        } else {
            // No grouping - create flat list of invoice items
            items = filteredInvoices.map { invoice in
                TreeItem(
                    id: "invoice_\(invoice.id)",
                    title: invoice.invoiceNumber,
                    subtitle: invoice.clientName ?? "No Client",
                    children: nil,
                    entityId: invoice.id.uuidString,
                    entityType: "invoice"
                )
            }
        }
        
        treeItems = items
    }
    
    // Handle item tap from hierarchical list
    private func handleItemTap(_ item: TreeItem) {
        guard let entityId = item.entityId,
              let uuid = UUID(uuidString: entityId) else { return }
        
        // Find the invoice by ID
        if let invoice = filteredInvoices.first(where: { $0.id == uuid }) {
            handleInvoiceTap(invoice: invoice)
        }
    }
    
    // Update the deleteSelectedInvoices function to show confirmation dialog
    private func deleteSelectedInvoices() {
        guard !selectedInvoices.isEmpty else { return }
        invoicesToDelete = selectedInvoices
        showingDeleteConfirmation = true
    }

    // MARK: - Bulk Operations
    private func bulkExportSelectedInvoices() {
        Task {
            let invoicesArray = Array(selectedInvoices)
            for inv in invoicesArray {
                if let url = await temporaryPDFURL(for: inv) {
                    // Already written by temporaryPDFURL
                    _ = url
                }
            }
            // Optionally, reveal temp directory
            await MainActor.run {
                NSWorkspace.shared.open(FileManager.default.temporaryDirectory)
            }
        }
    }

    private func bulkEmailSelectedInvoices() {
        Task {
            let invoicesArray = Array(selectedInvoices)
            guard !invoicesArray.isEmpty else { return }

            var items: [Any] = ["Please find attached the selected invoices." as NSString]
            for inv in invoicesArray {
                if let url = await temporaryPDFURL(for: inv) {
                    items.append(url as NSURL)
                }
            }

            // If nothing could be generated, bail
            guard items.count > 1 else { return }

            await MainActor.run {
                if let service = NSSharingService(named: .composeEmail) {
                    service.subject = "Invoices"
                    service.perform(withItems: items)
                }
            }
        }
    }

    // Generate PDF data for a given invoice using template-based rendering
    private func temporaryPDFURL(for invoice: Invoice) async -> URL? {
        // Fetch invoice items for PDF generation
        do {
            let invoiceItems = try await containerViewModel.invoicesRepository.fetchItems(by: invoice.id)
            return await containerViewModel.sharingService.temporaryPDFURL(
                invoice: invoice,
                invoiceItems: invoiceItems
            )
        } catch {
            print("❌ [InvoicesView] Error fetching invoice items for PDF: \(error)")
            return nil
        }
    }
    
    // Add handler functions for tap gestures
    private func handleInvoiceTap(invoice: Invoice) {
        if isMultiSelectMode {
            // In multi-select mode, toggle selection
            if selectedInvoices.contains(invoice) {
                selectedInvoices.remove(invoice)
            } else {
                selectedInvoices.insert(invoice)
            }
            
            // Exit multi-select mode if no items are selected
            if selectedInvoices.isEmpty {
                withAnimation(.easeInOut(duration: StyleGuide.Animations.durationMedium)) {
                    isMultiSelectMode = false
                }
            }
        } else {
            // Normal mode, select the invoice
            withAnimation(.easeOut(duration: 0.2)) {
                selectedInvoiceId = invoice.id
            }
        }
    }

    private func handleCommandTap(invoice: Invoice) {
        // Command+click always activates multi-select mode
        withAnimation(.easeInOut(duration: StyleGuide.Animations.durationMedium)) {
            if !isMultiSelectMode {
                isMultiSelectMode = true
                // Add the currently selected invoice to multi-selection if there is one
                if let currentlySelected = invoices.first(where: { $0.id == selectedInvoiceId }) {
                    selectedInvoices.insert(currentlySelected)
                }
            }
            
            // Toggle the clicked invoice
            if selectedInvoices.contains(invoice) {
                selectedInvoices.remove(invoice)
            } else {
                selectedInvoices.insert(invoice)
            }
        }
    }
    
    // Add a function to perform the actual deletion after confirmation
    private func performDeleteInvoices() {
        let invoiceIds = invoicesToDelete.map { $0.id }
        Task {
            await containerViewModel.deleteInvoices(invoiceIds)
            selectedInvoices.removeAll()
            isMultiSelectMode = false
            // Success toast
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
            invoicesToDelete.removeAll()
        }
    }

    // MARK: - Invoice List
    private var invoiceList: some View {
        VStack(spacing: 0) {
            if invoices.isEmpty {
                EmptyStateView(
                    icon: "doc.text.magnifyingglass",
                    title: "No Invoices Found",
                    message: "No invoices match the current filters."
                )
                .frame(maxHeight: .infinity)
                .standardContentPanelListInsets()
                .fluidTransition()
            } else {
                // Use hierarchical list
                FoldPaperContainer(
                    items: $treeItems,
                    onItemTap: handleItemTap
                )
            }
            
            // Add multi-select toolbar
            if isMultiSelectMode {
                let actionButtonShape = RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusSmall, style: .continuous)
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(selectedInvoices.count) selected")
                            .foregroundColor(Color("White", bundle: .sharedUI))
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("Press Esc or click Cancel to exit")
                            .foregroundColor(Color("White", bundle: .sharedUI).opacity(0.8))
                            .font(.caption)
                    }
                    .padding(.leading)
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation(.easeInOut(duration: StyleGuide.Animations.durationMedium)) {
                            isMultiSelectMode = false
                            selectedInvoices.removeAll()
                        }
                    }) {
                        Text("Cancel")
                            .foregroundColor(Color("White", bundle: .sharedUI))
                            .padding(.horizontal, StyleGuide.Dimensions.paddingMediumLarge)
                            .padding(.vertical, StyleGuide.Dimensions.paddingSmall)
                            .background(Color("Gray20", bundle: .sharedUI))
                            .cornerRadius(StyleGuide.Dimensions.cornerRadiusSmall)
                            .contentShape(actionButtonShape)
                    }
                    .buttonStyle(.plain)
                    .pointerStyle(.link)
                    .padding(.trailing, 8)
                    
                    Button(action: deleteSelectedInvoices) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete")
                        }
                        .foregroundColor(Color("White", bundle: .sharedUI))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color("Red70", bundle: .sharedUI))
                        .cornerRadius(StyleGuide.Dimensions.cornerRadiusSmall)
                        .contentShape(actionButtonShape)
                    }
                    .buttonStyle(.plain)
                    .pointerStyle(.link)
                    .disabled(selectedInvoices.isEmpty)
                    .padding(.trailing)

                    Button(action: bulkExportSelectedInvoices) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Export PDFs")
                        }
                        .foregroundColor(Color("White", bundle: .sharedUI))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color("Blue70", bundle: .sharedUI))
                        .cornerRadius(StyleGuide.Dimensions.cornerRadiusSmall)
                        .contentShape(actionButtonShape)
                    }
                    .buttonStyle(.plain)
                    .pointerStyle(.link)
                    .disabled(selectedInvoices.isEmpty)
                    .padding(.trailing, 8)

                    Button(action: bulkEmailSelectedInvoices) {
                        HStack {
                            Image(systemName: "envelope.fill")
                            Text("Email Selected")
                        }
                        .foregroundColor(Color("White", bundle: .sharedUI))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color("Blue70", bundle: .sharedUI))
                        .cornerRadius(StyleGuide.Dimensions.cornerRadiusSmall)
                        .contentShape(actionButtonShape)
                    }
                    .buttonStyle(.plain)
                    .pointerStyle(.link)
                    .disabled(selectedInvoices.isEmpty)
                }
                .padding(.vertical, 8)
                .glassEffect(.regular.interactive(true), in: .rect(cornerRadius: 12))
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .background(.clear)
        .animation(.easeInOut(duration: StyleGuide.Animations.durationMedium), value: groupBy)
        .animation(.easeInOut(duration: StyleGuide.Animations.durationMedium), value: isMultiSelectMode)
    }
}


// MARK: - Custom View Modifiers

struct ConfirmationDialogModifier: ViewModifier {
    @Binding var showingDeleteConfirmation: Bool
    let invoicesToDelete: Set<Invoice>
    let performDeleteInvoices: () -> Void
    
    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                "Delete Invoices",
                isPresented: $showingDeleteConfirmation,
                actions: {
                    Button("Delete", role: .destructive) {
                        performDeleteInvoices()
                    }
                    Button("Cancel", role: .cancel) {}
                },
                message: {
                    Text("Are you sure you want to delete \(invoicesToDelete.count) invoice(s)? This action cannot be undone.")
                }
            )
    }
}

// Note: A4InvoiceSheetView functionality is provided by SharedUI.A4InvoiceSheetView
// which is used for PDF rendering and printing via InvoiceSharingService

// MARK: - Form Field Style Modifier
struct FormFieldStyleModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    @State private var isHovering: Bool = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusSmall)
                    .fill(Color("A4White", bundle: .sharedUI).opacity(StyleGuide.Opacity.medium)) // Subtle background
            )
            .overlay(
                RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusSmall)
                    .stroke(isHovering ? Color("A4Text", bundle: .sharedUI).opacity(StyleGuide.Opacity.medium) : Color("A4Text", bundle: .sharedUI).opacity(StyleGuide.Opacity.strong), lineWidth: 1) // Border changes on hover
            )
            .onHover { hovering in
                withAnimation(.easeInOut(duration: StyleGuide.Animations.durationShort)) {
                    isHovering = hovering
                }
            }
    }
}

extension View {
    func formFieldStyle() -> some View {
        self.modifier(FormFieldStyleModifier())
    }
}

// MARK: - New Picker Component: PickerDisplayButton
struct PickerDisplayButton<Item: Hashable, LabelContent: View>: View {
    let items: [Item] 
    @Binding var selection: Item?
    let placeholder: String
    @ViewBuilder let selectedLabelContent: (Item) -> LabelContent
    let action: () -> Void
    let buttonWidth: CGFloat?

    // ADDED color constant
    private let mediumGrayText = Color("A4Text", bundle: .sharedUI)
    private var fieldShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusSmall, style: .continuous)
    }

    var body: some View {
        Button(action: action) {
            HStack {
                if let currentSelection = selection, items.contains(currentSelection) {
                    selectedLabelContent(currentSelection)
                } else {
                    Text(placeholder).foregroundColor(Color("A4Text", bundle: .sharedUI))
                }
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(Color("A4Text", bundle: .sharedUI))
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .font(.system(size: 10)) // <<<< REDUCED font size for picker button content
            .formFieldStyle()
            .contentShape(fieldShape)
        }
        .buttonStyle(.plain)
        .pointerStyle(.link)
        .frame(width: buttonWidth) // <<<< ADDED: Apply frame width if provided
    }
}

// MARK: - New Picker Component: PickerOptionsList
struct PickerOptionsList<Item: Hashable, ItemLabel: View>: View {
    let items: [Item]
    @Binding var selection: Item?
    @ViewBuilder let itemLabel: (Item) -> ItemLabel
    let onSelect: (Item) -> Void
    let popoverWidth: CGFloat? 

    @Environment(\.colorScheme) var colorScheme
    @State private var hoveredItem: Item? = nil

    private struct PickerOptionRowContent: View {
        let item: Item
        let isSelected: Bool
        let isHovered: Bool
        @ViewBuilder let itemLabel: (Item) -> ItemLabel
        let selectedTextColor: Color
        let defaultTextColor: Color 
        let hoverBackgroundColor: Color
        let selectedBackgroundColor: Color

        private let darkText = Color("A4Text", bundle: .sharedUI)

        var body: some View {
            HStack {
                itemLabel(item)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(selectedTextColor)
                }
            }
            .font(.system(size: 10)) // <<<< REDUCED Font size for picker options
            .padding(.horizontal, 6) // REDUCED padding
            .padding(.vertical, 4) // REDUCED padding
            .contentShape(Rectangle())
            .background(
                Group {
                    if isSelected {
                        selectedBackgroundColor.opacity(isHovered ? 0.9 : 1.0)
                    } else if isHovered {
                        hoverBackgroundColor
                    } else {
                        Color.clear
                    }
                }
            )
            .foregroundColor(isSelected ? selectedTextColor : defaultTextColor) // Use defaultTextColor for non-selected, which will be .black
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(items, id: \.self) { item in
                    Button(action: { onSelect(item) }) {
                        PickerOptionRowContent(
                            item: item,
                            isSelected: self.selection == item,
                            isHovered: self.hoveredItem == item,
                            itemLabel: self.itemLabel,
                            selectedTextColor: Color("A4Text", bundle: .sharedUI),
                            defaultTextColor: Color("A4Text", bundle: .sharedUI),
                            hoverBackgroundColor: Color("A4Text", bundle: .sharedUI).opacity(0.25),
                            selectedBackgroundColor: Color("A4Text", bundle: .sharedUI)
                        )
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.05)) {
                            self.hoveredItem = hovering ? item : nil
                        }
                    }
                    if items.last != item {
                        Divider()
                            .padding(.leading, 8)
                    }
                }
            }
        }
        // MODIFIED: Use the comprehensive frame modifier
        .frame(minWidth: popoverWidth, idealWidth: popoverWidth, maxWidth: popoverWidth, maxHeight: 250, alignment: .topLeading)
        .background(Color("A4White", bundle: .sharedUI))
        .cornerRadius(StyleGuide.Dimensions.cornerRadiusSmall)
        .shadow(radius: 5)
    }
}

// StringWidthCalculator removed - unused utility class



struct InvoiceEditor: View {
    @Environment(\.dismiss) private var dismiss
    
    // The ViewModel is now the source of truth for the view
    @StateObject var viewModel: InvoiceEditorViewModel
    @Binding var isEditing: Bool
    @Binding var showInspector: Bool
    
    // Template rendering dependencies
    @EnvironmentObject var templateDataService: TemplateDataService
    @EnvironmentObject var templateManager: TemplateManager

    // State for UI and gestures
    @State private var isPresentingPreviewSheet = false
    @State private var showingDeleteConfirmation = false
    @State private var showingCancelConfirmation = false

    
    private enum FitType {
        case width, height, page
    }

    // MARK: - Subviews (Editable Versions)

    var body: some View {
        VStack(spacing: 0) {
            if isEditing {
                // Use live preview when editing
                editableInvoiceContent
            } else {
                // Use template-based rendering for viewing
                InvoiceTemplateRendererView(
                    invoice: viewModel.invoice,
                    templateDataService: templateDataService
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .font(.system(size: 10))
        // toolbar consolidated in InvoicesContainerView
        .onChange(of: viewModel.status) { _, newStatus in
            // Sync paidDate with status changes
            if newStatus == AppConstants.invoiceStatusReceived {
                // Note: paidDate is updated when saving invoice
            }
        }
        .onChange(of: viewModel.discount) { _, _ in viewModel.recomputeTotals() }
        .onChange(of: viewModel.taxRate) { _, _ in viewModel.recomputeTotals() }
        .onChange(of: viewModel.creditApplied) { _, _ in viewModel.recomputeTotals() }
        .onChange(of: isEditing) { _, newValue in
            // Show inspector when entering editing mode, hide when exiting
            if newValue {
                showInspector = true
            } else {
                showInspector = false
            }
        }
        .confirmationDialog("Delete Invoice?", isPresented: $showingDeleteConfirmation) {
            Button("Delete Invoice", role: .destructive) {
                viewModel.deleteInvoiceAndDismiss()
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this invoice? This action cannot be undone.")
        }
        .confirmationDialog("Discard Changes?", isPresented: $showingCancelConfirmation) {
            Button("Discard Changes", role: .destructive) {
                viewModel.cancelEditing()
                isEditing = false
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("You have unsaved changes. Are you sure you want to discard them?")
        }
    }
    
    // MARK: - Editable Content (for editing mode)
    
    private var editableInvoiceContent: some View {
        // Live Preview (Main Content)
        VStack(spacing: 0) {
            Text("Live Preview")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
            
            InvoiceTemplateRendererView(
                invoice: viewModel.currentInvoiceSnapshot,
                invoiceItems: viewModel.invoiceItems,
                templateDataService: templateDataService
            )
            .id(viewModel.currentInvoiceSnapshot.id)
        }
    }
    
    private var invoiceEditingForm: some View {
        Form {
            Section("Invoice Details") {
                TextField("Invoice Number", text: $viewModel.invoiceNumber)
                DatePicker("Issue Date", selection: $viewModel.issueDate, displayedComponents: .date)
                DatePicker("Due Date", selection: Binding(get: { viewModel.dueDate ?? Date() }, set: { viewModel.dueDate = $0 }), displayedComponents: .date)
                
                Picker("Status", selection: $viewModel.status) {
                    ForEach(AppConstants.invoiceStatusOptions, id: \.self) { option in
                        Text(AppConstants.invoiceStatusDisplayName(for: option)).tag(option as String?)
                    }
                }
            }
            
            Section("Participant") {
                Picker("Client", selection: $viewModel.selectedClientId) {
                    Text("Select Client").tag(nil as UUID?)
                    ForEach(viewModel.allClients) { client in
                        Text(client.fullName).tag(client.id as UUID?)
                    }
                    // Fallback tag for currently selected client if not in allClients list
                    if let selectedId = viewModel.selectedClientId,
                       !viewModel.allClients.contains(where: { $0.id == selectedId }) {
                        Text(viewModel.selectedClient?.fullName ?? "Loading...").tag(selectedId as UUID?)
                    }
                }
                
                if let client = viewModel.selectedClient {
                    Text(client.email ?? "No Email")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Section("Line Items") {
                // Reuse the existing table logic but adapt for Form
                // Or just loop through items
                ForEach($viewModel.invoiceItems) { $item in
                    VStack(alignment: .leading) {
                        TextField("Description", text: $item.itemDescription)
                        HStack {
                            TextField("Qty", value: $item.quantity, formatter: NumberFormatter.decimal)
                                .frame(width: 60)
                            Text("@")
                            TextField("Rate", value: $item.rate, formatter: NumberFormatter.currency)
                                .frame(width: 80)
                            Spacer()
                            Text(item.lineTotal.formatted(.currency(code: "AUD")))
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onDelete { indexSet in
                    viewModel.deleteInvoiceItems(at: indexSet)
                }
                
                Button(action: viewModel.addNewInvoiceItem) {
                    Label("Add Item", systemImage: "plus")
                }
            }
            
            Section("Financials") {
                TextField("Discount %", value: $viewModel.discount, formatter: NumberFormatter.twoDecimal)
                TextField("Tax Rate %", value: $viewModel.taxRate, formatter: NumberFormatter.twoDecimal)
                TextField("Credit Applied", value: $viewModel.creditApplied, formatter: NumberFormatter.currency)
                
                LabeledContent("Subtotal", value: viewModel.subtotal, format: .currency(code: "AUD"))
                LabeledContent("Tax", value: viewModel.taxAmount, format: .currency(code: "AUD"))
                LabeledContent("Total", value: viewModel.calculatedTotal, format: .currency(code: "AUD"))
                    .fontWeight(.bold)
            }
            
            Section("Notes & Terms") {
                TextField("Payment Terms", text: Binding(get: { viewModel.paymentTerms ?? "" }, set: { viewModel.paymentTerms = $0 }), axis: .vertical)
                    .lineLimit(2...4)
                
                TextField("Notes", text: Binding(get: { viewModel.notes ?? "" }, set: { viewModel.notes = $0 }), axis: .vertical)
                    .lineLimit(2...4)
            }
        }
        .formStyle(.grouped)
    }

    // Helper formatter
    private var currencyFormatter: NumberFormatter {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "AUD"
        return f
    }

    }

// Add NumberFormatter extension for two decimal formatting
extension NumberFormatter {
    static var twoDecimal: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }

    static var decimal: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }
}

// MARK: - Enhanced Invoice Row View
struct InvoiceRowView: View {
    let invoice: Invoice
    let isSelected: Bool
    let isMultiSelectMode: Bool
    let onSelect: () -> Void
    let onTap: () -> Void
    
    @State private var isHovered = false
    
    private var backgroundColor: Color {
        if isSelected {
            return Color.accentColor.opacity(StyleGuide.Opacity.strong)
        } else if isHovered {
            return Color("White", bundle: .sharedUI).opacity(StyleGuide.Opacity.faint)
            } else {
            return Color("Black", bundle: .sharedUI).opacity(StyleGuide.Opacity.strong)
            }
        }
    
    private var strokeColor: Color {
        return isSelected ? Color.accentColor.opacity(StyleGuide.Opacity.light) : Color("White", bundle: .sharedUI).opacity(StyleGuide.Opacity.strong)
    }
    
    private var strokeWidth: CGFloat {
        return isSelected ? 2.0 : 1
    }
    
    private var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: NSNumber(value: invoice.totalAmount)) ?? "$0.00"
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: invoice.date)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            if isMultiSelectMode {
                Button(action: onSelect) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundColor(isSelected ? .accentColor : Color("Text", bundle: .sharedUI))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .pointerStyle(.link)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(invoice.invoiceNumber)
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(Color("Text", bundle: .sharedUI))
                    
                    Spacer()
                    
                    StatusBadge(status: AppConstants.invoiceStatusDisplayName(for: invoice.status))
                }
                

                
                HStack {
                    Text(formattedDate)
                        .font(.caption)
                        .foregroundColor(Color("Text", bundle: .sharedUI))
                    
                    Spacer()
                    
                    Text(formattedAmount)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(Color("Text", bundle: .sharedUI))
                    }
                }
        }
        .padding(.vertical, StyleGuide.Dimensions.paddingMediumLarge)
        .padding(.horizontal, StyleGuide.Dimensions.paddingLarge)
        .contentShape(RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusSmall, style: .continuous))
        .pointerStyle(.link)
        .glassEffect(.regular.interactive(true), in: .rect(cornerRadius: StyleGuide.Dimensions.cornerRadiusSmall))
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: StyleGuide.Animations.durationShort)) {
                isHovered = hovering
            }
        }
        .onTapGesture {
            onTap()
        }
        .animation(.easeInOut(duration: StyleGuide.Animations.durationShort), value: isSelected)
        .animation(.easeInOut(duration: StyleGuide.Animations.durationShort), value: isHovered)
    }
}

// MARK: - Adapted Line Items Table
struct AdaptedLineItemsTable: View {
    let invoice: Invoice
    var currentInvoiceItems: [InvoiceItem]
    let clientId: UUID?
    let clientServicesRepository: ClientServicesRepository
    let onDeleteItem: (IndexSet) -> Void
    let onUpdateItem: (InvoiceItem) -> Void
    let onItemDataChanged: () -> Void
    let isEditing: Bool
    
    @State private var availableClientServices: [ClientService] = []
    @State private var serviceDateMap: [UUID: Date] = [:] // Track service dates for each item
    
    init(invoice: Invoice, currentInvoiceItems: [InvoiceItem], clientId: UUID?, clientServicesRepository: ClientServicesRepository, onDeleteItem: @escaping (IndexSet) -> Void, onUpdateItem: @escaping (InvoiceItem) -> Void, onItemDataChanged: @escaping () -> Void, isEditing: Bool) {
        self.invoice = invoice
        self.currentInvoiceItems = currentInvoiceItems
        self.clientId = clientId
        self.clientServicesRepository = clientServicesRepository
        self.onDeleteItem = onDeleteItem
        self.onUpdateItem = onUpdateItem
        self.onItemDataChanged = onItemDataChanged
        self.isEditing = isEditing
        
        // Initialize service dates from current items
        // Note: InvoiceItem domain model doesn't include serviceDate, so we initialize with current date
        // In the future, serviceDate should be added to InvoiceItem domain model to preserve this data
        var dates: [UUID: Date] = [:]
        for item in currentInvoiceItems {
            dates[item.id] = Date() // Default to current date - serviceDate not available in domain model
        }
        self._serviceDateMap = State(initialValue: dates)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header row
            HStack(spacing: 0) {
                Text("SERVICE DATE")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(Color("A4Text", bundle: .sharedUI))
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(width: 80)
        .padding(EdgeInsets(top: 4, leading: 2, bottom: 4, trailing: 2))
                
                Divider().background(Color("A4White", bundle: .sharedUI))
                
                Text("DESCRIPTION")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(Color("A4Text", bundle: .sharedUI))
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(EdgeInsets(top: 4, leading: 2, bottom: 4, trailing: 2))
                
                Divider().background(Color("A4White", bundle: .sharedUI))
                
                Text("QTY")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(Color("A4Text", bundle: .sharedUI))
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(width: 40)
            .padding(EdgeInsets(top: 4, leading: 2, bottom: 4, trailing: 2))
                
                Divider().background(Color("A4White", bundle: .sharedUI))
                
                Text("RATE")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(Color("A4Text", bundle: .sharedUI))
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(width: 60)
                    .padding(EdgeInsets(top: 4, leading: 2, bottom: 4, trailing: 2))
                
                Divider().background(Color("A4White", bundle: .sharedUI))
                
                Text("AMOUNT")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(Color("A4Text", bundle: .sharedUI))
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(width: 60)
                    .padding(EdgeInsets(top: 4, leading: 2, bottom: 4, trailing: 2))
                
            if isEditing {
                    Divider().background(Color("A4White", bundle: .sharedUI))
                    
                    Text("")
                .frame(width: 20)
                .padding(EdgeInsets(top: 4, leading: 2, bottom: 4, trailing: 2))
                }
            }
            .background(Color("A4TableBorder", bundle: .sharedUI))
            
            // Data rows
            ForEach(currentInvoiceItems, id: \.id) { item in
                LineItemRowView(
                    item: item,
                    serviceDate: Binding(
                        get: { serviceDateMap[item.id] ?? Date() },
                        set: { serviceDateMap[item.id] = $0 }
                    ),
                    availableClientServices: availableClientServices,
                    onItemChanged: { updatedItem in
                        onUpdateItem(updatedItem)
                        onItemDataChanged()
                    },
                    onItemDataChanged: onItemDataChanged,
                    onDeleteItem: {
                        if let index = currentInvoiceItems.firstIndex(where: { $0.id == item.id }) {
                            onDeleteItem(IndexSet(integer: index))
                        }
                    },
                    isEditing: isEditing
                )
            }
            .task {
                // Fetch client services when clientId is available
                if let clientId = clientId {
                    do {
                        availableClientServices = try await clientServicesRepository.fetch(for: clientId)
                            .filter { $0.isActive }
                            .sorted { $0.serviceName < $1.serviceName }
                    } catch {
                        print("❌ [AdaptedLineItemsTable] Error fetching client services: \(error)")
                    }
                }
            }
            .onChange(of: clientId) { _, newClientId in
                Task {
                    if let clientId = newClientId {
                        do {
                            availableClientServices = try await clientServicesRepository.fetch(for: clientId)
                                .filter { $0.isActive }
                                .sorted { $0.serviceName < $1.serviceName }
                        } catch {
                            print("❌ [AdaptedLineItemsTable] Error fetching client services: \(error)")
                        }
                    } else {
                        availableClientServices = []
                    }
                }
            }
            
            // Empty state placeholder
            if currentInvoiceItems.isEmpty {
                HStack {
                    Spacer()
                    Text("No line items")
                        .foregroundColor(Color("A4Text", bundle: .sharedUI))
                        .padding()
                    Spacer()
                }
            .background(Color("A4White", bundle: .sharedUI))
                .overlay(Rectangle().frame(height: 1).foregroundColor(Color("A4Text", bundle: .sharedUI)), alignment: .bottom)
            }
            
            Spacer(minLength: 0)
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color("A4TableBorder", bundle: .sharedUI), lineWidth: 1))
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Line Item Row View
struct LineItemRowView: View {
    let item: InvoiceItem
    @Binding var serviceDate: Date
    let availableClientServices: [ClientService]
    let onItemChanged: (InvoiceItem) -> Void
    let onItemDataChanged: () -> Void
    let onDeleteItem: () -> Void
    let isEditing: Bool
    
    @State private var selectedClientServiceId: UUID?
    
    private var selectedClientService: ClientService? {
        guard let serviceId = selectedClientServiceId ?? item.clientServiceId else { return nil }
        return availableClientServices.first { $0.id == serviceId }
    }
    
    private var itemUnit: String {
        selectedClientService?.unit ?? ""
    }

    var body: some View {
        HStack(spacing: 0) {
            // Service Date Cell
            EditableServiceDateView(
                serviceDate: $serviceDate,
                isEditing: isEditing
            )
            .frame(width: 80)
            .padding(EdgeInsets(top: 4, leading: 2, bottom: 4, trailing: 2))

            Divider().background(Color("A4Text", bundle: .sharedUI))

            // Description Cell
            Group {
                if isEditing {
                    Picker("Service", selection: $selectedClientServiceId) {
                        Text("Select Service")
                            .tag(nil as UUID?)
                            .foregroundColor(Color("A4Text", bundle: .sharedUI))
                        ForEach(availableClientServices, id: \.id) { service in
                            Text(service.serviceName)
                                .tag(service.id as UUID?)
                                .foregroundColor(Color("A4Text", bundle: .sharedUI))
                        }
                    }
                    .colorScheme(.light)
                    .labelsHidden()
                    .pickerStyle(.automatic)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onChange(of: selectedClientServiceId) { _, selectedServiceId in
                        if let serviceId = selectedServiceId, let service = availableClientServices.first(where: { $0.id == serviceId }) {
                            onItemChanged(InvoiceItem(
                                id: item.id,
                                invoiceId: item.invoiceId,
                                sessionId: item.sessionId,
                                clientServiceId: serviceId,
                                itemDescription: service.serviceName,
                                quantity: item.quantity,
                                rate: service.rate,
                                position: item.position
                            ))
                            onItemDataChanged()
                        } else {
                            onItemChanged(InvoiceItem(
                                id: item.id,
                                invoiceId: item.invoiceId,
                                sessionId: item.sessionId,
                                clientServiceId: nil,
                                itemDescription: item.itemDescription,
                                quantity: item.quantity,
                                rate: item.rate,
                                position: item.position
                            ))
                            onItemDataChanged()
                        }
                    }
                    .onAppear {
                        selectedClientServiceId = item.clientServiceId
                    }
                } else {
                    let ndisCode = selectedClientService?.ndisCode
                    Text("\(item.itemDescription)\(ndisCode.map { " (\($0))" } ?? "")")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundColor(Color("A4Text", bundle: .sharedUI))
                }
            }
            .padding(EdgeInsets(top: 4, leading: 2, bottom: 4, trailing: 2))

            Divider().background(Color("A4Text", bundle: .sharedUI))

            // Quantity Cell
            Group {
                if isEditing {
                    TextField("Qty", text: Binding(
                        get: { String(describing: item.quantity) },
                        set: { newValue in
                            if let newQuantity = Double(newValue), newQuantity > 0 {
                                onItemChanged(InvoiceItem(
                                    id: item.id,
                                    invoiceId: item.invoiceId,
                                    sessionId: item.sessionId,
                                    clientServiceId: item.clientServiceId,
                                    itemDescription: item.itemDescription,
                                    quantity: newQuantity,
                                    rate: item.rate,
                                    position: item.position
                                ))
                                onItemDataChanged()
                            }
                        }
                    ))
                    .font(.system(size: 10))
                    .foregroundColor(Color("A4Text", bundle: .sharedUI))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .textFieldStyle(PlainTextFieldStyle())
                } else {
                    Text(String(describing: item.quantity))
                        .font(.system(size: 10))
                        .foregroundColor(Color("A4Text", bundle: .sharedUI))
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .frame(width: 40)
            .padding(EdgeInsets(top: 4, leading: 2, bottom: 4, trailing: 2))

            Divider().background(Color("A4Text", bundle: .sharedUI))

            // Rate Cell
            Group {
                if isEditing {
                    if itemUnit.lowercased() == "hour" {
                        Text(String(format: "$%.2f/h", item.rate))
                            .font(.system(size: 10))
                            .foregroundColor(Color("A4Text", bundle: .sharedUI))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .textFieldStyle(PlainTextFieldStyle())
                    } else if selectedClientService != nil {
                        Text(String(format: "$%.2f", item.rate))
                            .font(.system(size: 10))
                            .foregroundColor(Color("A4Text", bundle: .sharedUI))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .textFieldStyle(PlainTextFieldStyle())
                    } else {
                        TextField("Rate", text: Binding(
                            get: { String(format: "$%.2f", item.rate) },
                            set: { newValue in
                                let cleanRateString = newValue.replacingOccurrences(of: "$", with: "")
                                if selectedClientService == nil, let rateValue = Double(cleanRateString), rateValue >= 0 {
                                    onItemChanged(InvoiceItem(
                                        id: item.id,
                                        invoiceId: item.invoiceId,
                                        sessionId: item.sessionId,
                                        clientServiceId: item.clientServiceId,
                                        itemDescription: item.itemDescription,
                                        quantity: item.quantity,
                                        rate: rateValue,
                                        position: item.position
                                    ))
                                    onItemDataChanged()
                                }
                            }
                        ))
                        .disabled(selectedClientService != nil)
                        .font(.system(size: 10))
                        .foregroundColor(Color("A4Text", bundle: .sharedUI))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .textFieldStyle(PlainTextFieldStyle())
                    }
                } else {
                    if itemUnit.lowercased() == "hour" {
                        Text(String(format: "$%.2f/h", item.rate))
                            .font(.system(size: 10))
                            .foregroundColor(Color("A4Text", bundle: .sharedUI))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .textFieldStyle(PlainTextFieldStyle())
                    } else {
                        Text(String(format: "$%.2f", item.rate))
                            .font(.system(size: 10))
                            .foregroundColor(Color("A4Text", bundle: .sharedUI))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .textFieldStyle(PlainTextFieldStyle())
                    }
                }
            }
            .frame(width: 60)
            .padding(EdgeInsets(top: 4, leading: 2, bottom: 4, trailing: 2))

            Divider().background(Color("A4Text", bundle: .sharedUI))

            // Amount Cell
            Text(item.lineTotal.formatted(.currency(code: "AUD")))
                .font(.system(size: 10))
                .foregroundColor(Color("A4Text", bundle: .sharedUI))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .textFieldStyle(PlainTextFieldStyle())
                .frame(width: 60)
                .padding(EdgeInsets(top: 4, leading: 2, bottom: 4, trailing: 2))

            // Actions Cell (if editing)
            if isEditing {
                Divider().background(Color("A4Text", bundle: .sharedUI))
                Button(action: onDeleteItem) {
                    Image(systemName: "trash")
                        .foregroundColor(Color("A4Text", bundle: .sharedUI))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .pointerStyle(.link)
                .frame(width: 20)
                .padding(EdgeInsets(top: 4, leading: 2, bottom: 4, trailing: 2))
            }
        }
        .background(Color("A4White", bundle: .sharedUI))
        .overlay(Rectangle().frame(height: 1).foregroundColor(Color("A4Text", bundle: .sharedUI)), alignment: .bottom)
    }
}

// MARK: - Editable Service Date View
struct EditableServiceDateView: View {
    @Binding var serviceDate: Date
    var isEditing: Bool
    @State private var showPopover = false

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()
    
    var body: some View {
        if isEditing {
            Button(action: { showPopover = true }) {
                HStack(spacing: 4) {
                    Text(dateFormatter.string(from: serviceDate))
                        .font(.system(size: 10))
                        .foregroundColor(Color("A4Text", bundle: .sharedUI))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8))
                        .foregroundColor(Color("A4Text", bundle: .sharedUI))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showPopover, arrowEdge: .bottom) {
                DatePicker("Service Date", selection: $serviceDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                        .padding()
            }
        } else {
            Text(dateFormatter.string(from: serviceDate))
                .font(.system(size: 10))
                .foregroundColor(Color("A4Text", bundle: .sharedUI))
        }
    }
}

// MARK: - Simple Read-Only Line Items Table
// Used for displaying invoice items in a read-only format
struct SimpleLineItemsTable: View {
    let invoiceItems: [InvoiceItem]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header row
            HStack(spacing: 0) {
                Text("DESCRIPTION")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(Color("A4Text", bundle: .sharedUI))
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(EdgeInsets(top: 4, leading: 2, bottom: 4, trailing: 2))
                Divider().background(Color("A4White", bundle: .sharedUI))
                Text("QTY")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(Color("A4Text", bundle: .sharedUI))
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .frame(width: 40)
                    .padding(EdgeInsets(top: 4, leading: 2, bottom: 4, trailing: 2))
                Divider().background(Color("A4White", bundle: .sharedUI))
                Text("RATE")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(Color("A4Text", bundle: .sharedUI))
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .frame(width: 60)
                    .padding(EdgeInsets(top: 4, leading: 2, bottom: 4, trailing: 2))
                Divider().background(Color("A4White", bundle: .sharedUI))
                Text("AMOUNT")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(Color("A4Text", bundle: .sharedUI))
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .frame(width: 60)
                    .padding(EdgeInsets(top: 4, leading: 2, bottom: 4, trailing: 2))
            }
            .background(Color("A4TableBorder", bundle: .sharedUI))
            
            // Data rows
            ForEach(invoiceItems, id: \.id) { item in
                HStack(spacing: 0) {
                    Text(item.itemDescription)
                        .font(.system(size: 10))
                        .foregroundColor(Color("A4Text", bundle: .sharedUI))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(EdgeInsets(top: 4, leading: 2, bottom: 4, trailing: 2))
                    Divider().background(Color("A4Text", bundle: .sharedUI))
                    Text(String(describing: item.quantity))
                        .font(.system(size: 10))
                        .foregroundColor(Color("A4Text", bundle: .sharedUI))
                        .frame(width: 40, alignment: .center)
                        .padding(EdgeInsets(top: 4, leading: 2, bottom: 4, trailing: 2))
                    Divider().background(Color("A4Text", bundle: .sharedUI))
                    Text(String(format: "$%.2f", item.rate))
                        .font(.system(size: 10))
                        .foregroundColor(Color("A4Text", bundle: .sharedUI))
                        .frame(width: 60, alignment: .trailing)
                        .padding(EdgeInsets(top: 4, leading: 2, bottom: 4, trailing: 2))
                    Divider().background(Color("A4Text", bundle: .sharedUI))
                    Text(item.lineTotal.formatted(.currency(code: "AUD")))
                        .font(.system(size: 10))
                        .foregroundColor(Color("A4Text", bundle: .sharedUI))
                        .frame(width: 60, alignment: .trailing)
                        .padding(EdgeInsets(top: 4, leading: 2, bottom: 4, trailing: 2))
                }
                .background(Color("A4White", bundle: .sharedUI))
                .overlay(Rectangle().frame(height: 1).foregroundColor(Color("A4Text", bundle: .sharedUI)), alignment: .bottom)
            }
            
            if invoiceItems.isEmpty {
                HStack {
                    Spacer()
                    Text("No line items")
                        .foregroundColor(Color("A4Text", bundle: .sharedUI))
                        .padding()
                    Spacer()
                }
                .background(Color("A4White", bundle: .sharedUI))
                .overlay(Rectangle().frame(height: 1).foregroundColor(Color("A4Text", bundle: .sharedUI)), alignment: .bottom)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color("A4TableBorder", bundle: .sharedUI), lineWidth: 1))
    }
}

// MARK: - Info Section Component
struct InfoSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    let darkText = Color("A4Text", bundle: .sharedUI)
            let headerBackgroundColor = Color("A4TableBorder", bundle: .sharedUI)
        let contentBackgroundColor = Color("A4TableBackground", bundle: .sharedUI)
        let borderColor = Color("A4TableBorder", bundle: .sharedUI)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(darkText)
                .padding(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(headerBackgroundColor)

            VStack(alignment: .leading, spacing: 2) {
                content
            }
            .padding(.vertical, 4).padding(.horizontal, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(contentBackgroundColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(borderColor, lineWidth: 1))
    }
}


// MARK: - Date Filter Header Extension
