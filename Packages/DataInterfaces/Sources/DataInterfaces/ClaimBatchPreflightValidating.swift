import Core
import Foundation
import PersistenceModels

/// BPR export preflight validation with duplicate claim-reference detection.
@MainActor
public protocol ClaimBatchPreflightValidating: AnyObject, Sendable {
    func validate(lines: [BulkClaimLineSnapshot]) async -> BulkClaimValidationResult
    func validate(lines: [BulkClaimLine]) async -> BulkClaimValidationResult
}
