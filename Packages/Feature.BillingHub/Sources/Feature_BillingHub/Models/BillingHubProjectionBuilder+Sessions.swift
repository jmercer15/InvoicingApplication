import Core
import Foundation

extension BillingHubProjectionBuilder {
    
    internal static func filterSessions(
        _ sourceSessions: [Session],
        clients: [Client],
        searchText: String,
        selectedClientID: UUID?
    ) -> [Session] {
        var sessions = sourceSessions

        if let selectedClientID {
            sessions = sessions.filter { $0.clientId == selectedClientID }
        }

        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedQuery.isEmpty {
            sessions = sessions.filter { session in
                let clientName = clients.first(where: { $0.id == session.clientId })?.fullName ?? ""
                return session.title.localizedCaseInsensitiveContains(trimmedQuery) ||
                    clientName.localizedCaseInsensitiveContains(trimmedQuery) ||
                    (session.assignedServiceName?.localizedCaseInsensitiveContains(trimmedQuery) ?? false)
            }
        }

        return sessions
    }

    internal static func mapSessionToKanbanCard(
        _ session: Session,
        clients: [Client],
        clientServicesCache: [UUID: [ClientService]],
        allSessions: [Session]
    ) -> KanbanCardData? {
        guard let columnType = mapBillingStatus(for: session) else { return nil }
        let sessionId = session.id

        let title = session.title
        let clientName = clients.first(where: { $0.id == session.clientId })?.fullName ?? "Client"
        let serviceName = session.assignedServiceName ?? session.title
        let hasIssues = session.assignedServiceName == nil || session.clientId == nil
        let date = session.startTime?.formatted(.dateTime.day(.twoDigits).month(.twoDigits).year()) ?? ""
        var duration: String = "-"

        if let startTime = session.startTime, let endTime = session.endTime {
            let components = Calendar.current.dateComponents([.hour, .minute], from: startTime, to: endTime)
            if let hours = components.hour, let minutes = components.minute {
                let totalMinutes = Double(hours * 60 + minutes)
                if totalMinutes > 0 {
                    duration = String(format: "%.1f", totalMinutes / 60.0) + "h"
                }
            }
        }

        let workflowStatus = columnType.workflowStatus
        let accentColor = columnType.laneTint
        let priority = hasIssues ? Priority.high : .low
        let rateInfo = travelRateInfo(for: session, clientServicesCache: clientServicesCache)
        let travelSuggestion = travelSuggestion(for: session, allSessions: allSessions)
        let displayDistance = session.travelDistanceKM ?? travelSuggestion.distanceKilometres
        let displayTime = session.travelTimeMinutes ?? travelSuggestion.timeMinutes

        let sessionCardData = SessionKanbanCardData(
            sessionId: sessionId,
            title: title,
            clientName: clientName,
            serviceName: serviceName,
            travelRate: session.assignedRate ?? rateInfo?.rate,
            travelRateUnit: rateInfo?.unit,
            suggestedTravelDistanceKM: displayDistance,
            suggestedTravelTimeMinutes: displayTime,
            priority: priority,
            accentColor: accentColor,
            duration: duration,
            date: date,
            hasIssues: hasIssues,
            workflowStatus: workflowStatus,
            columnType: columnType,
            startTime: session.startTime,
            endTime: session.endTime,
            groupID: session.groupID
        )
        return .session(sessionCardData)
    }

    internal static func mapBillingStatus(for session: Session) -> KanbanCardData.BillingColumnType? {
        switch canonicalSessionStatusToken(session.statusToken) {
        case "completed": return .completed
        case "grouped": return .grouped
        case "needs_travel": return .addTravel
        default: return nil
        }
    }

    internal static func canonicalSessionStatusToken(_ status: String?) -> String? {
        guard let status, ["scheduled", "completed", "cancelled", "no_show", "rescheduled", "grouped", "needs_travel", "review_draft", "ready_to_send", "pending", "received"].contains(status) else { return nil }
        return status
    }
}
