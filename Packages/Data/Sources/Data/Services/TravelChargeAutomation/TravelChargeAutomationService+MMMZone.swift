import Core
import CoreLocation
import Foundation

extension TravelChargeAutomationService {
    /// Looks up the MMM zone for a session using available stored coordinates only.
    func lookupMMMZone(for session: SessionAutomationContext) -> MMMZone? {
        // Prefer explicit session coordinates first.
        if session.sessionLatitude != 0.0, session.sessionLongitude != 0.0 {
            let coordinate = CLLocationCoordinate2D(
                latitude: session.sessionLatitude,
                longitude: session.sessionLongitude
            )
            if let zone = mmmZoneTable.lookup(byCoordinate: coordinate) {
                return zone
            }
        }

        // Reuse any other stored coordinates attached to the session context.
        let candidateCoordinates: [CLLocationCoordinate2D] = [
            CLLocationCoordinate2D(
                latitude: session.address?.latitude ?? 0.0,
                longitude: session.address?.longitude ?? 0.0
            ),
            CLLocationCoordinate2D(
                latitude: session.client?.address?.latitude ?? 0.0,
                longitude: session.client?.address?.longitude ?? 0.0
            ),
        ]

        for coordinate in candidateCoordinates where coordinate.latitude != 0.0 && coordinate.longitude != 0.0 {
            if let zone = mmmZoneTable.lookup(byCoordinate: coordinate) {
                return zone
            }
        }

        return nil
    }
}

public struct MMMZone: Sendable {
    public let name: String
    public let maxTime: Double // in minutes

    public init(name: String, maxTime: Double) {
        self.name = name
        self.maxTime = maxTime
    }
}

public struct MMMZoneTable: Sendable {
    private let mmmZoneLookup: any MMMZoneLookupProtocol

    public init(mmmZoneLookup: any MMMZoneLookupProtocol) {
        self.mmmZoneLookup = mmmZoneLookup
    }

    /// Coordinate-first MMM lookup using polygon data from `MMMZoneLookup`.
    public func lookup(byCoordinate coordinate: CLLocationCoordinate2D) -> MMMZone? {
        guard let mmmCode = mmmZoneLookup.mmm(for: coordinate) else {
            return nil
        }
        return Self.zone(from: mmmCode)
    }

    private static func zone(from mmmCode: Int) -> MMMZone {
        let maxTime: Double = switch mmmCode {
        case 1 ... 3:
            30.0
        case 4 ... 5:
            60.0
        case 6 ... 7:
            .infinity
        default:
            30.0
        }
        return MMMZone(name: "MMM \(mmmCode)", maxTime: maxTime)
    }
}
