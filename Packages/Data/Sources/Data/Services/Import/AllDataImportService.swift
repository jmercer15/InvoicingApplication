import os
import Foundation
import SwiftData
import Core

/// Comprehensive import service for AllData-Export JSON files
struct AllDataImportService {
    
    /// Main import function that processes the AllData-Export JSON file
    static func importAllData(from data: Data, context: ModelContext) throws -> [ImportResult] {
        var results: [ImportResult] = []
        
        Logger.importExport.info("Starting AllData import process...")
        
        let payload = try AllDataImportPayload(data: data)
        Logger.importExport.info("JSON structure keys: \(payload.sortedKeys)")
        
        // Create a mapping of object URIs to actual entities for relationship resolution
        var entityMapping: [String: Any] = [:]
        
        // Import entities in dependency order (entities with relationships come after their dependencies)
        
        // 1. Import Address first (no dependencies)
        if let addressData = payload.rows(for: .address) {
            Logger.importExport.info("Importing \(addressData.count) Address records...")
            let addressResult = try importAddressEntities(addressData, context: context, entityMapping: &entityMapping)
            results.append(addressResult)
        } else {
            Logger.importExport.warning("WARNING: No Address data found in JSON")
        }
        
        // 2. Import Payee (depends on Address)
        if let payeeData = payload.rows(for: .payee) {
            Logger.importExport.info("Importing \(payeeData.count) Payee records...")
            let payeeResult = try importPayeeEntities(payeeData, context: context, entityMapping: &entityMapping)
            results.append(payeeResult)
        }
        
        // 3. Import PlanManager (no dependencies)
        if let planManagerData = payload.rows(for: .planManager) {
            let planManagerResult = try importPlanManagerEntities(planManagerData, context: context, entityMapping: &entityMapping)
            results.append(planManagerResult)
        }
        
        // 4. Import NDISItem (no dependencies)
        if let ndisData = payload.rows(for: .ndisItem) {
            let ndisResult = try importNDISItemEntities(ndisData, context: context, entityMapping: &entityMapping)
            results.append(ndisResult)
        }
        
        // 5. Import Business (no dependencies)
        if let businessData = payload.rows(for: .business) {
            Logger.importExport.info("Importing \(businessData.count) Business records...")
            let businessResult = try importBusinessEntities(businessData, context: context, entityMapping: &entityMapping)
            results.append(businessResult)
        }
        
        // 6. Import Client (depends on Payee, Address, PlanManager)
        if let clientData = payload.rows(for: .client) {
            Logger.importExport.info("Importing \(clientData.count) Client records...")
            let clientResult = try importClientEntities(clientData, context: context, entityMapping: &entityMapping)
            results.append(clientResult)
        }
        
        // 7. Import ClientService (depends on Client)
        if let clientServiceData = payload.rows(for: .clientService) {
            let clientServiceResult = try importClientServiceEntities(clientServiceData, context: context, entityMapping: &entityMapping)
            results.append(clientServiceResult)
        }
        
        // 8. Import Invoice (depends on Client)
        if let invoiceData = payload.rows(for: .invoice) {
            let invoiceResult = try importInvoiceEntities(invoiceData, context: context, entityMapping: &entityMapping)
            results.append(invoiceResult)
        }
        
        // 9. Import InvoiceItem (depends on Invoice, ClientService)
        if let invoiceItemData = payload.rows(for: .invoiceItem) {
            let invoiceItemResult = try importInvoiceItemEntities(invoiceItemData, context: context, entityMapping: &entityMapping)
            results.append(invoiceItemResult)
        }
        
        // 10. Import ServiceAgreement (depends on Client)
        if let serviceAgreementData = payload.rows(for: .serviceAgreement) {
            let serviceAgreementResult = try importServiceAgreementEntities(serviceAgreementData, context: context, entityMapping: &entityMapping)
            results.append(serviceAgreementResult)
        }
        
        // 11. Import Session (depends on Client)
        if let sessionData = payload.rows(for: .session) {
            let sessionResult = try importSessionEntities(sessionData, context: context, entityMapping: &entityMapping)
            results.append(sessionResult)
        }
        
        // 12. Import SupportLog (depends on Client, Session)
        if let supportLogData = payload.rows(for: .supportLog) {
            let supportLogResult = try importSupportLogEntities(supportLogData, context: context, entityMapping: &entityMapping)
            results.append(supportLogResult)
        }
        
        // 13. Import TravelCharge (depends on Client)
        if let travelChargeData = payload.rows(for: .travelCharge) {
            let travelChargeResult = try importTravelChargeEntities(travelChargeData, context: context, entityMapping: &entityMapping)
            results.append(travelChargeResult)
        }
        
        // 14. Import TravelChargeReviewItem (depends on TravelCharge)
        if let travelChargeReviewData = payload.rows(for: .travelChargeReviewItem) {
            let travelChargeReviewResult = try importTravelChargeReviewItems(travelChargeReviewData, context: context, entityMapping: &entityMapping)
            results.append(travelChargeReviewResult)
        }
        
        // 15. Import TravelChargeAuditLog (depends on TravelCharge)
        if let travelChargeAuditData = payload.rows(for: .travelChargeAuditLog) {
            let travelChargeAuditResult = try importTravelChargeAuditLogs(travelChargeAuditData, context: context, entityMapping: &entityMapping)
            results.append(travelChargeAuditResult)
        }
        
        // 16. Import RegionalPrice (depends on ClientService/NDISItem)
        if let regionalPriceData = payload.rows(for: .regionalPrice) {
            let regionalPriceResult = try importRegionalPriceEntities(regionalPriceData, context: context, entityMapping: &entityMapping)
            results.append(regionalPriceResult)
        }
        
        // 17. Import CreditHistoryEntry (depends on Client)
        if let creditHistoryData = payload.rows(for: .creditHistoryEntry) {
            let creditHistoryResult = try importCreditHistoryEntryEntities(creditHistoryData, context: context, entityMapping: &entityMapping)
            results.append(creditHistoryResult)
        }
        
        // 18. Import BulkClaimBatch (no dependencies)
        if let bulkBatchData = payload.rows(for: .bulkClaimBatch) {
            let bulkBatchResult = try importBulkClaimBatchEntities(bulkBatchData, context: context, entityMapping: &entityMapping)
            results.append(bulkBatchResult)
        }
        
        // 19. Import BulkClaimLine (depends on BulkClaimBatch, Invoice, InvoiceItem)
        if let bulkLineData = payload.rows(for: .bulkClaimLine) {
            let bulkLineResult = try importBulkClaimLineEntities(bulkLineData, context: context, entityMapping: &entityMapping)
            results.append(bulkLineResult)
        }
        
        // Save all imported entities to persist them to the store
        do {
            try context.save()
            let totalImported = results.reduce(0) { $0 + $1.successful }
            let totalFailed = results.reduce(0) { $0 + $1.failed }
            Logger.importExport.info("Successfully imported and saved \(totalImported) total entities across \(results.count) entity types to SwiftData store")
            
            if totalFailed > 0 {
                Logger.importExport.warning("WARNING: \(totalFailed) entities failed to import")
            }
        } catch {
            Logger.importExport.warning("Error saving imported entities: \(error)")
        }
        
        return results
    }
}
