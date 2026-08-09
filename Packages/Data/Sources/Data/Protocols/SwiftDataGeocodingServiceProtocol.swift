import Foundation
import CoreLocation
import SwiftData
import Core
import PersistenceModels

/// SwiftData-aware geocoding contract: resolves coordinates and optionally persists them on entities.
///
/// Conforming types run on the main actor because they mutate `ModelContext`-bound models.
/// For read-only lookup without persistence, use ``GeocodingServiceProtocol`` / ``GeocodingService``.
public protocol SwiftDataGeocodingServiceProtocol: Sendable {
    /// Forward-geocodes a free-form address string without persistence.
    func geocodeAddressString(_ addressString: String) async -> (latitude: Double, longitude: Double)?

    /// Reverse-geocodes coordinates into structured location metadata.
    func reverseGeocodeCoordinates(
        _ coordinate: CLLocationCoordinate2D,
        preferredLocale: Locale?
    ) async -> EventKitLocationParser.ParsedLocation?

    /// Geocodes an `Address` entity and writes latitude/longitude into the supplied context.
    @MainActor func geocodeAndSave(addressEntity: Address, in context: ModelContext, completion: (() -> Void)?)

    /// Geocodes a session's location text and persists coordinates on the session model.
    @MainActor func geocodeAndSave(session: Session, in context: ModelContext, completion: (() -> Void)?)

    /// Alias for ``geocodeAndSave(session:in:completion:)`` retained for legacy call sites.
    @MainActor func geocodeAndSave(sessionEntity: Session, in context: ModelContext, completion: (() -> Void)?)

    /// Ensures the session has coordinates, geocoding and saving when missing.
    @MainActor func ensureCoordinatesForSession(_ session: Session, modelContext: ModelContext) async -> Bool
}
