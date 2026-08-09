import Foundation
import SwiftData
import Core
import PersistenceModels

extension AllDataImportService {
    
    internal static func importAddressEntities(_ data: [[String: Any]], context: ModelContext, entityMapping: inout [String: Any]) throws -> ImportResult {
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
            source: .unknown,
            successful: successful,
            failed: failed,
            messages: messages,
            fileName: "AllData-Export"
        )
    }
    
    internal static func importPayeeEntities(_ data: [[String: Any]], context: ModelContext, entityMapping: inout [String: Any]) throws -> ImportResult {
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
    
    internal static func importClientEntities(_ data: [[String: Any]], context: ModelContext, entityMapping: inout [String: Any]) throws -> ImportResult {
        var successful = 0
        var failed = 0
        var messages: [String] = []
        
        for clientDict in data {
            do {
                let ndisNumber = clientDict["ndisNumber"] as? String ?? ""
                
                var client: Client?
                
                if !ndisNumber.isEmpty {
                    let descriptor = FetchDescriptor<Client>(
                        predicate: #Predicate<Client> { client in
                            client.ndisNumber == ndisNumber
                        }
                    )
                    client = try context.fetch(descriptor).first
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
    
    internal static func importPlanManagerEntities(_ data: [[String: Any]], context: ModelContext, entityMapping: inout [String: Any]) throws -> ImportResult {
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

    internal static func importNDISItemEntities(_ data: [[String: Any]], context: ModelContext, entityMapping: inout [String: Any]) throws -> ImportResult {
        var successful = 0
        var failed = 0
        var messages: [String] = []
        
        for ndisDict in data {
            do {
                let ndisItem = try AllDataFactories.createNDISItem(from: ndisDict)
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

    internal static func importBusinessEntities(_ data: [[String: Any]], context: ModelContext, entityMapping: inout [String: Any]) throws -> ImportResult {
        var successful = 0
        var failed = 0
        var messages: [String] = []
        
        for businessDict in data {
            do {
                let business = try AllDataFactories.createBusiness(from: businessDict, entityMapping: entityMapping)
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
}
