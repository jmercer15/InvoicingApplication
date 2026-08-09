import Foundation
import CryptoKit
import Core
import PersistenceModels

public final class BPRCSVWriter: Sendable {
    public static let columns: [String] = [
        "Registration Number",
        "NDIS Number",
        "Supports Delivered From",
        "Supports Delivered To",
        "Support Number",
        "Claim Reference",
        "Quantity",
        "Hours",
        "Unit Price",
        "GST Code",
        "Authorised By",
        "Participant Approved",
        "In Kind Funding Program",
        "Claim Type",
        "Cancellation Reason",
        "ABN Of Support Provider"
    ]

    public init() {}

    public func csvString(lines: [BulkClaimLine]) -> String {
        var rows: [String] = []
        rows.append(Self.columns.joined(separator: ","))

        for line in lines {
            let values: [String] = [
                line.registrationNumber,
                line.ndisNumber,
                ExportMachineFormatting.exportDate(line.supportsDeliveredFrom),
                ExportMachineFormatting.exportDate(line.supportsDeliveredTo),
                line.supportNumber,
                line.claimReference ?? "",
                line.quantity.map(formatQuantity) ?? "",
                line.hours ?? "",
                formatUnitPrice(line.unitPrice),
                line.gstCode.uppercased(),
                line.authorisedBy ?? "",
                line.participantApproved ?? "",
                line.inKindFundingProgram ?? "",
                line.claimTypeCode ?? "",
                line.cancellationReason ?? "",
                line.abnOfSupportProvider ?? ""
            ]
            rows.append(values.map(escapeCSV).joined(separator: ","))
        }

        return rows.joined(separator: "\n") + "\n"
    }

    public func csvData(lines: [BulkClaimLine]) -> Data {
        Data(csvString(lines: lines).utf8)
    }

    public func csvString(snapshots: [BulkClaimLineSnapshot]) -> String {
        var rows: [String] = []
        rows.append(Self.columns.joined(separator: ","))

        for line in snapshots {
            let values: [String] = [
                line.registrationNumber,
                line.ndisNumber,
                ExportMachineFormatting.exportDate(line.supportsDeliveredFrom),
                ExportMachineFormatting.exportDate(line.supportsDeliveredTo),
                line.supportNumber,
                line.claimReference ?? "",
                line.quantity.map(formatQuantity) ?? "",
                line.hours ?? "",
                formatUnitPrice(line.unitPrice),
                line.gstCode.uppercased(),
                line.authorisedBy ?? "",
                line.participantApproved ?? "",
                line.inKindFundingProgram ?? "",
                line.claimTypeCode ?? "",
                line.cancellationReason ?? "",
                line.abnOfSupportProvider ?? ""
            ]
            rows.append(values.map(escapeCSV).joined(separator: ","))
        }

        return rows.joined(separator: "\n") + "\n"
    }

    public func csvData(snapshots: [BulkClaimLineSnapshot]) -> Data {
        Data(csvString(snapshots: snapshots).utf8)
    }

    public func sha256Hex(for data: Data) -> String {
        ExportMachineFormatting.sha256Hex(digest: SHA256.hash(data: data))
    }

    private func formatQuantity(_ value: Decimal) -> String {
        ExportMachineFormatting.exportDecimal3(value)
    }

    private func formatUnitPrice(_ value: Decimal) -> String {
        ExportMachineFormatting.exportDecimal2(value)
    }

    private func escapeCSV(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r") {
            let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return value
    }
}
