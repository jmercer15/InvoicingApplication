import Foundation

public enum GSTCode: String, Codable, CaseIterable, Sendable {
    case p1 = "P1"
    case p2 = "P2"
    case p5 = "P5"

    /// NDIS catalogue P2/P5 supplies are GST-free; P1 is taxable.
    public var isGSTFree: Bool {
        switch self {
        case .p2, .p5: return true
        case .p1: return false
        }
    }
}

public enum CancellationPolicyType: String, Codable, CaseIterable, Sendable {
    case sevenDaysDSW = "7_days_dsw"
    case twoClearBusinessDays = "2_clear_business_days"
}

public enum SignatureMethod: String, Codable, CaseIterable, Sendable {
    case signature
    case attestation
    case none
}

public enum BPRClaimTypeCode: String, Codable, CaseIterable, Sendable {
    case canc = "CANC"
    case repw = "REPW"
    case tran = "TRAN"
    case nf2f = "NF2F"
    case thlt = "THLT"
    case irss = "IRSS"
}

public enum CancellationReasonCode: String, Codable, CaseIterable, Sendable {
    case nsdh = "NSDH"
    case nsdf = "NSDF"
    case nsdt = "NSDT"
    case nsdo = "NSDO"
}

public enum BulkClaimBatchStatus: String, Codable, CaseIterable, Sendable {
    case draft
    case validated
    case exported
    case failed
}

public enum BulkClaimSubmissionStatus: String, Codable, CaseIterable, Sendable {
    case pending
    case submitted
    case accepted
    case rejected
    case reconciled
}
