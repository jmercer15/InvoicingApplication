//
//  MapKitTravelService.swift
//  Data
//
//  Service for calculating travel details using MapKit directions
//

import Core
import PersistenceModels
import Foundation
import MapKit
import CoreLocation
import SwiftData

/// Service for calculating travel details using MapKit directions.
/// MapKit work runs on the main actor; the actor boundary keeps callers off `@MainActor`.
/// Concurrent MapKit hops are capped to avoid main-thread storms during bulk travel calc.
public actor MapKitTravelService {
    public init() {}

    private let hopGate = MapKitHopGate(maxConcurrent: 2)

    /// Travel details calculated from MapKit
    public struct TravelDetails: Sendable {
        public let distance: Double // in kilometers
        public let time: Double // in minutes

        public init(distance: Double, time: Double) {
            self.distance = distance
            self.time = time
        }
    }

    // MARK: - Snapshot-Based API

    /// Calculate travel details for a session end address from a resolved business coordinate.
    public func calculateTravelDetailsForSession(
        endAddress: String?,
        businessCoordinate: CLLocationCoordinate2D
    ) async -> TravelDetails? {
        if let endAddress = endAddress?.trimmingCharacters(in: .whitespacesAndNewlines),
           !endAddress.isEmpty,
           let destCoord = await geocodeAddress(endAddress) {
            return await calculateTravelDetails(from: businessCoordinate, to: destCoord)
        }
        return nil
    }

    // MARK: - Core Calculation Methods

    /// Calculates travel details between two coordinates using MapKit.
    public func calculateTravelDetails(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D
    ) async -> TravelDetails? {
        guard await hopGate.acquire() else { return nil }
        guard !Task.isCancelled else {
            await hopGate.release()
            return nil
        }
        let result = await performDirections(from: from, to: to)
        await hopGate.release()
        return result
    }

    // MARK: - MainActor MapKit

    @MainActor
    private func performDirections(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D
    ) async -> TravelDetails? {
        let request = MKDirections.Request()
        request.source = MKMapItem(
            location: CLLocation(latitude: from.latitude, longitude: from.longitude),
            address: nil
        )
        request.destination = MKMapItem(
            location: CLLocation(latitude: to.latitude, longitude: to.longitude),
            address: nil
        )
        request.transportType = .automobile

        let directions = MKDirections(request: request)

        do {
            let result = try await directions.calculate()

            if let route = result.routes.first {
                let distanceKm = route.distance / 1000.0
                let timeMinutes = route.expectedTravelTime / 60.0
                return TravelDetails(distance: distanceKm, time: timeMinutes)
            } else {
                return nil
            }
        } catch {
            return nil
        }
    }

    @MainActor
    private func performGeocode(_ address: String) async -> CLLocationCoordinate2D? {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = address
        let search = MKLocalSearch(request: request)

        do {
            let response = try await search.start()
            return response.mapItems.first?.location.coordinate
        } catch {
            return nil
        }
    }

    private func geocodeAddress(_ address: String) async -> CLLocationCoordinate2D? {
        guard await hopGate.acquire() else { return nil }
        guard !Task.isCancelled else {
            await hopGate.release()
            return nil
        }
        let result = await performGeocode(address)
        await hopGate.release()
        return result
    }
}

/// Actor-owned admission control for framework operations that must remain on MainActor.
/// Each waiter has a single continuation; cancellation removes and resumes its own waiter.
actor MapKitHopGate {
    private let maxConcurrent: Int
    private var activeCount = 0
    private var waiters: [UUID: CheckedContinuation<Bool, Never>] = [:]

    init(maxConcurrent: Int) {
        self.maxConcurrent = max(1, maxConcurrent)
    }

    func acquire() async -> Bool {
        guard !Task.isCancelled else { return false }
        guard activeCount >= maxConcurrent else {
            activeCount += 1
            return true
        }

        let waiterID = UUID()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                guard !Task.isCancelled else {
                    continuation.resume(returning: false)
                    return
                }
                waiters[waiterID] = continuation
            }
        } onCancel: {
            Task { await self.cancelWaiter(id: waiterID) }
        }
    }

    func release() {
        precondition(activeCount > 0, "MapKit hop release without an acquired slot")
        guard let waiterID = waiters.keys.first,
              let waiter = waiters.removeValue(forKey: waiterID) else {
            activeCount -= 1
            return
        }
        // Transfer current slot directly. `activeCount` stays unchanged until
        // resumed owner releases it.
        waiter.resume(returning: true)
    }

    func pendingWaiterCount() -> Int { waiters.count }

    private func cancelWaiter(id: UUID) {
        waiters.removeValue(forKey: id)?.resume(returning: false)
    }
}

extension MapKitTravelService {
    /// Resolves business coordinates on the caller's main-actor context before handing snapshots to the actor.
    @MainActor
    public static func resolveBusinessCoordinate(modelContext: ModelContext) -> CLLocationCoordinate2D? {
        let resolver = EntityResolutionService(context: modelContext)
        guard let business = try? resolver.resolveBusiness(),
              let address = business.address,
              address.latitude != 0,
              address.longitude != 0 else {
            print("🗺️ [MapKit Travel] No business address with coordinates found")
            return nil
        }
        return CLLocationCoordinate2D(latitude: address.latitude, longitude: address.longitude)
    }
}
