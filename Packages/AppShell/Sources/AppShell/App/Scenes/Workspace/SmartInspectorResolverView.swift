import SwiftUI
import SharedUI
import Feature_Clients
import Feature_Invoices
import Feature_NDIS

struct SmartInspectorResolverView: View {
    let features: WorkspaceFeatureRegistries
    let navigationManager: AppNavigationManager

    private var resolvedSelection: AppSelection? {
        navigationManager.selection ?? navigationManager.inspectorFallbackSelection()
    }

    var body: some View {
        Group {
            switch resolvedSelection {
            case .invoice(let id):
                ContentUnavailableView {
                    Label("Invoice Inspector", systemImage: "doc.text.magnifyingglass")
                } description: {
                    Text("Invoice fields and formatting now live in editor’s integrated inspector.")
                }
                .id("inspector-invoice-\(id.uuidString)")
            case .client(let id):
                relationshipInspector(target: .client(id))
            case .payee(let id):
                relationshipInspector(target: .payee(id))
            case .planManager(let id):
                relationshipInspector(target: .planManager(id))
            case .ndisItem(let id):
                NDISCatalogueDetailColumn(viewModel: features.ndisCatalogue)
                    .id("ndis-inspector-\(id.uuidString)")
            case nil:
                emptyState("Select an item to inspect.")
            }
        }
        .standardPanelShell(role: .detailPanel)
        .onAppear {
            syncSelectionToInspector(resolvedSelection)
        }
        .onChange(of: resolvedSelection) { _, newSelection in
            syncSelectionToInspector(newSelection)
        }
    }

    private func emptyState(_ text: String) -> some View {
        EmptyStateView(
            icon: "sidebar.right",
            title: "Nothing Selected",
            message: text
        )
    }

    @ViewBuilder
    private func relationshipInspector(target: DetailState) -> some View {
        ZStack {
            let entityNavigation = makeWorkspaceEntityNavigationHandlers(
                navigationManager: navigationManager
            )
            RelationshipsDetailColumn(
                viewModel: relationshipsVM,
                onOpenInvoice: entityNavigation.openInvoice,
                onOpenClient: entityNavigation.openClient
            )
            if relationshipsVM.detailState != target {
                VStack(spacing: FormSectionTokens.sectionStackSpacing) {
                    ProgressView()
                    Text("Loading relationship details...")
                        .font(StyleGuide.Typography.caption)
                        .foregroundStyle(StyleGuide.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .glassEffect(.regular, in: .rect())
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .onAppear {
            if relationshipsVM.detailState != target {
                withAnimation(.easeInOut(duration: StyleGuide.Animations.durationMedium)) {
                    relationshipsVM.detailState = target
                }
            }
        }
        .onChange(of: target) { _, newTarget in
            if relationshipsVM.detailState != newTarget {
                withAnimation(.easeInOut(duration: StyleGuide.Animations.durationMedium)) {
                    relationshipsVM.detailState = newTarget
                }
            }
        }
        .animation(.easeInOut(duration: StyleGuide.Animations.durationMedium), value: relationshipsVM.detailState)
    }

    private var relationshipsVM: RelationshipsContainerViewModel {
        features.relationships
    }

    private func syncSelectionToInspector(_ selection: AppSelection?) {
        guard let selection else {
            features.invoices.clearSelection()
            features.relationships.clearSelection()
            features.ndisCatalogue.clearSelection()
            return
        }

        switch selection {
        case .invoice(let id):
            features.invoices.selectInvoiceForDeepLink(id: id)
        case .client(let id):
            if relationshipsVM.detailState != .client(id) {
                relationshipsVM.detailState = .client(id)
            }
        case .payee(let id):
            if relationshipsVM.detailState != .payee(id) {
                relationshipsVM.detailState = .payee(id)
            }
        case .planManager(let id):
            if relationshipsVM.detailState != .planManager(id) {
                relationshipsVM.detailState = .planManager(id)
            }
        case .ndisItem(let id):
            features.ndisCatalogue.selectItemForInspectorFocus(id: id)
        }
    }
}
