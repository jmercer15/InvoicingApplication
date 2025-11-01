import Foundation
import SwiftUI
import SwiftData
import Data
import Core

// Add struct for services.json format
struct ServicesImportJSON: Codable {
    let parentName: String
    let studentName: String
    let taskName: String
    let code: String
    let rate: String
    let unit: String
    let defaultQuantity: Int?
    
    enum CodingKeys: String, CodingKey {
        case parentName = "Parent Name"
        case studentName = "Student Name"
        case taskName = "Task Name"
        case code = "Code"
        case rate = "Rate"
        case unit = "Unit"
        case defaultQuantity = "Default Quantity"
    }
}

struct ServiceImport {
    static func importServices(data: Data, fileName: String, context: ModelContext) throws -> ImportExportView.ImportResults {
        let decoder = JSONDecoder()
        
        // Try to decode the services.json structure that includes client information first
        if let servicesImport = try? decoder.decode([ServicesImportJSON].self, from: data) {
            return try processClientServices(servicesImport, fileName: fileName, context: context)
        }
        
        // Fall back to the generic format – these are no longer supported because ServiceEntity has been removed
        if let genericServices = try? decoder.decode([ImportExportView.ServiceJSON].self, from: data) {
            return processGenericServices(genericServices, fileName: fileName)
        }
        
        if let singleService = try? decoder.decode(ImportExportView.ServiceJSON.self, from: data) {
            return processGenericServices([singleService], fileName: fileName)
        }
        
        throw NSError(
            domain: "JSONImportError",
            code: 1001,
            userInfo: [
                NSLocalizedDescriptionKey: "Failed to parse service data.",
                NSLocalizedFailureReasonErrorKey: "The JSON structure does not match any supported service format."
            ]
        )
    }
    
    private static func processClientServices(_ servicesImport: [ServicesImportJSON], fileName: String, context: ModelContext) throws -> ImportExportView.ImportResults {
        var successful = 0
        var failed = 0
        var messages: [String] = []
        
        for item in servicesImport {
            do {
                let clientDescriptor = FetchDescriptor<ClientEntity>(predicate: #Predicate { $0.fullName == item.studentName })
                guard let clientEntity = try context.fetch(clientDescriptor).first else {
                    throw NSError(domain: "ImportError", code: 1003, userInfo: [NSLocalizedDescriptionKey: "Client not found: \(item.studentName)"])
                }
                
                let name = item.taskName
                let linkDescriptor = FetchDescriptor<ClientServiceEntity>(predicate: #Predicate { $0.serviceName == name })
                let existingLinks = try context.fetch(linkDescriptor)
                let clientService: ClientServiceEntity
                if let existing = existingLinks.first(where: { $0.client?.id == clientEntity.id }) {
                    clientService = existing
                    messages.append("Updated service link: \(item.taskName) for client \(item.studentName)")
                } else {
                    clientService = ClientServiceEntity(
                        id: UUID(),
                        serviceName: item.taskName,
                        unit: item.unit.isEmpty ? "hour" : item.unit,
                        rate: 0.0
                    )
                    clientService.client = clientEntity
                    clientService.startDate = Date()
                    clientService.clientServiceID = Int32.random(in: 1000...9999)
                    messages.append("Linked service '\(item.taskName)' to client '\(item.studentName)'")
                }
                
                if let parsedRate = Double(item.rate.replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "")) {
                    clientService.rate = parsedRate
                }
                clientService.unit = item.unit.isEmpty ? clientService.unit : item.unit
                clientService.status = "Active"
                clientService.isActive = true
                clientService.ndisCode = item.code != "N/A" ? item.code : clientService.ndisCode
                clientService.endDate = nil
                
                if let code = clientService.ndisCode,
                   let linkedItem = try findNDISItem(matching: code, in: context) {
                    clientService.ndisItem = linkedItem
                }
                
                successful += 1
            } catch {
                failed += 1
                messages.append("Failed to process service link for client '\(item.studentName)' / service '\(item.taskName)': \(error.localizedDescription)")
            }
        }
        
        try context.save()
        
        return ImportExportView.ImportResults(
            source: .services,
            successful: successful,
            failed: failed,
            messages: messages,
            fileName: fileName
        )
    }
    
    private static func processGenericServices(_ services: [ImportExportView.ServiceJSON], fileName: String) -> ImportExportView.ImportResults {
        let messages = services.map { service in
            "Skipped generic service definition '\(service.name)'. Convert this data to NDIS items or client services before importing."
        }
        return ImportExportView.ImportResults(
            source: .services,
            successful: 0,
            failed: services.count,
            messages: messages,
            fileName: fileName
        )
    }
    
    private static func findNDISItem(matching code: String, in context: ModelContext) throws -> NDISItemEntity? {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let descriptor = FetchDescriptor<NDISItemEntity>(predicate: #Predicate { $0.itemNumber == trimmed })
        return try context.fetch(descriptor).first
    }
}
