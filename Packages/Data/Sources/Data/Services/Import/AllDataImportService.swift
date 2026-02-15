import Foundation
import SwiftData
import Core

/// Comprehensive import service for AllData-Export JSON files
struct AllDataImportService {
    
    /// Main import function that processes the AllData-Export JSON file
    static func importAllData(from data: Data, context: ModelContext) throws -> [ImportResult] {
        var results: [ImportResult] = []
        
        print("Starting AllData import process...")
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            print("ERROR: Failed to parse JSON data")
            throw NSError(domain: "ImportError", code: 100, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON Format"])
        }
        
        print("JSON structure keys: \(Array(json.keys).sorted())")
        
        // Create a mapping of object URIs to actual entities for relationship resolution
        var entityMapping: [String: Any] = [:]
        
        // Import entities in dependency order (entities with relationships come after their dependencies)
        
        // 1. Import Address first (no dependencies)
        if let addressData = json["AddressEntity"] as? [[String: Any]] {
            print("Importing \(addressData.count) Address records...")
            let addressResult = try importAddressEntities(addressData, context: context, entityMapping: &entityMapping)
            results.append(addressResult)
        } else {
            print("WARNING: No AddressEntity data found in JSON")
        }
        
        // 2. Import Payee (depends on Address)
        if let payeeData = json["PayeeEntity"] as? [[String: Any]] {
            print("Importing \(payeeData.count) Payee records...")
            let payeeResult = try importPayeeEntities(payeeData, context: context, entityMapping: &entityMapping)
            results.append(payeeResult)
        }
        
        // 3. Import PlanManager (no dependencies)
        if let planManagerData = json["PlanManagerEntity"] as? [[String: Any]] {
            let planManagerResult = try importPlanManagerEntities(planManagerData, context: context, entityMapping: &entityMapping)
            results.append(planManagerResult)
        }
        
        // 4. Import NDISItemEntity (no dependencies)
        if let ndisData = json["NDISItemEntity"] as? [[String: Any]] {
            let ndisResult = try importNDISItemEntities(ndisData, context: context, entityMapping: &entityMapping)
            results.append(ndisResult)
        }
        
        // 5. Import BusinessEntity (no dependencies)
        if let businessData = json["BusinessEntity"] as? [[String: Any]] {
            print("Importing \(businessData.count) BusinessEntity records...")
            let businessResult = try importBusinessEntities(businessData, context: context, entityMapping: &entityMapping)
            results.append(businessResult)
        }
        
        // 6. Import Client (depends on Payee, Address, PlanManager)
        if let clientData = json["ClientEntity"] as? [[String: Any]] {
            print("Importing \(clientData.count) Client records...")
            let clientResult = try importClientEntities(clientData, context: context, entityMapping: &entityMapping)
            results.append(clientResult)
        }
        
        // 7. Import ClientServiceEntity (depends on Client)
        if let clientServiceData = json["ClientServiceEntity"] as? [[String: Any]] {
            let clientServiceResult = try importClientServiceEntities(clientServiceData, context: context, entityMapping: &entityMapping)
            results.append(clientServiceResult)
        }
        
        // 8. Import InvoiceEntity (depends on Client)
        if let invoiceData = json["InvoiceEntity"] as? [[String: Any]] {
            let invoiceResult = try importInvoiceEntities(invoiceData, context: context, entityMapping: &entityMapping)
            results.append(invoiceResult)
        }
        
        // 9. Import InvoiceItemEntity (depends on InvoiceEntity, ClientServiceEntity)
        if let invoiceItemData = json["InvoiceItemEntity"] as? [[String: Any]] {
            let invoiceItemResult = try importInvoiceItemEntities(invoiceItemData, context: context, entityMapping: &entityMapping)
            results.append(invoiceItemResult)
        }
        
        // 10. Import ServiceAgreementEntity (depends on Client)
        if let serviceAgreementData = json["ServiceAgreementEntity"] as? [[String: Any]] {
            let serviceAgreementResult = try importServiceAgreementEntities(serviceAgreementData, context: context, entityMapping: &entityMapping)
            results.append(serviceAgreementResult)
        }

        // 11. Import SessionEntity (depends on Client)
        if let sessionData = json["SessionEntity"] as? [[String: Any]] {
            let sessionResult = try importSessionEntities(sessionData, context: context, entityMapping: &entityMapping)
            results.append(sessionResult)
        }

        // 12. Import SupportLogEntity (depends on Client, Session)
        if let supportLogData = json["SupportLogEntity"] as? [[String: Any]] {
            let supportLogResult = try importSupportLogEntities(supportLogData, context: context, entityMapping: &entityMapping)
            results.append(supportLogResult)
        }

        // 13. Import TravelChargeEntity (depends on Client)
        if let travelChargeData = json["TravelChargeEntity"] as? [[String: Any]] {
            let travelChargeResult = try importTravelChargeEntities(travelChargeData, context: context, entityMapping: &entityMapping)
            results.append(travelChargeResult)
        }

        // 14. Import TravelChargeReviewItem (depends on TravelChargeEntity)
        if let travelChargeReviewData = json["TravelChargeReviewItem"] as? [[String: Any]] {
            let travelChargeReviewResult = try importTravelChargeReviewItems(travelChargeReviewData, context: context, entityMapping: &entityMapping)
            results.append(travelChargeReviewResult)
        }

        // 15. Import TravelChargeAuditLog (depends on TravelChargeEntity)
        if let travelChargeAuditData = json["TravelChargeAuditLog"] as? [[String: Any]] {
            let travelChargeAuditResult = try importTravelChargeAuditLogs(travelChargeAuditData, context: context, entityMapping: &entityMapping)
            results.append(travelChargeAuditResult)
        }

        // 16. Import RegionalPriceEntity (depends on ClientServiceEntity/NDISItem)
        if let regionalPriceData = json["RegionalPriceEntity"] as? [[String: Any]] {
            let regionalPriceResult = try importRegionalPriceEntities(regionalPriceData, context: context, entityMapping: &entityMapping)
            results.append(regionalPriceResult)
        }

        // 17. Import CreditHistoryEntryEntity (depends on Client)
        if let creditHistoryData = json["CreditHistoryEntryEntity"] as? [[String: Any]] {
            let creditHistoryResult = try importCreditHistoryEntryEntities(creditHistoryData, context: context, entityMapping: &entityMapping)
            results.append(creditHistoryResult)
        }

        // 18. Import BulkClaimBatchEntity (no dependencies)
        if let bulkBatchData = json["BulkClaimBatchEntity"] as? [[String: Any]] {
            let bulkBatchResult = try importBulkClaimBatchEntities(bulkBatchData, context: context, entityMapping: &entityMapping)
            results.append(bulkBatchResult)
        }

        // 19. Import BulkClaimLineEntity (depends on BulkClaimBatchEntity, InvoiceEntity, InvoiceItemEntity)
        if let bulkLineData = json["BulkClaimLineEntity"] as? [[String: Any]] {
            let bulkLineResult = try importBulkClaimLineEntities(bulkLineData, context: context, entityMapping: &entityMapping)
            results.append(bulkLineResult)
        }
        
        // Save all imported entities to persist them to the store
        do {
            try context.save()
            let totalImported = results.reduce(0) { $0 + $1.successful }
            let totalFailed = results.reduce(0) { $0 + $1.failed }
            print("Successfully imported and saved \(totalImported) total entities across \(results.count) entity types to SwiftData store")
            
            if totalFailed > 0 {
                print("WARNING: \(totalFailed) entities failed to import")
            }
        } catch {
            print("Error saving imported entities: \(error)")
            // We don't throw here to allow partial success reporting, but we log it
        }
        
        return results
    }
    
    // MARK: - Individual Entity Import Functions
    
    private static func importAddressEntities(_ data: [[String: Any]], context: ModelContext, entityMapping: inout [String: Any]) throws -> ImportResult {
        var successful = 0
        var failed = 0
        var messages: [String] = []
        
        for addressDict in data {
            do {
                let address = try AllDataFactories.createAddress(from: addressDict)
                context.insert(address)
                
                if let odUri = addressDict["_objectURI"] as? String {
                    entityMapping[odUri] = address
                }
                if let originalId = addressDict["id"] as? String {
                    entityMapping[originalId] = address
                }
                
                successful += 1
            } catch {
                failed += 1
                messages.append("Failed to import address: \(error.localizedDescription)")
            }
        }
        
        return ImportResult(
            source: .unknown, // Address is part of AllData but doesn't have its own source type
            successful: successful,
            failed: failed,
            messages: messages,
            fileName: "AllData-Export"
        )
    }
    
    private static func importPayeeEntities(_ data: [[String: Any]], context: ModelContext, entityMapping: inout [String: Any]) throws -> ImportResult {
        var successful = 0
        var failed = 0
        var messages: [String] = []
        
        for payeeDict in data {
            do {
                let payee = try AllDataFactories.createPayee(from: payeeDict, entityMapping: entityMapping)
                context.insert(payee)
                
                if let objectURI = payeeDict["_objectURI"] as? String {
                    entityMapping[objectURI] = payee
                }
                if let originalId = payeeDict["id"] as? String {
                    entityMapping[originalId] = payee
                }
                
                successful += 1
            } catch {
                failed += 1
                messages.append("Failed to import payee: \(error.localizedDescription)")
            }
        }
        
        return ImportResult(
            source: .payees,
            successful: successful,
            failed: failed,
            messages: messages,
            fileName: "AllData-Export"
        )
    }
    
    private static func importClientEntities(_ data: [[String: Any]], context: ModelContext, entityMapping: inout [String: Any]) throws -> ImportResult {
        var successful = 0
        var failed = 0
        var messages: [String] = []
        
        for clientDict in data {
            do {
                let ndisNumber = clientDict["ndisNumber"] as? String ?? ""
                
                // Check if a client with this ndisNumber already exists
                // We'll skip complex merging logic for AllData import and assume clean import or overwrite mostly
                // But let's check basic existence to avoid duplicates if ndisNumber is set
                var client: ClientEntity?
                
                if !ndisNumber.isEmpty {
                    let descriptor = FetchDescriptor<ClientEntity>(
                        predicate: #Predicate<ClientEntity> { client in
                            client.ndisNumber == ndisNumber
                        }
                    )
                    client = try? context.fetch(descriptor).first
                }

                let importedClient = try AllDataFactories.createClient(from: clientDict, entityMapping: entityMapping)
                if let existingClient = client {
                    existingClient.fullName = importedClient.fullName
                    existingClient.status = importedClient.status
                    existingClient.email = importedClient.email
                    existingClient.notes = importedClient.notes
                    existingClient.phone = importedClient.phone
                    existingClient.creditAmount = importedClient.creditAmount
                    existingClient.isMinor = importedClient.isMinor
                    existingClient.hasNdisPlan = importedClient.hasNdisPlan
                    existingClient.planManagementType = importedClient.planManagementType
                    existingClient.billingAuthority = importedClient.billingAuthority
                    existingClient.address = importedClient.address
                    existingClient.clientServices = importedClient.clientServices
                    existingClient.invoices = importedClient.invoices
                    existingClient.planManager = importedClient.planManager
                    existingClient.creditHistory = importedClient.creditHistory
                    existingClient.travelCharges = importedClient.travelCharges
                    existingClient.sessions = importedClient.sessions
                    existingClient.payee = importedClient.payee
                    existingClient.sendInvoicesToClient = importedClient.sendInvoicesToClient
                    existingClient.sendInvoicesToPayee = importedClient.sendInvoicesToPayee
                    existingClient.sendInvoicesToPlanManager = importedClient.sendInvoicesToPlanManager
                    client = existingClient
                } else {
                    context.insert(importedClient)
                    client = importedClient
                }
                
                if let c = client {
                    if let objectURI = clientDict["_objectURI"] as? String {
                        entityMapping[objectURI] = c
                    }
                    if let originalId = clientDict["id"] as? String {
                        entityMapping[originalId] = c
                    }
                }
                
                successful += 1
            } catch {
                failed += 1
                messages.append("Failed to import client: \(error.localizedDescription)")
            }
        }
        
        return ImportResult(
            source: .clients,
            successful: successful,
            failed: failed,
            messages: messages,
            fileName: "AllData-Export"
        )
    }
    
    // ... Other import methods follow similar pattern using factories ...
    
    private static func importPlanManagerEntities(_ data: [[String: Any]], context: ModelContext, entityMapping: inout [String: Any]) throws -> ImportResult {
        var successful = 0
        var failed = 0
        var messages: [String] = []
        
        for pmDict in data {
            do {
                let planManager = try AllDataFactories.createPlanManager(from: pmDict, entityMapping: entityMapping)
                context.insert(planManager)
                
                if let objectURI = pmDict["_objectURI"] as? String {
                    entityMapping[objectURI] = planManager
                }
                if let originalId = pmDict["id"] as? String {
                    entityMapping[originalId] = planManager
                }
                successful += 1
            } catch {
                failed += 1
                messages.append("Failed to import plan manager: \(error.localizedDescription)")
            }
        }
        
        return ImportResult(
            source: .unknown,
            successful: successful,
            failed: failed,
            messages: messages,
            fileName: "AllData-Export"
        )
    }

    private static func importNDISItemEntities(_ data: [[String: Any]], context: ModelContext, entityMapping: inout [String: Any]) throws -> ImportResult {
        var successful = 0
        var failed = 0
        var messages: [String] = []
        
        for ndisDict in data {
            do {
                let ndisItem = try AllDataFactories.createNDISItemEntity(from: ndisDict)
                context.insert(ndisItem)
                
                if let objectURI = ndisDict["_objectURI"] as? String {
                    entityMapping[objectURI] = ndisItem
                }
                if let originalId = ndisDict["id"] as? String {
                    entityMapping[originalId] = ndisItem
                }
                successful += 1
            } catch {
                failed += 1
                messages.append("Failed to import NDIS item: \(error.localizedDescription)")
            }
        }
        
        return ImportResult(
            source: .ndisItems,
            successful: successful,
            failed: failed,
            messages: messages,
            fileName: "AllData-Export"
        )
    }

    private static func importBusinessEntities(_ data: [[String: Any]], context: ModelContext, entityMapping: inout [String: Any]) throws -> ImportResult {
        var successful = 0
        var failed = 0
        var messages: [String] = []
        
        for businessDict in data {
            do {
                let business = try AllDataFactories.createBusinessEntity(from: businessDict, entityMapping: entityMapping)
                context.insert(business)
                
                if let objectURI = businessDict["_objectURI"] as? String {
                    entityMapping[objectURI] = business
                }
                if let originalId = businessDict["id"] as? String {
                    entityMapping[originalId] = business
                }
                successful += 1
            } catch {
                failed += 1
                messages.append("Failed to import business: \(error.localizedDescription)")
            }
        }
        
        return ImportResult(
            source: .unknown,
            successful: successful,
            failed: failed,
            messages: messages,
            fileName: "AllData-Export"
        )
    }

    private static func importClientServiceEntities(_ data: [[String: Any]], context: ModelContext, entityMapping: inout [String: Any]) throws -> ImportResult {
        var successful = 0
        var failed = 0
        var messages: [String] = []
        
        for csDict in data {
            do {
                let cs = try AllDataFactories.createClientServiceEntity(from: csDict, entityMapping: entityMapping)
                context.insert(cs)
                
                if let objectURI = csDict["_objectURI"] as? String {
                    entityMapping[objectURI] = cs
                }
                if let originalId = csDict["id"] as? String {
                    entityMapping[originalId] = cs
                }
                successful += 1
            } catch {
                failed += 1
                messages.append("Failed to import client service: \(error.localizedDescription)")
            }
        }
        
        return ImportResult(
            source: .unknown, // No specific source enum for client services yet
            successful: successful,
            failed: failed,
            messages: messages,
            fileName: "AllData-Export"
        )
    }

    private static func importInvoiceEntities(_ data: [[String: Any]], context: ModelContext, entityMapping: inout [String: Any]) throws -> ImportResult {
        var successful = 0
        var failed = 0
        var messages: [String] = []
        
        for invDict in data {
            do {
                let invoice = try AllDataFactories.createInvoiceEntity(from: invDict, entityMapping: entityMapping)
                context.insert(invoice)
                
                if let objectURI = invDict["_objectURI"] as? String {
                    entityMapping[objectURI] = invoice
                }
                if let originalId = invDict["id"] as? String {
                    entityMapping[originalId] = invoice
                }
                successful += 1
            } catch {
                failed += 1
                messages.append("Failed to import invoice: \(error.localizedDescription)")
            }
        }
        
        return ImportResult(
            source: .invoices,
            successful: successful,
            failed: failed,
            messages: messages,
            fileName: "AllData-Export"
        )
    }

    private static func importInvoiceItemEntities(_ data: [[String: Any]], context: ModelContext, entityMapping: inout [String: Any]) throws -> ImportResult {
        var successful = 0
        var failed = 0
        var messages: [String] = []
        
        for itemDict in data {
            do {
                let item = try AllDataFactories.createInvoiceItemEntity(from: itemDict, entityMapping: entityMapping)
                context.insert(item)
                
                if let objectURI = itemDict["_objectURI"] as? String {
                    entityMapping[objectURI] = item
                }
                if let originalId = itemDict["id"] as? String {
                    entityMapping[originalId] = item
                }
                successful += 1
            } catch {
                failed += 1
                messages.append("Failed to import invoice item: \(error.localizedDescription)")
            }
        }
        
        return ImportResult(
            source: .unknown,
            successful: successful,
            failed: failed,
            messages: messages,
            fileName: "AllData-Export"
        )
    }

    private static func importServiceAgreementEntities(_ data: [[String: Any]], context: ModelContext, entityMapping: inout [String: Any]) throws -> ImportResult {
        var successful = 0
        var failed = 0
        var messages: [String] = []

        for agreementDict in data {
            do {
                let agreement = try AllDataFactories.createServiceAgreementEntity(from: agreementDict, entityMapping: entityMapping)
                context.insert(agreement)

                if let objectURI = agreementDict["_objectURI"] as? String {
                    entityMapping[objectURI] = agreement
                }
                if let originalId = agreementDict["id"] as? String {
                    entityMapping[originalId] = agreement
                }
                successful += 1
            } catch {
                failed += 1
                messages.append("Failed to import service agreement: \(error.localizedDescription)")
            }
        }

        return ImportResult(
            source: .unknown,
            successful: successful,
            failed: failed,
            messages: messages,
            fileName: "AllData-Export"
        )
    }

    private static func importSessionEntities(_ data: [[String: Any]], context: ModelContext, entityMapping: inout [String: Any]) throws -> ImportResult {
        var successful = 0
        var failed = 0
        var messages: [String] = []
        
        for sessionDict in data {
            do {
                let session = try AllDataFactories.createSessionEntity(from: sessionDict, entityMapping: entityMapping)
                context.insert(session)
                
                if let objectURI = sessionDict["_objectURI"] as? String {
                    entityMapping[objectURI] = session
                }
                if let originalId = sessionDict["id"] as? String {
                    entityMapping[originalId] = session
                }
                successful += 1
            } catch {
                failed += 1
                messages.append("Failed to import session: \(error.localizedDescription)")
            }
        }
        
        return ImportResult(
            source: .sessions,
            successful: successful,
            failed: failed,
            messages: messages,
            fileName: "AllData-Export"
        )
    }

    private static func importSupportLogEntities(_ data: [[String: Any]], context: ModelContext, entityMapping: inout [String: Any]) throws -> ImportResult {
        var successful = 0
        var failed = 0
        var messages: [String] = []

        for logDict in data {
            do {
                let log = try AllDataFactories.createSupportLogEntity(from: logDict, entityMapping: entityMapping)
                context.insert(log)

                if let objectURI = logDict["_objectURI"] as? String {
                    entityMapping[objectURI] = log
                }
                if let originalId = logDict["id"] as? String {
                    entityMapping[originalId] = log
                }
                successful += 1
            } catch {
                failed += 1
                messages.append("Failed to import support log: \(error.localizedDescription)")
            }
        }

        return ImportResult(
            source: .unknown,
            successful: successful,
            failed: failed,
            messages: messages,
            fileName: "AllData-Export"
        )
    }

    private static func importTravelChargeEntities(_ data: [[String: Any]], context: ModelContext, entityMapping: inout [String: Any]) throws -> ImportResult {
        var successful = 0
        var failed = 0
        var messages: [String] = []
        
        for tcDict in data {
            do {
                let tc = try AllDataFactories.createTravelChargeEntity(from: tcDict, entityMapping: entityMapping)
                context.insert(tc)
                
                if let objectURI = tcDict["_objectURI"] as? String {
                    entityMapping[objectURI] = tc
                }
                if let originalId = tcDict["id"] as? String {
                    entityMapping[originalId] = tc
                }
                successful += 1
            } catch {
                failed += 1
                messages.append("Failed to import travel charge: \(error.localizedDescription)")
            }
        }
        
        return ImportResult(
            source: .unknown,
            successful: successful,
            failed: failed,
            messages: messages,
            fileName: "AllData-Export"
        )
    }

    private static func importTravelChargeReviewItems(_ data: [[String: Any]], context: ModelContext, entityMapping: inout [String: Any]) throws -> ImportResult {
        var successful = 0
        var failed = 0
        var messages: [String] = []
        
        for reviewItemDict in data {
            do {
                let item = try AllDataFactories.createTravelChargeReviewItem(from: reviewItemDict, entityMapping: entityMapping)
                context.insert(item)
                
                if let objectURI = reviewItemDict["_objectURI"] as? String {
                    entityMapping[objectURI] = item
                }
                if let originalId = reviewItemDict["id"] as? String {
                    entityMapping[originalId] = item
                }
                successful += 1
            } catch {
                failed += 1
                messages.append("Failed to import travel charge review item: \(error.localizedDescription)")
            }
        }
        
        return ImportResult(
            source: .unknown,
            successful: successful,
            failed: failed,
            messages: messages,
            fileName: "AllData-Export"
        )
    }
    
    private static func importTravelChargeAuditLogs(_ data: [[String: Any]], context: ModelContext, entityMapping: inout [String: Any]) throws -> ImportResult {
        var successful = 0
        var failed = 0
        var messages: [String] = []
        
        for logDict in data {
            do {
                let log = try AllDataFactories.createTravelChargeAuditLog(from: logDict, entityMapping: entityMapping)
                context.insert(log)
                
                if let objectURI = logDict["_objectURI"] as? String {
                    entityMapping[objectURI] = log
                }
                if let originalId = logDict["id"] as? String {
                    entityMapping[originalId] = log
                }
                successful += 1
            } catch {
                failed += 1
                messages.append("Failed to import travel charge audit log: \(error.localizedDescription)")
            }
        }
        
        return ImportResult(
            source: .unknown,
            successful: successful,
            failed: failed,
            messages: messages,
            fileName: "AllData-Export"
        )
    }

    private static func importRegionalPriceEntities(_ data: [[String: Any]], context: ModelContext, entityMapping: inout [String: Any]) throws -> ImportResult {
        var successful = 0
        var failed = 0
        var messages: [String] = []
        
        for priceDict in data {
            do {
                let price = try AllDataFactories.createRegionalPriceEntity(from: priceDict, entityMapping: entityMapping)
                context.insert(price)
                
                if let objectURI = priceDict["_objectURI"] as? String {
                    entityMapping[objectURI] = price
                }
                if let originalId = priceDict["id"] as? String {
                    entityMapping[originalId] = price
                }
                successful += 1
            } catch {
                failed += 1
                messages.append("Failed to import regional price: \(error.localizedDescription)")
            }
        }
        
        return ImportResult(
            source: .unknown,
            successful: successful,
            failed: failed,
            messages: messages,
            fileName: "AllData-Export"
        )
    }

    private static func importCreditHistoryEntryEntities(_ data: [[String: Any]], context: ModelContext, entityMapping: inout [String: Any]) throws -> ImportResult {
        var successful = 0
        var failed = 0
        var messages: [String] = []
        
        for creditDict in data {
            do {
                let credit = try AllDataFactories.createCreditHistoryEntryEntity(from: creditDict, entityMapping: entityMapping)
                context.insert(credit)
                
                if let objectURI = creditDict["_objectURI"] as? String {
                    entityMapping[objectURI] = credit
                }
                if let originalId = creditDict["id"] as? String {
                    entityMapping[originalId] = credit
                }
                successful += 1
            } catch {
                failed += 1
                messages.append("Failed to import credit history: \(error.localizedDescription)")
            }
        }
        
        return ImportResult(
            source: .unknown,
            successful: successful,
            failed: failed,
            messages: messages,
            fileName: "AllData-Export"
        )
    }

    private static func importBulkClaimBatchEntities(_ data: [[String: Any]], context: ModelContext, entityMapping: inout [String: Any]) throws -> ImportResult {
        var successful = 0
        var failed = 0
        var messages: [String] = []

        for batchDict in data {
            do {
                let batch = try AllDataFactories.createBulkClaimBatchEntity(from: batchDict)
                context.insert(batch)

                if let objectURI = batchDict["_objectURI"] as? String {
                    entityMapping[objectURI] = batch
                }
                if let originalId = batchDict["id"] as? String {
                    entityMapping[originalId] = batch
                }
                successful += 1
            } catch {
                failed += 1
                messages.append("Failed to import bulk claim batch: \(error.localizedDescription)")
            }
        }

        return ImportResult(
            source: .unknown,
            successful: successful,
            failed: failed,
            messages: messages,
            fileName: "AllData-Export"
        )
    }

    private static func importBulkClaimLineEntities(_ data: [[String: Any]], context: ModelContext, entityMapping: inout [String: Any]) throws -> ImportResult {
        var successful = 0
        var failed = 0
        var messages: [String] = []

        for lineDict in data {
            do {
                let line = try AllDataFactories.createBulkClaimLineEntity(from: lineDict, entityMapping: entityMapping)
                context.insert(line)

                if let objectURI = lineDict["_objectURI"] as? String {
                    entityMapping[objectURI] = line
                }
                if let originalId = lineDict["id"] as? String {
                    entityMapping[originalId] = line
                }
                successful += 1
            } catch {
                failed += 1
                messages.append("Failed to import bulk claim line: \(error.localizedDescription)")
            }
        }

        return ImportResult(
            source: .unknown,
            successful: successful,
            failed: failed,
            messages: messages,
            fileName: "AllData-Export"
        )
    }
}
