import Foundation
import CoreLocation
import SwiftData
import MapKit
import Core

/// SwiftData-facing geocoding: resolves coordinates and **persists** lat/long on entities.
/// For **pure** address → coordinate lookup without persistence, use `Core.GeocodingService` (actor).
@MainActor
public final class SwiftDataGeocodingService: SwiftDataGeocodingServiceProtocol {

    public init() {}
    
    // MARK: - Snapshot / Entity Helpers
    
    /// Geocodes an address snapshot payload.
    /// Returns updated coordinates without persisting.
    public func geocodeAddress(_ address: Address) async -> (latitude: Double, longitude: Double)? {
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
            print("🌍 [GeocodingService] Failed reverse geocode for (\(coordinate.latitude), \(coordinate.longitude)): \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - ModelContext-Based Methods (Legacy)
    /// Geocodes an address string and updates the provided SwiftData entity with latitude and longitude.
    ///
    /// - Parameters:
    ///   - addressEntity: The `Address` to update. The `fullFormattedAddress` property will be used for the lookup.
    ///   - context: The `ModelContext` to perform the update on.
    ///   - completion: An optional closure to be executed after the operation is finished.
    public func geocodeAndSave(addressEntity: Address, in context: ModelContext, completion: (() -> Void)? = nil) {
        let fullAddress = addressEntity.fullFormattedAddress
        let entityID = addressEntity.persistentModelID
        
        guard !fullAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            completion?()
            return
        }
        
        Task {
            if let coordinate = await geocodeAddress(fullAddress) {
                // Re-fetch the entity using the persistentModelID
                let resolver = EntityResolutionService(context: context)
                if let entity: Address = resolver.resolve(persistentModelID: entityID) {
                    entity.latitude = coordinate.latitude
                    entity.longitude = coordinate.longitude
                    do {
                        try context.save()
                    } catch {
                        print("❌ Failed to save context after geocoding: \(error.localizedDescription)")
                    }
                }
                completion?()
            } else {
                completion?()
            }
        }
    }
    
    /// Geocodes an address string for a Session domain model and updates it with latitude and longitude (domain model version)
    ///
    /// - Parameters:
    ///   - session: The `Session` domain model to update. The `location` property will be used for the lookup.
    ///   - context: The `ModelContext` to perform the update on.
    ///   - completion: An optional closure to be executed after the operation is finished.
    public func geocodeAndSave(session: Session, in context: ModelContext, completion: (() -> Void)? = nil) {
        guard let location = session.location, !location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            completion?()
            return
        }
        
        // Fetch entity for update
        let resolver = EntityResolutionService(context: context)
        guard let sessionEntity = try? resolver.resolveSession(id: session.id) else {
            completion?()
            return
        }
        geocodeAndSave(sessionEntity: sessionEntity, in: context, completion: completion)
    }
    
    /// Geocodes an address string for a Session and updates it with latitude and longitude.
    ///
    /// - Parameters:
    ///   - sessionEntity: The `Session` to update. The `location` property will be used for the lookup.
    ///   - context: The `ModelContext` to perform the update on.
    ///   /// - completion: An optional closure to be executed after the operation is finished.
    public func geocodeAndSave(sessionEntity: Session, in context: ModelContext, completion: (() -> Void)? = nil) {
        guard let fullAddress = sessionEntity.location, !fullAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            completion?()
            return
        }
        
        let entityID = sessionEntity.persistentModelID
        
        Task {
            if let coordinate = await geocodeAddress(fullAddress) {
                // Re-fetch the entity using the persistentModelID
                let resolver = EntityResolutionService(context: context)
                if let entity: Session = resolver.resolve(persistentModelID: entityID) {
                    entity.sessionLatitude = coordinate.latitude
                    entity.sessionLongitude = coordinate.longitude
                    do {
                        try context.save()
                    } catch {
                        print("❌ Failed to save context after geocoding: \(error.localizedDescription)")
                    }
                }
                completion?()
            } else {
                completion?()
            }
        }
    }
    
    /// Bulk geocodes sessions and their related entities to ensure coordinates are available (entity version)
    /// This should be called before running auto-determination services
    public func ensureCoordinatesForSession(_ session: Session, modelContext: ModelContext) async -> Bool {
        print("🌍 [GeocodingService] Starting async bulk coordinate check for session: \(session.id.uuidString)")
        
        // Capture the session ID and context info before async operations
        let sessionID = session.persistentModelID
        let sessionLocation = getSessionLocation(session)
        let sessionAddressID = session.address?.persistentModelID
        let clientAddressID = session.client?.address?.persistentModelID
        
        // Ensure all ModelContext operations happen on MainActor
        let entitiesToGeocode = await MainActor.run {
            var entities: [(String, String)] = []
            let resolver = EntityResolutionService(context: modelContext)
            
            // Re-fetch session to check coordinates
            guard let currentSession: Session = resolver.resolve(persistentModelID: sessionID) else {
                return entities
            }
            
            // Check session coordinates
            if currentSession.sessionLatitude == 0 && currentSession.sessionLongitude == 0 {
                if let sessionLocation = sessionLocation {
                    entities.append(("session", sessionLocation))
                    print("🌍 [GeocodingService] Session needs geocoding: \(sessionLocation)")
                }
            }
            
            // Check session address coordinates
            if let sessionAddressID = sessionAddressID {
                if let sessionAddress: Address = resolver.resolve(persistentModelID: sessionAddressID),
                   sessionAddress.latitude == 0 && sessionAddress.longitude == 0 {
                    let addressString = sessionAddress.fullFormattedAddress
                    if !addressString.isEmpty {
                        entities.append(("session_address", addressString))
                        print("🌍 [GeocodingService] Session address needs geocoding: \(addressString)")
                    }
                }
            }
            
            // Check client address coordinates
            if let clientAddressID = clientAddressID {
                if let clientAddress: Address = resolver.resolve(persistentModelID: clientAddressID),
                   clientAddress.latitude == 0 && clientAddress.longitude == 0 {
                    let addressString = clientAddress.fullFormattedAddress
                    if !addressString.isEmpty {
                        entities.append(("client_address", addressString))
                        print("🌍 [GeocodingService] Client address needs geocoding: \(addressString)")
                    }
                }
            }
            
            // Check business address coordinates
            if let business = try? resolver.resolveBusiness(),
               let businessAddress = business.address {
                if businessAddress.latitude == 0 && businessAddress.longitude == 0 {
                    let addressString = businessAddress.fullFormattedAddress
                    if !addressString.isEmpty {
                        entities.append(("business_address", addressString))
                        print("🌍 [GeocodingService] Business address needs geocoding: \(addressString)")
                    }
                }
            }
            
            return entities
        }
        
        if entitiesToGeocode.isEmpty {
            print("🌍 [GeocodingService] All coordinates are already available")
            return true
        }
        
        print("🌍 [GeocodingService] Found \(entitiesToGeocode.count) entities that need geocoding")
        
        // Process geocoding concurrently with a limit
        let batchSize = 2
        var successCount = 0
        
        for i in stride(from: 0, to: entitiesToGeocode.count, by: batchSize) {
            let batch = Array(entitiesToGeocode[i..<min(i + batchSize, entitiesToGeocode.count)])
            
            let batchResults = await withTaskGroup(of: (String, CLLocationCoordinate2D?).self) { group in
                for (entityType, address) in batch {
                    group.addTask {
                        let coordinate = await self.geocodeAddress(address)
                        return (entityType, coordinate)
                    }
                }
                
                var results: [(String, CLLocationCoordinate2D?)] = []
                for await result in group {
                    results.append(result)
                }
                return results
            }
            
            for (entityType, coordinate) in batchResults {
                if let coordinate = coordinate {
                    self.updateEntityCoordinates(entityType: entityType, sessionID: sessionID, coordinates: coordinate, modelContext: modelContext)
                    do {
                        try modelContext.save()
                    } catch {
                        print("❌ [GeocodingService] Failed to save context after geocoding: \(error.localizedDescription)")
                    }
                    successCount += 1
                } else {
                    print("🌍 [GeocodingService] No coordinates found for \(entityType)")
                }
            }
        }
        
        print("🌍 [GeocodingService] Async bulk geocoding completed: \(successCount)/\(entitiesToGeocode.count) successful")
        
        // If session coordinates are missing but session address has coordinates, copy them over
        let resolver = EntityResolutionService(context: modelContext)
        if let currentSession: Session = resolver.resolve(persistentModelID: sessionID),
           currentSession.sessionLatitude == 0 && currentSession.sessionLongitude == 0 {
            if let sessionAddressID = sessionAddressID {
                if let address: Address = resolver.resolve(persistentModelID: sessionAddressID), address.latitude != 0 && address.longitude != 0 {
                    currentSession.sessionLatitude = address.latitude
                    currentSession.sessionLongitude = address.longitude
                    print("🌍 [GeocodingService] Copied session address coordinates to session coordinates: (\(address.latitude), \(address.longitude))")
                    do {
                        try modelContext.save()
                    } catch {
                        print("❌ [GeocodingService] Failed to save context after copying coordinates: \(error.localizedDescription)")
                    }
                }
            }
        }
        
        return successCount > 0
    }
    
    /// Updates the appropriate entity with geocoded coordinates
    private func updateEntityCoordinates(entityType: String, sessionID: PersistentIdentifier, coordinates: CLLocationCoordinate2D, modelContext: ModelContext) {
        let resolver = EntityResolutionService(context: modelContext)
        switch entityType {
        case "session":
            if let session: Session = resolver.resolve(persistentModelID: sessionID) {
                session.sessionLatitude = coordinates.latitude
                session.sessionLongitude = coordinates.longitude
                print("🌍 [GeocodingService] Updated session coordinates: (\(coordinates.latitude), \(coordinates.longitude))")
            }
            
        case "session_address":
            if let session: Session = resolver.resolve(persistentModelID: sessionID),
               let address = session.address {
                address.latitude = coordinates.latitude
                address.longitude = coordinates.longitude
                print("🌍 [GeocodingService] Updated session address coordinates: (\(coordinates.latitude), \(coordinates.longitude))")
            }
            
        case "client_address":
            if let session: Session = resolver.resolve(persistentModelID: sessionID),
               let client = session.client,
               let address = client.address {
                address.latitude = coordinates.latitude
                address.longitude = coordinates.longitude
                print("🌍 [GeocodingService] Updated client address coordinates: (\(coordinates.latitude), \(coordinates.longitude))")
            }
            
        case "business_address":
            if let business = try? resolver.resolveBusiness() {
                business.address?.latitude = coordinates.latitude
                business.address?.longitude = coordinates.longitude
                print("🌍 [GeocodingService] Updated business address coordinates: (\(coordinates.latitude), \(coordinates.longitude))")
            }
            
        default:
            print("🌍 [GeocodingService] Unknown entity type: \(entityType)")
        }
    }
    
    /// Gets the session location string from either location property or address
    private func getSessionLocation(_ session: Session) -> String? {
        // Check session location string first
        if let location = session.location, !location.isEmpty {
            return location
        }
        
        // Check session address entity
        if let address = session.address {
            return address.fullFormattedAddress
        }
        
        return nil
    }
    
    // MARK: - Helpers
    private func geocodeAddress(_ address: String) async -> CLLocationCoordinate2D? {
        do {
            return try await MapKitAddressResolver.forwardSearch(query: address)?.location.coordinate
        } catch {
            print("🌍 [GeocodingService] Failed to geocode address: \(address) error: \(error.localizedDescription)")
        }
        return nil
    }
}
