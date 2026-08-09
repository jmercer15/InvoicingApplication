import Foundation

/// Errors shared by individually testable migration transforms.
/// Orchestration and external completion-marker tracking are intentionally absent.
public enum MigrationError: Error, LocalizedError {
    case rollbackFailed(String)
    case validationFailed(String)
    case migrationFailed(String)

    public var errorDescription: String? {
        switch self {
        case let .rollbackFailed(message):
            return "Migration rollback failed: \(message)"
        case let .validationFailed(message):
            return "Migration validation failed: \(message)"
        case let .migrationFailed(message):
            return "Migration failed: \(message)"
        }
    }
}
