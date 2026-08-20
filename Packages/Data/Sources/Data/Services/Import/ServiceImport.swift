import Core
import PersistenceModels
import Foundation
import SwiftData

// Add struct for services.json format
struct ServicesImportJSON: Codable {
    let clientID: UUID?
    let clientNDISNumber: String?
    let parentName: String
    let studentName: String
    let taskName: String
    let code: String
    let rate: String
    let unit: String
    let defaultQuantity: Int?
    
    enum CodingKeys: String, CodingKey {
        case clientID = "Client ID"
        case clientNDISNumber = "Client NDIS Number"
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
    static func importServices(data: Data, fileName: String, context: ModelContext) throws -> ImportResult {
        let decoder = JSONDecoder()
        
        // Try to decode the services.json structure that includes client information first
        if let servicesImport = try? decoder.decode([ServicesImportJSON].self, from: data) {
            return try processClientServices(servicesImport, fileName: fileName, context: context)
        }
        
        // Fall back to the generic format – these are no longer supported because ServiceEntity has been removed
        if let genericServices = try? decoder.decode([ServiceJSON].self, from: data) {
            return processGenericServices(genericServices, fileName: fileName)
        }
        
        if let singleService = try? decoder.decode(ServiceJSON.self, from: data) {
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
    
    private static func processClientServices(_ servicesImport: [ServicesImportJSON], fileName: String, context: ModelContext) throws -> ImportResult {
        var successful = 0
        var failed = 0
        var messages: [String] = []
        
        for item in servicesImport {
            do {
                let clientModel = try resolveClient(for: item, context: context)
                
                let serviceName = item.taskName
                let linkDescriptor = FetchDescriptor<ClientService>(predicate: #Predicate<ClientService> { $0.serviceName == serviceName })
                let existingLinks = try context.fetch(linkDescriptor)
                let clientService: ClientService
                if let existing = existingLinks.first(where: { $0.client?.id == clientModel.id }) {
                    clientService = existing
                    messages.append("Updated service link: \(item.taskName) for client \(item.studentName)")
                } else {
                    clientService = ClientService(
                        id: UUID(),
                        serviceName: item.taskName,
                        unit: item.unit.isEmpty ? "hour" : item.unit,
                        rate: 0.0
                    )
                    clientService.client = clientModel
                    clientService.startDate = Date()
                    messages.append("Linked service '\(item.taskName)' to client '\(item.studentName)'")
                }
                
                if let parsedRate = Double(item.rate.replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "")) {
                    clientService.rate = MoneyDecimalImport.decimal(from: parsedRate)
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
        
        return ImportResult(
            source: .services,
            successful: successful,
            failed: failed,
            messages: messages,
            fileName: fileName
        )
    }
    
    private static func processGenericServices(_ services: [ServiceJSON], fileName: String) -> ImportResult {
        let messages = services.map { service in
            "Skipped generic service definition '\(service.name)'. Convert this data to NDIS items or client services before importing."
        }
        return ImportResult(
            source: .services,
            successful: 0,
            failed: services.count,
            messages: messages,
            fileName: fileName
        )
    }
    
    private static func findNDISItem(matching code: String, in context: ModelContext) throws -> NDISItem? {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let descriptor = FetchDescriptor<NDISItem>(predicate: #Predicate<NDISItem> { $0.itemNumber == trimmed })
        return try context.fetch(descriptor).first
    }

    private static func resolveClient(for item: ServicesImportJSON, context: ModelContext) throws -> Client {
        if let id = item.clientID {
            let descriptor = FetchDescriptor<Client>(predicate: #Predicate<Client> { $0.id == id })
            let matches = try context.fetch(descriptor)
            guard matches.count == 1 else {
                throw NSError(domain: "ImportIdentityError", code: 1003, userInfo: [NSLocalizedDescriptionKey: "Service import needs one matching Client ID for \(item.studentName)."])
            }
            return matches[0]
        }

        let ndisNumber = (item.clientNDISNumber ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !ndisNumber.isEmpty else {
            throw NSError(domain: "ImportIdentityError", code: 1003, userInfo: [NSLocalizedDescriptionKey: "Service import needs Client ID or Client NDIS Number for \(item.studentName); name matching is not supported."])
        }
        let descriptor = FetchDescriptor<Client>(predicate: #Predicate<Client> { $0.ndisNumber == ndisNumber })
        let matches = try context.fetch(descriptor)
        guard matches.count == 1 else {
            throw NSError(domain: "ImportIdentityError", code: 1003, userInfo: [NSLocalizedDescriptionKey: "Service import needs one matching Client NDIS Number for \(item.studentName)."])
        }
        return matches[0]
    }
}
