import Foundation
import SwiftData
import Core
import PersistenceModels
import Data

@ModelActor
public actor CalendarWorkflowActor {
    
    public func fetchProjectedSessionIDs(
        range: (start: Date, end: Date),
        selectedClientFilterIDs: Set<UUID>,
        showCancelledSessions: Bool,
        allowedStatuses: Set<String>,
        hasStatusFilter: Bool,
        normalizedSearchText: String
    ) throws -> [PersistentIdentifier] {
        let start = range.start
        let end = range.end
        
        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate<Session> { session in
                if let st = session.startTime {
                    if st < end {
                        if session.recurrenceRuleData != nil {
                            return true
                        } else {
                            return st >= start
                        }
                    } else {
                        return false
                    }
                } else {
                    return false
                }
            },
            sortBy: [SortDescriptor(\.startTime)]
        )
        
        let rawSessions = try modelContext.fetch(descriptor)
        
        return rawSessions.filter { s in
            let statusToken = SessionStatus(normalized: s.status?.rawValue ?? "")?.token
            if !showCancelledSessions && statusToken == SessionStatus.cancelled.token {
                return false
            }

            if hasStatusFilter {
                guard let token = statusToken, allowedStatuses.contains(token) else {
                    return false
                }
            }

            if !selectedClientFilterIDs.isEmpty {
                guard let clientID = s.clientId, selectedClientFilterIDs.contains(clientID) else {
                    return false
                }
            }

            if !normalizedSearchText.isEmpty {
                let haystack = [
                    s.title,
                    s.location ?? "",
                    s.notes ?? ""
                ]
                .joined(separator: " ")
                .lowercased()

                if !haystack.contains(normalizedSearchText) {
                    return false
                }
            }

            if s.recurrenceRuleData != nil {
                return (s.startTime ?? .distantFuture) < range.end
            }
            guard let sessionStart = s.startTime else { return false }
            return sessionStart >= range.start && sessionStart < range.end
        }.map(\.persistentModelID)
    }
}
