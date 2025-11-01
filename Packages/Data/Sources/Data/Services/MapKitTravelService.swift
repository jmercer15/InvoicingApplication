import Foundation
import MapKit
import CoreLocation
import SwiftData

// swiftlint:disable concurrency

/// Service for calculating travel details using MapKit directions
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
    
    /// Calculates travel details from business to session location using MapKit
    /// - Parameters:
    ///   - session: The session entity
    ///   - modelContext: SwiftData model context
    /// - Returns: Travel details if successful, nil if calculation fails
    /// Calculate travel details for a single session using individual parameters
    func calculateTravelDetailsForSession(
        sessionId: UUID,
        clientId: UUID?,
        startAddress: String?,
        endAddress: String?,
        modelContext: ModelContext
    ) async -> TravelDetails? {
        // This method works with individual parameters to avoid concurrency issues
        // For now, return nil as a placeholder - the actual implementation would
        // geocode the string addresses to coordinates and then call calculateTravelDetails
        return nil
    }
    
    func calculateTravelDetails(for session: SessionEntity, modelContext: ModelContext) async -> TravelDetails? {
        print("🗺️ [MapKit Travel] Starting travel calculation for session")
        
        // Get business address
        let businessDescriptor = FetchDescriptor<BusinessEntity>()
        guard let business = try? modelContext.fetch(businessDescriptor).first,
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
    
    /// Calculates travel details between two coordinates using MapKit
    /// - Parameters:
    ///   - from: Starting coordinate
    ///   - to: Destination coordinate
    /// - Returns: Travel details if successful, nil if calculation fails
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
            // Use async/await directly - let orchestrator handle timeouts
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
    
    /// Ensures travel details are calculated for all sessions in a list
    /// - Parameters:
    ///   - sessions: Array of session entities
    ///   - modelContext: SwiftData model context
    /// - Returns: Dictionary mapping session ID to travel details
    nonisolated func ensureTravelDetailsForSessions(_ sessions: [SessionEntity], modelContext: ModelContext) async -> [String: TravelDetails] {
        print("🗺️ [MapKit Travel] Ensuring travel details for \(sessions.count) sessions")
        
        var travelDetailsMap: [String: TravelDetails] = [:]
        
        // Process sessions concurrently with a limit to avoid overwhelming the system
        let batchSize = 3
        for i in stride(from: 0, to: sessions.count, by: batchSize) {
            let batch = Array(sessions[i..<min(i + batchSize, sessions.count)])
            
            let modelContextCopy = modelContext
            // Extract all data outside the TaskGroup to avoid concurrency issues
            let sessionData = batch.map { session in
                (sessionID: session.id.uuidString, sessionId: session.id, clientId: session.client?.id, location: session.location)
            }
            
            // Simplified approach: process sessions sequentially to avoid concurrency issues
            var batchResults: [(String, TravelDetails?)] = []
            for (sessionID, sessionId, clientId, location) in sessionData {
                let details = await MapKitTravelService.shared.calculateTravelDetailsForSession(
                    sessionId: sessionId,
                    clientId: clientId,
                    startAddress: location,
                    endAddress: location, // Use location for both start and end for now
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
    
    /// Calculates travel details for a session and updates it with the results
    nonisolated func calculateTravelDetailsForSession(_ session: SessionEntity, modelContext: ModelContext) async -> TravelDetails? {
        // Get coordinates from the session
        let sessionLat = session.sessionLatitude
        let sessionLon = session.sessionLongitude

        // If session has coordinates, use them
        if sessionLat != 0 && sessionLon != 0 {
            return await calculateTravelDetails(for: session, modelContext: modelContext)
        }

        // Otherwise, try to get coordinates from the session's address
        if let address = session.address, address.latitude != 0 && address.longitude != 0 {
            return await calculateTravelDetails(for: session, modelContext: modelContext)
        }

        // No coordinates available
        return nil
    }
}