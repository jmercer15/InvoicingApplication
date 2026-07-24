import Foundation
import SwiftData
import Core

extension AllDataImportService {
    
    internal static func importTravelChargeEntities(_ data: [[String: Any]], context: ModelContext, entityMapping: inout [String: Any]) throws -> ImportResult {
        var successful = 0
        var failed = 0
        var messages: [String] = []
        
        for tcDict in data {
            do {
                let tc = try AllDataFactories.createTravelCharge(from: tcDict, entityMapping: entityMapping)
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

    internal static func importTravelChargeReviewItems(_ data: [[String: Any]], context: ModelContext, entityMapping: inout [String: Any]) throws -> ImportResult {
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
    
    internal static func importTravelChargeAuditLogs(_ data: [[String: Any]], context: ModelContext, entityMapping: inout [String: Any]) throws -> ImportResult {
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
}
