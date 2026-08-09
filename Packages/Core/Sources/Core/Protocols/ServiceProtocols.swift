import Foundation
import CoreLocation

// MARK: - Core System Services

/// Protocol for bulk data wipe (e.g. for reset/import flows). Implemented by the Data layer.
public protocol DataWipeService: Sendable {
    /// Wipe all data. Returns total deleted count and per-entity counts.
    func wipeAllData() async throws -> (totalDeleted: Int, deletedByEntity: [String: Int])
}

// MARK: - Location Services

/// Resolves human-readable addresses to coordinates and coordinates back to structured address payloads.
///
/// Implementations must be safe to call from any isolation domain (`Sendable`). Pure lookup types
/// (for example ``GeocodingService``) perform no persistence; SwiftData-aware variants live in Data.
public protocol GeocodingServiceProtocol: Sendable {
    /// Forward-geocodes a free-form address string.
    ///
    /// - Parameter addressString: Street or postal text to resolve.
    /// - Returns: Latitude/longitude pair when MapKit resolves a match; otherwise `nil`.
    func geocodeAddressString(_ addressString: String) async -> (latitude: Double, longitude: Double)?

    /// Reverse-geocodes a map coordinate into the app's canonical parsed-location shape.
    ///
    /// - Parameters:
    ///   - coordinate: WGS-84 coordinate to resolve.
    ///   - preferredLocale: Optional locale hint for formatted address components.
    /// - Returns: Parsed location metadata suitable for session/address import, or `nil` on failure.
    func reverseGeocodeCoordinates(
        _ coordinate: CLLocationCoordinate2D,
        preferredLocale: Locale?
    ) async -> EventKitLocationParser.ParsedLocation?
}

public protocol MMMZoneLookupProtocol: Sendable {
    func mmm(for coord: CLLocationCoordinate2D) -> Int?
}
