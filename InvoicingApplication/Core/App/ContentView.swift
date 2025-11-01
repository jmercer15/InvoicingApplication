import SwiftUI
import SwiftData
import AppKit
import Core
import Data
import SharedUI
import Feature_Calendar
import Feature_BillingHub
import Feature_Clients
import Feature_Invoices
import Feature_Settings
import Feature_NDIS
import Feature_InvoiceTemplateEditor

struct ContentView: View {
    @EnvironmentObject private var appAssembly: AppAssembly
    @Environment(\.modelContext) private var modelContext

    @State private var selectedFeature: AppTab? = .invoices
    @State private var navigationPath = NavigationPath()
    @State private var navigationHistory: [AppTab] = [.invoices]
    @State private var forwardHistory: [AppTab] = []
    @State private var canNavigateBack = false
    @State private var canNavigateForward = false
    @StateObject private var invoicesViewModel = ContentView.makeInvoicesViewModel()
    @StateObject private var relationshipsViewModel = ContentView.makeRelationshipsViewModel()
    @StateObject private var calendarViewModel = ContentView.makeCalendarViewModel()
    @StateObject private var templateEditorWorkspace = ContentView.makeTemplateEditorWorkspace()
    @StateObject private var settingsViewModel = ContentView.makeSettingsViewModel()
    @StateObject private var ndisCatalogueViewModel = ContentView.makeNDISCatalogueViewModel()
    @StateObject private var ndisBillingViewModel = ContentView.makeNDISBillingViewModel()


    private var maxTabLabelWidth: CGFloat {
        let font = NSFont.systemFont(ofSize: 13, weight: .medium)
        let maxTextWidth = AppTab.allCases
            .map { ($0.title as NSString).size(withAttributes: [.font: font]).width }
            .max() ?? 0
        return 20 + 8 + maxTextWidth + 24 + 16
    }

    @ViewBuilder
    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            mainContent
        }
        .navigationSplitViewStyle(.balanced)
    }

    private var sidebar: some View {
        List(selection: $selectedFeature) {
            Section(header: featuresHeader) {
                ForEach(AppTab.allCases) { feature in
                    NavigationLink(value: feature) {
                        SidebarItemRow(icon: feature.iconName, title: feature.title)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .applyDefaultSidebarRowSize()
        .navigationTitle("Workspace")
        .frame(minWidth: maxTabLabelWidth)
    }

    private var mainContent: some View {
        Group {
            if selectedFeature == .invoiceTemplateEditor {
                // Present template editor without NavigationStack to avoid conflicts
                featureWorkspace(for: .invoiceTemplateEditor)
                    .id(AppTab.invoiceTemplateEditor)
            } else {
                NavigationStack(path: $navigationPath) {
                    // Root view - show selected feature or default
                    Group {
                        if let selectedFeature = selectedFeature {
                            featureWorkspace(for: selectedFeature)
                                .id(selectedFeature)
                        } else {
                            featureWorkspace(for: .invoices)
                                .id(AppTab.invoices)
                        }
                    }
                    .navigationDestination(for: AppTab.self) { feature in
                        featureWorkspace(for: feature)
                            .id(feature)
                            .navigationTitle(feature.title)
                            .onAppear {
                                // Update navigation state when destination appears
                                updateNavigationButtons()
                            }
                    }
                }
            }
        }
        .onAppear {
            // Initialize navigation path with default selection
            if navigationPath.isEmpty {
                let initialFeature = selectedFeature ?? .invoices
                if initialFeature != .invoiceTemplateEditor {
                    navigationPath.append(initialFeature)
                }
                updateNavigationHistory(for: initialFeature)
            }
        }
        .onChange(of: selectedFeature) { _, newValue in
            // Update navigation path when selection changes
            if let newValue = newValue {
                updateNavigationHistory(for: newValue)
                if newValue != .invoiceTemplateEditor {
                    navigationPath = NavigationPath()
                    navigationPath.append(newValue)
                }
            }
        }
        .onOpenURL { url in
            // Handle deep linking
            handleDeepLink(url: url)
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button(action: navigateBack) {
                    Image(systemName: "chevron.left")
                }
                .disabled(!canNavigateBack)
                .help("Go Back")
                .keyboardShortcut(.leftArrow, modifiers: .command)
                
                Button(action: navigateForward) {
                    Image(systemName: "chevron.right")
                }
                .disabled(!canNavigateForward)
                .help("Go Forward")
                .keyboardShortcut(.rightArrow, modifiers: .command)
            }
            
            ToolbarItem(placement: .principal) {
                if let selectedFeature = selectedFeature {
                    HStack(spacing: 4) {
                        Image(systemName: selectedFeature.iconName)
                            .foregroundColor(.accentColor)
                        Text(selectedFeature.title)
                            .font(.headline)
                    }
                }
            }
            
            ToolbarItem(placement: .navigation) {
                Menu {
                    ForEach(AppTab.allCases) { feature in
                        Button(action: {
                            selectedFeature = feature
                        }) {
                            HStack {
                                Image(systemName: feature.iconName)
                                Text(feature.title)
                                if selectedFeature == feature {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "list.bullet")
                }
            }
        }
    }


    @ViewBuilder
    private func featureWorkspace(for feature: AppTab) -> some View {
        switch feature {
        case .invoices:
            HSplitView {
                InvoicesContentColumn(viewModel: invoicesViewModel)
                    .environment(\.modelContext, modelContext)
                    .background(Color("Background", bundle: .sharedUI))

                InvoicesDetailColumn(viewModel: invoicesViewModel, showInspector: .constant(false))
                    .environment(\.modelContext, modelContext)
                    .background(Color("Background", bundle: .sharedUI))
            }
        case .billingHub:
            BillingHubView()
                .environmentObject(appAssembly.makeBillingHubViewModel())
                .environment(\.modelContext, modelContext)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .invoiceTemplateEditor:
            ZStack {
                ModernTemplateEditorView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .environment(\.modelContext, modelContext)
                    .environmentObject(templateEditorWorkspace)
                    .environmentObject(templateEditorWorkspace.editorViewModel)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color("Background", bundle: .sharedUI))
        case .calendar:
            CalendarContentColumn(viewModel: calendarViewModel, showInspector: .constant(false))
                .environment(\.modelContext, modelContext)
                .environmentObject(EventKitSyncService.shared)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onAppear {
                    calendarViewModel.updateContextIfNeeded(modelContext)
                }
        case .relationships:
            HSplitView {
                RelationshipsContentColumn(viewModel: relationshipsViewModel)
                    .environment(\.modelContext, modelContext)
                    .background(Color("Background", bundle: .sharedUI))

                RelationshipsDetailColumn(viewModel: relationshipsViewModel)
                    .environment(\.modelContext, modelContext)
                    .background(Color("Background", bundle: .sharedUI))
            }
            .onAppear {
                relationshipsViewModel.updateContextIfNeeded(modelContext)
            }
        case .ndisCatalogue:
            HSplitView {
                NDISCatalogueContentColumn(viewModel: ndisCatalogueViewModel)
                    .environment(\.modelContext, modelContext)
                    .background(Color("Background", bundle: .sharedUI))

                NDISCatalogueDetailColumn(viewModel: ndisCatalogueViewModel)
                    .environment(\.modelContext, modelContext)
                    .background(Color("Background", bundle: .sharedUI))
            }
            .onAppear {
                ndisCatalogueViewModel.updateContextIfNeeded(modelContext)
            }
        case .ndisBilling:
            HSplitView {
                NDISBillingContentColumn(viewModel: ndisBillingViewModel)
                    .environment(\.modelContext, modelContext)
                    .background(Color("Background", bundle: .sharedUI))

                NDISBillingDetailColumn(viewModel: ndisBillingViewModel)
                    .background(Color("Background", bundle: .sharedUI))
            }
            .onAppear {
                ndisBillingViewModel.updateContextIfNeeded(modelContext)
            }
        case .testingArea:
            TestingAreaView()
                .environment(\.modelContext, modelContext)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .settings:
            HSplitView {
                SettingsContentColumn(viewModel: settingsViewModel)
                    .background(Color("Background", bundle: .sharedUI))

                SettingsDetailColumn(viewModel: settingsViewModel)
                    .environment(\.modelContext, modelContext)
                    .background(Color("Background", bundle: .sharedUI))
            }
        }
    }

    private static func makeInvoicesViewModel() -> InvoicesContainerViewModel {
        guard let container = ModelContainerHelper.createModelContainerSafely() else {
            fatalError("Failed to create model container for invoices")
        }
        let dummyContext = ModelContext(container)
        return InvoicesContainerViewModel(context: dummyContext)
    }

    private static func makeRelationshipsViewModel() -> RelationshipsContainerViewModel {
        guard let container = ModelContainerHelper.createModelContainerSafely() else {
            fatalError("Failed to create model container for relationships")
        }
        let dummyContext = ModelContext(container)
        return RelationshipsContainerViewModel(
            context: dummyContext,
            navigationManager: AppNavigationManager.shared
        )
    }

    private static func makeCalendarViewModel() -> CalendarContainerViewModel {
        guard let container = ModelContainerHelper.createModelContainerSafely() else {
            fatalError("Failed to create model container for calendar")
        }
        let dummyContext = ModelContext(container)
        return CalendarContainerViewModel(modelContext: dummyContext)
    }

    private static func makeTemplateEditorWorkspace() -> TemplateEditorWorkspaceViewModel {
        TemplateEditorWorkspaceViewModel()
    }

    private static func makeNDISCatalogueViewModel() -> NDISContainerViewModel {
        guard let container = ModelContainerHelper.createModelContainerSafely() else {
            fatalError("Failed to create model container for NDIS catalogue")
        }
        let dummyContext = ModelContext(container)
        return NDISContainerViewModel(context: dummyContext)
    }

    private static func makeNDISBillingViewModel() -> NDISBillingWorkspaceViewModel {
        guard let container = ModelContainerHelper.createModelContainerSafely() else {
            fatalError("Failed to create model container for NDIS billing")
        }
        let dummyContext = ModelContext(container)
        return NDISBillingWorkspaceViewModel(modelContext: dummyContext)
    }

    private static func makeSettingsViewModel() -> SettingsWorkspaceViewModel {
        SettingsWorkspaceViewModel()
    }

    private var featuresHeader: some View {
        Text("Features")
            .font(.caption)
            .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
    }
    
    // MARK: - Navigation Helpers
    
    private func navigateBack() {
        guard canNavigateBack, navigationHistory.count > 1 else { return }
        
        // Get current feature to add to forward history
        if let currentFeature = selectedFeature {
            forwardHistory.insert(currentFeature, at: 0)
        }
        
        // Remove current feature from navigation history
        navigationHistory.removeLast()
        
        if let previousFeature = navigationHistory.last {
            selectedFeature = previousFeature
            navigationPath = NavigationPath()
            navigationPath.append(previousFeature)
        }
        
        updateNavigationButtons()
    }
    
    private func navigateForward() {
        guard canNavigateForward, !forwardHistory.isEmpty else { return }
        
        // Get the next feature from forward history
        let nextFeature = forwardHistory.removeFirst()
        
        // Add current feature to forward history for potential back navigation
        if let currentFeature = selectedFeature {
            forwardHistory.insert(currentFeature, at: 0)
        }
        
        // Navigate to the next feature
        selectedFeature = nextFeature
        navigationPath = NavigationPath()
        navigationPath.append(nextFeature)
        
        // Update navigation history
        navigationHistory.append(nextFeature)
        
        updateNavigationButtons()
    }
    
    private func updateNavigationHistory(for feature: AppTab) {
        // Add to history if it's not already the last item
        if navigationHistory.last != feature {
            // Clear forward history when navigating to a new feature
            forwardHistory.removeAll()
            
            // Add to navigation history
            navigationHistory.append(feature)
            
            // Optimize navigation performance
            optimizeNavigationPerformance()
        }
        updateNavigationButtons()
    }
    
    private func updateNavigationButtons() {
        canNavigateBack = navigationHistory.count > 1
        canNavigateForward = !forwardHistory.isEmpty
    }
    
    // MARK: - Deep Linking Support
    
    private func handleDeepLink(url: URL) {
        guard let scheme = url.scheme,
              scheme == "invoicingapp" else { return }
        
        let pathComponents = url.pathComponents.filter { $0 != "/" }
        
        if let firstComponent = pathComponents.first,
           let feature = AppTab.allCases.first(where: { $0.rawValue == firstComponent }) {
            selectedFeature = feature
            updateNavigationHistory(for: feature)
            navigationPath = NavigationPath()
            navigationPath.append(feature)
        }
    }
    
    // MARK: - Navigation Performance Optimization
    
    private func optimizeNavigationPerformance() {
        // Limit navigation history to prevent memory issues
        if navigationHistory.count > 20 {
            let excessCount = navigationHistory.count - 20
            navigationHistory.removeFirst(excessCount)
        }
        
        // Limit forward history to prevent memory issues
        if forwardHistory.count > 20 {
            let excessCount = forwardHistory.count - 20
            forwardHistory.removeLast(excessCount)
        }
        
        // Clear navigation path if it becomes too deep
        if navigationPath.count > 10 {
            navigationPath = NavigationPath()
            if let currentFeature = selectedFeature {
                navigationPath.append(currentFeature)
            }
        }
    }

}


private extension View {
    @ViewBuilder
    func applyDefaultSidebarRowSize() -> some View {
        #if os(macOS)
        if #available(macOS 14.0, *) {
            self.environment(\.sidebarRowSize, .medium)
        } else {
            self
        }
        #elseif os(iOS)
        if #available(iOS 17.0, *) {
            self.environment(\.sidebarRowSize, .medium)
        } else {
            self
        }
        #else
        self
        #endif
    }
}

