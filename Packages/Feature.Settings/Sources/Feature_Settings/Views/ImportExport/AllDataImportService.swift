import Foundation
import SwiftUI
import SwiftData
import Data
import Core

// Import the Data package types directly to avoid Foundation.Data ambiguity
import class Data.TravelChargeReviewItem
import class Data.TravelChargeAuditLog
import class Data.ClientEntity
import class Data.ClientServiceEntity

/// Comprehensive import service for AllData-Export JSON files
struct AllDataImportService {
    
    /// Main import function that processes the AllData-Export JSON file
    static func importAllData(from data: Data, context: ModelContext) async throws -> [ImportExportView.ImportResults] {
        var results: [ImportExportView.ImportResults] = []
        
        print("Starting AllData import process...")
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            print("ERROR: Failed to parse JSON data")
            throw ImportError.invalidJSONFormat
        }
        
        print("JSON structure keys: \(Array(json.keys).sorted())")
        
        // Create a mapping of object URIs to actual entities for relationship resolution
        var entityMapping: [String: Any] = [:]
        
        // Import entities in dependency order (entities with relationships come after their dependencies)
        
        // 1. Import Address first (no dependencies)
        if let addressData = json["AddressEntity"] as? [[String: Any]] {
            print("Importing \(addressData.count) Address records...")
            let addressResult = try await importAddressEntities(addressData, context: context, entityMapping: &entityMapping)
            results.append(addressResult)
        } else {
            print("WARNING: No AddressEntity data found in JSON")
        }
        
        // 2. Import Payee (depends on Address)
        if let payeeData = json["PayeeEntity"] as? [[String: Any]] {
            print("Importing \(payeeData.count) Payee records...")
            let payeeResult = try await importPayeeEntities(payeeData, context: context, entityMapping: &entityMapping)
            results.append(payeeResult)
        } else {
            print("WARNING: No PayeeEntity data found in JSON")
        }
        
        // 3. Import PlanManager (no dependencies)
        if let planManagerData = json["PlanManagerEntity"] as? [[String: Any]] {
            let planManagerResult = try await importPlanManagerEntities(planManagerData, context: context, entityMapping: &entityMapping)
            results.append(planManagerResult)
        }
        
        // 4. Import NDISItemEntity (no dependencies)
        if let ndisData = json["NDISItemEntity"] as? [[String: Any]] {
            let ndisResult = try await importNDISItemEntities(ndisData, context: context, entityMapping: &entityMapping)
            results.append(ndisResult)
        }
        
        // 5. Import BusinessEntity (no dependencies)
        if let businessData = json["BusinessEntity"] as? [[String: Any]] {
            print("Importing \(businessData.count) BusinessEntity records...")
            let businessResult = try await importBusinessEntities(businessData, context: context, entityMapping: &entityMapping)
            results.append(businessResult)
        }
        
        // 6. Import Client (depends on Payee, Address, PlanManager)
        if let clientData = json["ClientEntity"] as? [[String: Any]] {
            print("Importing \(clientData.count) Client records...")
            let clientResult = try await importClientEntities(clientData, context: context, entityMapping: &entityMapping)
            results.append(clientResult)
        } else {
            print("WARNING: No ClientEntity data found in JSON")
        }
        
        // 7. Import ClientServiceEntity (depends on Client)
        if let clientServiceData = json["ClientServiceEntity"] as? [[String: Any]] {
            let clientServiceResult = try await importClientServiceEntities(clientServiceData, context: context, entityMapping: &entityMapping)
            results.append(clientServiceResult)
        }
        
        // 8. Import InvoiceEntity (depends on Client)
        if let invoiceData = json["InvoiceEntity"] as? [[String: Any]] {
            let invoiceResult = try await importInvoiceEntities(invoiceData, context: context, entityMapping: &entityMapping)
            results.append(invoiceResult)
        }
        
        // 9. Import InvoiceItemEntity (depends on InvoiceEntity, ClientServiceEntity)
        if let invoiceItemData = json["InvoiceItemEntity"] as? [[String: Any]] {
            let invoiceItemResult = try await importInvoiceItemEntities(invoiceItemData, context: context, entityMapping: &entityMapping)
            results.append(invoiceItemResult)
        }
        
        // 10. Import SessionEntity (depends on Client)
        if let sessionData = json["SessionEntity"] as? [[String: Any]] {
            let sessionResult = try await importSessionEntities(sessionData, context: context, entityMapping: &entityMapping)
            results.append(sessionResult)
        }
        
        // 11. Import TravelChargeEntity (depends on Client)
        if let travelChargeData = json["TravelChargeEntity"] as? [[String: Any]] {
            let travelChargeResult = try await importTravelChargeEntities(travelChargeData, context: context, entityMapping: &entityMapping)
            results.append(travelChargeResult)
        }
        
        // 12. Import TravelChargeReviewItem (depends on TravelChargeEntity)
        if let travelChargeReviewData = json["TravelChargeReviewItem"] as? [[String: Any]] {
            let travelChargeReviewResult = try await importTravelChargeReviewItems(travelChargeReviewData, context: context, entityMapping: &entityMapping)
            results.append(travelChargeReviewResult)
        }
        
        // 13. Import TravelChargeAuditLog (depends on TravelChargeEntity)
        if let travelChargeAuditData = json["TravelChargeAuditLog"] as? [[String: Any]] {
            let travelChargeAuditResult = try await importTravelChargeAuditLogs(travelChargeAuditData, context: context, entityMapping: &entityMapping)
            results.append(travelChargeAuditResult)
        }
        
        // 14. Import RegionalPriceEntity (depends on ClientServiceEntity/NDISItem)
        if let regionalPriceData = json["RegionalPriceEntity"] as? [[String: Any]] {
            let regionalPriceResult = try await importRegionalPriceEntities(regionalPriceData, context: context, entityMapping: &entityMapping)
            results.append(regionalPriceResult)
        }
        
        // 17. Import CreditHistoryEntryEntity (depends on Client)
        if let creditHistoryData = json["CreditHistoryEntryEntity"] as? [[String: Any]] {
            let creditHistoryResult = try await importCreditHistoryEntryEntities(creditHistoryData, context: context, entityMapping: &entityMapping)
            results.append(creditHistoryResult)
        }
        
        // Save all imported entities to persist them to the store
        do {
            try context.save()
            let totalImported = results.reduce(0) { $0 + $1.successful }
            let totalFailed = results.reduce(0) { $0 + $1.failed }
            print("Successfully imported and saved \(totalImported) total entities across \(results.count) entity types to SwiftData store")
            print("Import summary:")
            for result in results {
                print("  \(result.source.description): \(result.successful) successful, \(result.failed) failed")
            }
            if totalFailed > 0 {
                print("WARNING: \(totalFailed) entities failed to import")
            }
        } catch {
            print("Error saving imported entities: \(error)")
            throw ImportError.saveFailed(error.localizedDescription)
        }
        
        return results
    }
    
    // MARK: - Individual Entity Import Functions
    
    private static func importAddressEntities(_ data: [[String: Any]], context: ModelContext, entityMapping: inout [String: Any]) async throws -> ImportExportView.ImportResults {
        var successful = 0
        var failed = 0
        var messages: [String] = []
        
        for addressDict in data {
            do {
                let address = try createAddress(from: addressDict)
                context.insert(address)
                
                // Store in mapping for relationship resolution using original ID
                if let objectURI = addressDict["_objectURI"] as? String {
                    entityMapping[objectURI] = address
                }
                // Store by original ID for relationship resolution
                if let originalId = addressDict["id"] as? String {
                    entityMapping[originalId] = address
                }
                
                successful += 1
            } catch {
                failed += 1
                messages.append("Failed to import address: \(error.localizedDescription)")
            }
        }
        
        return ImportExportView.ImportResults(
            source: .unknown,
            successful: successful,
            failed: failed,
            messages: messages,
            fileName: "AllData-Export"
        )
    }
    
    private static func importPayeeEntities(_ data: [[String: Any]], context: ModelContext, entityMapping: inout [String: Any]) async throws -> ImportExportView.ImportResults {
        var successful = 0
        var failed = 0
        var messages: [String] = []
        
        for payeeDict in data {
            do {
                let payee = try createPayee(from: payeeDict, entityMapping: entityMapping)
                context.insert(payee)
                
                // Store in mapping for relationship resolution using original ID
                if let objectURI = payeeDict["_objectURI"] as? String {
                    entityMapping[objectURI] = payee
                }
                // Store by original ID for relationship resolution
                if let originalId = payeeDict["id"] as? String {
                    entityMapping[originalId] = payee
                }
                
                successful += 1
            } catch {
                failed += 1
                messages.append("Failed to import payee: \(error.localizedDescription)")
            }
        }
        
        return ImportExportView.ImportResults(
            source: .payees,
            successful: successful,
            failed: failed,
            messages: messages,
            fileName: "AllData-Export"
        )
    }
    
    private static func importClientEntities(_ data: [[String: Any]], context: ModelContext, entityMapping: inout [String: Any]) async throws -> ImportExportView.ImportResults {
        var successful = 0
        var failed = 0
        var messages: [String] = []
        
        for clientDict in data {
            do {
                let ndisNumber = clientDict["ndisNumber"] as? String ?? ""
                
                // Check if a client with this ndisNumber already exists
                let descriptor = FetchDescriptor<ClientEntity>(
                    predicate: #Predicate<ClientEntity> { client in
                        client.ndisNumber == ndisNumber
                    }
                )
                
                let existingClients = try context.fetch(descriptor)
                let existingClient = existingClients.first
                
                let client: ClientEntity
                
                if let existing = existingClient {
                    // Update existing client instead of creating new one
                    existing.fullName = clientDict["fullName"] as? String ?? ""
                    existing.status = ClientStatus(rawValue: clientDict["status"] as? String ?? "Active") ?? .active
                    // colorHex property removed - no longer supported
                    existing.billingAuthority = BillingAuthority(rawValue: clientDict["billingAuthority"] as? String ?? "Client")
                    existing.creditAmount = clientDict["creditAmount"] as? Double ?? 0.0
                    existing.isMinor = clientDict["isMinor"] as? Bool ?? false
                    existing.hasNdisPlan = clientDict["hasNdisPlan"] as? Bool ?? false
                    existing.notes = clientDict["notes"] as? String
                    existing.phone = clientDict["phone"] as? String
                    existing.email = clientDict["email"] as? String
                    existing.planManagementType = clientDict["planManagementType"] as? String
                    
                    // Set or clear payee relationship if available (stored as UUID string)
                    if let payeeUUID = clientDict["payee"] as? String,
                       let payee = entityMapping[payeeUUID] as? PayeeEntity {
                        existing.payee = payee
                    } else {
                        // Explicitly clear payee relationship if not provided
                        existing.payee = nil
                    }
                    
                    client = existing
                } else {
                    // Create new client
                    client = try createClient(from: clientDict, entityMapping: entityMapping)
                    context.insert(client)
                }
                
                // Store in mapping for relationship resolution using original ID
                if let objectURI = clientDict["_objectURI"] as? String {
                    entityMapping[objectURI] = client
                }
                // Store by original ID for relationship resolution
                if let originalId = clientDict["id"] as? String {
                    entityMapping[originalId] = client
                }
                
                successful += 1
            } catch {
                failed += 1
                messages.append("Failed to import client: \(error.localizedDescription)")
            }
        }
        
        return ImportExportView.ImportResults(
            source: .clients,
            successful: successful,
            failed: failed,
            messages: messages,
            fileName: "AllData-Export"
        )
    }
    
    // MARK: - Entity Creation Functions
    
    private static func createAddress(from dict: [String: Any]) throws -> AddressEntity {
        let address = AddressEntity()
        
        // Generate new UUID instead of preserving existing one to avoid SwiftData remapping issues
        
        address.streetNumber = dict["streetNumber"] as? String ?? ""
        address.streetName = dict["streetName"] as? String ?? ""
        address.suburb = dict["suburb"] as? String ?? ""
        address.state = dict["state"] as? String ?? ""
        address.postcode = dict["postcode"] as? String ?? ""
        address.latitude = dict["latitude"] as? Double ?? 0.0
        address.longitude = dict["longitude"] as? Double ?? 0.0
        
        return address
    }
    
    private static func createPayee(from dict: [String: Any], entityMapping: [String: Any]) throws -> PayeeEntity {
        // Generate new UUID instead of preserving existing one to avoid SwiftData remapping issues
        let fullName = dict["fullName"] as? String ?? ""
        let email = dict["email"] as? String
        let relationToClient = dict["relationToClient"] as? String
        let status = dict["status"] as? String
        let payeeID = dict["payeeID"] as? Int32 ?? 0
        let phone = dict["phone"] as? String
        let _ = dict["notes"] as? String
        // colorHex property removed - no longer supported
        
        let payee = PayeeEntity(id: UUID(), fullName: fullName)
        payee.email = email
        payee.relationToClient = relationToClient
        payee.status = status
        payee.payeeID = payeeID
        payee.phone = phone
        // notes property removed from Payee - no longer supported
        
        // Set address relationship if available (stored as UUID string)
        if let addressUUID = dict["address"] as? String,
           let address = entityMapping[addressUUID] as? AddressEntity {
            payee.address = address
        }
        
        // Set guarded clients array if available (stored as array of UUID strings)
        if let clientUUIDs = dict["guardedClients"] as? [String] {
            var guardedClients: [ClientEntity] = []
            for uuid in clientUUIDs {
                if let client = entityMapping[uuid] as? ClientEntity {
                    guardedClients.append(client)
                }
            }
            payee.guardedClients = guardedClients
        }
        
        // Set invoices array if available (stored as array of UUID strings)
        if let invoiceUUIDs = dict["invoices"] as? [String] {
            var invoices: [InvoiceEntity] = []
            for uuid in invoiceUUIDs {
                if let invoice = entityMapping[uuid] as? InvoiceEntity {
                    invoices.append(invoice)
                }
            }
            payee.invoices = invoices
        }
        
        return payee
    }
    
    private static func createClient(from dict: [String: Any], entityMapping: [String: Any]) throws -> ClientEntity {
        // Generate new UUID instead of preserving existing one to avoid SwiftData remapping issues
        let fullName = dict["fullName"] as? String ?? ""
        let status = dict["status"] as? String ?? "Active"
        let _ = dict["color"] as? String ?? "#000000"
        let billingAuthority = dict["billingAuthority"] as? String
        let creditAmount = dict["creditAmount"] as? Double ?? 0.0
        let isMinor = dict["isMinor"] as? Bool ?? false
        let hasNdisPlan = dict["hasNdisPlan"] as? Bool ?? false
        let ndisNumber = dict["ndisNumber"] as? String ?? ""
        let notes = dict["notes"] as? String
        let phone = dict["phone"] as? String
        let email = dict["email"] as? String
        let planManagementType = dict["planManagementType"] as? String
        
        let client = ClientEntity(
            id: UUID(),
            ndisNumber: ndisNumber,
            fullName: fullName,
            status: ClientStatus(rawValue: status) ?? .active
            // colorHex property removed - no longer supported
        )
        client.billingAuthority = BillingAuthority(rawValue: billingAuthority ?? "Client")
        client.creditAmount = creditAmount
        client.isMinor = isMinor
        client.hasNdisPlan = hasNdisPlan
        client.notes = notes
        client.phone = phone
        client.email = email
        client.planManagementType = planManagementType
        
        // Set address relationship if available
        if let addressRef = dict["address"] as? [String: Any],
           let addressURI = addressRef["_objectURI"] as? String,
           let address = entityMapping[addressURI] as? AddressEntity {
            client.address = address
        }
        
        // Set or clear payee relationship if available (stored as UUID string)
        if let payeeUUID = dict["payee"] as? String,
           let payee = entityMapping[payeeUUID] as? PayeeEntity {
            client.payee = payee
        } else {
            // Explicitly clear payee relationship if not provided
            client.payee = nil
        }
        
        // Set plan manager relationship if available (stored as UUID string)
        if let planManagerUUID = dict["planManager"] as? String,
           let planManager = entityMapping[planManagerUUID] as? PlanManagerEntity {
            client.planManager = planManager
        }
        
        // Set client services array if available (stored as array of UUID strings)
        if let clientServiceUUIDs = dict["clientServices"] as? [String] {
            var clientServices: [ClientServiceEntity] = []
            for uuid in clientServiceUUIDs {
                if let clientService = entityMapping[uuid] as? ClientServiceEntity {
                    clientServices.append(clientService)
                }
            }
            client.clientServices = clientServices
        }
        
        // Set invoices array if available (stored as array of UUID strings)
        if let invoiceUUIDs = dict["invoices"] as? [String] {
            var invoices: [InvoiceEntity] = []
            for uuid in invoiceUUIDs {
                if let invoice = entityMapping[uuid] as? InvoiceEntity {
                    invoices.append(invoice)
                }
            }
            client.invoices = invoices
        }
        
        // Set sessions array if available (stored as array of UUID strings)
        if let sessionUUIDs = dict["sessions"] as? [String] {
            var sessions: [SessionEntity] = []
            for uuid in sessionUUIDs {
                if let session = entityMapping[uuid] as? SessionEntity {
                    sessions.append(session)
                }
            }
            client.sessions = sessions
        }
        
        // Set travel charges array if available (stored as array of UUID strings)
        if let travelChargeUUIDs = dict["travelCharges"] as? [String] {
            var travelCharges: [TravelChargeEntity] = []
            for uuid in travelChargeUUIDs {
                if let travelCharge = entityMapping[uuid] as? TravelChargeEntity {
                    travelCharges.append(travelCharge)
                }
            }
            client.travelCharges = travelCharges
        }
        
        // Set credit history array if available (stored as array of UUID strings)
        if let creditHistoryUUIDs = dict["creditHistory"] as? [String] {
            var creditHistory: [CreditHistoryEntryEntity] = []
            for uuid in creditHistoryUUIDs {
                if let creditHistoryEntry = entityMapping[uuid] as? CreditHistoryEntryEntity {
                    creditHistory.append(creditHistoryEntry)
                }
            }
            client.creditHistory = creditHistory
        }
        
        return client
    }
    
    private static func createPlanManager(from dict: [String: Any], entityMapping: [String: Any]) throws -> PlanManagerEntity {
        // Generate new UUID instead of preserving existing one to avoid SwiftData remapping issues
        let abn = dict["abn"] as? String ?? ""
        let businessName = dict["businessName"] as? String
        let email = dict["email"] as? String
        let phone = dict["phone"] as? String
        
        let planManager = PlanManagerEntity(id: UUID(), abn: abn)
        planManager.name = businessName
        planManager.email = email
        planManager.phone = phone
        
        // Set address relationship if available (stored as UUID string)
        if let addressUUID = dict["address"] as? String,
           let address = entityMapping[addressUUID] as? AddressEntity {
            planManager.address = address
        }
        
        // Set managed clients array if available (stored as array of UUID strings)
        if let clientUUIDs = dict["managedClients"] as? [String] {
            var managedClients: [ClientEntity] = []
            for uuid in clientUUIDs {
                if let client = entityMapping[uuid] as? ClientEntity {
                    managedClients.append(client)
                }
            }
            planManager.managedClients = managedClients
        }
        
        return planManager
    }
    
    private static func createNDISItemEntity(from dict: [String: Any]) throws -> NDISItemEntity {
        // Generate new UUID instead of preserving existing one to avoid SwiftData remapping issues
        let itemNumber = dict["itemNumber"] as? String ?? ""
        let name = dict["name"] as? String ?? ""
        let versionIdentifier = dict["versionIdentifier"] as? String ?? ""
        
        let ndisItem = NDISItemEntity(id: UUID(), itemNumber: itemNumber, name: name, versionIdentifier: versionIdentifier)
        
        // Set optional properties
        ndisItem.isCurrent = dict["isCurrent"] as? Bool ?? true
        ndisItem.category = dict["category"] as? String
        ndisItem.categoryNamePACE = dict["categoryNamePACE"] as? String
        ndisItem.categoryNumber = dict["categoryNumber"] as? String
        ndisItem.categoryNumberPACE = dict["categoryNumberPACE"] as? String
        ndisItem.features = dict["features"] as? String
        ndisItem.itemDescription = dict["itemDescription"] as? String
        ndisItem.ndiaRequestedReports = dict["ndiaRequestedReports"] as? Bool
        ndisItem.nonFaceToFaceProvision = dict["nonFaceToFaceProvision"] as? Bool
        ndisItem.providerTravel = dict["providerTravel"] as? Bool
        ndisItem.quoteRequired = dict["quoteRequired"] as? Bool
        ndisItem.registrationGroup = dict["registrationGroup"] as? String
        ndisItem.registrationGroupNumber = dict["registrationGroupNumber"] as? String
        ndisItem.shortNoticeCancellations = dict["shortNoticeCancellations"] as? Bool
        ndisItem.irregularSILSupports = dict["irregularSILSupports"] as? Bool
        ndisItem.status = dict["status"] as? String
        ndisItem.type = dict["type"] as? String
        ndisItem.unit = dict["unit"] as? String
        
        // Handle dates
        if let effectiveStartDateString = dict["effectiveStartDate"] as? String {
            ndisItem.effectiveStartDate = ISO8601DateFormatter().date(from: effectiveStartDateString)
        }
        if let effectiveEndDateString = dict["effectiveEndDate"] as? String {
            ndisItem.effectiveEndDate = ISO8601DateFormatter().date(from: effectiveEndDateString)
        }
        
        return ndisItem
    }
    
    // MARK: - Additional Entity Import Functions
    
    private static func importPlanManagerEntities(_ data: [[String: Any]], context: ModelContext, entityMapping: inout [String: Any]) async throws -> ImportExportView.ImportResults {
        var successful = 0
        var failed = 0
        var messages: [String] = []
        
        for planManagerDict in data {
            do {
                let abn = planManagerDict["abn"] as? String ?? ""
                
                // Check if a plan manager with this abn already exists
                let descriptor = FetchDescriptor<PlanManagerEntity>(
                    predicate: #Predicate<PlanManagerEntity> { planManager in
                        planManager.abn == abn
                    }
                )
                
                let existingPlanManagers = try context.fetch(descriptor)
                let existingPlanManager = existingPlanManagers.first
                
                let planManager: PlanManagerEntity
                
                if let existing = existingPlanManager {
                    // Update existing plan manager instead of creating new one
                    existing.name = planManagerDict["businessName"] as? String
                    existing.email = planManagerDict["email"] as? String
                    existing.phone = planManagerDict["phone"] as? String
                    
                    planManager = existing
                } else {
                    // Create new plan manager
                    planManager = try createPlanManager(from: planManagerDict, entityMapping: entityMapping)
                    context.insert(planManager)
                }
                
                // Store in mapping for relationship resolution using original ID
                if let objectURI = planManagerDict["_objectURI"] as? String {
                    entityMapping[objectURI] = planManager
                }
                // Store by original ID for relationship resolution
                if let originalId = planManagerDict["id"] as? String {
                    entityMapping[originalId] = planManager
                }
                
                successful += 1
            } catch {
                failed += 1
                messages.append("Failed to import plan manager: \(error.localizedDescription)")
            }
        }
        
        return ImportExportView.ImportResults(
            source: .unknown,
            successful: successful,
            failed: failed,
            messages: messages,
            fileName: "AllData-Export"
        )
    }
    
    private static func importNDISItemEntities(_ data: [[String: Any]], context: ModelContext, entityMapping: inout [String: Any]) async throws -> ImportExportView.ImportResults {
        var successful = 0
        var failed = 0
        var messages: [String] = []
        
        for ndisDict in data {
            do {
                _ = ndisDict["itemNumber"] as? String ?? ""
                let versionIdentifier = ndisDict["versionIdentifier"] as? String ?? ""
                
                // Check if an NDIS item with this versionIdentifier already exists
                let descriptor = FetchDescriptor<NDISItemEntity>(
                    predicate: #Predicate<NDISItemEntity> { item in
                        item.versionIdentifier == versionIdentifier
                    }
                )
                
                let existingItems = try context.fetch(descriptor)
                let existingItem = existingItems.first
                
                let ndisItem: NDISItemEntity
                
                if let existing = existingItem {
                    // Update existing item instead of creating new one
                    existing.name = ndisDict["name"] as? String ?? ""
                    existing.versionIdentifier = ndisDict["versionIdentifier"] as? String ?? ""
                    existing.isCurrent = ndisDict["isCurrent"] as? Bool ?? true
                    existing.category = ndisDict["category"] as? String
                    existing.categoryNamePACE = ndisDict["categoryNamePACE"] as? String
                    existing.categoryNumber = ndisDict["categoryNumber"] as? String
                    existing.categoryNumberPACE = ndisDict["categoryNumberPACE"] as? String
                    existing.features = ndisDict["features"] as? String
                    existing.itemDescription = ndisDict["itemDescription"] as? String
                    existing.ndiaRequestedReports = ndisDict["ndiaRequestedReports"] as? Bool
                    existing.nonFaceToFaceProvision = ndisDict["nonFaceToFaceProvision"] as? Bool
                    existing.providerTravel = ndisDict["providerTravel"] as? Bool
                    existing.quoteRequired = ndisDict["quoteRequired"] as? Bool
                    existing.registrationGroup = ndisDict["registrationGroup"] as? String
                    existing.registrationGroupNumber = ndisDict["registrationGroupNumber"] as? String
                    existing.shortNoticeCancellations = ndisDict["shortNoticeCancellations"] as? Bool
                    existing.irregularSILSupports = ndisDict["irregularSILSupports"] as? Bool
                    existing.status = ndisDict["status"] as? String
                    existing.type = ndisDict["type"] as? String
                    existing.unit = ndisDict["unit"] as? String
                    
                    // Handle dates
                    if let effectiveStartDateString = ndisDict["effectiveStartDate"] as? String {
                        existing.effectiveStartDate = ISO8601DateFormatter().date(from: effectiveStartDateString)
                    }
                    if let effectiveEndDateString = ndisDict["effectiveEndDate"] as? String {
                        existing.effectiveEndDate = ISO8601DateFormatter().date(from: effectiveEndDateString)
                    }
                    
                    ndisItem = existing
                } else {
                    // Create new item
                    ndisItem = try createNDISItemEntity(from: ndisDict)
                    context.insert(ndisItem)
                }
                
                // Store in mapping for relationship resolution using original ID
                if let objectURI = ndisDict["_objectURI"] as? String {
                    entityMapping[objectURI] = ndisItem
                }
                // Store by original ID for relationship resolution
                if let originalId = ndisDict["id"] as? String {
                    entityMapping[originalId] = ndisItem
                }
                
                successful += 1
            } catch {
                failed += 1
                messages.append("Failed to import NDIS item: \(error.localizedDescription)")
            }
        }
        
        return ImportExportView.ImportResults(
            source: .ndisItems,
            successful: successful,
            failed: failed,
            messages: messages,
            fileName: "AllData-Export"
        )
    }
    

    
    private static func importBusinessEntities(_ data: [[String: Any]], context: ModelContext, entityMapping: inout [String: Any]) async throws -> ImportExportView.ImportResults {
        var successful = 0
        var failed = 0
        var messages: [String] = []
        
        for businessDict in data {
            do {
                let abn = businessDict["abn"] as? String ?? ""
                
                // Check if a business with this abn already exists
                let descriptor = FetchDescriptor<BusinessEntity>(
                    predicate: #Predicate<BusinessEntity> { business in
                        business.abn == abn
                    }
                )
                
                let existingBusinesses = try context.fetch(descriptor)
                let existingBusiness = existingBusinesses.first
                
                let business: BusinessEntity
                
                if let existing = existingBusiness {
                    // Update existing business instead of creating new one
                    existing.name = businessDict["name"] as? String ?? ""
                    existing.email = businessDict["email"] as? String ?? ""
                    existing.phone = businessDict["phone"] as? String ?? ""
                    existing.accountingMethod = businessDict["accountingMethod"] as? String ?? "Accrual"
                    existing.bankAccountName = businessDict["bankAccountName"] as? String
                    existing.bankAccountNumber = businessDict["bankAccountNumber"] as? String
                    existing.bankBSB = businessDict["bankBSB"] as? String
                    existing.bankName = businessDict["bankName"] as? String
                    
                    business = existing
                } else {
                    // Create new business
                    business = try createBusinessEntity(from: businessDict, entityMapping: entityMapping)
                    context.insert(business)
                }
                
                // Store in mapping for relationship resolution using original ID
                if let objectURI = businessDict["_objectURI"] as? String {
                    entityMapping[objectURI] = business
                }
                // Store by original ID for relationship resolution
                if let originalId = businessDict["id"] as? String {
                    entityMapping[originalId] = business
                }
                
                successful += 1
            } catch {
                failed += 1
                messages.append("Failed to import business: \(error.localizedDescription)")
            }
        }
        
        return ImportExportView.ImportResults(
            source: .unknown,
            successful: successful,
            failed: failed,
            messages: messages,
            fileName: "AllData-Export"
        )
    }
    
    private static func importClientServiceEntities(_ data: [[String: Any]], context: ModelContext, entityMapping: inout [String: Any]) async throws -> ImportExportView.ImportResults {
        var successful = 0
        var failed = 0
        var messages: [String] = []
        
        for clientServiceDict in data {
            do {
                let clientService = try createClientServiceEntity(from: clientServiceDict, entityMapping: entityMapping)
                context.insert(clientService)
                
                // Store in mapping for relationship resolution using original ID
                if let objectURI = clientServiceDict["_objectURI"] as? String {
                    entityMapping[objectURI] = clientService
                }
                // Store by original ID for relationship resolution
                if let originalId = clientServiceDict["id"] as? String {
                    entityMapping[originalId] = clientService
                }
                
                successful += 1
            } catch {
                failed += 1
                messages.append("Failed to import client service: \(error.localizedDescription)")
            }
        }
        
        return ImportExportView.ImportResults(
            source: .unknown,
            successful: successful,
            failed: failed,
            messages: messages,
            fileName: "AllData-Export"
        )
    }
    
    private static func importInvoiceEntities(_ data: [[String: Any]], context: ModelContext, entityMapping: inout [String: Any]) async throws -> ImportExportView.ImportResults {
        var successful = 0
        var failed = 0
        var messages: [String] = []
        
        for invoiceDict in data {
            do {
                let invoiceNumber = invoiceDict["invoiceNumber"] as? String ?? ""
                
                // Check if an invoice with this invoiceNumber already exists
                let descriptor = FetchDescriptor<InvoiceEntity>(
                    predicate: #Predicate<InvoiceEntity> { invoice in
                        invoice.invoiceNumber == invoiceNumber
                    }
                )
                
                let existingInvoices = try context.fetch(descriptor)
                let existingInvoice = existingInvoices.first
                
                let invoice: InvoiceEntity
                
                if let existing = existingInvoice {
                    // Update existing invoice instead of creating new one
                    existing.totalAmount = invoiceDict["totalAmount"] as? Double ?? 0.0
                    existing.taxRate = invoiceDict["taxRate"] as? Double ?? 0.0
                    existing.creditApplied = invoiceDict["creditApplied"] as? Double ?? 0.0
                    existing.discount = invoiceDict["discount"] as? Double ?? 0.0
                    existing.invoiceID = invoiceDict["invoiceID"] as? Int32 ?? 0
                    existing.notes = invoiceDict["notes"] as? String
                    existing.paymentTerms = invoiceDict["paymentTerms"] as? String
                    existing.status = InvoiceStatus(rawValue: invoiceDict["status"] as? String ?? "Draft")
                    
                    // Handle dates
                    if let dateString = invoiceDict["date"] as? String {
                        existing.date = ISO8601DateFormatter().date(from: dateString) ?? Date()
                    }
                    if let dueDateString = invoiceDict["dueDate"] as? String {
                        existing.dueDate = ISO8601DateFormatter().date(from: dueDateString)
                    }
                    if let issueDateString = invoiceDict["issueDate"] as? String {
                        existing.issueDate = ISO8601DateFormatter().date(from: issueDateString) ?? Date()
                    }
                    if let paidDateString = invoiceDict["paidDate"] as? String {
                        existing.paidDate = ISO8601DateFormatter().date(from: paidDateString)
                    }
                    
                    invoice = existing
                } else {
                    // Create new invoice
                    invoice = try createInvoiceEntity(from: invoiceDict, entityMapping: entityMapping)
                    context.insert(invoice)
                }
                
                // Store in mapping for relationship resolution using original ID
                if let objectURI = invoiceDict["_objectURI"] as? String {
                    entityMapping[objectURI] = invoice
                }
                // Store by original ID for relationship resolution
                if let originalId = invoiceDict["id"] as? String {
                    entityMapping[originalId] = invoice
                }
                
                successful += 1
            } catch {
                failed += 1
                messages.append("Failed to import invoice: \(error.localizedDescription)")
            }
        }
        
        return ImportExportView.ImportResults(
            source: .invoices,
            successful: successful,
            failed: failed,
            messages: messages,
            fileName: "AllData-Export"
        )
    }
    
    private static func importInvoiceItemEntities(_ data: [[String: Any]], context: ModelContext, entityMapping: inout [String: Any]) async throws -> ImportExportView.ImportResults {
        var successful = 0
        var failed = 0
        var messages: [String] = []
        
        for invoiceItemDict in data {
            do {
                let invoiceItem = try createInvoiceItemEntity(from: invoiceItemDict, entityMapping: entityMapping)
                context.insert(invoiceItem)
                
                // Store in mapping for relationship resolution using original ID
                if let objectURI = invoiceItemDict["_objectURI"] as? String {
                    entityMapping[objectURI] = invoiceItem
                }
                // Store by original ID for relationship resolution
                if let originalId = invoiceItemDict["id"] as? String {
                    entityMapping[originalId] = invoiceItem
                }
                
                successful += 1
            } catch {
                failed += 1
                messages.append("Failed to import invoice item: \(error.localizedDescription)")
            }
        }
        
        return ImportExportView.ImportResults(
            source: .unknown,
            successful: successful,
            failed: failed,
            messages: messages,
            fileName: "AllData-Export"
        )
    }
    
    private static func importSessionEntities(_ data: [[String: Any]], context: ModelContext, entityMapping: inout [String: Any]) async throws -> ImportExportView.ImportResults {
        var successful = 0
        var failed = 0
        var messages: [String] = []
        
        for sessionDict in data {
            do {
                let session = try createSessionEntity(from: sessionDict, entityMapping: entityMapping)
                context.insert(session)
                
                // Store in mapping for relationship resolution using original ID
                if let objectURI = sessionDict["_objectURI"] as? String {
                    entityMapping[objectURI] = session
                }
                // Store by original ID for relationship resolution
                if let originalId = sessionDict["id"] as? String {
                    entityMapping[originalId] = session
                }
                
                successful += 1
            } catch {
                failed += 1
                messages.append("Failed to import session: \(error.localizedDescription)")
            }
        }
        
        return ImportExportView.ImportResults(
            source: .sessions,
            successful: successful,
            failed: failed,
            messages: messages,
            fileName: "AllData-Export"
        )
    }
    
    private static func importTravelChargeEntities(_ data: [[String: Any]], context: ModelContext, entityMapping: inout [String: Any]) async throws -> ImportExportView.ImportResults {
        var successful = 0
        var failed = 0
        var messages: [String] = []
        
        for travelChargeDict in data {
            do {
                let travelCharge = try createTravelChargeEntity(from: travelChargeDict, entityMapping: entityMapping)
                context.insert(travelCharge)
                
                // Store in mapping for relationship resolution using original ID
                if let objectURI = travelChargeDict["_objectURI"] as? String {
                    entityMapping[objectURI] = travelCharge
                }
                // Store by original ID for relationship resolution
                if let originalId = travelChargeDict["id"] as? String {
                    entityMapping[originalId] = travelCharge
                }
                
                successful += 1
            } catch {
                failed += 1
                messages.append("Failed to import travel charge: \(error.localizedDescription)")
            }
        }
        
        return ImportExportView.ImportResults(
            source: .unknown,
            successful: successful,
            failed: failed,
            messages: messages,
            fileName: "AllData-Export"
        )
    }
    
    private static func importTravelChargeReviewItems(_ data: [[String: Any]], context: ModelContext, entityMapping: inout [String: Any]) async throws -> ImportExportView.ImportResults {
        var successful = 0
        var failed = 0
        var messages: [String] = []
        
        for reviewItemDict in data {
            do {
                let reviewItem = try createTravelChargeReviewItem(from: reviewItemDict, entityMapping: entityMapping)
                context.insert(reviewItem)
                
                // Store in mapping for relationship resolution using original ID
                if let objectURI = reviewItemDict["_objectURI"] as? String {
                    entityMapping[objectURI] = reviewItem
                }
                // Store by original ID for relationship resolution
                if let originalId = reviewItemDict["id"] as? String {
                    entityMapping[originalId] = reviewItem
                }
                
                successful += 1
            } catch {
                failed += 1
                messages.append("Failed to import travel charge review item: \(error.localizedDescription)")
            }
        }
        
        return ImportExportView.ImportResults(
            source: .unknown,
            successful: successful,
            failed: failed,
            messages: messages,
            fileName: "AllData-Export"
        )
    }
    
    private static func importTravelChargeAuditLogs(_ data: [[String: Any]], context: ModelContext, entityMapping: inout [String: Any]) async throws -> ImportExportView.ImportResults {
        var successful = 0
        var failed = 0
        var messages: [String] = []
        
        for auditLogDict in data {
            do {
                let auditLog = try createTravelChargeAuditLog(from: auditLogDict, entityMapping: entityMapping)
                context.insert(auditLog)
                
                // Store in mapping for relationship resolution using original ID
                if let objectURI = auditLogDict["_objectURI"] as? String {
                    entityMapping[objectURI] = auditLog
                }
                // Store by original ID for relationship resolution
                if let originalId = auditLogDict["id"] as? String {
                    entityMapping[originalId] = auditLog
                }
                
                successful += 1
            } catch {
                failed += 1
                messages.append("Failed to import travel charge audit log: \(error.localizedDescription)")
            }
        }
        
        return ImportExportView.ImportResults(
            source: .unknown,
            successful: successful,
            failed: failed,
            messages: messages,
            fileName: "AllData-Export"
        )
    }
    

    
    private static func importRegionalPriceEntities(_ data: [[String: Any]], context: ModelContext, entityMapping: inout [String: Any]) async throws -> ImportExportView.ImportResults {
        var successful = 0
        var failed = 0
        var messages: [String] = []
        
        for regionalPriceDict in data {
            do {
                let regionalPrice = try createRegionalPriceEntity(from: regionalPriceDict, entityMapping: entityMapping)
                context.insert(regionalPrice)
                
                // Store in mapping for relationship resolution using original ID
                if let objectURI = regionalPriceDict["_objectURI"] as? String {
                    entityMapping[objectURI] = regionalPrice
                }
                // Store by original ID for relationship resolution
                if let originalId = regionalPriceDict["id"] as? String {
                    entityMapping[originalId] = regionalPrice
                }
                
                successful += 1
            } catch {
                failed += 1
                messages.append("Failed to import regional price: \(error.localizedDescription)")
            }
        }
        
        return ImportExportView.ImportResults(
            source: .unknown,
            successful: successful,
            failed: failed,
            messages: messages,
            fileName: "AllData-Export"
        )
    }
    
    private static func importCreditHistoryEntryEntities(_ data: [[String: Any]], context: ModelContext, entityMapping: inout [String: Any]) async throws -> ImportExportView.ImportResults {
        var successful = 0
        var failed = 0
        var messages: [String] = []
        
        for creditHistoryDict in data {
            do {
                let creditHistory = try createCreditHistoryEntryEntity(from: creditHistoryDict, entityMapping: entityMapping)
                context.insert(creditHistory)
                
                // Store in mapping for relationship resolution using original ID
                if let objectURI = creditHistoryDict["_objectURI"] as? String {
                    entityMapping[objectURI] = creditHistory
                }
                // Store by original ID for relationship resolution
                if let originalId = creditHistoryDict["id"] as? String {
                    entityMapping[originalId] = creditHistory
                }
                
                successful += 1
            } catch {
                failed += 1
                messages.append("Failed to import credit history entry: \(error.localizedDescription)")
            }
        }
        
        return ImportExportView.ImportResults(
            source: .unknown,
            successful: successful,
            failed: failed,
            messages: messages,
            fileName: "AllData-Export"
        )
    }
    

    
    // MARK: - Entity Creation Functions
    

    
    private static func createBusinessEntity(from dict: [String: Any], entityMapping: [String: Any]) throws -> BusinessEntity {
        // Generate new UUID instead of preserving existing one to avoid SwiftData remapping issues
        let abn = dict["abn"] as? String ?? ""
        let name = dict["name"] as? String ?? ""
        let email = dict["email"] as? String ?? ""
        let phone = dict["phone"] as? String ?? ""
        let accountingMethod = dict["accountingMethod"] as? String ?? "Accrual"
        let bankAccountName = dict["bankAccountName"] as? String
        let bankAccountNumber = dict["bankAccountNumber"] as? String
        let bankBSB = dict["bankBSB"] as? String
        let bankName = dict["bankName"] as? String
        
        let business = BusinessEntity(id: UUID(), abn: abn)
        business.name = name
        business.email = email
        business.phone = phone
        business.accountingMethod = accountingMethod
        business.bankAccountName = bankAccountName
        business.bankAccountNumber = bankAccountNumber
        business.bankBSB = bankBSB
        business.bankName = bankName
        
        // Set address relationship if available (stored as nested object with _objectURI)
        if let addressRef = dict["address"] as? [String: Any],
           let addressURI = addressRef["_objectURI"] as? String,
           let address = entityMapping[addressURI] as? AddressEntity {
            business.address = address
        }
        

        
        // Set invoices array if available (stored as array of UUID strings)
        if let invoiceUUIDs = dict["invoices"] as? [String] {
            var invoices: [InvoiceEntity] = []
            for uuid in invoiceUUIDs {
                if let invoice = entityMapping[uuid] as? InvoiceEntity {
                    invoices.append(invoice)
                }
            }
            business.invoices = invoices
        }
        
        return business
    }
    
    private static func createClientServiceEntity(from dict: [String: Any], entityMapping: [String: Any]) throws -> ClientServiceEntity {
        // Generate new UUID instead of preserving existing one to avoid SwiftData remapping issues
        let serviceName = dict["serviceName"] as? String ?? ""
        let unit = dict["unit"] as? String ?? ""
        let rate = dict["rate"] as? Double ?? 0.0
        let status = dict["status"] as? String
        let clientServiceID = dict["clientServiceID"] as? Int32 ?? 0
        let ndisCode = dict["ndisCode"] as? String
        let isActive = dict["isActive"] as? Bool ?? true
        
        let clientService = ClientServiceEntity(id: UUID(), serviceName: serviceName, unit: unit, rate: rate)
        clientService.status = status
        clientService.clientServiceID = clientServiceID
        clientService.ndisCode = ndisCode
        clientService.isActive = isActive
        
        // Set dates
        if let startDateString = dict["startDate"] as? String {
            clientService.startDate = ISO8601DateFormatter().date(from: startDateString)
        }
        if let endDateString = dict["endDate"] as? String {
            clientService.endDate = ISO8601DateFormatter().date(from: endDateString)
        }
        
        // Set client relationship if available
        if let clientId = dict["client"] as? String,
           let client = entityMapping[clientId] as? ClientEntity {
            clientService.client = client
        }
        
        // Set NDIS item relationship if available
        if let ndisItemId = dict["ndisItem"] as? String,
           let ndisItem = entityMapping[ndisItemId] as? NDISItemEntity {
            clientService.ndisItem = ndisItem
        }
        
        return clientService
    }
    
    private static func createInvoiceEntity(from dict: [String: Any], entityMapping: [String: Any]) throws -> InvoiceEntity {
        // Generate new UUID instead of preserving existing one to avoid SwiftData remapping issues
        let invoiceNumber = dict["invoiceNumber"] as? String ?? ""
        let totalAmount = dict["totalAmount"] as? Double ?? 0.0
        let taxRate = dict["taxRate"] as? Double ?? 0.0
        let creditApplied = dict["creditApplied"] as? Double ?? 0.0
        let discount = dict["discount"] as? Double ?? 0.0
        let invoiceID = dict["invoiceID"] as? Int32 ?? 0
        let notes = dict["notes"] as? String
        let paymentTerms = dict["paymentTerms"] as? String
        let status = dict["status"] as? String
        
        let invoice = InvoiceEntity(id: UUID(), invoiceNumber: invoiceNumber)
        invoice.totalAmount = totalAmount
        invoice.taxRate = taxRate
        invoice.creditApplied = creditApplied
        invoice.discount = discount
        invoice.invoiceID = invoiceID
        invoice.notes = notes
        invoice.paymentTerms = paymentTerms
        invoice.status = InvoiceStatus(rawValue: status ?? "Draft") ?? .draft
        
        // Set dates
        if let dateString = dict["date"] as? String {
            invoice.date = ISO8601DateFormatter().date(from: dateString) ?? Date()
        }
        if let dueDateString = dict["dueDate"] as? String {
            invoice.dueDate = ISO8601DateFormatter().date(from: dueDateString)
        }
        if let issueDateString = dict["issueDate"] as? String {
            invoice.issueDate = ISO8601DateFormatter().date(from: issueDateString) ?? Date()
        }
        if let paidDateString = dict["paidDate"] as? String {
            invoice.paidDate = ISO8601DateFormatter().date(from: paidDateString)
        }
        
        // Set client relationship if available
        if let clientId = dict["client"] as? String,
           let client = entityMapping[clientId] as? ClientEntity {
            invoice.client = client
        
            // Set payee relationship based on client's billing authority
            // If billing authority is parent/guardian and client has a payee, link invoice to that payee
            // This ensures invoices inherit the correct payee from their client
            if client.billingAuthority == .parentGuardian, let clientPayee = client.payee {
                invoice.payee = clientPayee
            } else {
                // If explicit payee ID provided, use that instead
        if let payeeId = dict["payee"] as? String,
           let payee = entityMapping[payeeId] as? PayeeEntity {
            invoice.payee = payee
                } else {
                    // Explicitly clear payee relationship if not applicable
                    invoice.payee = nil
                }
            }
        } else {
            // Client not found, but still try to set payee if explicitly provided
            if let payeeId = dict["payee"] as? String,
               let payee = entityMapping[payeeId] as? PayeeEntity {
                invoice.payee = payee
            } else {
                invoice.payee = nil
            }
            invoice.client = nil
        }
        
        // Populate snapshot fields from relationships after setting them
        invoice.snapshotRelatedData()
        
        // Set invoice items array if available (stored as array of UUID strings)
        if let invoiceItemUUIDs = dict["invoiceItems"] as? [String] {
            var invoiceItems: [InvoiceItemEntity] = []
            for uuid in invoiceItemUUIDs {
                if let invoiceItem = entityMapping[uuid] as? InvoiceItemEntity {
                    invoiceItems.append(invoiceItem)
                }
            }
            invoice.items = invoiceItems
        }
        
        return invoice
    }
    
    private static func createInvoiceItemEntity(from dict: [String: Any], entityMapping: [String: Any]) throws -> InvoiceItemEntity {
        // Generate new UUID instead of preserving existing one to avoid SwiftData remapping issues
        let itemDescription = dict["itemDescription"] as? String ?? ""
        let amount = dict["amount"] as? Double ?? 0.0
        let position = dict["position"] as? Int32 ?? 0
        let quantity = dict["quantity"] as? Double ?? 0.0
        let rate = dict["rate"] as? Double ?? 0.0
        let unit = dict["unit"] as? String
        let taxRate = dict["taxRate"] as? Double ?? 0.0
        
        let invoiceItem = InvoiceItemEntity(id: UUID(), itemDescription: itemDescription)
        invoiceItem.amount = amount
        invoiceItem.position = position
        invoiceItem.quantity = quantity
        invoiceItem.rate = rate
        invoiceItem.unit = unit
        invoiceItem.taxRate = taxRate
        
        // Set date
        if let dateString = dict["date"] as? String {
            invoiceItem.date = ISO8601DateFormatter().date(from: dateString) ?? Date()
        }
        
        // Set invoice relationship if available
        if let invoiceId = dict["invoice"] as? String,
           let invoice = entityMapping[invoiceId] as? InvoiceEntity {
            invoiceItem.invoice = invoice
        }
        
        // Set session relationship if available
        if let sessionId = dict["session"] as? String,
           let session = entityMapping[sessionId] as? SessionEntity {
            invoiceItem.session = session
        }
        
        // Set client service relationship if available
        if let clientServiceId = dict["clientService"] as? String,
           let clientService = entityMapping[clientServiceId] as? ClientServiceEntity {
            invoiceItem.clientService = clientService
        }
        
        return invoiceItem
    }
    
    private static func createSessionEntity(from dict: [String: Any], entityMapping: [String: Any]) throws -> SessionEntity {
        // Generate new UUID instead of preserving existing one to avoid SwiftData remapping issues
        let title = dict["title"] as? String ?? ""
        let notes = dict["notes"] as? String
        let status = dict["status"] as? String
        let location = dict["location"] as? String
        let attendeesCount = dict["attendeesCount"] as? Int32 ?? 0
        let isTravel = dict["isTravel"] as? Bool ?? false
        let sessionLatitude = dict["sessionLatitude"] as? Double ?? 0.0
        let sessionLongitude = dict["sessionLongitude"] as? Double ?? 0.0
        
        let session = SessionEntity(id: UUID())
        session.title = title
        session.notes = notes
        session.status = SessionStatus(rawValue: status ?? "Scheduled") ?? .scheduled
        session.location = location
        session.attendeesCount = attendeesCount
        session.isTravel = isTravel
        session.sessionLatitude = sessionLatitude
        session.sessionLongitude = sessionLongitude
        
        // Set dates
        if let startTimeString = dict["startTime"] as? String {
            session.startTime = ISO8601DateFormatter().date(from: startTimeString)
        }
        if let endTimeString = dict["endTime"] as? String {
            session.endTime = ISO8601DateFormatter().date(from: endTimeString)
        }
        if let occurrenceDateString = dict["occurrenceDate"] as? String {
            session.occurrenceDate = ISO8601DateFormatter().date(from: occurrenceDateString)
        }
        if let lastModifiedDateString = dict["lastModifiedDate"] as? String {
            session.lastModifiedDate = ISO8601DateFormatter().date(from: lastModifiedDateString)
        }
        if let ekCreationDateString = dict["ekCreationDate"] as? String {
            session.ekCreationDate = ISO8601DateFormatter().date(from: ekCreationDateString)
        }
        
        // Set client relationship if available
        if let clientId = dict["client"] as? String,
           let client = entityMapping[clientId] as? ClientEntity {
            session.client = client
        }
        
        // Set client service relationship if available
        if let clientServiceId = dict["clientService"] as? String,
           let clientService = entityMapping[clientServiceId] as? ClientServiceEntity {
            session.clientService = clientService
        }
        
        // Set address relationship if available (stored as UUID string)
        if let addressUUID = dict["address"] as? String,
           let address = entityMapping[addressUUID] as? AddressEntity {
            session.address = address
        }
        
        // Set invoice items array if available (stored as array of UUID strings)
        if let invoiceItemUUIDs = dict["invoiceItems"] as? [String] {
            var invoiceItems: [InvoiceItemEntity] = []
            for uuid in invoiceItemUUIDs {
                if let invoiceItem = entityMapping[uuid] as? InvoiceItemEntity {
                    invoiceItems.append(invoiceItem)
                }
            }
            session.invoiceItems = invoiceItems
        }
        
        return session
    }
    
    private static func createTravelChargeEntity(from dict: [String: Any], entityMapping: [String: Any]) throws -> TravelChargeEntity {
        // Generate new UUID instead of preserving existing one to avoid SwiftData remapping issues
        let title = dict["title"] as? String ?? ""
        let notes = dict["notes"] as? String
        let location = dict["location"] as? String
        let mmmZoneName = dict["mmmZoneName"] as? String
        let travelDistance = dict["travelDistance"] as? Double
        let travelDuration = dict["travelDuration"] as? Double
        let vehicleType = dict["vehicleType"] as? String
        let parkingCost = dict["parkingCost"] as? Double
        let tollCost = dict["tollCost"] as? Double
        let participantCount = dict["participantCount"] as? Int16
        let splitCosts = dict["splitCosts"] as? Bool
        let chargeType = dict["chargeType"] as? String
        let travelDirection = dict["travelDirection"] as? String
        
        let travelCharge = TravelChargeEntity(id: UUID())
        travelCharge.title = title
        travelCharge.notes = notes
        travelCharge.location = location
        travelCharge.mmmZoneName = mmmZoneName
        travelCharge.travelDistance = travelDistance
        travelCharge.travelDuration = travelDuration
        travelCharge.vehicleType = VehicleType(rawValue: vehicleType ?? "car")
        travelCharge.parkingCost = parkingCost
        travelCharge.tollCost = tollCost
        travelCharge.participantCount = participantCount
        travelCharge.splitCosts = splitCosts
        travelCharge.chargeType = TravelChargeType(rawValue: chargeType ?? "standard")
        travelCharge.travelDirection = TravelChargeDirection(rawValue: travelDirection ?? "toClient")
        
        // Set dates
        if let startTimeString = dict["startTime"] as? String {
            travelCharge.startTime = ISO8601DateFormatter().date(from: startTimeString)
        }
        if let endTimeString = dict["endTime"] as? String {
            travelCharge.endTime = ISO8601DateFormatter().date(from: endTimeString)
        }
        if let occurrenceDateString = dict["occurrenceDate"] as? String {
            travelCharge.occurrenceDate = ISO8601DateFormatter().date(from: occurrenceDateString)
        }
        if let lastModifiedDateString = dict["lastModifiedDate"] as? String {
            travelCharge.lastModifiedDate = ISO8601DateFormatter().date(from: lastModifiedDateString)
        }
        if let ekCreationDateString = dict["ekCreationDate"] as? String {
            travelCharge.ekCreationDate = ISO8601DateFormatter().date(from: ekCreationDateString)
        }
        
        // Set client relationship if available
        if let clientId = dict["client"] as? String,
           let client = entityMapping[clientId] as? ClientEntity {
            travelCharge.client = client
        }
        
        // Set service relationship if available
        if let serviceId = dict["service"] as? String,
           let service = entityMapping[serviceId] as? ClientServiceEntity {
            travelCharge.service = service
        }
        
        // Set linked session relationship if available
        if let linkedSessionId = dict["linkedSession"] as? String,
           let linkedSession = entityMapping[linkedSessionId] as? SessionEntity {
            travelCharge.linkedSession = linkedSession
        }
        
        return travelCharge
    }
    
    private static func createTravelChargeReviewItem(from dict: [String: Any], entityMapping: [String: Any]) throws -> TravelChargeReviewItem {
        // Generate new UUID instead of preserving existing one to avoid SwiftData remapping issues
        let reason = dict["reason"] as? String
        
        let reviewItem = TravelChargeReviewItem(id: UUID())
        reviewItem.reason = reason
        
        // Set timestamp
        if let timestampString = dict["timestamp"] as? String {
            reviewItem.timestamp = ISO8601DateFormatter().date(from: timestampString)
        }
        
        // Set session relationship if available
        if let sessionId = dict["session"] as? String,
           let session = entityMapping[sessionId] as? SessionEntity {
            reviewItem.session = session
        }
        
        return reviewItem
    }
    
    private static func createTravelChargeAuditLog(from dict: [String: Any], entityMapping: [String: Any]) throws -> TravelChargeAuditLog {
        // Generate new UUID instead of preserving existing one to avoid SwiftData remapping issues
        let summary = dict["summary"] as? String
        
        let auditLog = TravelChargeAuditLog(id: UUID())
        auditLog.summary = summary
        
        // Set timestamp
        if let timestampString = dict["timestamp"] as? String {
            auditLog.timestamp = ISO8601DateFormatter().date(from: timestampString)
        }
        
        // Set travel charge relationship if available
        if let chargeId = dict["charge"] as? String,
           let charge = entityMapping[chargeId] as? TravelChargeEntity {
            auditLog.charge = charge
        }
        
        return auditLog
    }
    

    
    private static func createRegionalPriceEntity(from dict: [String: Any], entityMapping: [String: Any]) throws -> RegionalPriceEntity {
        // Generate new UUID instead of preserving existing one to avoid SwiftData remapping issues
        let amount = dict["amount"] as? Double ?? 0.0
        let regionIdentifier = dict["regionIdentifier"] as? String
        
        let regionalPrice = RegionalPriceEntity(id: UUID())
        regionalPrice.amount = amount
        regionalPrice.regionIdentifier = regionIdentifier
        
        // Set NDIS item relationship if available
        if let ndisItemId = dict["ndisItem"] as? String,
           let ndisItem = entityMapping[ndisItemId] as? NDISItemEntity {
            regionalPrice.ndisItem = ndisItem
        }
        
        return regionalPrice
    }
    
    private static func createCreditHistoryEntryEntity(from dict: [String: Any], entityMapping: [String: Any]) throws -> CreditHistoryEntryEntity {
        // Generate new UUID instead of preserving existing one to avoid SwiftData remapping issues
        let amount = dict["amount"] as? Double ?? 0.0
        let type = dict["type"] as? String
        let notes = dict["notes"] as? String
        let relatedInvoiceNumber = dict["relatedInvoiceNumber"] as? String
        
        let creditHistory = CreditHistoryEntryEntity(id: UUID())
        creditHistory.amount = amount
        creditHistory.type = CreditHistoryType(rawValue: type ?? "credit")
        creditHistory.notes = notes
        creditHistory.relatedInvoiceNumber = relatedInvoiceNumber
        
        // Set date
        if let dateString = dict["date"] as? String {
            creditHistory.date = ISO8601DateFormatter().date(from: dateString)
        }
        
        // Set client relationship if available
        if let clientId = dict["client"] as? String,
           let client = entityMapping[clientId] as? ClientEntity {
            creditHistory.client = client
        }
        
        return creditHistory
    }
    

}

// MARK: - Error Types

enum ImportError: Error, LocalizedError {
    case invalidJSONFormat
    case missingRequiredField(String)
    case invalidUUID(String)
    case relationshipNotFound(String)
    case saveFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidJSONFormat:
            return "Invalid JSON format"
        case .missingRequiredField(let field):
            return "Missing required field: \(field)"
        case .invalidUUID(let value):
            return "Invalid UUID: \(value)"
        case .relationshipNotFound(let relationship):
            return "Relationship not found: \(relationship)"
        case .saveFailed(let reason):
            return "Failed to save imported entities: \(reason)"
        }
    }
} 
