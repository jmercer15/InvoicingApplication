import Foundation
import Core

/// Forces `CalendarView` to rebuild its `@Query` when the visible window changes.
struct CalendarQueryRangeIdentity: Hashable {
    let start: Date
    let end: Date

    init(_ range: (start: Date, end: Date)) {
        start = range.start
        end = range.end
    }
}

struct CalendarSessionWindowProjection {
    let entities: [Session]
    let range: (start: Date, end: Date)
    let selectedClientFilterIDs: Set<UUID>
    let showCancelledSessions: Bool
    let allowedStatuses: Set<String>
    let hasStatusFilter: Bool
    let normalizedSearchText: String

    func filteredSessions() -> [Session] {
        entities.filter { s in
            let statusToken = SessionStatus(normalized: s.status?.rawValue ?? "")?.token
            if !showCancelledSessions && statusToken == SessionStatus.cancelled.token {
                return false
            }

            if hasStatusFilter {
                guard let statusToken, allowedStatuses.contains(statusToken) else {
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
            guard let start = s.startTime else { return false }
            return start >= range.start && start < range.end
        }
    }

    struct TaskId: Equatable {
        let start: Date
        let end: Date
        let sourceCount: Int
        let filterSignature: String
    }

    var taskID: TaskId {
        TaskId(
            start: range.start,
            end: range.end,
            sourceCount: entities.count,
            filterSignature: filterSignature
        )
    }

    private var filterSignature: String {
        let statusKey = allowedStatuses.sorted().joined(separator: "|")
        let clientKey = selectedClientFilterIDs
            .map(\.uuidString)
            .sorted()
            .joined(separator: "|")
        return [
            showCancelledSessions ? "includeCancelled" : "excludeCancelled",
            hasStatusFilter ? "statusFiltered" : "statusAll",
            statusKey,
            clientKey,
            normalizedSearchText
        ].joined(separator: "||")
    }
}
