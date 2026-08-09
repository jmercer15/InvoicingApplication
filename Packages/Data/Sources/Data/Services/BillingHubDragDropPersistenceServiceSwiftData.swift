import Core
import PersistenceModels
import Foundation
import SwiftData

public actor BillingHubDragDropPersistenceServiceSwiftData: BillingHubDragDropPersistenceService, ModelActor {
    nonisolated public let modelContainer: ModelContainer
    nonisolated public let modelExecutor: any ModelExecutor

    public init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        let context = ModelContext(modelContainer)
        modelExecutor = DefaultSerialModelExecutor(modelContext: context)
    }

    public func applySessionStatePatches(
        _ patches: [BillingHubSessionStatePatch],
        notifyRefresh: Bool
    ) async throws {
        guard !patches.isEmpty else { return }

        let latestByID = Dictionary(patches.map { ($0.id, $0) }, uniquingKeysWith: { _, new in new })
        guard !latestByID.isEmpty else { return }
        let sessionIDs = Array(latestByID.keys)
        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate { sessionIDs.contains($0.id) }
        )
        let allMatching = try modelContext.fetch(descriptor)

        var appliedAnyChange = false
        for entity in allMatching {
            guard let patch = latestByID[entity.id],
                  let normalizedStatus = SessionStatus(normalized: patch.status) else { continue }

            if entity.status != normalizedStatus {
                entity.status = normalizedStatus
                appliedAnyChange = true
            }
            if entity.groupID != patch.groupID {
                entity.groupID = patch.groupID
                appliedAnyChange = true
            }
            if entity.groupedPosition != patch.groupedPosition {
                entity.groupedPosition = patch.groupedPosition
                appliedAnyChange = true
            }
        }

        guard appliedAnyChange else { return }

        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw PersistenceError.persistenceFailure(underlying: error)
        }

        if notifyRefresh {
            await MainActor.run {
                // UI is driven by SwiftData observation / @Query; no manual refresh broadcast.
            }
        }
    }
}
