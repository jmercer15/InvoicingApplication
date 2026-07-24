import Foundation
import CryptoKit
import Core

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

    private let dateFormatter: DateFormatter

    public init() {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        self.dateFormatter = formatter
    }

    public func csvString(lines: [BulkClaimLine]) -> String {
        var rows: [String] = []
        rows.append(Self.columns.joined(separator: ","))

        for line in lines {
            let values: [String] = [
                line.registrationNumber,
                line.ndisNumber,
                dateFormatter.string(from: line.supportsDeliveredFrom),
                dateFormatter.string(from: line.supportsDeliveredTo),
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
                dateFormatter.string(from: line.supportsDeliveredFrom),
                dateFormatter.string(from: line.supportsDeliveredTo),
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
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func formatQuantity(_ value: Double) -> String {
        let rounded = (value * 1000).rounded() / 1000
        var text = String(format: "%.3f", rounded)
        while text.contains(".") && text.last == "0" {
            text.removeLast()
        }
        if text.last == "." {
            text.removeLast()
        }
        return text
    }

    private func formatUnitPrice(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    private func escapeCSV(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r") {
            let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return value
    }
}
