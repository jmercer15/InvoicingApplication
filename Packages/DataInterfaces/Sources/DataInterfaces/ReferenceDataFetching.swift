import Foundation
import SwiftData

/// Background reference-data reads for pickers, catalogues, and relationship detail screens.
///
/// Implemented by `ReferenceDataWorkflowActor` in the Data package.
///
/// ## Payload policy
/// Prefer domain UUIDs and Core `*Snapshot` DTOs in new methods. Methods returning
/// `[PersistentIdentifier]` remain for `@Query` / `model(for:)` binding workflows where
/// stable SwiftData row identity is required (see `InterfacePayloadExceptions.md`).
public protocol ReferenceDataFetching: Sendable {
    // MARK: - UUID-first catalogue reads (preferred)

    func fetchAllNDISItemUUIDs() async throws -> [UUID]
    func fetchAllPayeeUUIDs() async throws -> [UUID]
    func fetchAllPlanManagerUUIDs() async throws -> [UUID]
    func fetchTravelChargeBootstrapData() async throws -> TravelChargeBootstrapData

    // MARK: - PersistentIdentifier reads (legacy @Query binding)

    func fetchAllNDISItemIDs() async throws -> [PersistentIdentifier]
    func fetchAllPayeeIDs() async throws -> [PersistentIdentifier]
    func fetchAllPlanManagerIDs() async throws -> [PersistentIdentifier]
}
