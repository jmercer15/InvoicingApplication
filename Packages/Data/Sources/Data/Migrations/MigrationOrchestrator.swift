//
//  MigrationOrchestrator.swift
//  InvoicingApplication
//
//  Created by AI Assistant on 21/7/2025.
//
//  Central migration orchestrator for managing all database migrations
//  This orchestrator handles the execution of multiple migrations in the correct order
//  and provides comprehensive logging and error handling.
//

import Core
import Foundation
import SwiftData

/// Central migration orchestrator for managing all database migrations
/// 
/// This orchestrator handles the execution of multiple migrations in the correct order,
/// provides comprehensive logging and error handling, and ensures data integrity
/// throughout the migration process.
public class MigrationOrchestrator {
    private static let migrationHistoryFileName = "migration-history.json"
    
    /// Migration result types
    public enum MigrationResult {
        case success
        case failure(Error)
        case skipped(String)
    }
    
    /// Migration status
    public enum MigrationStatus {
        case pending
        case inProgress
        case completed
        case failed(Error)
        case skipped
    }
    
    /// Individual migration information
    public struct MigrationInfo {
        let id: String
        let name: String
        let version: String
        let description: String
        let execute: (ModelContext) throws -> Void
        let rollback: (ModelContext) throws -> Void
        var status: MigrationStatus = .pending
        var startTime: Date?
        var endTime: Date?
        var error: Error?
    }
    
    /// All available migrations
    private let migrations: [MigrationInfo] = [
        MigrationInfo(
            id: "address_suburb_to_city",
            name: "Address.suburb -> city",
            version: "1.0.0",
            description: "Rename Address.suburb property to city for domain model consistency",
            execute: { try Address_SuburbToCity_Migration.execute(modelContext: $0) },
            rollback: { try Address_SuburbToCity_Migration.rollback(modelContext: $0) }
        ),
        MigrationInfo(
            id: "planmanager_businessname_to_name",
            name: "PlanManager.businessName -> name",
            version: "1.0.0",
            description: "Rename PlanManager.businessName property to name for domain model consistency",
            execute: { try PlanManager_BusinessNameToName_Migration.execute(modelContext: $0) },
            rollback: { try PlanManager_BusinessNameToName_Migration.rollback(modelContext: $0) }
        ),
        MigrationInfo(
            id: "ndisitem_itemdescription_to_description",
            name: "NDISItem.itemDescription -> description",
            version: "1.0.0",
            description: "Rename NDISItem.itemDescription property to description for domain model consistency",
            execute: { try NDISItem_ItemDescriptionToDescription_Migration.execute(modelContext: $0) },
            rollback: { try NDISItem_ItemDescriptionToDescription_Migration.rollback(modelContext: $0) }
        ),
        MigrationInfo(
            id: "remove_unused_properties",
            name: "Remove unused properties",
            version: "1.0.0",
            description: "Remove unused properties from Session and TravelCharge",
            execute: { try RemoveUnusedProperties_Migration.execute(modelContext: $0) },
            rollback: { try RemoveUnusedProperties_Migration.rollback(modelContext: $0) }
        ),
        MigrationInfo(
            id: "remove_colorhex_columns",
            name: "Remove colorHex columns",
            version: "1.0.0",
            description: "Remove colorHex columns from Client and Payee",
            execute: { try RemoveColorHexColumns_Migration.execute(modelContext: $0) },
            rollback: { try RemoveColorHexColumns_Migration.rollback(modelContext: $0) }
        ),
        MigrationInfo(
            id: "remove_payee_notes_column",
            name: "Remove Payee.notes column",
            version: "1.0.0",
            description: "Remove notes column from Payee",
            execute: { try RemovePayeeNotesColumn_Migration.execute(modelContext: $0) },
            rollback: { try RemovePayeeNotesColumn_Migration.rollback(modelContext: $0) }
        ),
        MigrationInfo(
            id: "normalize_invoice_status_values",
            name: "Normalize invoice status values",
            version: "1.0.0",
            description: "Rewrite persisted invoice statuses to canonical tokens",
            execute: { try NormalizeInvoiceStatusValues_Migration.execute(modelContext: $0) },
            rollback: { try NormalizeInvoiceStatusValues_Migration.rollback(modelContext: $0) }
        ),
        MigrationInfo(
            id: "add_compliance_foundation_fields_v1",
            name: "Add compliance foundation fields",
            version: "1.0.0",
            description: "Initialize claiming config defaults on business profile",
            execute: { try AddComplianceFoundationFields_v1.execute(modelContext: $0) },
            rollback: { try AddComplianceFoundationFields_v1.rollback(modelContext: $0) }
        ),
        MigrationInfo(
            id: "enum_rawvalue_column",
            name: "Enum rawValue column backfill",
            version: "1.0.0",
            description: "Backfill *Raw String columns that replaced stored enum properties",
            execute: { try EnumRawValueColumn_Migration.execute(modelContext: $0) },
            rollback: { try EnumRawValueColumn_Migration.rollback(modelContext: $0) }
        ),
        MigrationInfo(
            id: "backfill_eventkit_sync_metadata_v1",
            name: "Backfill EventKit sync metadata v1",
            version: "1.0.0",
            description: "Backfill durable EventKit sync metadata from legacy Session fields",
            execute: { try BackfillEventKitSyncMetadata_v1.execute(modelContext: $0) },
            rollback: { try BackfillEventKitSyncMetadata_v1.rollback(modelContext: $0) }
        ),
        MigrationInfo(
            id: "backfill_eventkit_sync_metadata_v2",
            name: "Backfill EventKit sync metadata v2",
            version: "1.0.0",
            description: "Backfill additional EventKit reconciliation metadata",
            execute: { try BackfillEventKitSyncMetadata_v2.execute(modelContext: $0) },
            rollback: { try BackfillEventKitSyncMetadata_v2.rollback(modelContext: $0) }
        ),
        MigrationInfo(
            id: "backfill_invoice_address_snapshots_v1",
            name: "Backfill invoice address snapshots v1",
            version: "1.0.0",
            description: "Copy legacy invoice address relationships into value snapshots",
            execute: { try BackfillInvoiceAddressSnapshots_v1.execute(modelContext: $0) },
            rollback: { try BackfillInvoiceAddressSnapshots_v1.rollback(modelContext: $0) }
        ),
        MigrationInfo(
            id: "drain_legacy_invoice_address_relationships_v1",
            name: "Drain legacy invoice address relationships v1",
            version: "1.0.0",
            description: "Copy any remaining legacy invoice address links into snapshots and clear the old relationships",
            execute: { try DrainLegacyInvoiceAddressRelationships_v1.execute(modelContext: $0) },
            rollback: { try DrainLegacyInvoiceAddressRelationships_v1.rollback(modelContext: $0) }
        )
    ]
    
    /// Migration configuration
    public struct Config {
        public static let enableDetailedLogging = true
        public static let enableValidation = true
        public static let enableRollback = true
        public static let stopOnFirstError = true
        public static let maxRetries = 3
    }
    
    /// Execute all pending migrations
    /// 
    /// This method executes all pending migrations in the correct order.
    /// 
    /// - Parameter modelContext: The Swift Data model context
    /// - Returns: Array of migration results
    /// - Throws: MigrationError if the orchestration fails
    public func executeAllMigrations(modelContext: ModelContext) throws -> [MigrationResult] {
        let historyPath = migrationHistoryURL(for: modelContext).path
        print("🚀 Starting migration orchestration")
        print("📋 Found \(migrations.count) migrations to process")
        print("🗂️ Migration history file: \(historyPath)")
        
        var results: [MigrationResult] = []
        var failedMigrations: [String] = []
        
        for (index, migration) in migrations.enumerated() {
            print("\n🔄 Processing migration \(index + 1)/\(migrations.count): \(migration.name)")
            
            do {
                let result = try executeMigration(migration, modelContext: modelContext)
                results.append(result)
                
                switch result {
                case .success:
                    print("✅ Migration \(migration.name) completed successfully")
                case .skipped(let reason):
                    print("⏭️ Migration \(migration.name) skipped: \(reason)")
                case .failure(let error):
                    print("❌ Migration \(migration.name) failed: \(error.localizedDescription)")
                    failedMigrations.append(migration.name)
                    
                    if Config.stopOnFirstError {
                        throw MigrationError.orchestrationFailed("Migration \(migration.name) failed: \(error.localizedDescription)")
                    }
                }
                
            } catch {
                let result = MigrationResult.failure(error)
                results.append(result)
                failedMigrations.append(migration.name)
                
                print("❌ Migration \(migration.name) failed with error: \(error.localizedDescription)")
                
                if Config.stopOnFirstError {
                    throw MigrationError.orchestrationFailed("Migration \(migration.name) failed: \(error.localizedDescription)")
                }
            }
        }
        
        // Summary
        let successCount = results.filter { if case .success = $0 { return true } else { return false } }.count
        let failureCount = results.filter { if case .failure = $0 { return true } else { return false } }.count
        let skippedCount = results.filter { if case .skipped = $0 { return true } else { return false } }.count
        
        print("\n📊 Migration Summary:")
        print("✅ Successful: \(successCount)")
        print("❌ Failed: \(failureCount)")
        print("⏭️ Skipped: \(skippedCount)")
        
        if !failedMigrations.isEmpty {
            print("❌ Failed migrations: \(failedMigrations.joined(separator: ", "))")
        }
        
        if failureCount == 0 {
            print("🎉 All migrations completed successfully!")
        } else {
            print("⚠️ Some migrations failed. Check the logs above for details.")
        }
        
        return results
    }
    
    /// Execute a single migration
    /// 
    /// - Parameters:
    ///   - migration: The migration to execute
    ///   - modelContext: The Swift Data model context
    /// - Returns: Migration result
    /// - Throws: MigrationError if the migration fails
    private func executeMigration(_ migration: MigrationInfo, modelContext: ModelContext) throws -> MigrationResult {
        // Check if migration is already applied
        if try isMigrationApplied(migration.id, modelContext: modelContext) {
            return .skipped("Migration already applied")
        }
        
        // Execute the migration
        try migration.execute(modelContext)
        
        // Mark migration as applied
        try markMigrationAsApplied(migration.id, modelContext: modelContext)
        
        return .success
    }
    
    /// Check if a migration has already been applied
    /// 
    /// - Parameters:
    ///   - migrationId: The migration ID to check
    ///   - modelContext: The Swift Data model context
    /// - Returns: True if the migration has been applied
    /// - Throws: MigrationError if the check fails
    private func isMigrationApplied(_ migrationId: String, modelContext: ModelContext) throws -> Bool {
        try appliedMigrationIDs(modelContext: modelContext).contains(migrationId)
    }
    
    /// Mark a migration as applied
    /// 
    /// - Parameters:
    ///   - migrationId: The migration ID to mark as applied
    ///   - modelContext: The Swift Data model context
    /// - Throws: MigrationError if the marking fails
    private func markMigrationAsApplied(_ migrationId: String, modelContext: ModelContext) throws {
        var applied = try appliedMigrationIDs(modelContext: modelContext)
        applied.insert(migrationId)
        try persistAppliedMigrationIDs(applied, modelContext: modelContext)
        print("📝 Marking migration \(migrationId) as applied")
    }

    private var cachedAppliedMigrationIDs: Set<String>?

    private func appliedMigrationIDs(modelContext: ModelContext) throws -> Set<String> {
        if let cached = cachedAppliedMigrationIDs {
            return cached
        }
        let historyURL = migrationHistoryURL(for: modelContext)
        guard FileManager.default.fileExists(atPath: historyURL.path) else {
            cachedAppliedMigrationIDs = []
            return []
        }

        let data = try Data(contentsOf: historyURL)
        let stored = try JSONDecoder().decode([String].self, from: data)
        let ids = Set(stored)
        cachedAppliedMigrationIDs = ids
        return ids
    }

    private func persistAppliedMigrationIDs(_ ids: Set<String>, modelContext: ModelContext) throws {
        let historyURL = migrationHistoryURL(for: modelContext)
        let directoryURL = historyURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
        let payload = Array(ids).sorted()
        let encoded = try JSONEncoder().encode(payload)
        try encoded.write(to: historyURL, options: [.atomic])
        cachedAppliedMigrationIDs = ids
    }

    /// Keep migration history durable and store-scoped.
    private func migrationHistoryURL(for modelContext: ModelContext) -> URL {
        if let storeURL = modelContext.container.configurations.first?.url {
            return storeURL
                .deletingLastPathComponent()
                .appendingPathComponent(Self.migrationHistoryFileName)
        } else {
            return FileManager.default.temporaryDirectory
                .appendingPathComponent("invoicingapp-inmemory-\(Self.migrationHistoryFileName)")
        }
    }
    
    /// Rollback all migrations
    /// 
    /// This method rolls back all migrations in reverse order.
    /// 
    /// - Parameter modelContext: The Swift Data model context
    /// - Throws: MigrationError if the rollback fails
    public func rollbackAllMigrations(modelContext: ModelContext) throws {
        print("🔄 Starting migration rollback")
        
        // Rollback migrations in reverse order
        for migration in migrations.reversed() {
            print("🔄 Rolling back migration: \(migration.name)")
            
            do {
                try migration.rollback(modelContext)
                print("✅ Rollback completed for: \(migration.name)")
            } catch {
                print("❌ Rollback failed for: \(migration.name) - \(error.localizedDescription)")
                throw MigrationError.rollbackFailed("Rollback failed for \(migration.name): \(error.localizedDescription)")
            }
        }
        
        print("🎉 All migrations rolled back successfully!")
    }
    
    /// Get migration status
    /// 
    /// - Returns: Dictionary of migration statuses
    public func getMigrationStatus() -> [String: MigrationStatus] {
        var status: [String: MigrationStatus] = [:]
        
        for migration in migrations {
            status[migration.id] = migration.status
        }
        
        return status
    }
    
    /// Test all migrations
    /// 
    /// This method tests all migrations with sample data.
    /// 
    /// - Parameter modelContext: The Swift Data model context
    /// - Throws: MigrationError if the test fails
    #if DEBUG
    public func testAllMigrations(modelContext: ModelContext) throws {
        print("🧪 Testing all migrations")
        
        // Test each migration individually
        for migration in migrations {
            print("🧪 Testing migration: \(migration.name)")
            
            do {
                try testMigration(migration, modelContext: modelContext)
                print("✅ Test passed for: \(migration.name)")
            } catch {
                print("❌ Test failed for: \(migration.name) - \(error.localizedDescription)")
                throw MigrationError.testFailed("Test failed for \(migration.name): \(error.localizedDescription)")
            }
        }

        print("🎉 All migration tests passed!")
    }
    #else
    public func testAllMigrations(modelContext: ModelContext) throws {
        _ = modelContext
        throw MigrationError.testFailed("Migration tests are only available in DEBUG builds.")
    }
    #endif
    
    /// Test a single migration
    /// 
    /// - Parameters:
    ///   - migration: The migration to test
    ///   - modelContext: The Swift Data model context
    /// - Throws: MigrationError if the test fails
    #if DEBUG
    private func testMigration(_ migration: MigrationInfo, modelContext: ModelContext) throws {
        // Create test data based on migration type
        switch migration.id {
        case "address_suburb_to_city":
            try MigrationTestUtils.testAddressMigration(modelContext: modelContext)
        case "planmanager_businessname_to_name":
            try PlanManagerMigrationTestUtils.testMigration(modelContext: modelContext)
        case "ndisitem_itemdescription_to_description":
            try NDISItemMigrationTestUtils.testMigration(modelContext: modelContext)
        case "remove_unused_properties":
            try UnusedPropertiesMigrationTestUtils.testMigration(modelContext: modelContext)
        case "remove_colorhex_columns":
            try ColorHexColumnsMigrationTestUtils.testMigration(modelContext: modelContext)
        case "remove_payee_notes_column":
            try PayeeNotesColumnMigrationTestUtils.testMigration(modelContext: modelContext)
        case "add_compliance_foundation_fields_v1":
            break
        case "enum_rawvalue_column", "backfill_eventkit_sync_metadata_v1", "backfill_eventkit_sync_metadata_v2":
            break
        default:
            throw MigrationError.testFailed("Unknown migration type: \(migration.id)")
        }
    }
    #endif
}

/// Migration error types
public enum MigrationError: Error, LocalizedError {
    case orchestrationFailed(String)
    case testFailed(String)
    case rollbackFailed(String)
    case validationFailed(String)
    case migrationFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .orchestrationFailed(let message):
            return "Migration orchestration failed: \(message)"
        case .testFailed(let message):
            return "Migration test failed: \(message)"
        case .rollbackFailed(let message):
            return "Migration rollback failed: \(message)"
        case .validationFailed(let message):
            return "Migration validation failed: \(message)"
        case .migrationFailed(let message):
            return "Migration failed: \(message)"
        }
    }
}

/// Migration test utilities
#if DEBUG
public struct MigrationTestUtils {
    
    /// Test Address migration
    /// 
    /// - Parameter modelContext: The Swift Data model context
    /// - Throws: MigrationError if the test fails
    public static func testAddressMigration(modelContext: ModelContext) throws {
        print("🧪 Testing Address.suburb -> city migration")
        
        // Create test data
        let testAddress = Address()
        testAddress.id = UUID()
        testAddress.city = "Test City"
        testAddress.state = "NSW"
        testAddress.postcode = "2000"
        
        modelContext.insert(testAddress)
        try modelContext.save()
        
        // Test migration
        try Address_SuburbToCity_Migration.execute(modelContext: modelContext)
        
        // Verify test data
        let descriptor = FetchDescriptor<Address>()
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
        
        print("✅ Address migration test completed successfully")
    }
}
#endif
