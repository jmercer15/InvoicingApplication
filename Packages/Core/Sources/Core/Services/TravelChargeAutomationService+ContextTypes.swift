import Foundation

extension TravelChargeAutomationService {
    /// A wrapper containing a Session snapshot and its pre-fetched relationships as snapshots.
    public struct SessionAutomationContext: Equatable, Hashable, Sendable {
        public let session: SessionSnapshot
        public let client: ClientSnapshot?
        public let service: ClientServiceSnapshot?
        public let ndisItem: NDISItemSnapshot?
        public let address: AddressSnapshot?

        public init(
            session: SessionSnapshot,
            client: ClientSnapshot?,
            service: ClientServiceSnapshot?,
            ndisItem: NDISItemSnapshot?,
            address: AddressSnapshot?
        ) {
            self.session = session
            self.client = client
            self.service = service
            self.ndisItem = ndisItem
            self.address = address
        }

        public static func == (lhs: SessionAutomationContext, rhs: SessionAutomationContext) -> Bool {
            lhs.session.id == rhs.session.id
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(session.id)
        }

        /// Polyfills for legacy entity properties
        public var id: UUID { session.id }
        public var title: String { session.title }
        public var location: String? { session.location }
        public var startTime: Date? { session.startTime }
        public var endTime: Date? { session.endTime }
        public var isTravel: Bool { session.isTravel }
        public var status: SessionStatus { session.status }
        public var sessionLatitude: Double { session.sessionLatitude }
        public var sessionLongitude: Double { session.sessionLongitude }
        public var recurrenceRuleData: Data? { session.recurrenceRuleData }
        public var isAllDay: Bool { session.isAllDay }
        public var notes: String? { session.notes }
        public var groupID: UUID? { session.groupID }
        public var travelCharges: [TravelChargeSnapshot] { session.travelCharges }
        public var clientService: ClientServiceSnapshot? { service }
    }
}

