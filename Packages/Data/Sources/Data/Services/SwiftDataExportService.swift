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

    // MARK: - Export
    public static func exportAllEntitiesToJSON(context: ModelContext) throws -> Data {
        let exportDict = try collectEntityDictionaries(context: context)
        return try JSONSerialization.data(withJSONObject: exportDict, options: [.prettyPrinted, .sortedKeys])
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

// Extension to add ISO8601 string conversion to Date
extension Date {
    func iso8601String() -> String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: self)
    }
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

        let iso = ISO8601DateFormatter()

        // 1. AddressEntity
        let addressDescriptor = FetchDescriptor<AddressEntity>()
        let addresses = try context.fetch(addressDescriptor)
        exportDict["AddressEntity"] = addresses.map { address -> [String: Any] in
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

        // 2. BusinessEntity
        let businessDescriptor = FetchDescriptor<BusinessEntity>()
        let businesses = try context.fetch(businessDescriptor)
        exportDict["BusinessEntity"] = businesses.map { business -> [String: Any] in
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

        // 3. NDISItemEntity
        let ndisDescriptor = FetchDescriptor<NDISItemEntity>()
        let ndisItems = try context.fetch(ndisDescriptor)
        exportDict["NDISItemEntity"] = ndisItems.map { item -> [String: Any] in
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

        // 4. PayeeEntity
        let payeeDescriptor = FetchDescriptor<PayeeEntity>()
        let payees = try context.fetch(payeeDescriptor)
        exportDict["PayeeEntity"] = payees.map { payee -> [String: Any] in
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

        // 5. PlanManagerEntity
        let planManagerDescriptor = FetchDescriptor<PlanManagerEntity>()
        let planManagers = try context.fetch(planManagerDescriptor)
        exportDict["PlanManagerEntity"] = planManagers.map { planManager -> [String: Any] in
            var dict: [String: Any] = [:]
            dict["id"] = planManager.id.uuidString
            dict["businessName"] = planManager.name ?? ""
            dict["email"] = planManager.email ?? ""
            dict["phone"] = planManager.phone ?? ""
            dict["abn"] = planManager.abn
            dict["addressId"] = planManager.address?.id.uuidString
            return dict
        }

        // 6. ClientEntity
        let clientDescriptor = FetchDescriptor<ClientEntity>()
        let clients = try context.fetch(clientDescriptor)
        exportDict["ClientEntity"] = clients.map { client -> [String: Any] in
            var dict: [String: Any] = [:]
            dict["id"] = client.id.uuidString
            dict["fullName"] = client.fullName
            dict["email"] = client.email ?? ""
            dict["phone"] = client.phone ?? ""
            dict["ndisNumber"] = client.ndisNumber
            dict["status"] = client.status.rawValue
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

        // 7. ClientServiceEntity
        let clientServiceDescriptor = FetchDescriptor<ClientServiceEntity>()
        let clientServices = try context.fetch(clientServiceDescriptor)
        exportDict["ClientServiceEntity"] = clientServices.map { clientService -> [String: Any] in
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

        // 8. InvoiceEntity
        let invoiceDescriptor = FetchDescriptor<InvoiceEntity>()
        let invoices = try context.fetch(invoiceDescriptor)
        exportDict["InvoiceEntity"] = invoices.map { invoice -> [String: Any] in
            var dict: [String: Any] = [:]
            dict["id"] = invoice.id.uuidString
            dict["invoiceNumber"] = invoice.invoiceNumber
            dict["date"] = iso.string(from: invoice.date)
            dict["issueDate"] = iso.string(from: invoice.issueDate)
            dict["dueDate"] = invoice.dueDate.map { iso.string(from: $0) } ?? ""
            dict["totalAmount"] = invoice.totalAmount
            dict["status"] = invoice.status.rawValue
            dict["clientId"] = invoice.client?.id.uuidString ?? ""
            dict["payeeId"] = invoice.payee?.id.uuidString
            dict["businessId"] = invoice.business?.id.uuidString
            return dict
        }
        
        // 9. InvoiceItemEntity
        let invoiceItemDescriptor = FetchDescriptor<InvoiceItemEntity>()
        let invoiceItems = try context.fetch(invoiceItemDescriptor)
        exportDict["InvoiceItemEntity"] = invoiceItems.map { item -> [String: Any] in
            var dict: [String: Any] = [:]
            dict["id"] = item.id.uuidString
            dict["invoiceId"] = item.invoice?.id.uuidString
            dict["description"] = item.itemDescription
            dict["quantity"] = item.quantity
            dict["unitPrice"] = item.rate
            dict["totalPrice"] = item.lineTotal
            dict["gstAmount"] = item.lineTaxAmount
            dict["gstCode"] = item.gstCode
            dict["clientServiceId"] = item.clientService?.id.uuidString
            dict["date"] = iso.string(from: item.serviceDate)
            return dict
        }

        // 10. SessionEntity
        let sessionDescriptor = FetchDescriptor<SessionEntity>()
        let sessions = try context.fetch(sessionDescriptor)
        exportDict["SessionEntity"] = sessions.map { session -> [String: Any] in
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
        
        // 11. ServiceAgreementEntity
        let serviceAgreementDescriptor = FetchDescriptor<ServiceAgreementEntity>()
        let serviceAgreements = try context.fetch(serviceAgreementDescriptor)
        exportDict["ServiceAgreementEntity"] = serviceAgreements.map { agreement -> [String: Any] in
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

        // 12. SupportLogEntity
        let supportLogDescriptor = FetchDescriptor<SupportLogEntity>()
        let supportLogs = try context.fetch(supportLogDescriptor)
        exportDict["SupportLogEntity"] = supportLogs.map { log -> [String: Any] in
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

        // 13. BulkClaimBatchEntity
        let bulkBatchDescriptor = FetchDescriptor<BulkClaimBatchEntity>()
        let bulkBatches = try context.fetch(bulkBatchDescriptor)
        exportDict["BulkClaimBatchEntity"] = bulkBatches.map { batch -> [String: Any] in
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

        // 14. BulkClaimLineEntity
        let bulkLineDescriptor = FetchDescriptor<BulkClaimLineEntity>()
        let bulkLines = try context.fetch(bulkLineDescriptor)
        exportDict["BulkClaimLineEntity"] = bulkLines.map { line -> [String: Any] in
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

        // 15. TravelChargeEntity
        let travelChargeDescriptor = FetchDescriptor<TravelChargeEntity>()
        let travelCharges = try context.fetch(travelChargeDescriptor)
        exportDict["TravelChargeEntity"] = travelCharges.map { charge -> [String: Any] in
            var dict: [String: Any] = [:]
            dict["id"] = charge.id.uuidString
            dict["clientId"] = charge.client?.id.uuidString
            dict["date"] = charge.startTime.map { iso.string(from: $0) }
            dict["distance"] = charge.travelDistance
            dict["duration"] = charge.travelDuration
            dict["parkingCost"] = charge.parkingCost
            dict["tollCost"] = charge.tollCost
            dict["notes"] = charge.notes
            dict["linkedSessionId"] = charge.linkedSession?.id.uuidString
            dict["serviceId"] = charge.service?.id.uuidString
            return dict
        }
        
        // 16. TravelChargeReviewItem
        let reviewItemDescriptor = FetchDescriptor<TravelChargeReviewItemEntity>()
        let reviewItems = try context.fetch(reviewItemDescriptor)
        exportDict["TravelChargeReviewItem"] = reviewItems.map { item -> [String: Any] in
            var dict: [String: Any] = [:]
            dict["id"] = item.id.uuidString
            dict["sessionId"] = item.session?.id.uuidString
            dict["isApproved"] = item.isResolved // Mapping isResolved to isApproved for export compatibility if needed, or just export status
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
        
        // 18. RegionalPriceEntity
        let regionalPriceDescriptor = FetchDescriptor<RegionalPriceEntity>()
        let regionalPrices = try context.fetch(regionalPriceDescriptor)
        exportDict["RegionalPriceEntity"] = regionalPrices.map { price -> [String: Any] in
            var dict: [String: Any] = [:]
            dict["id"] = price.id.uuidString
            dict["ndisItemId"] = price.ndisItem?.id.uuidString
            dict["region"] = price.regionIdentifier
            dict["price"] = price.amount
            // dict["effectiveDate"] = iso.string(from: price.effectiveDate) // Not available in RegionalPriceEntity
            return dict
        }
        
        // 19. CreditHistoryEntryEntity
        let creditHistoryDescriptor = FetchDescriptor<CreditHistoryEntryEntity>()
        let creditHistory = try context.fetch(creditHistoryDescriptor)
        exportDict["CreditHistoryEntryEntity"] = creditHistory.map { entry -> [String: Any] in
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
<?xml version=\"1.0\"?>
<Workbook xmlns=\"urn:schemas-microsoft-com:office:spreadsheet\"
          xmlns:o=\"urn:schemas-microsoft-com:office:office\"
          xmlns:x=\"urn:schemas-microsoft-com:office:excel\"
          xmlns:ss=\"urn:schemas-microsoft-com:office:spreadsheet\">
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
            return ISO8601DateFormatter().string(from: date)
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
