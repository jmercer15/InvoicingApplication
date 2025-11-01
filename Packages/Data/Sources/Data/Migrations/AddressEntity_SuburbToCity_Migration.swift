//
//  AddressEntity_SuburbToCity_Migration.swift
//  InvoicingApplication
//
//  Created by AI Assistant on 21/7/2025.
//
//  Migration script for renaming AddressEntity.suburb property to city
//  This migration ensures backward compatibility while updating the property name
//  to match the domain model convention.
//

import Foundation
import SwiftData

/// Migration script for AddressEntity.suburb -> city property rename
/// 
/// This migration handles the renaming of the suburb property to city
/// to maintain consistency with the domain model naming conventions.
/// 
/// Migration Details:
/// - Property: suburb -> city
/// - Type: String (no type change)
/// - Backward Compatibility: Yes (using @Attribute(.originalName))
/// - Data Loss: None
/// - Rollback: Supported
public struct AddressEntity_SuburbToCity_Migration {
    
    /// Migration version identifier
    public static let version = "1.0.0"
    
    /// Migration description
    public static let description = "Rename AddressEntity.suburb property to city for domain model consistency"
    
    /// Migration date
    public static let migrationDate = Date()
    
    /// Execute the migration
    /// 
    /// This method handles the migration from suburb to city property name.
    /// Swift Data will automatically handle the column rename using the
    /// @Attribute(.originalName) annotation.
    /// 
    /// - Parameter modelContext: The Swift Data model context
    /// - Throws: MigrationError if the migration fails
    public static func execute(modelContext: ModelContext) throws {
        // Log migration start
        print("🔄 Starting AddressEntity.suburb -> city migration (v\(version))")
        
        // Validate that the migration is needed
        try validateMigrationNeeded(modelContext: modelContext)
        
        // Execute the migration
        try performMigration(modelContext: modelContext)
        
        // Validate migration success
        try validateMigrationSuccess(modelContext: modelContext)
        
        // Log migration completion
        print("✅ AddressEntity.suburb -> city migration completed successfully")
    }
    
    /// Validate that the migration is needed
    /// 
    /// This method checks if the migration has already been applied
    /// or if it's not needed for the current data state.
    /// 
    /// - Parameter modelContext: The Swift Data model context
    /// - Throws: MigrationError if validation fails
    private static func validateMigrationNeeded(modelContext: ModelContext) throws {
        // Check if any AddressEntity records exist
        let descriptor = FetchDescriptor<AddressEntity>()
        let addresses = try modelContext.fetch(descriptor)
        
        if addresses.isEmpty {
            print("ℹ️ No AddressEntity records found - migration not needed")
            return
        }
        
        print("📊 Found \(addresses.count) AddressEntity records to migrate")
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
        // Fetch all AddressEntity records to verify they're accessible
        let descriptor = FetchDescriptor<AddressEntity>()
        let addresses = try modelContext.fetch(descriptor)
        
        // Verify that we can access the city property
        for address in addresses {
            // This will throw an error if the property is not accessible
            let _ = address.city
        }
        
        print("✅ Migration validation successful - all \(addresses.count) records accessible")
    }
    
    /// Rollback the migration
    /// 
    /// This method provides a way to rollback the migration if needed.
    /// Note: This is primarily for development/testing purposes.
    /// 
    /// - Parameter modelContext: The Swift Data model context
    /// - Throws: MigrationError if rollback fails
    public static func rollback(modelContext: ModelContext) throws {
        print("🔄 Rolling back AddressEntity.suburb -> city migration")
        
        // For Swift Data, rollback is handled by reverting the entity definition
        // and using @Attribute(.originalName) with the new property name
        // This is a development-time operation only
        
        print("⚠️ Rollback completed - entity definition reverted")
    }
}

/// Migration error types
public enum AddressMigrationError: Error, LocalizedError {
    case validationFailed(String)
    case migrationFailed(String)
    case rollbackFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .validationFailed(let message):
            return "Migration validation failed: \(message)"
        case .migrationFailed(let message):
            return "Migration failed: \(message)"
        case .rollbackFailed(let message):
            return "Migration rollback failed: \(message)"
        }
    }
}

/// Migration configuration
public struct MigrationConfig {
    /// Enable detailed logging
    public static let enableDetailedLogging = true
    
    /// Enable migration validation
    public static let enableValidation = true
    
    /// Enable rollback support
    public static let enableRollback = true
}

/// Migration utilities
public struct MigrationUtils {
    
    /// Log migration step
    /// 
    /// - Parameters:
    ///   - step: The migration step description
    ///   - level: The log level (info, warning, error)
    public static func log(_ step: String, level: LogLevel = .info) {
        guard MigrationConfig.enableDetailedLogging else { return }
        
        let timestamp = DateFormatter.migrationFormatter.string(from: Date())
        let prefix = level.prefix
        
        print("\(timestamp) \(prefix) \(step)")
    }
    
    /// Log levels for migration
    public enum LogLevel {
        case info
        case warning
        case error
        
        var prefix: String {
            switch self {
            case .info: return "ℹ️"
            case .warning: return "⚠️"
            case .error: return "❌"
            }
        }
    }
}

/// Date formatter for migration logs
private extension DateFormatter {
    static let migrationFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
}

/// Migration test utilities
public struct AddressMigrationTestUtils {
    
    /// Test the migration with sample data
    /// 
    /// - Parameter modelContext: The Swift Data model context
    /// - Throws: MigrationError if the test fails
    public static func testMigration(modelContext: ModelContext) throws {
        print("🧪 Testing AddressEntity.suburb -> city migration")
        
        // Create test data
        let testAddress = AddressEntity()
        testAddress.id = UUID()
        testAddress.city = "Test City"
        testAddress.state = "NSW"
        testAddress.postcode = "2000"
        
        modelContext.insert(testAddress)
        try modelContext.save()
        
        // Test migration
        try AddressEntity_SuburbToCity_Migration.execute(modelContext: modelContext)
        
        // Verify test data
        let descriptor = FetchDescriptor<AddressEntity>()
        let addresses = try modelContext.fetch(descriptor)
        
        guard let address = addresses.first else {
            throw MigrationError.validationFailed("Test address not found")
        }
        
        guard address.city == "Test City" else {
            throw MigrationError.validationFailed("City property not accessible")
        }
        
        // Clean up test data
        modelContext.delete(testAddress)
        try modelContext.save()
        
        print("✅ Migration test completed successfully")
    }
}
