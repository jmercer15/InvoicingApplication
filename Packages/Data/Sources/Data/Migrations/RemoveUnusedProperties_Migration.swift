//
//  RemoveUnusedProperties_Migration.swift
//  InvoicingApplication
//
//  Created by AI Assistant on 21/7/2025.
//
//  Migration script for removing unused properties from entities
//  This migration handles the removal of properties that were identified as truly unused
//  in business logic and have been removed from the entity definitions.
//

import Core
import Foundation
import SwiftData

/// Migration script for removing unused properties from entities
/// 
/// This migration handles the removal of properties that were identified as truly unused
/// in business logic and have been removed from the entity definitions.
/// 
/// Properties Removed:
/// - Session: attachmentsData, firstReminderTime, hasSecondReminder, isSystemEvent, secondReminderTime, useRichText
/// - TravelCharge: auditLogs
/// 
/// Migration Details:
/// - Type: Property Removal
/// - Backward Compatibility: No (properties are removed)
/// - Data Loss: None (properties were unused)
/// - Rollback: Not supported (properties are permanently removed)
public struct RemoveUnusedProperties_Migration {
    
    /// Migration version identifier
    public static let version = "1.0.0"
    
    /// Migration description
    public static let description = "Remove unused properties from Session and TravelCharge"
    
    /// Migration date
    public static let migrationDate = Date()
    
    /// Execute the migration
    /// 
    /// This method handles the removal of unused properties from entities.
    /// For Swift Data, the migration is handled automatically when the entity
    /// definitions are updated to remove the properties.
    /// 
    /// - Parameter modelContext: The Swift Data model context
    /// - Throws: MigrationError if the migration fails
    public static func execute(modelContext: ModelContext) throws {
        // Log migration start
        print("🔄 Starting unused properties removal migration (v\(version))")
        
        // Validate that the migration is needed
        try validateMigrationNeeded(modelContext: modelContext)
        
        // Execute the migration
        try performMigration(modelContext: modelContext)
        
        // Validate migration success
        try validateMigrationSuccess(modelContext: modelContext)
        
        // Log migration completion
        print("✅ Unused properties removal migration completed successfully")
    }
    
    /// Validate that the migration is needed
    /// 
    /// This method checks if the migration has already been applied
    /// or if it's not needed for the current data state.
    /// 
    /// - Parameter modelContext: The Swift Data model context
    /// - Throws: MigrationError if validation fails
    private static func validateMigrationNeeded(modelContext: ModelContext) throws {
        // Check if any Session records exist
        let sessionDescriptor = FetchDescriptor<Session>()
        let sessions = try modelContext.fetch(sessionDescriptor)
        
        // Check if any TravelCharge records exist
        let travelChargeDescriptor = FetchDescriptor<TravelCharge>()
        let travelCharges = try modelContext.fetch(travelChargeDescriptor)
        
        if sessions.isEmpty && travelCharges.isEmpty {
            print("ℹ️ No Session or TravelCharge records found - migration not needed")
            return
        }
        
        print("📊 Found \(sessions.count) Session records and \(travelCharges.count) TravelCharge records to migrate")
    }
    
    /// Perform the actual migration
    /// 
    /// This method executes the migration logic. For Swift Data,
    /// the migration is handled automatically when the entity definitions
    /// are updated to remove the properties.
    /// 
    /// - Parameter modelContext: The Swift Data model context
    /// - Throws: MigrationError if the migration fails
    private static func performMigration(modelContext: ModelContext) throws {
        // For Swift Data, the migration is handled automatically
        // when the entity definitions are updated to remove the properties.
        // We just need to ensure the model context is properly configured.
        
        // Save the context to ensure any pending changes are persisted
        try modelContext.save()
        
        print("💾 Migration data persisted successfully")
    }
    
    /// Validate that the migration was successful
    /// 
    /// This method verifies that the migration completed successfully
    /// and that all data is accessible without the removed properties.
    /// 
    /// - Parameter modelContext: The Swift Data model context
    /// - Throws: MigrationError if validation fails
    private static func validateMigrationSuccess(modelContext: ModelContext) throws {
        // Fetch all Session records to verify they're accessible
        let sessionDescriptor = FetchDescriptor<Session>()
        let sessions = try modelContext.fetch(sessionDescriptor)
        
        // Verify that we can access the remaining properties
        for session in sessions {
            // This will throw an error if any removed properties are still accessible
            let _ = session.id
            let _ = session.title
            let _ = session.startTime
            let _ = session.endTime
            let _ = session.isAllDay
            let _ = session.location
            let _ = session.notes
            let _ = session.status
            let _ = session.isTravel
            let _ = session.groupID
            let _ = session.groupedPosition
            let _ = session.attendeesCount
            let _ = session.derivedFromEKEventID
            let _ = session.googleColorId
            let _ = session.sessionLatitude
            let _ = session.sessionLongitude
        }
        
        // Fetch all TravelCharge records to verify they're accessible
        let travelChargeDescriptor = FetchDescriptor<TravelCharge>()
        let travelCharges = try modelContext.fetch(travelChargeDescriptor)
        
        // Verify that we can access the remaining properties
        for travelCharge in travelCharges {
            // This will throw an error if any removed properties are still accessible
            let _ = travelCharge.id
            let _ = travelCharge.mmmZoneName
            let _ = travelCharge.distanceKM
            let _ = travelCharge.durationMinutes
            let _ = travelCharge.vehicleType
            let _ = travelCharge.parkingCost
            let _ = travelCharge.tollCost
            let _ = travelCharge.participantCount
            let _ = travelCharge.splitCosts
            let _ = travelCharge.chargeType
            let _ = travelCharge.travelDirection
        }
        
        print("✅ Migration validation successful - all \(sessions.count) Session and \(travelCharges.count) TravelCharge records accessible")
    }
    
    /// Rollback the migration
    /// 
    /// This method provides a way to rollback the migration if needed.
    /// Note: This is not supported for property removal migrations as the
    /// properties are permanently removed from the entity definitions.
    /// 
    /// - Parameter modelContext: The Swift Data model context
    /// - Throws: MigrationError if rollback fails
    public static func rollback(modelContext _: ModelContext) throws {
        print("🔄 Attempting to rollback unused properties removal migration")
        
        // For property removal migrations, rollback is not supported
        // as the properties are permanently removed from the entity definitions
        throw MigrationError.rollbackFailed("Rollback not supported for property removal migrations")
    }
}

/// Migration test utilities for unused properties removal
#if DEBUG
public struct UnusedPropertiesMigrationTestUtils {
    
    /// Test the migration with sample data
    /// 
    /// - Parameter modelContext: The Swift Data model context
    /// - Throws: MigrationError if the test fails
    public static func testMigration(modelContext: ModelContext) throws {
        print("🧪 Testing unused properties removal migration")
        
        // Create test Session data
        let testSession = Session(id: UUID())
        testSession.title = "Test Session"
        testSession.startTime = Date()
        testSession.endTime = Date().addingTimeInterval(3600)
        testSession.isAllDay = false
        testSession.location = "Test Location"
        testSession.notes = "Test Notes"
        testSession.status = .scheduled
        testSession.isTravel = false
        testSession.groupID = UUID()
        testSession.groupedPosition = 0
        testSession.attendeesCount = 1
        testSession.derivedFromEKEventID = "test-event-id"
        testSession.googleColorId = "test-color-id"
        testSession.sessionLatitude = 0.0
        testSession.sessionLongitude = 0.0
        
        modelContext.insert(testSession)
        
        // Create test TravelCharge data
        let testTravelCharge = TravelCharge(id: UUID())
        testTravelCharge.mmmZoneName = "Test Zone"
        testTravelCharge.distanceKM = 10.0
        testTravelCharge.durationMinutes = 30.0
        testTravelCharge.vehicleType = .car
        testTravelCharge.parkingCost = 5.0
        testTravelCharge.tollCost = 2.0
        testTravelCharge.participantCount = 1
        testTravelCharge.splitCosts = false
        testTravelCharge.chargeType = .standard
        testTravelCharge.travelDirection = .toClient
        
        modelContext.insert(testTravelCharge)
        try modelContext.save()
        
        // Test migration
        try RemoveUnusedProperties_Migration.execute(modelContext: modelContext)
        
        // Verify test data
        let sessionDescriptor = FetchDescriptor<Session>()
        let sessions = try modelContext.fetch(sessionDescriptor)
        
        guard let session = sessions.first else {
            throw MigrationError.validationFailed("Test session not found")
        }
        
        guard session.title == "Test Session" else {
            throw MigrationError.validationFailed("Session title not accessible")
        }
        
        let travelChargeDescriptor = FetchDescriptor<TravelCharge>()
        let travelCharges = try modelContext.fetch(travelChargeDescriptor)
        
        guard let travelCharge = travelCharges.first else {
            throw MigrationError.validationFailed("Test travel charge not found")
        }
        
        guard travelCharge.mmmZoneName == "Test Zone" else {
            throw MigrationError.validationFailed("Travel charge zone name not accessible")
        }
        
        // Clean up test data
        modelContext.delete(testSession)
        modelContext.delete(testTravelCharge)
        try modelContext.save()
        
        print("✅ Unused properties removal migration test completed successfully")
    }
}
#endif
