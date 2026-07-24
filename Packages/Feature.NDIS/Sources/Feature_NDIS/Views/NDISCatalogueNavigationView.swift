import SwiftUI
import SharedUI
import Data
import Core
import Observation

struct NDISCatalogueNavigationView: View {
    @Bindable var viewModel: NDISContainerViewModel
    let projection: NDISCatalogueProjection
    @Binding var showingHistoricalChanges: Bool
    private let externalSelectionPath: Binding<[String]>?
    private let onSelectionChanged: ((AppSelection?) -> Void)?

    @State private var selectionPath: [String] = []

    /// Layout rule (`.cursor/rules/swiftui/layout-system.mdc`) directs us
    /// toward `GridItem.adaptive(minimum:)` for adaptive multi-column layouts
    /// instead of a `GeometryReader` measurement loop. Per-card minimum width
    /// is still enforced by the cards themselves; this seed mirrors the
    /// historical packing breakpoint.
    private static let cardMinimumWidth: CGFloat = StyleGuide.Dimensions.workspaceContentColumnMin

    init(
        viewModel: NDISContainerViewModel,
        projection: NDISCatalogueProjection,
        showingHistoricalChanges: Binding<Bool>,
        selectionPath: Binding<[String]>? = nil,
        onSelectionChanged: ((AppSelection?) -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.projection = projection
        self._showingHistoricalChanges = showingHistoricalChanges
        self.externalSelectionPath = selectionPath
        self.onSelectionChanged = onSelectionChanged
    }

    private var itemLookup: [UUID: NDISItemSnapshot] {
        projection.itemLookup
    }

    private var currentNodes: [NDISCatalogueTreeNode] {
        var level = projection.navigationTree
        for id in selectionPath {
            guard let selected = level.first(where: { $0.id == id }),
                  let children = selected.children, !children.isEmpty else {
                return level
            }
            level = children
        }
        return level
    }

    private var gridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: Self.cardMinimumWidth), spacing: PanelShellTokens.contentListGridSpacing)]
    }

    var body: some View {
        VStack(spacing: 0) {
            NDISCatalogueBreadcrumbBar(
                selectionPath: $selectionPath,
                navigationTree: projection.navigationTree
            )
            Divider()

            if !viewModel.hasLoadedCatalogue {
                VStack(spacing: StyleGuide.Dimensions.paddingLarge) {
                    ProgressView("Loading NDIS items...")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .standardContentPanelListInsets()
            } else if let error = viewModel.loadError {
                VStack(spacing: StyleGuide.Dimensions.paddingLarge) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(StyleGuide.Typography.hero)
                        .foregroundStyle(ColorSystem.Status.error)
                    
                    Text("Failed to Load NDIS Catalogue")
                        .font(StyleGuide.Typography.sectionTitle)
                        .foregroundStyle(StyleGuide.Colors.text)
                    
                    Text(error.localizedDescription)
                        .font(StyleGuide.Typography.caption)
                        .foregroundStyle(StyleGuide.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, StyleGuide.Dimensions.paddingLarge)
                    
                    Button(action: {
                        viewModel.loadCatalogue(force: true)
                    }) {
                        Label("Retry", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.glassProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusLarge, style: .continuous)
                        .fill(PanelShellTokens.panelSecondaryBackground)
                )
                .standardContentPanelListInsets()
            } else if projection.totalItemCount == 0 {
                EmptyStateView(
                    icon: "list.bullet.clipboard",
                    title: "No NDIS Items Available",
                    message: "Import or sync the catalogue to browse support items."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusLarge, style: .continuous)
                        .fill(PanelShellTokens.panelSecondaryBackground)
                )
                .standardContentPanelListInsets()
            } else if projection.navigationTree.isEmpty {
                EmptyStateView(
                    icon: "line.3.horizontal.decrease.circle",
                    title: "No Matching NDIS Items",
                    message: "Try adjusting your search or filter criteria."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusLarge, style: .continuous)
                        .fill(PanelShellTokens.panelSecondaryBackground)
                )
                .standardContentPanelListInsets()
            } else {
                ScrollableNDISCatalogueGrid(
                    currentNodes: currentNodes,
                    gridColumns: gridColumns,
                    itemLookup: itemLookup,
                    preferredRegionIdentifier: projection.preferredRegionIdentifier,
                    resolvedSelectedItemId: viewModel.resolvedSelectedItem?.id,
                    selectionPath: $selectionPath,
                    showingHistoricalChanges: $showingHistoricalChanges,
                    onSelectionChanged: onSelectionChanged,
                    onSelectCard: { item in
                        viewModel.selectedItemID = item.id
                        onSelectionChanged?(.ndisItem(item.id))
                    }
                )
            }
        }
        .background(.clear)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear(perform: reconcileNavigationState)
        .onChange(of: projection.navigationTree) { _, _ in
            reconcileNavigationState()
        }
        .onChange(of: viewModel.selectedItemID) { _, newValue in
            guard let id = newValue else { return }
            syncSelectionPath(with: id)
            onSelectionChanged?(.ndisItem(id))
        }
        .onChange(of: selectionPath) { _, newValue in
            externalSelectionPath?.wrappedValue = newValue
            pruneSelectionPath()
            clearSelectionIfNoLongerInCurrentPath()
        }
        .animation(.easeInOut(duration: StyleGuide.Animations.durationMedium), value: projection.navigationTree.count)
        .animation(.easeInOut(duration: StyleGuide.Animations.durationMedium), value: selectionPath)
    }


    private func reconcileNavigationState() {
        if let externalSelectionPath {
            selectionPath = externalSelectionPath.wrappedValue
        }
        pruneSelectionPath()
        clearSelectionIfNoLongerInCurrentPath()
        if let selectedId = viewModel.resolvedSelectedItem?.id {
            syncSelectionPath(with: selectedId)
        }
    }

    private func clearSelectionIfNoLongerInCurrentPath() {
        guard let selectedId = viewModel.selectedItemID else { return }
        guard let itemPath = pathToItem(with: selectedId) else {
            viewModel.selectedItemID = nil
            onSelectionChanged?(nil)
            return
        }
        if itemPath.starts(with: selectionPath) {
            return
        }
        viewModel.selectedItemID = nil
        onSelectionChanged?(nil)
    }

    private func pruneSelectionPath() {
        var validPath: [String] = []
        var level = projection.navigationTree
        for id in selectionPath {
            guard let node = level.first(where: { $0.id == id }),
                  let children = node.children, !children.isEmpty else {
                break
            }
            validPath.append(id)
            level = children
        }
        if validPath != selectionPath {
            selectionPath = validPath
        }
    }

    private func syncSelectionPath(with itemId: UUID) {
        guard let path = pathToItem(with: itemId) else { return }
        if selectionPath != path {
            selectionPath = path
        }
    }

    private func pathToItem(with id: UUID) -> [String]? {
        guard let item = projection.itemLookup[id] else { return nil }
        let category = (item.category ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedCategory = category.isEmpty ? "Uncategorized" : category
        
        let group = (item.registrationGroup ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedGroup = group.isEmpty ? "No Group" : group
        
        return ["category_\(resolvedCategory)", "group_\(resolvedCategory)_\(resolvedGroup)"]
    }
}

struct ScrollableNDISCatalogueGrid: View {
    let currentNodes: [NDISCatalogueTreeNode]
    let gridColumns: [GridItem]
    let itemLookup: [UUID: NDISItemSnapshot]
    let preferredRegionIdentifier: String?
    let resolvedSelectedItemId: UUID?
    @Binding var selectionPath: [String]
    @Binding var showingHistoricalChanges: Bool
    let onSelectionChanged: ((AppSelection?) -> Void)?
    let onSelectCard: (NDISItemSnapshot) -> Void
    
    var body: some View {
        ScrollView {
            LazyVGrid(
                columns: gridColumns,
                spacing: PanelShellTokens.contentListGridSpacing
            ) {
                ForEach(currentNodes) { node in
                    card(for: node)
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal: .scale.combined(with: .opacity)
                        ))
                }
            }
            .standardContentPanelListInsets()
        }
    }
    
    @ViewBuilder
    private func card(for node: NDISCatalogueTreeNode) -> some View {
        if let children = node.children, !children.isEmpty {
            NDISCatalogueNavigationNodeCard(
                node: node,
                level: selectionPath.count,
                count: node.descendantCount
            ) {
                selectionPath.append(node.id)
                onSelectionChanged?(nil)
            }
        } else if let entityID = node.entityID, let uuid = UUID(uuidString: entityID), let item = itemLookup[uuid] {
            NDISCatalogueCard(
                item: item,
                preferredRegion: preferredRegionIdentifier,
                isSelected: resolvedSelectedItemId == item.id,
                onSelect: {
                    onSelectCard(item)
                }
            )
            .equatable()
            .contextMenu {
                Button("View details") {
                    onSelectCard(item)
                }

                if !item.isCurrent {
                    Button("Show historical context") {
                        showingHistoricalChanges = true
                    }
                }
            }
        }
    }
}

