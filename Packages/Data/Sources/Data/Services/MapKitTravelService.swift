//
//  MapKitTravelService.swift
//  Data
//
//  Service for calculating travel details using MapKit directions
//

import Core
import Foundation
import MapKit
import CoreLocation
import SwiftData

/// Service for calculating travel details using MapKit directions
@MainActor
final class MapKitTravelService {
    init() {}
    
    /// Travel details calculated from MapKit
    struct TravelDetails: Sendable {
        let distance: Double // in kilometers
        let time: Double // in minutes
        
        init(distance: Double, time: Double) {
            self.distance = distance
            self.time = time
        }
    }
    
    // MARK: - ModelContext-Based Methods (Legacy)
    
    /// Calculate travel details for a single session using individual parameters (legacy)
    func calculateTravelDetailsForSession(
        endAddress: String?,
        modelContext: ModelContext
    ) async -> TravelDetails? {
        // Get business address coordinates from model context
        let resolver = EntityResolutionService(context: modelContext)
        guard let business = try? resolver.resolveBusiness(),
              let address = business.address,
              address.latitude != 0 && address.longitude != 0 else {
            print("🗺️ [MapKit Travel] No business address with coordinates found")
            return nil
        }
        
        let businessCoord = CLLocationCoordinate2D(latitude: address.latitude, longitude: address.longitude)
        
        // Geocode the end address if provided
        if let endAddress = endAddress, !endAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if let destCoord = await geocodeAddress(endAddress) {
                return await calculateTravelDetails(from: businessCoord, to: destCoord)
            }
        }
        
        return nil
    }
    
    // MARK: - Core Calculation Methods
    
    /// Calculates travel details between two coordinates using MapKit
    func calculateTravelDetails(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) async -> TravelDetails? {
        print("🗺️ [MapKit Travel] Calculating travel details from MapKit directions")
        
        let request = MKDirections.Request()
        if #available(macOS 15.0, *) {
            request.source = MKMapItem(location: CLLocation(latitude: from.latitude, longitude: from.longitude), address: nil)
            request.destination = MKMapItem(location: CLLocation(latitude: to.latitude, longitude: to.longitude), address: nil)
        } else {
            request.source = MKMapItem(location: CLLocation(latitude: from.latitude, longitude: from.longitude), address: nil)
            request.destination = MKMapItem(location: CLLocation(latitude: to.latitude, longitude: to.longitude), address: nil)
        }
        request.transportType = .automobile
        
        let directions = MKDirections(request: request)
        
        do {
            let result = try await directions.calculate()
            
            if let route = result.routes.first {
                let distanceKm = route.distance / 1000.0 // Convert meters to kilometers
                let timeMinutes = route.expectedTravelTime / 60.0 // Convert seconds to minutes
                
                print("🗺️ [MapKit Travel] Route found - Distance: \(distanceKm) km, Time: \(timeMinutes) minutes")
                
                return TravelDetails(distance: distanceKm, time: timeMinutes)
            } else {
                print("🗺️ [MapKit Travel] No route found")
                return nil
            }
        } catch {
            print("🗺️ [MapKit Travel] Error calculating directions: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Helpers
    
    /// Geocode an address string to coordinates
    private func geocodeAddress(_ address: String) async -> CLLocationCoordinate2D? {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = address
        let search = MKLocalSearch(request: request)
        
        do {
            let response = try await search.start()
            return response.mapItems.first?.location.coordinate
        } catch {
            print("🗺️ [MapKit Travel] Geocoding failed for: \(address)")
            return nil
        }
    }
}
