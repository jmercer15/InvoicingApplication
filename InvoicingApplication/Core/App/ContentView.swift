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
    @State private var navigationHistory: [AppTab] = [.invoices]
    @State private var forwardHistory: [AppTab] = []
    @State private var canNavigateBack = false
    @State private var canNavigateForward = false
    @State private var isHistoryNavigation = false
    
    // Inspector state for invoices feature
    @State private var showInvoiceInspector = false

    private var invoicesViewModel: InvoicesContainerViewModel {
        appAssembly.makeInvoicesViewModel()
    }

    private var billingHubViewModel: BillingHubViewModel {
        appAssembly.makeBillingHubViewModel()
    }

    private var relationshipsViewModel: RelationshipsContainerViewModel {
        appAssembly.makeRelationshipsViewModel()
    }

    private var calendarViewModel: CalendarContainerViewModel {
        appAssembly.makeCalendarContainerViewModel()
    }

    private var templateEditorWorkspace: TemplateEditorWorkspaceViewModel {
        appAssembly.makeTemplateEditorWorkspace()
    }

    private var settingsViewModel: SettingsWorkspaceViewModel {
        appAssembly.makeSettingsWorkspaceViewModel()
    }

    private var ndisCatalogueViewModel: NDISContainerViewModel {
        appAssembly.makeNDISContainerViewModel()
    }

    private var maxTabLabelWidth: CGFloat {
        let font = NSFont.systemFont(ofSize: 13, weight: .medium)
        let maxTextWidth = AppTab.allCases
            .map { ($0.title as NSString).size(withAttributes: [.font: font]).width }
            .max() ?? 0
        return 20 + 8 + maxTextWidth + 24 + 16
    }

    var body: some View {
        dynamicSplitView
            .background(PanelShellTokens.panelBackground.ignoresSafeArea())
            .navigationSplitViewStyle(.balanced)
            .onAppear {
                if let initialFeature = selectedFeature {
                    updateNavigationHistory(for: initialFeature)
                }
            }
            .onChange(of: selectedFeature) { _, newValue in
                if let newValue {
                    updateNavigationHistory(for: newValue)
                }
            }
    }

    @ViewBuilder
    var dynamicSplitView: some View {
        let activeFeature = selectedFeature ?? .invoices
        let widthProfile = activeFeature.widthProfile

        if activeFeature.splitStyle == .workspacePlusContentDetail {
            NavigationSplitView {
                sidebarColumn(with: widthProfile.sidebar)
            } content: {
                contentColumn(with: widthProfile)
            } detail: {
                detailColumn(with: widthProfile)
            }
        } else {
            NavigationSplitView {
                sidebarColumn(with: widthProfile.sidebar)
            } detail: {
                detailColumn(with: widthProfile)
            }
        }
    }

    private func sidebarColumn(with width: SplitViewColumnWidthProfile) -> some View {
        sidebar
            .background(PanelShellTokens.sidebarPanelBackground)
            .overlay(alignment: .trailing) {
                Rectangle()
                    .fill(PanelShellTokens.sidebarDividerColor)
                    .frame(width: 1)
            }
            .navigationSplitViewColumnWidth(
                min: width.min,
                ideal: width.ideal,
                max: width.max
            )
    }

    @ViewBuilder
    private func contentColumn(with widthProfile: SplitViewWidthProfile) -> some View {
        if let feature = selectedFeature {
            featureContent(for: feature)
                .id(feature)
                .standardPanelShell(role: .contentPanel)
                .navigationSplitViewColumnWidth(
                    min: widthProfile.content?.min ?? 300,
                    ideal: widthProfile.content?.ideal ?? 360,
                    max: widthProfile.content?.max ?? 460
                )
        } else {
            ContentUnavailableView("Select a Feature", systemImage: "sidebar.left")
                .navigationSplitViewColumnWidth(
                    min: widthProfile.content?.min ?? 300,
                    ideal: widthProfile.content?.ideal ?? 360,
                    max: widthProfile.content?.max ?? 460
                )
        }
    }

    @ViewBuilder
    private func detailColumn(with widthProfile: SplitViewWidthProfile) -> some View {
        let role: PanelShellRole = widthProfile.content == nil ? .singlePanel : .detailPanel
        NavigationStack {
            if let feature = selectedFeature {
                featureDetail(for: feature)
            } else {
                ContentUnavailableView("Select a Feature", systemImage: "sidebar.left")
            }
        }
        .standardPanelShell(role: role)
        .navigationSplitViewColumnWidth(
            min: widthProfile.detail.min,
            ideal: widthProfile.detail.ideal,
            max: widthProfile.detail.max
        )
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
        .scrollContentBackground(.hidden)
        .background(PanelShellTokens.sidebarPanelBackground)
        .applyDefaultSidebarRowSize()
        .navigationTitle("Workspace")
        .frame(minWidth: maxTabLabelWidth)
    }

    // MARK: - Content Column (List/Middle)
    @ViewBuilder
    private func featureContent(for feature: AppTab) -> some View {
        switch feature {
        case .invoices:
            InvoicesContentColumn(viewModel: invoicesViewModel)
                .environment(\.modelContext, modelContext)
        case .relationships:
            RelationshipsContentColumn(viewModel: relationshipsViewModel)
                .environment(\.modelContext, modelContext)
        case .ndisCatalogue:
            NDISCatalogueContentColumn(viewModel: ndisCatalogueViewModel)
                .environment(\.modelContext, modelContext)
                .onAppear {
                    ndisCatalogueViewModel.updateContextIfNeeded(modelContext)
                }
        case .settings:
            SettingsContentColumn(viewModel: settingsViewModel)
        default:
            EmptyView()
        }
    }

    // MARK: - Detail Column (Right/Main)
    @ViewBuilder
    private func featureDetail(for feature: AppTab) -> some View {
        renderFeatureDetail(for: feature)
            .id(feature)
        .onAppear {
            updateNavigationButtons()
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
        }
    }

    @ViewBuilder
    private func renderFeatureDetail(for feature: AppTab) -> some View {
        switch feature {
            case .invoices:
                InvoicesDetailColumn(viewModel: invoicesViewModel, showInspector: $showInvoiceInspector)
                    .environment(\.modelContext, modelContext)
                    .environmentObject(appAssembly.templateDataService)
                    .environmentObject(templateEditorWorkspace.templateManager)

            case .relationships:
                 RelationshipsDetailColumn(viewModel: relationshipsViewModel)
                    .environment(\.modelContext, modelContext)

            case .ndisCatalogue:
                 NDISCatalogueDetailColumn(viewModel: ndisCatalogueViewModel)
                    .environment(\.modelContext, modelContext)

            case .settings:
                SettingsDetailColumn(viewModel: settingsViewModel)
                    .environment(\.modelContext, modelContext)

            case .billingHub:
                BillingHubView(viewModel: billingHubViewModel)
                    .environment(\.modelContext, modelContext)
                    .environment(\.openInvoice) { invoiceId in
                        Task { @MainActor in
                            selectedFeature = .invoices
                            invoicesViewModel.selectInvoice(byId: invoiceId)
                        }
                    }
                    .environment(\.openSession) { sessionId in
                        Task { @MainActor in
                            selectedFeature = .calendar
                            await calendarViewModel.openSession(sessionID: sessionId)
                        }
                    }

            case .calendar:
                CalendarContentColumn(viewModel: calendarViewModel)
                    .environmentObject(EventKitSyncService.shared)

            case .invoiceTemplateEditor:
                 ModernTemplateEditorView(workspace: templateEditorWorkspace)
                    .environment(\.modelContext, modelContext)
                    .environmentObject(templateEditorWorkspace)
                    .environmentObject(templateEditorWorkspace.editorViewModel)
                    .environmentObject(appAssembly.templateDataService)
        }
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
            isHistoryNavigation = true
            selectedFeature = previousFeature
        }
        
        updateNavigationButtons()
    }
    
    private func navigateForward() {
        guard canNavigateForward, !forwardHistory.isEmpty else { return }
        
        // Get the next feature from forward history
        let nextFeature = forwardHistory.removeFirst()

        // Mirror browser-like forward navigation:
        // moving forward should push the destination onto back history.
        if navigationHistory.last != nextFeature {
            navigationHistory.append(nextFeature)
            optimizeNavigationPerformance()
        }

        // Navigate to the next feature
        isHistoryNavigation = true
        selectedFeature = nextFeature

        updateNavigationButtons()
    }

    private func updateNavigationHistory(for feature: AppTab) {
        if isHistoryNavigation {
            isHistoryNavigation = false
            updateNavigationButtons()
            return
        }

        if navigationHistory.last != feature {
            forwardHistory.removeAll()
            navigationHistory.append(feature)
            optimizeNavigationPerformance()
        }
        updateNavigationButtons()
    }
    
    private func updateNavigationButtons() {
        canNavigateBack = navigationHistory.count > 1
        canNavigateForward = !forwardHistory.isEmpty
    }

    private func optimizeNavigationPerformance() {
        if navigationHistory.count > 20 {
            let excessCount = navigationHistory.count - 20
            navigationHistory.removeFirst(excessCount)
        }

        if forwardHistory.count > 20 {
            let excessCount = forwardHistory.count - 20
            forwardHistory.removeLast(excessCount)
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
