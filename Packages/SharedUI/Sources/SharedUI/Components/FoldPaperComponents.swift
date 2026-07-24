import SwiftUI
import Core


// MARK: - TreeItem Data Structure
public struct TreeItem: Hashable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var subtitle: String?
    public var children: [TreeItem]? = nil
    public var entityID: String?
    public var entityType: String?
    /// Optional domain state used only for row presentation (for example invoice status colour).
    public var entityState: String?

    public init(
        id: String,
        title: String,
        subtitle: String? = nil,
        children: [TreeItem]? = nil,
        entityID: String? = nil,
        entityType: String? = nil,
        entityState: String? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.children = children
        self.entityID = entityID
        self.entityType = entityType
        self.entityState = entityState
    }
}

// MARK: - Simple List Container

public struct FoldPaperContainer: View {
    @Binding var items: [TreeItem]
    @State private var selectedItemID: String? = nil
    @State private var selectionPath: [String] = []
    @FocusState private var keyboardFocusedItemID: String?
    let selectedItemIDs: Set<String>?
    let onItemTap: ((TreeItem) -> Void)?
    let onItemContextMenu: ((TreeItem) -> AnyView?)?
    let rootTitle: String

    public init(
        items: Binding<[TreeItem]>,
        selectedItemIDs: Set<String>? = nil,
        rootTitle: String = "All Items",
        onItemTap: ((TreeItem) -> Void)? = nil,
        onItemContextMenu: ((TreeItem) -> AnyView?)? = nil
    ) {
        self._items = items
        self.selectedItemIDs = selectedItemIDs
        self.rootTitle = rootTitle
        self.onItemTap = onItemTap
        self.onItemContextMenu = onItemContextMenu
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            breadcrumbView
                .padding(.bottom, FormSectionTokens.sectionStackSpacing)

            ScrollView {
                LazyVStack(spacing: PanelShellTokens.contentListGridSpacing) {
                    ForEach(currentItems, id: \.id) { item in
                        rowView(for: item)
                    }
                }
                .standardContentPanelListInsets()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)
        }
        .animation(.easeInOut(duration: StyleGuide.Animations.durationMedium), value: selectionPath)
        .onMoveCommand(perform: handleMoveCommand)
        .onAppear(perform: ensureKeyboardFocus)
        .onChange(of: items) {
            pruneSelectionPath()
        }
        .onChange(of: currentItemIDs) {
            ensureKeyboardFocus()
        }
    }

    private var breadcrumbTrail: [TreeItem] {
        var trail: [TreeItem] = []
        var currentLevel = items

        for id in selectionPath {
            guard let selected = currentLevel.first(where: { $0.id == id }) else { break }
            trail.append(selected)
            currentLevel = selected.children ?? []
        }
        return trail
    }

    private var currentItems: [TreeItem] {
        var level = items
        for id in selectionPath {
            guard let selected = level.first(where: { $0.id == id }),
                  let children = selected.children, !children.isEmpty else {
                return level
            }
            level = children
        }
        return level
    }

    private var currentItemIDs: [String] {
        currentItems.map(\.id)
    }

    private var breadcrumbView: some View {
        AppBreadcrumbBar(
            showsBackButton: !selectionPath.isEmpty,
            onBack: goBack
        ) {
            let nodes: [TreeItem?] = [nil] + breadcrumbTrail.map { Optional($0) }
            ForEach(Array(nodes.enumerated()), id: \.offset) { index, node in
                AppBreadcrumbSegmentButton(
                    title: node?.title ?? rootTitle,
                    count: entityCount(for: node),
                    indentLevel: index,
                    backgroundColor: breadcrumbBackground(for: node)
                ) {
                    crumbTapped(at: index)
                }
            }
        }
    }

    private func breadcrumbBackground(for node: TreeItem?) -> Color {
        guard let node else {
            return Color.primary.opacity(StyleGuide.Opacity.faint - 0.03)
        }
        if isTopLevelCategory(node) {
            return ColorSystem.Navigation.categoryTint.opacity(StyleGuide.Opacity.light + 0.05)
        }
        if isRegistrationGroup(node) {
            return ColorSystem.Navigation.groupTint.opacity(StyleGuide.Opacity.light + 0.05)
        }
        return Color.primary.opacity(StyleGuide.Opacity.faint + 0.02)
    }

    private func entityCount(for node: TreeItem?) -> Int {
        guard let node else {
            return items.reduce(0) { $0 + entityCount(for: $1) }
        }
        return entityCount(for: node)
    }

    private func entityCount(for node: TreeItem) -> Int {
        var total = node.entityID == nil ? 0 : 1
        if let children = node.children, !children.isEmpty {
            total += children.reduce(0) { $0 + entityCount(for: $1) }
        }
        return total
    }

    private func isTopLevelCategory(_ item: TreeItem) -> Bool {
        // Check if this is a top-level category (has children but no parent context)
        return item.children != nil && item.id.hasPrefix("category_")
    }

    private func isRegistrationGroup(_ item: TreeItem) -> Bool {
        // Check if this is a registration group (has children and is under a category)
        return item.children != nil && item.id.hasPrefix("group_")
    }

    private func colorFor(_ entityType: String, state: String?) -> Color {
        switch entityType {
        case "client": return ColorSystem.Relationships.clientTint
        case "payee": return ColorSystem.Relationships.payeeTint
        case "planManager": return ColorSystem.Relationships.planManagerTint
        case "invoice":
            return ColorSystem.Invoice.statusColor(
                for: state ?? AppConstants.invoiceStatusPending
            )
        case "ndisItem": return ColorSystem.Navigation.categoryTint
        default: return ColorSystem.Relationships.unknownTint
        }
    }
    @ViewBuilder
    private func rowView(for item: TreeItem) -> some View {
        let hasChildren = (item.children?.isEmpty == false)
        let isLeafHighlighted = selectedItemIDs?.contains(item.id) ?? (selectedItemID == item.id)

        let row = Group {
            if hasChildren {
                NavigationListRow(
                    title: item.title,
                    subtitle: item.subtitle,
                    style: .parent,
                    onTap: {
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.85)) {
                            handleSelection(of: item)
                        }
                    }
                )
                .focused($keyboardFocusedItemID, equals: item.id)
            } else {
                NavigationListRow(
                    title: item.title,
                    subtitle: item.subtitle,
                    style: .leaf(
                        entityType: item.entityType,
                        entityTint: colorFor(
                            item.entityType ?? "unknown",
                            state: item.entityState
                        )
                    ),
                    isHighlighted: isLeafHighlighted,
                    onTap: {
                        withAnimation(.spring(response: 0.15, dampingFraction: 0.9)) {
                            handleSelection(of: item)
                        }
                    }
                )
                .focused($keyboardFocusedItemID, equals: item.id)
            }
        }

        if let menu = onItemContextMenu?(item) {
            row.contextMenu { menu }
        } else {
            row
        }
    }

    private func handleSelection(of item: TreeItem) {
        if let children = item.children, !children.isEmpty {
            if selectionPath.last != item.id {
                selectionPath.append(item.id)
            }
            selectedItemID = nil
            keyboardFocusedItemID = nil
            Task { @MainActor in
                await Task.yield()
                ensureKeyboardFocus()
            }
        } else {
            if selectedItemIDs == nil {
                selectedItemID = item.id
            }
            onItemTap?(item)
        }
    }

    private func pruneSelectionPath() {
        var newPath: [String] = []
        var currentLevel = items

        for id in selectionPath {
            guard let selected = currentLevel.first(where: { $0.id == id }) else { break }
            guard let children = selected.children, !children.isEmpty else { break }
            newPath.append(id)
            currentLevel = children
        }

        if newPath != selectionPath {
            selectionPath = newPath
        }

        if let selectedID = selectedItemID,
           !currentItems.contains(where: { $0.id == selectedID }) {
            selectedItemID = nil
        }
    }

    private func goBack() {
        guard !selectionPath.isEmpty else { return }
        selectionPath.removeLast()
        selectedItemID = nil
        keyboardFocusedItemID = nil
        Task { @MainActor in
            await Task.yield()
            ensureKeyboardFocus()
        }
    }

    private func crumbTapped(at index: Int) {
        if index == 0 {
            selectionPath = []
        } else {
            selectionPath = Array(selectionPath.prefix(index))
        }
        selectedItemID = nil
        keyboardFocusedItemID = nil
        Task { @MainActor in
            await Task.yield()
            ensureKeyboardFocus()
        }
    }

    private func handleMoveCommand(_ direction: MoveCommandDirection) {
        switch direction {
        case .up:
            keyboardFocusedItemID = FoldPaperKeyboardNavigation.adjacentItemID(
                currentID: keyboardFocusedItemID,
                itemIDs: currentItemIDs,
                move: .previous
            )
        case .down:
            keyboardFocusedItemID = FoldPaperKeyboardNavigation.adjacentItemID(
                currentID: keyboardFocusedItemID,
                itemIDs: currentItemIDs,
                move: .next
            )
        case .right:
            guard let focused = currentItems.first(where: { $0.id == keyboardFocusedItemID }),
                  focused.children?.isEmpty == false
            else { return }
            handleSelection(of: focused)
        case .left:
            goBack()
        default:
            break
        }
    }

    private func ensureKeyboardFocus() {
        guard !currentItems.isEmpty else {
            keyboardFocusedItemID = nil
            return
        }
        if let keyboardFocusedItemID, currentItemIDs.contains(keyboardFocusedItemID) {
            return
        }
        keyboardFocusedItemID = currentItems.first(where: {
            selectedItemIDs?.contains($0.id) == true
        })?.id ?? selectedItemID ?? currentItems.first?.id
    }
}

enum FoldPaperKeyboardNavigation {
    enum Move: Equatable {
        case previous
        case next
    }

    static func adjacentItemID(
        currentID: String?,
        itemIDs: [String],
        move: Move
    ) -> String? {
        guard !itemIDs.isEmpty else { return nil }
        guard let currentID,
              let currentIndex = itemIDs.firstIndex(of: currentID)
        else {
            return move == .next ? itemIDs.first : itemIDs.last
        }

        switch move {
        case .previous:
            return itemIDs[max(0, currentIndex - 1)]
        case .next:
            return itemIDs[min(itemIDs.count - 1, currentIndex + 1)]
        }
    }
}
