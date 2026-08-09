import Core
import Foundation

struct ClientDayKey: Hashable {
    let clientId: UUID
    let day: Date
}

extension TravelChargeAutomationService {
    /// Expands sessions into instances (handles recurring sessions)
    func expandSessionsToInstances(_ sessions: [SessionAutomationContext], dateRange: ClosedRange<Date>? = nil) -> [SessionInstance] {
        var instances: [SessionInstance] = []
        let calendar = Calendar.current

        let (rangeStart, rangeEnd): (Date, Date)
        if let dateRange {
            rangeStart = dateRange.lowerBound
            rangeEnd = dateRange.upperBound
        } else {
            let today = Date()
            let startOfDay = calendar.startOfDay(for: today)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            rangeStart = startOfDay
            rangeEnd = endOfDay
        }

        for session in sessions {
            if session.recurrenceRuleData == nil {
                if let startTime = session.startTime {
                    instances.append(SessionInstance(session: session, instanceStart: startTime, instanceEnd: session.endTime ?? startTime))
                }
                continue
            }

            if let ruleData = session.recurrenceRuleData,
               let rule = recurrenceRuleManager.deserialize(ruleData),
               let sessionStartTime = session.startTime,
               let sessionEndTime = session.endTime {
                let expanded = RecurrenceExpansion.expandInstances(
                    for: session.session,
                    rule: rule,
                    masterStartTime: sessionStartTime,
                    masterEndTime: sessionEndTime,
                    rangeStart: rangeStart,
                    rangeEnd: rangeEnd
                )

                for instance in expanded {
                    instances.append(SessionInstance(session: session, instanceStart: instance.instanceStart, instanceEnd: instance.instanceEnd))
                }
            }
        }

        return instances
    }

    func groupSessionsByClientAndDay(_ sessions: [SessionInstance]) -> [ClientDayKey: [SessionInstance]] {
        var result: [ClientDayKey: [SessionInstance]] = [:]
        let calendar = Calendar.current
        for sessionInstance in sessions {
            guard let client = sessionInstance.session.client else { continue }
            let day = calendar.startOfDay(for: sessionInstance.instanceStart)
            let key = ClientDayKey(clientId: client.id, day: day)
            result[key, default: []].append(sessionInstance)
        }
        return result
    }

    func sortSessionsChronologically(_ sessions: [SessionInstance]) -> [SessionInstance] {
        sessions.sorted { $0.instanceStart < $1.instanceStart }
    }
}
