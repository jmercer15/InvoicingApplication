import Foundation
import CoreLocation
import SwiftData
import MapKit
import os
import Core
import PersistenceModels

/// SwiftData-facing geocoding: resolves coordinates and **persists** lat/long on entities.
/// For **pure** address → coordinate lookup without persistence, use `Core.GeocodingService` (actor).
@MainActor
public final class SwiftDataGeocodingService: SwiftDataGeocodingServiceProtocol {
    private static let logger = Logger(subsystem: "com.invoicingapplication.app", category: "geocoding")

    public init() {}
    
    // MARK: - Snapshot / Entity Helpers
    
    /// Geocodes an address snapshot payload.
    /// Returns updated coordinates without persisting.
    public func geocodeAddress(_ address: Address) async -> (latitude: Double, longitude: Double)? {
        await GeocodingService.shared.geocodeAddress(address.snapshot())
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
            Self.logger.error("Reverse geocoding failed.")
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
                        Self.logger.error("Failed to save geocoded address.")
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
                        Self.logger.error("Failed to save geocoded session.")
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
        Self.logger.debug("Starting bulk coordinate check.")
        
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
                    Self.logger.debug("Session coordinates need geocoding.")
                }
            }
            
            // Check session address coordinates
            if let sessionAddressID = sessionAddressID {
                if let sessionAddress: Address = resolver.resolve(persistentModelID: sessionAddressID),
                   sessionAddress.latitude == 0 && sessionAddress.longitude == 0 {
                    let addressString = sessionAddress.fullFormattedAddress
                    if !addressString.isEmpty {
                        entities.append(("session_address", addressString))
                        Self.logger.debug("Session address coordinates need geocoding.")
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
                        Self.logger.debug("Client address coordinates need geocoding.")
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
                        Self.logger.debug("Business address coordinates need geocoding.")
                    }
                }
            }
            
            return entities
        }
        
        if entitiesToGeocode.isEmpty {
            Self.logger.debug("All coordinates already available.")
            return true
        }
        
        Self.logger.debug("Geocoding \(entitiesToGeocode.count, privacy: .public) entities.")
        
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
                        Self.logger.error("Failed to save bulk geocoding result.")
                    }
                    successCount += 1
                } else {
                    Self.logger.debug("No coordinates found for \(entityType, privacy: .public).")
                }
            }
        }
        
        Self.logger.debug("Bulk geocoding completed: \(successCount, privacy: .public)/\(entitiesToGeocode.count, privacy: .public).")
        
        // If session coordinates are missing but session address has coordinates, copy them over
        let resolver = EntityResolutionService(context: modelContext)
        if let currentSession: Session = resolver.resolve(persistentModelID: sessionID),
           currentSession.sessionLatitude == 0 && currentSession.sessionLongitude == 0 {
            if let sessionAddressID = sessionAddressID {
                if let address: Address = resolver.resolve(persistentModelID: sessionAddressID), address.latitude != 0 && address.longitude != 0 {
                    currentSession.sessionLatitude = address.latitude
                    currentSession.sessionLongitude = address.longitude
                    Self.logger.debug("Copied session address coordinates.")
                    do {
                        try modelContext.save()
                    } catch {
                        Self.logger.error("Failed to save copied session coordinates.")
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
                Self.logger.debug("Updated session coordinates.")
            }
            
        case "session_address":
            if let session: Session = resolver.resolve(persistentModelID: sessionID),
               let address = session.address {
                address.latitude = coordinates.latitude
                address.longitude = coordinates.longitude
                Self.logger.debug("Updated session address coordinates.")
            }
            
        case "client_address":
            if let session: Session = resolver.resolve(persistentModelID: sessionID),
               let client = session.client,
               let address = client.address {
                address.latitude = coordinates.latitude
                address.longitude = coordinates.longitude
                Self.logger.debug("Updated client address coordinates.")
            }
            
        case "business_address":
            if let business = try? resolver.resolveBusiness() {
                business.address?.latitude = coordinates.latitude
                business.address?.longitude = coordinates.longitude
                Self.logger.debug("Updated business address coordinates.")
            }
            
        default:
            Self.logger.error("Unknown geocoding entity type: \(entityType, privacy: .public).")
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
            Self.logger.error("Address geocoding failed.")
        }
        return nil
    }
}
