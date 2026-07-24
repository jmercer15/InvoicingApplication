import Foundation

struct AllDataImportPayload {
    enum EntityName: String, CaseIterable {
        case address = "Address"
        case payee = "Payee"
        case planManager = "PlanManager"
        case ndisItem = "NDISItem"
        case business = "Business"
        case client = "Client"
        case clientService = "ClientService"
        case invoice = "Invoice"
        case invoiceItem = "InvoiceItem"
        case serviceAgreement = "ServiceAgreement"
        case session = "Session"
        case supportLog = "SupportLog"
        case travelCharge = "TravelCharge"
        case travelChargeReviewItem = "TravelChargeReviewItem"
        case travelChargeAuditLog = "TravelChargeAuditLog"
        case regionalPrice = "RegionalPrice"
        case creditHistoryEntry = "CreditHistoryEntry"
        case bulkClaimBatch = "BulkClaimBatch"
        case bulkClaimLine = "BulkClaimLine"
    }

    private let json: [String: Any]

    init(data: Data) throws {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "ImportError", code: 100, userInfo: [
                NSLocalizedDescriptionKey: "Invalid JSON Format"
            ])
        }
        self.json = json
    }

    var sortedKeys: [String] {
        Array(json.keys).sorted()
    }

    func rows(for entityName: EntityName) -> [[String: Any]]? {
        json[entityName.rawValue] as? [[String: Any]]
    }
}
