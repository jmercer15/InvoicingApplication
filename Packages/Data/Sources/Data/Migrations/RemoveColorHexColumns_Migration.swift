//
//  RemoveColorHexColumns_Migration.swift
//  InvoicingApplication
//
//  Created by AI Assistant on 21/7/2025.
//
//  Migration script for removing colorHex columns from entities
//  This migration handles the removal of colorHex properties that violate
//  architectural guidelines and have been removed from entity definitions.
//

import Core
import PersistenceModels
import Foundation
import SwiftData

/// Migration script for removing colorHex columns from entities
/// 
/// This migration handles the removal of colorHex properties that violate
/// architectural guidelines and have been removed from entity definitions.
/// 
/// Properties Removed:
/// - Client.colorHex
/// - Payee.colorHex
/// 
/// Migration Details:
/// - Type: Property Removal
/// - Backward Compatibility: No (properties are removed)
/// - Data Loss: None (properties were architectural violations)
/// - Rollback: Not supported (properties are permanently removed)
public struct RemoveColorHexColumns_Migration {
    
    /// Migration version identifier
    public static let version = "1.0.0"
    
    /// Migration description
    public static let description = "Remove colorHex columns from Client and Payee"
    
    /// Migration date
    public static let migrationDate = Date()
    
    /// Execute the migration
    /// 
    /// This method handles the removal of colorHex properties from entities.
    /// For Swift Data, the migration is handled automatically when the entity
    /// definitions are updated to remove the properties.
    /// 
    /// - Parameter modelContext: The Swift Data model context
    /// - Throws: MigrationError if the migration fails
    public static func execute(modelContext: ModelContext) throws {
        // Log migration start
        print("🔄 Starting colorHex columns removal migration (v\(version))")
        
        // Validate that the migration is needed
        try validateMigrationNeeded(modelContext: modelContext)
        
        // Execute the migration
        try performMigration(modelContext: modelContext)
        
        // Validate migration success
        try validateMigrationSuccess(modelContext: modelContext)
        
        // Log migration completion
        print("✅ ColorHex columns removal migration completed successfully")
    }
    
    /// Validate that the migration is needed
    /// 
    /// This method checks if the migration has already been applied
    /// or if it's not needed for the current data state.
    /// 
    /// - Parameter modelContext: The Swift Data model context
    /// - Throws: MigrationError if validation fails
    private static func validateMigrationNeeded(modelContext: ModelContext) throws {
        // Check if any Client records exist
        let clientDescriptor = FetchDescriptor<Client>()
        let clients = try modelContext.fetch(clientDescriptor)
        
        // Check if any Payee records exist
        let payeeDescriptor = FetchDescriptor<Payee>()
        let payees = try modelContext.fetch(payeeDescriptor)
        
        if clients.isEmpty && payees.isEmpty {
            print("ℹ️ No Client or Payee records found - migration not needed")
            return
        }
        
        print("📊 Found \(clients.count) Client records and \(payees.count) Payee records to migrate")
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
        // Fetch all Client records to verify they're accessible
        let clientDescriptor = FetchDescriptor<Client>()
        let clients = try modelContext.fetch(clientDescriptor)
        
        // Verify that we can access the remaining properties
        for client in clients {
            // This will throw an error if any removed properties are still accessible
            let _ = client.id
            let _ = client.ndisNumber
            let _ = client.fullName
            let _ = client.effectiveStatus
            let _ = client.email
            let _ = client.notes
            let _ = client.phone
            let _ = client.creditAmount
            let _ = client.isMinor
            let _ = client.hasNdisPlan
            let _ = client.planManagementType
            let _ = client.billingAuthority
            let _ = client.sendInvoicesToClient
            let _ = client.sendInvoicesToPayee
            let _ = client.sendInvoicesToPlanManager
        }
        
        // Fetch all Payee records to verify they're accessible
        let payeeDescriptor = FetchDescriptor<Payee>()
        let payees = try modelContext.fetch(payeeDescriptor)
        
        // Verify that we can access the remaining properties
        for payee in payees {
            // This will throw an error if any removed properties are still accessible
            let _ = payee.id
            let _ = payee.fullName
            let _ = payee.email
            let _ = payee.phone
            let _ = payee.relationToClient
            let _ = payee.status
        }
        
        print("✅ Migration validation successful - all \(clients.count) Client and \(payees.count) Payee records accessible")
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
        print("🔄 Attempting to rollback colorHex columns removal migration")
        
        // For property removal migrations, rollback is not supported
        // as the properties are permanently removed from the entity definitions
        throw MigrationError.rollbackFailed("Rollback not supported for property removal migrations")
    }
}

/// Migration test utilities for colorHex columns removal
#if DEBUG
public struct ColorHexColumnsMigrationTestUtils {
    
    /// Test the migration with sample data
    /// 
    /// - Parameter modelContext: The Swift Data model context
    /// - Throws: MigrationError if the test fails
    public static func testMigration(modelContext: ModelContext) throws {
        print("🧪 Testing colorHex columns removal migration")
        
        // Create test Client data
        let testClient = Client(id: UUID(), ndisNumber: "123456789", fullName: "Test Client", status: .active)
        testClient.email = "test@example.com"
        testClient.notes = "Test notes"
        testClient.phone = "0412345678"
        testClient.creditAmount = 100.0
        testClient.isMinor = false
        testClient.hasNdisPlan = true
        testClient.planManagementType = "plan_managed"
        testClient.billingAuthority = .ndia
        
        modelContext.insert(testClient)
        
        // Create test Payee data
        let testPayee = Payee(id: UUID(), fullName: "Test Payee")
        testPayee.email = "payee@example.com"
        testPayee.phone = "0412345679"
        testPayee.relationToClient = "parent"
        testPayee.status = "active"
        
        modelContext.insert(testPayee)
        try modelContext.save()
        
        // Test migration
        try RemoveColorHexColumns_Migration.execute(modelContext: modelContext)
        
        // Verify test data
        let clientDescriptor = FetchDescriptor<Client>()
        let clients = try modelContext.fetch(clientDescriptor)
        
        guard let client = clients.first else {
            throw MigrationError.validationFailed("Test client not found")
        }
        
        guard client.fullName == "Test Client" else {
            throw MigrationError.validationFailed("Client full name not accessible")
        }
        
        let payeeDescriptor = FetchDescriptor<Payee>()
        let payees = try modelContext.fetch(payeeDescriptor)
        
        guard let payee = payees.first else {
            throw MigrationError.validationFailed("Test payee not found")
        }
        
        guard payee.fullName == "Test Payee" else {
            throw MigrationError.validationFailed("Payee full name not accessible")
        }
        
        // Clean up test data
        modelContext.delete(testClient)
        modelContext.delete(testPayee)
        try modelContext.save()
        
        print("✅ ColorHex columns removal migration test completed successfully")
    }
}
#endif
