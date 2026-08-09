import Foundation

/// Pure tree search used to reveal a deep-linked selection inside ``FoldPaperContainer``.
public enum FoldPaperSelectionReveal {
    /// Returns the breadcrumb path (ancestor group IDs, root to leaf's parent) needed to make one of
    /// `targetIDs` visible in `items`, or `nil` if none of the targets exist in the tree.
    public static func path(toReveal targetIDs: Set<String>, in items: [TreeItem]) -> [String]? {
        guard !targetIDs.isEmpty else { return nil }

        func search(_ nodes: [TreeItem], path: [String]) -> [String]? {
            for node in nodes {
                if targetIDs.contains(node.id) {
                    return path
                }
                if let children = node.children, !children.isEmpty,
                   let found = search(children, path: path + [node.id]) {
                    return found
                }
            }
            return nil
        }

        return search(items, path: [])
    }
}
