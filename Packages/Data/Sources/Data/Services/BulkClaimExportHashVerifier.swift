import Foundation
import Core

public struct BulkClaimExportHashVerificationResult: Sendable, Equatable {
    public let expectedSHA256: String
    public let actualSHA256: String

    public var isMatch: Bool {
        expectedSHA256.caseInsensitiveCompare(actualSHA256) == .orderedSame
    }

    public init(expectedSHA256: String, actualSHA256: String) {
        self.expectedSHA256 = expectedSHA256
        self.actualSHA256 = actualSHA256
    }
}

public struct BulkClaimExportHashVerifier: Sendable {
    private let csvWriter: BPRCSVWriter

    public init(csvWriter: BPRCSVWriter = BPRCSVWriter()) {
        self.csvWriter = csvWriter
    }

    public func hash(for data: Data) -> String {
        csvWriter.sha256Hex(for: data)
    }

    public func hash(for lines: [BulkClaimLine]) -> String {
        let csvData = csvWriter.csvData(lines: lines)
        return hash(for: csvData)
    }

    public func verify(data: Data, expectedSHA256: String) -> Bool {
        hash(for: data).caseInsensitiveCompare(expectedSHA256) == .orderedSame
    }

    public func verify(lines: [BulkClaimLine], expectedSHA256: String) -> Bool {
        hash(for: lines).caseInsensitiveCompare(expectedSHA256) == .orderedSame
    }

    public func verificationResult(data: Data, expectedSHA256: String) -> BulkClaimExportHashVerificationResult {
        BulkClaimExportHashVerificationResult(
            expectedSHA256: expectedSHA256,
            actualSHA256: hash(for: data)
        )
    }
}
