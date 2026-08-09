import SharedUI

struct RelationshipsProjection: Sendable {
    let tree: [TreeItem]
    let counts: [String: Int]

    static let empty = RelationshipsProjection(tree: [], counts: [:])
}
