// /Users/user/Developer/InvoicingApplication/InvoicingApplication/InvoicingApplication/Views/Invoices/InvoicesContainerView.swift
import SwiftUI
import PDFKit
import SwiftData

struct InvoicesContainerView: View {
    @Environment(\.modelContext) private var viewContext
    @Binding var columnVisibility: NavigationSplitViewVisibility
    @Binding var showInspector: Bool
    
    @StateObject private var containerViewModel: InvoicesContainerViewModel
    @State private var isSidebarVisible: Bool = true
    
    // Global inspector content provider
    @StateObject private var inspectorContentProvider = GlobalInspectorContentProvider.shared

    init(columnVisibility: Binding<NavigationSplitViewVisibility>, showInspector: Binding<Bool>) {
        self._columnVisibility = columnVisibility
        self._showInspector = showInspector
        // Use a dummy context for initial StateObject creation; will be replaced in .onAppear
        let dummyContext: ModelContext
        if let container = try? ModelContainer(for: InvoiceEntity.self) {
            dummyContext = ModelContext(container)
        } else {
            fatalError("Failed to create dummy ModelContainer for InvoicesContainerViewModel initialization.")
        }
        self._containerViewModel = StateObject(wrappedValue: InvoicesContainerViewModel(context: dummyContext))
    }

    // MARK: - Computed View for Invoice List Panel
    private func invoiceListPanel(geometry: GeometryProxy) -> some View {
        Group {
                InvoicesView(
                searchText: $containerViewModel.invoiceSearchText,
                selectedInvoice: $containerViewModel.selectedInvoice,
                filterStatus: $containerViewModel.invoiceFilterStatus,
                containerViewModel: containerViewModel
                )
                .selectionColumnStyle() // Apply list styling
        }
                .frame(minWidth: 300)
                .background(Color.black)
    }

    // MARK: - Computed View for Invoice Detail Panel
    private func invoiceDetailPanel(geometry: GeometryProxy) -> some View {
                ZStack {
            if containerViewModel.isTransitioningToBlack {
                        Color.black
                            .transition(.opacity.animation(.easeInOut(duration: 0.1)))
                            .id("black_transition_layer")
            } else if let viewModel = containerViewModel.invoiceEditorViewModel { // Use the viewModel
                Group {
                    InvoiceEditor(viewModel: viewModel, isEditing: $containerViewModel.isEditingInvoice, showInspector: $showInspector) // Use the global inspector binding
                            .id("invoice-editor-\(viewModel.invoice.id.uuidString)")
                            .environment(\.modelContext, viewContext)
                            .transition(.asymmetric(
                                insertion: .opacity.animation(.easeInOut(duration: 0.2)),
                                removal: .opacity.combined(with: .scale(scale: 0.9)).animation(.easeInOut(duration: 0.15))
                            ))
                }
                    } else {
                        EmptyStateView(
                            icon: "doc.text.fill",
                            title: "No Invoice Selected",
                            message: "Select an invoice from the list or create a new one."
                        )
                        .id("empty_state_detail_view")
                    }
                }
        .preferredColorScheme(.light)
        

        .padding(.trailing, 16)
        .padding(.leading, 8)
        .frame(minWidth: geometry.size.width * 0.65, idealWidth: geometry.size.width * 0.75)
        .background(Color.black.ignoresSafeArea())
    }

    var body: some View {
        // Wrap HSplitView in GeometryReader to get available width
        GeometryReader { geometry in
            CustomHSplitView(
                fraction: 0.3,
                minPFraction: 0.2,
                minSFraction: 0.3,
                maxPFraction: 0.4,
                isPrimaryVisible: $isSidebarVisible,
                primary: {
                    invoiceListPanel(geometry: geometry)
                },
                secondary: {
                    invoiceDetailPanel(geometry: geometry)
                },
                splitter: { _ in
                    Splitter()
                }
            )
        }
        .onAppear {
            containerViewModel.updateContextIfNeeded(viewContext)
            containerViewModel.initializeIfNeeded()
            // Provide invoice inspector content to global inspector
            inspectorContentProvider.setInspectorContent(
                InvoiceInspectorContent(containerViewModel: containerViewModel),
                for: .invoices
            )
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: { withAnimation(.easeInOut(duration: 0.25)) { isSidebarVisible.toggle() } }) {
                    Image(systemName: isSidebarVisible ? "sidebar.left" : "sidebar.left")
                }
                .help("Toggle Sidebar")
                .appInteractiveCursor()
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showInspector.toggle()
                } label: {
                    Label("Inspector", systemImage: "sidebar.trailing")
                }
                .help("Show or hide inspector")
                .appInteractiveCursor()
            }
        }
        .preferredColorScheme(nil) // MODIFIED: Reset to system/inherited scheme for the container
        .sheet(isPresented: $containerViewModel.showingInvoiceGeneratorSheet) {
            InvoiceGeneratorView()
        }
        .onDisappear {
            // Clear inspector content when leaving invoices
            inspectorContentProvider.clearInspectorContent()
        }
    }




}

// MARK: - Invoice Inspector Content
struct InvoiceInspectorContent: View {
    @ObservedObject var containerViewModel: InvoicesContainerViewModel
    @State private var isEditing: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Invoice Inspector")
                .font(.headline)
                .foregroundColor(.primary)
            
            // Selected invoice info
            if let selectedInvoice = containerViewModel.selectedInvoice {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Selected Invoice")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(selectedInvoice.invoiceNumber.isEmpty ? "Draft" : selectedInvoice.invoiceNumber)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if let client = selectedInvoice.client {
                            Text("Client: \(client.fullName)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Text("Status: \(selectedInvoice.status ?? "Unknown")")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("Issue Date: \(selectedInvoice.issueDate, style: .date)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if let dueDate = selectedInvoice.dueDate {
                            Text("Due Date: \(dueDate, style: .date)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Text("Total: $\(selectedInvoice.totalAmount, specifier: "%.2f")")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                    .padding()
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(8)
                }
            } else {
                Text("No invoice selected")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // Quick actions
            VStack(alignment: .leading, spacing: 8) {
                Text("Quick Actions")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Button("New Invoice") {
                    containerViewModel.showingInvoiceGeneratorSheet = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                
                if containerViewModel.selectedInvoice != nil {
                    Button(isEditing ? "Done Editing" : "Edit Invoice") {
                        isEditing.toggle()
                        containerViewModel.isEditingInvoice = isEditing
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            
            Divider()
            
            // Invoice editor (if editing)
            if isEditing, let vm = containerViewModel.invoiceEditorViewModel {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Edit Invoice")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    InvoiceInspectorView(viewModel: vm, isEditing: $isEditing)
                        .frame(maxHeight: 300)
                }
            }
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    return formatter
}()

