import SwiftUI
import Core
import PersistenceModels

// MARK: - Simple List Container

/// Hierarchical fold-paper list container with breadcrumb drill-down and optional per-item context menus.
public struct FoldPaperContainer<ContextMenu: View>: View {
    @Binding var items: [TreeItem]
    @State private var selectedItemID: String? = nil
    @State private var selectionPath: [String] = []
    @FocusState private var keyboardFocusedItemID: String?
    let selectedItemIDs: Set<String>?
    let onItemTap: ((TreeItem) -> Void)?
    let makeContextMenu: (TreeItem) -> ContextMenu
    let rootTitle: String

    public init(
        items: Binding<[TreeItem]>,
        selectedItemIDs: Set<String>? = nil,
        rootTitle: String = "All Items",
        onItemTap: ((TreeItem) -> Void)? = nil,
        @ViewBuilder makeContextMenu: @escaping (TreeItem) -> ContextMenu
    ) {
        self._items = items
        self.selectedItemIDs = selectedItemIDs
        self.rootTitle = rootTitle
        self.onItemTap = onItemTap
        self.makeContextMenu = makeContextMenu
    }
}

public extension FoldPaperContainer where ContextMenu == EmptyView {
    init(
        items: Binding<[TreeItem]>,
        selectedItemIDs: Set<String>? = nil,
        rootTitle: String = "All Items",
        onItemTap: ((TreeItem) -> Void)? = nil
    ) {
        self.init(
            items: items,
            selectedItemIDs: selectedItemIDs,
            rootTitle: rootTitle,
            onItemTap: onItemTap,
            makeContextMenu: { _ in EmptyView() }
        )
    }
}

extension FoldPaperContainer {

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            breadcrumbView
                .padding(.bottom, FormSectionTokens.sectionStackSpacing)

            ScrollViewReader { proxy in
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
                .onChange(of: selectionPath) {
                    scrollToSelection(proxy: proxy)
                }
                .onAppear {
                    scrollToSelection(proxy: proxy)
                }
            }
        }
        .animation(.easeInOut(duration: StyleGuide.Animations.durationMedium), value: selectionPath)
        .appRespectsReduceMotion()
        .onMoveCommand(perform: handleMoveCommand)
        .onAppear {
            ensureKeyboardFocus()
            revealSelectionIfNeeded()
        }
        .onChange(of: items) {
            pruneSelectionPath()
        }
        .onChange(of: currentItemIDs) {
            ensureKeyboardFocus()
        }
        .onChange(of: selectedItemIDs) {
            revealSelectionIfNeeded()
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

    private struct BreadcrumbNode: Identifiable {
        let id: String
        let node: TreeItem?
        let indentLevel: Int
    }

    private var breadcrumbNodes: [BreadcrumbNode] {
        var nodes = [BreadcrumbNode(id: "root", node: nil, indentLevel: 0)]
        for (index, item) in breadcrumbTrail.enumerated() {
            nodes.append(BreadcrumbNode(id: item.id, node: item, indentLevel: index + 1))
        }
        return nodes
    }

    private var breadcrumbView: some View {
        AppBreadcrumbBar(
            showsBackButton: !selectionPath.isEmpty,
            onBack: goBack
        ) {
            ForEach(breadcrumbNodes) { entry in
                AppBreadcrumbSegmentButton(
                    title: entry.node?.title ?? rootTitle,
                    count: entityCount(for: entry.node),
                    indentLevel: entry.indentLevel,
                    backgroundColor: breadcrumbBackground(for: entry.node)
                ) {
                    crumbTapped(at: entry.indentLevel)
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
                    trailingTitle: item.trailingTitle,
                    trailingSubtitle: item.trailingSubtitle,
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

        if item.entityID != nil {
            row.contextMenu {
                makeContextMenu(item)
            }
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

    /// Deep-linked selections (e.g. arriving via Billing Hub's `openInvoice`) may point at a leaf
    /// nested several groups deep. Drill the breadcrumb path down to that leaf's parent so the item
    /// is actually visible instead of silently selected off-screen.
    private func revealSelectionIfNeeded() {
        guard let selectedItemIDs, !selectedItemIDs.isEmpty else { return }
        if currentItems.contains(where: { selectedItemIDs.contains($0.id) }) { return }
        guard let path = FoldPaperSelectionReveal.path(toReveal: selectedItemIDs, in: items) else { return }
        if path != selectionPath {
            selectionPath = path
        }
    }

    private func scrollToSelection(proxy: ScrollViewProxy) {
        guard let selectedItemIDs,
              let targetID = currentItems.first(where: { selectedItemIDs.contains($0.id) })?.id
        else { return }
        Task { @MainActor in
            withAnimation(.easeInOut(duration: StyleGuide.Animations.durationMedium)) {
                proxy.scrollTo(targetID, anchor: .center)
            }
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
