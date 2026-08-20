import Foundation

/// Hierarchical list node for fold-paper navigation containers.
public struct TreeItem: Hashable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var subtitle: String?
    public var trailingTitle: String?
    public var trailingSubtitle: String?
    public var children: [TreeItem]? = nil
    public var entityID: String?
    public var entityType: String?
    /// Optional domain state used only for row presentation (for example invoice status colour).
    public var entityState: String?

    public init(
        id: String,
        title: String,
        subtitle: String? = nil,
        trailingTitle: String? = nil,
        trailingSubtitle: String? = nil,
        children: [TreeItem]? = nil,
        entityID: String? = nil,
        entityType: String? = nil,
        entityState: String? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.trailingTitle = trailingTitle
        self.trailingSubtitle = trailingSubtitle
        self.children = children
        self.entityID = entityID
        self.entityType = entityType
        self.entityState = entityState
    }
}
