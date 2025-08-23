// /Users/user/Developer/InvoicingApplication/InvoicingApplication/InvoicingApplication/ContentView.swift

import SwiftUI
import MapKit
import SwiftData

// MARK: - Global Inspector Content Provider
class GlobalInspectorContentProvider: ObservableObject {
    static let shared = GlobalInspectorContentProvider()
    
    @Published var currentInspectorContent: AnyView?
    @Published var currentFeature: AppTab?
    
    private init() {}
    
    func setInspectorContent<Content: View>(_ content: Content, for feature: AppTab) {
        currentInspectorContent = AnyView(content)
        currentFeature = feature
    }
    
    func clearInspectorContent() {
        currentInspectorContent = nil
        currentFeature = nil
    }
}

// (Removed old row style modifier; native list style is sufficient in NavigationSplitView)


struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var hoveredTab: AppTab?
    // --- NavigationSplitView State ---
    @State private var columnVisibility = NavigationSplitViewVisibility.doubleColumn // Start with sidebar visible
    



    @State private var showingDeleteRelationshipAlert = false
    // Change relationshipToDeleteId to UUID?
    // Update all usages to use UUID
    @State private var relationshipToDeleteId: UUID? // State for the specific ID to delete
    
    // Track current active feature for conditional inspector
    @State private var currentActiveFeature: AppTab? = nil
    @State private var mainInspectorVisible: Bool = false
    
    // Global inspector content provider
    @StateObject private var inspectorContentProvider = GlobalInspectorContentProvider.shared

    // Sidebar row view for consistent styling
    struct SidebarItemRow: View {
        let icon: String
        let title: String
        var body: some View {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .frame(width: 18)
                Text(title)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 6)
            .contentShape(Rectangle())
        }
    }

    // Sidebar width target based on tab label sizing
    private var maxTabLabelWidth: CGFloat {
        let font = NSFont.systemFont(ofSize: 13, weight: .medium)
        let maxTextWidth = AppTab.allCases.map { ( $0.title as NSString ).size(withAttributes: [.font: font]).width }.max() ?? 0
        // icon + spacing + text + padding
        return 20 + 8 + maxTextWidth + 24 + 16
    }
    
    // Determine if the main inspector should be shown for the current feature
    private var shouldShowMainInspector: Bool {
        guard let currentFeature = currentActiveFeature else { return false }
        
        // Only show main inspector for Calendar and Invoices features
        let featuresWithInspector: [AppTab] = [.calendar, .invoices]
        
        return featuresWithInspector.contains(currentFeature) && mainInspectorVisible
    }

    var body: some View {
        // --- Use NavigationSplitView with sidebar and detail for two columns ---
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar Column (native NavigationLinks to destinations)
            List {
                Section(header: featuresHeader) {
                    featuresLinks()
                }
            }
            .navigationTitle("")
            .listStyle(.sidebar)
            .accentColor(.primary)
            .listRowInsets(EdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10))
            .listSectionSeparator(.hidden)
            // .hoverEffect is unavailable on macOS; removed to fix build error
            .animation(.easeInOut(duration: 0.2), value: hoveredTab)
            .listRowSeparator(.hidden)
            .scrollContentBackground(.hidden)
            .frame(minWidth: maxTabLabelWidth)

        } detail: {
            Text("Select an item.")
        }
        .navigationSplitViewStyle(.automatic)
        .inspector(isPresented: $mainInspectorVisible) {
            mainInspectorContent
        }
        // --- End of NavigationSplitView ---

        // Sheets and alerts remain attached to the top-level view
        .alert("Delete Relationship", isPresented: $showingDeleteRelationshipAlert) {
            deleteRelationshipAlertButtons()
        } message: {
            Text("Are you sure you want to delete this relationship? This action cannot be undone.")
        }
        .background(
            Color.black
                .ignoresSafeArea(edges: .top)
        )
        // Add a default frame if needed, otherwise rely on window size
        // .frame(minWidth: 800, minHeight: 600)
    }
    
    // Main inspector content
    @ViewBuilder
    private var mainInspectorContent: some View {
        if let content = inspectorContentProvider.currentInspectorContent {
            content
                .inspectorColumnWidth(min: 220, ideal: 280, max: 350)
        } else {
            // Default inspector content
            VStack(alignment: .leading, spacing: 16) {
                if let currentFeature = currentActiveFeature {
                    Text("Inspector")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Feature: \(currentFeature.title)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("No inspector content available for this feature.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Spacer()
                } else {
                    Text("No feature selected")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .inspectorColumnWidth(min: 220, ideal: 280, max: 350)
        }
    }



    // MARK: - Content Switching (Selects the container view to display)
    @ViewBuilder
    private func currentContentContainer(columnVisibility: Binding<NavigationSplitViewVisibility>) -> some View { EmptyView() }

    // MARK: - Alert Handling (Unchanged, remains in ContentView)
    @ViewBuilder
    private func deleteRelationshipAlertButtons() -> some View {
        Button("Cancel", role: .cancel) { relationshipToDeleteId = nil }
        .appInteractiveCursor()
        Button("Delete", role: .destructive) {
            deleteSelectedRelationship()
        }
        .appInteractiveCursor()
    }

    private func deleteSelectedRelationship() {
        guard let objectId = relationshipToDeleteId else { return }
        Task {
            // Try to find and delete a ClientEntity, PayeeEntity, or PlanManagerEntity by id
            let clientDescriptor = FetchDescriptor<ClientEntity>(predicate: #Predicate { $0.id == objectId })
            if let client = try? modelContext.fetch(clientDescriptor).first {
                modelContext.delete(client)
                print("Client relationship deleted successfully.")
            } else {
                let payeeDescriptor = FetchDescriptor<PayeeEntity>(predicate: #Predicate { $0.id == objectId })
                if let payee = try? modelContext.fetch(payeeDescriptor).first {
                    modelContext.delete(payee)
                    print("Payee relationship deleted successfully.")
                } else {
                    let planManagerDescriptor = FetchDescriptor<PlanManagerEntity>(predicate: #Predicate { $0.id == objectId })
                    if let planManager = try? modelContext.fetch(planManagerDescriptor).first {
                        modelContext.delete(planManager)
                        print("Plan Manager relationship deleted successfully.")
                    } else {
                        print("Error: Could not find object to delete.")
                    }
                }
            }
            // No explicit save needed in SwiftData; changes are auto-tracked
            await MainActor.run {
                self.relationshipToDeleteId = nil
            }
        }
    }

    // MARK: - Sidebar helpers
    private var featuresHeader: some View {
        Text("Features")
            .font(.caption)
            .foregroundColor(.secondary)
    }

    @ViewBuilder
    private func featuresLinks() -> some View {
        NavigationLink {
            DashboardContainerView(columnVisibility: $columnVisibility, modelContext: modelContext)
                .environment(\EnvironmentValues.modelContext, modelContext)
                .onAppear {
                    currentActiveFeature = .dashboard
                    inspectorContentProvider.clearInspectorContent()
                }
        } label: { SidebarItemRow(icon: "speedometer", title: "Dashboard") }

        NavigationLink {
            InvoicesContainerView(columnVisibility: $columnVisibility, showInspector: $mainInspectorVisible)
                .environment(\EnvironmentValues.modelContext, modelContext)
                .onAppear {
                    currentActiveFeature = .invoices
                }
        } label: { SidebarItemRow(icon: "doc.text", title: "Invoices") }

        NavigationLink {
            InvoiceTemplateEditorView()
                .environment(\EnvironmentValues.modelContext, modelContext)
                .onAppear {
                    currentActiveFeature = .invoiceTemplateEditor
                    inspectorContentProvider.clearInspectorContent()
                }
        } label: { SidebarItemRow(icon: "doc.badge.plus", title: "Template Editor") }

        NavigationLink {
            CalendarContainerView(columnVisibility: $columnVisibility, showInspector: $mainInspectorVisible, modelContext: modelContext)
                .environment(\EnvironmentValues.modelContext, modelContext)
                .onAppear {
                    currentActiveFeature = .calendar
                }
        } label: { SidebarItemRow(icon: "calendar", title: "Calendar") }

        NavigationLink {
            RelationshipsContainerView(
                columnVisibility: $columnVisibility,
                requestRelationshipDelete: { id in
                    self.relationshipToDeleteId = id
                    self.showingDeleteRelationshipAlert = true
                },
                context: modelContext,
                navigationManager: AppNavigationManager.shared
            )
            .environment(\EnvironmentValues.modelContext, modelContext)
            .onAppear {
                currentActiveFeature = .relationships
                inspectorContentProvider.clearInspectorContent()
            }
        } label: { SidebarItemRow(icon: "person.2", title: "Relationships") }

        NavigationLink {
            EnhancedNDISCatalogueContainerView()
                .environment(\EnvironmentValues.modelContext, modelContext)
                .onAppear {
                    currentActiveFeature = .ndisCatalogue
                    inspectorContentProvider.clearInspectorContent()
                }
        } label: { SidebarItemRow(icon: "list.bullet.rectangle", title: "NDIS Catalogue") }

        NavigationLink {
            NDISBillingContainerView()
                .environment(\EnvironmentValues.modelContext, modelContext)
                .onAppear {
                    currentActiveFeature = .ndisBilling
                    inspectorContentProvider.clearInspectorContent()
                }
        } label: { SidebarItemRow(icon: "creditcard", title: "NDIS Billing") }

        NavigationLink {
            TaxContainerView(modelContext: modelContext)
                .environment(\EnvironmentValues.modelContext, modelContext)
                .onAppear {
                    currentActiveFeature = .tax
                    inspectorContentProvider.clearInspectorContent()
                }
        } label: { SidebarItemRow(icon: "chart.pie", title: "Tax") }

        NavigationLink {
            SettingsContainerView(columnVisibility: $columnVisibility)
                .environment(\EnvironmentValues.modelContext, modelContext)
                .onAppear {
                    currentActiveFeature = .settings
                    inspectorContentProvider.clearInspectorContent()
                }
        } label: { SidebarItemRow(icon: "gearshape", title: "Settings") }

        NavigationLink {
            MapView()
                .environment(\EnvironmentValues.modelContext, modelContext)
                .onAppear {
                    currentActiveFeature = .map
                    inspectorContentProvider.clearInspectorContent()
                }
        } label: { SidebarItemRow(icon: "map", title: "Map") }
    }
}
