#if DEBUG
import Data
import DataInterfaces
import SwiftData
import SwiftUI

@MainActor
private final class PreviewRelationshipDeleter: ClientRelationshipDeleting {
    func deleteClient(id: UUID, deleteSessions: Bool) async throws {}
    func deletePayee(id: UUID) async throws {}
    func deletePlanManager(id: UUID) async throws {}
}

@MainActor
private enum RelationshipsPreviewSupport {
    static func makeContainer() -> ModelContainer {
        try! ModelContainerFactory.makeInMemoryContainer()
    }

    static func makeViewModel() -> RelationshipsContainerViewModel {
        RelationshipsContainerViewModel(relationshipDeleter: PreviewRelationshipDeleter())
    }
}

#Preview("Relationships Content") {
    let container = RelationshipsPreviewSupport.makeContainer()
    let viewModel = RelationshipsPreviewSupport.makeViewModel()

    NavigationStack {
        RelationshipsContentColumn(viewModel: viewModel)
    }
    .modelContainer(container)
    .frame(width: 760, height: 520)
}

#Preview("Relationships Detail Empty") {
    let container = RelationshipsPreviewSupport.makeContainer()
    let viewModel = RelationshipsPreviewSupport.makeViewModel()

    RelationshipsDetailColumn(viewModel: viewModel)
        .modelContainer(container)
        .frame(width: 520, height: 420)
}
#endif
