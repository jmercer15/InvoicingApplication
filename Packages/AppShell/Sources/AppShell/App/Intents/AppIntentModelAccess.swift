import AppIntents
import Core
import PersistenceModels
import Foundation
import SwiftData

public enum AppIntentModelAccessError: LocalizedError, Sendable, Equatable {
    case containerUnavailable
    case clientNotFound(UUID)

    public var errorDescription: String? {
        switch self {
        case .containerUnavailable:
            return "The app database is not ready yet."
        case .clientNotFound(let id):
            return "No client found for id \(id.uuidString)."
        }
    }
}

/// Actor-isolated holder for the shared `ModelContainer`. Intents create ephemeral contexts locally;
/// they must not use `ModelContext` from `perform()` directly across isolation boundaries.
public actor AppIntentModelAccess {
    public static let shared = AppIntentModelAccess()

    private var containerStorage: ModelContainer?

    internal init() {}

    public func adopt(container: ModelContainer) {
        containerStorage = container
    }

    private func resolvedContainer() throws -> ModelContainer {
        guard let containerStorage else {
            throw AppIntentModelAccessError.containerUnavailable
        }
        return containerStorage
    }

    /// Waits until bootstrap adopts the shared container (cold launch / headless Shortcuts).
    public func requireReadyContainer(
        timeout: Duration = .seconds(10),
        pollInterval: Duration = .milliseconds(50)
    ) async throws -> ModelContainer {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if let container = try? resolvedContainer() {
                return container
            }
            try await Task.sleep(for: pollInterval)
        }
        throw AppIntentModelAccessError.containerUnavailable
    }

    public func clientExists(id: UUID) async throws -> Bool {
        let container = try await requireReadyContainer()
        let context = ModelContext(container)
        context.autosaveEnabled = false
        var descriptor = FetchDescriptor<Client>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first != nil
    }

    public func clients(for ids: [UUID]) async throws -> [ClientEntity] {
        guard !ids.isEmpty else { return [] }
        let container = try await requireReadyContainer()
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let fetched = try context.fetch(
            FetchDescriptor<Client>(predicate: #Predicate { ids.contains($0.id) })
        )
        return fetched.map { ClientEntity(id: $0.id, displayName: $0.fullName) }
    }

    public func searchClients(matching query: String, limit: Int = 20) async throws -> [ClientEntity] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return try await suggestedClients(limit: limit)
        }

        let container = try await requireReadyContainer()
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let lowered = trimmed.lowercased()

        // NDIS numbers are stored as entered; predicate handles exact substring match.
        var ndisDescriptor = FetchDescriptor<Client>(
            predicate: #Predicate { client in client.ndisNumber.contains(trimmed) },
            sortBy: [SortDescriptor(\.fullName)]
        )
        ndisDescriptor.fetchLimit = limit
        let ndisMatches = try context.fetch(ndisDescriptor)

        // #Predicate cannot express case-insensitive name contains; bound the scan instead of fetch-all.
        let nameScanLimit = min(max(limit * 10, 50), 500)
        var nameDescriptor = FetchDescriptor<Client>(sortBy: [SortDescriptor(\.fullName)])
        nameDescriptor.fetchLimit = nameScanLimit
        let nameMatches = try context.fetch(nameDescriptor).filter {
            $0.fullName.lowercased().contains(lowered)
        }

        var seen = Set<UUID>()
        var results: [ClientEntity] = []
        results.reserveCapacity(limit)
        for client in ndisMatches + nameMatches where seen.insert(client.id).inserted {
            results.append(ClientEntity(id: client.id, displayName: client.fullName))
            if results.count == limit { break }
        }
        return results
    }

    public func suggestedClients(limit: Int = 10) async throws -> [ClientEntity] {
        let container = try await requireReadyContainer()
        let context = ModelContext(container)
        context.autosaveEnabled = false
        var descriptor = FetchDescriptor<Client>(sortBy: [SortDescriptor(\.fullName)])
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor).map { ClientEntity(id: $0.id, displayName: $0.fullName) }
    }
}
