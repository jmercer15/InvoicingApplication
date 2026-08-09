import Foundation

/// Lightweight database connectivity probe for Settings health checks.
///
/// Implemented by `SwiftDataDatabaseHealthChecker` in the Data package.
@MainActor
public protocol DatabaseHealthChecking: AnyObject, Sendable {
    func verifyConnection() throws
}
