import Core
import PersistenceModels
import DataInterfaces
import Foundation
import SwiftData

extension ReferenceDataWorkflowActor {
    public func fetchAllNDISItemUUIDs() throws -> [UUID] {
        var descriptor = FetchDescriptor<NDISItem>(sortBy: [SortDescriptor(\.itemNumber)])
        descriptor.propertiesToFetch = [\.itemNumber]
        return try modelContext.fetch(descriptor).map(\.id)
    }

    public func fetchAllPayeeUUIDs() throws -> [UUID] {
        var descriptor = FetchDescriptor<Payee>(sortBy: [SortDescriptor(\.fullName)])
        descriptor.propertiesToFetch = [\.fullName]
        return try modelContext.fetch(descriptor).map(\.id)
    }

    public func fetchAllPlanManagerUUIDs() throws -> [UUID] {
        var descriptor = FetchDescriptor<PlanManager>(sortBy: [SortDescriptor(\.name)])
        descriptor.propertiesToFetch = [\.name]
        return try modelContext.fetch(descriptor).map(\.id)
    }

    public func fetchTravelChargeBootstrapData() throws -> TravelChargeBootstrapData {
        let sessionDescriptor = FetchDescriptor<Session>(sortBy: [SortDescriptor(\.startTime)])
        let sessions = try modelContext.fetch(sessionDescriptor).map(SessionSnapshot.init)

        var businessDescriptor = FetchDescriptor<Business>(sortBy: [SortDescriptor(\.name)])
        businessDescriptor.fetchLimit = 1
        let primaryBusiness = try modelContext.fetch(businessDescriptor).first.map(BusinessSnapshot.init)

        return TravelChargeBootstrapData(sessions: sessions, primaryBusiness: primaryBusiness)
    }
}
