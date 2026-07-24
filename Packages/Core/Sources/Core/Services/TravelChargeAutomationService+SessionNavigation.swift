import Foundation

extension TravelChargeAutomationService {
    /// Determines which travel directions (before/after) are needed for a session, based on its position and location differences.
    func determineTravelDirections(sessionIndex: Int, daySessions: [SessionInstance]) -> [TravelChargeDirection] {
        var directions: [TravelChargeDirection] = []
        let sessionInstance = daySessions[sessionIndex]
        let session = sessionInstance.session

        func normalizedLocation(_ session: SessionAutomationContext?) -> String? {
            guard let loc = session?.location else { return nil }
            return loc.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }

        if isFirstNonTravelSession(sessionIndex: sessionIndex, daySessions: daySessions) {
            directions.append(.before)
        }
        if isLastNonTravelSession(sessionIndex: sessionIndex, daySessions: daySessions) {
            directions.append(.after)
        }
        if sessionIndex > 0 {
            let prev = previousNonTravelSession(sessionIndex: sessionIndex, daySessions: daySessions)
            if let prev, normalizedLocation(prev.session) != normalizedLocation(session) {
                directions.append(.before)
            }
        }
        if sessionIndex < daySessions.count - 1 {
            let next = nextNonTravelSession(sessionIndex: sessionIndex, daySessions: daySessions)
            if let next, normalizedLocation(next.session) != normalizedLocation(session) {
                directions.append(.after)
            }
        }
        return Array(Set(directions))
    }

    /// Returns true if this is the first non-travel session of the day
    private func isFirstNonTravelSession(sessionIndex: Int, daySessions: [SessionInstance]) -> Bool {
        for priorIndex in 0 ..< sessionIndex {
            if !daySessions[priorIndex].session.isTravel { return false }
        }
        return true
    }

    /// Returns true if this is the last non-travel session of the day
    private func isLastNonTravelSession(sessionIndex: Int, daySessions: [SessionInstance]) -> Bool {
        for nextIndex in (sessionIndex + 1) ..< daySessions.count {
            if !daySessions[nextIndex].session.isTravel { return false }
        }
        return true
    }

    /// Finds the previous non-travel session before index i
    func previousNonTravelSession(sessionIndex: Int, daySessions: [SessionInstance]) -> SessionInstance? {
        for priorIndex in stride(from: sessionIndex - 1, through: 0, by: -1) {
            if !daySessions[priorIndex].session.isTravel { return daySessions[priorIndex] }
        }
        return nil
    }

    /// Finds the next non-travel session after index i
    func nextNonTravelSession(sessionIndex: Int, daySessions: [SessionInstance]) -> SessionInstance? {
        for nextIndex in (sessionIndex + 1) ..< daySessions.count {
            if !daySessions[nextIndex].session.isTravel { return daySessions[nextIndex] }
        }
        return nil
    }
}

