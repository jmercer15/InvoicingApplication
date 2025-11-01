import SwiftUI
import SharedUI
import Data
import Core

struct NDISCatalogueNavigationView: View {
    @ObservedObject var viewModel: NDISContainerViewModel
    @Binding var showingHistoricalChanges: Bool

    @State private var navigationTree: [TreeItem] = []
    @State private var selectionPath: [String] = []
    @State private var breadcrumbHeight: CGFloat = 32

    private let columns: [GridItem] = [
        GridItem(.adaptive(minimum: 260, maximum: 360), spacing: 16, alignment: .top)
    ]

    private var itemLookup: [UUID: NDISItemEntity] {
        Dictionary(uniqueKeysWithValues: viewModel.filteredItems.map { ($0.id, $0) })
    }

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

    private var breadcrumbTrail: [TreeItem] {
        var trail: [TreeItem] = []
        var level = navigationTree
        for id in selectionPath {
            guard let node = level.first(where: { $0.id == id }) else { break }
            trail.append(node)
            level = node.children ?? []
        }
        return trail
    }

    var body: some View {
        VStack(spacing: 0) {
            breadcrumbView

            if navigationTree.isEmpty {
                EmptyStateView(
                    icon: "list.bullet.clipboard",
                    title: "No NDIS Items Found",
                    message: "Try adjusting your search or filter criteria."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color("Background", bundle: .sharedUI))
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                        ForEach(currentNodes, id: \.id) { node in
                            card(for: node)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                }
                .background(Color.clear)
            }
        }
        .searchable(text: $viewModel.searchText)
        .searchToolbarBehavior(.automatic)
        .background(Color("Background", bundle: .sharedUI).ignoresSafeArea())
        .onAppear(perform: rebuildNavigationTree)
        .onChange(of: viewModel.filteredItems) { _, _ in
            rebuildNavigationTree()
        }
        .onChange(of: viewModel.selectedCategoryId) { _, _ in rebuildNavigationTree() }
        .onChange(of: viewModel.selectedRegistrationGroup) { _, _ in rebuildNavigationTree() }
        .onChange(of: viewModel.quoteFilter) { _, _ in rebuildNavigationTree() }
        .onChange(of: viewModel.sortOrder) { _, _ in rebuildNavigationTree() }
        .onChange(of: viewModel.currentSelectedFeatures) { _, _ in rebuildNavigationTree() }
        .onChange(of: viewModel.currentSelectedUnits) { _, _ in rebuildNavigationTree() }
        .onChange(of: viewModel.showHistoricalItems) { _, _ in rebuildNavigationTree() }
        .onChange(of: viewModel.selectedItem?.id) { _, newValue in
            guard let id = newValue else { return }
            syncSelectionPath(with: id)
        }
        .animation(.easeInOut(duration: 0.25), value: navigationTree.count)
        .animation(.easeInOut(duration: 0.25), value: selectionPath)
    }

    @ViewBuilder
    private func card(for node: TreeItem) -> some View {
        if let children = node.children, !children.isEmpty {
            NDISCatalogueNavigationNodeCard(
                node: node,
                level: selectionPath.count,
                count: descendantCount(for: node)
            ) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    selectionPath.append(node.id)
                }
            }
        } else if let entityId = node.entityId, let uuid = UUID(uuidString: entityId), let item = itemLookup[uuid] {
            NDISCatalogueCard(
                item: item,
                isSelected: viewModel.selectedItem?.id == item.id,
                onSelect: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        viewModel.selectedItem = item
                    }
                }
            )
            .contextMenu {
                Button("View details") {
                    viewModel.selectedItem = item
                }

                if !item.isCurrent {
                    Button("Show historical context") {
                        showingHistoricalChanges = true
                    }
                }
            }
        }
    }

    private var breadcrumbView: some View {
        HStack(alignment: .top, spacing: 8) {
            if !selectionPath.isEmpty {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.accentColor.opacity(0.25))
                    .frame(width: 42, height: breadcrumbHeight)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.accentColor.opacity(0.45), lineWidth: 1)
                    )
                    .overlay(
                        Image(systemName: "chevron.backward")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(.accentColor)
                    )
                    .shadow(color: Color.accentColor.opacity(0.2), radius: 3, x: 0, y: 1)
                    .onTapGesture { goBack() }
                    .animation(.easeInOut(duration: 0.2), value: selectionPath)
                    .appInteractiveCursor()
            }

            VStack(alignment: .leading, spacing: 0) {
                breadcrumbSegments
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .onAppear { breadcrumbHeight = geometry.size.height }
                        .onChange(of: geometry.size.height) { _, newHeight in
                            breadcrumbHeight = newHeight
                        }
                }
            )
        }
        .padding(.horizontal, 24)
        .padding(.top, 18)
    }

    private var breadcrumbSegments: some View {
        let trail = breadcrumbTrail
        let nodes: [TreeItem?] = [nil] + trail.map { Optional($0) }

        return ForEach(Array(nodes.enumerated()), id: \.offset) { index, node in
            Button {
                crumbTapped(at: index)
            } label: {
                HStack(spacing: 12) {
                    Text(node?.title ?? "All Items")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    Text("\(nodeCount(for: node))")
                        .font(.system(.caption2, design: .rounded).weight(.semibold))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 14)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(breadcrumbBackground(for: node))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.primary.opacity(0.12), lineWidth: 0.6)
                )
                .padding(.trailing, CGFloat(index) * 14)
            }
            .buttonStyle(.plain)
            .appInteractiveCursor()
            .animation(.easeInOut(duration: 0.2), value: selectionPath)
        }
    }

    private func nodeCount(for node: TreeItem?) -> Int {
        if let node { return descendantCount(for: node) }
        return navigationTree.reduce(0) { $0 + descendantCount(for: $1) }
    }

    private func breadcrumbBackground(for node: TreeItem?) -> Color {
        guard let node else { return Color.primary.opacity(0.06) }
        if node.id.hasPrefix("category_") { return Color.purple.opacity(0.15) }
        if node.id.hasPrefix("group_") { return Color.indigo.opacity(0.15) }
        return Color.primary.opacity(0.08)
    }

    private func goBack() {
        guard !selectionPath.isEmpty else { return }
        selectionPath.removeLast()
    }

    private func crumbTapped(at index: Int) {
        if index == 0 {
            selectionPath = []
        } else {
            selectionPath = Array(selectionPath.prefix(index))
        }
    }

    private func rebuildNavigationTree() {
        navigationTree = makeNavigationTree(from: viewModel.filteredItems)
        pruneSelectionPath()
        if let selectedId = viewModel.selectedItem?.id {
            syncSelectionPath(with: selectedId)
        }
    }

    private func pruneSelectionPath() {
        var validPath: [String] = []
        var level = navigationTree
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
        guard let path = pathToItem(with: itemId, in: navigationTree) else { return }
        if selectionPath != path {
            selectionPath = path
        }
    }

    private func pathToItem(with id: UUID, in nodes: [TreeItem], currentPath: [String] = []) -> [String]? {
        for node in nodes {
            var updatedPath = currentPath
            if let children = node.children, !children.isEmpty {
                updatedPath.append(node.id)
                if let path = pathToItem(with: id, in: children, currentPath: updatedPath) {
                    return path
                }
                updatedPath.removeLast()
            } else if let entityId = node.entityId, let uuid = UUID(uuidString: entityId), uuid == id {
                return currentPath
            }
        }
        return nil
    }

    private func descendantCount(for node: TreeItem) -> Int {
        if let children = node.children, !children.isEmpty {
            return children.reduce(0) { $0 + descendantCount(for: $1) }
        }
        return node.entityId == nil ? 0 : 1
    }

    private func makeNavigationTree(from items: [NDISItemEntity]) -> [TreeItem] {
        var result: [TreeItem] = []

        let groupedByCategory = Dictionary(grouping: items) { item in
            item.category?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? item.category! : "Uncategorized"
        }

        for (category, categoryItems) in groupedByCategory.sorted(by: { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }) {
            let groupedByRegistration = Dictionary(grouping: categoryItems) { item in
                item.registrationGroup?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? item.registrationGroup! : "No Group"
            }

            var categoryChildren: [TreeItem] = []
            for (group, groupItems) in groupedByRegistration.sorted(by: { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }) {
                let sortedItems = groupItems.sorted { lhs, rhs in
                    lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }

                let itemChildren = sortedItems.map { item -> TreeItem in
                    TreeItem(
                        id: "ndis_item_\(item.id.uuidString)",
                        title: item.name,
                        subtitle: item.itemNumber,
                        children: nil,
                        entityId: item.id.uuidString,
                        entityType: "ndisItem"
                    )
                }

                categoryChildren.append(
                    TreeItem(
                        id: "group_\(category)_\(group)",
                        title: group,
                        subtitle: "\(groupItems.count) \(groupItems.count == 1 ? "item" : "items")",
                        children: itemChildren
                    )
                )
            }

            result.append(
                TreeItem(
                    id: "category_\(category)",
                    title: category,
                    subtitle: "\(categoryItems.count) \(categoryItems.count == 1 ? "item" : "items")",
                    children: categoryChildren
                )
            )
        }

        return result
    }
}

private struct NDISCatalogueNavigationNodeCard: View {
    let node: TreeItem
    let level: Int
    let count: Int
    let onSelect: () -> Void

    private var iconName: String {
        if node.id.hasPrefix("group_") { return "square.stack.3d.forward.dottedline" }
        return "square.grid.2x2"
    }

    private var tint: Color {
        if node.id.hasPrefix("group_") { return Color.indigo }
        return Color.purple
    }

    private var subtitle: String {
        if let subtitle = node.subtitle, !subtitle.isEmpty {
            return subtitle
        }
        return "\(count) \(count == 1 ? "item" : "items")"
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 10) {
                    Circle()
                        .fill(tint.opacity(0.16))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: iconName)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(tint)
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(node.title)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .lineLimit(2)

                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer(minLength: 0)

                HStack {
                    Label("Browse \(count) \(count == 1 ? "item" : "items")", systemImage: "rectangle.3.group")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(tint)
                        .labelStyle(.titleAndIcon)

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(tint.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(tint.opacity(0.3), lineWidth: 1)
                    )
            )
            .shadow(color: tint.opacity(0.2), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens \(node.title)")
    }
}

private struct NDISCatalogueCard: View {
    let item: NDISItemEntity
    let isSelected: Bool
    let onSelect: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private enum PricingState {
        case national(Double)
        case regional(Double, String)
        case quoteRequired
        case unavailable
    }

    private var pricingState: PricingState {
        if let nationalPrice = item.regionalPrices.first(where: { ($0.regionIdentifier ?? "").uppercased() == "NATIONAL" })?.amount {
            return .national(nationalPrice)
        }

        let meaningfulPrices = item.regionalPrices.filter { ($0.regionIdentifier?.isEmpty == false) && $0.amount > 0 }
        let fallbackPrices = item.regionalPrices.filter { $0.amount > 0 }

        if let price = (meaningfulPrices.isEmpty ? fallbackPrices : meaningfulPrices)
            .min(by: { $0.amount < $1.amount }) {
            let region = (price.regionIdentifier?.isEmpty == false) ? price.regionIdentifier! : "Regional"
            return .regional(price.amount, region)
        }

        if item.quoteRequired == true {
            return .quoteRequired
        }

        return .unavailable
    }

    private var priceText: String {
        switch pricingState {
        case .national(let amount):
            return NumberFormatter.currency.string(from: NSNumber(value: amount))
                ?? "$\(String(format: "%.2f", amount))"
        case .regional(let amount, let region):
            let formatted = NumberFormatter.currency.string(from: NSNumber(value: amount))
                ?? "$\(String(format: "%.2f", amount))"
            return "\(region): \(formatted)"
        case .quoteRequired:
            return "Quote Required"
        case .unavailable:
            return "Pricing Unavailable"
        }
    }

    private var priceIcon: String {
        switch pricingState {
        case .national, .regional:
            return "dollarsign.circle"
        case .quoteRequired:
            return "doc.text.magnifyingglass"
        case .unavailable:
            return "questionmark.circle"
        }
    }

    private var priceColor: Color {
        switch pricingState {
        case .national, .regional:
            return Color("Primary", bundle: .sharedUI)
        case .quoteRequired:
            return Color("Orange", bundle: .sharedUI)
        case .unavailable:
            return Color("TextSecondary", bundle: .sharedUI)
        }
    }

    private var subtitleColor: Color {
        Color("TextSecondary", bundle: .sharedUI)
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    Text(item.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)

                    Spacer(minLength: 0)

                    if !item.isCurrent {
                        chip(text: "Historical", icon: "clock.arrow.circlepath", tint: Color("Orange", bundle: .sharedUI))
                    }
                }

                Text(item.itemNumber)
                    .font(.subheadline)
                    .foregroundColor(subtitleColor)

                Spacer(minLength: 0)

                Divider()
                    .padding(.vertical, 4)

                HStack(alignment: .center) {
                    Label(priceText, systemImage: priceIcon)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(priceColor)
                        .labelStyle(.titleAndIcon)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(subtitleColor.opacity(0.7))
                }

            }
        }
        .buttonStyle(
            NDISCatalogueCardButtonStyle(
                isSelected: isSelected,
                colorScheme: colorScheme
            )
        )
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func chip(text: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.caption2.weight(.semibold))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(tint.opacity(colorScheme == .dark ? 0.2 : 0.12))
        .foregroundColor(colorScheme == .dark ? tint.opacity(0.9) : tint)
        .clipShape(Capsule())
    }
}

private struct NDISCatalogueCardButtonStyle: ButtonStyle {
    let isSelected: Bool
    let colorScheme: ColorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(20)
            .frame(maxWidth: .infinity, minHeight: 160, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(backgroundColor(isPressed: configuration.isPressed))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(borderColor(isPressed: configuration.isPressed), lineWidth: isSelected ? 2 : 1)
            )
            .shadow(color: shadowColor(isPressed: configuration.isPressed), radius: isSelected ? 10 : 6, x: 0, y: isSelected ? 6 : 3)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: configuration.isPressed)
            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: isSelected)
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        if isSelected {
            return Color.accentColor.opacity(isPressed ? 0.30 : 0.22)
        }

        switch colorScheme {
        case .dark:
            return Color.white.opacity(isPressed ? 0.08 : 0.12)
        default:
            return Color.white.opacity(isPressed ? 0.95 : 1.0)
        }
    }

    private func borderColor(isPressed: Bool) -> Color {
        if isSelected {
            return Color.accentColor
        }

        switch colorScheme {
        case .dark:
            return Color.white.opacity(isPressed ? 0.45 : 0.25)
        default:
            return Color.black.opacity(isPressed ? 0.2 : 0.12)
        }
    }

    private func shadowColor(isPressed: Bool) -> Color {
        if isSelected {
            return Color.accentColor.opacity(0.32)
        }

        switch colorScheme {
        case .dark:
            return Color.black.opacity(isPressed ? 0.7 : 0.5)
        default:
            return Color.black.opacity(isPressed ? 0.18 : 0.08)
        }
    }
}
