import Foundation
import SwiftUI
import SwiftData // Import SwiftData

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
    func toPayeeJSON() -> ImportExportView.PayeeJSON {
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
        
        return ImportExportView.PayeeJSON(
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
    static func importPayees(data: Data, fileName: String, context: ModelContext) throws -> ImportExportView.ImportResults {
        // Try to decode the JSON data
        let decoder = JSONDecoder()
        
        do {
            // First try to decode as standard PayeeJSON format
            let payees = try decoder.decode([ImportExportView.PayeeJSON].self, from: data)
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
                    let payee = try decoder.decode(ImportExportView.PayeeJSON.self, from: data)
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
    
    private static func processPayees(_ payees: [ImportExportView.PayeeJSON], fileName: String, context: ModelContext) throws -> ImportExportView.ImportResults {
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
                let descriptor = FetchDescriptor<PayeeEntity>(predicate: #Predicate { $0.fullName == payee.payeeName })
                let existingPayees = try context.fetch(descriptor)
                // Either update existing or create new
                let payeeEntity: PayeeEntity
                if let existingPayee = existingPayees.first {
                    payeeEntity = existingPayee
                    messages.append("Updated payee: \(payee.payeeName)")
                } else {
                    payeeEntity = PayeeEntity(id: UUID(), fullName: payee.payeeName, colorHex: "#2196F3")
                    context.insert(payeeEntity)
                    messages.append("Created payee: \(payee.payeeName)")
                }
                // Set properties
                payeeEntity.fullName = payee.payeeName
                payeeEntity.email = payee.email
                payeeEntity.phone = payee.phone
                // Handle address - always create an AddressEntity if we have an address string
                if let addressString = payee.address, !addressString.isEmpty {
                    let addressEntity = createOrUpdateAddress(for: payeeEntity, addressString: addressString, context: context)
                    payeeEntity.address = addressEntity
                    Task {
                        await GeocodingService.shared.geocodeAndSave(addressEntity: addressEntity, in: context)
                    }
                }
                // Bank details are stored in notes since PayeeEntity doesn't have bankDetails property
                if payee.bankAccount != nil || payee.bankBSB != nil {
                    var bankNotes = "Bank Details: "
                    if let bsb = payee.bankBSB {
                        bankNotes += "BSB: \(bsb) "
                    }
                    if let account = payee.bankAccount {
                        bankNotes += "Account: \(account)"
                    }
                    // Append to existing notes if any
                    if let existingNotes = payeeEntity.notes, !existingNotes.isEmpty {
                        payeeEntity.notes = "\(existingNotes)\n\(bankNotes)"
                    } else {
                        payeeEntity.notes = bankNotes
                    }
                }
                // Set default status
                payeeEntity.status = payee.status ?? "Active"
                payeeEntity.relationToClient = payee.relationToClient
                successful += 1
            } catch {
                failed += 1
                messages.append("Failed to import payee \(payee.payeeName): \(error.localizedDescription)")
            }
        }
        try context.save()
        return ImportExportView.ImportResults(
            source: .payees,
            successful: successful,
            failed: failed,
            messages: messages,
            fileName: fileName
        )
    }
    // Helper function to create or update an address entity
    private static func createOrUpdateAddress(for payeeEntity: PayeeEntity, addressString: String, context: ModelContext) -> AddressEntity {
        // Get or create address entity
        let addressEntity: AddressEntity
        if let existingAddress = payeeEntity.address {
            addressEntity = existingAddress
        } else {
            addressEntity = AddressEntity()
            context.insert(addressEntity)
        }
        // Try to parse address components
        let components = addressString.components(separatedBy: ", ")
        if components.count >= 1 {
            addressEntity.fullAddressText = addressString
        }
        return addressEntity
    }
} 