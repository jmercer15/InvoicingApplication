import Foundation
import Core

/// Standard session JSON format
struct SessionJSON: Codable {
    let title: String
    let date: String
    let startTime: String
    let endTime: String?
    let clientName: String
    let location: String?
    let notes: String?
    let status: String?
    
    // Additional processing data can be stored here
    var userData: Data?
    
    enum CodingKeys: String, CodingKey {
        case title, date, startTime, endTime, clientName, location, notes, status
    }
    
    init(title: String, date: String, startTime: String, endTime: String?, clientName: String, location: String?, notes: String?, status: String?) {
        self.title = title
        self.date = date
        self.startTime = startTime
        self.endTime = endTime
        self.clientName = clientName
        self.location = location
        self.notes = notes
        self.status = status
        self.userData = nil
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        title = try container.decode(String.self, forKey: .title)
        date = try container.decode(String.self, forKey: .date)
        startTime = try container.decode(String.self, forKey: .startTime)
        endTime = try container.decodeIfPresent(String.self, forKey: .endTime)
        clientName = try container.decode(String.self, forKey: .clientName)
        location = try container.decodeIfPresent(String.self, forKey: .location)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        userData = nil
    }
}

/// JSON model for the session JSON import format
struct SessionImportJSON: Codable {
    let title: String
    let date: String
    let startTime: String
    let endTime: String?
    let clientName: String
    let location: String?
    let notes: String?
    let status: String?
    
    enum CodingKeys: String, CodingKey {
        case title = "Title"
        case date = "Date"
        case startTime = "Start Time"
        case endTime = "End Time"
        case clientName = "Client Name"
        case location = "Location"
        case notes = "Notes"
        case status = "Status"
    }
    
    /// Converts this model to the legacy SessionJSON format for processing
    func toSessionJSON() -> SessionJSON {
        return SessionJSON(
            title: title,
            date: date,
            startTime: startTime,
            endTime: endTime,
            clientName: clientName,
            location: location,
            notes: notes,
            status: status
        )
    }
}
