import Foundation
import SwiftData
import Core
import PersistenceModels

extension AllDataFactories {

    // MARK: - NDIS Item

    static func createNDISItem(from dict: [String: Any]) throws -> NDISItem {
        let ndisItem = NDISItem(
            id: UUID(),
            itemNumber:        dict["itemNumber"]        as? String ?? "",
            name:              dict["name"]              as? String ?? "",
            versionIdentifier: dict["versionIdentifier"] as? String ?? ""
        )
        ndisItem.isCurrent                = dict["isCurrent"]                as? Bool   ?? true
        ndisItem.category                 = dict["category"]                 as? String
        ndisItem.categoryNamePACE         = dict["categoryNamePACE"]         as? String
        ndisItem.categoryNumber           = dict["categoryNumber"]           as? String
        ndisItem.categoryNumberPACE       = dict["categoryNumberPACE"]       as? String
        ndisItem.features                 = dict["features"]                 as? String
        ndisItem.itemDescription          = dict["itemDescription"]          as? String
        ndisItem.ndiaRequestedReports     = dict["ndiaRequestedReports"]     as? Bool
        ndisItem.nonFaceToFaceProvision   = dict["nonFaceToFaceProvision"]   as? Bool
        ndisItem.providerTravel           = dict["providerTravel"]           as? Bool
        ndisItem.quoteRequired            = dict["quoteRequired"]            as? Bool
        ndisItem.registrationGroup        = dict["registrationGroup"]        as? String
        ndisItem.registrationGroupNumber  = dict["registrationGroupNumber"]  as? String
        ndisItem.shortNoticeCancellations = dict["shortNoticeCancellations"] as? Bool
        ndisItem.irregularSILSupports     = dict["irregularSILSupports"]     as? Bool
        ndisItem.status                   = dict["status"]                   as? String
        ndisItem.type                     = dict["type"]                     as? String
        ndisItem.unit                     = dict["unit"]                     as? String

        if let s = dict["effectiveStartDate"] as? String { ndisItem.effectiveStartDate = ISO8601DateFormatter().date(from: s) }
        if let s = dict["effectiveEndDate"]   as? String { ndisItem.effectiveEndDate   = ISO8601DateFormatter().date(from: s) }

        return ndisItem
    }

    static func createRegionalPrice(from dict: [String: Any], entityMapping: [String: Any]) throws -> RegionalPrice {
        let rp = RegionalPrice(id: UUID())
        rp.amount           = MoneyDecimalImport.decimal(from: dict["amount"] as? Double ?? 0.0)
        rp.regionIdentifier = dict["regionIdentifier"] as? String ?? ""

        if let id = dict["ndisItem"] as? String, let item = entityMapping[id] as? NDISItem {
            rp.ndisItem = item
        } else if let id = dict["ndisItemId"] as? String, let item = entityMapping[id] as? NDISItem {
            rp.ndisItem = item
        }

        return rp
    }

    // MARK: - Invoice

    static func createInvoice(from dict: [String: Any], entityMapping: [String: Any]) throws -> Invoice {
        let invoice = Invoice(id: UUID(), invoiceNumber: dict["invoiceNumber"] as? String ?? "")
        invoice.totalAmount   = MoneyDecimalImport.decimal(from: dict["totalAmount"]  as? Double ?? 0.0)
        invoice.taxRate       = MoneyDecimalImport.decimal(from: dict["taxRate"]      as? Double ?? 0.0)
        invoice.creditApplied = MoneyDecimalImport.decimal(from: dict["creditApplied"] as? Double ?? 0.0)
        invoice.discount      = MoneyDecimalImport.decimal(from: dict["discount"]     as? Double ?? 0.0)
        invoice.notes         = dict["notes"]        as? String
        invoice.paymentTerms  = dict["paymentTerms"] as? String
        invoice.currencyCode  = dict["currencyCode"] as? String ?? "AUD"
        invoice.businessName  = dict["businessName"] as? String
        invoice.businessABN   = dict["businessABN"] as? String
        invoice.businessEmail = dict["businessEmail"] as? String
        invoice.businessPhone = dict["businessPhone"] as? String
        invoice.clientName = dict["clientName"] as? String
        invoice.clientNDISNumber = dict["clientNDISNumber"] as? String
        invoice.clientEmail = dict["clientEmail"] as? String
        invoice.clientPhone = dict["clientPhone"] as? String
        invoice.billToName = dict["billToName"] as? String
        invoice.billToEmail = dict["billToEmail"] as? String
        invoice.bankName = dict["bankName"] as? String
        invoice.bankAccountName = dict["bankAccountName"] as? String
        invoice.bankBSB = dict["bankBSB"] as? String
        invoice.bankAccountNumber = dict["bankAccountNumber"] as? String

        if let rawAuthority = dict["billingAuthority"] as? String {
            invoice.billingAuthority = BillingAuthority(rawValue: rawAuthority)
        }
        invoice.businessAddressSnapshot = decodeBase64(
            dict["businessAddressSnapshot"] as? String,
            as: AddressSnapshot.self
        )
        invoice.clientAddressSnapshot = decodeBase64(
            dict["clientAddressSnapshot"] as? String,
            as: AddressSnapshot.self
        )
        invoice.billToAddressSnapshot = decodeBase64(
            dict["billToAddressSnapshot"] as? String,
            as: AddressSnapshot.self
        )
        if let encodedState = dict["editorConfiguration"] as? String {
            invoice.invoiceEditorStateData = Data(base64Encoded: encodedState)
        }

        let rawStatus = dict["status"] as? String
        if let token = canonicalInvoiceStatusToken(rawStatus) {
            guard let parsed = InvoiceStatus(rawValue: token) else {
                throw NSError(
                    domain: "ImportError", code: 1003,
                    userInfo: [NSLocalizedDescriptionKey: "Unsupported invoice status '\(rawStatus ?? "")'."]
                )
            }
            invoice.status = parsed
        } else {
            invoice.status = .reviewDraft
        }

        if let s = dict["date"]      as? String { invoice.date      = ISO8601DateFormatter().date(from: s) ?? Date() }
        if let s = dict["dueDate"]   as? String { invoice.dueDate   = ISO8601DateFormatter().date(from: s) }
        if let s = dict["issueDate"] as? String { invoice.issueDate = ISO8601DateFormatter().date(from: s) ?? Date() }
        if let s = dict["paidDate"]  as? String { invoice.paidDate  = ISO8601DateFormatter().date(from: s) }
        if let s = dict["sentDate"]  as? String { invoice.sentDate  = ISO8601DateFormatter().date(from: s) }

        if let clientId = dict["client"] as? String, let client = entityMapping[clientId] as? Client {
            invoice.client = client
            if client.billingAuthority == .parentGuardian, let payee = client.payee {
                invoice.payee = payee
            } else {
                invoice.payee = (dict["payee"] as? String).flatMap { entityMapping[$0] as? Payee }
            }
        } else if let clientId = dict["clientId"] as? String, let client = entityMapping[clientId] as? Client {
            invoice.client = client
            if client.billingAuthority == .parentGuardian, let payee = client.payee {
                invoice.payee = payee
            } else {
                invoice.payee = (dict["payee"] as? String).flatMap { entityMapping[$0] as? Payee }
            }
        } else {
            invoice.client = nil
            invoice.payee  = (dict["payee"] as? String).flatMap { entityMapping[$0] as? Payee }
        }

        if let id = dict["businessId"] as? String, let biz = entityMapping[id] as? Business {
            invoice.business = biz
        }

        invoice.snapshotRelatedData()

        // Exported snapshots are authoritative. Relationship snapshots may be incomplete
        // when related records came from older or partial backups.
        if let value = dict["businessName"] as? String { invoice.businessName = value }
        if let value = dict["businessABN"] as? String { invoice.businessABN = value }
        if let value = dict["businessEmail"] as? String { invoice.businessEmail = value }
        if let value = dict["businessPhone"] as? String { invoice.businessPhone = value }
        if let value = dict["clientName"] as? String { invoice.clientName = value }
        if let value = dict["clientNDISNumber"] as? String { invoice.clientNDISNumber = value }
        if let value = dict["clientEmail"] as? String { invoice.clientEmail = value }
        if let value = dict["clientPhone"] as? String { invoice.clientPhone = value }
        if let value = dict["billToName"] as? String { invoice.billToName = value }
        if let value = dict["billToEmail"] as? String { invoice.billToEmail = value }
        if let value = dict["bankName"] as? String { invoice.bankName = value }
        if let value = dict["bankAccountName"] as? String { invoice.bankAccountName = value }
        if let value = dict["bankBSB"] as? String { invoice.bankBSB = value }
        if let value = dict["bankAccountNumber"] as? String { invoice.bankAccountNumber = value }
        if let value = decodeBase64(dict["businessAddressSnapshot"] as? String, as: AddressSnapshot.self) {
            invoice.businessAddressSnapshot = value
        }
        if let value = decodeBase64(dict["clientAddressSnapshot"] as? String, as: AddressSnapshot.self) {
            invoice.clientAddressSnapshot = value
        }
        if let value = decodeBase64(dict["billToAddressSnapshot"] as? String, as: AddressSnapshot.self) {
            invoice.billToAddressSnapshot = value
        }

        if let uuids = dict["invoiceItems"] as? [String] {
            invoice.items = uuids.compactMap { entityMapping[$0] as? InvoiceItem }
        }

        return invoice
    }

    static func createInvoiceItem(from dict: [String: Any], entityMapping: [String: Any]) throws -> InvoiceItem {
        let item = InvoiceItem(id: UUID(), itemDescription: dict["itemDescription"] as? String ?? dict["description"] as? String ?? "")
        item.position = dict["position"] as? Int32 ?? 0
        item.quantity = MoneyDecimalImport.decimal(from: dict["quantity"] as? Double ?? 0.0)
        item.rate     = MoneyDecimalImport.decimal(from: dict["rate"] as? Double ?? dict["unitPrice"] as? Double ?? 0.0)
        item.unit     = dict["unit"]    as? String
        item.taxRate  = MoneyDecimalImport.decimal(from: dict["taxRate"] as? Double ?? 0.0)
        item.gstCode  = dict["gstCode"] as? String
        item.ndisItemNumber = dict["itemCode"] as? String

        if let s = dict["date"] as? String { item.serviceDate = ISO8601DateFormatter().date(from: s) ?? Date() }

        if let id = dict["invoice"] as? String, let inv = entityMapping[id] as? Invoice { item.invoice = inv }
        else if let id = dict["invoiceId"] as? String, let inv = entityMapping[id] as? Invoice { item.invoice = inv }

        if let id = dict["session"] as? String, let sess = entityMapping[id] as? Session { item.session = sess }
        else if let id = dict["sessionId"] as? String, let sess = entityMapping[id] as? Session { item.session = sess }

        if let id = dict["clientService"] as? String, let cs = entityMapping[id] as? ClientService { item.clientService = cs }
        else if let id = dict["clientServiceId"] as? String, let cs = entityMapping[id] as? ClientService { item.clientService = cs }

        return item
    }

    // MARK: - Bulk Claim

    static func createBulkClaimBatch(from dict: [String: Any]) throws -> BulkClaimBatch {
        let batch = BulkClaimBatch(id: UUID())
        batch.status                   = dict["status"]                   as? String ?? BulkClaimBatchStatus.draft.rawValue
        batch.includeTravel            = dict["includeTravel"]            as? Bool   ?? true
        batch.includeCancellations     = dict["includeCancellations"]     as? Bool   ?? true
        batch.claimReferenceStrategy   = dict["claimReferenceStrategy"]   as? String ?? "invoice_number"
        batch.exportFileName           = dict["exportFileName"]           as? String
        batch.rowCount                 = Int32(dict["rowCount"]           as? Int    ?? 0)
        batch.errorCount               = Int32(dict["errorCount"]         as? Int    ?? 0)
        batch.checksumSHA256           = dict["checksumSHA256"]           as? String
        batch.notes                    = dict["notes"]                    as? String

        if let s = dict["createdAt"]   as? String { batch.createdAt   = ISO8601DateFormatter().date(from: s) ?? Date() }
        if let s = dict["fromDate"]    as? String { batch.fromDate    = ISO8601DateFormatter().date(from: s) ?? Date() }
        if let s = dict["toDate"]      as? String { batch.toDate      = ISO8601DateFormatter().date(from: s) ?? Date() }
        if let s = dict["exportedAt"]  as? String { batch.exportedAt  = ISO8601DateFormatter().date(from: s) }

        return batch
    }

    static func createBulkClaimLine(from dict: [String: Any], entityMapping: [String: Any]) throws -> BulkClaimLine {
        let line = BulkClaimLine(id: UUID())
        line.registrationNumber    = dict["registrationNumber"]    as? String ?? ""
        line.ndisNumber            = dict["ndisNumber"]            as? String ?? ""
        line.supportNumber         = dict["supportNumber"]         as? String ?? ""
        line.claimReference        = dict["claimReference"]        as? String
        line.quantity              = MoneyDecimalImport.decimal(from: dict["quantity"] as? Double)
        line.hours                 = dict["hours"]                 as? String
        line.unitPrice             = MoneyDecimalImport.decimal(from: dict["unitPrice"] as? Double ?? 0.0)
        line.gstCode               = dict["gstCode"]              as? String ?? GSTCode.p2.rawValue
        line.authorisedBy          = dict["authorisedBy"]          as? String
        line.participantApproved   = dict["participantApproved"]   as? String
        line.inKindFundingProgram  = dict["inKindFundingProgram"]  as? String
        line.claimTypeCode         = dict["claimTypeCode"]         as? String
        line.cancellationReason    = dict["cancellationReason"]    as? String
        line.abnOfSupportProvider  = dict["abnOfSupportProvider"]  as? String
        line.isValid               = dict["isValid"]               as? Bool   ?? true
        line.validationErrorSummary = dict["validationErrorSummary"] as? String
        line.submissionStatus      = dict["submissionStatus"]      as? String
        line.submissionRef         = dict["submissionRef"]         as? String
        line.reconciliationNotes   = dict["reconciliationNotes"]   as? String

        if let s = dict["supportsDeliveredFrom"] as? String { line.supportsDeliveredFrom = ISO8601DateFormatter().date(from: s) ?? Date() }
        if let s = dict["supportsDeliveredTo"]   as? String { line.supportsDeliveredTo   = ISO8601DateFormatter().date(from: s) ?? line.supportsDeliveredFrom }
        if let s = dict["reconciledAt"]          as? String { line.reconciledAt          = ISO8601DateFormatter().date(from: s) }

        guard let batchId = dict["batchId"] as? String, let batch = entityMapping[batchId] as? BulkClaimBatch else {
            throw NSError(
                domain: "AllDataImport", code: 422,
                userInfo: [NSLocalizedDescriptionKey: "BulkClaimLine is missing required batch relationship."]
            )
        }
        line.batch = batch

        if let id = dict["invoiceId"]     as? String, let inv  = entityMapping[id]  as? Invoice     { line.invoice     = inv }
        if let id = dict["invoiceItemId"] as? String, let item = entityMapping[id]  as? InvoiceItem { line.invoiceItem = item }

        return line
    }

    // MARK: - Session

    static func createSession(from dict: [String: Any], entityMapping: [String: Any]) throws -> Session {
        let session = Session(id: UUID())
        session.title           = dict["title"]           as? String ?? ""
        session.notes           = dict["notes"]           as? String
        session.location        = dict["location"]        as? String
        session.attendeesCount  = dict["attendeesCount"]  as? Int32  ?? 0
        session.isTravel        = dict["isTravel"]        as? Bool   ?? false
        session.sessionLatitude = dict["sessionLatitude"] as? Double ?? 0.0
        session.sessionLongitude = dict["sessionLongitude"] as? Double ?? 0.0
        let token = canonicalSessionStatusToken(dict["status"] as? String) ?? SessionStatus.scheduled.rawValue
        session.status = SessionStatus(normalized: token) ?? .scheduled

        if let s = dict["startTime"]       as? String { session.startTime        = ISO8601DateFormatter().date(from: s) }
        if let s = dict["endTime"]         as? String { session.endTime          = ISO8601DateFormatter().date(from: s) }
        if let s = dict["occurrenceDate"]  as? String { session.occurrenceDate   = ISO8601DateFormatter().date(from: s) }
        if let s = dict["lastModifiedDate"] as? String { session.lastModifiedDate = ISO8601DateFormatter().date(from: s) }
        if let s = dict["ekCreationDate"]  as? String { session.ekCreationDate   = ISO8601DateFormatter().date(from: s) }

        if let id = dict["client"] as? String, let c = entityMapping[id] as? Client { session.client = c }
        else if let id = dict["clientId"] as? String, let c = entityMapping[id] as? Client { session.client = c }

        if let id = dict["clientService"] as? String, let cs = entityMapping[id] as? ClientService { session.clientService = cs }
        else if let id = dict["clientServiceId"] as? String, let cs = entityMapping[id] as? ClientService { session.clientService = cs }

        if let id = dict["invoiceId"] as? String, let inv = entityMapping[id] as? Invoice { session.invoice = inv }

        if let id = dict["address"] as? String, let addr = entityMapping[id] as? Address { session.address = addr }
        else if let id = dict["addressId"] as? String, let addr = entityMapping[id] as? Address { session.address = addr }

        if let uuids = dict["invoiceItems"] as? [String] {
            session.invoiceItems = uuids.compactMap { entityMapping[$0] as? InvoiceItem }
        }

        return session
    }

}

private func decodeBase64<T: Decodable>(_ value: String?, as type: T.Type) -> T? {
    guard let value, let data = Data(base64Encoded: value) else { return nil }
    return try? JSONDecoder().decode(type, from: data)
}
