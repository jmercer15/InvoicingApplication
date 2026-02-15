import Foundation
import Core

public struct BulkClaimValidationSummary: Sendable, Equatable {
    public let totalRows: Int
    public let validRows: Int
    public let invalidRows: Int

    public var hasBlockers: Bool { invalidRows > 0 }

    public init(totalRows: Int, validRows: Int, invalidRows: Int) {
        self.totalRows = totalRows
        self.validRows = validRows
        self.invalidRows = invalidRows
    }
}

public struct BulkClaimValidationResult: Sendable, Equatable {
    public let lines: [BulkClaimLine]
    public let summary: BulkClaimValidationSummary

    public init(lines: [BulkClaimLine], summary: BulkClaimValidationSummary) {
        self.lines = lines
        self.summary = summary
    }
}

public final class BulkClaimValidationService: Sendable {
    private let validGSTCodes = Set(GSTCode.allCases.map(\.rawValue))
    private let validCancellationReasons = Set(CancellationReasonCode.allCases.map(\.rawValue))
    private let validClaimTypeCodes = Set(BPRClaimTypeCode.allCases.map(\.rawValue))

    public init() {}

    public func validate(lines: [BulkClaimLine]) -> [BulkClaimLine] {
        lines.map(validate(line:))
    }

    public func summarize(lines: [BulkClaimLine]) -> BulkClaimValidationSummary {
        let validRows = lines.filter(\.isValid).count
        return BulkClaimValidationSummary(
            totalRows: lines.count,
            validRows: validRows,
            invalidRows: lines.count - validRows
        )
    }

    public func validateAndSummarize(lines: [BulkClaimLine]) -> BulkClaimValidationResult {
        let validated = validate(lines: lines)
        return BulkClaimValidationResult(lines: validated, summary: summarize(lines: validated))
    }

    private func validate(line: BulkClaimLine) -> BulkClaimLine {
        var errors: [String] = []

        if line.registrationNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Registration number is required")
        }

        let normalizedNDIS = line.ndisNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalizedNDIS.isEmpty || !isDigitsOnly(normalizedNDIS) {
            errors.append("NDIS number must be numeric")
        }

        if line.supportNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Support number is required")
        }

        if line.supportsDeliveredTo < line.supportsDeliveredFrom {
            errors.append("Support delivery end is before start")
        }

        if line.unitPrice <= 0 {
            errors.append("Unit price must be greater than zero")
        }

        let gstCode = line.gstCode.uppercased()
        if !validGSTCodes.contains(gstCode) {
            errors.append("GST code must be one of P1, P2, P5")
        }

        if let claimTypeCode = line.claimTypeCode,
           !claimTypeCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           !validClaimTypeCodes.contains(claimTypeCode.uppercased()) {
            errors.append("Claim type code is invalid")
        }

        let hasQuantity = line.quantity != nil
        let hasHours = !(line.hours?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)

        if hasQuantity == hasHours {
            errors.append("Exactly one of quantity or hours is required")
        }

        if let quantity = line.quantity, quantity <= 0 {
            errors.append("Quantity must be greater than zero")
        }

        if let hours = line.hours?.trimmingCharacters(in: .whitespacesAndNewlines),
           !hours.isEmpty,
           !isValidHoursFormat(hours) {
            errors.append("Hours must use HHH:MM format")
        }

        if line.claimTypeCode?.uppercased() == BPRClaimTypeCode.canc.rawValue {
            let reason = line.cancellationReason?.uppercased() ?? ""
            if !validCancellationReasons.contains(reason) {
                errors.append("Cancellation reason is required for CANC")
            }
        }

        if let abn = line.abnOfSupportProvider?.trimmingCharacters(in: .whitespacesAndNewlines),
           !abn.isEmpty,
           (!isDigitsOnly(abn) || abn.count != 11) {
            errors.append("ABN of support provider must be 11 digits")
        }

        let summary = errors.isEmpty ? nil : errors.joined(separator: "; ")

        return BulkClaimLine(
            id: line.id,
            batchId: line.batchId,
            registrationNumber: line.registrationNumber,
            ndisNumber: line.ndisNumber,
            supportsDeliveredFrom: line.supportsDeliveredFrom,
            supportsDeliveredTo: line.supportsDeliveredTo,
            supportNumber: line.supportNumber,
            claimReference: line.claimReference,
            quantity: line.quantity,
            hours: line.hours,
            unitPrice: line.unitPrice,
            gstCode: line.gstCode,
            authorisedBy: line.authorisedBy,
            participantApproved: line.participantApproved,
            inKindFundingProgram: line.inKindFundingProgram,
            claimTypeCode: line.claimTypeCode,
            cancellationReason: line.cancellationReason,
            abnOfSupportProvider: line.abnOfSupportProvider,
            invoiceId: line.invoiceId,
            invoiceItemId: line.invoiceItemId,
            isValid: summary == nil,
            validationErrorSummary: summary,
            submissionStatus: line.submissionStatus,
            submissionRef: line.submissionRef,
            reconciliationNotes: line.reconciliationNotes,
            reconciledAt: line.reconciledAt
        )
    }

    private func isDigitsOnly(_ value: String) -> Bool {
        CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: value))
    }

    private func isValidHoursFormat(_ value: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: "^\\d{1,3}:[0-5]\\d$") else {
            return false
        }
        let range = NSRange(location: 0, length: value.utf16.count)
        return regex.firstMatch(in: value, options: [], range: range) != nil
    }
}
