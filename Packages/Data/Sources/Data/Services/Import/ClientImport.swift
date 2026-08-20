import Core
import PersistenceModels
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
                
                let matchingClient = try resolveExistingClient(for: client, context: context)
                
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
                let payeeModel: Payee
                if let payeeID = clientPayee.payeeID {
                    let descriptor = FetchDescriptor<Payee>(predicate: #Predicate<Payee> { $0.id == payeeID })
                    let matches = try context.fetch(descriptor)
                    guard matches.count <= 1 else {
                        throw ImportIdentityError.ambiguousPayeeIdentifier(payeeID)
                    }
                    if let existingPayee = matches.first {
                        payeeModel = existingPayee
                        messages.append("Using existing payee: \(clientPayee.payeeName)")
                    } else {
                        payeeModel = Payee(id: payeeID, fullName: clientPayee.payeeName)
                        context.insert(payeeModel)
                        payeeModel.status = "Active"
                        messages.append("Created payee: \(clientPayee.payeeName)")
                    }
                } else {
                    payeeModel = Payee(id: UUID(), fullName: clientPayee.payeeName)
                    context.insert(payeeModel)
                    payeeModel.status = "Active"
                    messages.append("Created payee: \(clientPayee.payeeName)")
                }

                let clientModel = try resolveOrCreateClient(for: clientPayee, context: context, messages: &messages)
                
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

    private static func resolveExistingClient(for payload: ClientJSON, context: ModelContext) throws -> Client? {
        if let id = payload.id {
            let descriptor = FetchDescriptor<Client>(predicate: #Predicate<Client> { $0.id == id })
            let matches = try context.fetch(descriptor)
            guard matches.count <= 1 else { throw ImportIdentityError.ambiguousClientIdentifier(id) }
            return matches.first
        }

        let ndisNumber = (payload.ndisNumber ?? payload.ndis_number ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !ndisNumber.isEmpty else { return nil }
        let descriptor = FetchDescriptor<Client>(predicate: #Predicate<Client> { $0.ndisNumber == ndisNumber })
        let matches = try context.fetch(descriptor)
        guard matches.count <= 1 else { throw ImportIdentityError.ambiguousNDISNumber(ndisNumber) }
        return matches.first
    }

    private static func resolveOrCreateClient(
        for payload: ClientPayeeImportJSON,
        context: ModelContext,
        messages: inout [String]
    ) throws -> Client {
        let stableNDISNumber = payload.ndisNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        if let clientID = payload.clientID {
            let descriptor = FetchDescriptor<Client>(predicate: #Predicate<Client> { $0.id == clientID })
            let matches = try context.fetch(descriptor)
            guard matches.count <= 1 else { throw ImportIdentityError.ambiguousClientIdentifier(clientID) }
            if let existing = matches.first {
                messages.append("Updated client: \(payload.studentName)")
                return existing
            }
            let client = Client(id: clientID, ndisNumber: stableNDISNumber == "N/A" ? "" : stableNDISNumber, fullName: payload.studentName, status: .active)
            context.insert(client)
            messages.append("Created client: \(payload.studentName)")
            return client
        }

        guard stableNDISNumber.isEmpty == false, stableNDISNumber != "N/A" else {
            throw ImportIdentityError.missingClientIdentifier(payload.studentName)
        }
        let descriptor = FetchDescriptor<Client>(predicate: #Predicate<Client> { $0.ndisNumber == stableNDISNumber })
        let matches = try context.fetch(descriptor)
        guard matches.count <= 1 else { throw ImportIdentityError.ambiguousNDISNumber(stableNDISNumber) }
        if let existing = matches.first {
            messages.append("Updated client: \(payload.studentName)")
            return existing
        }
        let client = Client(id: UUID(), ndisNumber: stableNDISNumber, fullName: payload.studentName, status: .active)
        context.insert(client)
        messages.append("Created client: \(payload.studentName)")
        return client
    }
}

private enum ImportIdentityError: LocalizedError {
    case ambiguousClientIdentifier(UUID)
    case ambiguousPayeeIdentifier(UUID)
    case ambiguousNDISNumber(String)
    case missingClientIdentifier(String)

    var errorDescription: String? {
        switch self {
        case let .ambiguousClientIdentifier(id): "Multiple clients use import identifier \(id.uuidString)."
        case let .ambiguousPayeeIdentifier(id): "Multiple payees use import identifier \(id.uuidString)."
        case let .ambiguousNDISNumber(number): "Multiple clients use NDIS number \(number)."
        case let .missingClientIdentifier(name): "Client \(name) needs a Client ID or NDIS number; name matching is not supported."
        }
    }
}
