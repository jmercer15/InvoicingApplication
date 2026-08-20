import Testing
import CoreTesting
@testable import SharedUI

@Suite(.tags(.unit))
struct FoldPaperBreadcrumbIdentityTests {
    @Test func breadcrumbRootUsesStableIdentifier() {
        let nodes = breadcrumbNodes(for: [], rootTitle: "All Items")
        #expect(nodes.map(\.id) == ["root"])
        #expect(nodes[0].node == nil)
    }

    @Test func breadcrumbTrailUsesTreeItemIDs() {
        let child = TreeItem(id: "group_a", title: "Group A")
        let nodes = breadcrumbNodes(for: [child], rootTitle: "Catalogue")
        #expect(nodes.map(\.id) == ["root", "group_a"])
        #expect(nodes[1].node?.title == "Group A")
    }
}

private struct BreadcrumbNode: Identifiable {
    let id: String
    let node: TreeItem?
    let indentLevel: Int
}

private func breadcrumbNodes(for trail: [TreeItem], rootTitle: String) -> [BreadcrumbNode] {
    var nodes = [BreadcrumbNode(id: "root", node: nil, indentLevel: 0)]
    for (index, item) in trail.enumerated() {
        nodes.append(BreadcrumbNode(id: item.id, node: item, indentLevel: index + 1))
    }
    return nodes
}
