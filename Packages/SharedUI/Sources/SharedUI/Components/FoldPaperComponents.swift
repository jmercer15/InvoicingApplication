import SwiftUI

// MARK: - TreeItem Data Structure
public struct TreeItem: Hashable, Identifiable {
    public var id: String
    public var title: String
    public var subtitle: String?
    public var children: [TreeItem]? = nil
    public var entityId: String?
    public var entityType: String?

    public init(id: String, title: String, subtitle: String? = nil, children: [TreeItem]? = nil, entityId: String? = nil, entityType: String? = nil) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.children = children
        self.entityId = entityId
        self.entityType = entityType
    }
}

// MARK: - Simple List Container

public struct FoldPaperContainer: View {
    @Binding var items: [TreeItem]
    @State private var selectedItemID: String? = nil
    @State private var selectionPath: [String] = []
    let onItemTap: ((TreeItem) -> Void)?

    public init(items: Binding<[TreeItem]>, onItemTap: ((TreeItem) -> Void)? = nil) {
        self._items = items
        self.onItemTap = onItemTap
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            breadcrumbView

            List(currentItems, id: \.id) { item in
                rowView(for: item)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
            .listStyle(.plain)
            .scrollIndicators(.hidden)
        }
        .padding(.horizontal, 8)
        .animation(.easeInOut(duration: 0.2), value: selectionPath)
        .onChange(of: items) {
            pruneSelectionPath()
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

    private let breadcrumbIndent: CGFloat = 12

    private var breadcrumbView: some View {
        HStack(alignment: .top, spacing: 10) {
            if !selectionPath.isEmpty {
                Button(action: goBack) {
                    Image(systemName: "chevron.backward")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.accentColor.opacity(0.24))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.accentColor.opacity(0.5), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .shadow(color: Color.accentColor.opacity(0.16), radius: 2, x: 0, y: 1)
                .accessibilityLabel(Text("Back"))
                .appInteractiveCursor()
                .transition(.scale.combined(with: .opacity))
            }

            VStack(alignment: .leading, spacing: 0) {
                breadcrumbSegments()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 1)
        }
        .padding(.horizontal, 4)
    }

    private func parentBackground(for item: TreeItem) -> Color {
        if isTopLevelCategory(item) {
            return Color.purple.opacity(0.12)
        } else if isRegistrationGroup(item) {
            return Color.indigo.opacity(0.12)
        } else {
            return Color.primary.opacity(0.08)
        }
    }

    @ViewBuilder
    private func breadcrumbSegments() -> some View {
        let trail = breadcrumbTrail
        let nodes: [TreeItem?] = [nil] + trail.map { Optional($0) }

        ForEach(Array(nodes.enumerated()), id: \.offset) { index, node in
            let background = breadcrumbBackground(for: node)

            Button(action: { crumbTapped(at: index) }) {
                HStack(spacing: 12) {
                    breadcrumbLabel(for: node)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer(minLength: 0)

                    Text("\(entityCount(for: node))")
                        .font(.system(.caption2, design: .rounded).weight(.semibold))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(background)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.primary.opacity(0.16), lineWidth: 0.5)
                )
                .padding(.leading, CGFloat(index) * breadcrumbIndent)
            }
            .buttonStyle(.plain)
            .appInteractiveCursor()
            .help(node?.subtitle ?? node?.title ?? "All Items")
        }
    }

    private func breadcrumbLabel(for node: TreeItem?) -> Text {
        var leading = AttributedString(node?.title ?? "All Items")
        leading.font = .system(.subheadline, design: .rounded).weight(.semibold)
        leading.foregroundColor = .primary

        if let subtitle = node?.subtitle, !subtitle.isEmpty {
            var trailing = AttributedString(" • \(subtitle)")
            trailing.font = .system(.caption, design: .rounded)
            trailing.foregroundColor = .secondary
            leading += trailing
        }

        return Text(leading)
    }

    private func breadcrumbBackground(for node: TreeItem?) -> Color {
        guard let node else {
            return Color.primary.opacity(0.06)
        }
        return parentBackground(for: node)
    }

    private func entityCount(for node: TreeItem?) -> Int {
        guard let node else {
            return items.reduce(0) { $0 + entityCount(for: $1) }
        }
        return entityCount(for: node)
    }

    private func entityCount(for node: TreeItem) -> Int {
        var total = node.entityId == nil ? 0 : 1
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
    
    private func backgroundForChild(_ item: TreeItem) -> Color {
        if selectedItemID == item.id {
            return Color.accentColor.opacity(0.2)
        }
        return Color.primary.opacity(0.04)
    }
    
    private func colorFor(_ entityType: String) -> Color {
        switch entityType {
        case "client": return .green
        case "payee": return .blue
        case "planManager": return .orange
        case "invoice": return .purple
        case "ndisItem": return .cyan
        default: return .gray
        }
    }
    private func rowView(for item: TreeItem) -> some View {
        let hasChildren = (item.children?.isEmpty == false)
        let isLeafHighlighted = selectedItemID == item.id

        return Group {
            if hasChildren {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.system(.headline, design: .rounded))
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .help(item.title)

                        if let subtitle = item.subtitle, !subtitle.isEmpty {
                            Text(subtitle)
                                .font(.system(.caption, design: .rounded))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .help(subtitle)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(parentBackground(for: item))
                )
                .contentShape(RoundedRectangle(cornerRadius: 8))
                .onTapGesture {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.85)) {
                        handleSelection(of: item)
                    }
                }
            } else {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.system(.body, design: .rounded))
                            .fontWeight(.medium)
                            .foregroundColor(isLeafHighlighted ? .accentColor : .primary)
                            .lineLimit(1)
                            .help(item.title)
                            .animation(.easeInOut(duration: 0.1), value: isLeafHighlighted)

                        if let subtitle = item.subtitle, !subtitle.isEmpty {
                            Text(subtitle)
                                .font(.system(.caption, design: .rounded))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .help(subtitle)
                                .opacity(min(1.0, (isLeafHighlighted ? 0.8 : 1.0) * 2.0))
                                .animation(.easeInOut(duration: 0.1), value: isLeafHighlighted)
                        }
                    }

                    Spacer()

                    if let entityType = item.entityType {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(colorFor(entityType))
                                .frame(width: 10, height: 10)
                                .scaleEffect(isLeafHighlighted ? 1.2 : 1.0)
                                .animation(.spring(response: 0.1, dampingFraction: 0.9), value: isLeafHighlighted)

                            Text(entityType.capitalized)
                                .font(.system(.caption2, design: .rounded))
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                                .opacity(1.0)
                        }
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(backgroundForChild(item))
                        .strokeBorder(
                            isLeafHighlighted ? Color.accentColor.opacity(0.6) : Color.primary.opacity(0.2),
                            lineWidth: isLeafHighlighted ? 1.0 : 0.5
                        )
                )
                .scaleEffect(isLeafHighlighted ? 1.02 : 1.0)
                .animation(.spring(response: 0.12, dampingFraction: 0.85), value: isLeafHighlighted)
                .contentShape(RoundedRectangle(cornerRadius: 8))
                .onTapGesture {
                    withAnimation(.spring(response: 0.15, dampingFraction: 0.9)) {
                        handleSelection(of: item)
                    }
                }
            }
        }
    }

    private func handleSelection(of item: TreeItem) {
        if let children = item.children, !children.isEmpty {
            if selectionPath.last != item.id {
                selectionPath.append(item.id)
            }
            selectedItemID = nil
        } else {
            selectedItemID = item.id
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
    }

    private func crumbTapped(at index: Int) {
        if index == 0 {
            selectionPath = []
        } else {
            selectionPath = Array(selectionPath.prefix(index))
        }
        selectedItemID = nil
    }
}
