import Foundation

/// JSON model for the student-payee relationship format
struct ClientPayeeImportJSON: Codable {
    let clientID: UUID?
    let payeeID: UUID?
    let payeeName: String
    let studentName: String
    let ndisNumber: String
    
    enum CodingKeys: String, CodingKey {
        case clientID = "Client ID"
        case payeeID = "Payee ID"
        case payeeName = "Payee Name"
        case studentName = "Student Name"
        case ndisNumber = "NDIS No."
    }
}

/// JSON model for the modern client import format
struct ClientImportJSON: Codable {
    let id: UUID?
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
        case id = "ID"
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
    
    /// Converts this model to the legacy ClientJSON format for processing
    func toClientJSON() -> ClientJSON {
        return ClientJSON(
            fullName: fullName,
            id: id,
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
