import SwiftData

public enum PersistenceSchema {
    public static let appModels: [any PersistentModel.Type] = [
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
        TravelChargeAuditLogEntity.self,
        TravelChargeReviewItemEntity.self,
        CreditHistoryEntryEntity.self,
        NDISItemEntity.self,
        RegionalPriceEntity.self,
        ServiceAgreementEntity.self,
        SupportLogEntity.self,
        BulkClaimBatchEntity.self,
        BulkClaimLineEntity.self,
        SoleTraderCredentialEntity.self
    ]

    public static func appSchema() -> Schema {
        Schema(appModels)
    }
}
