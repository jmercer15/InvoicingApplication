import Foundation
import CoreLocation
import SwiftData
import Core

public protocol SwiftDataGeocodingServiceProtocol: Sendable {
    func geocodeAddressString(_ addressString: String) async -> (latitude: Double, longitude: Double)?
    func reverseGeocodeCoordinates(
        _ coordinate: CLLocationCoordinate2D,
        preferredLocale: Locale?
    ) async -> EventKitLocationParser.ParsedLocation?
    
    @MainActor func geocodeAndSave(addressEntity: Address, in context: ModelContext, completion: (() -> Void)?)
    @MainActor func geocodeAndSave(session: Session, in context: ModelContext, completion: (() -> Void)?)
    @MainActor func geocodeAndSave(sessionEntity: Session, in context: ModelContext, completion: (() -> Void)?)
    @MainActor func ensureCoordinatesForSession(_ session: Session, modelContext: ModelContext) async -> Bool
}
