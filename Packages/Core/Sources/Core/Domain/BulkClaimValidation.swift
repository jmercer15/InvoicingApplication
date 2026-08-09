import Foundation

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
    public let lines: [BulkClaimLineSnapshot]
    public let summary: BulkClaimValidationSummary

    public init(lines: [BulkClaimLineSnapshot], summary: BulkClaimValidationSummary) {
        self.lines = lines
        self.summary = summary
    }
}
