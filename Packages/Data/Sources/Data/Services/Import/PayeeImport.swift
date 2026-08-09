import Core
import PersistenceModels
import Foundation
import SwiftData

// New struct to handle the provided JSON format
struct PayeeImportJSON: Codable {
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
    let relationToClient: String?
    
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
        case relationToClient = "Relation to Client"
    }
    
    // Convert to standard PayeeJSON format
    func toPayeeJSON() -> PayeeJSON {
        // Build address string from components
        var addressComponents: [String] = []
        
        if let streetNumber = streetNumber, !streetNumber.isEmpty {
            if let streetName = streetName, !streetName.isEmpty {
                addressComponents.append("\(streetNumber) \(streetName)")
            } else {
                addressComponents.append(streetNumber)
            }
        } else if let streetName = streetName, !streetName.isEmpty {
            addressComponents.append(streetName)
        }
        
        if let suburb = suburb, !suburb.isEmpty {
            addressComponents.append(suburb)
        }
        
        if let state = state, !state.isEmpty {
            addressComponents.append(state)
        }
        
        if let zip = zip, !zip.isEmpty {
            addressComponents.append(zip)
        }
        
        if let country = country, !country.isEmpty, country.lowercased() != "australia" {
            addressComponents.append(country)
        }
        
        let addressString = addressComponents.isEmpty ? nil : addressComponents.joined(separator: ", ")
        
        return PayeeJSON(
            payeeName: fullName,
            email: email,
            phone: mobile == "N/A" ? nil : mobile,
            address: addressString,
            bankAccount: nil,
            bankBSB: nil,
            status: "Active", // Default status
            relationToClient: relationToClient // Pass the value
        )
    }
}

struct PayeeImport {
    static func importPayees(data: Data, fileName: String, context: ModelContext) throws -> ImportResult {
        // Try to decode the JSON data
        let decoder = JSONDecoder()
        
        do {
            // First try to decode as standard PayeeJSON format
            let payees = try decoder.decode([PayeeJSON].self, from: data)
            return try processPayees(payees, fileName: fileName, context: context)
        } catch {
            // If that fails, try the new format
            do {
                let importPayees = try decoder.decode([PayeeImportJSON].self, from: data)
                let payees = importPayees.map { $0.toPayeeJSON() }
                return try processPayees(payees, fileName: fileName, context: context)
            } catch {
                // If that fails too, try as a single object in standard format
                do {
                    let payee = try decoder.decode(PayeeJSON.self, from: data)
                    return try processPayees([payee], fileName: fileName, context: context)
                } catch {
                    // Finally try as a single object in the new format
                    do {
                        let importPayee = try decoder.decode(PayeeImportJSON.self, from: data)
                        return try processPayees([importPayee.toPayeeJSON()], fileName: fileName, context: context)
                    } catch {
                        throw NSError(
                            domain: "JSONImportError",
                            code: 1001,
                            userInfo: [
                                NSLocalizedDescriptionKey: "Failed to parse payee data: \(error.localizedDescription)",
                                NSLocalizedFailureReasonErrorKey: "The JSON structure doesn't match any of the expected formats for payees."
                            ]
                        )
                    }
                }
            }
        }
    }
    
    private static func processPayees(_ payees: [PayeeJSON], fileName: String, context: ModelContext) throws -> ImportResult {
        var successful = 0
        var failed = 0
        var messages: [String] = []
        
        for payee in payees {
            do {
                // Validate required data
                if payee.payeeName.isEmpty {
                    throw NSError(domain: "ValidationError", code: 1002, userInfo: [
                        NSLocalizedDescriptionKey: "Payee name cannot be empty"
                    ])
                }
                // Find if the payee exists based on name
                let payeeName = payee.payeeName
                let descriptor = FetchDescriptor<Payee>(predicate: #Predicate<Payee> { $0.fullName == payeeName })
                let existingPayees = try context.fetch(descriptor)
                // Either update existing or create new
                let payeeModel: Payee
                if let existingPayee = existingPayees.first {
                    payeeModel = existingPayee
                    messages.append("Updated payee: \(payee.payeeName)")
                } else {
                    payeeModel = Payee(id: UUID(), fullName: payee.payeeName)
                    context.insert(payeeModel)
                    messages.append("Created payee: \(payee.payeeName)")
                }
                // Set properties
                payeeModel.fullName = payee.payeeName
                payeeModel.email = payee.email
                payeeModel.phone = payee.phone
                // Handle address - always create an Address if we have an address string
                if let addressString = payee.address, !addressString.isEmpty {
                    let addressModel = createOrUpdateAddress(for: payeeModel, addressString: addressString, context: context)
                    payeeModel.address = addressModel
                }
                // Bank details cannot be stored - Payee.notes has been removed per architectural guidelines
                // Note: Bank details from import are discarded as payees should not store notes
                if payee.bankAccount != nil || payee.bankBSB != nil {
                    print("⚠️ [PayeeImport] Bank details for \(payee.payeeName) cannot be stored - Payee.notes removed per architectural guidelines")
                }
                // Set default status
                payeeModel.status = payee.status ?? "Active"
                payeeModel.relationToClient = payee.relationToClient
                successful += 1
            } catch {
                failed += 1
                messages.append("Failed to import payee \(payee.payeeName): \(error.localizedDescription)")
            }
        }
        try context.save()
        return ImportResult(
            source: .payees,
            successful: successful,
            failed: failed,
            messages: messages,
            fileName: fileName
        )
    }
    // Helper function to create or update an address entity
    private static func createOrUpdateAddress(for payee: Payee, addressString: String, context: ModelContext) -> Address {
        // Get or create address entity
        let addressModel: Address
        if let existingAddress = payee.address {
            addressModel = existingAddress
        } else {
            addressModel = Address()
            context.insert(addressModel)
        }
        // Try to parse address components
        let components = addressString.components(separatedBy: ", ")
        if components.count >= 1 {
            addressModel.fullAddressText = addressString
        }
        return addressModel
    }
}
