import Foundation
import Testing
import CoreTesting
import SwiftData
import Core
import PersistenceModels
import Data
@testable import Feature_Clients

@MainActor
@Suite(.tags(.integration))
struct RelationshipsContainerViewModelDeletionTests {
    private func makeContext() throws -> (ModelContainer, ModelContext) {
        try ModelContainerFactory.makeInMemoryContext()
    }

    @Test func deleteClientBlocksWhenSessionsExist() async throws {
        let (_, modelContext) = try makeContext()
        let client = Client(fullName: "Blocked Client")
        let session = Session(id: UUID())
        session.client = client
        client.sessions = [session]
        modelContext.insert(client)
        modelContext.insert(session)
        try modelContext.save()

        let viewModel = RelationshipsContainerViewModel(
            relationshipDeleter: SwiftDataClientRelationshipDeleter(modelContext: modelContext)
        )

        do {
            try await viewModel.deleteClient(client)
            Issue.record("Expected client delete to be blocked")
        } catch let error as ClientDeletionError {
            #expect(error == .hasLinkedSessions(count: 1))
        }

        #expect(try modelContext.fetch(FetchDescriptor<Client>()).count == 1)
        #expect(try modelContext.fetch(FetchDescriptor<Session>()).count == 1)
    }

    @Test func deleteClientCascadeRemovesSessionsThenClient() async throws {
        let (_, modelContext) = try makeContext()
        let client = Client(fullName: "Cascade Client")
        let firstSession = Session(id: UUID())
        let secondSession = Session(id: UUID())
        firstSession.client = client
        secondSession.client = client
        client.sessions = [firstSession, secondSession]
        modelContext.insert(client)
        modelContext.insert(firstSession)
        modelContext.insert(secondSession)
        try modelContext.save()

        let viewModel = RelationshipsContainerViewModel(
            relationshipDeleter: SwiftDataClientRelationshipDeleter(modelContext: modelContext)
        )
        try await viewModel.deleteClient(client, deleteSessions: true)

        #expect(try modelContext.fetch(FetchDescriptor<Client>()).count == 0)
        #expect(try modelContext.fetch(FetchDescriptor<Session>()).count == 0)
    }

    @Test func deleteClientWithoutSessionsRemovesClient() async throws {
        let (_, modelContext) = try makeContext()
        let client = Client(fullName: "Empty Client")
        modelContext.insert(client)
        try modelContext.save()

        let viewModel = RelationshipsContainerViewModel(
            relationshipDeleter: SwiftDataClientRelationshipDeleter(modelContext: modelContext)
        )
        try await viewModel.deleteClient(client)

        #expect(try modelContext.fetch(FetchDescriptor<Client>()).count == 0)
    }
}
