import Foundation

// Pure decision helpers and small value types for EventKit sync.

struct EventKitStaleMissOutcome: Equatable, Sendable {
    let nextMisses: Int
    let shouldMarkStale: Bool
}

enum EventKitReconcileDecision: Equatable, Sendable {
    case prompt
    case push
    case pull
    case skip
}

enum EventKitSyncPolicy {
    static func didReattach(
        hasWindowMatch: Bool,
        hasResolvedMatch: Bool
    ) -> Bool {
        !hasWindowMatch && hasResolvedMatch
    }

    static func staleMissOutcome(
        currentMisses: Int,
        hasWindowMatch: Bool,
        hasResolvedMatch: Bool
    ) -> EventKitStaleMissOutcome {
        if hasWindowMatch || hasResolvedMatch {
            return EventKitStaleMissOutcome(nextMisses: 0, shouldMarkStale: false)
        }

        let nextMisses = max(0, currentMisses) + 1
        return EventKitStaleMissOutcome(
            nextMisses: nextMisses,
            shouldMarkStale: nextMisses >= 2
        )
    }

    static func shouldImportRemoteEvent(
        skipAutoCreate: Bool,
        eventKey: String,
        matchedRemoteKeys: Set<String>,
        remoteIdentityKeys: Set<String>,
        localIdentityKeys: Set<String>
    ) -> Bool {
        guard !skipAutoCreate else { return false }
        guard matchedRemoteKeys.contains(eventKey) else { return false }
        return remoteIdentityKeys.isDisjoint(with: localIdentityKeys)
    }

    static func reconcileDecision(
        syncDirection: CalendarPreferences.SyncDirection,
        conflictResolutionPolicy: CalendarPreferences.ConflictResolutionPolicy,
        localChanged: Bool,
        remoteFreshness: EventKitSyncWatermark.RemoteFreshnessState
    ) -> EventKitReconcileDecision {
        let remoteNeedsAttention = remoteFreshness == .changed || remoteFreshness == .unknown

        switch syncDirection {
        case .appToCalendar:
            return localChanged ? .push : .skip
        case .calendarToApp:
            return remoteNeedsAttention ? .pull : .skip
        case .bidirectional:
            if !localChanged && remoteFreshness == .unchanged {
                return .skip
            }

            switch conflictResolutionPolicy {
            case .prompt:
                if remoteFreshness == .unknown || (localChanged && remoteFreshness == .changed) {
                    return .prompt
                }
                if remoteFreshness == .changed {
                    return .pull
                }
                return localChanged ? .push : .skip
            case .preferCalendar, .remoteWins:
                return remoteNeedsAttention ? .pull : (localChanged ? .push : .skip)
            case .preferApp, .localWins:
                return localChanged ? .push : (remoteNeedsAttention ? .pull : .skip)
            }
        }
    }

    static func orderedOccurrenceDates(_ dates: [Date]) -> [Date] {
        dates.sorted()
    }
}
