import CoreLocation
import Foundation
import MapKit
import os

/// Actor-isolated MapKit geocoder with in-memory forward-geocode caching.
///
/// Use this type when you need **pure** address ↔ coordinate resolution without touching SwiftData.
/// For persistence onto `Address` / `Session` entities, prefer `SwiftDataGeocodingService` in Data.
public actor GeocodingService: GeocodingServiceProtocol {

    nonisolated public static let shared = GeocodingService()

    private struct CachedCoordinate: Sendable {
        let latitude: Double
        let longitude: Double
    }

    /// Normalized query → last successful coordinate (bounded to avoid unbounded growth).
    private var forwardGeocodeCache: [String: CachedCoordinate] = [:]
    private let maxForwardCacheEntries = 384

    public init() {}

    // MARK: - Snapshot Helpers

    /// Geocodes an address snapshot payload.
    /// Returns updated coordinates without persisting.
    public func geocodeAddress(_ address: AddressSnapshot) async -> (latitude: Double, longitude: Double)? {
        let fullAddress = address.fullFormattedAddress
        guard !fullAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        if let coordinate = await geocodeAddress(fullAddress) {
            return (coordinate.latitude, coordinate.longitude)
        }
        return nil
    }

    /// Geocodes an address string and returns coordinates (pure function, no persistence)
    public func geocodeAddressString(_ addressString: String) async -> (latitude: Double, longitude: Double)? {
        guard !addressString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        if let coordinate = await geocodeAddress(addressString) {
            return (coordinate.latitude, coordinate.longitude)
        }
        return nil
    }

    /// Reverse geocodes coordinates into a structured, verbose address payload.
    public func reverseGeocodeCoordinates(
        _ coordinate: CLLocationCoordinate2D,
        preferredLocale: Locale? = nil
    ) async -> EventKitLocationParser.ParsedLocation? {
        do {
            return try await MapKitAddressResolver.parseAddress(
                from: coordinate,
                preferredLocale: preferredLocale
            )
        } catch {
            Logger.data.error("Failed reverse geocode for (\(coordinate.latitude), \(coordinate.longitude)): \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Helpers

    private func geocodeAddress(_ address: String) async -> CLLocationCoordinate2D? {
        let key = Self.cacheKey(for: address)
        if let hit = forwardGeocodeCache[key] {
            return CLLocationCoordinate2D(latitude: hit.latitude, longitude: hit.longitude)
        }
        do {
            guard let coord = try await performMainActorGeocode(address) else {
                return nil
            }
            rememberForwardCache(key: key, coordinate: coord)
            return coord
        } catch {
            Logger.data.error("Failed to geocode address: \(address) error: \(error.localizedDescription)")
        }
        return nil
    }

    private func rememberForwardCache(key: String, coordinate: CLLocationCoordinate2D) {
        while forwardGeocodeCache.count >= maxForwardCacheEntries {
            guard let victim = forwardGeocodeCache.keys.randomElement() else { break }
            forwardGeocodeCache.removeValue(forKey: victim)
        }
        forwardGeocodeCache[key] = CachedCoordinate(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
    }

    private nonisolated static func cacheKey(for raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let collapsed = trimmed.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return collapsed.lowercased()
    }

    @MainActor
    private func performMainActorGeocode(_ address: String) async throws -> CLLocationCoordinate2D? {
        let item = try await MapKitAddressResolver.forwardSearch(query: address)
        return item?.location.coordinate
    }
}
