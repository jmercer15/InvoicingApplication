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

    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var preferredCompactColumn: NavigationSplitViewColumn = .sidebar
    @State private var selectedFeature: AppTab? = .invoices
    @State private var detailNavigationPath = NavigationPath()
    @StateObject private var invoicesViewModel = ContentView.makeInvoicesViewModel()
    @StateObject private var relationshipsViewModel = ContentView.makeRelationshipsViewModel()
    @StateObject private var calendarViewModel = ContentView.makeCalendarViewModel()
    @StateObject private var templateEditorWorkspace = ContentView.makeTemplateEditorWorkspace()
    @StateObject private var settingsViewModel = ContentView.makeSettingsViewModel()
    @StateObject private var ndisCatalogueViewModel = ContentView.makeNDISCatalogueViewModel()
    @StateObject private var ndisBillingViewModel = ContentView.makeNDISBillingViewModel()

    @State private var currentActiveFeature: AppTab? = .invoices
    @State private var mainInspectorVisible = false
    @State private var inspectorContent: InspectorContent? = nil

    private var maxTabLabelWidth: CGFloat {
        let font = NSFont.systemFont(ofSize: 13, weight: .medium)
        let maxTextWidth = AppTab.allCases
            .map { ($0.title as NSString).size(withAttributes: [.font: font]).width }
            .max() ?? 0
        return 20 + 8 + maxTextWidth + 24 + 16
    }

    @ViewBuilder
    var body: some View {
        Group {
            if needsDetailColumn(for: selectedFeature) {
                NavigationSplitView(
                    columnVisibility: $columnVisibility,
                    preferredCompactColumn: $preferredCompactColumn
                ) {
                    sidebar
                } content: {
                    contentNavigator
                        .navigationSplitViewColumnWidth(min: 620, ideal: 860, max: 1280)
                } detail: {
                    detailColumn
                }
            } else {
                NavigationSplitView(
                    preferredCompactColumn: $preferredCompactColumn
                ) {
                    sidebar
                } detail: {
                    contentNavigator
                }
            }
        }
        .navigationSplitViewStyle(shrinkStyle(for: selectedFeature))
        .inspector(isPresented: $mainInspectorVisible) {
            mainInspectorPanel
        }
        .background(
            Color("Background", bundle: .sharedUI)
                .ignoresSafeArea(edges: .top)
        )
        .onAppear {
            updateSplitVisibility(for: selectedFeature)
        }
        .onChange(of: selectedFeature) { _, newValue in
            updateSplitVisibility(for: newValue)
            guard let newValue else { return }
            currentActiveFeature = newValue
            if needsDetailColumn(for: newValue) {
                detailNavigationPath = NavigationPath()
            }
        }
    }

    private var sidebar: some View {
        List(selection: $selectedFeature) {
            Section(header: featuresHeader) {
                ForEach(AppTab.allCases) { feature in
                    Button(action: { selectFeature(feature) }) {
                        SidebarItemRow(icon: feature.iconName, title: feature.title)
                    }
                    .buttonStyle(.plain)
                    .background(
                        selectedFeature == feature ? Color.accentColor.opacity(0.12) : Color.clear
                    )
                    .cornerRadius(StyleGuide.Dimensions.cornerRadiusSmall)
                }
            }
        }
        .listStyle(.sidebar)
        .applyDefaultSidebarRowSize()
        .navigationTitle("Workspace")
        .frame(minWidth: maxTabLabelWidth)
    }

    private var contentNavigator: some View {
        NavigationStack(path: $detailNavigationPath) {
            featureContent(for: selectedFeature ?? .invoices)
                .id(selectedFeature ?? .invoices)
                .onPreferenceChange(InspectorContentPreferenceKey.self) { newContent in
                    inspectorContent = newContent
                }
                .fluidTransition()
                .animation(.spring(response: 0.6, dampingFraction: 0.7), value: selectedFeature)
        }
    }

    private var detailColumn: some View {
        featureDetail(for: selectedFeature ?? .invoices)
    }

    private func selectFeature(_ feature: AppTab) {
        if selectedFeature != feature {
            selectedFeature = feature
        }
    }

    @ViewBuilder
    private var mainInspectorPanel: some View {
        if let inspectorContent {
            VSplitView {
                InspectorHeader(feature: currentActiveFeature)
                inspectorContent.view
                    .inspectorColumnWidth(
                        min: StyleGuide.Dimensions.inspectorWidthMin,
                        ideal: StyleGuide.Dimensions.inspectorWidthIdeal,
                        max: StyleGuide.Dimensions.inspectorWidthMax
                    )
            }
        } else {
            VSplitView {
                InspectorHeader(feature: currentActiveFeature)
                InspectorFallbackView(feature: currentActiveFeature)
            }
        }
    }

    @ViewBuilder
    private func featureContent(for feature: AppTab) -> some View {
        switch feature {
        case .invoices:
            InvoicesContentColumn(viewModel: invoicesViewModel)
                .environment(\.modelContext, modelContext)
                .onAppear { currentActiveFeature = .invoices }
        case .billingHub:
            BillingHubView()
                .environmentObject(appAssembly.makeBillingHubViewModel())
                .environment(\.modelContext, modelContext)
                .onAppear { currentActiveFeature = .billingHub }
        case .invoiceTemplateEditor:
            TemplateEditorContentColumn(workspace: templateEditorWorkspace)
                .onAppear { currentActiveFeature = .invoiceTemplateEditor }
        case .calendar:
            CalendarContentColumn(viewModel: calendarViewModel, showInspector: $mainInspectorVisible)
                .environment(\.modelContext, modelContext)
                .environmentObject(EventKitSyncService.shared)
                .onAppear {
                    currentActiveFeature = .calendar
                    calendarViewModel.updateContextIfNeeded(modelContext)
                }
        case .relationships:
            RelationshipsContentColumn(viewModel: relationshipsViewModel)
                .environment(\.modelContext, modelContext)
                .onAppear {
                    currentActiveFeature = .relationships
                    relationshipsViewModel.updateContextIfNeeded(modelContext)
                }
        case .ndisCatalogue:
            NDISCatalogueContentColumn(viewModel: ndisCatalogueViewModel)
                .environment(\.modelContext, modelContext)
                .onAppear {
                    currentActiveFeature = .ndisCatalogue
                    ndisCatalogueViewModel.updateContextIfNeeded(modelContext)
                }
        case .ndisBilling:
            NDISBillingContentColumn(viewModel: ndisBillingViewModel)
                .environment(\.modelContext, modelContext)
                .onAppear {
                    currentActiveFeature = .ndisBilling
                    ndisBillingViewModel.updateContextIfNeeded(modelContext)
                }
        case .testingArea:
            TestingAreaView()
                .environment(\.modelContext, modelContext)
                .onAppear { currentActiveFeature = .testingArea }
        case .settings:
            SettingsContentColumn(viewModel: settingsViewModel)
                .onAppear { currentActiveFeature = .settings }
        }
    }

    @ViewBuilder
    private func featureDetail(for feature: AppTab) -> some View {
        switch feature {
        case .invoices:
            InvoicesDetailColumn(viewModel: invoicesViewModel, showInspector: $mainInspectorVisible)
                .environment(\.modelContext, modelContext)
        case .relationships:
            RelationshipsDetailColumn(viewModel: relationshipsViewModel)
                .environment(\.modelContext, modelContext)
                .onAppear {
                    relationshipsViewModel.updateContextIfNeeded(modelContext)
                }
        case .calendar:
            EmptyView()
        case .invoiceTemplateEditor:
            TemplateEditorDetailColumn(workspace: templateEditorWorkspace, isInspectorVisible: $mainInspectorVisible)
        case .ndisCatalogue:
            NDISCatalogueDetailColumn(viewModel: ndisCatalogueViewModel)
                .environment(\.modelContext, modelContext)
        case .ndisBilling:
            NDISBillingDetailColumn(viewModel: ndisBillingViewModel)
        case .settings:
            SettingsDetailColumn(viewModel: settingsViewModel)
                .environment(\.modelContext, modelContext)
        default:
            EmptyView()
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

    private func updateSplitVisibility(for feature: AppTab?) {
        columnVisibility = needsDetailColumn(for: feature) ? .all : .doubleColumn
    }

    private func needsDetailColumn(for feature: AppTab?) -> Bool {
        guard let feature else { return true }
        switch feature {
        case .billingHub, .calendar, .testingArea:
            return false
        default:
            return true
        }
    }

    private func usesProminentDetail(for feature: AppTab) -> Bool {
        switch feature {
        case .invoices, .relationships, .invoiceTemplateEditor, .settings:
            return true
        default:
            return false
        }
    }

    private func shrinkStyle(for feature: AppTab?) -> ShrinkFitSplitViewStyle {
        let feature = feature ?? .invoices
        let sidebarClamp: ClosedRange<CGFloat> = 200...360

        if needsDetailColumn(for: feature) {
            if usesProminentDetail(for: feature) {
                return ShrinkFitSplitViewStyle(
                    variant: .detailExpands,
                    sidebarClamp: sidebarClamp,
                    contentClamp: 260...420,
                    detailClamp: 520...1280
                )
            } else {
                return ShrinkFitSplitViewStyle(
                    variant: .contentExpands,
                    sidebarClamp: sidebarClamp,
                    contentClamp: 320...960,
                    detailClamp: 320...680
                )
            }
        } else {
            return ShrinkFitSplitViewStyle(
                sidebarClamp: sidebarClamp,
                detailClamp: 520...1280
            )
        }
    }
}


private struct InspectorHeader: View {
    let feature: AppTab?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Inspector")
                .font(.headline)
            if let feature {
                Text(feature.title)
                    .font(.subheadline)
                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
            } else {
                Text("No feature selected")
                    .font(.subheadline)
                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
            }
        }
        .padding()
    }
}

private struct InspectorFallbackView: View {
    let feature: AppTab?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("No inspector content available")
                .font(.body)
                .foregroundStyle(.secondary)
            if let feature {
                Text("Select an element in \(feature.title) to populate the inspector.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
