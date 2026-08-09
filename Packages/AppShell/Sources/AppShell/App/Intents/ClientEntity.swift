import AppIntents
import Foundation

public struct ClientEntity: AppEntity, Sendable {
    public static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Client")
    }

    public static let defaultQuery = ClientEntityQuery()

    public var id: UUID

    @Property(title: "Name")
    public var displayName: String

    public init(id: UUID, displayName: String) {
        self.id = id
        self.displayName = displayName
    }

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(displayName)")
    }
}

public struct ClientEntityQuery: EntityQuery, EntityStringQuery {
    public init() {}

    @Dependency private var modelAccess: AppIntentModelAccess

    public func entities(for identifiers: [ClientEntity.ID]) async throws -> [ClientEntity] {
        try await modelAccess.clients(for: identifiers)
    }

    public func entities(matching string: String) async throws -> [ClientEntity] {
        try await modelAccess.searchClients(matching: string)
    }

    public func suggestedEntities() async throws -> [ClientEntity] {
        try await modelAccess.suggestedClients()
    }
}
