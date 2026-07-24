import Foundation
import Observation

/// Tracks last focused tab entities for inspector fallback without owning SwiftUI navigation paths.
@MainActor
@Observable
public final class InvoicesWorkspaceCoordinator {
    /// Last invoice pushed via coordinator sync (inspector fallback when `AppSelection` is briefly nil).
    public private(set) var lastFocusedInvoiceID: UUID?

    public func recordFocusedInvoice(_ id: UUID) {
        lastFocusedInvoiceID = id
    }
}

@MainActor
@Observable
public final class RelationshipsWorkspaceCoordinator {
    /// Mirrors the last relationship targeted through navigation helpers (inspector fallback).
    public private(set) var lastRelationshipSelection: AppSelection?

    /// Inspector fallback only (no ``path`` mutation).
    public func recordFocusedRelationship(selection: AppSelection?) {
        switch selection {
        case .client, .payee, .planManager:
            lastRelationshipSelection = selection
        default:
            break
        }
    }
}

@MainActor
@Observable
public final class NDISWorkspaceCoordinator {
    public private(set) var lastFocusedNDISItemID: UUID?

    public func recordFocusedNDISItem(_ id: UUID) {
        lastFocusedNDISItemID = id
    }
}

// MARK: - Inspector selection fallback (secondary window / timing gaps)

extension AppNavigationManager {
    /// When ``selection`` is momentarily nil, recover the last targets recorded by tab coordinators.
    public func inspectorFallbackSelection() -> AppSelection? {
        if let id = invoicesCoordinator.lastFocusedInvoiceID {
            return .invoice(id)
        }
        if let rel = relationshipsCoordinator.lastRelationshipSelection {
            return rel
        }
        if let id = ndisCoordinator.lastFocusedNDISItemID {
            return .ndisItem(id)
        }
        return nil
    }
}
