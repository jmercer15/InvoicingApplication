import Core
import Foundation

public enum BPRFParserError: Error, Sendable {
    case invalidEncoding
}

/// Parses NDIA BPRF (Bulk Payment Results File) CSV into result lines keyed by claim reference.
public struct BPRFParser: Sendable {
    public init() {}

    /// Parses BPRF CSV data; returns result lines. Uses header-based column mapping.
    /// Expected columns (case-insensitive): Claim Reference / ClaimReference, Status / Submission Status, Paid Amount / PaidAmount, Error Code / ErrorCode, Error Message / ErrorMessage.
    public func parse(data: Data) throws -> [BPRFResultLine] {
        guard let string = String(data: data, encoding: .utf8) else {
            throw BPRFParserError.invalidEncoding
        }
        return try parse(csv: string)
    }

    /// Parses BPRF CSV string.
    public func parse(csv: String) throws -> [BPRFResultLine] {
        let rows = csv.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard let headerRow = rows.first else { return [] }
        let headers = parseCSVRow(headerRow)
        let headerLower = headers.map { $0.lowercased().replacingOccurrences(of: " ", with: "") }

        let refIdx = headerLower.firstIndex(of: "claimreference") ?? headerLower.firstIndex(of: "claim_reference") ?? 0
        let statusIdx: Int? = headerLower.firstIndex(of: "status") ?? headerLower.firstIndex(of: "submissionstatus") ?? headerLower.firstIndex(of: "submission_status")
            ?? (refIdx + 1 < headerLower.count ? refIdx + 1 : nil)
        let paidIdx = headerLower.firstIndex(of: "paidamount") ?? headerLower.firstIndex(of: "paid_amount") ?? headerLower.firstIndex(of: "amount")
        let errCodeIdx = headerLower.firstIndex(of: "errorcode") ?? headerLower.firstIndex(of: "error_code")
        let errMsgIdx = headerLower.firstIndex(of: "errormessage") ?? headerLower.firstIndex(of: "error_message") ?? headerLower.firstIndex(of: "message")

        var results: [BPRFResultLine] = []
        for row in rows.dropFirst() {
            let values = parseCSVRow(row)
            let ref = refIdx < values.count ? values[refIdx].trimmingCharacters(in: .whitespaces) : ""
            guard !ref.isEmpty else { continue }
            let status: String = {
                guard let i = statusIdx, i < values.count else { return "pending" }
                return values[i].trimmingCharacters(in: .whitespaces)
            }()
            let paidAmount: Decimal? = paidIdx.flatMap { i in
                guard i < values.count else { return nil }
                let s = values[i].trimmingCharacters(in: .whitespaces)
                return Decimal(string: s)
            }
            let errorCode = errCodeIdx.flatMap { $0 < values.count ? values[$0].trimmingCharacters(in: .whitespaces) : nil }
            let errorMessage = errMsgIdx.flatMap { $0 < values.count ? values[$0].trimmingCharacters(in: .whitespaces) : nil }
            results.append(BPRFResultLine(
                claimReference: ref,
                submissionStatus: status,
                paidAmount: paidAmount,
                errorCode: errorCode?.isEmpty == true ? nil : errorCode,
                errorMessage: errorMessage?.isEmpty == true ? nil : errorMessage
            ))
        }
        return results
    }

    private func parseCSVRow(_ row: String) -> [String] {
        var result: [String] = []
        var current = ""
        var inQuotes = false
        for char in row {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
                result.append(current)
                current = ""
            } else {
                current.append(char)
            }
        }
        result.append(current)
        return result
    }
}
