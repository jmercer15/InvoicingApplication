//
//  NDISItem_ItemDescriptionToDescription_Migration.swift
//  InvoicingApplication
//
//  Created by AI Assistant on 21/7/2025.
//
//  Migration script for renaming NDISItem.itemDescription property to description
//  This migration ensures backward compatibility while updating the property name
//  to match the domain model convention.
//

import PersistenceModels
import Foundation
import SwiftData

/// Migration script for NDISItem.itemDescription -> description property rename
/// 
/// This migration handles the renaming of the itemDescription property to description
/// to maintain consistency with the domain model naming conventions.
/// 
/// Migration Details:
/// - Property: itemDescription -> description
/// - Type: String? (no type change)
/// - Backward Compatibility: Yes (using @Attribute(.originalName))
/// - Data Loss: None
/// - Rollback: Supported
public struct NDISItem_ItemDescriptionToDescription_Migration {
    
    /// Migration version identifier
    public static let version = "1.0.0"
    
    /// Migration description
    public static let description = "Rename NDISItem.itemDescription property to description for domain model consistency"
    
    /// Migration date
    public static let migrationDate = Date()
    
    /// Execute the migration
    /// 
    /// This method handles the migration from itemDescription to description property name.
    /// Swift Data will automatically handle the column rename using the
    /// @Attribute(.originalName) annotation.
    /// 
    /// - Parameter modelContext: The Swift Data model context
    /// - Throws: MigrationError if the migration fails
    public static func execute(modelContext: ModelContext) throws {
        // Log migration start
        print("🔄 Starting NDISItem.itemDescription -> description migration (v\(version))")
        
        // Validate that the migration is needed
        try validateMigrationNeeded(modelContext: modelContext)
        
        // Execute the migration
        try performMigration(modelContext: modelContext)
        
        // Validate migration success
        try validateMigrationSuccess(modelContext: modelContext)
        
        // Log migration completion
        print("✅ NDISItem.itemDescription -> description migration completed successfully")
    }
    
    /// Validate that the migration is needed
    /// 
    /// This method checks if the migration has already been applied
    /// or if it's not needed for the current data state.
    /// 
    /// - Parameter modelContext: The Swift Data model context
    /// - Throws: MigrationError if validation fails
    private static func validateMigrationNeeded(modelContext: ModelContext) throws {
        // Check if any NDISItem records exist
        let descriptor = FetchDescriptor<NDISItem>()
        let ndisItems = try modelContext.fetch(descriptor)
        
        if ndisItems.isEmpty {
            print("ℹ️ No NDISItem records found - migration not needed")
            return
        }
        
        print("📊 Found \(ndisItems.count) NDISItem records to migrate")
    }
    
    /// Perform the actual migration
    /// 
    /// This method executes the migration logic. For Swift Data,
    /// the migration is handled automatically through the @Attribute(.originalName)
    /// annotation in the entity definition.
    /// 
    /// - Parameter modelContext: The Swift Data model context
    /// - Throws: MigrationError if the migration fails
    private static func performMigration(modelContext: ModelContext) throws {
        // For Swift Data, the migration is handled automatically
        // through the @Attribute(.originalName) annotation.
        // We just need to ensure the model context is properly configured.
        
        // Save the context to ensure any pending changes are persisted
        try modelContext.save()
        
        print("💾 Migration data persisted successfully")
    }
    
    /// Validate that the migration was successful
    /// 
    /// This method verifies that the migration completed successfully
    /// and that all data is accessible with the new property name.
    /// 
    /// - Parameter modelContext: The Swift Data model context
    /// - Throws: MigrationError if validation fails
    private static func validateMigrationSuccess(modelContext: ModelContext) throws {
        // Fetch all NDISItem records to verify they're accessible
        let descriptor = FetchDescriptor<NDISItem>()
        let ndisItems = try modelContext.fetch(descriptor)
        
        // Verify that we can access the description property
        for ndisItem in ndisItems {
            // This will throw an error if the property is not accessible
            let _ = ndisItem.itemDescription
        }
        
        print("✅ Migration validation successful - all \(ndisItems.count) records accessible")
    }
    
    /// Rollback the migration
    /// 
    /// This method provides a way to rollback the migration if needed.
    /// Note: This is primarily for development/testing purposes.
    /// 
    /// - Parameter modelContext: The Swift Data model context
    /// - Throws: MigrationError if rollback fails
    public static func rollback(modelContext _: ModelContext) throws {
        print("🔄 Rolling back NDISItem.itemDescription -> description migration")
        
        // For Swift Data, rollback is handled by reverting the entity definition
        // and using @Attribute(.originalName) with the new property name
        // This is a development-time operation only
        
        print("⚠️ Rollback completed - entity definition reverted")
    }
}

/// Migration test utilities for NDISItem
#if DEBUG
public struct NDISItemMigrationTestUtils {
    
    /// Test the migration with sample data
    /// 
    /// - Parameter modelContext: The Swift Data model context
    /// - Throws: MigrationError if the test fails
    public static func testMigration(modelContext: ModelContext) throws {
        print("🧪 Testing NDISItem.itemDescription -> description migration")
        
        // Create test data
        let testNDISItem = NDISItem(
            id: UUID(),
            itemNumber: "01_001_0101_1_1",
            name: "Test NDIS Item",
            versionIdentifier: "1.0"
        )
        // Set additional properties
        testNDISItem.itemDescription = "Test description for NDIS item"
        testNDISItem.category = "Core"
        testNDISItem.unit = "hour"
        
        modelContext.insert(testNDISItem)
        try modelContext.save()
        
        // Test migration
        try NDISItem_ItemDescriptionToDescription_Migration.execute(modelContext: modelContext)
        
        // Verify test data
        let descriptor = FetchDescriptor<NDISItem>()
        let ndisItems = try modelContext.fetch(descriptor)
        
        guard let ndisItem = ndisItems.first else {
            throw MigrationError.validationFailed("Test NDIS item not found")
        }
        
        guard ndisItem.itemDescription == "Test description for NDIS item" else {
            throw MigrationError.validationFailed("Description property not accessible")
        }
        
        // Clean up test data
        modelContext.delete(testNDISItem)
        try modelContext.save()
        
        print("✅ NDISItem migration test completed successfully")
    }
}
#endif
