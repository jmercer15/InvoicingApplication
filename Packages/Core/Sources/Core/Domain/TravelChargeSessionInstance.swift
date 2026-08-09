import Foundation

/// A wrapper containing a session snapshot and prefetched relationship snapshots for travel automation.
public struct TravelChargeSessionAutomationContext: Equatable, Hashable, Sendable {
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

    public static func == (lhs: TravelChargeSessionAutomationContext, rhs: TravelChargeSessionAutomationContext) -> Bool {
        lhs.session.id == rhs.session.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(session.id)
    }

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

/// Expanded session instance row for travel-charge automation and Settings preview UI.
public struct TravelChargeSessionInstance: Sendable {
    public let session: TravelChargeSessionAutomationContext
    public let instanceStart: Date
    public let instanceEnd: Date

    public init(
        session: TravelChargeSessionAutomationContext,
        instanceStart: Date,
        instanceEnd: Date
    ) {
        self.session = session
        self.instanceStart = instanceStart
        self.instanceEnd = instanceEnd
    }

    public var uniqueInstanceId: String {
        "\(session.id.uuidString)-\(instanceStart.timeIntervalSince1970)"
    }
}

/// Builds expanded session-instance rows for travel charge automation preview lists.
public enum TravelChargeAutomationSessionExpansion {
    public static func buildExpandedInstances(
        from snapshots: [SessionSnapshot],
        rangeStart: Date,
        rangeEnd: Date,
        recurrenceRuleManager: RecurrenceRuleManager
    ) -> [TravelChargeSessionInstance] {
        let recurrenceService = RecurrenceService(recurrenceRuleManager: recurrenceRuleManager)
        let recurringSnapshots = snapshots.filter { $0.recurrenceRuleData != nil }
        let expandedSessionData = recurrenceService.expandRecurringSnapshots(
            recurringSnapshots,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd
        )

        var instances: [TravelChargeSessionInstance] = []

        for sessionData in expandedSessionData {
            let masterSnapshot = sessionData.masterSnapshot
            let context = TravelChargeSessionAutomationContext(
                session: masterSnapshot,
                client: nil,
                service: nil,
                ndisItem: nil,
                address: nil
            )
            for instance in sessionData.instances {
                instances.append(
                    TravelChargeSessionInstance(
                        session: context,
                        instanceStart: instance.instanceStart,
                        instanceEnd: instance.instanceEnd
                    )
                )
            }
        }

        let nonRecurringSnapshots = snapshots.filter { $0.recurrenceRuleData == nil }
        for snapshot in nonRecurringSnapshots {
            if let start = snapshot.startTime {
                let end = snapshot.endTime ?? start
                let context = TravelChargeSessionAutomationContext(
                    session: snapshot,
                    client: nil,
                    service: nil,
                    ndisItem: nil,
                    address: nil
                )
                instances.append(
                    TravelChargeSessionInstance(
                        session: context,
                        instanceStart: start,
                        instanceEnd: end
                    )
                )
            }
        }

        return instances.sorted { $0.instanceStart < $1.instanceStart }
    }
}
