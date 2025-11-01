//
//  ModelContainerHelper.swift
//  InvoicingApplication
//
//  Created by AI Assistant on 21/7/2025.
//

import Foundation
import SwiftData
import Data

/// Helper class for creating ModelContainer instances with all required entities
public struct ModelContainerHelper {
    
    /// All entities that need to be included in the ModelContainer
    static let allEntities: [any PersistentModel.Type] = [
        ClientEntity.self,
        BusinessEntity.self,
        AddressEntity.self,
        InvoiceEntity.self,
        InvoiceItemEntity.self,
        ClientServiceEntity.self,
        PayeeEntity.self,
        PlanManagerEntity.self,
        SessionEntity.self,
        TravelChargeEntity.self,
        TravelChargeAuditLog.self,
        TravelChargeReviewItem.self,
        CreditHistoryEntryEntity.self,
        NDISItemEntity.self,
        RegionalPriceEntity.self
    ]
    
    /// Creates a ModelContainer with all required entities
    /// - Returns: A configured ModelContainer instance
    /// - Throws: ModelContainer creation errors
    public static func createModelContainer() throws -> ModelContainer {
        return try ModelContainer(for: ClientEntity.self, BusinessEntity.self, AddressEntity.self, InvoiceEntity.self, InvoiceItemEntity.self, ClientServiceEntity.self, PayeeEntity.self, PlanManagerEntity.self, SessionEntity.self, TravelChargeEntity.self, TravelChargeAuditLog.self, TravelChargeReviewItem.self, CreditHistoryEntryEntity.self, NDISItemEntity.self, RegionalPriceEntity.self)
    }
    
    /// Creates a ModelContainer with all required entities (non-throwing version)
    /// - Returns: A configured ModelContainer instance, or nil if creation fails
    static func createModelContainerSafely() -> ModelContainer? {
        return try? ModelContainer(for: ClientEntity.self, BusinessEntity.self, AddressEntity.self, InvoiceEntity.self, InvoiceItemEntity.self, ClientServiceEntity.self, PayeeEntity.self, PlanManagerEntity.self, SessionEntity.self, TravelChargeEntity.self, TravelChargeAuditLog.self, TravelChargeReviewItem.self, CreditHistoryEntryEntity.self, NDISItemEntity.self, RegionalPriceEntity.self)
    }
}
