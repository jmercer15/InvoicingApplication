import Foundation
import SwiftUI
import SwiftData // Import SwiftData

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
    
    // We won't use toServiceJSON() for this specific import path anymore
    // func toServiceJSON() -> ImportExportView.ServiceJSON { ... }
}

struct ServiceImport {
    static func importServices(data: Data, fileName: String, context: ModelContext) throws -> ImportExportView.ImportResults {
        let decoder = JSONDecoder()
        
        // --- Try the specific services.json format FIRST ---
        do {
            let servicesImport = try decoder.decode([ServicesImportJSON].self, from: data)
            // If successful, process this specific format which includes client linking
            return try processClientServices(servicesImport, fileName: fileName, context: context)
        } catch {
            // --- If specific format fails, try the generic ServiceJSON formats ---
            print("DEBUG: Failed to decode as [ServicesImportJSON], trying generic [ServiceJSON]. Error: \(error)")
            do {
                let services = try decoder.decode([ImportExportView.ServiceJSON].self, from: data)
                // Process generic format (only creates ServiceEntity)
                return try processGenericServices(services, fileName: fileName, context: context)
            } catch {
                print("DEBUG: Failed to decode as [ServiceJSON], trying single ServiceJSON. Error: \(error)")
                // If array decoding fails, try as a single object
                do {
                    let service = try decoder.decode(ImportExportView.ServiceJSON.self, from: data)
                    return try processGenericServices([service], fileName: fileName, context: context)
                } catch {
                     print("DEBUG: Failed to decode as single ServiceJSON. Error: \(error)")
                    // Throw the final error if all attempts fail
                    throw NSError(
                        domain: "JSONImportError",
                        code: 1001,
                        userInfo: [
                            NSLocalizedDescriptionKey: "Failed to parse service data: \(error.localizedDescription)",
                            NSLocalizedFailureReasonErrorKey: "The JSON structure doesn't match any expected service format."
                        ]
                    )
                }
            }
        }
    }

    // --- NEW Function to process services.json format and link to clients ---
    private static func processClientServices(_ servicesImport: [ServicesImportJSON], fileName: String, context: ModelContext) throws -> ImportExportView.ImportResults {
        var successful = 0
        var failed = 0
        var messages: [String] = []

        for item in servicesImport {
            do {
                // 1. Find or Create ServiceEntity (based on Task Name)
                let serviceDescriptor = FetchDescriptor<ServiceEntity>(predicate: #Predicate { $0.name == item.taskName })
                let existingServices = try context.fetch(serviceDescriptor)

                let serviceEntity: ServiceEntity
                if let existing = existingServices.first {
                    serviceEntity = existing
                    // Optionally update rate/unit/code if needed from JSON
                    // serviceEntity.rate = ...
                    messages.append("Found service: \(item.taskName)")
                } else {
                    serviceEntity = ServiceEntity(id: UUID(), name: item.taskName, rate: 0.0)
                    serviceEntity.name = item.taskName
                    serviceEntity.status = "Active"
                    // Set rate, unit, description, etc.
                    if let rate = Double(item.rate.replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "")) {
                        serviceEntity.rate = rate
                    } else {
                        serviceEntity.rate = 0.0
                    }
                    serviceEntity.unit = item.unit
                    // Use a generic description or leave blank if not needed for ServiceEntity
                    serviceEntity.descriptionText = "Imported service: \(item.taskName)"
                    messages.append("Created service: \(item.taskName)")
                }

                // 2. Find ClientEntity (based on Student Name)
                let clientDescriptor = FetchDescriptor<ClientEntity>(predicate: #Predicate { $0.fullName == item.studentName })
                let existingClients = try context.fetch(clientDescriptor)

                guard let clientEntity = existingClients.first else {
                    throw NSError(domain: "ImportError", code: 1003, userInfo: [NSLocalizedDescriptionKey: "Client not found: \(item.studentName) for service \(item.taskName)"])
                }

                // 3. Create and Link ClientServiceEntity
                let serviceName = serviceEntity.name
                let clientId = clientEntity.id
                let clientServiceDescriptor = FetchDescriptor<ClientServiceEntity>(predicate: #Predicate { $0.client?.id == clientId })
                let possibleLinks = try context.fetch(clientServiceDescriptor)
                let existingLinks = possibleLinks.filter { $0.serviceName == serviceName }

                if existingLinks.isEmpty {
                    let clientService = ClientServiceEntity(id: UUID(), serviceName: serviceEntity.name, unit: serviceEntity.unit ?? "hour", rate: serviceEntity.rate)
                    clientService.clientServiceID = Int32.random(in: 1000...9999) // Or use a more robust ID system
                    clientService.serviceName = serviceEntity.name // Copy from ServiceEntity
                    clientService.ndisCode = item.code != "N/A" ? item.code : nil
                    clientService.rate = serviceEntity.rate // Copy from ServiceEntity
                    clientService.unit = serviceEntity.unit ?? "hour" // Provide default if nil
                    clientService.status = "Active"
                    clientService.startDate = Date() // Default start date to now
                    
                    // Establish relationships
                    clientService.client = clientEntity
                    
                    messages.append("Linked service '\(item.taskName)' to client '\(item.studentName)'")
                    successful += 1
                } else {
                     messages.append("Skipped duplicate link: Service '\(item.taskName)' already linked to client '\(item.studentName)'")
                     // Treat as success or failure depending on desired behaviour
                     successful += 1 // Count as success if skipping duplicates is intended
                }

            } catch {
                failed += 1
                messages.append("Failed to process service link for client '\(item.studentName)' / service '\(item.taskName)': \(error.localizedDescription)")
            }
        }

        try context.save()

        return ImportExportView.ImportResults(
            source: .services, // Or a new source type like .clientServices
            successful: successful,
            failed: failed,
            messages: messages,
            fileName: fileName
        )
    }

    // --- Renamed original function to handle generic ServiceJSON ---
    private static func processGenericServices(_ services: [ImportExportView.ServiceJSON], fileName: String, context: ModelContext) throws -> ImportExportView.ImportResults {
        var successful = 0
        var failed = 0
        var messages: [String] = []
        
        for service in services {
            do {
                // --- Keep existing logic for creating/updating ServiceEntity ---
                if service.name.isEmpty {
                     throw NSError(domain: "ValidationError", code: 1002, userInfo: [
                         NSLocalizedDescriptionKey: "Service name cannot be empty"
                     ])
                 }
                
                 let serviceDescriptor = FetchDescriptor<ServiceEntity>(predicate: #Predicate { $0.name == service.name })
                 let existingServices = try context.fetch(serviceDescriptor)
                
                 let serviceEntity: ServiceEntity
                 if let existingService = existingServices.first {
                     serviceEntity = existingService
                     messages.append("Updated service definition: \(service.name)")
                 } else {
                     serviceEntity = ServiceEntity(id: UUID(), name: service.name, rate: 0.0)
                     messages.append("Created service definition: \(service.name)")
                 }
                
                 serviceEntity.name = service.name
                
                 let descriptionText = service.description
                 // let ndisCodeFromDescription = extractNDISCode(from: descriptionText) // No longer needed here
                
                 // Set description using the correct property name if it exists
                 serviceEntity.descriptionText = descriptionText
                

                
                 if let rateStr = service.rate, let rate = Double(rateStr.replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "")) {
                     serviceEntity.rate = rate
                 } else if let rate = service.rateValue {
                     serviceEntity.rate = rate
                 } else {
                     serviceEntity.rate = 0.0
                 }
                
                 serviceEntity.unit = service.unit
                 serviceEntity.status = "Active"
                // --- End of existing logic ---
                
                successful += 1
            } catch {
                failed += 1
                messages.append("Failed to import generic service \(service.name): \(error.localizedDescription)")
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
}
