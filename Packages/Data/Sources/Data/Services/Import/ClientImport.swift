import Foundation
import SwiftData
import Data
import Core

// New struct to handle the provided JSON format
struct ClientImportJSON: Codable {
    let fullName: String
    let email: String?
    let mobile: String?
    let streetNumber: String?
    let streetName: String?
    let suburb: String?
    let city: String?
    let zip: String?
    let state: String?
    let country: String?
    let ndisNumber: String?
    
    enum CodingKeys: String, CodingKey {
        case fullName = "Full Name"
        case email = "Email"
        case mobile = "Mobile"
        case streetNumber = "Street Number"
        case streetName = "Street Name"
        case suburb = "Suburb"
        case city = "City"
        case zip = "Zip"
        case state = "State"
        case country = "Country"
        case ndisNumber = "NDIS Number"
    }
    
    // Convert to standard ClientJSON format
    func toClientJSON() -> ClientJSON {
        return ClientJSON(
            fullName: fullName,
            email: email,
            phone: mobile,
            address: nil,
            addressLine1: streetNumber != nil && streetName != nil ? "\(streetNumber!) \(streetName!)" : streetName ?? nil,
            addressLine2: nil,
            addressCity: city ?? suburb,
            addressState: state,
            addressPostalCode: zip, 
            city: city ?? suburb,
            state: state, 
            postalCode: zip, 
            zip: zip, 
            addressStreet: streetNumber != nil && streetName != nil ? "\(streetNumber!) \(streetName!)" : streetName ?? nil,
            ndisNumber: ndisNumber,
            ndis_number: nil
        )
    }
}

// Add struct for clients.json format
struct ClientPayeeImportJSON: Codable {
    let payeeName: String
    let studentName: String
    let ndisNumber: String
    
    enum CodingKeys: String, CodingKey {
        case payeeName = "Payee Name"
        case studentName = "Student Name"
        case ndisNumber = "NDIS No."
    }
    
    // Convert to standard ClientJSON format
    func toClientJSON() -> ClientJSON {
        return ClientJSON(
            fullName: studentName,
            email: nil,
            phone: nil,
            address: nil,
            addressLine1: nil,
            addressLine2: nil,
            addressState: nil,
            addressPostalCode: nil, city: nil,
            state: nil, postalCode: nil, zip: nil, addressStreet: nil,
            ndisNumber: ndisNumber != "N/A" ? ndisNumber : nil,
            ndis_number: nil
        )
    }
}

/// Handles import functionality for client data from JSON files
struct ClientImport {
    static func importClients(data: Data, fileName: String, context: ModelContext) throws -> ImportResult {
        // Try to decode the JSON data
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
                // Validate required data
                if client.fullName.isEmpty {
                    throw NSError(domain: "ValidationError", code: 1002, userInfo: [
                        NSLocalizedDescriptionKey: "Client name cannot be empty"
                    ])
                }
                
                // Prepare address for comparison
                let addressForComparison = formatAddressForComparison(client: client)
                
                // Find if the client exists based on name
                let descriptor = FetchDescriptor<ClientEntity>(predicate: #Predicate { $0.fullName == client.fullName })
                let existingClients = try context.fetch(descriptor)
                
                // Check if we have a matching client with same address
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
                
                // Either update existing or create new
                let clientEntity: ClientEntity
                if let existingClient = matchingClient {
                    clientEntity = existingClient
                    messages.append("Updated client: \(client.fullName)")
                } else {
                    clientEntity = ClientEntity(id: UUID(), ndisNumber: "", fullName: "", status: .active)
                    context.insert(clientEntity) // Explicitly insert new entity
                    messages.append("Created client: \(client.fullName)")
                }
                
                // Set properties
                clientEntity.fullName = client.fullName
                clientEntity.email = client.email
                clientEntity.phone = client.phone
                
                // Create or update address entity
                let addressEntity: AddressEntity
                if let existingAddress = clientEntity.address {
                    addressEntity = existingAddress
                } else {
                    addressEntity = AddressEntity()
                    clientEntity.address = addressEntity
                    context.insert(addressEntity) // Explicitly insert new address
                }
                
                // Set address components based on available data
                if let address = client.address {
                    // Parse the combined address
                    let components = parseAddress(address)
                    setAddressComponents(address: addressEntity, components: components)
                    if let coordinates = parseCoordinates(from: address) {
                        addressEntity.latitude = coordinates.latitude
                        addressEntity.longitude = coordinates.longitude
                    }
                } else {
                    // Use provided address components
                    var streetNumber: String?
                    var streetName: String?
                    
                    // Parse street address if available
                    if let street = client.addressStreet ?? client.addressLine1 {
                        let streetComponents = parseStreetAddress(street)
                        streetNumber = streetComponents.number
                        streetName = streetComponents.name
                    }
                    
                    // Set address fields
                    addressEntity.streetNumber = streetNumber ?? ""
                    addressEntity.streetName = streetName ?? ""
                    addressEntity.unitNumber = client.addressLine2 ?? ""
                    addressEntity.suburb = (client.addressCity ?? client.city) ?? ""
                    addressEntity.state = (client.addressState ?? client.state) ?? ""
                    addressEntity.postcode = (client.addressPostalCode ?? client.postalCode ?? client.zip) ?? ""
                    // addressEntity.country = "Australia" // Property not accessible
                    if let coordinateHint = parseCoordinates(from: [
                        client.addressStreet,
                        client.addressCity ?? client.city,
                        client.addressState ?? client.state,
                        client.addressPostalCode ?? client.postalCode ?? client.zip
                    ].compactMap { $0 }.joined(separator: ", ")) {
                        addressEntity.latitude = coordinateHint.latitude
                        addressEntity.longitude = coordinateHint.longitude
                    }
                }
                
                // Set NDIS number
                clientEntity.ndisNumber = client.ndisNumber ?? client.ndis_number ?? ""
                
                // Set default status
                clientEntity.status = .active
                
                successful += 1
            } catch {
                failed += 1
                messages.append("Failed to import client \(client.fullName): \(error.localizedDescription)")
            }
        }
        
        // No explicit save needed here, changes are tracked by ModelContext
        
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
                // Find or create the payee entity
                let payeeDescriptor = FetchDescriptor<PayeeEntity>(predicate: #Predicate { $0.fullName == clientPayee.payeeName })
                let existingPayees = try context.fetch(payeeDescriptor)
                
                let payeeEntity: PayeeEntity
                if let existingPayee = existingPayees.first {
                    payeeEntity = existingPayee
                    messages.append("Using existing payee: \(clientPayee.payeeName)")
                } else {
                    payeeEntity = PayeeEntity(id: UUID(), fullName: "")
                    context.insert(payeeEntity) // Explicitly insert new entity
                    payeeEntity.fullName = clientPayee.payeeName
                    payeeEntity.status = "Active"
                    messages.append("Created payee: \(clientPayee.payeeName)")
                }
                
                // Find or create the client entity
                let clientDescriptor = FetchDescriptor<ClientEntity>(predicate: #Predicate { $0.fullName == clientPayee.studentName })
                let existingClients = try context.fetch(clientDescriptor)
                
                let clientEntity: ClientEntity
                if let existingClient = existingClients.first {
                    clientEntity = existingClient
                    messages.append("Updated client: \(clientPayee.studentName)")
                } else {
                    clientEntity = ClientEntity(id: UUID(), ndisNumber: "", fullName: "", status: .active)
                    context.insert(clientEntity) // Explicitly insert new entity
                    clientEntity.fullName = clientPayee.studentName
                    clientEntity.status = .active
                    messages.append("Created client: \(clientPayee.studentName)")
                }
                
                // Set NDIS number if not "N/A"
                if clientPayee.ndisNumber != "N/A" {
                    clientEntity.ndisNumber = clientPayee.ndisNumber
                }
                
                // Set up the relationship between client and payee
                clientEntity.payee = payeeEntity
                
                // Set plan management type based on having a payee
                // Assuming if a payee is assigned, the client has an NDIS plan and it's Plan-Managed.
                // This might need adjustment if the CSV provides more granular NDIS plan details.
                clientEntity.hasNdisPlan = true 
                clientEntity.planManagementType = "Plan-Managed"
                
                successful += 1
            } catch {
                failed += 1
                messages.append("Failed to import client-payee relationship for \(clientPayee.studentName): \(error.localizedDescription)")
            }
        }
        
        // No explicit save needed here, changes are tracked by ModelContext
        
        return ImportResult(
            source: .clients,
            successful: successful,
            failed: failed,
            messages: messages,
            fileName: fileName
        )
    }
    
    private static func formatAddressForComparison(client: ClientJSON) -> String {
        if let address = client.address {
            return address.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            // Create composite address from components
            return [
                client.addressLine1,
                client.addressLine2,
                client.addressCity ?? client.city,
                client.addressState ?? client.state,
                client.addressPostalCode ?? client.postalCode ?? client.zip
            ].compactMap { $0 }
            .joined(separator: " ")
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
    
    private static func parseAddress(_ address: String) -> (line1: String?, line2: String?, city: String?, state: String?, postalCode: String?) {
        let lines = address.split(separator: "\n").map { String($0) }
        let line1 = lines.first
        let line2 = lines.count > 1 ? lines[1] : nil
        
        // Try to extract city, state, zip from the last line
        var city: String?
        var state: String?
        var postalCode: String?
        
        if let lastLine = lines.last {
            // Common patterns: "City, State ZIP" or "City State ZIP"
            let components = lastLine.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            
            if components.count > 1 {
                city = components[0]
                let stateZip = components[1].split(separator: " ").map { String($0) }
                state = stateZip.first
                postalCode = stateZip.last
            } else {
                // Try space-separated format
                let parts = lastLine.split(separator: " ").map { String($0) }
                if parts.count >= 3 {
                    if let lastPart = parts.last, lastPart.rangeOfCharacter(from: CharacterSet.decimalDigits) != nil {
                        postalCode = lastPart
                        state = parts[parts.count - 2]
                        city = parts.dropLast(2).joined(separator: " ")
                    }
                }
            }
        }
        
        return (line1, line2, city, state, postalCode)
    }
    
    private static func parseStreetAddress(_ street: String) -> (number: String?, name: String?) {
        // Extract street number and name from a street address
        // Common formats: "123 Main St", "Unit 5/123 Main St", etc.
        
        let parts = street.split(separator: " ").map { String($0) }
        
        if parts.isEmpty {
            return (nil, nil)
        }
        
        if let firstPart = parts.first, firstPart.rangeOfCharacter(from: CharacterSet.decimalDigits) != nil {
            // If first part contains numbers, assume it's the street number
            return (firstPart, parts.dropFirst().joined(separator: " "))
        } else {
            // If not, check for number/street patterns like "Unit 5/123"
            for (index, part) in parts.enumerated() {
                if part.contains("/") && part.rangeOfCharacter(from: CharacterSet.decimalDigits) != nil {
                    let beforeParts = parts[0..<index].joined(separator: " ")
                    let number = part
                    let afterParts = index + 1 < parts.count ? parts[(index + 1)...].joined(separator: " ") : ""
                    return (number, [beforeParts, afterParts].filter { !$0.isEmpty }.joined(separator: " "))
                }
            }
        }
        
        // If no pattern found, return the whole string as the street name
        return (nil, street)
    }
    
    private static func setAddressComponents(address: AddressEntity, components: (line1: String?, line2: String?, city: String?, state: String?, postalCode: String?)) {
        // If line1 exists, try to parse it into street number and name
        if let line1 = components.line1 {
            let streetComponents = parseStreetAddress(line1)
            address.streetNumber = streetComponents.number ?? ""
            address.streetName = streetComponents.name ?? ""
        }

        address.unitNumber = components.line2 ?? ""
        address.suburb = components.city ?? ""
        address.state = components.state ?? ""
        address.postcode = components.postalCode ?? ""
        // address.country = "Australia" // Property not accessible
    }

    private static func parseCoordinates(from text: String) -> (latitude: Double, longitude: Double)? {
        let pattern = #"(-?\d{1,2}\.\d+)\s*,\s*(-?\d{1,3}\.\d+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)

        guard let match = regex.firstMatch(in: text, options: [], range: range),
              match.numberOfRanges == 3 else {
            return nil
        }

        let latitudeString = nsText.substring(with: match.range(at: 1))
        let longitudeString = nsText.substring(with: match.range(at: 2))
        guard let latitude = Double(latitudeString),
              let longitude = Double(longitudeString),
              abs(latitude) <= 90,
              abs(longitude) <= 180 else {
            return nil
        }

        return (latitude, longitude)
    }
}
