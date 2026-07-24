import Foundation

/// Builds expanded session-instance rows for Travel Charge Automation UI preview lists.
/// Runs off the Main Actor when invoked from a detached task with ``SessionSnapshot`` inputs.
public enum TravelChargeAutomationSessionExpansion {
    public static func buildExpandedInstances(
        from snapshots: [SessionSnapshot],
        rangeStart: Date,
        rangeEnd: Date,
        recurrenceRuleManager: RecurrenceRuleManager
    ) -> [TravelChargeAutomationService.SessionInstance] {
        let recurrenceService = RecurrenceService(recurrenceRuleManager: recurrenceRuleManager)
        let recurringSnapshots = snapshots.filter { $0.recurrenceRuleData != nil }
        let expandedSessionData = recurrenceService.expandRecurringSnapshots(
            recurringSnapshots,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd
        )

        var instances: [TravelChargeAutomationService.SessionInstance] = []

        for sessionData in expandedSessionData {
            let masterSnapshot = sessionData.masterSnapshot
            let context = TravelChargeAutomationService.SessionAutomationContext(
                session: masterSnapshot,
                client: nil,
                service: nil,
                ndisItem: nil,
                address: nil
            )
            for instance in sessionData.instances {
                instances.append(
                    TravelChargeAutomationService.SessionInstance(
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
                let context = TravelChargeAutomationService.SessionAutomationContext(
                    session: snapshot,
                    client: nil,
                    service: nil,
                    ndisItem: nil,
                    address: nil
                )
                instances.append(
                    TravelChargeAutomationService.SessionInstance(
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
