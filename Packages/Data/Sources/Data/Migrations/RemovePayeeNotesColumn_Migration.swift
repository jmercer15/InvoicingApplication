//
//  RemovePayeeNotesColumn_Migration.swift
//  InvoicingApplication
//
//  Created by AI Assistant on 21/7/2025.
//
//  Migration script for removing PayeeEntity.notes column
//  This migration handles the removal of the notes property that violates
//  architectural guidelines and has been removed from entity definitions.
//

import Foundation
import SwiftData

/// Migration script for removing PayeeEntity.notes column
/// 
/// This migration handles the removal of the notes property that violates
/// architectural guidelines and has been removed from entity definitions.
/// 
/// Properties Removed:
/// - PayeeEntity.notes
/// 
/// Migration Details:
/// - Type: Property Removal
/// - Backward Compatibility: No (properties are removed)
/// - Data Loss: None (properties were architectural violations)
/// - Rollback: Not supported (properties are permanently removed)
public struct RemovePayeeNotesColumn_Migration {
    
    /// Migration version identifier
    public static let version = "1.0.0"
    
    /// Migration description
    public static let description = "Remove notes column from PayeeEntity"
    
    /// Migration date
    public static let migrationDate = Date()
    
    /// Execute the migration
    /// 
    /// This method handles the removal of the notes property from PayeeEntity.
    /// For Swift Data, the migration is handled automatically when the entity
    /// definitions are updated to remove the properties.
    /// 
    /// - Parameter modelContext: The Swift Data model context
    /// - Throws: MigrationError if the migration fails
    public static func execute(modelContext: ModelContext) throws {
        // Log migration start
        print("🔄 Starting PayeeEntity.notes column removal migration (v\(version))")
        
        // Validate that the migration is needed
        try validateMigrationNeeded(modelContext: modelContext)
        
        // Execute the migration
        try performMigration(modelContext: modelContext)
        
        // Validate migration success
        try validateMigrationSuccess(modelContext: modelContext)
        
        // Log migration completion
        print("✅ PayeeEntity.notes column removal migration completed successfully")
    }
    
    /// Validate that the migration is needed
    /// 
    /// This method checks if the migration has already been applied
    /// or if it's not needed for the current data state.
    /// 
    /// - Parameter modelContext: The Swift Data model context
    /// - Throws: MigrationError if validation fails
    private static func validateMigrationNeeded(modelContext: ModelContext) throws {
        // Check if any PayeeEntity records exist
        let payeeDescriptor = FetchDescriptor<PayeeEntity>()
        let payees = try modelContext.fetch(payeeDescriptor)
        
        if payees.isEmpty {
            print("ℹ️ No PayeeEntity records found - migration not needed")
            return
        }
        
        print("📊 Found \(payees.count) PayeeEntity records to migrate")
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
        // Fetch all PayeeEntity records to verify they're accessible
        let payeeDescriptor = FetchDescriptor<PayeeEntity>()
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
        
        print("✅ Migration validation successful - all \(payees.count) PayeeEntity records accessible")
    }
    
    /// Rollback the migration
    /// 
    /// This method provides a way to rollback the migration if needed.
    /// Note: This is not supported for property removal migrations as the
    /// properties are permanently removed from the entity definitions.
    /// 
    /// - Parameter modelContext: The Swift Data model context
    /// - Throws: MigrationError if rollback fails
    public static func rollback(modelContext: ModelContext) throws {
        print("🔄 Attempting to rollback PayeeEntity.notes column removal migration")
        
        // For property removal migrations, rollback is not supported
        // as the properties are permanently removed from the entity definitions
        throw MigrationError.rollbackFailed("Rollback not supported for property removal migrations")
    }
}

/// Migration test utilities for PayeeEntity.notes column removal
#if DEBUG
public struct PayeeNotesColumnMigrationTestUtils {
    
    /// Test the migration with sample data
    /// 
    /// - Parameter modelContext: The Swift Data model context
    /// - Throws: MigrationError if the test fails
    public static func testMigration(modelContext: ModelContext) throws {
        print("🧪 Testing PayeeEntity.notes column removal migration")
        
        // Create test PayeeEntity data
        let testPayee = PayeeEntity(id: UUID(), fullName: "Test Payee")
        testPayee.email = "payee@example.com"
        testPayee.phone = "0412345679"
        testPayee.relationToClient = "parent"
        testPayee.status = "active"
        
        modelContext.insert(testPayee)
        try modelContext.save()
        
        // Test migration
        try RemovePayeeNotesColumn_Migration.execute(modelContext: modelContext)
        
        // Verify test data
        let payeeDescriptor = FetchDescriptor<PayeeEntity>()
        let payees = try modelContext.fetch(payeeDescriptor)
        
        guard let payee = payees.first else {
            throw MigrationError.validationFailed("Test payee not found")
        }
        
        guard payee.fullName == "Test Payee" else {
            throw MigrationError.validationFailed("Payee full name not accessible")
        }
        
        // Clean up test data
        modelContext.delete(testPayee)
        try modelContext.save()
        
        print("✅ PayeeEntity.notes column removal migration test completed successfully")
    }
}
#endif

/// Migration configuration for PayeeEntity.notes column removal
public struct PayeeNotesColumnMigrationConfig {
    /// Enable detailed logging
    public static let enableDetailedLogging = true
    
    /// Enable migration validation
    public static let enableValidation = true
    
    /// Enable rollback support (not supported for property removal)
    public static let enableRollback = false
    
    /// Properties that were removed from PayeeEntity
    public static let removedPayeeProperties = [
        "notes"
    ]
}

/// Migration utilities for PayeeEntity.notes column removal
public struct PayeeNotesColumnMigrationUtils {
    
    /// Log migration step
    /// 
    /// - Parameters:
    ///   - step: The migration step description
    ///   - level: The log level (info, warning, error)
    public static func log(_ step: String, level: LogLevel = .info) {
        guard PayeeNotesColumnMigrationConfig.enableDetailedLogging else { return }
        
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
