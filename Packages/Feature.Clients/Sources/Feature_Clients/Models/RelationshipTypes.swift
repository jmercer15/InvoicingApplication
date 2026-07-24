import Foundation

// MARK: - Entity Filter Enum
public enum EntityFilter: String, CaseIterable, Sendable {
    case all = "all"
    case clients = "clients"
    case payees = "payees"
    case planManagers = "planManagers"

    var displayName: String {
        switch self {
        case .all: return "All"
        case .clients: return "Clients"
        case .payees: return "Payees"
        case .planManagers: return "Plan Managers"
        }
    }
}

// MARK: - Status Filter Enum
public enum StatusFilter: String, CaseIterable, Sendable {
    case all = "all"
    case active = "Active"
    case inactive = "Inactive"

    var displayName: String {
        switch self {
        case .all: return "All Status"
        case .active: return "Active"
        case .inactive: return "Inactive"
        }
    }
}
