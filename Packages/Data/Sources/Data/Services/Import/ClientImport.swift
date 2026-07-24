import Core
import Foundation
import SwiftData

/// Handles import functionality for client data from JSON files
struct ClientImport {
    static func importClients(data: Data, fileName: String, context: ModelContext) throws -> ImportResult {
        let decoder = JSONDecoder()
        
        // First try to decode as the new format
        do {
            let newFormatClients = try decoder.decode([ClientImportJSON].self, from: data)
            let clientJSONs = newFormatClients.map { $0.toClientJSON() }
            return try processClients(clientJSONs, fileName: fileName, context: context)
        } catch {
            // Try the clients.json format (client-payee relationship)
            do {
                let clientPayeeData = try decoder.decode([ClientPayeeImportJSON].self, from: data)
                return try processClientPayeeData(clientPayeeData, fileName: fileName, context: context)
            } catch {
                // If that fails, try the standard formats
                do {
                    let clients = try decoder.decode([ClientJSON].self, from: data)
                    return try processClients(clients, fileName: fileName, context: context)
                } catch {
                    // Try as single objects for each format
                    do {
                        let newFormatClient = try decoder.decode(ClientImportJSON.self, from: data)
                        return try processClients([newFormatClient.toClientJSON()], fileName: fileName, context: context)
                    } catch {
                        do {
                            let clientPayee = try decoder.decode(ClientPayeeImportJSON.self, from: data)
                            return try processClientPayeeData([clientPayee], fileName: fileName, context: context)
                        } catch {
                            do {
                                let client = try decoder.decode(ClientJSON.self, from: data)
                                return try processClients([client], fileName: fileName, context: context)
                            } catch {
                                throw NSError(
                                    domain: "JSONImportError",
                                    code: 1001,
                                    userInfo: [
                                        NSLocalizedDescriptionKey: "Failed to parse client data: \(error.localizedDescription)",
                                        NSLocalizedFailureReasonErrorKey: "The JSON structure doesn't match any of the expected formats for clients."
                                    ]
                                )
                            }
                        }
                    }
                }
            }
        }
    }
    
    // Process regular client data
    private static func processClients(_ clients: [ClientJSON], fileName: String, context: ModelContext) throws -> ImportResult {
        var successful = 0
        var failed = 0
        var messages: [String] = []
        
        for client in clients {
            do {
                if client.fullName.isEmpty {
                    throw NSError(domain: "ValidationError", code: 1002, userInfo: [
                        NSLocalizedDescriptionKey: "Client name cannot be empty"
                    ])
                }
                
                let addressForComparison = formatAddressForComparison(client: client)
                let fullName = client.fullName
                let descriptor = FetchDescriptor<Client>(predicate: #Predicate<Client> { $0.fullName == fullName })
                let existingClients = try context.fetch(descriptor)
                
                let matchingClient = existingClients.first { existingClient in
                    guard let address = existingClient.address else { return false }
                    
                    let existingAddress = [
                        address.streetNumber,
                        address.streetName,
                        address.suburb,
                        address.state,
                        address.postcode
                    ].compactMap { $0 }.joined(separator: " ")
                    .lowercased()
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    return existingAddress == addressForComparison || existingAddress.isEmpty
                }
                
                let clientModel: Client
                if let existingClient = matchingClient {
                    clientModel = existingClient
                    messages.append("Updated client: \(client.fullName)")
                } else {
                    clientModel = Client(id: UUID(), ndisNumber: "", fullName: "", status: .active)
                    context.insert(clientModel)
                    messages.append("Created client: \(client.fullName)")
                }
                
                clientModel.fullName = client.fullName
                clientModel.email = client.email
                clientModel.phone = client.phone
                
                let addressModel: Address
                if let existingAddress = clientModel.address {
                    addressModel = existingAddress
                } else {
                    addressModel = Address()
                    clientModel.address = addressModel
                    context.insert(addressModel)
                }
                
                if let address = client.address {
                    let components = parseAddress(address)
                    setAddressComponents(address: addressModel, components: components)
                    if let coordinates = parseCoordinates(from: address) {
                        addressModel.latitude = coordinates.latitude
                        addressModel.longitude = coordinates.longitude
                    }
                } else {
                    var streetNumber: String?
                    var streetName: String?
                    
                    if let street = client.addressStreet ?? client.addressLine1 {
                        let streetComponents = parseStreetAddress(street)
                        streetNumber = streetComponents.number
                        streetName = streetComponents.name
                    }
                    
                    addressModel.streetNumber = streetNumber ?? ""
                    addressModel.streetName = streetName ?? ""
                    addressModel.unitNumber = client.addressLine2 ?? ""
                    addressModel.suburb = (client.addressCity ?? client.city) ?? ""
                    addressModel.state = (client.addressState ?? client.state) ?? ""
                    addressModel.postcode = (client.addressPostalCode ?? client.postalCode ?? client.zip) ?? ""
                    
                    if let coordinateHint = parseCoordinates(from: [
                        client.addressStreet,
                        client.addressCity ?? client.city,
                        client.addressState ?? client.state,
                        client.addressPostalCode ?? client.postalCode ?? client.zip
                    ].compactMap { $0 }.joined(separator: ", ")) {
                        addressModel.latitude = coordinateHint.latitude
                        addressModel.longitude = coordinateHint.longitude
                    }
                }
                
                clientModel.ndisNumber = client.ndisNumber ?? client.ndis_number ?? ""
                clientModel.status = .active
                
                successful += 1
            } catch {
                failed += 1
                messages.append("Failed to import client \(client.fullName): \(error.localizedDescription)")
            }
        }
        
        return ImportResult(
            source: .clients,
            successful: successful,
            failed: failed,
            messages: messages,
            fileName: fileName
        )
    }
    
    // Process the client-payee relationship data
    private static func processClientPayeeData(_ clientPayeeData: [ClientPayeeImportJSON], fileName: String, context: ModelContext) throws -> ImportResult {
        var successful = 0
        var failed = 0
        var messages: [String] = []
        
        for clientPayee in clientPayeeData {
            do {
                let payeeName = clientPayee.payeeName
                let payeeDescriptor = FetchDescriptor<Payee>(predicate: #Predicate<Payee> { $0.fullName == payeeName })
                let existingPayees = try context.fetch(payeeDescriptor)
                
                let payeeModel: Payee
                if let existingPayee = existingPayees.first {
                    payeeModel = existingPayee
                    messages.append("Using existing payee: \(clientPayee.payeeName)")
                } else {
                    payeeModel = Payee(id: UUID(), fullName: "")
                    context.insert(payeeModel)
                    payeeModel.fullName = clientPayee.payeeName
                    payeeModel.status = "Active"
                    messages.append("Created payee: \(clientPayee.payeeName)")
                }
                
                let studentName = clientPayee.studentName
                let clientDescriptor = FetchDescriptor<Client>(predicate: #Predicate<Client> { $0.fullName == studentName })
                let existingClients = try context.fetch(clientDescriptor)
                
                let clientModel: Client
                if let existingClient = existingClients.first {
                    clientModel = existingClient
                    messages.append("Updated client: \(clientPayee.studentName)")
                } else {
                    clientModel = Client(id: UUID(), ndisNumber: "", fullName: "", status: .active)
                    context.insert(clientModel)
                    clientModel.fullName = clientPayee.studentName
                    clientModel.status = .active
                    messages.append("Created client: \(clientPayee.studentName)")
                }
                
                if clientPayee.ndisNumber != "N/A" {
                    clientModel.ndisNumber = clientPayee.ndisNumber
                }
                
                clientModel.payee = payeeModel
                clientModel.hasNdisPlan = true
                clientModel.planManagementType = "Plan-Managed"
                
                successful += 1
            } catch {
                failed += 1
                messages.append("Failed to import client-payee relationship for \(clientPayee.studentName): \(error.localizedDescription)")
            }
        }
        
        return ImportResult(
            source: .clients,
            successful: successful,
            failed: failed,
            messages: messages,
            fileName: fileName
        )
    }
}
