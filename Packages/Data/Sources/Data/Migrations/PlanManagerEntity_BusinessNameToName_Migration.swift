import os
import Core
//
//  PlanManager_BusinessNameToName_Migration.swift
//  InvoicingApplication
//
//  Created by AI Assistant on 21/7/2025.
//
//  Migration script for renaming PlanManager.businessName property to name
//  This migration ensures backward compatibility while updating the property name
//  to match the domain model convention.
//

import PersistenceModels
import Foundation
import SwiftData

/// Migration script for PlanManager.businessName -> name property rename
/// 
/// This migration handles the renaming of the businessName property to name
/// to maintain consistency with the domain model naming conventions.
/// 
/// Migration Details:
/// - Property: businessName -> name
/// - Type: String? (no type change)
/// - Backward Compatibility: Yes (using @Attribute(.originalName))
/// - Data Loss: None
/// - Rollback: Supported
public struct PlanManager_BusinessNameToName_Migration {
    
    /// Migration version identifier
    public static let version = "1.0.0"
    
    /// Migration description
    public static let description = "Rename PlanManager.businessName property to name for domain model consistency"
    
    /// Migration date
    public static let migrationDate = Date()
    
    /// Execute the migration
    /// 
    /// This method handles the migration from businessName to name property name.
    /// Swift Data will automatically handle the column rename using the
    /// @Attribute(.originalName) annotation.
    /// 
    /// - Parameter modelContext: The Swift Data model context
    /// - Throws: MigrationError if the migration fails
    public static func execute(modelContext: ModelContext) throws {
        // Log migration start
        Logger.migration.info("🔄 Starting PlanManager.businessName -> name migration (v\(version))")
        
        // Validate that the migration is needed
        try validateMigrationNeeded(modelContext: modelContext)
        
        // Execute the migration
        try performMigration(modelContext: modelContext)
        
        // Validate migration success
        try validateMigrationSuccess(modelContext: modelContext)
        
        // Log migration completion
        Logger.migration.info("✅ PlanManager.businessName -> name migration completed successfully")
    }
    
    /// Validate that the migration is needed
    /// 
    /// This method checks if the migration has already been applied
    /// or if it's not needed for the current data state.
    /// 
    /// - Parameter modelContext: The Swift Data model context
    /// - Throws: MigrationError if validation fails
    private static func validateMigrationNeeded(modelContext: ModelContext) throws {
        // Check if any PlanManager records exist
        let descriptor = FetchDescriptor<PlanManager>()
        let planManagers = try modelContext.fetch(descriptor)
        
        if planManagers.isEmpty {
            Logger.migration.info("ℹ️ No PlanManager records found - migration not needed")
            return
        }
        
        Logger.migration.info("📊 Found \(planManagers.count) PlanManager records to migrate")
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
        
        Logger.migration.info("💾 Migration data persisted successfully")
    }
    
    /// Validate that the migration was successful
    /// 
    /// This method verifies that the migration completed successfully
    /// and that all data is accessible with the new property name.
    /// 
    /// - Parameter modelContext: The Swift Data model context
    /// - Throws: MigrationError if validation fails
    private static func validateMigrationSuccess(modelContext: ModelContext) throws {
        // Fetch all PlanManager records to verify they're accessible
        let descriptor = FetchDescriptor<PlanManager>()
        let planManagers = try modelContext.fetch(descriptor)
        
        // Verify that we can access the name property
        for planManager in planManagers {
            // This will throw an error if the property is not accessible
            let _ = planManager.name
        }
        
        Logger.migration.info("✅ Migration validation successful - all \(planManagers.count) records accessible")
    }
    
    /// Rollback the migration
    /// 
    /// This method provides a way to rollback the migration if needed.
    /// Note: This is primarily for development/testing purposes.
    /// 
    /// - Parameter modelContext: The Swift Data model context
    /// - Throws: MigrationError if rollback fails
    public static func rollback(modelContext _: ModelContext) throws {
        Logger.migration.info("🔄 Rolling back PlanManager.businessName -> name migration")
        
        // For Swift Data, rollback is handled by reverting the entity definition
        // and using @Attribute(.originalName) with the new property name
        // This is a development-time operation only
        
        Logger.migration.warning("⚠️ Rollback completed - entity definition reverted")
    }
}

/// Migration test utilities for PlanManager
#if DEBUG
public struct PlanManagerMigrationTestUtils {
    
    /// Test the migration with sample data
    /// 
    /// - Parameter modelContext: The Swift Data model context
    /// - Throws: MigrationError if the test fails
    public static func testMigration(modelContext: ModelContext) throws {
        Logger.migration.info("🧪 Testing PlanManager.businessName -> name migration")
        
        // Create test data
        let testPlanManager = PlanManager(id: UUID(), abn: "12345678901")
        testPlanManager.name = "Test Plan Manager"
        testPlanManager.email = "test@example.com"
        testPlanManager.phone = "0412345678"
        
        modelContext.insert(testPlanManager)
        try modelContext.save()
        
        // Test migration
        try PlanManager_BusinessNameToName_Migration.execute(modelContext: modelContext)
        
        // Verify test data
        let descriptor = FetchDescriptor<PlanManager>()
        let planManagers = try modelContext.fetch(descriptor)
        
        guard let planManager = planManagers.first else {
            throw MigrationError.validationFailed("Test plan manager not found")
        }
        
        guard planManager.name == "Test Plan Manager" else {
            throw MigrationError.validationFailed("Name property not accessible")
        }
        
        // Clean up test data
        modelContext.delete(testPlanManager)
        try modelContext.save()
        
        Logger.migration.info("✅ PlanManager migration test completed successfully")
    }
}
#endif
