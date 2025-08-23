import Foundation
import CoreLocation
import SwiftData // Import SwiftData
import MapKit

@MainActor
class GeocodingService {
    
    static let shared = GeocodingService()
    
    private init() {}
    
    /// Geocodes an address string and updates the provided SwiftData entity with latitude and longitude.
    ///
    /// - Parameters:
    ///   - addressEntity: The `AddressEntity` to update. The `fullFormattedAddress` property will be used for the lookup.
    ///   - context: The `ModelContext` to perform the update on.
    ///   - completion: An optional closure to be executed after the operation is finished.
    func geocodeAndSave(addressEntity: AddressEntity, in context: ModelContext, completion: (() -> Void)? = nil) {
        let fullAddress = addressEntity.fullFormattedAddress
        let entityID = addressEntity.persistentModelID
        
        guard !fullAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            completion?()
            return
        }
        
        Task {
            if let coordinate = await geocodeAddress(fullAddress) {
                // Re-fetch the entity using the persistentModelID
                let descriptor = FetchDescriptor<AddressEntity>(predicate: #Predicate { $0.persistentModelID == entityID })
                if let entity = try? context.fetch(descriptor).first {
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
    
    /// Geocodes an address string for a SessionEntity and updates it with latitude and longitude.
    ///
    /// - Parameters:
    ///   - sessionEntity: The `SessionEntity` to update. The `location` property will be used for the lookup.
    ///   - context: The `ModelContext` to perform the update on.
    ///   /// - completion: An optional closure to be executed after the operation is finished.
    func geocodeAndSave(sessionEntity: SessionEntity, in context: ModelContext, completion: (() -> Void)? = nil) {
        guard let fullAddress = sessionEntity.location, !fullAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            completion?()
            return
        }
        
        let entityID = sessionEntity.persistentModelID
        
        Task {
            if let coordinate = await geocodeAddress(fullAddress) {
                // Re-fetch the entity using the persistentModelID
                let descriptor = FetchDescriptor<SessionEntity>(predicate: #Predicate { $0.persistentModelID == entityID })
                if let entity = try? context.fetch(descriptor).first {
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
    
    /// Bulk geocodes sessions and their related entities to ensure coordinates are available
    /// This should be called before running auto-determination services
    func ensureCoordinatesForSession(_ session: SessionEntity, modelContext: ModelContext, completion: @escaping (Bool) -> Void) {
        print("🌍 [GeocodingService] Starting bulk coordinate check for session: \(session.id.uuidString)")
        
        Task {
            let success = await self.ensureCoordinatesForSession(session, modelContext: modelContext)
            completion(success)
        }
    }
    
    /// Async version of ensureCoordinatesForSession
    func ensureCoordinatesForSession(_ session: SessionEntity, modelContext: ModelContext) async -> Bool {
        print("🌍 [GeocodingService] Starting async bulk coordinate check for session: \(session.id.uuidString)")
        
        // Capture the session ID and context info before async operations
        let sessionID = session.persistentModelID
        let sessionLocation = getSessionLocation(session)
        let sessionAddressID = session.address?.persistentModelID
        let clientAddressID = session.client?.address?.persistentModelID
        
        // Ensure all ModelContext operations happen on MainActor
        let entitiesToGeocode = await MainActor.run {
            var entities: [(String, String)] = []
            
            // Re-fetch session to check coordinates
            let sessionDescriptor = FetchDescriptor<SessionEntity>(predicate: #Predicate { $0.persistentModelID == sessionID })
            guard let currentSession = try? modelContext.fetch(sessionDescriptor).first else {
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
                let addressDescriptor = FetchDescriptor<AddressEntity>(predicate: #Predicate { $0.persistentModelID == sessionAddressID })
                if let sessionAddress = try? modelContext.fetch(addressDescriptor).first,
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
                let clientAddressDescriptor = FetchDescriptor<AddressEntity>(predicate: #Predicate { $0.persistentModelID == clientAddressID })
                if let clientAddress = try? modelContext.fetch(clientAddressDescriptor).first,
                   clientAddress.latitude == 0 && clientAddress.longitude == 0 {
                    let addressString = clientAddress.fullFormattedAddress
                    if !addressString.isEmpty {
                        entities.append(("client_address", addressString))
                        print("🌍 [GeocodingService] Client address needs geocoding: \(addressString)")
                    }
                }
            }
            
            // Check business address coordinates
            let businessDescriptor = FetchDescriptor<BusinessEntity>()
            if let business = try? modelContext.fetch(businessDescriptor).first,
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
        let sessionDescriptor = FetchDescriptor<SessionEntity>(predicate: #Predicate { $0.persistentModelID == sessionID })
        if let currentSession = try? modelContext.fetch(sessionDescriptor).first,
           currentSession.sessionLatitude == 0 && currentSession.sessionLongitude == 0 {
            if let sessionAddressID = sessionAddressID {
                let addressDescriptor = FetchDescriptor<AddressEntity>(predicate: #Predicate { $0.persistentModelID == sessionAddressID })
                if let address = try? modelContext.fetch(addressDescriptor).first, address.latitude != 0 && address.longitude != 0 {
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
        switch entityType {
        case "session":
            let sessionDescriptor = FetchDescriptor<SessionEntity>(predicate: #Predicate { $0.persistentModelID == sessionID })
            if let session = try? modelContext.fetch(sessionDescriptor).first {
                session.sessionLatitude = coordinates.latitude
                session.sessionLongitude = coordinates.longitude
                print("🌍 [GeocodingService] Updated session coordinates: (\(coordinates.latitude), \(coordinates.longitude))")
            }
            
        case "session_address":
            let sessionDescriptor = FetchDescriptor<SessionEntity>(predicate: #Predicate { $0.persistentModelID == sessionID })
            if let session = try? modelContext.fetch(sessionDescriptor).first,
               let address = session.address {
                address.latitude = coordinates.latitude
                address.longitude = coordinates.longitude
                print("🌍 [GeocodingService] Updated session address coordinates: (\(coordinates.latitude), \(coordinates.longitude))")
            }
            
        case "client_address":
            let sessionDescriptor = FetchDescriptor<SessionEntity>(predicate: #Predicate { $0.persistentModelID == sessionID })
            if let session = try? modelContext.fetch(sessionDescriptor).first,
               let client = session.client,
               let address = client.address {
                address.latitude = coordinates.latitude
                address.longitude = coordinates.longitude
                print("🌍 [GeocodingService] Updated client address coordinates: (\(coordinates.latitude), \(coordinates.longitude))")
            }
            
        case "business_address":
            let businessDescriptor = FetchDescriptor<BusinessEntity>()
            if let business = try? modelContext.fetch(businessDescriptor).first {
                business.address?.latitude = coordinates.latitude
                business.address?.longitude = coordinates.longitude
                print("🌍 [GeocodingService] Updated business address coordinates: (\(coordinates.latitude), \(coordinates.longitude))")
            }
            
        default:
            print("🌍 [GeocodingService] Unknown entity type: \(entityType)")
        }
    }
    
    /// Gets the session location string from either location property or address
    private func getSessionLocation(_ session: SessionEntity) -> String? {
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
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = address
        let search = MKLocalSearch(request: request)
        do {
            let response = try await search.start()
            if let item = response.mapItems.first {
                return item.location.coordinate
            }
        } catch {
            print("🌍 [GeocodingService] Failed to geocode address: \(address) error: \(error.localizedDescription)")
        }
        return nil
    }
} 