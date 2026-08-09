import Core
import Foundation

final class InvoiceLineItem {
    var id: UUID
    var sortOrder: Int
    var itemDescription: String
    var serviceDate: Date
    var itemCode: String = ""
    var quantity: Decimal
    var unit: String = ""
    var unitPrice: Decimal
    var taxRate: Decimal
    var gstCode: String = ""
    var claimType: NDISClaimType?
    var sessionID: UUID?
    var clientServiceID: UUID?

    var invoice: InvoiceDocument?

    init(
        id: UUID = UUID(),
        sortOrder: Int = 0,
        itemDescription: String = "",
        serviceDate: Date = .now,
        itemCode: String = "",
        quantity: Decimal = 1,
        unit: String = "",
        unitPrice: Decimal = 0,
        taxRate: Decimal = 0,
        gstCode: String = "",
        claimType: NDISClaimType? = nil,
        sessionID: UUID? = nil,
        clientServiceID: UUID? = nil
    ) {
        self.id = id
        self.sortOrder = sortOrder
        self.itemDescription = itemDescription
        self.serviceDate = serviceDate
        self.itemCode = itemCode
        self.quantity = quantity
        self.unit = unit
        self.unitPrice = unitPrice
        self.taxRate = taxRate
        self.gstCode = gstCode
        self.claimType = claimType
        self.sessionID = sessionID
        self.clientServiceID = clientServiceID
    }

    var lineSubtotal: Decimal {
        InvoiceCalculations.lineSubtotal(quantity: quantity, unitPrice: unitPrice)
    }

    var lineTax: Decimal {
        InvoiceCalculations.lineTax(subtotal: lineSubtotal, taxRate: taxRate)
    }

    var lineTotal: Decimal {
        InvoiceCalculations.lineTotal(subtotal: lineSubtotal, taxRate: taxRate)
    }

    var calculationInput: InvoiceCalculations.LineItemInput {
        InvoiceCalculations.LineItemInput(
            quantity: quantity,
            unitPrice: unitPrice,
            taxRate: taxRate
        )
    }
}
