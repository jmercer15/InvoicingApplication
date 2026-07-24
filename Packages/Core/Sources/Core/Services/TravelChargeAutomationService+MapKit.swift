import Foundation
@preconcurrency import MapKit

extension TravelChargeAutomationService {
    /// Geocodes an address string to CLLocationCoordinate2D using MapKit with retry logic. Returns nil if geocoding fails.
    func geocodeAddressAsync(_ address: String?) async -> CLLocationCoordinate2D? {
        guard let address, !address.isEmpty else { return nil }

        for attempt in 0 ..< 3 {
            do {
                guard let request = MKGeocodingRequest(addressString: address) else {
                    if attempt < 2 {
                        let delay = Double(attempt + 1) * 1.5
                        try? await Task.sleep(for: .seconds(delay))
                        continue
                    }
                    return nil
                }
                let mapItems = try await request.mapItems
                if let firstItem = mapItems.first {
                    return firstItem.location.coordinate
                }
                if attempt < 2 {
                    let delay = Double(attempt + 1) * 1.5
                    try? await Task.sleep(for: .seconds(delay))
                    continue
                }
                return nil
            } catch {
                if attempt < 2 {
                    let delay = Double(attempt + 1) * 1.5
                    try? await Task.sleep(for: .seconds(delay))
                    continue
                }
                return nil
            }
        }
        return nil
    }

    /// Calculates driving distance (in km) between two coordinates using MapKit Directions with retry logic and fallback.
    func calculateDrivingDistanceAsync(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) async -> Double? {
        for attempt in 0 ..< 4 {
            do {
                let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Double?, Error>) in
                    let request = MKDirections.Request()
                    request.source = MKMapItem(location: CLLocation(latitude: from.latitude, longitude: from.longitude), address: nil)
                    request.destination = MKMapItem(location: CLLocation(latitude: to.latitude, longitude: to.longitude), address: nil)
                    request.transportType = .automobile
                    let directions = MKDirections(request: request)

                    let timeoutTask = Task {
                        try? await Task.sleep(for: .seconds(15))
                        if !Task.isCancelled {
                            directions.cancel()
                        }
                    }

                    directions.calculate { response, error in
                        timeoutTask.cancel()
                        if let route = response?.routes.first {
                            continuation.resume(returning: route.distance / 1000.0)
                        } else if let error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: nil)
                        }
                    }
                }
                if let result { return result }
                if attempt < 3 {
                    let delay = Double(attempt + 1) * 2.0
                    try? await Task.sleep(for: .seconds(delay))
                    continue
                }
                return calculateDirectLineDistance(from: from, to: to)
            } catch {
                if attempt < 3 {
                    let delay = Double(attempt + 1) * 2.0
                    try? await Task.sleep(for: .seconds(delay))
                    continue
                }
                return calculateDirectLineDistance(from: from, to: to)
            }
        }
        return calculateDirectLineDistance(from: from, to: to)
    }

    /// Calculates direct-line distance as fallback when routing fails.
    nonisolated private func calculateDirectLineDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double? {
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return fromLocation.distance(from: toLocation) / 1000.0 // Convert meters to km
    }
}

