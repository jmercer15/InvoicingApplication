import Core
import PersistenceModels
import Foundation

/// Session and business snapshots for travel-charge automation test bootstrap.
public struct TravelChargeBootstrapData: Sendable, Equatable {
    public let sessions: [SessionSnapshot]
    public let primaryBusiness: BusinessSnapshot?

    public init(sessions: [SessionSnapshot], primaryBusiness: BusinessSnapshot?) {
        self.sessions = sessions
        self.primaryBusiness = primaryBusiness
    }
}
