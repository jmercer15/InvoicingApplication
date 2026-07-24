import Foundation

/// Errors that can occur during persistence operations.
public enum PersistenceError: Error, Sendable {
    case notFound(id: UUID)
    case duplicateEntry(message: String)
    case persistenceFailure(underlying: Error)
    case validationFailed(message: String)
    case concurrencyConflict
    
    public var localizedDescription: String {
        switch self {
        case .notFound(let id):
            return "Entity with id \(id) not found"
        case .duplicateEntry(let message):
            return "Duplicate entry: \(message)"
        case .persistenceFailure(let underlying):
            return "Persistence failure: \(underlying.localizedDescription)"
        case .validationFailed(let message):
            return "Validation failed: \(message)"
        case .concurrencyConflict:
            return "Concurrency conflict detected"
        }
    }
}
