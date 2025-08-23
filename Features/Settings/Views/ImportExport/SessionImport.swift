import Foundation
import SwiftUI
import SwiftData // Import SwiftData

// Structs for parsing the session JSON format
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
    
    // Convert to standard format for processing
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

// Standard session JSON format
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
    var userData: Any?
    
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

/// Handles import functionality for session data from JSON files
struct SessionImport {
    static func importSessions(data: Data, fileName: String, context: ModelContext) throws -> ImportExportView.ImportResults {
        // First try to decode as the new format with specific field names
        let decoder = JSONDecoder()
        
        do {
            // Try as array of SessionImportJSON
            let newFormatSessions = try decoder.decode([SessionImportJSON].self, from: data)
            let convertedSessions = newFormatSessions.map { $0.toSessionJSON() }
            return try processSessions(convertedSessions, fileName: fileName, context: context)
        } catch {
            // Try as single SessionImportJSON
            do {
                let newFormatSession = try decoder.decode(SessionImportJSON.self, from: data)
                return try processSessions([newFormatSession.toSessionJSON()], fileName: fileName, context: context)
            } catch {
                // Try standard format as array
                do {
                    let sessions = try decoder.decode([SessionJSON].self, from: data)
                    return try processSessions(sessions, fileName: fileName, context: context)
                } catch {
                    // Try as single session
                    do {
                        let session = try decoder.decode(SessionJSON.self, from: data)
                        return try processSessions([session], fileName: fileName, context: context)
                    } catch {
                        throw NSError(
                            domain: "JSONImportError",
                            code: 1001,
                            userInfo: [
                                NSLocalizedDescriptionKey: "Failed to parse session data: \(error.localizedDescription)",
                                NSLocalizedFailureReasonErrorKey: "The JSON structure doesn't match any of the expected formats for sessions."
                            ]
                        )
                    }
                }
            }
        }
    }
    
    private static func processSessions(_ sessions: [SessionJSON], fileName: String, context: ModelContext) throws -> ImportExportView.ImportResults {
        var successful = 0
        var failed = 0
        var messages: [String] = []
        
        // Create date formatters for parsing
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        
        let dateTimeFormatter = DateFormatter()
        dateTimeFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        
        // Pre-fetch all clients for matching
        let clientFetchDescriptor = FetchDescriptor<ClientEntity>()
        let allClients = try context.fetch(clientFetchDescriptor)
        
        for session in sessions {
            do {
                // Basic validation checks
                guard !session.title.isEmpty else {
                    throw NSError(domain: "ValidationError", code: 1002, userInfo: [
                        NSLocalizedDescriptionKey: "Session title cannot be empty"
                    ])
                }
                
                guard !session.clientName.isEmpty else {
                    throw NSError(domain: "ValidationError", code: 1002, userInfo: [
                        NSLocalizedDescriptionKey: "Client name cannot be empty"
                    ])
                }
                
                // Parse the date
                guard let date = dateFormatter.date(from: session.date) else {
                    throw NSError(domain: "ValidationError", code: 1002, userInfo: [
                        NSLocalizedDescriptionKey: "Invalid date format. Expected YYYY-MM-DD"
                    ])
                }
                
                // Parse the start time
                guard let startTimeDate = timeFormatter.date(from: session.startTime) else {
                    throw NSError(domain: "ValidationError", code: 1002, userInfo: [
                        NSLocalizedDescriptionKey: "Invalid start time format. Expected HH:MM"
                    ])
                }
                
                // Combine date and time components
                let startTimeComponents = Calendar.current.dateComponents([.hour, .minute], from: startTimeDate)
                let startDateTime = Calendar.current.date(bySettingHour: startTimeComponents.hour ?? 0, 
                                                      minute: startTimeComponents.minute ?? 0, 
                                                      second: 0, 
                                                      of: date) ?? date
                
                // Parse the end time if available
                var endDateTime: Date?
                if let endTime = session.endTime, !endTime.isEmpty {
                    if let endTimeDate = timeFormatter.date(from: endTime) {
                        let endTimeComponents = Calendar.current.dateComponents([.hour, .minute], from: endTimeDate)
                        endDateTime = Calendar.current.date(bySettingHour: endTimeComponents.hour ?? 0, 
                                                        minute: endTimeComponents.minute ?? 0, 
                                                        second: 0, 
                                                        of: date)
                    }
                }
                
                // Find the client
                let matchingClient = allClients.first { client in
                    return client.fullName.caseInsensitiveCompare(session.clientName) == .orderedSame
                }
                
                guard let client = matchingClient else {
                    throw NSError(domain: "ValidationError", code: 1002, userInfo: [
                        NSLocalizedDescriptionKey: "Client '\(session.clientName)' not found"
                    ])
                }
                
                // Check if the session already exists
                let sessionFetchDescriptor = FetchDescriptor<SessionEntity>(predicate: #Predicate<SessionEntity> {
                    $0.startTime != nil
                })
                let possibleSessions = try context.fetch(sessionFetchDescriptor)
                let existingSessions = possibleSessions.filter { ($0.startTime ?? Date.distantPast) == startDateTime && $0.client?.id == client.id }
                
                // Create new session or update existing
                if let existingSession = existingSessions.first {
                    _ = existingSession
                    messages.append("Updated session: \(session.title) for \(session.clientName) on \(session.date)")
                } else {
                    // Use SessionFactory for consistent import session creation
                    let sessionFactory = SessionFactory(context: context)
                    
                    // Use endDateTime if available, otherwise default to 1 hour after start time
                    let finalEndTime = endDateTime ?? Calendar.current.date(byAdding: .hour, value: 1, to: startDateTime) ?? startDateTime
                    
                    _ = sessionFactory.createSessionForImport(
                        title: session.title,
                        startTime: startDateTime,
                        endTime: finalEndTime,
                        client: client,
                        location: session.location,
                        notes: session.notes,
                        status: session.status ?? "Scheduled"
                    )
                    messages.append("Created session: \(session.title) for \(session.clientName) on \(session.date)")
                }
                
                // Save changes
                successful += 1
            } catch {
                failed += 1
                messages.append("Failed to import session '\(session.title)' for \(session.clientName): \(error.localizedDescription)")
            }
        }
        
        try context.save()
        
        return ImportExportView.ImportResults(
            source: .sessions,
            successful: successful,
            failed: failed,
            messages: messages,
            fileName: fileName
        )
    }
}