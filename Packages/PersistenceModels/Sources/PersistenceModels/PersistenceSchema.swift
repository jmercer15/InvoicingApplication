import SwiftData

/// Canonical registry of persisted model types for container bootstrap and tests.
public enum PersistenceSchema {
    public static let appModels: [any PersistentModel.Type] = [
        Client.self,
        Business.self,
        Address.self,
        Invoice.self,
        InvoiceItem.self,
        ClientService.self,
        Payee.self,
        PlanManager.self,
        Session.self,
        TravelCharge.self,
        TravelChargeAuditLog.self,
        TravelChargeReviewItem.self,
        CreditHistoryEntry.self,
        NDISItem.self,
        RegionalPrice.self,
        ServiceAgreement.self,
        SupportLog.self,
        BulkClaimBatch.self,
        BulkClaimLine.self,
        SoleTraderCredential.self,
        BillableDraft.self,
        ClaimableLine.self,
        DraftIssue.self
    ]
}
