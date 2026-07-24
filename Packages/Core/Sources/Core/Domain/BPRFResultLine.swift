import Foundation

/// One line from a BPRF (Bulk Payment Results File) import, keyed by claim reference.
public struct BPRFResultLine: Sendable, Equatable {
    public let claimReference: String
    public let submissionStatus: String
    public let paidAmount: Decimal?
    public let errorCode: String?
    public let errorMessage: String?

    public init(
        claimReference: String,
        submissionStatus: String,
        paidAmount: Decimal? = nil,
        errorCode: String? = nil,
        errorMessage: String? = nil
    ) {
        self.claimReference = claimReference
        self.submissionStatus = submissionStatus
        self.paidAmount = paidAmount
        self.errorCode = errorCode
        self.errorMessage = errorMessage
    }
}
