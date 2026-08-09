import Core
import PersistenceModels
import Foundation
import SwiftData
@testable import DataInterfaces

struct StubInvoiceDigesting: InvoiceDigesting, Sendable {
    let numbers: [String]

    func allInvoiceNumbers() async throws -> [String] {
        numbers
    }
}

@MainActor
final class StubClientRelationshipDeleter: ClientRelationshipDeleting {
    private(set) var deletedClientIDs: [UUID] = []
    private(set) var lastDeleteSessionsFlag: Bool?

    func deleteClient(id: UUID, deleteSessions: Bool) async throws {
        deletedClientIDs.append(id)
        lastDeleteSessionsFlag = deleteSessions
    }

    func deletePayee(id: UUID) async throws {}
    func deletePlanManager(id: UUID) async throws {}
}

struct StubReferenceDataFetching: ReferenceDataFetching, Sendable {
    let itemIDs: [PersistentIdentifier]

    func fetchAllNDISItemUUIDs() async throws -> [UUID] { [] }
    func fetchAllPayeeUUIDs() async throws -> [UUID] { [] }
    func fetchAllPlanManagerUUIDs() async throws -> [UUID] { [] }
    func fetchTravelChargeBootstrapData() async throws -> TravelChargeBootstrapData {
        TravelChargeBootstrapData(sessions: [], primaryBusiness: nil)
    }

    func fetchAllNDISItemIDs() async throws -> [PersistentIdentifier] { itemIDs }
    func fetchAllPayeeIDs() async throws -> [PersistentIdentifier] { [] }
    func fetchAllPlanManagerIDs() async throws -> [PersistentIdentifier] { [] }
}
