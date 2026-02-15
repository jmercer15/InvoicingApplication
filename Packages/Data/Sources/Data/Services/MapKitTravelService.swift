//
//  MapKitTravelService.swift
//  Data
//
//  Service for calculating travel details using MapKit directions
//

import Foundation
import MapKit
import CoreLocation
import SwiftData
import Core

// swiftlint:disable concurrency

/// Service for calculating travel details using MapKit directions
@MainActor
class MapKitTravelService: @unchecked Sendable {
    static let shared = MapKitTravelService()
    
    private init() {}
    
    /// Travel details calculated from MapKit
    struct TravelDetails: Sendable {
        let distance: Double // in kilometers
        let time: Double // in minutes
        
        init(distance: Double, time: Double) {
            self.distance = distance
            self.time = time
        }
    }
    
    // MARK: - UnitOfWork-Based Methods (Preferred)
    
    /// Calculate travel details using UnitOfWorkService (preferred)
    /// - Parameters:
    ///   - fromAddress: Starting address string
    ///   - toAddress: Destination address string
    ///   - unitOfWork: Unit of work for business lookup
    /// - Returns: Travel details if successful, nil if calculation fails
    func calculateTravelDetails(
        from fromAddress: String,
        to toAddress: String,
        unitOfWork: UnitOfWorkService
    ) async -> TravelDetails? {
        // Get business address for default origin if needed
        guard let business = try? await unitOfWork.business.fetchFirst(),
              let businessAddress = business.address else {
            print("🗺️ [MapKit Travel] No business address found via UoW")
            return nil
        }
        
        // Parse business coordinates
        let businessCoord = await geocodeAddress(businessAddress.fullFormattedAddress)
        guard let fromCoord = businessCoord else {
            print("🗺️ [MapKit Travel] Could not geocode business address")
            return nil
        }
        
        // Geocode destination
        guard let toCoord = await geocodeAddress(toAddress) else {
            print("🗺️ [MapKit Travel] Could not geocode destination address")
            return nil
        }
        
        return await calculateTravelDetails(from: fromCoord, to: toCoord)
    }
    
    /// Calculate travel details for a session domain model using UoW
    func calculateTravelDetails(
        for session: Session,
        unitOfWork: UnitOfWorkService
    ) async -> TravelDetails? {
        print("🗺️ [MapKit Travel] Calculating travel for session via UoW")
        
        // Get business address
        guard let business = try? await unitOfWork.business.fetchFirst(),
              let businessAddr = business.address else {
            print("🗺️ [MapKit Travel] No business found")
            return nil
        }
        
        let businessCoord = CLLocationCoordinate2D(
            latitude: businessAddr.latitude ?? 0,
            longitude: businessAddr.longitude ?? 0
        )
        
        guard businessCoord.latitude != 0, businessCoord.longitude != 0 else {
            print("🗺️ [MapKit Travel] Business has no coordinates")
            return nil
        }
        
        // Get session location - check if coordinates exist
        var sessionCoord: CLLocationCoordinate2D?
        
        // Try session's location string first via geocoding
        if let location = session.location, !location.isEmpty {
            sessionCoord = await geocodeAddress(location)
        }
        
        guard let destCoord = sessionCoord else {
            print("🗺️ [MapKit Travel] Could not determine session location")
            return nil
        }
        
        return await calculateTravelDetails(from: businessCoord, to: destCoord)
    }
    
    // MARK: - ModelContext-Based Methods (Legacy)
    
    /// Calculate travel details for a single session using individual parameters (legacy)
    func calculateTravelDetailsForSession(
        sessionId: UUID,
        clientId: UUID?,
        startAddress: String?,
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
    
    /// Calculate travel details for a SessionEntity (legacy)
    func calculateTravelDetails(for session: SessionEntity, modelContext: ModelContext) async -> TravelDetails? {
        print("🗺️ [MapKit Travel] Starting travel calculation for session")
        
        // Get business address
        let resolver = EntityResolutionService(context: modelContext)
        guard let business = try? resolver.resolveBusiness(),
              let businessAddress = business.address else {
            print("🗺️ [MapKit Travel] No business address found")
            return nil
        }
        
        // Check if business has coordinates
        guard businessAddress.latitude != 0 && businessAddress.longitude != 0 else {
            print("🗺️ [MapKit Travel] Business has no coordinates")
            return nil
        }
        
        let businessCoord = CLLocationCoordinate2D(
            latitude: businessAddress.latitude,
            longitude: businessAddress.longitude
        )
        
        // Get session coordinates (prefer session coordinates, fall back to address coordinates)
        let sessionCoord: CLLocationCoordinate2D?
        if session.sessionLatitude != 0.0 && session.sessionLongitude != 0.0 {
            sessionCoord = CLLocationCoordinate2D(
                latitude: session.sessionLatitude,
                longitude: session.sessionLongitude
            )
            print("🗺️ [MapKit Travel] Using session coordinates")
        } else if let address = session.address, address.latitude != 0.0 && address.longitude != 0.0 {
            sessionCoord = CLLocationCoordinate2D(
                latitude: address.latitude,
                longitude: address.longitude
            )
            print("🗺️ [MapKit Travel] Using session address coordinates")
        } else {
            print("🗺️ [MapKit Travel] Session has no coordinates")
            sessionCoord = nil
        }
        
        guard let sessionCoordinate = sessionCoord else {
            return nil
        }
        
        print("🗺️ [MapKit Travel] Business coordinates: (\(businessCoord.latitude), \(businessCoord.longitude))")
        print("🗺️ [MapKit Travel] Session coordinates: (\(sessionCoordinate.latitude), \(sessionCoordinate.longitude))")
        
        return await calculateTravelDetails(from: businessCoord, to: sessionCoordinate)
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
    
    // MARK: - Batch Processing (Legacy)
    
    /// Ensures travel details are calculated for all sessions in a list
    func ensureTravelDetailsForSessions(_ sessions: [SessionEntity], modelContext: ModelContext) async -> [String: TravelDetails] {
        print("🗺️ [MapKit Travel] Ensuring travel details for \(sessions.count) sessions")
        
        var travelDetailsMap: [String: TravelDetails] = [:]
        
        let batchSize = 3
        for i in stride(from: 0, to: sessions.count, by: batchSize) {
            let batch = Array(sessions[i..<min(i + batchSize, sessions.count)])
            
            let modelContextCopy = modelContext
            let sessionData = batch.map { session in
                (sessionID: session.id.uuidString, sessionId: session.id, clientId: session.client?.id, location: session.location)
            }
            
            var batchResults: [(String, TravelDetails?)] = []
            for (sessionID, sessionId, clientId, location) in sessionData {
                let details = await MapKitTravelService.shared.calculateTravelDetailsForSession(
                    sessionId: sessionId,
                    clientId: clientId,
                    startAddress: location,
                    endAddress: location,
                    modelContext: modelContextCopy
                )
                batchResults.append((sessionID, details))
            }
            
            for (sessionId, travelDetails) in batchResults {
                if let details = travelDetails {
                    travelDetailsMap[sessionId] = details
                    print("🗺️ [MapKit Travel] Calculated travel details for session: \(sessionId)")
                } else {
                    print("🗺️ [MapKit Travel] Failed to calculate travel details for session: \(sessionId)")
                }
            }
        }
        
        print("🗺️ [MapKit Travel] Completed travel details calculation for \(travelDetailsMap.count) sessions")
        return travelDetailsMap
    }
    
    /// Calculates travel details for a session and updates it with the results (legacy)
    func calculateTravelDetailsForSession(_ session: SessionEntity, modelContext: ModelContext) async -> TravelDetails? {
        let sessionLat = session.sessionLatitude
        let sessionLon = session.sessionLongitude

        if sessionLat != 0 && sessionLon != 0 {
            return await calculateTravelDetails(for: session, modelContext: modelContext)
        }

        if let address = session.address, address.latitude != 0 && address.longitude != 0 {
            return await calculateTravelDetails(for: session, modelContext: modelContext)
        }

        return nil
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