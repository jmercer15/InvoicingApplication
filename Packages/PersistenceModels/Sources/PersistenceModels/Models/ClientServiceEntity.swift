import Foundation
import Core
import SwiftData


@Model public class ClientService {
    #Index<ClientService>([\.serviceName], [\.ndisCode], [\.isActive], [\.startDate], [\.endDate], [\.rateDecimal])
    public var id: UUID = UUID()
    public var serviceName: String = ""
    public var ndisCode: String?
    public var unit: String = ""
    /// CloudKit forbids attribute renames; physical `*Decimal` names stay stable.
    public var rateDecimal: Decimal = 0
    public var rate: Decimal {
        get { rateDecimal }
        set { rateDecimal = newValue }
    }
    public var isActive: Bool = true
    public var startDate: Date?
    public var endDate: Date?
    
    // Workflow/Billing fields
    public var isDefault: Bool = false
    public var ndisItemNumber: String?
    public var gstCode: String?
    /// When set, live NDIS billing may emit an establishment fee. `nil` means do not emit.
    public var consecutiveMonths: Int?

    public var status: String?
    @Relationship(deleteRule: .nullify, inverse: \NDISItem.clientServices) public var ndisItem: NDISItem?
    @Relationship(deleteRule: .nullify, inverse: \Client.clientServices) public var client: Client?
    @Relationship(deleteRule: .nullify, inverse: \InvoiceItem.clientService) public var invoiceItems: [InvoiceItem]?
    @Relationship(deleteRule: .cascade, inverse: \Session.clientService) public var sessions: [Session]?
    @Relationship(deleteRule: .cascade)
    public var travelCharges: [TravelCharge]?
    @Relationship(deleteRule: .nullify) public var billableDrafts: [BillableDraft]?
    public init(id: UUID = UUID(), serviceName: String, unit: String, rate: Decimal) {
        self.id = id
        self.serviceName = serviceName
        self.unit = unit
        self.rateDecimal = rate
    }

    public var clientId: UUID? { client?.id }

    /// Returns a thread-safe snapshot of this client service.
    public func snapshot() -> ClientServiceSnapshot {
        ClientServiceSnapshot(self)
    }
}
