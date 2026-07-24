import SwiftUI
import Core
import SharedUI

struct RelationshipsBreadcrumbBar: View {
    @Binding var selectionPath: [String]
    let navigationTree: [TreeItem]
    let descendantCountLookup: [String: Int]

    var body: some View {
        AppBreadcrumbBar(
            showsBackButton: !selectionPath.isEmpty,
            onBack: goBack
        ) {
            breadcrumbSegments
        }
        .animation(.easeInOut(duration: StyleGuide.Animations.durationMedium - StyleGuide.Animations.durationShort), value: selectionPath)
    }

    private var breadcrumbSegments: some View {
        let nodes: [TreeItem?] = [nil] + breadcrumbTrail.map { Optional($0) }

        return ForEach(Array(nodes.enumerated()), id: \.offset) { index, node in
            AppBreadcrumbSegmentButton(
                title: node?.title ?? "All Items",
                count: nodeCount(for: node),
                indentLevel: index,
                backgroundColor: breadcrumbBackground(for: node)
            ) {
                crumbTapped(at: index)
            }
        }
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

    private func nodeCount(for node: TreeItem?) -> Int {
        if let node { return descendantCount(for: node) }
        return navigationTree.reduce(0) { $0 + descendantCount(for: $1) }
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

    private func breadcrumbBackground(for node: TreeItem?) -> Color {
        guard let node else { return Color.primary.opacity(StyleGuide.Opacity.faint) }
        if node.id.hasPrefix("section_clients") { return Color.clientDefault.opacity(StyleGuide.Opacity.strong - 0.15) }
        if node.id.hasPrefix("section_payees") { return Color.payeeDefault.opacity(StyleGuide.Opacity.strong - 0.15) }
        if node.id.hasPrefix("section_planmanagers") { return Color.planManagerDefault.opacity(StyleGuide.Opacity.strong - 0.15) }
        return Color.primary.opacity(StyleGuide.Opacity.faint + 0.02)
    }

    private func goBack() {
        if !selectionPath.isEmpty {
            selectionPath.removeLast()
        }
    }

    private func crumbTapped(at index: Int) {
        if index == 0 {
            selectionPath = []
        } else {
            selectionPath = Array(selectionPath.prefix(index))
        }
    }
}
