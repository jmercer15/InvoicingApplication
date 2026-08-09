import SwiftUI

/// Resolves a SwiftData entity from a live `@Query` list when selection changes.
struct RelationshipResolvedDetailView<Entity: Identifiable, Revision: Equatable, EmptyState: View, Content: View>: View
where Entity.ID == UUID {
    let objectID: UUID
    let entities: [Entity]
    @Binding var resolved: Entity?
    let revision: Revision
    let emptyState: EmptyState
    let content: (Entity) -> Content

    /// Tracks which revision `resolved` belongs to. Prevents touching invalidated
    /// models after CloudKit HistoryExpired while the resolve task is still pending.
    @State private var resolvedRevision: Revision?

    init(
        objectID: UUID,
        entities: [Entity],
        resolved: Binding<Entity?>,
        revision: Revision,
        emptyState: EmptyState,
        @ViewBuilder content: @escaping (Entity) -> Content
    ) {
        self.objectID = objectID
        self.entities = entities
        self._resolved = resolved
        self.revision = revision
        self.emptyState = emptyState
        self.content = content
    }

    var body: some View {
        Group {
            if let entity = resolved, resolvedRevision == revision, entity.id == objectID {
                content(entity)
            } else {
                emptyState
            }
        }
        .task(id: ResolveTaskId(id: objectID, revision: revision)) {
            resolved = nil
            resolvedRevision = nil
            let match = entities.first { $0.id == objectID }
            resolved = match
            resolvedRevision = revision
        }
    }

    private struct ResolveTaskId: Equatable {
        let id: UUID
        let revision: Revision
    }
}
