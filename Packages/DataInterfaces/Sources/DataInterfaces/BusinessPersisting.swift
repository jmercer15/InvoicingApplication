import PersistenceModels
import Foundation

/// Persists company/business profile edits from Settings.
///
/// Implemented by `SwiftDataBusinessMainContextPersistence` in the Data package.
@MainActor
public protocol BusinessPersisting: AnyObject, Sendable {
    /// Inserts or updates `draft` and nested address, returning the persisted business row.
    func saveBusiness(draft: Business, persisted: Business?) throws -> Business
}
