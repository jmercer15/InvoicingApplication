import CoreLocation
import Foundation

/// Context passed to draft validation rules when building a billable draft.
public struct DraftValidationContext: Sendable {
    public let session: SessionSnapshot
    public let client: ClientSnapshot
    public let billingContext: NDISBillingContext
    public let supportStartDate: Date
    public let draftId: UUID
    public let referenceDate: Date

    public init(
        session: SessionSnapshot,
        client: ClientSnapshot,
        billingContext: NDISBillingContext,
        supportStartDate: Date,
        draftId: UUID,
        referenceDate: Date = Date()
    ) {
        self.session = session
        self.client = client
        self.billingContext = billingContext
        self.supportStartDate = supportStartDate
        self.draftId = draftId
        self.referenceDate = referenceDate
    }

    public var sessionCoordinate: CLLocationCoordinate2D? {
        let lat = session.sessionLatitude
        let lon = session.sessionLongitude
        guard lat != 0 || lon != 0, CLLocationCoordinate2DIsValid(CLLocationCoordinate2D(latitude: lat, longitude: lon)) else {
            return nil
        }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    public var clientCoordinate: CLLocationCoordinate2D? {
        let lat = client.latitude
        let lon = client.longitude
        guard lat != 0 || lon != 0 else { return nil }

        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        guard CLLocationCoordinate2DIsValid(coordinate) else { return nil }
        return coordinate
    }
}
