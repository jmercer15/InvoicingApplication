import PersistenceModels
import CoreLocation
import Foundation

extension BillingHubProjectionBuilder {
    
    internal struct TravelRateInfo {
        let rate: Decimal
        let unit: String?
    }

    internal struct TravelSuggestion {
        let distanceKilometres: Double?
        let timeMinutes: Double?
    }

    internal static func travelRateInfo(for session: Session, clientServicesCache: [UUID: [ClientService]]) -> TravelRateInfo? {
        guard let clientId = session.clientId, let clientServices = clientServicesCache[clientId] else { return nil }
        let travelService = clientServices.first { service in
            let name = service.serviceName.lowercased()
            return name.contains("travel") || name.contains("transport") || name.contains("km")
        }
        if let travelService {
            return TravelRateInfo(rate: travelService.rate, unit: travelService.unit)
        }
        return nil
    }

    internal static func travelSuggestion(for session: Session, allSessions: [Session]) -> TravelSuggestion {
        var suggestion = TravelSuggestion(distanceKilometres: nil, timeMinutes: nil)
        if let previous = previousSession(before: session, in: allSessions) {
            let metrics = travelMetrics(between: previous, and: session)
            suggestion = TravelSuggestion(distanceKilometres: metrics.distance, timeMinutes: metrics.minutes)
        }
        if (suggestion.distanceKilometres == nil || suggestion.timeMinutes == nil),
           let next = nextSession(after: session, in: allSessions) {
            let metrics = travelMetrics(between: session, and: next)
            let distance = suggestion.distanceKilometres ?? metrics.distance
            let minutes = suggestion.timeMinutes ?? metrics.minutes
            suggestion = TravelSuggestion(distanceKilometres: distance, timeMinutes: minutes)
        }
        return suggestion
    }

    internal static func previousSession(before session: Session, in allSessions: [Session]) -> Session? {
        guard let sessionStart = session.startTime else { return nil }
        return allSessions
            .filter { $0.id != session.id && ($0.endTime ?? $0.startTime ?? .distantPast) <= sessionStart }
            .sorted { ($0.endTime ?? $0.startTime ?? .distantPast) > ($1.endTime ?? $1.startTime ?? .distantPast) }
            .first
    }

    internal static func nextSession(after session: Session, in allSessions: [Session]) -> Session? {
        guard let sessionEnd = session.endTime ?? session.startTime else { return nil }
        return allSessions
            .filter { $0.id != session.id && ($0.startTime ?? .distantFuture) >= sessionEnd }
            .sorted { ($0.startTime ?? .distantFuture) < ($1.startTime ?? .distantFuture) }
            .first
    }

    internal static func travelMetrics(between first: Session, and second: Session) -> (distance: Double?, minutes: Double?) {
        let distance = distanceKilometres(between: first, and: second)
        var minutes: Double? = nil
        if let firstEnd = first.endTime ?? first.startTime, let secondStart = second.startTime {
            let interval = secondStart.timeIntervalSince(firstEnd) / 60.0
            if interval > 0, interval <= (6 * 60) { minutes = interval }
        }
        return (distance, minutes)
    }

    internal static func distanceKilometres(between first: Session, and second: Session) -> Double? {
        guard let firstCoordinate = coordinate(for: first), let secondCoordinate = coordinate(for: second) else { return nil }
        let firstLocation = CLLocation(latitude: firstCoordinate.latitude, longitude: firstCoordinate.longitude)
        let secondLocation = CLLocation(latitude: secondCoordinate.latitude, longitude: secondCoordinate.longitude)
        let metres = firstLocation.distance(from: secondLocation)
        return metres.isFinite ? metres / 1000.0 : nil
    }

    internal static func coordinate(for session: Session) -> CLLocationCoordinate2D? {
        if session.sessionLatitude != 0.0 || session.sessionLongitude != 0.0 {
            return CLLocationCoordinate2D(latitude: session.sessionLatitude, longitude: session.sessionLongitude)
        }
        return nil
    }
}
