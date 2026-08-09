import Core
import CoreLocation
import Foundation

extension TravelChargeAutomationService {
    /// Determines which charge types (labour, non-labour, activity-based) apply to a session.
    func determineChargeTypes(session: SessionAutomationContext) async -> [String] {
        var types: [String] = []

        if isPrimarySupportEligibleForTravel(session) {
            types.append("labour")
        }

        if isPrimarySupportEligibleForTravel(session) {
            types.append("non-labour")
        }

        return types
    }

    /// Detects shared travel participants for a session by looking for other sessions near the same time and location.
    func detectSharedTravelParticipantsAsync(
        session: SessionAutomationContext,
        daySessions: [SessionInstance],
        direction: TravelChargeDirection
    ) async -> [SessionAutomationContext] {
        var locationCache: [UUID: CLLocationCoordinate2D] = [:]

        for daySession in daySessions {
            let coord = await geocodeAddressAsync(daySession.session.location)
            if let coord {
                locationCache[daySession.session.id] = coord
            }
        }

        guard let tCoord = await geocodeAddressAsync(session.location) else { return [session] }

        let targetTime: Date? = (direction == .before) ? session.startTime : session.endTime
        guard let tTime = targetTime else { return [session] }

        let distanceThreshold: Double = 1000.0 // meters
        let timeThreshold: TimeInterval = 60 * 30 // 30 mins

        let matches = daySessions.filter { otherInstance in
            let other = otherInstance.session
            guard other.id != session.id, !other.isTravel else { return false }

            let otherTime: Date = (direction == .before) ? otherInstance.instanceStart : otherInstance.instanceEnd
            let timeDiff = abs(otherTime.timeIntervalSince(tTime))

            guard timeDiff <= timeThreshold else { return false }
            guard let oCoord = locationCache[other.id] else { return false }

            let loc1 = CLLocation(latitude: tCoord.latitude, longitude: tCoord.longitude)
            let loc2 = CLLocation(latitude: oCoord.latitude, longitude: oCoord.longitude)
            let dist = loc1.distance(from: loc2)

            return dist <= distanceThreshold
        }

        return [session] + matches.map { $0.session }
    }
}

