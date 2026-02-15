import Foundation

/// Domain model for a credit history entry
public struct CreditHistoryEntry: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let clientId: UUID
    public var date: Date
    public var amount: Double
    public var type: String?
    public var notes: String?
    public var relatedInvoiceNumber: String?
    
    public init(
        id: UUID,
        clientId: UUID,
        date: Date = Date(),
        amount: Double = 0.0,
        type: String? = nil,
        notes: String? = nil,
        relatedInvoiceNumber: String? = nil
    ) {
        self.id = id
        self.clientId = clientId
        self.date = date
        self.amount = amount
        self.type = type
        self.notes = notes
        self.relatedInvoiceNumber = relatedInvoiceNumber
    }
}
