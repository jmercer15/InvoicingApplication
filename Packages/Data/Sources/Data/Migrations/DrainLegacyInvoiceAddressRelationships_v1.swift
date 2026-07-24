import Core
import Foundation
import SwiftData

/// Drains legacy invoice address relationships into value snapshots and clears the old links.
public enum DrainLegacyInvoiceAddressRelationships_v1 {
    public static func execute(modelContext: ModelContext) throws {
        let invoices = try modelContext.fetch(FetchDescriptor<Invoice>())
        var didChangeAnyInvoice = false

        for invoice in invoices {
            var didChangeInvoice = false

            if invoice.businessAddressSnapshot == nil,
               let snapshot = snapshotAddress(from: invoice.businessAddress) {
                invoice.businessAddressSnapshot = snapshot
                didChangeInvoice = true
            }
            if invoice.businessAddress != nil {
                invoice.businessAddress = nil
                didChangeInvoice = true
            }

            if invoice.clientAddressSnapshot == nil,
               let snapshot = snapshotAddress(from: invoice.clientAddress) {
                invoice.clientAddressSnapshot = snapshot
                didChangeInvoice = true
            }
            if invoice.clientAddress != nil {
                invoice.clientAddress = nil
                didChangeInvoice = true
            }

            if invoice.billToAddressSnapshot == nil,
               let snapshot = snapshotAddress(from: invoice.billToAddress) {
                invoice.billToAddressSnapshot = snapshot
                didChangeInvoice = true
            }
            if invoice.billToAddress != nil {
                invoice.billToAddress = nil
                didChangeInvoice = true
            }

            if invoice.payeeAddressSnapshot == nil,
               let snapshot = snapshotAddress(from: invoice.payeeAddress) {
                invoice.payeeAddressSnapshot = snapshot
                didChangeInvoice = true
            }
            if invoice.payeeAddress != nil {
                invoice.payeeAddress = nil
                didChangeInvoice = true
            }

            if didChangeInvoice {
                didChangeAnyInvoice = true
            }
        }

        if didChangeAnyInvoice {
            try modelContext.save()
        }
    }

    public static func rollback(modelContext _: ModelContext) throws {}

    private static func snapshotAddress(from sourceAddress: Address?) -> AddressSnapshot? {
        guard let sourceAddress else { return nil }
        return AddressSnapshot(sourceAddress)
    }
}
