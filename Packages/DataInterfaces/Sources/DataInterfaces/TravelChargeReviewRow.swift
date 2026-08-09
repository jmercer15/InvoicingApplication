import Core
import Foundation
import SwiftData

/// DTO for Settings travel-charge review UI — snapshot fields plus model identity for mutations.
public struct TravelChargeReviewRow: Sendable, Identifiable, Hashable {
    public let snapshot: TravelChargeReviewSnapshot
    public let persistentModelID: PersistentIdentifier

    public var id: UUID { snapshot.id }
    public var reason: String? { snapshot.reason }
    public var timestamp: Date? { snapshot.timestamp }
    public var status: String { snapshot.status }
    public var sessionTitle: String? { snapshot.sessionTitle }
    public var clientName: String? { snapshot.clientName }
    public var violationDetails: [String]? { snapshot.violationDetails }
    public var suggestedActions: [String]? { snapshot.suggestedActions }
    public var overrideOptions: [String]? { snapshot.overrideOptions }

    public var hasViolations: Bool {
        !(snapshot.violations?.isEmpty ?? true) || !(snapshot.violationDetails?.isEmpty ?? true)
    }

    public var violationCount: Int {
        snapshot.violations?.count ?? snapshot.violationDetails?.count ?? 0
    }

    public init(snapshot: TravelChargeReviewSnapshot, persistentModelID: PersistentIdentifier) {
        self.snapshot = snapshot
        self.persistentModelID = persistentModelID
    }
}
