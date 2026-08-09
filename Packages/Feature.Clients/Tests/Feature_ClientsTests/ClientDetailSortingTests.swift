import Foundation
import Testing
import Core
import PersistenceModels
import SwiftData
import Data
@testable import Feature_Clients

@MainActor
@Suite(.tags(.integration))
struct ClientDetailSortingTests {
    private func makeContext() throws -> (ModelContainer, ModelContext) {
        try ModelContainerFactory.makeInMemoryContext()
    }

    @Test func sortedServicesFollowsViewModelSortOrder() throws {
        let (_, modelContext) = try makeContext()
        let viewModel = ClientDetailViewModel(
            client: Client(id: UUID(), ndisNumber: "1", fullName: "A", status: "Active"),
            modelContext: modelContext,
            isCreating: false
        )

        let therapy = ClientService(serviceName: "Therapy", unit: "hour", rate: 100)
        let transport = ClientService(serviceName: "Transport", unit: "trip", rate: 50)
        viewModel.clientServices = [transport, therapy]

        viewModel.servicesSortOrder = .nameAsc
        #expect(viewModel.sortedServices.map(\.serviceName) == ["Therapy", "Transport"])

        viewModel.servicesSortOrder = .nameDesc
        #expect(viewModel.sortedServices.map(\.serviceName) == ["Transport", "Therapy"])
    }

    @Test func sortedInvoicesFollowsViewModelSortOrder() throws {
        let viewModel = ClientDetailViewModel(
            client: Client(id: UUID(), ndisNumber: "1", fullName: "A", status: "Active"), modelContext: makeInMemoryContext(),
            isCreating: false)

        let older = Invoice(invoiceNumber: "INV-OLD")
        older.issueDate = Date(timeIntervalSince1970: 1_000)
        let newer = Invoice(invoiceNumber: "INV-NEW")
        newer.issueDate = Date(timeIntervalSince1970: 2_000)
        viewModel.relatedInvoices = [older, newer]

        viewModel.invoicesSortOrder = .dateDesc
        #expect(viewModel.sortedInvoices.map(\.invoiceNumber) == ["INV-NEW", "INV-OLD"])

        viewModel.invoicesSortOrder = .dateAsc
        #expect(viewModel.sortedInvoices.map(\.invoiceNumber) == ["INV-OLD", "INV-NEW"])
    }

    private func makeInMemoryContext() -> ModelContext {
        let container = try! ModelContainerFactory.makeInMemoryContainer()
        return ModelContext(container)
    }
}