import Foundation
import CoreLocation

// MARK: - Core System Services

/// Protocol for bulk data wipe (e.g. for reset/import flows). Implemented by the Data layer.
public protocol DataWipeService: Sendable {
    /// Wipe all data. Returns total deleted count and per-entity counts.
    func wipeAllData() async throws -> (totalDeleted: Int, deletedByEntity: [String: Int])
}

// MARK: - Location Services

public protocol GeocodingServiceProtocol: Sendable {
    func geocodeAddressString(_ addressString: String) async -> (latitude: Double, longitude: Double)?
    func reverseGeocodeCoordinates(
        _ coordinate: CLLocationCoordinate2D,
        preferredLocale: Locale?
    ) async -> EventKitLocationParser.ParsedLocation?
}

public protocol MMMZoneLookupProtocol: Sendable {
    func mmm(for coord: CLLocationCoordinate2D) -> Int?
}
