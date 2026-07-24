import SwiftUI
import SharedUI

struct NDISCatalogueBreadcrumbBar: View {
    @Binding var selectionPath: [String]
    let navigationTree: [NDISCatalogueTreeNode]

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
        let nodes: [NDISCatalogueTreeNode?] = [nil] + breadcrumbTrail.map { Optional($0) }

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

    private var breadcrumbTrail: [NDISCatalogueTreeNode] {
        var trail: [NDISCatalogueTreeNode] = []
        var level = navigationTree
        for id in selectionPath {
            guard let node = level.first(where: { $0.id == id }) else { break }
            trail.append(node)
            level = node.children ?? []
        }
        return trail
    }

    private func nodeCount(for node: NDISCatalogueTreeNode?) -> Int {
        if let node { return node.descendantCount }
        return navigationTree.reduce(0) { $0 + $1.descendantCount }
    }

    private func breadcrumbBackground(for node: NDISCatalogueTreeNode?) -> Color {
        guard let node else { return StyleGuide.Colors.text.opacity(StyleGuide.Opacity.faint) }
        if node.id.hasPrefix("category_") { return ColorSystem.Navigation.categoryTint.opacity(StyleGuide.Opacity.medium) }
        if node.id.hasPrefix("group_") { return ColorSystem.Navigation.groupTint.opacity(StyleGuide.Opacity.medium) }
        return StyleGuide.Colors.text.opacity(StyleGuide.Opacity.light)
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
}
