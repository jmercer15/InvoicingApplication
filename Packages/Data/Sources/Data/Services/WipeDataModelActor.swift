//
//  WipeDataModelActor.swift
//  Data
//

import Core
import Foundation
import SwiftData

/// Dedicated @ModelActor for the wipeAllData operation.
public actor WipeDataModelActor: ModelActor {
    nonisolated public let modelContainer: ModelContainer
    nonisolated public let modelExecutor: any ModelExecutor

    public init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        let context = ModelContext(modelContainer)
        modelExecutor = DefaultSerialModelExecutor(modelContext: context)
    }

    public func wipeAll() throws -> (totalDeleted: Int, deletedByEntity: [String: Int]) {
        var deletedCounts: [String: Int] = [:]
        var totalDeleted = 0

        // Helper to delete and count
        func deleteAndCount<T: PersistentModel>(_ modelType: T.Type, name: String) throws {
            let descriptor = FetchDescriptor<T>()
            let count = try modelContext.fetchCount(descriptor)
            if count > 0 {
                try modelContext.delete(model: modelType)
                deletedCounts[name] = count
                totalDeleted += count
            }
        }

        // Delete in order to respect potential relationships (leaves first)
        try deleteAndCount(InvoiceItem.self, name: "InvoiceItem")
        try deleteAndCount(BulkClaimLine.self, name: "BulkClaimLine")
        try deleteAndCount(BulkClaimBatch.self, name: "BulkClaimBatch")
        try deleteAndCount(Invoice.self, name: "Invoice")
        try deleteAndCount(ServiceAgreement.self, name: "ServiceAgreement")
        try deleteAndCount(SupportLog.self, name: "SupportLog")
        try deleteAndCount(Session.self, name: "Session")
        try deleteAndCount(ClientService.self, name: "ClientService")
        try deleteAndCount(CreditHistoryEntry.self, name: "CreditHistory")
        try deleteAndCount(Client.self, name: "Client")
        try deleteAndCount(Payee.self, name: "Payee")
        try deleteAndCount(PlanManager.self, name: "PlanManager")
        try deleteAndCount(RegionalPrice.self, name: "RegionalPrice")
        try deleteAndCount(NDISItem.self, name: "NDISItem")
        try deleteAndCount(TravelCharge.self, name: "TravelCharge")
        try deleteAndCount(TravelChargeReviewItem.self, name: "TravelChargeReviewItem")
        try deleteAndCount(SoleTraderCredential.self, name: "SoleTraderCredential")
        try deleteAndCount(Business.self, name: "Business")
        try deleteAndCount(Address.self, name: "Address")

        try modelContext.save()

        return (totalDeleted: totalDeleted, deletedByEntity: deletedCounts)
    }
}
