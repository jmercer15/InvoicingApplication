import AppIntents
import Core
import Data
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

/// Actor-isolated holder for the shared `ModelContainer`. It can bootstrap persistence without a
/// SwiftUI scene, which is required for headless Shortcuts invocations.
public actor AppIntentModelAccess {
    public static let shared = AppIntentModelAccess()

    private var containerStorage: ModelContainer?
    private let containerProvider: @Sendable () async throws -> ModelContainer
    private var bootstrapTask: Task<ModelContainer, Error>?

    internal init() {
        self.containerProvider = Self.bootstrapProductionContainer
    }

    internal init(containerProvider: @escaping @Sendable () async throws -> ModelContainer) {
        self.containerProvider = containerProvider
    }

    public func adopt(container: ModelContainer) {
        containerStorage = container
    }

    /// Resolves eagerly adopted app storage or performs a single shared production bootstrap.
    public func requireReadyContainer() async throws -> ModelContainer {
        if let containerStorage { return containerStorage }

        if bootstrapTask == nil {
            let containerProvider = containerProvider
            bootstrapTask = Task {
                try await containerProvider()
            }
        }

        do {
            guard let bootstrapTask else {
                throw AppIntentModelAccessError.containerUnavailable
            }
            let container = try await bootstrapTask.value
            containerStorage = container
            return container
        } catch {
            bootstrapTask = nil
            throw error
        }
    }

    private nonisolated static func bootstrapProductionContainer() async throws -> ModelContainer {
        try await AppDatabase.bootstrap(policy: .productionSyncRequired).container
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

        // #Predicate cannot express case-insensitive name matching. Scan all names so an
        // alphabetical prefix cannot hide a valid Shortcuts result after an arbitrary limit.
        let nameDescriptor = FetchDescriptor<Client>(sortBy: [SortDescriptor(\.fullName)])
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
