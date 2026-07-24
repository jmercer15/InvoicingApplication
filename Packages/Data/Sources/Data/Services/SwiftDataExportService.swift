import Core
import Foundation
import SwiftData
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

/// SwiftData Export Service
/// Provides data export capabilities for the InvoicingApplication
public struct SwiftDataExportService {
    private static let jsonWriteOptions: JSONSerialization.WritingOptions = []
    nonisolated(unsafe) private static let isoFormatter = ISO8601DateFormatter()

    // MARK: - Export
    public static func exportAllEntitiesToJSON(context: ModelContext) throws -> Data {
        let exportDict = try collectEntityDictionaries(context: context)
        return try JSONSerialization.data(withJSONObject: exportDict, options: jsonWriteOptions)
    }

    public static func exportToFile(context: ModelContext, format: SwiftDataExportFormat = .json) throws -> (Data, String) {
        switch format {
        case .json:
            let data = try exportAllEntitiesToJSON(context: context)
            let timestamp = DateFormatter.exportTimestamp.string(from: Date())
            let filename = "InvoicingApp-Export-\(timestamp).json"
            return (data, filename)

        case .csv:
            let exportDict = try collectEntityDictionaries(context: context)
            let csvString = buildCSV(from: exportDict)
            let timestamp = DateFormatter.exportTimestamp.string(from: Date())
            let filename = "InvoicingApp-Export-\(timestamp).csv"
            return (Data(csvString.utf8), filename)

        case .excel:
            let exportDict = try collectEntityDictionaries(context: context)
            let workbookXML = buildSpreadsheetML(from: exportDict)
            let timestamp = DateFormatter.exportTimestamp.string(from: Date())
            let filename = "InvoicingApp-Export-\(timestamp).xml"
            return (Data(workbookXML.utf8), filename)
        }
    }
}

/// Export format options
public enum SwiftDataExportFormat {
    case json
    case csv
    case excel
}

extension DateFormatter {
    static let exportTimestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter
    }()
}

// MARK: - Private Helpers
private extension SwiftDataExportService {
    static func collectEntityDictionaries(context: ModelContext) throws -> [String: [[String: Any]]] {
        var exportDict: [String: [[String: Any]]] = [:]

        let iso = Self.isoFormatter

        // 1. Address
        let addressDescriptor = FetchDescriptor<Address>()
        let addresses = try context.fetch(addressDescriptor)
        exportDict["Address"] = addresses.map { address -> [String: Any] in
            var dict: [String: Any] = [:]
            dict["id"] = address.id.uuidString
            dict["streetNumber"] = address.streetNumber
            dict["streetName"] = address.streetName
            dict["suburb"] = address.suburb
            dict["state"] = address.state
            dict["postcode"] = address.postcode
            dict["country"] = address.country
            dict["latitude"] = address.latitude
            dict["longitude"] = address.longitude
            return dict
        }

        // 2. Business
        let businessDescriptor = FetchDescriptor<Business>()
        let businesses = try context.fetch(businessDescriptor)
        exportDict["Business"] = businesses.map { business -> [String: Any] in
            var dict: [String: Any] = [:]
            dict["id"] = business.id.uuidString
            dict["name"] = business.name
            dict["email"] = business.email
            dict["phone"] = business.phone
            dict["abn"] = business.abn
            dict["accountingMethod"] = business.accountingMethod
            dict["bankAccountName"] = business.bankAccountName
            dict["bankAccountNumber"] = business.bankAccountNumber
            dict["bankBSB"] = business.bankBSB
            dict["bankName"] = business.bankName
            dict["ndiaOrganisationID"] = business.ndiaOrganisationID
            dict["isRegisteredProvider"] = business.isRegisteredProvider
            dict["defaultGstCode"] = business.defaultGstCode
            dict["addressId"] = business.address?.id.uuidString
            return dict
        }

        // 3. NDISItem
        let ndisDescriptor = FetchDescriptor<NDISItem>()
        let ndisItems = try context.fetch(ndisDescriptor)
        exportDict["NDISItem"] = ndisItems.map { item -> [String: Any] in
            var dict: [String: Any] = [:]
            dict["id"] = item.id.uuidString
            dict["itemNumber"] = item.itemNumber
            dict["name"] = item.name
            dict["versionIdentifier"] = item.versionIdentifier
            dict["isCurrent"] = item.isCurrent
            dict["category"] = item.category
            dict["categoryNamePACE"] = item.categoryNamePACE
            dict["categoryNumber"] = item.categoryNumber
            dict["categoryNumberPACE"] = item.categoryNumberPACE
            dict["features"] = item.features
            dict["itemDescription"] = item.itemDescription
            dict["ndiaRequestedReports"] = item.ndiaRequestedReports
            dict["nonFaceToFaceProvision"] = item.nonFaceToFaceProvision
            dict["providerTravel"] = item.providerTravel
            dict["quoteRequired"] = item.quoteRequired
            dict["registrationGroup"] = item.registrationGroup
            dict["registrationGroupNumber"] = item.registrationGroupNumber
            dict["shortNoticeCancellations"] = item.shortNoticeCancellations
            dict["irregularSILSupports"] = item.irregularSILSupports
            dict["status"] = item.status
            dict["type"] = item.type
            dict["unit"] = item.unit
            dict["effectiveStartDate"] = item.effectiveStartDate.map { iso.string(from: $0) }
            dict["effectiveEndDate"] = item.effectiveEndDate.map { iso.string(from: $0) }
            return dict
        }

        // 4. Payee
        let payeeDescriptor = FetchDescriptor<Payee>()
        let payees = try context.fetch(payeeDescriptor)
        exportDict["Payee"] = payees.map { payee -> [String: Any] in
            var dict: [String: Any] = [:]
            dict["id"] = payee.id.uuidString
            dict["fullName"] = payee.fullName
            dict["email"] = payee.email ?? ""
            dict["phone"] = payee.phone ?? ""
            dict["relationToClient"] = payee.relationToClient ?? ""
            dict["status"] = payee.status ?? ""
            dict["addressId"] = payee.address?.id.uuidString
            return dict
        }

        // 5. PlanManager
        let planManagerDescriptor = FetchDescriptor<PlanManager>()
        let planManagers = try context.fetch(planManagerDescriptor)
        exportDict["PlanManager"] = planManagers.map { planManager -> [String: Any] in
            var dict: [String: Any] = [:]
            dict["id"] = planManager.id.uuidString
            dict["businessName"] = planManager.name ?? ""
            dict["email"] = planManager.email ?? ""
            dict["phone"] = planManager.phone ?? ""
            dict["abn"] = planManager.abn
            dict["addressId"] = planManager.address?.id.uuidString
            return dict
        }

        // 6. Client
        let clientDescriptor = FetchDescriptor<Client>()
        let clients = try context.fetch(clientDescriptor)
        exportDict["Client"] = clients.map { client -> [String: Any] in
            var dict: [String: Any] = [:]
            dict["id"] = client.id.uuidString
            dict["fullName"] = client.fullName
            dict["email"] = client.email ?? ""
            dict["phone"] = client.phone ?? ""
            dict["ndisNumber"] = client.ndisNumber
            dict["status"] = client.effectiveStatus.rawValue
            dict["notes"] = client.notes ?? ""
            dict["creditAmount"] = client.creditAmount
            dict["isMinor"] = client.isMinor
            dict["hasNdisPlan"] = client.hasNdisPlan
            dict["planManagementType"] = client.planManagementType ?? ""
            dict["billingAuthority"] = client.billingAuthority?.rawValue ?? ""
            dict["addressId"] = client.address?.id.uuidString
            dict["payeeId"] = client.payee?.id.uuidString
            dict["planManagerId"] = client.planManager?.id.uuidString
            return dict
        }

        // 7. ClientService
        let clientServiceDescriptor = FetchDescriptor<ClientService>()
        let clientServices = try context.fetch(clientServiceDescriptor)
        exportDict["ClientService"] = clientServices.map { clientService -> [String: Any] in
            var dict: [String: Any] = [:]
            dict["id"] = clientService.id.uuidString
            dict["clientId"] = clientService.client?.id.uuidString ?? ""
            dict["serviceName"] = clientService.serviceName
            dict["rate"] = clientService.rate
            dict["unit"] = clientService.unit
            dict["status"] = clientService.status ?? ""
            dict["isActive"] = clientService.isActive
            dict["startDate"] = clientService.startDate.map { iso.string(from: $0) } ?? ""
            dict["endDate"] = clientService.endDate.map { iso.string(from: $0) } ?? ""
            dict["ndisCode"] = clientService.ndisCode ?? ""
            dict["ndisItemId"] = clientService.ndisItem?.id.uuidString ?? ""
            return dict
        }

        // 8. Invoice
        let invoiceDescriptor = FetchDescriptor<Invoice>()
        let invoices = try context.fetch(invoiceDescriptor)
        exportDict["Invoice"] = invoices.map { invoice -> [String: Any] in
            var dict: [String: Any] = [:]
            dict["id"] = invoice.id.uuidString
            dict["invoiceNumber"] = invoice.invoiceNumber
            dict["date"] = iso.string(from: invoice.date)
            dict["issueDate"] = iso.string(from: invoice.issueDate)
            dict["dueDate"] = invoice.dueDate.map { iso.string(from: $0) } ?? ""
            dict["totalAmount"] = invoice.totalAmount
            dict["taxRate"] = invoice.taxRate
            dict["discount"] = invoice.discount
            dict["creditApplied"] = invoice.creditApplied
            dict["currencyCode"] = invoice.currencyCode
            dict["paymentTerms"] = invoice.paymentTerms
            dict["notes"] = invoice.notes
            dict["status"] = invoice.effectiveStatus.rawValue
            dict["paidDate"] = invoice.paidDate.map { iso.string(from: $0) }
            dict["sentDate"] = invoice.sentDate.map { iso.string(from: $0) }
            dict["businessName"] = invoice.businessName
            dict["businessABN"] = invoice.businessABN
            dict["businessEmail"] = invoice.businessEmail
            dict["businessPhone"] = invoice.businessPhone
            dict["clientName"] = invoice.clientName
            dict["clientNDISNumber"] = invoice.clientNDISNumber
            dict["clientEmail"] = invoice.clientEmail
            dict["clientPhone"] = invoice.clientPhone
            dict["billingAuthority"] = invoice.billingAuthority?.rawValue
            dict["billToName"] = invoice.billToName
            dict["billToEmail"] = invoice.billToEmail
            dict["bankName"] = invoice.bankName
            dict["bankAccountName"] = invoice.bankAccountName
            dict["bankBSB"] = invoice.bankBSB
            dict["bankAccountNumber"] = invoice.bankAccountNumber
            dict["businessAddressSnapshot"] = encodedBase64(invoice.businessAddressSnapshot)
            dict["clientAddressSnapshot"] = encodedBase64(invoice.clientAddressSnapshot)
            dict["billToAddressSnapshot"] = encodedBase64(invoice.billToAddressSnapshot)
            dict["editorConfiguration"] = invoice.invoiceEditorStateData?.base64EncodedString()
            dict["clientId"] = invoice.client?.id.uuidString ?? ""
            dict["payeeId"] = invoice.payee?.id.uuidString
            dict["businessId"] = invoice.business?.id.uuidString
            return dict
        }

        // 9. InvoiceItem
        let invoiceItemDescriptor = FetchDescriptor<InvoiceItem>()
        let invoiceItems = try context.fetch(invoiceItemDescriptor)
        exportDict["InvoiceItem"] = invoiceItems.map { item -> [String: Any] in
            var dict: [String: Any] = [:]
            dict["id"] = item.id.uuidString
            dict["invoiceId"] = item.invoice?.id.uuidString
            dict["description"] = item.itemDescription
            dict["position"] = item.position
            dict["quantity"] = item.quantity
            dict["unit"] = item.unit
            dict["unitPrice"] = item.rate
            dict["taxRate"] = item.taxRate
            dict["itemCode"] = item.ndisItemNumber
            dict["totalPrice"] = item.lineTotal
            dict["gstAmount"] = item.lineTotal * (item.taxRate / 100.0)
            dict["gstCode"] = item.gstCode
            dict["clientServiceId"] = item.clientService?.id.uuidString
            dict["date"] = iso.string(from: item.serviceDate)
            return dict
        }

        // 10. Session
        let sessionDescriptor = FetchDescriptor<Session>()
        let sessions = try context.fetch(sessionDescriptor)
        exportDict["Session"] = sessions.map { session -> [String: Any] in
            var dict: [String: Any] = [:]
            dict["id"] = session.id.uuidString
            dict["title"] = session.title
            dict["startTime"] = session.startTime.map { iso.string(from: $0) } ?? ""
            dict["endTime"] = session.endTime.map { iso.string(from: $0) } ?? ""
            dict["location"] = session.location ?? ""
            dict["notes"] = session.notes ?? ""
            dict["status"] = session.status?.rawValue ?? ""
            dict["clientId"] = session.client?.id.uuidString ?? ""
            dict["clientServiceId"] = session.clientService?.id.uuidString
            dict["invoiceId"] = session.invoice?.id.uuidString
            dict["addressId"] = session.address?.id.uuidString
            return dict
        }

        // 11. ServiceAgreement
        let serviceAgreementDescriptor = FetchDescriptor<ServiceAgreement>()
        let serviceAgreements = try context.fetch(serviceAgreementDescriptor)
        exportDict["ServiceAgreement"] = serviceAgreements.map { agreement -> [String: Any] in
            var dict: [String: Any] = [:]
            dict["id"] = agreement.id.uuidString
            dict["clientId"] = agreement.client?.id.uuidString
            dict["effectiveFrom"] = iso.string(from: agreement.effectiveFrom)
            dict["effectiveTo"] = agreement.effectiveTo.map { iso.string(from: $0) }
            dict["pricingDisclosureAcceptedAt"] = agreement.pricingDisclosureAcceptedAt.map { iso.string(from: $0) }
            dict["cancellationPolicyType"] = agreement.cancellationPolicyType
            dict["allowsProviderTravel"] = agreement.allowsProviderTravel
            dict["allowsTelehealth"] = agreement.allowsTelehealth
            dict["allowsNonFaceToFace"] = agreement.allowsNonFaceToFace
            dict["participantSignatoryName"] = agreement.participantSignatoryName
            dict["participantSignatoryRole"] = agreement.participantSignatoryRole
            dict["signedAt"] = agreement.signedAt.map { iso.string(from: $0) }
            dict["signatureMethod"] = agreement.signatureMethod
            dict["notes"] = agreement.notes
            dict["isArchived"] = agreement.isArchived
            return dict
        }

        // 12. SupportLog
        let supportLogDescriptor = FetchDescriptor<SupportLog>()
        let supportLogs = try context.fetch(supportLogDescriptor)
        exportDict["SupportLog"] = supportLogs.map { log -> [String: Any] in
            var dict: [String: Any] = [:]
            dict["id"] = log.id.uuidString
            dict["clientId"] = log.client?.id.uuidString
            dict["sessionId"] = log.session?.id.uuidString
            dict["participantName"] = log.participantName
            dict["participantNdisNumber"] = log.participantNdisNumber
            dict["supportItemNumber"] = log.supportItemNumber
            dict["serviceDescription"] = log.serviceDescription
            dict["location"] = log.location
            dict["deliveredFrom"] = iso.string(from: log.deliveredFrom)
            dict["deliveredTo"] = iso.string(from: log.deliveredTo)
            dict["quantityHours"] = log.quantityHours
            dict["deliveredBy"] = log.deliveredBy
            dict["attestedBy"] = log.attestedBy
            dict["attestedAt"] = iso.string(from: log.attestedAt)
            dict["signatureMethod"] = log.signatureMethod
            dict["signedBy"] = log.signedBy
            dict["signedAt"] = log.signedAt.map { iso.string(from: $0) }
            dict["cancellationReasonCode"] = log.cancellationReasonCode
            dict["notes"] = log.notes
            return dict
        }

        // 13. BulkClaimBatch
        let bulkBatchDescriptor = FetchDescriptor<BulkClaimBatch>()
        let bulkBatches = try context.fetch(bulkBatchDescriptor)
        exportDict["BulkClaimBatch"] = bulkBatches.map { batch -> [String: Any] in
            var dict: [String: Any] = [:]
            dict["id"] = batch.id.uuidString
            dict["createdAt"] = iso.string(from: batch.createdAt)
            dict["fromDate"] = iso.string(from: batch.fromDate)
            dict["toDate"] = iso.string(from: batch.toDate)
            dict["status"] = batch.status
            dict["includeTravel"] = batch.includeTravel
            dict["includeCancellations"] = batch.includeCancellations
            dict["claimReferenceStrategy"] = batch.claimReferenceStrategy
            dict["exportFileName"] = batch.exportFileName
            dict["exportedAt"] = batch.exportedAt.map { iso.string(from: $0) }
            dict["rowCount"] = Int(batch.rowCount)
            dict["errorCount"] = Int(batch.errorCount)
            dict["checksumSHA256"] = batch.checksumSHA256
            dict["notes"] = batch.notes
            return dict
        }

        // 14. BulkClaimLine
        let bulkLineDescriptor = FetchDescriptor<BulkClaimLine>()
        let bulkLines = try context.fetch(bulkLineDescriptor)
        exportDict["BulkClaimLine"] = bulkLines.map { line -> [String: Any] in
            var dict: [String: Any] = [:]
            dict["id"] = line.id.uuidString
            dict["batchId"] = line.batch?.id.uuidString
            dict["registrationNumber"] = line.registrationNumber
            dict["ndisNumber"] = line.ndisNumber
            dict["supportsDeliveredFrom"] = iso.string(from: line.supportsDeliveredFrom)
            dict["supportsDeliveredTo"] = iso.string(from: line.supportsDeliveredTo)
            dict["supportNumber"] = line.supportNumber
            dict["claimReference"] = line.claimReference
            dict["quantity"] = line.quantity
            dict["hours"] = line.hours
            dict["unitPrice"] = line.unitPrice
            dict["gstCode"] = line.gstCode
            dict["authorisedBy"] = line.authorisedBy
            dict["participantApproved"] = line.participantApproved
            dict["inKindFundingProgram"] = line.inKindFundingProgram
            dict["claimTypeCode"] = line.claimTypeCode
            dict["cancellationReason"] = line.cancellationReason
            dict["abnOfSupportProvider"] = line.abnOfSupportProvider
            dict["invoiceId"] = line.invoice?.id.uuidString
            dict["invoiceItemId"] = line.invoiceItem?.id.uuidString
            dict["isValid"] = line.isValid
            dict["validationErrorSummary"] = line.validationErrorSummary
            dict["submissionStatus"] = line.submissionStatus
            dict["submissionRef"] = line.submissionRef
            dict["reconciliationNotes"] = line.reconciliationNotes
            dict["reconciledAt"] = line.reconciledAt.map { iso.string(from: $0) }
            return dict
        }

        // 15. TravelCharge
        let travelChargeDescriptor = FetchDescriptor<TravelCharge>()
        let travelCharges = try context.fetch(travelChargeDescriptor)
        exportDict["TravelCharge"] = travelCharges.map { charge -> [String: Any] in
            var dict: [String: Any] = [:]
            dict["id"] = charge.id.uuidString
            dict["clientId"] = charge.client?.id.uuidString
            dict["date"] = charge.startTime.map { iso.string(from: $0) }
            dict["distance"] = charge.distanceKM
            dict["duration"] = charge.durationMinutes
            dict["parkingCost"] = charge.parkingCost
            dict["tollCost"] = charge.tollCost
            dict["notes"] = charge.notes
            dict["linkedSessionId"] = charge.linkedSession?.id.uuidString
            dict["serviceId"] = charge.service?.id.uuidString
            return dict
        }

        // 16. TravelChargeReviewItem
        let reviewItemDescriptor = FetchDescriptor<TravelChargeReviewItem>()
        let reviewItems = try context.fetch(reviewItemDescriptor)
        exportDict["TravelChargeReviewItem"] = reviewItems.map { item -> [String: Any] in
            var dict: [String: Any] = [:]
            dict["id"] = item.id.uuidString
            dict["sessionId"] = item.session?.id.uuidString
            dict["isApproved"] = item.status != "pending"
            dict["status"] = item.status
            dict["reason"] = item.reason
            dict["timestamp"] = item.timestamp.map { iso.string(from: $0) }
            return dict
        }

        // 17. TravelChargeAuditLog
        let auditLogDescriptor = FetchDescriptor<TravelChargeAuditLog>()
        let auditLogs = try context.fetch(auditLogDescriptor)
        exportDict["TravelChargeAuditLog"] = auditLogs.map { log -> [String: Any] in
            var dict: [String: Any] = [:]
            dict["id"] = log.id.uuidString
            dict["travelChargeId"] = log.charge?.id.uuidString
            dict["action"] = log.action
            dict["timestamp"] = log.timestamp.map { iso.string(from: $0) }
            dict["details"] = log.details
            return dict
        }

        // 18. RegionalPrice
        let regionalPriceDescriptor = FetchDescriptor<RegionalPrice>()
        let regionalPrices = try context.fetch(regionalPriceDescriptor)
        exportDict["RegionalPrice"] = regionalPrices.map { price -> [String: Any] in
            var dict: [String: Any] = [:]
            dict["id"] = price.id.uuidString
            dict["ndisItemId"] = price.ndisItem?.id.uuidString
            dict["region"] = price.regionIdentifier
            dict["price"] = price.amount
            return dict
        }

        // 19. CreditHistoryEntry
        let creditHistoryDescriptor = FetchDescriptor<CreditHistoryEntry>()
        let creditHistory = try context.fetch(creditHistoryDescriptor)
        exportDict["CreditHistoryEntry"] = creditHistory.map { entry -> [String: Any] in
            var dict: [String: Any] = [:]
            dict["id"] = entry.id.uuidString
            dict["clientId"] = entry.client?.id.uuidString
            dict["amount"] = entry.amount
            dict["date"] = entry.date.map { iso.string(from: $0) }
            dict["reason"] = entry.notes
            dict["type"] = entry.type
            return dict
        }

        return exportDict
    }

    static func encodedBase64<T: Encodable>(_ value: T?) -> String? {
        guard let value, let data = try? JSONEncoder().encode(value) else { return nil }
        return data.base64EncodedString()
    }

    static func buildCSV(from exportDict: [String: [[String: Any]]]) -> String {
        let orderedEntities = exportDict.keys.sorted()
        var sections: [String] = []

        for entityName in orderedEntities {
            guard let rows = exportDict[entityName], !rows.isEmpty else { continue }
            let headers = orderedHeaders(for: rows)
            var csv = "# \(entityName)" + "\n"
            csv += headers.joined(separator: ",") + "\n"

            for row in rows {
                let line = headers
                    .map { header -> String in
                        let value = row[header] ?? ""
                        return escapeCSVField(stringify(value))
                    }
                    .joined(separator: ",")
                csv += line + "\n"
            }
            sections.append(csv.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return sections.joined(separator: "\n\n") + "\n"
    }

    static func buildSpreadsheetML(from exportDict: [String: [[String: Any]]]) -> String {
        let orderedEntities = exportDict.keys.sorted()
        var worksheets: [String] = []

        for entity in orderedEntities {
            guard let rows = exportDict[entity], !rows.isEmpty else { continue }
            let headers = orderedHeaders(for: rows)
            var rowsXML = "    <Row>\n"
            for header in headers {
                rowsXML += "      <Cell><Data ss:Type=\"String\">\(escapeXML(header))</Data></Cell>\n"
            }
            rowsXML += "    </Row>\n"

            for row in rows {
                rowsXML += "    <Row>\n"
                for header in headers {
                    let value = row[header] ?? ""
                    let stringValue = stringify(value)
                    let type = (Double(stringValue) != nil) ? "Number" : "String"
                    rowsXML += "      <Cell><Data ss:Type=\"\(type)\">\(escapeXML(stringValue))</Data></Cell>\n"
                }
                rowsXML += "    </Row>\n"
            }

            let worksheetName = escapeXML(String(entity.prefix(31)))
            let worksheet = "  <Worksheet ss:Name=\"\(worksheetName)\">\n    <Table>\n\(rowsXML)    </Table>\n  </Worksheet>"
            worksheets.append(worksheet)
        }

        let workbook = """
<?xml version="1.0"?>
<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet"
          xmlns:o="urn:schemas-microsoft-com:office:office"
          xmlns:x="urn:schemas-microsoft-com:office:excel"
          xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">
\(worksheets.joined(separator: "\n"))
</Workbook>
"""
        return workbook
    }

    static func orderedHeaders(for rows: [[String: Any]]) -> [String] {
        var ordered: [String] = []
        var seen = Set<String>()
        for row in rows {
            for key in row.keys where !seen.contains(key) {
                ordered.append(key)
                seen.insert(key)
            }
        }
        return ordered
    }

    static func stringify(_ value: Any) -> String {
        switch value {
        case let date as Date:
            return isoFormatter.string(from: date)
        case let number as NSNumber:
            return number.stringValue
        case let bool as Bool:
            return bool ? "true" : "false"
        case let string as String:
            return string
        case let uuid as UUID:
            return uuid.uuidString
        case let array as [Any]:
            return array.map { stringify($0) }.joined(separator: ";")
        default:
            return String(describing: value)
        }
    }

    static func escapeCSVField(_ value: String) -> String {
        var result = value
        if result.contains(",") || result.contains("\"") || result.contains("\n") {
            result = "\"" + result.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return result
    }

    static func escapeXML(_ value: String) -> String {
        var escaped = value.replacingOccurrences(of: "&", with: "&amp;")
        escaped = escaped.replacingOccurrences(of: "<", with: "&lt;")
        escaped = escaped.replacingOccurrences(of: ">", with: "&gt;")
        escaped = escaped.replacingOccurrences(of: "\"", with: "&quot;")
        escaped = escaped.replacingOccurrences(of: "'", with: "&apos;")
        return escaped
    }
}
