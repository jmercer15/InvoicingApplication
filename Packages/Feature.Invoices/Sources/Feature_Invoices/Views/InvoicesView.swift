//
//  InvoicesView.swift
//  InvoicingApplication
//
//  Created by Jesse Mercer on 23/3/2025.
//

import SwiftUI
import SwiftData // Import SwiftData
import AppKit  // Add this import for NSScreen
import PDFKit
import Data
import Core
import SharedUI

struct InvoicesView: View {
    @Environment(\.modelContext) private var modelContext // Change to modelContext
    @Binding var searchText: String
    @Binding var selectedInvoice: InvoiceEntity?

    // Bindings for filter and sort state, controlled by the parent container
    @Binding var filterStatus: Set<String> // Changed to Set<String> for multi-selection
    
    // Container view model for toolbar actions
    @ObservedObject var containerViewModel: InvoicesContainerViewModel

    // State for the ID-based selection used by UnifiedListView
    @State private var selectedInvoiceId: UUID? = nil

    // Use @Binding for groupBy from container
    @Binding var groupBy: GroupBy
    @State private var isMultiSelectMode = false
    @State private var selectedInvoices: Set<InvoiceEntity> = []
    @Binding var sortField: SortField
    @Binding var sortDirection: SortDirection
    
    // Add state variables for confirmation dialog
    @State private var showingDeleteConfirmation = false
    @State private var invoicesToDelete: Set<InvoiceEntity> = []
    @State private var expandedGroups: Set<String> = []
    @Namespace private var namespace
    
    // Tree items for hierarchical list
    @State private var treeItems: [TreeItem] = []
    
    @Query(sort: \InvoiceEntity.date, order: .reverse) var invoices: [InvoiceEntity]
    // Computed property for filtered invoices
    private var filteredInvoices: [InvoiceEntity] {
        var filtered = invoices

        // Apply search filter across multiple fields
        if !searchText.isEmpty {
            let q = searchText.localizedLowercase
            filtered = filtered.filter { invoice in
                let haystack = [
                    invoice.invoiceNumber,
                    invoice.clientName ?? invoice.client?.fullName ?? "",
                    invoice.billToName ?? "",
                    invoice.billToEmail ?? "",
                    invoice.notes ?? ""
                ].joined(separator: " \u{2022} ").localizedLowercase
                return haystack.localizedStandardContains(q)
            }
        }

        // Apply status filter
        if !filterStatus.isEmpty {
            filtered = filtered.filter { filterStatus.contains($0.status?.rawValue ?? "") }
        }

        // Future enhancement: Add date range and amount range filters in toolbar controls

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
                return (first.clientName ?? first.client?.fullName ?? "") < (second.clientName ?? second.client?.fullName ?? "")
            case .invoiceNumber:
                return first.invoiceNumber < second.invoiceNumber
            case .numberAsc:
                return first.invoiceNumber < second.invoiceNumber
            case .numberDesc:
                return first.invoiceNumber > second.invoiceNumber
            case .statusAsc:
                return (first.status?.rawValue ?? "") < (second.status?.rawValue ?? "")
            case .statusDesc:
                return (first.status?.rawValue ?? "") > (second.status?.rawValue ?? "")
            }
        })
    }
    

    

    
    // Initializer with the properly configured fetch request
    init(searchText: Binding<String>, 
         selectedInvoice: Binding<InvoiceEntity?>,
         filterStatus: Binding<Set<String>>, // Re-added filterStatus
         groupBy: Binding<GroupBy>,
         sortField: Binding<SortField>,
         sortDirection: Binding<SortDirection>,
         containerViewModel: InvoicesContainerViewModel
    ) {
        self._searchText = searchText
        self._selectedInvoice = selectedInvoice
        self._filterStatus = filterStatus // Initialize the binding
        self._groupBy = groupBy
        self._sortField = sortField
        self._sortDirection = sortDirection
        self.containerViewModel = containerViewModel

        // Initialize FetchRequest with the initial predicate

        
        // Initialize selectedInvoiceId (UUID?) from selectedInvoice's id property (UUID?)
        let initialInvoice: InvoiceEntity? = selectedInvoice.wrappedValue
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
        .onChange(of: searchText) { _, _ in 
            updateFetchRequest()
            updateTreeItems()
        }
        .onChange(of: filterStatus) { _, _ in 
            updateFetchRequest()
            updateTreeItems()
        }
        .onChange(of: sortField) { _, _ in
            updateFetchRequest()
            updateTreeItems()
        }
        .onChange(of: sortDirection) { _, _ in
            updateFetchRequest()
            updateTreeItems()
        }
        .onChange(of: groupBy) { _, _ in
            updateTreeItems()
        }
        .onChange(of: invoices) { _, _ in
            updateTreeItems()
        }
        .onChange(of: selectedInvoiceId) { _, newIdUUID in
            syncSelectedInvoiceFromId(newIdUUID)
        }
        .onChange(of: selectedInvoice) { _, newInvoice in
            syncSelectedIdFromInvoice(newInvoice)
        }
        .modifier(ConfirmationDialogModifier(
            showingDeleteConfirmation: $showingDeleteConfirmation,
            invoicesToDelete: invoicesToDelete,
            performDeleteInvoices: performDeleteInvoices
        ))
    }
    
    // MARK: - Helper Methods
    
    private func setupInitialState() {
        updateFetchRequest()
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
    
    private func syncSelectedIdFromInvoice(_ newInvoice: InvoiceEntity?) {
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
    private func invoiceGroupView(key: String, invoicesInGroup: [InvoiceEntity]) -> some View {
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
    private func groupHeaderView(key: String, invoicesInGroup: [InvoiceEntity]) -> some View {
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
        .appInteractiveCursor()
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
    private func expandedInvoicesView(invoicesInGroup: [InvoiceEntity]) -> some View {
        ForEach(Array(invoicesInGroup.enumerated()), id: \.element.id) { index, invoice in
            invoiceRowView(invoice: invoice)
        }
    }
    
    // MARK: - Invoice Row View
    private func invoiceRowView(invoice: InvoiceEntity) -> some View {
        HStack(spacing: 12) {
            HStack {
                Text(invoice.invoiceNumber)
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(Color("Text", bundle: .sharedUI))

                Spacer()

                Text(invoice.status?.rawValue ?? "Draft")
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
    private var groupedInvoices: [String: [InvoiceEntity]] {
        Dictionary(grouping: filteredInvoices) { invoice in
            switch groupBy {
            case .status:
                return invoice.status?.rawValue ?? "Draft"
            case .client:
                return invoice.clientName ?? invoice.client?.fullName ?? "No Client"
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
            case "Draft": return "doc.text"
            case "Sent": return "paperplane.fill"
            case "Paid": return "checkmark.circle.fill"
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
    
    // Update the fetch request when filters change
    private func updateFetchRequest() {
        // No longer needed - @Query handles this automatically
        // The filteredInvoices computed property handles filtering and sorting
    }
    
    // Update tree items for hierarchical list
    private func updateTreeItems() {
        var items: [TreeItem] = []
        
        if groupBy != .none {
            // Create grouped structure
            let grouped = groupedInvoices
            for (key, invoicesInGroup) in grouped.sorted(by: { $0.key < $1.key }) {
                let children = invoicesInGroup.map { invoice in
                    TreeItem(
                        id: "invoice_\(invoice.id)",
                        title: invoice.invoiceNumber,
                        subtitle: invoice.clientName ?? invoice.client?.fullName ?? "No Client",
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
        } else {
            // Create ungrouped structure - single section with all invoices
            let children = filteredInvoices.map { invoice in
                TreeItem(
                    id: "invoice_\(invoice.id)",
                    title: invoice.invoiceNumber,
                    subtitle: invoice.clientName ?? invoice.client?.fullName ?? "No Client",
                    children: nil,
                    entityId: invoice.id.uuidString,
                    entityType: "invoice"
                )
            }
            
            items.append(TreeItem(
                id: "section_all",
                title: "All Invoices",
                subtitle: "\(filteredInvoices.count) \(filteredInvoices.count == 1 ? "invoice" : "invoices")",
                children: children
            ))
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
        let invoicesArray = Array(selectedInvoices)
        for inv in invoicesArray {
            if let url = temporaryPDFURL(for: inv) {
                // Already written by temporaryPDFURL
                _ = url
            }
        }
        // Optionally, reveal temp directory
        NSWorkspace.shared.open(FileManager.default.temporaryDirectory)
    }

    private func bulkEmailSelectedInvoices() {
        let invoicesArray = Array(selectedInvoices)
        guard !invoicesArray.isEmpty else { return }

        var items: [Any] = ["Please find attached the selected invoices." as NSString]
        for inv in invoicesArray {
            if let url = temporaryPDFURL(for: inv) {
                items.append(url as NSURL)
            }
        }

        // If nothing could be generated, bail
        guard items.count > 1 else { return }

        if let service = NSSharingService(named: .composeEmail) {
            service.subject = "Invoices"
            service.perform(withItems: items)
        }
    }

    // Generate PDF data for a given invoice using the same sheet view used elsewhere
    private func temporaryPDFURL(for invoice: InvoiceEntity) -> URL? {
        var business: BusinessEntity? = invoice.business
        if business == nil {
            let descriptor = FetchDescriptor<BusinessEntity>()
            business = (try? modelContext.fetch(descriptor))?.first
        }
        guard let biz = business else { return nil }
        return InvoiceSharingService.temporaryPDFURL(invoice: invoice, business: biz, context: modelContext)
    }
    
    // Add handler functions for tap gestures
    private func handleInvoiceTap(invoice: InvoiceEntity) {
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
    
    private func handleCommandTap(invoice: InvoiceEntity) {
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
        for invoice in invoicesToDelete {
            modelContext.delete(invoice)
        }
        do {
            try modelContext.save()
            if let selectedInvoice = selectedInvoice, invoicesToDelete.contains(selectedInvoice) {
                self.selectedInvoice = nil
            }
            selectedInvoices.removeAll()
            isMultiSelectMode = false
            // Success toast (simple)
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
        } catch {
            // Error toast (simple)
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
        }
        invoicesToDelete.removeAll()
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
                .fluidTransition()
            } else {
                // Use hierarchical list
                FoldPaperContainer(
                    items: $treeItems,
                    onItemTap: handleItemTap
                )
                .padding(.horizontal, StyleGuide.Dimensions.paddingLarge)
                .padding(.vertical, StyleGuide.Dimensions.paddingMedium)
            }
            
            // Add multi-select toolbar
            if isMultiSelectMode {
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
                    }
                    .buttonStyle(.plain)
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
                    }
                    .buttonStyle(.plain)
                    .appInteractiveCursor()
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
                    }
                    .buttonStyle(.plain)
                    .appInteractiveCursor()
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
                    }
                    .buttonStyle(.plain)
                    .appInteractiveCursor()
                    .disabled(selectedInvoices.isEmpty)
                }
                .padding(.vertical, 8)
                .glassEffect(.regular.interactive(true), in: .rect(cornerRadius: 12))
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .background(Color("Background", bundle: .sharedUI))
        .animation(.easeInOut(duration: StyleGuide.Animations.durationMedium), value: groupBy)
        .animation(.easeInOut(duration: StyleGuide.Animations.durationMedium), value: isMultiSelectMode)
    }
}


// MARK: - Custom View Modifiers

struct ConfirmationDialogModifier: ViewModifier {
    @Binding var showingDeleteConfirmation: Bool
    let invoicesToDelete: Set<InvoiceEntity>
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

// All of the InvoiceEditor and its direct helpers will be replaced.
// The helper views used by A4InvoiceSheetView and other parts of the app will be kept.

// MARK: - A4 Invoice Sheet View
struct A4InvoiceSheetView: View {
    @Bindable var invoice: InvoiceEntity
    var business: BusinessEntity? // Passed from InvoiceEditor or preview

    // Replicate AppStorage properties needed for the A4 sheet
    @AppStorage("companyName") private var companyName: String = "Your Business Name Pty Ltd"
    @AppStorage("companyABN") private var companyABN: String = "ABN: 12 345 678 901"
    @AppStorage("companyPhone") private var companyPhone: String = "0400 000 000"
    @AppStorage("companyEmail") private var companyEmail: String = "contact@yourbusiness.com.au"
    @AppStorage("companyAddress") private var companyAddress: String = ""
    @AppStorage("defaultPaymentTerms") private var defaultPaymentTerms: String = "Payment due within 14 days."

            let darkText = Color("A4Text", bundle: .sharedUI)
        let mediumGrayText = Color("A4Text", bundle: .sharedUI)
    let tableBorderColor = Color("A4TableBorder", bundle: .sharedUI)
    let headerBackgroundColor = Color("A4TableBorder", bundle: .sharedUI)
    let indigoButtonBackground = Color("A4IndigoButton", bundle: .sharedUI)
    let indigoButtonText = Color("A4Text", bundle: .sharedUI)
    let hoverIndigoButtonBackground = Color("A4IndigoButtonHover", bundle: .sharedUI)

    // MARK: - Section: Business Info Header
    private var businessInfoHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading) {
                Text("TAX INVOICE")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Color("A4Text", bundle: .sharedUI))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(companyName)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color("A4Text", bundle: .sharedUI))
                    .lineLimit(1)
                Text(business?.abn ?? "ABN: N/A")
                    .font(.system(size: 11))
                    .foregroundColor(Color("A4Text", bundle: .sharedUI))
                Text(companyEmail)
                    .font(.system(size: 11))
                    .foregroundColor(Color("A4Text", bundle: .sharedUI))
            }
        }
        .padding(EdgeInsets(top: 12, leading: 24, bottom: 10, trailing: 24))
        .fixedSize(horizontal: false, vertical: true)
        .background(Color("A4LightBlueBackground", bundle: .sharedUI))
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 8, topTrailingRadius: 8))
        .padding(.bottom, 8)
    }

    // Computed properties for summary
    private var subtotal: Double {
                        invoice.items.reduce(0) { $0 + ($1.rate * $1.quantity) }
    }
    private var discountAmount: Double {
        subtotal * (invoice.discount / 100.0)
    }
    private var taxAmount: Double {
        let taxableSubtotal = subtotal
        let taxableSubtotalAfterDiscount = taxableSubtotal * (1.0 - (invoice.discount / 100.0))
        return taxableSubtotalAfterDiscount * (invoice.taxRate / 100.0)
    }
    private var appliedCreditAmountFromEntity: Double {
        invoice.creditApplied
    }
    private var total: Double {
        subtotal - discountAmount + taxAmount - appliedCreditAmountFromEntity
    }

    // MARK: - Section: Invoice Reference & Dates
    private var invoiceReferenceAndDatesSection: some View {
        InfoSection(title: "Invoice Reference & Dates") {
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 4) {
                GridRow {
                    Text("Invoice No.:")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color("A4Text", bundle: .sharedUI))
                        .gridColumnAlignment(.trailing)
                    Text(invoice.invoiceNumber)
                        .font(.system(size: 11))
                        .foregroundColor(Color("A4Text", bundle: .sharedUI))
                        .gridColumnAlignment(.leading)
                }
                GridRow {
                    Text("Issue Date:")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color("A4Text", bundle: .sharedUI))
                        .gridColumnAlignment(.trailing)
                    Text(invoice.issueDate, style: .date)
                        .font(.system(size: 10))
                        .foregroundColor(Color("A4Text", bundle: .sharedUI))
                        .gridColumnAlignment(.leading)
                }
                GridRow {
                    Text("Due Date:")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color("A4Text", bundle: .sharedUI))
                        .gridColumnAlignment(.trailing)
                    Text(invoice.dueDate ?? Date(), style: .date)
                        .font(.system(size: 10))
                        .foregroundColor(Color("A4Text", bundle: .sharedUI))
                        .gridColumnAlignment(.leading)
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Section: Participant
    private var participantSection: some View {
        InfoSection(title: "Participant") {
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 4) {
                GridRow {
                    Text("Name:")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color("A4Text", bundle: .sharedUI))
                        .gridColumnAlignment(.trailing)
                                            Text(invoice.clientName ?? invoice.client?.fullName ?? "N/A")
                        .font(.system(size: 10))
                        .foregroundColor(Color("A4Text", bundle: .sharedUI))
                }
                if let ndisNumber = invoice.client?.ndisNumber, !ndisNumber.isEmpty {
                    GridRow {
                        Text("NDIS No.:")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Color("A4Text", bundle: .sharedUI))
                            .gridColumnAlignment(.trailing)
                        Text(ndisNumber)
                            .font(.system(size: 10))
                            .foregroundColor(Color("A4Text", bundle: .sharedUI))
                    }
                }
            }
        }
    }

    // MARK: - Section: Bill To
    private var billToSection: some View {
        let client = invoice.client
        let billingAuthString = client?.billingAuthority
        var billToTitle = "Bill To"
        var name: String? = ""
        var email: String? = ""
        var addressDisplayString: String? = nil
        
        if billingAuthString == .parentGuardian, let payee = client?.payee {
            billToTitle = "Bill To: Parent/Guardian"
            name = payee.fullName
            email = payee.email
            if let address = payee.address {
                addressDisplayString = address.fullFormattedAddress
            }
        } else if billingAuthString == .client, let participant = client {
            billToTitle = "Bill To: Participant"
            name = participant.fullName
            email = participant.email
            if let address = participant.address {
                addressDisplayString = address.fullFormattedAddress
            }
        } else {
            return AnyView(InfoSection(title: "Bill To") {
                Text("Participant/billing details not fully specified.")
                    .font(.system(size: 10))
                    .foregroundColor(Color("A4Text", bundle: .sharedUI))
            })
        }
        return AnyView(InfoSection(title: billToTitle) {
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 4) {
                GridRow { Text("Name:").gridColumnAlignment(.trailing).foregroundColor(Color("A4Text", bundle: .sharedUI)); Text(name ?? "N/A").foregroundColor(Color("A4Text", bundle: .sharedUI)) }
                GridRow { Text("Email:").gridColumnAlignment(.trailing).foregroundColor(Color("A4Text", bundle: .sharedUI)); Text(email ?? "N/A").multilineTextAlignment(.leading).lineLimit(nil).foregroundColor(Color("A4Text", bundle: .sharedUI)) }
                GridRow(alignment: .top) { Text("Address:").gridColumnAlignment(.trailing).foregroundColor(Color("A4Text", bundle: .sharedUI)); Text(addressDisplayString ?? "N/A").foregroundColor(Color("A4Text", bundle: .sharedUI)) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .font(.system(size: 10))
            .foregroundColor(Color("A4Text", bundle: .sharedUI))
        })
    }

    // MARK: - Section: Line Items
    private var lineItemsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Spacer()
            Text("Line Items")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color("A4Text", bundle: .sharedUI))
                .padding(.top, 4)
            AdaptedLineItemsTable(
                invoice: invoice,
                currentInvoiceItems: invoice.itemsArray,
                onDeleteItem: { _ in /* Read-only in A4InvoiceSheetView */ },
                onItemDataChanged: {},
                isEditing: false
            )
        }
    }

    // MARK: - Section: Invoice Summary
    private var invoiceSummarySection: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack { Text("Subtotal").foregroundColor(Color("A4Text", bundle: .sharedUI)); Spacer(); Text(subtotal.formatted(.currency(code: "AUD"))).foregroundColor(Color("A4Text", bundle: .sharedUI)) }
            if discountAmount > 0 {
                HStack {
                    Text("Discount (" + String(format: "%.2f", invoice.discount) + "%").foregroundColor(Color("A4Text", bundle: .sharedUI))
                    Spacer()
                    Text("-" + discountAmount.formatted(.currency(code: "AUD"))).foregroundColor(Color("A4Text", bundle: .sharedUI))
                }
            }
            HStack { Text("Tax (" + String(format: "%.2f", invoice.taxRate) + "%").foregroundColor(Color("A4Text", bundle: .sharedUI))
                Spacer()
                Text(taxAmount.formatted(.currency(code: "AUD"))).foregroundColor(Color("A4Text", bundle: .sharedUI))
            }
            if appliedCreditAmountFromEntity > 0 { HStack { Text("Credit Applied").foregroundColor(Color("A4Text", bundle: .sharedUI)); Spacer(); Text("-" + appliedCreditAmountFromEntity.formatted(.currency(code: "AUD"))).foregroundColor(Color("A4Text", bundle: .sharedUI)) } }
            Divider().padding(.vertical, 2)
            HStack { Text("TOTAL").fontWeight(.bold).foregroundColor(Color("A4Text", bundle: .sharedUI)); Spacer(); Text(total.formatted(.currency(code: "AUD"))).fontWeight(.bold).foregroundColor(Color("A4Text", bundle: .sharedUI)) }
        }
        .font(.system(size: 10))
        .foregroundColor(darkText)
        .padding(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
        .background(Color("A4TableBackground", bundle: .sharedUI))
        .cornerRadius(StyleGuide.Dimensions.cornerRadiusSmall)
        .overlay(RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusSmall).stroke(Color("A4TableBorder", bundle: .sharedUI), lineWidth: 1))
    }

    // MARK: - Section: Payment Details
    private var paymentDetailsSection: some View {
        InfoSection(title: "Payment Details") {
            if let biz = business {
                Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 4) {
                    GridRow { Text("Bank Name:").gridColumnAlignment(.trailing).foregroundColor(Color("A4Text", bundle: .sharedUI)); Text(biz.bankName ?? "N/A").foregroundColor(Color("A4Text", bundle: .sharedUI)) }
                    GridRow { Text("Account Name:").gridColumnAlignment(.trailing).foregroundColor(Color("A4Text", bundle: .sharedUI)); Text(biz.bankAccountName ?? "N/A").foregroundColor(Color("A4Text", bundle: .sharedUI)) }
                    GridRow { Text("BSB:").gridColumnAlignment(.trailing).foregroundColor(Color("A4Text", bundle: .sharedUI)); Text(biz.bankBSB ?? "N/A").foregroundColor(Color("A4Text", bundle: .sharedUI)) }
                    GridRow { Text("Account No.:").gridColumnAlignment(.trailing).foregroundColor(Color("A4Text", bundle: .sharedUI)); Text(biz.bankAccountNumber ?? "N/A").foregroundColor(Color("A4Text", bundle: .sharedUI)) }
                }
                .font(.system(size: 10))
                .foregroundColor(Color("A4Text", bundle: .sharedUI))
            } else {
                Text("Business payment details not available.").font(.system(size: 10)).foregroundColor(Color("A4Text", bundle: .sharedUI))
            }
        }
    }

    // MARK: - Section: Payment Terms
    private var paymentTermsSection: some View {
        InfoSection(title: "Payment Terms") {
            Text(invoice.paymentTerms ?? defaultPaymentTerms)
                 .font(.system(size: 10))
                 .foregroundColor(Color("A4Text", bundle: .sharedUI))
                 .frame(maxWidth: .infinity, alignment: .leading)
                 .padding(StyleGuide.Dimensions.paddingXSmall)
        }
    }



    var body: some View {
        VStack(spacing: 0) {
            businessInfoHeader
            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 12) {
                    invoiceReferenceAndDatesSection
                    VStack(alignment: .leading, spacing: 12) {
                        participantSection
                        billToSection
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.bottom, 12)

                Rectangle().fill(Color.clear)

                VStack(alignment: .trailing, spacing: 0) {
                    lineItemsSection
                    HStack(alignment: .top) {
                        Spacer()
                        invoiceSummarySection
                            .frame(width: 280)
                    }
                    .padding(.top, 10)
                }

                Rectangle().fill(Color.clear)

                Grid(horizontalSpacing: 12) {
                    GridRow(alignment: .top) {
                        paymentDetailsSection
                        paymentTermsSection
                    }
                }
                .padding(.top, 12)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .frame(maxHeight: .infinity)
        }
        .background(Color("A4White", bundle: .sharedUI))
    }
}

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
        }
        .buttonStyle(.plain)
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
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // The ViewModel is now the source of truth for the view
    @StateObject var viewModel: InvoiceEditorViewModel
    @Binding var isEditing: Bool
    @Binding var showInspector: Bool

    // State for UI and gestures
    @State private var isPresentingPreviewSheet = false
    @State private var committedScaleFactor: CGFloat = 1.0
    @GestureState private var gestureMagnification: CGFloat = 1.0
    @State private var previousSize: CGSize? = nil
    @State private var autoFitOnResize: Bool = false
    @State private var currentGeometry: ViewGeometry = ViewGeometry()
    
    // State for confirmation dialogs
    @State private var showingDeleteConfirmation = false
    @State private var showingCancelConfirmation = false
    
    // Fetch required entities using @Query
    @Query(sort: \ClientEntity.fullName) private var clients: [ClientEntity]
    @Query(sort: \BusinessEntity.name) private var businesses: [BusinessEntity]
    
    // Computed property for business
    private var business: BusinessEntity? { businesses.first }
    
    // Structure to store geometry information
    struct ViewGeometry {
        var size: CGSize = .zero
    }

    // Color constants
            let lightGrayBackground = Color("A4TableBackground", bundle: .sharedUI)
    let mediumGrayText = Color("A4Text", bundle: .sharedUI)
    let darkText = Color("A4Text", bundle: .sharedUI)
            let indigoButtonBackground = Color("A4IndigoButton", bundle: .sharedUI)
            let indigoButtonText = Color("A4Text", bundle: .sharedUI)

    // The view is initialized with its ViewModel
    public init(viewModel: InvoiceEditorViewModel, isEditing: Binding<Bool>, showInspector: Binding<Bool>) {
        self._viewModel = StateObject(wrappedValue: viewModel)
        self._isEditing = isEditing
        self._showInspector = showInspector
    }
    
    private enum FitType {
        case width, height, page
    }

    // MARK: - Subviews (Editable Versions)

    private var formHeaderBar: some View { EmptyView() }

    private var businessInfoHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading) {
                Text("TAX INVOICE")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(darkText)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(viewModel.invoice.businessName ?? business?.name ?? "Your Business Name")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(darkText)
                    .lineLimit(1)
                Text(viewModel.invoice.businessABN ?? business?.abn ?? "ABN: N/A")
                    .font(.system(size: 11))
                    .foregroundColor(mediumGrayText)
                Text(viewModel.invoice.businessEmail ?? business?.email ?? "contact@yourbusiness.com.au")
                    .font(.system(size: 11))
                    .foregroundColor(mediumGrayText)
            }
        }
        .padding(EdgeInsets(top: 12, leading: 24, bottom: 10, trailing: 24))
        .fixedSize(horizontal: false, vertical: true)
        .background(Color("A4LightBlueBackground", bundle: .sharedUI))
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 8, topTrailingRadius: 8))
        .padding(.bottom, 8)
    }

    private var invoiceReferenceAndDatesSection: some View {
        InfoSection(title: "Invoice Reference & Dates") {
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 4) {
                GridRow {
                    Text("Invoice No.:")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color("A4Text", bundle: .sharedUI))
                        .gridColumnAlignment(.trailing)
                    if isEditing {
                        TextField("Auto-generated when client selected", text: $viewModel.invoice.invoiceNumber)
                            .font(.system(size: 11))
                            .foregroundColor(darkText)
                            .textFieldStyle(PlainTextFieldStyle())
                            .gridColumnAlignment(.leading)
                    } else {
                        Text(viewModel.invoice.invoiceNumber)
                            .font(.system(size: 11))
                            .foregroundColor(darkText)
                            .gridColumnAlignment(.leading)
                    }
                }
                GridRow {
                    Text("Issue Date:")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color("A4Text", bundle: .sharedUI))
                        .gridColumnAlignment(.trailing)
                    if isEditing {
                        DatePicker("", selection: $viewModel.invoice.issueDate, displayedComponents: .date)
                            .labelsHidden()
                            .font(.system(size: 10))
                            .foregroundColor(darkText)
                            .colorScheme(.light)
                            .accentColor(darkText)
                            .gridColumnAlignment(.leading)
                    } else {
                        Text(viewModel.invoice.issueDate, style: .date)
                            .font(.system(size: 10))
                            .foregroundColor(darkText)
                            .gridColumnAlignment(.leading)
                    }
                }
                GridRow {
                    Text("Due Date:")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color("A4Text", bundle: .sharedUI))
                        .gridColumnAlignment(.trailing)
                    if isEditing {
                        DatePicker("", selection: Binding(get: { viewModel.invoice.dueDate ?? Date() }, set: { viewModel.invoice.dueDate = $0 }), displayedComponents: .date)
                            .labelsHidden()
                            .font(.system(size: 10))
                            .foregroundColor(darkText)
                            .colorScheme(.light)
                            .accentColor(darkText)
                            .gridColumnAlignment(.leading)
                    } else {
                        Text(viewModel.invoice.dueDate ?? Date(), style: .date)
                            .font(.system(size: 10))
                            .foregroundColor(darkText)
                            .gridColumnAlignment(.leading)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        }
    }

    private var participantSection: some View {
        InfoSection(title: "Participant") {
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 4) {
                GridRow {
                    Text("Name:")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color("A4Text", bundle: .sharedUI))
                        .gridColumnAlignment(.trailing)
                    if isEditing {
                        Picker("Client", selection: $viewModel.invoice.client) {
                            Text("Select Client").tag(nil as ClientEntity?)
                            ForEach(clients) { client in
                                Text(client.fullName).tag(client as ClientEntity?)
                            }
                        }
                        .colorScheme(.light)
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .onChange(of: viewModel.invoice.client) { _, newClient in
                            viewModel.onClientChanged(to: newClient)
                        }
                    } else {
                        Text(viewModel.invoice.clientName ?? viewModel.invoice.client?.fullName ?? "N/A")
                            .font(.system(size: 10))
                            .foregroundColor(Color("A4Text", bundle: .sharedUI))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                if let ndisNumber = viewModel.invoice.clientNDISNumber ?? viewModel.invoice.client?.ndisNumber, !ndisNumber.isEmpty {
                    GridRow {
                        Text("NDIS No.:")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Color("A4Text", bundle: .sharedUI))
                            .gridColumnAlignment(.trailing)
                        Text(ndisNumber)
                            .font(.system(size: 10))
                            .foregroundColor(Color("A4Text", bundle: .sharedUI))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var billToSection: some View {
        // Use snapshot data if available, otherwise fall back to relationships
        let billingAuthString = viewModel.invoice.billingAuthority ?? viewModel.invoice.client?.billingAuthority
        let billToName = viewModel.invoice.billToName
        let billToEmail = viewModel.invoice.billToEmail
        let billToAddress = viewModel.invoice.billToAddress
        
        var billToTitle = "Bill To"
        var name: String? = ""
        var email: String? = ""
        var addressDisplayString: String? = nil

        if billingAuthString == .parentGuardian {
            billToTitle = "Bill To: Parent/Guardian"
            name = billToName ?? viewModel.invoice.payeeName ?? viewModel.invoice.client?.payee?.fullName
            email = billToEmail ?? viewModel.invoice.payeeEmail ?? viewModel.invoice.client?.payee?.email
            addressDisplayString = billToAddress ?? viewModel.invoice.payeeAddress ?? viewModel.invoice.client?.payee?.address?.fullFormattedAddress
        } else if billingAuthString == .client {
            billToTitle = "Bill To: Participant"
            name = billToName ?? viewModel.invoice.clientName ?? viewModel.invoice.client?.fullName
            email = billToEmail ?? viewModel.invoice.clientEmail ?? viewModel.invoice.client?.email
            addressDisplayString = billToAddress ?? viewModel.invoice.clientAddress ?? viewModel.invoice.client?.address?.fullFormattedAddress
        } else {
            return AnyView(InfoSection(title: "Bill To") {
                Text("Select Participant to determine billing details.")
                    .font(.system(size: 10))
                    .foregroundColor(Color("A4Text", bundle: .sharedUI))
            })
        }

        return AnyView(InfoSection(title: billToTitle) {
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 4) {
                GridRow { Text("Name:").gridColumnAlignment(.trailing).foregroundColor(Color("A4Text", bundle: .sharedUI)); Text(name ?? "N/A").foregroundColor(Color("A4Text", bundle: .sharedUI)) }
                GridRow { Text("Email:").gridColumnAlignment(.trailing).foregroundColor(Color("A4Text", bundle: .sharedUI)); Text(email ?? "N/A").multilineTextAlignment(.leading).lineLimit(nil).foregroundColor(Color("A4Text", bundle: .sharedUI)) }
                GridRow(alignment: .top) { Text("Address:").gridColumnAlignment(.trailing).foregroundColor(Color("A4Text", bundle: .sharedUI)); Text(addressDisplayString ?? "N/A").foregroundColor(Color("A4Text", bundle: .sharedUI)) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .font(.system(size: 10))
            .foregroundColor(Color("A4Text", bundle: .sharedUI))
        })
    }

    private var lineItemsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Line Items")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color("A4Text", bundle: .sharedUI))
                .padding(.top, 4)
            AdaptedLineItemsTable(
                invoice: viewModel.invoice,
                currentInvoiceItems: viewModel.invoice.itemsArray,
                onDeleteItem: { offsets in
                    viewModel.deleteInvoiceItems(at: offsets)
                },
                onItemDataChanged: { },
                isEditing: isEditing
            )
            .id(viewModel.invoice.client?.id)
            
            if isEditing {
                HStack {
                    Spacer()
                    Button(action: viewModel.addNewInvoiceItem) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 10))
                            Text("Add New Line Item")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(Color("A4Text", bundle: .sharedUI))
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(indigoButtonBackground)
                        .foregroundColor(indigoButtonText)
                        .cornerRadius(StyleGuide.Dimensions.cornerRadiusSmall)
                    }
                    .buttonStyle(.plain)
                    .appInteractiveCursor()
                    Spacer()
                }
                .padding(.top, 8)
            }
        }
    }

    private var paymentTermsSection: some View {
        InfoSection(title: "Payment Terms") {
            if isEditing {
                TextField("Payment Terms", text: Binding(get: { viewModel.invoice.paymentTerms ?? "" }, set: { viewModel.invoice.paymentTerms = $0 }), axis: .vertical)
                    .font(.system(size: 10))
                    .foregroundColor(Color("A4Text", bundle: .sharedUI))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(StyleGuide.Dimensions.paddingXSmall)
            } else {
                Text(viewModel.invoice.paymentTerms ?? "")
                    .font(.system(size: 10))
                    .foregroundColor(Color("A4Text", bundle: .sharedUI))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(StyleGuide.Dimensions.paddingXSmall)
            }
        }
    }

    private var invoiceSummarySection: some View {
        VStack(alignment: .trailing, spacing: 5) {
             HStack { Text("Subtotal").foregroundColor(Color("A4Text", bundle: .sharedUI)); Spacer(); Text(viewModel.invoice.subtotal.formatted(.currency(code: "AUD"))).foregroundColor(Color("A4Text", bundle: .sharedUI)) }
            if viewModel.invoice.discountAmount > 0 {
                 HStack {
                     Text("Discount (\(viewModel.invoice.discount, specifier: "%.2f")%)").foregroundColor(Color("A4Text", bundle: .sharedUI))
                     Spacer()
                     Text("-\(viewModel.invoice.discountAmount.formatted(.currency(code: "AUD")))").foregroundColor(Color("A4Text", bundle: .sharedUI))
                }
            }
             HStack { Text("Tax (\(viewModel.invoice.taxRate, specifier: "%.2f")%)").foregroundColor(Color("A4Text", bundle: .sharedUI)); Spacer(); Text(viewModel.invoice.taxAmount.formatted(.currency(code: "AUD"))).foregroundColor(Color("A4Text", bundle: .sharedUI)) }
             if viewModel.invoice.creditApplied > 0 { HStack { Text("Credit Applied").foregroundColor(Color("A4Text", bundle: .sharedUI)); Spacer(); Text("-\(viewModel.invoice.creditApplied.formatted(.currency(code: "AUD")))").foregroundColor(Color("A4Text", bundle: .sharedUI)) } }
             Divider().padding(.vertical, 2)
             HStack { Text("TOTAL").fontWeight(.bold).foregroundColor(Color("A4Text", bundle: .sharedUI)); Spacer(); Text(viewModel.invoice.calculatedTotal.formatted(.currency(code: "AUD"))).fontWeight(.bold).foregroundColor(Color("A4Text", bundle: .sharedUI)) }
        }
        .font(.system(size: 10))
        .foregroundColor(darkText)
        .padding(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
        .background(Color("A4TableBackground", bundle: .sharedUI))
        .cornerRadius(StyleGuide.Dimensions.cornerRadiusSmall)
        .overlay(RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusSmall).stroke(Color("A4TableBorder", bundle: .sharedUI), lineWidth: 1))
    }

    private var paymentDetailsSection: some View {
        InfoSection(title: "Payment Details") {
            // Use snapshot data if available, otherwise fall back to business relationship
            let bankName = viewModel.invoice.bankName ?? business?.bankName
            let bankAccountName = viewModel.invoice.bankAccountName ?? business?.bankAccountName
            let bankBSB = viewModel.invoice.bankBSB ?? business?.bankBSB
            let bankAccountNumber = viewModel.invoice.bankAccountNumber ?? business?.bankAccountNumber
            
            if bankName != nil || bankAccountName != nil || bankBSB != nil || bankAccountNumber != nil {
                Grid(alignment: .bottomLeading, horizontalSpacing: 10, verticalSpacing: 4) {
                    GridRow { Text("Bank Name:").gridColumnAlignment(.trailing).foregroundColor(Color("A4Text", bundle: .sharedUI)); Text(bankName ?? "N/A").foregroundColor(Color("A4Text", bundle: .sharedUI)) }
                    GridRow { Text("Account Name:").gridColumnAlignment(.trailing).foregroundColor(Color("A4Text", bundle: .sharedUI)); Text(bankAccountName ?? "N/A").foregroundColor(Color("A4Text", bundle: .sharedUI)) }
                    GridRow { Text("BSB:").gridColumnAlignment(.trailing).foregroundColor(Color("A4Text", bundle: .sharedUI)); Text(bankBSB ?? "N/A").foregroundColor(Color("A4Text", bundle: .sharedUI)) }
                    GridRow { Text("Account No.:").gridColumnAlignment(.trailing).foregroundColor(Color("A4Text", bundle: .sharedUI)); Text(bankAccountNumber ?? "N/A").foregroundColor(Color("A4Text", bundle: .sharedUI)) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .font(.system(size: 10))
                .foregroundColor(Color("A4Text", bundle: .sharedUI))
            } else {
                Text("Business payment details not available.").font(.system(size: 10)).foregroundColor(Color("A4Text", bundle: .sharedUI))
            }
        }
    }
    
    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            formHeaderBar
                .padding(.top, 16)
                .padding(.bottom, 16)
            
            ZStack(alignment: .bottomTrailing) {
            GeometryReader { geometry in
                    ScrollView([.vertical, .horizontal]) {
                        let currentOverallScale = committedScaleFactor * gestureMagnification
                        
                        VStack(spacing: 0) {
                            businessInfoHeader

                            VStack(alignment: .leading, spacing: 12) {
                                HStack(alignment: .top, spacing: 12) {
                                    invoiceReferenceAndDatesSection
                                        .frame(maxWidth: .infinity)
                                    VStack(alignment: .leading, spacing: 12) {
                                        participantSection
                                        billToSection
                                    }
                                    .frame(maxWidth: .infinity)
                                }

                                VStack(alignment: .trailing, spacing: 0) {
                                    lineItemsSection
                                    HStack(alignment: .top) {
                                        Spacer()
                                        invoiceSummarySection
                                            .frame(width: 280) // A bit wider to accommodate text
                                    }
                                    .padding(.top, 10)
                                }
                                .frame(maxHeight: .infinity, alignment: .top) // Pushes summary down

                                Grid(alignment: .bottom, horizontalSpacing: 12) {
                                    GridRow(alignment: .top) {
                                        paymentDetailsSection
                                        paymentTermsSection
                                    }
                                }
                                .frame(maxHeight: .infinity, alignment: .bottom) // Pushes payment details down
                            }
                            .padding(.vertical, 24)
                        }
                        .background(Color("A4White", bundle: .sharedUI))
                        .frame(width: 595, height: 842)
                        .scaleEffect(currentOverallScale)
                        .gesture(
                            MagnificationGesture()
                                .updating($gestureMagnification) { currentState, gestureState, _ in
                                    gestureState = max(0.01, currentState)
                                }
                                .onEnded { value in
                                    self.committedScaleFactor *= value
                                    self.committedScaleFactor = max(0.2, min(self.committedScaleFactor, 3.0))
                                }
                        )
                        .frame(width: 595 * currentOverallScale, height: 842 * currentOverallScale)
                        .clipped()
                        .onAppear {
                            self.currentGeometry.size = geometry.size
                             DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                 autoFitToPage(geometrySize: geometry.size)
                                 previousSize = geometry.size
                             }
                        }
                        .onChange(of: geometry.size) { _, newSize in
                             self.currentGeometry.size = newSize
                             if autoFitOnResize {
                                 autoFitToPage(geometrySize: newSize)
                             }
                        }
                    }
                    .background(Color("A4Black", bundle: .sharedUI).opacity(StyleGuide.Opacity.medium))
                }
                
                zoomControls
            }
        }
        .font(.system(size: 10))
        // toolbar consolidated in InvoicesContainerView
        .onChange(of: viewModel.invoice.status) { _, newStatus in
            // Sync paidDate with status changes
            if (newStatus?.rawValue ?? "") == AppConstants.invoiceStatusPaid {
                viewModel.invoice.paidDate = Date()
            } else {
                viewModel.invoice.paidDate = nil
            }
        }
        .onChange(of: viewModel.invoice.discount) { _, _ in viewModel.recomputeTotals() }
        .onChange(of: viewModel.invoice.taxRate) { _, _ in viewModel.recomputeTotals() }
        .onChange(of: viewModel.invoice.creditApplied) { _, _ in viewModel.recomputeTotals() }
        .confirmationDialogs(
            showingDeleteConfirmation: $showingDeleteConfirmation,
            showingCancelConfirmation: $showingCancelConfirmation,
            onDelete: {
                viewModel.deleteInvoiceAndDismiss()
                dismiss()
            },
            onDiscard: {
                viewModel.cancelEditing()
                isEditing = false
                dismiss()
            }
        )
    }

    // MARK: - Zoom Controls & Helpers
    
    private var zoomControls: some View {
        HStack(spacing: 8) {
            Button(action: { autoFitToPage(geometrySize: currentGeometry.size, withAnimation: true) }) {
                                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(Color("A4Text", bundle: .sharedUI))
            }.help("Fit to Page")
                                
            Button(action: { fitTo(.width, withAnimation: true) }) {
                                    Image(systemName: "arrow.left.and.right.square")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(Color("A4Text", bundle: .sharedUI))
            }.help("Fit to Width")
                                
            Button(action: { fitTo(.height, withAnimation: true) }) {
                                    Image(systemName: "arrow.up.and.down.square")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(Color("A4Text", bundle: .sharedUI))
            }.help("Fit to Height")
                                
            Rectangle().fill(Color("A4White", bundle: .sharedUI).opacity(StyleGuide.Opacity.strong)).frame(width: 1, height: 16)
            
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(Color("A4Text", bundle: .sharedUI))
                                Text("\(Int((committedScaleFactor * gestureMagnification) * 100))%")
                                    .foregroundColor(Color("A4Text", bundle: .sharedUI))
            
            Button(action: { withAnimation(.spring()) { committedScaleFactor = 1.0 } }) {
                                    Image(systemName: "arrow.counterclockwise")
                                        .foregroundColor(Color("A4Text", bundle: .sharedUI))
            }.help("Reset Zoom")
                                
            Rectangle().fill(Color("A4White", bundle: .sharedUI).opacity(StyleGuide.Opacity.strong)).frame(width: 1, height: 16)

            Toggle(isOn: $autoFitOnResize) {
                Image(systemName: "arrow.up.left.and.down.right.and.arrow.up.right.and.down.left")
                    .foregroundColor(Color("A4Text", bundle: .sharedUI))
            }
            .toggleStyle(.button)
            .help(autoFitOnResize ? "Disable Auto-Fit on Resize" : "Enable Auto-Fit on Resize")
                                }
                                .buttonStyle(.plain)
        .padding(StyleGuide.Dimensions.paddingMedium)
        .background(.black.opacity(StyleGuide.Opacity.medium))
        .cornerRadius(StyleGuide.Dimensions.cornerRadiusSmall)
        .shadow(radius: 5)
        .padding()
    }

    private func autoFitToPage(geometrySize: CGSize, withAnimation: Bool = false) {
        let availableWidth = geometrySize.width - 40
        let availableHeight = geometrySize.height - 40
        let scale = min(availableWidth / 595.0, availableHeight / 842.0) * 0.95
        
        if withAnimation {
            SwiftUI.withAnimation(.spring()) {
                committedScaleFactor = max(0.2, min(3.0, scale))
            }
        } else {
            committedScaleFactor = max(0.2, min(3.0, scale))
        }
    }
    
    private func fitTo(_ type: FitType, withAnimation: Bool = false) {
        let availableWidth = currentGeometry.size.width - 40
        let availableHeight = currentGeometry.size.height - 40
        var scale: CGFloat = 1.0
        
        switch type {
        case .width:
            scale = availableWidth / 595.0
        case .height:
            scale = availableHeight / 842.0
        case .page:
            autoFitToPage(geometrySize: currentGeometry.size, withAnimation: withAnimation)
            return
        }
        
        if withAnimation {
            SwiftUI.withAnimation(.spring()) {
                committedScaleFactor = max(0.2, min(3.0, scale))
            }
        } else {
            committedScaleFactor = max(0.2, min(3.0, scale))
                            }
                        }
                    }

// Add this helper modifier at the end of the file for the confirmation dialogs
extension View {
    func confirmationDialogs(
        showingDeleteConfirmation: Binding<Bool>,
        showingCancelConfirmation: Binding<Bool>,
        onDelete: @escaping () -> Void,
        onDiscard: @escaping () -> Void
    ) -> some View {
        self
        .confirmationDialog(
            "Delete Invoice",
            isPresented: showingDeleteConfirmation,
            actions: {
                Button("Delete", role: .destructive, action: onDelete)
                Button("Cancel", role: .cancel) {}
            },
            message: {
                Text("Are you sure you want to delete this invoice? This action cannot be undone.")
            }
        )
        .confirmationDialog(
            "Discard Changes",
            isPresented: showingCancelConfirmation,
            actions: {
                Button("Discard", role: .destructive, action: onDiscard)
                Button("Keep Editing", role: .cancel) {}
            },
            message: {
                Text("You have unsaved changes. Are you sure you want to discard them?")
            }
        )
    }
}

// MARK: - Invoice Inspector View
struct InvoiceInspectorView: View {
    @ObservedObject var viewModel: InvoiceEditorViewModel
    @Binding var isEditing: Bool
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Financials
                VStack(alignment: .leading, spacing: 6) {
                    Text("Financials").font(.headline).foregroundColor(Color("A4Text", bundle: .sharedUI))
                    VStack(alignment: .leading, spacing: 8) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Discount %").font(.caption).foregroundColor(Color("A4Text", bundle: .sharedUI))
                            TextField("0", value: $viewModel.invoice.discount, formatter: NumberFormatter.twoDecimal)
                                .controlSize(.small)
                                .textFieldStyle(.roundedBorder)
                                .disabled(!isEditing)
                                .frame(width: 80)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("GST %").font(.caption).foregroundColor(Color("A4Text", bundle: .sharedUI))
                            TextField("0", value: $viewModel.invoice.taxRate, formatter: NumberFormatter.twoDecimal)
                                .controlSize(.small)
                                .textFieldStyle(.roundedBorder)
                                .disabled(!isEditing)
                                .frame(width: 80)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Credit Applied").font(.caption).foregroundColor(Color("A4Text", bundle: .sharedUI))
                            HStack(spacing: 6) {
                                TextField("0", value: $viewModel.invoice.creditApplied, formatter: NumberFormatter.twoDecimal)
                                    .controlSize(.small)
                                    .textFieldStyle(.roundedBorder)
                                    .disabled(!isEditing)
                                    .frame(width: 120)
                                Button("Max") { viewModel.applyMaxClientCredit() }
                                    .controlSize(.small)
                                    .disabled(!isEditing)
                                    .appInteractiveCursor()
                            }
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Status").font(.caption).foregroundColor(Color("A4Text", bundle: .sharedUI))
                            Picker("Status", selection: $viewModel.invoice.status) {
                                ForEach(AppConstants.invoiceStatusOptions, id: \.self) { Text($0).tag($0) }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .controlSize(.small)
                            .frame(width: 140)
                            .disabled(!isEditing)
                        }
                    }
                }
                .padding(StyleGuide.Dimensions.paddingMedium)
                .glassEffect(.regular, in: .rect(cornerRadius: StyleGuide.Dimensions.cornerRadiusMedium))

                // Summary & Dates removed per requirement
            }
            .padding(StyleGuide.Dimensions.paddingMedium)
        }
        .frame(minWidth: 220)
        
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
}

// MARK: - Enhanced Invoice Row View
struct InvoiceRowView: View {
    let invoice: InvoiceEntity
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
                }
                .buttonStyle(.plain)
                .appInteractiveCursor()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(invoice.invoiceNumber)
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(Color("Text", bundle: .sharedUI))
                    
                    Spacer()
                    
                    StatusBadge(status: invoice.status?.rawValue ?? AppConstants.invoiceStatusDraft)
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
        .appInteractiveCursor()
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
    @Bindable var invoice: InvoiceEntity
    var currentInvoiceItems: [InvoiceItemEntity]
    let onDeleteItem: (IndexSet) -> Void
    let onItemDataChanged: () -> Void
    let isEditing: Bool

    @Environment(\.modelContext) private var modelContext
    
    // Query for client services
    @Query private var allClientServices: [ClientServiceEntity]
    
    // Computed property for available client services, filtered by current invoice's client
    private var availableClientServices: [ClientServiceEntity] {
        guard let clientID = invoice.client?.id else { return [] }
        return allClientServices
            .filter { $0.client?.id == clientID && $0.isActive }
            .sorted { $0.serviceName < $1.serviceName }
}

    init(invoice: InvoiceEntity, currentInvoiceItems: [InvoiceItemEntity], onDeleteItem: @escaping (IndexSet) -> Void, onItemDataChanged: @escaping () -> Void, isEditing: Bool) {
        self.invoice = invoice
        self.currentInvoiceItems = currentInvoiceItems
        self.onDeleteItem = onDeleteItem
        self.onItemDataChanged = onItemDataChanged
        self.isEditing = isEditing
        
        // Initialize the query for client services
        _allClientServices = Query(sort: \ClientServiceEntity.serviceName)
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
                    availableClientServices: availableClientServices,
                    onItemDataChanged: onItemDataChanged,
                    onDeleteItem: { itemToDelete in
                        if let index = currentInvoiceItems.firstIndex(where: { $0.id == itemToDelete.id }) {
                            onDeleteItem(IndexSet(integer: index))
                        }
                    },
                    isEditing: isEditing
                )
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
    @Bindable var item: InvoiceItemEntity
    let availableClientServices: [ClientServiceEntity]
    let onItemDataChanged: () -> Void
    let onDeleteItem: (InvoiceItemEntity) -> Void
    let isEditing: Bool

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        HStack(spacing: 0) {
            // Service Date Cell
            EditableServiceDateView(
                serviceDate: $item.serviceDate,
                isEditing: isEditing
            )
            .frame(width: 80)
            .padding(EdgeInsets(top: 4, leading: 2, bottom: 4, trailing: 2))

            Divider().background(Color("A4Text", bundle: .sharedUI))

            // Description Cell
            Group {
                if isEditing {
                    Picker("Service", selection: $item.clientService) {
                        Text("Select Service")
                            .tag(nil as ClientServiceEntity?)
                            .foregroundColor(Color("A4Text", bundle: .sharedUI))
                        ForEach(availableClientServices, id: \.self) {
                            Text($0.serviceName)
                                .tag($0 as ClientServiceEntity?)
                                .foregroundColor(Color("A4Text", bundle: .sharedUI))
                        }
                    }
                    .colorScheme(.light)
                    .labelsHidden()
                    .pickerStyle(.automatic)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onChange(of: item.clientService) { _, selectedService in
                        if let service = selectedService {
                            item.itemDescription = service.computedServiceName
                            item.rate = service.computedRate
                            item.unit = service.computedUnit
                            onItemDataChanged()
                        } else {
                            item.itemDescription = ""
                            item.rate = 0.0
                            item.unit = nil
                            onItemDataChanged()
                        }
                    }
                } else {
                    Text("\(item.itemDescription)\(item.clientService?.ndisCode.map { " (\($0))" } ?? "")")
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
                                item.quantity = newQuantity
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
                    if item.clientService?.computedUnit.lowercased() == "hour" {
                        Text(String(format: "$%.2f/h", item.rate))
                            .font(.system(size: 10))
                            .foregroundColor(Color("A4Text", bundle: .sharedUI))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .textFieldStyle(PlainTextFieldStyle())
                    } else if item.clientService != nil {
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
                                if item.clientService == nil, let rateValue = Double(cleanRateString), rateValue >= 0 {
                                    item.rate = rateValue
                                    onItemDataChanged()
                                }
                            }
                        ))
                        .disabled(item.clientService != nil)
                        .font(.system(size: 10))
                        .foregroundColor(Color("A4Text", bundle: .sharedUI))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .textFieldStyle(PlainTextFieldStyle())
                    }
                } else {
                    if item.clientService?.computedUnit.lowercased() == "hour" {
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
            Text((Double(item.quantity) * item.rate).formatted(.currency(code: "AUD")))
                .font(.system(size: 10))
                .foregroundColor(Color("A4Text", bundle: .sharedUI))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .textFieldStyle(PlainTextFieldStyle())
                .frame(width: 60)
                .padding(EdgeInsets(top: 4, leading: 2, bottom: 4, trailing: 2))

            // Actions Cell (if editing)
            if isEditing {
                Divider().background(Color("A4Text", bundle: .sharedUI))
                                        Button(action: {
                                            onDeleteItem(item)
                                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(Color("A4Text", bundle: .sharedUI))
                        }
                        .buttonStyle(.plain)
                        .appInteractiveCursor()
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
