import Foundation
import SwiftData
import Core

extension AllDataImportService {
    
    internal static func importClientServiceEntities(_ data: [[String: Any]], context: ModelContext, entityMapping: inout [String: Any]) throws -> ImportResult {
        var successful = 0
        var failed = 0
        var messages: [String] = []
        
        for csDict in data {
            do {
                let cs = try AllDataFactories.createClientService(from: csDict, entityMapping: entityMapping)
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
            source: .unknown,
            successful: successful,
            failed: failed,
            messages: messages,
            fileName: "AllData-Export"
        )
    }

    internal static func importInvoiceEntities(_ data: [[String: Any]], context: ModelContext, entityMapping: inout [String: Any]) throws -> ImportResult {
        var successful = 0
        var failed = 0
        var messages: [String] = []
        
        for invDict in data {
            do {
                let invoice = try AllDataFactories.createInvoice(from: invDict, entityMapping: entityMapping)
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

    internal static func importInvoiceItemEntities(_ data: [[String: Any]], context: ModelContext, entityMapping: inout [String: Any]) throws -> ImportResult {
        var successful = 0
        var failed = 0
        var messages: [String] = []
        
        for itemDict in data {
            do {
                let item = try AllDataFactories.createInvoiceItem(from: itemDict, entityMapping: entityMapping)
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

    internal static func importServiceAgreementEntities(_ data: [[String: Any]], context: ModelContext, entityMapping: inout [String: Any]) throws -> ImportResult {
        var successful = 0
        var failed = 0
        var messages: [String] = []

        for agreementDict in data {
            do {
                let agreement = try AllDataFactories.createServiceAgreement(from: agreementDict, entityMapping: entityMapping)
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

    internal static func importSessionEntities(_ data: [[String: Any]], context: ModelContext, entityMapping: inout [String: Any]) throws -> ImportResult {
        var successful = 0
        var failed = 0
        var messages: [String] = []
        
        for sessionDict in data {
            do {
                let session = try AllDataFactories.createSession(from: sessionDict, entityMapping: entityMapping)
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

    internal static func importSupportLogEntities(_ data: [[String: Any]], context: ModelContext, entityMapping: inout [String: Any]) throws -> ImportResult {
        var successful = 0
        var failed = 0
        var messages: [String] = []

        for logDict in data {
            do {
                let log = try AllDataFactories.createSupportLog(from: logDict, entityMapping: entityMapping)
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

    internal static func importRegionalPriceEntities(_ data: [[String: Any]], context: ModelContext, entityMapping: inout [String: Any]) throws -> ImportResult {
        var successful = 0
        var failed = 0
        var messages: [String] = []
        
        for priceDict in data {
            do {
                let price = try AllDataFactories.createRegionalPrice(from: priceDict, entityMapping: entityMapping)
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

    internal static func importCreditHistoryEntryEntities(_ data: [[String: Any]], context: ModelContext, entityMapping: inout [String: Any]) throws -> ImportResult {
        var successful = 0
        var failed = 0
        var messages: [String] = []
        
        for creditDict in data {
            do {
                let credit = try AllDataFactories.createCreditHistoryEntry(from: creditDict, entityMapping: entityMapping)
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

    internal static func importBulkClaimBatchEntities(_ data: [[String: Any]], context: ModelContext, entityMapping: inout [String: Any]) throws -> ImportResult {
        var successful = 0
        var failed = 0
        var messages: [String] = []

        for batchDict in data {
            do {
                let batch = try AllDataFactories.createBulkClaimBatch(from: batchDict)
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

    internal static func importBulkClaimLineEntities(_ data: [[String: Any]], context: ModelContext, entityMapping: inout [String: Any]) throws -> ImportResult {
        var successful = 0
        var failed = 0
        var messages: [String] = []

        for lineDict in data {
            do {
                let line = try AllDataFactories.createBulkClaimLine(from: lineDict, entityMapping: entityMapping)
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
