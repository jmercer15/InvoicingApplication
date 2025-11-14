import SwiftUI
import SwiftData
import AppKit
import SharedUI
import Data
import Core

public struct InvoicesContentColumn: View {
    @ObservedObject private var viewModel: InvoicesContainerViewModel
    @Environment(\.modelContext) private var viewContext

    public init(viewModel: InvoicesContainerViewModel) {
        self._viewModel = ObservedObject(wrappedValue: viewModel)
    }

    public var body: some View {
        invoiceList
            .onAppear(perform: syncContext)
            .onChange(of: viewContext) { _, _ in syncContext() }
            .toolbar(content: toolbarContent)
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
        .background(Color("Background", bundle: .sharedUI))
    }

    @ToolbarContentBuilder
    private func toolbarContent() -> some ToolbarContent {
        ToolbarItemGroup(placement: .automatic) {
            Button(action: viewModel.prepareNewInvoice) {
                Label("New Invoice", systemImage: "plus")
            }
            .help("Create a new invoice")
            .appInteractiveCursor()

            Menu {
                ForEach(GroupBy.allCases) { groupBy in
                    Button(action: { viewModel.groupBy = groupBy }) {
                        HStack {
                            Text(groupBy.rawValue)
                            if viewModel.groupBy == groupBy {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Label("Group By: \(viewModel.groupBy.rawValue)", systemImage: "folder")
            }
            .help("Change how invoices are grouped")
            .appInteractiveCursor()

            Menu {
                ForEach(SortField.allCases) { sortField in
                    Button(action: { viewModel.sortField = sortField }) {
                        HStack {
                            Text(sortField.rawValue)
                            if viewModel.sortField == sortField {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Label("Sort By: \(viewModel.sortField.rawValue)", systemImage: "arrow.up.arrow.down")
            }
            .help("Change sort field")
            .appInteractiveCursor()

            Button {
                viewModel.sortDirection = viewModel.sortDirection == .ascending ? .descending : .ascending
            } label: {
                Label("Sort Direction", systemImage: viewModel.sortDirection.displayName)
            }
            .help("Toggle sort direction (\(viewModel.sortDirection.rawValue))")
            .appInteractiveCursor()

            Menu {
                ForEach(AppConstants.invoiceStatusOptions, id: \.self) { status in
                    Button {
                        if viewModel.invoiceFilterStatus.contains(status) {
                            viewModel.invoiceFilterStatus.remove(status)
                        } else {
                            viewModel.invoiceFilterStatus.insert(status)
                        }
                    } label: {
                        HStack {
                            Text(status)
                            if viewModel.invoiceFilterStatus.contains(status) {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }

                Divider()

                Button("Select All") {
                    viewModel.invoiceFilterStatus = Set(AppConstants.invoiceStatusOptions)
                }

                Button("Clear All") {
                    viewModel.invoiceFilterStatus.removeAll()
                }
            } label: {
                Label(
                    "Filter Status (\(viewModel.invoiceFilterStatus.count)/\(AppConstants.invoiceStatusOptions.count))",
                    systemImage: "line.3.horizontal.decrease.circle"
                )
            }
            .help("Filter by invoice status")
            .appInteractiveCursor()
        }
    }

    private func syncContext() {
        // Note: updateContextIfNeeded removed - repositories handle persistence
        viewModel.initializeIfNeeded()
    }
}

public struct InvoicesDetailColumn: View {
    @ObservedObject private var viewModel: InvoicesContainerViewModel
    @Binding private var showInspector: Bool
    @Environment(\.modelContext) private var viewContext

    public init(viewModel: InvoicesContainerViewModel, showInspector: Binding<Bool>) {
        self._viewModel = ObservedObject(wrappedValue: viewModel)
        self._showInspector = showInspector
    }

    public var body: some View {
        detailContent
            .onAppear(perform: syncContext)
            .onChange(of: viewContext) { _, _ in syncContext() }
            .toolbar(content: detailToolbar)
            .preference(
                key: InspectorContentPreferenceKey.self,
                value: InspectorContent(id: "InvoicesInspector", view: AnyView(InvoiceInspectorViewProxy(containerViewModel: viewModel)))
            )
    }

    @ViewBuilder
    private var detailContent: some View {
        ZStack {
            if viewModel.isTransitioningToBlack {
                Color("Background", bundle: .sharedUI)
                    .id("invoice_detail_transition")
            } else if let editorViewModel = viewModel.invoiceEditorViewModel {
                InvoiceEditor(
                    viewModel: editorViewModel,
                    isEditing: $viewModel.isEditingInvoice,
                    showInspector: $showInspector
                )
                .id("invoice-editor-\(editorViewModel.invoice.id.uuidString)")
                .environment(\.modelContext, viewContext)
                .fluidDetailTransition()
                .background(Color("Background", bundle: .sharedUI).ignoresSafeArea())
            } else {
                EmptyStateView(
                    icon: "doc.text.fill",
                    title: "No Invoice Selected",
                    message: "Select an invoice from the list or create a new one."
                )
                .id("invoice_detail_placeholder")
                .background(Color("Background", bundle: .sharedUI).ignoresSafeArea())
            }
        }
        .preferredColorScheme(.light)
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
                .appInteractiveCursor()
            }
        }

        if let editorViewModel = viewModel.invoiceEditorViewModel, !viewModel.isEditingInvoice {
            ToolbarItemGroup(placement: .automatic) {
                Button(action: editorViewModel.printInvoice) {
                    Label("Print", systemImage: "printer")
                }
                .help("Print invoice")
                .appInteractiveCursor()

                Button(action: editorViewModel.exportInvoiceToPDF) {
                    Label("Export PDF", systemImage: "square.and.arrow.down.on.square")
                }
                .help("Export invoice to PDF")
                .appInteractiveCursor()

                Button {
                    if let provider = editorViewModel.itemProviderForPDFSharing() {
                        let items: [Any] = [editorViewModel.shareBodyText() as NSString, provider]
                        let picker = NSSharingServicePicker(items: items)
                        if let keyWindow = NSApp.keyWindow, let contentView = keyWindow.contentView {
                            picker.show(relativeTo: .zero, of: contentView, preferredEdge: .minY)
                        }
                    }
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .help("Share invoice")
                .appInteractiveCursor()
            }
        }
    }

    private func syncContext() {
        // Note: updateContextIfNeeded removed - repositories handle persistence
        viewModel.initializeIfNeeded()
    }
}

private struct InvoiceInspectorViewProxy: View {
    @ObservedObject var containerViewModel: InvoicesContainerViewModel

    var body: some View {
        if let editorViewModel = containerViewModel.invoiceEditorViewModel {
            InvoiceInspectorView(viewModel: editorViewModel, isEditing: $containerViewModel.isEditingInvoice)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text("No invoice selected")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text("Choose an invoice to populate the inspector.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}
