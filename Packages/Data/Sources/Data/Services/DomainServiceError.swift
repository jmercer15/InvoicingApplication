import Foundation

/// Shared error type for domain-service operations.
public enum DomainServiceError: Error, LocalizedError, Sendable {
    case entityNotFound(type: String, id: UUID)
    case invalidOperation(message: String)
    case validationFailed(field: String, reason: String)
    case dependencyMissing(service: String)

    public var errorDescription: String? {
        switch self {
        case let .entityNotFound(type, id):
            return "\(type) not found (\(id.uuidString))"
        case let .invalidOperation(message):
            return message
        case let .validationFailed(field, reason):
            return "Validation failed for \(field): \(reason)"
        case let .dependencyMissing(service):
            return "Missing dependency: \(service)"
        }
    }
}
