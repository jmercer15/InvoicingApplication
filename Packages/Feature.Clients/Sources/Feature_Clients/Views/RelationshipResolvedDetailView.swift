import SwiftUI

/// Resolves a SwiftData entity from a live `@Query` list when selection changes.
struct RelationshipResolvedDetailView<Entity: Identifiable, Revision: Equatable, Content: View>: View
where Entity.ID == UUID {
    let objectID: UUID
    let entities: [Entity]
    @Binding var resolved: Entity?
    let revision: Revision
    let emptyState: AnyView
    let content: (Entity) -> Content

    init(
        objectID: UUID,
        entities: [Entity],
        resolved: Binding<Entity?>,
        revision: Revision,
        emptyState: some View,
        @ViewBuilder content: @escaping (Entity) -> Content
    ) {
        self.objectID = objectID
        self.entities = entities
        self._resolved = resolved
        self.revision = revision
        self.emptyState = AnyView(emptyState)
        self.content = content
    }

    var body: some View {
        Group {
            if let entity = resolved, entity.id == objectID {
                content(entity)
            } else {
                emptyState
            }
        }
        .task(id: ResolveTaskId(id: objectID, revision: revision)) {
            resolved = entities.first { $0.id == objectID }
        }
    }

    private struct ResolveTaskId: Equatable {
        let id: UUID
        let revision: Revision
    }
}
