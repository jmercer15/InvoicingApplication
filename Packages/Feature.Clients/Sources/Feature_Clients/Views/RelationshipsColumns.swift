import SwiftUI
import SwiftData
import Core
import SharedUI
import Data
import Observation

public struct RelationshipsContentColumn: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable private var viewModel: RelationshipsContainerViewModel

    @State private var selectedFilter: EntityFilter = .all
    @State private var selectedStatus: StatusFilter = .all
    @State private var selectionPath: [String] = []
    @State private var cachedProjection: RelationshipsProjection = .empty
    private let minimumCardWidth: CGFloat = 260
    private let externalSelectionPath: Binding<[String]>?
    private let onSelectionChanged: ((AppSelection?) -> Void)?

    /// Memoizes the relationships projection so the O(n) tree/counts build
    /// only runs when search, filters, or global entity data actually change.
    private var projectionTaskID: RelationshipsProjectionTaskID {
        RelationshipsProjectionTaskID(
            revision: viewModel.dataRevision,
            searchText: viewModel.relationshipSearchText,
            selectedFilter: selectedFilter,
            selectedStatus: selectedStatus
        )
    }

    // Tree and counts derived from cached projection (rebuilt by .task(id:)).
    private var navigationTree: [TreeItem] { cachedProjection.tree }
    private var descendantCountLookup: [String: Int] { cachedProjection.counts }
    private var isDetailVisible: Bool { viewModel.detailState != .none }
    private var isListStyle: Bool { isDetailVisible }

    /// Layout rule (`.cursor/rules/swiftui/layout-system.mdc`):
    /// "Never start with `GeometryReader` for ordinary screen layout." Use
    /// `GridItem.adaptive(minimum:)` so the container packs columns based on
    /// intrinsic minimum card width without a parent measurement loop.
    private var gridColumns: [GridItem] {
        let spacing = PanelShellTokens.contentListGridSpacing
        if isListStyle {
            return [GridItem(.flexible(), spacing: spacing)]
        }
        return [GridItem(.adaptive(minimum: minimumCardWidth), spacing: spacing)]
    }

    public init(
        viewModel: RelationshipsContainerViewModel,
        selectionPath: Binding<[String]>? = nil,
        onSelectionChanged: ((AppSelection?) -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.externalSelectionPath = selectionPath
        self.onSelectionChanged = onSelectionChanged
    }

    public var body: some View {
        VStack(spacing: 0) {
            RelationshipsBreadcrumbBar(
                selectionPath: $selectionPath,
                navigationTree: navigationTree,
                descendantCountLookup: descendantCountLookup
            )
                .padding(.bottom, StyleGuide.Dimensions.paddingMediumLarge)

            if navigationTree.isEmpty {
                EmptyStateView(
                    icon: "person.2.slash",
                    title: "No Relationships Found",
                    message: "Try adjusting your search or filters."
                )
                .standardSectionStyle()
                .standardContentPanelListInsets()
            } else {
                ScrollableRelationshipsGrid(
                    viewModel: viewModel,
                    currentNodes: currentNodes,
                    isListStyle: isListStyle,
                    isDetailVisible: isDetailVisible,
                    descendantCountLookup: descendantCountLookup,
                    selectionPath: $selectionPath,
                    onSelectionChanged: onSelectionChanged
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar(content: toolbarContent)

        .navigationTitle("Clients")
        .onAppear {
            if let externalSelectionPath {
                selectionPath = externalSelectionPath.wrappedValue
            }
        }
        .task(id: projectionTaskID) {
            try? await Task.sleep(for: .milliseconds(150))
            let container = modelContext.container
            let actor = RelationshipsProjectionActor(modelContainer: container)
            
            if let newProjection = try? await actor.build(
                searchText: viewModel.relationshipSearchText,
                selectedFilter: selectedFilter,
                selectedStatus: selectedStatus
            ) {
                cachedProjection = newProjection
                let normalized = normalizedSelectionPath(from: selectionPath, tree: newProjection.tree)
                if normalized != selectionPath {
                    selectionPath = normalized
                }
            }
        }
        .onChange(of: selectionPath) { _, newValue in
            externalSelectionPath?.wrappedValue = newValue
        }
        // Note: detailState change handled inside ScrollViewReader
        .animation(.easeInOut(duration: StyleGuide.Animations.durationMedium), value: selectionPath)
    }

    // MARK: - Grid Logic

    private var currentNodes: [TreeItem] {
        var level = navigationTree
        for id in selectionPath {
            guard let selected = level.first(where: { $0.id == id }),
                  let children = selected.children, !children.isEmpty else {
                return level
            }
            level = children
        }
        return level
    }

    // MARK: - Navigation Construction
    
    private func normalizedSelectionPath(from path: [String], tree: [TreeItem]) -> [String] {
        var normalized: [String] = []
        var level = tree

        for id in path {
            guard let node = level.first(where: { $0.id == id }),
                  let children = node.children,
                  !children.isEmpty else { break }
            normalized.append(id)
            level = children
        }

        return normalized
    }

    // MARK: - Toolbar
    @ToolbarContentBuilder
    private func toolbarContent() -> some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            AppToolbarPrimaryCreateButton(
                "New Client",
                systemImage: "person.crop.circle.badge.plus",
                help: "Create a new client",
                action: viewModel.createNewClient
            )
        }

        AppToolbarUtilityGroup {
            AppToolbarActionsMenu(title: "Add", systemImage: "plus", help: "Create a payee or plan manager") {
                Button(action: viewModel.createNewPayee) {
                    Label("New Payee", systemImage: "person.badge.plus")
                }
                Button(action: viewModel.createNewPlanManager) {
                    Label("New Plan Manager", systemImage: "briefcase.fill")
                }
            }

            Menu {
                Section("Entity Type") {
                    ForEach(Array(EntityFilter.allCases), id: \.self) { filter in
                        Button(filter.displayName) { selectedFilter = filter }
                    }
                }
                Section("Status") {
                    ForEach(Array(StatusFilter.allCases), id: \.self) { status in
                        Button(status.displayName) { selectedStatus = status }
                    }
                }
            } label: {
                Label {
                    Text(relationshipsFilterMenuTitle)
                } icon: {
                    Image(systemName: relationshipsFilterIsActive ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                }
            }
            .appToolbarLinkStyle(help: "Filter relationships")
        }
    }

    private var relationshipsFilterIsActive: Bool {
        selectedFilter != .all || selectedStatus != .all
    }

    private var relationshipsFilterMenuTitle: String {
        switch (selectedFilter, selectedStatus) {
        case (.all, .all):
            return "Filter"
        case let (filter, .all):
            return filter.displayName
        case let (.all, status):
            return status.displayName
        case let (filter, status):
            return "\(filter.displayName) · \(status.displayName)"
        }
    }

    // End RelationshipsContentColumn
}

private struct ScrollableRelationshipsGrid: View {
    let viewModel: RelationshipsContainerViewModel
    let currentNodes: [TreeItem]
    let isListStyle: Bool
    let isDetailVisible: Bool
    let descendantCountLookup: [String: Int]
    @Binding var selectionPath: [String]
    let onSelectionChanged: ((AppSelection?) -> Void)?

    private let minimumCardWidth: CGFloat = 260

    private var gridColumns: [GridItem] {
        let spacing = PanelShellTokens.contentListGridSpacing
        if isListStyle {
            return [GridItem(.flexible(), spacing: spacing)]
        }
        return [GridItem(.adaptive(minimum: minimumCardWidth), spacing: spacing)]
    }

    private var cardTransition: AnyTransition {
        if isDetailVisible {
            return .identity
        }
        return .opacity.combined(with: .scale(scale: 0.96, anchor: .center))
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVGrid(
                    columns: gridColumns,
                    spacing: PanelShellTokens.contentListGridSpacing
                ) {
                    ForEach(currentNodes, id: \.id) { node in
                        card(for: node)
                            .id(node.id) // Explicit ID for scrolling
                            .transition(cardTransition)
                    }
                }
                .animation(.easeInOut(duration: StyleGuide.Animations.durationMedium), value: isListStyle)
                .standardContentPanelListInsets()
            }
            .transaction { transaction in
                if isDetailVisible {
                    transaction.disablesAnimations = true
                }
            }
            .onChange(of: viewModel.detailState) { _, newState in
                if let scrollToId = nodeIdFrom(detailState: newState),
                   currentNodes.contains(where: { $0.id == scrollToId }) {
                    Task { @MainActor in
                        withAnimation {
                            proxy.scrollTo(scrollToId, anchor: .center)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func card(for node: TreeItem) -> some View {
        if isListStyle {
            if let children = node.children, !children.isEmpty {
                NavigationListRow(
                    title: node.title,
                    subtitle: "\(descendantCount(for: node)) items",
                    style: .parent,
                    isHighlighted: false,
                    onTap: {
                        selectionPath.append(node.id)
                    }
                )
            } else {
                NavigationListRow(
                    title: node.title,
                    subtitle: node.subtitle,
                    style: .leaf(
                        entityType: node.entityType,
                        entityTint: ColorSystem.Relationships.tint(forEntityType: node.entityType ?? "")
                    ),
                    isHighlighted: isSelected(node),
                    onTap: {
                        handleItemTap(node)
                    }
                )
            }
        } else {
            if let children = node.children, !children.isEmpty {
                RelationshipGroupCard(
                    node: node,
                    count: descendantCount(for: node),
                    isListStyle: isListStyle,
                    onSelect: {
                        selectionPath.append(node.id)
                    }
                )
                .equatable()
            } else {
                RelationshipCard(
                    title: node.title,
                    subtitle: node.subtitle,
                    entityType: node.entityType ?? "unknown",
                    status: node.subtitle, // Passing subtitle as status for now, or could map from entity
                    isSelected: isSelected(node),
                    isListStyle: isListStyle,
                    onSelect: {
                        handleItemTap(node)
                    }
                )
                .equatable()
            }
        }
    }
    
    private func isSelected(_ node: TreeItem) -> Bool {
        guard let entityIDString = node.entityID,
              let uuid = UUID(uuidString: entityIDString) else { return false }
        
        switch viewModel.detailState {
        case .client(let id): return id == uuid
        case .payee(let id): return id == uuid
        case .planManager(let id): return id == uuid
        default: return false
        }
    }
    
    private func descendantCount(for node: TreeItem) -> Int {
        if let cached = descendantCountLookup[node.id] {
            return cached
        }
        if let children = node.children, !children.isEmpty {
            return children.reduce(0) { $0 + descendantCount(for: $1) }
        }
        return node.entityID != nil ? 1 : 0
    }

    private func handleItemTap(_ item: TreeItem) {
        guard let entityIDString = item.entityID,
              let entityID = UUID(uuidString: entityIDString),
              let entityType = item.entityType else { return }

        switch entityType {
        case "client":
            viewModel.detailState = .client(entityID)
            onSelectionChanged?(.client(entityID))
        case "payee":
            viewModel.detailState = .payee(entityID)
            onSelectionChanged?(.payee(entityID))
        case "planManager":
            viewModel.detailState = .planManager(entityID)
            onSelectionChanged?(.planManager(entityID))
        default:
            break
        }
    }
    
    private func nodeIdFrom(detailState: DetailState) -> String? {
        switch detailState {
        case .client(let id): return "client_\(id)"
        case .payee(let id): return "payee_\(id)"
        case .planManager(let id): return "planmanager_\(id)"
        default: return nil
        }
    }
}

private struct RelationshipsProjectionTaskID: Equatable {
    let revision: Int
    let searchText: String
    let selectedFilter: EntityFilter
    let selectedStatus: StatusFilter
}
