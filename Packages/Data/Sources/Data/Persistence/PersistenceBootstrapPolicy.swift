import Foundation

public enum PersistenceBootstrapPolicy: Sendable, Equatable {
    case productionSyncRequired
    case localOnly
    case inMemory

    var isStoredInMemoryOnly: Bool {
        if case .inMemory = self {
            return true
        }
        return false
    }

    var cloudSyncEnabled: Bool {
        switch self {
        case .productionSyncRequired:
            return true
        case .localOnly, .inMemory:
            return false
        }
    }
}
