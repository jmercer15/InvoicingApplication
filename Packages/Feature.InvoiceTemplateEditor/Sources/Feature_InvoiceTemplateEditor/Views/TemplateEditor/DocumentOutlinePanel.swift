import SwiftUI
import Core
import SharedUI

struct DocumentOutlinePanel: View {
    @EnvironmentObject private var document: InvoiceDocument
    @Environment(\.panelMaxHeight) private var panelMaxHeight
    @State private var expandedSections: Set<AnyHashable> = ["structure"]
    @State private var expandedNodeIDs: Set<String> = []
    @State private var hoveredNodeID: String?
    
    private struct OutlineNode: Identifiable, Hashable {
        let id: String
        let title: String
        let subtitle: String?
        let badge: String?
        let icon: String
        let selection: SectionSplitSelection?
        let children: [OutlineNode]
        
        var isLeaf: Bool { children.isEmpty }
    }
    
    var body: some View {
        InspectorContentLayout(
            header: EmptyView(),
            descriptors: [
                InspectorSectionDescriptor(
                    section: "structure",
                    title: "",
                    alwaysExpanded: true,
                    isVisible: true
                ) {
                    AnyView(outlineContent)
                }
            ],
            side: .leading,
            expandedSections: $expandedSections
        )
        .onAppear { syncExpandedNodes(with: outline) }
        .onChange(of: outline) { _, newValue in
            syncExpandedNodes(with: newValue)
        }
        .onChange(of: document.selectedSplitSelection) { _, newSelection in
            expandPathToSelection(newSelection)
        }
    }
    
    private var header: some View {
        HStack(spacing: 10) {
            // Icon box
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.accentColor.opacity(0.15),
                                Color.accentColor.opacity(0.06)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.accentColor.opacity(0.35), lineWidth: 0.9)
                Image("fluent-ic_fluent_split_vertical_20_regular", bundle: .module)
                    .resizable()
                    .renderingMode(.template)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 14, height: 14)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.accentColor)
            }
            .frame(width: 28, height: 28)
            
            Text("Sections")
                .font(InspectorTypography.panelTitle)
                .foregroundColor(Color.primaryText)
            
            Spacer()
            
            HStack(spacing: 4) {
                headerControlButton(
                    iconName: "fluent-ic_fluent_arrow_expand_20_regular",
                    help: "Expand all nodes",
                    action: expandAllNodes
                )
                headerControlButton(
                    iconName: "fluent-ic_fluent_arrow_collapse_all_20_regular",
                    help: "Collapse to sections",
                    action: collapseToSections
                )
            }
        }
    }
    
    @ViewBuilder
    private var outlineContent: some View {
        if outline.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Image("fluent-ic_fluent_square_hint_20_regular", bundle: .module)
                    .resizable()
                    .renderingMode(.template)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(Color.secondaryText.opacity(0.7))
                Text("No splits yet")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(Color.secondaryText)
                Text("Add a split on the canvas to see it appear here.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color.secondaryText.opacity(0.9))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.03))
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
            )
        } else {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(outline) { node in
                    nodeView(node, level: 0)
                }
            }
            .padding(.vertical, 2)
        }
    }
    
    private func nodeView(_ node: OutlineNode, level: Int) -> AnyView {
        let isExpanded = expandedNodeIDs.contains(node.id)
        
        return AnyView(
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if node.isLeaf {
                        Spacer()
                            .frame(width: 24)
                    } else {
                        Button {
                            toggle(node)
                        } label: {
                            Image(expandedNodeIDs.contains(node.id) ? "fluent-ic_fluent_chevron_down_20_regular" : "fluent-ic_fluent_chevron_right_20_regular", bundle: .module)
                                .resizable()
                                .renderingMode(.template)
                                .aspectRatio(contentMode: .fit)
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundColor(Color.secondaryText)
                                .frame(width: 20, height: 20, alignment: .center)
                                .background(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(Color(NSColor.controlBackgroundColor).opacity(0.08))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .stroke(Color(NSColor.separatorColor).opacity(0.35), lineWidth: 0.9)
                                )
                                .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .pointerStyle(.link)
                        .frame(width: 24, height: 24, alignment: .center)
                    }
                    
                    nodeRow(node)
                        .buttonStyle(.plain)
                }
                
                if isExpanded, !node.children.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(node.children) { child in
                            nodeView(child, level: level + 1)
                        }
                    }
                    .padding(.leading, 8)
                    .transition(.opacity)
                }
            }
            .padding(.leading, CGFloat(level) * 2)
            .animation(.smooth(duration: 0.22), value: isExpanded)
        )
    }
    
    private func headerControlButton(iconName: String, help: String, action: @escaping () -> Void) -> some View {
        HeaderControlButton(iconName: iconName, help: help, action: action)
    }
    
    private func nodeRow(_ node: OutlineNode) -> some View {
        let isSelected = node.selection.map { $0 == document.selectedSplitSelection } ?? false
        let isHovered = hoveredNodeID == node.id
        let background = RoundedRectangle(cornerRadius: 10, style: .continuous)
        let badgeText = node.badge
        let isSplit = !node.isLeaf
        let fillColor = isSelected
            ? Color.accentColor.opacity(0.14)
            : Color(NSColor.controlBackgroundColor).opacity(isHovered ? 0.12 : 0.08)
        let strokeColor = isSelected
            ? Color.accentColor.opacity(0.9)
            : Color(NSColor.separatorColor).opacity(isHovered ? 0.5 : 0.35)
        let leadingAccentWidth: CGFloat = isSplit ? 3 : 2
        
        return Button {
            select(node)
        } label: {
            HStack(spacing: 8) {
                Image(node.icon, bundle: .module)
                    .resizable()
                    .renderingMode(.template)
                    .aspectRatio(contentMode: .fit)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(isSelected ? Color.accentColor : Color.secondaryText.opacity(isHovered ? 0.9 : 0.8))
                    .frame(width: 16, height: 16)
                    .background(
                        Circle()
                            .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.white.opacity(isHovered ? 0.08 : 0))
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(node.title)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundColor(Color.primaryText.opacity(isSelected ? 1 : 0.95))
                }
                
                Spacer()
                
                if let badgeText {
                    Text(badgeText)
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundColor(isSelected ? Color.white : Color.secondaryText)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2.5)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.accentColor : Color.secondaryText.opacity(isHovered ? 0.2 : 0.12))
                        )
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 7)
            .background(
                background
                    .fill(fillColor)
            )
            .overlay(
                background
                    .strokeBorder(strokeColor, lineWidth: isSelected ? 1.1 : 0.9)
            )
            .contentShape(background)
        }
        .onHover { hovering in
            hoveredNodeID = hovering ? node.id : nil
            if hovering {
                document.hoveredSplitSelection = node.selection
            } else if document.hoveredSplitSelection == node.selection {
                document.hoveredSplitSelection = nil
            }
        }
        .contextMenu {
            if let selection = node.selection {
                nodeContextMenu(for: node, selection: selection)
            }
        }
        .pointerStyle(.link)
    }
    
    @ViewBuilder
    private func nodeContextMenu(for node: OutlineNode, selection: SectionSplitSelection) -> some View {
        if let parentSplit = getParentSplit(for: selection) {
            if parentSplit.direction == .grid {
                gridContextMenu(for: node, selection: selection, parentSplit: parentSplit)
            } else {
                linearContextMenu(for: node, selection: selection, parentSplit: parentSplit)
            }
        }
    }
    
    @ViewBuilder
    private func linearContextMenu(for node: OutlineNode, selection: SectionSplitSelection, parentSplit: SectionSplit) -> some View {
        let childIndex = selection.path.last ?? 0
        
        // Insert options (available for all nodes)
        Button(action: {
            document.insertChildInSplit(for: selection, at: childIndex)
        }) {
            Label {
                Text("Insert Before")
            } icon: {
                Image("fluent-ic_fluent_arrow_up_20_regular", bundle: .module)
                    .resizable()
                    .renderingMode(.template)
                    .aspectRatio(contentMode: .fit)
            }
        }
        
        Button(action: {
            document.insertChildInSplit(for: selection, at: childIndex + 1)
        }) {
            Label {
                Text("Insert After")
            } icon: {
                Image("fluent-ic_fluent_arrow_down_20_regular", bundle: .module)
                    .resizable()
                    .renderingMode(.template)
                    .aspectRatio(contentMode: .fit)
            }
        }
        
        // Delete option (only if parent has more than 1 child)
        if parentSplit.splitCount > 1 {
            Divider()
            
            Button(role: .destructive, action: {
                document.deleteChildFromSplit(for: selection, at: childIndex)
            }) {
                Label {
                    Text("Delete This Child")
                } icon: {
                    Image("fluent-ic_fluent_delete_20_regular", bundle: .module)
                        .resizable()
                        .renderingMode(.template)
                        .aspectRatio(contentMode: .fit)
                }
            }
        }
    }
    
    @ViewBuilder
    private func gridContextMenu(for node: OutlineNode, selection: SectionSplitSelection, parentSplit: SectionSplit) -> some View {
        let childIndex = selection.path.last ?? 0
        let (row, col) = parentSplit.rowColumn(for: childIndex)
        
        // Row operations
        Menu("Row Operations") {
            Button(action: {
                document.insertGridRow(for: selection, at: row)
            }) {
                Label {
                    Text("Insert Row Above")
                } icon: {
                    Image("fluent-ic_fluent_arrow_up_20_regular", bundle: .module)
                        .resizable()
                        .renderingMode(.template)
                        .aspectRatio(contentMode: .fit)
                }
            }
            
            Button(action: {
                document.insertGridRow(for: selection, at: row + 1)
            }) {
                Label {
                    Text("Insert Row Below")
                } icon: {
                    Image("fluent-ic_fluent_arrow_down_20_regular", bundle: .module)
                        .resizable()
                        .renderingMode(.template)
                        .aspectRatio(contentMode: .fit)
                }
            }
            
            if parentSplit.gridRows > 1 {
                Divider()
                
                Button(role: .destructive, action: {
                    document.deleteGridRow(for: selection, at: row)
                }) {
                    Label {
                        Text("Delete This Row")
                    } icon: {
                        Image("fluent-ic_fluent_delete_20_regular", bundle: .module)
                            .resizable()
                            .renderingMode(.template)
                            .aspectRatio(contentMode: .fit)
                    }
                }
            }
        }
        
        // Column operations
        Menu("Column Operations") {
            Button(action: {
                document.insertGridColumn(for: selection, at: col)
            }) {
                Label {
                    Text("Insert Column Left")
                } icon: {
                    Image("fluent-ic_fluent_arrow_left_20_regular", bundle: .module)
                        .resizable()
                        .renderingMode(.template)
                        .aspectRatio(contentMode: .fit)
                }
            }
            
            Button(action: {
                document.insertGridColumn(for: selection, at: col + 1)
            }) {
                Label {
                    Text("Insert Column Right")
                } icon: {
                    Image("fluent-ic_fluent_arrow_right_20_regular", bundle: .module)
                        .resizable()
                        .renderingMode(.template)
                        .aspectRatio(contentMode: .fit)
                }
            }
            
            if parentSplit.gridColumns > 1 {
                Divider()
                
                Button(role: .destructive, action: {
                    document.deleteGridColumn(for: selection, at: col)
                }) {
                    Label {
                        Text("Delete This Column")
                    } icon: {
                        Image("fluent-ic_fluent_delete_20_regular", bundle: .module)
                            .resizable()
                            .renderingMode(.template)
                            .aspectRatio(contentMode: .fit)
                    }
                }
            }
        }
    }
    
    private func getParentSplit(for selection: SectionSplitSelection) -> SectionSplit? {
        guard var split = document.sectionSplits[selection.sectionIndex] else { return nil }
        
        // Navigate to the parent split (drop the last path component)
        let parentPath = Array(selection.path.dropLast())
        for index in parentPath {
            guard index < split.children.count, let childSplit = split.children[index] else {
                return nil
            }
            split = childSplit
        }
        
        return split
    }
    
    private var outline: [OutlineNode] {
        let sortedSections = document.sectionSplits.sorted { lhs, rhs in
            lhs.key < rhs.key
        }
        
        // Directly return the children of each section (skip the section wrapper)
        // since the root section itself is not selectable or customizable
        return sortedSections.flatMap { entry in
            let sectionIndex = entry.key
            let split = entry.value
            return outlineNodes(for: split, sectionIndex: sectionIndex, path: [])
        }
    }
    
    private func outlineNodes(for split: SectionSplit, sectionIndex: Int, path: [Int]) -> [OutlineNode] {
        guard split.splitCount > 0 else { return [] }
        
        return (0..<split.splitCount).map { childIndex in
            let childPath = path + [childIndex]
            let childSplit = split.children[childIndex]
            let childTitle = nodeTitle(
                for: split,
                childIndex: childIndex,
                childSplit: childSplit
            )
            let isLeaf = childSplit == nil
            let componentsCount = split.childComponents[childIndex]?.count ?? 0
            let badge = isLeaf ? (componentsCount > 0 ? "\(componentsCount) item\(componentsCount == 1 ? "" : "s")" : "Empty") : splitBadge(for: childSplit)
            
            let subtitle = nodeSubtitle(
                childSplit: childSplit,
                componentsCount: componentsCount
            )
            let iconName = childSplit?.direction.icon ?? leafIconName(for: split, childIndex: childIndex)
            
            let children = childSplit.map { outlineNodes(for: $0, sectionIndex: sectionIndex, path: childPath) } ?? []
            
            return OutlineNode(
                id: outlineID(for: sectionIndex, path: childPath),
                title: childTitle,
                subtitle: subtitle,
                badge: badge,
                icon: iconName,
                selection: SectionSplitSelection(sectionIndex: sectionIndex, path: childPath),
                children: children
            )
        }
    }
    
    private func splitBadge(for split: SectionSplit?) -> String? {
        guard let split else { return nil }
        switch split.direction {
        case .horizontal:
            return "H ×\(split.splitCount)"
        case .vertical:
            return "V ×\(split.splitCount)"
        case .grid:
            return "\(split.gridRows)×\(split.gridColumns)"
        }
    }
    
    private func splitDescription(_ split: SectionSplit) -> String {
        switch split.direction {
        case .horizontal:
            return "Horizontal split into \(split.splitCount)"
        case .vertical:
            return "Vertical split into \(split.splitCount)"
        case .grid:
            return "Grid \(split.gridRows) × \(split.gridColumns)"
        }
    }
    
    private func nodeTitle(
        for parentSplit: SectionSplit,
        childIndex: Int,
        childSplit: SectionSplit?
    ) -> String {
        if let customLabel = normalizedCustomLabel(from: parentSplit, childIndex: childIndex) {
            return customLabel
        }
        
        let roleLabel = roleDescription(for: parentSplit, childIndex: childIndex)
        let typeLabel = childSplit.map { "\($0.direction.displayName) Split" } ?? "Leaf"
        return "\(roleLabel) · \(typeLabel)"
    }
    
    private func nodeSubtitle(
        childSplit: SectionSplit?,
        componentsCount: Int
    ) -> String {
        var segments: [String] = []
        if let childSplit {
            segments.append(splitDescription(childSplit))
        } else {
            segments.append(leafSummary(componentsCount))
        }
        return segments.joined(separator: " • ")
    }
    
    private func leafSummary(_ componentsCount: Int) -> String {
        if componentsCount == 0 {
            return "Leaf with no components"
        } else if componentsCount == 1 {
            return "Leaf with 1 component"
        } else {
            return "Leaf with \(componentsCount) components"
        }
    }
    
    private func normalizedCustomLabel(from split: SectionSplit, childIndex: Int) -> String? {
        guard let rawLabel = split.getLabel(forChild: childIndex)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !rawLabel.isEmpty else {
            return nil
        }
        return rawLabel
    }
    
    private func roleDescription(for split: SectionSplit, childIndex: Int) -> String {
        switch split.direction {
        case .horizontal:
            return "Column \(childIndex + 1)"
        case .vertical:
            return "Row \(childIndex + 1)"
        case .grid:
            let coordinates = split.rowColumn(for: childIndex)
            return "Cell R\(coordinates.row + 1)C\(coordinates.column + 1)"
        }
    }
    
    private func leafIconName(for parentSplit: SectionSplit, childIndex: Int) -> String {
        switch parentSplit.direction {
        case .horizontal:
            return "fluent-ic_fluent_split_horizontal_20_regular"
        case .vertical:
            return "fluent-ic_fluent_split_vertical_20_regular"
        case .grid:
            return "fluent-ic_fluent_grid_20_regular"
        }
    }
    
    private func outlineID(for sectionIndex: Int, path: [Int]) -> String {
        let pathFragment = path.map(String.init).joined(separator: "-")
        return "section-\(sectionIndex)-\(pathFragment)"
    }
    
    private func select(_ node: OutlineNode) {
        guard let selection = node.selection else { return }
        document.selectSplitSelection(selection)
    }
    
    private func toggle(_ node: OutlineNode) {
        guard !node.children.isEmpty else { return }
        withAnimation(.smooth(duration: 0.22)) {
            if expandedNodeIDs.contains(node.id) {
                expandedNodeIDs.remove(node.id)
            } else {
                expandedNodeIDs.insert(node.id)
            }
        }
    }
    
    private func expandAllNodes() {
        withAnimation(.smooth(duration: 0.22)) {
            expandedNodeIDs = collectIDs(from: outline)
        }
    }
    
    private func collapseToSections() {
        let rootIDs = outline.map(\.id)
        withAnimation(.smooth(duration: 0.22)) {
            expandedNodeIDs = Set(rootIDs)
        }
    }
    
    private func syncExpandedNodes(with nodes: [OutlineNode]) {
        let validIDs = collectIDs(from: nodes)
        expandedNodeIDs = expandedNodeIDs.intersection(validIDs)
        let rootIDs = nodes.map(\.id)
        expandedNodeIDs.formUnion(rootIDs)
    }
    
    private func collectIDs(from nodes: [OutlineNode]) -> Set<String> {
        var ids: Set<String> = []
        for node in nodes {
            ids.insert(node.id)
            ids.formUnion(collectIDs(from: node.children))
        }
        return ids
    }
    
    /// Expands all ancestor nodes for the given selection so it's visible in the hierarchy
    private func expandPathToSelection(_ selection: SectionSplitSelection?) {
        guard let selection else {
            // Selection cleared - collapse all rows
            withAnimation(.smooth(duration: 0.22)) {
                expandedNodeIDs = []
            }
            return
        }
        
        // Build all ancestor node IDs that need to be expanded
        var nodeIDsToExpand: Set<String> = []
        
        // First, add the section root ID
        let sectionID = "section-\(selection.sectionIndex)"
        nodeIDsToExpand.insert(sectionID)
        
        // Then add each ancestor path node (excluding the selected node itself)
        // For path [0, 1, 2], we need to expand:
        // - section-X-0 (parent)
        // - section-X-0-1 (parent)
        // But NOT section-X-0-1-2 (the selected node)
        for i in 0..<(selection.path.count - 1) {
            let ancestorPath = Array(selection.path.prefix(i + 1))
            let ancestorID = outlineID(for: selection.sectionIndex, path: ancestorPath)
            nodeIDsToExpand.insert(ancestorID)
        }
        
        // Collapse other paths and only expand the path to this selection
        withAnimation(.smooth(duration: 0.22)) {
            expandedNodeIDs = nodeIDsToExpand
        }
    }
}

// MARK: - Preview

/// Note: Full preview requires InvoiceDocument environment object. Use live app for testing.
#Preview("Sections Side Panel - Empty") {
    DocumentOutlinePanel()
        .environmentObject(InvoiceDocument())
        .frame(width: 300, height: 400)
        .environment(\.panelMaxHeight, 400)
}

#Preview("Sections Side Panel - Populated") {
    struct PreviewWrapper: View {
        @StateObject private var document = InvoiceDocument()
        
        var body: some View {
            DocumentOutlinePanel()
                .environmentObject(document)
                .frame(width: 300, height: 500)
                .environment(\.panelMaxHeight, 500)
                .onAppear {
                    setupMockSections()
                }
        }
        
        private func setupMockSections() {
            // Section 0: Header - horizontal split with 2 children (Logo, Invoice Title)
            var headerSplit = SectionSplit(direction: .horizontal, splitCount: 2)
            headerSplit.childLabels[0] = "Company Logo"
            headerSplit.childLabels[1] = "Invoice Title"
            document.sectionSplits[0] = headerSplit
            
            // Section 1: Body - horizontal split with 3 children (Bill To, Dates, Notes)
            var bodySplit = SectionSplit(direction: .horizontal, splitCount: 3)
            bodySplit.childLabels[0] = "Bill To"
            bodySplit.childLabels[1] = "Invoice Dates"
            bodySplit.childLabels[2] = "Notes"
            
            // Nest a vertical split inside the first child
            var billToSplit = SectionSplit(direction: .vertical, splitCount: 2)
            billToSplit.childLabels[0] = "Customer Name"
            billToSplit.childLabels[1] = "Customer Address"
            bodySplit.children[0] = billToSplit
            
            document.sectionSplits[1] = bodySplit
            
            // Section 2: Services Table - single leaf
            var servicesSplit = SectionSplit(direction: .horizontal, splitCount: 1)
            servicesSplit.childLabels[0] = "Services Table"
            document.sectionSplits[2] = servicesSplit
            
            // Section 3: Footer - horizontal split with Totals and Payment Details
            var footerSplit = SectionSplit(direction: .horizontal, splitCount: 2)
            footerSplit.childLabels[0] = "Totals"
            footerSplit.childLabels[1] = "Payment Details"
            document.sectionSplits[3] = footerSplit
        }
    }
    return PreviewWrapper()
}

// MARK: - Header Control Button with Hover Effect

private struct HeaderControlButton: View {
    let iconName: String
    let help: String
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Image(iconName, bundle: .module)
                .resizable()
                .renderingMode(.template)
                .aspectRatio(contentMode: .fit)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(isHovered ? Color.primaryText : Color.secondaryText)
                .frame(width: 26, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isHovered ? Color.white.opacity(0.1) : Color.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color.white.opacity(isHovered ? 0.2 : 0.1), lineWidth: 0.6)
                        )
                )
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .pointerStyle(.link)
        .help(help)
        .scaleEffect(isHovered ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
