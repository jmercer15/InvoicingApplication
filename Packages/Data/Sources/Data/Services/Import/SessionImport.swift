import Core
import Foundation
import SwiftData

/// Handles import functionality for session data from JSON files
struct SessionImport {
    static func importSessions(data: Data, fileName: String, context: ModelContext) throws -> ImportResult {
        let decoder = JSONDecoder()
        
        do {
            let newFormatSessions = try decoder.decode([SessionImportJSON].self, from: data)
            let convertedSessions = newFormatSessions.map { $0.toSessionJSON() }
            return try processSessions(convertedSessions, fileName: fileName, context: context)
        } catch {
            do {
                let newFormatSession = try decoder.decode(SessionImportJSON.self, from: data)
                return try processSessions([newFormatSession.toSessionJSON()], fileName: fileName, context: context)
            } catch {
                do {
                    let sessions = try decoder.decode([SessionJSON].self, from: data)
                    return try processSessions(sessions, fileName: fileName, context: context)
                } catch {
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
    
    private static func processSessions(_ sessions: [SessionJSON], fileName: String, context: ModelContext) throws -> ImportResult {
        var successful = 0
        var failed = 0
        var messages: [String] = []
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        
        let clientFetchDescriptor = FetchDescriptor<Client>()
        let allClients = try context.fetch(clientFetchDescriptor)
        
        for session in sessions {
            do {
                guard !session.title.isEmpty else {
                    throw NSError(domain: "ValidationError", code: 1002, userInfo: [NSLocalizedDescriptionKey: "Session title cannot be empty"])
                }
                
                guard !session.clientName.isEmpty else {
                    throw NSError(domain: "ValidationError", code: 1002, userInfo: [NSLocalizedDescriptionKey: "Client name cannot be empty"])
                }
                
                guard let date = dateFormatter.date(from: session.date) else {
                    throw NSError(domain: "ValidationError", code: 1002, userInfo: [NSLocalizedDescriptionKey: "Invalid date format. Expected YYYY-MM-DD"])
                }
                
                guard let startTimeDate = timeFormatter.date(from: session.startTime) else {
                    throw NSError(domain: "ValidationError", code: 1002, userInfo: [NSLocalizedDescriptionKey: "Invalid start time format. Expected HH:MM"])
                }
                
                let startTimeComponents = Calendar.current.dateComponents([.hour, .minute], from: startTimeDate)
                let startDateTime = Calendar.current.date(bySettingHour: startTimeComponents.hour ?? 0, 
                                                      minute: startTimeComponents.minute ?? 0, 
                                                      second: 0, 
                                                      of: date) ?? date
                
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
                
                let matchingClient = allClients.first { client in
                    return client.fullName.caseInsensitiveCompare(session.clientName) == .orderedSame
                }
                
                guard let client = matchingClient else {
                    throw NSError(domain: "ValidationError", code: 1002, userInfo: [NSLocalizedDescriptionKey: "Client '\(session.clientName)' not found"])
                }
                
                let sessionFetchDescriptor = FetchDescriptor<Session>(predicate: #Predicate<Session> {
                    $0.startTime != nil
                })
                let possibleSessions = try context.fetch(sessionFetchDescriptor)
                let existingSessions = possibleSessions.filter { ($0.startTime ?? Date.distantPast) == startDateTime && $0.client?.id == client.id }
                
                if let _ = existingSessions.first {
                    messages.append("Updated session: \(session.title) for \(session.clientName) on \(session.date)")
                } else {
                    let finalEndTime = endDateTime ?? Calendar.current.date(byAdding: .hour, value: 1, to: startDateTime) ?? startDateTime
                    
                    let newSession = Session(id: UUID())
                    newSession.title = session.title
                    newSession.startTime = startDateTime
                    newSession.endTime = finalEndTime
                    newSession.client = client
                    newSession.location = session.location
                    newSession.notes = session.notes
                    let statusToken = canonicalSessionStatusToken(session.status) ?? SessionStatus.scheduled.rawValue
                    newSession.status = SessionStatus(normalized: statusToken) ?? .scheduled
                    
                    context.insert(newSession)
                    messages.append("Created session: \(session.title) for \(session.clientName) on \(session.date)")
                }
                
                successful += 1
            } catch {
                failed += 1
                messages.append("Failed to import session '\(session.title)' for \(session.clientName): \(error.localizedDescription)")
            }
        }
        
        try context.save()
        
        return ImportResult(
            source: .sessions,
            successful: successful,
            failed: failed,
            messages: messages,
            fileName: fileName
        )
    }

    private static func canonicalSessionStatusToken(_ rawStatus: String?) -> String? {
        guard let rawStatus else { return nil }
        let normalized = rawStatus
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
        guard !normalized.isEmpty else { return nil }

        switch normalized {
        case "needs_services", "needstravel", "needs_travel", "add_travel":
            return SessionStatus.needsTravel.rawValue
        case "reviewdraft", "review_draft", "review_drafts":
            return SessionStatus.reviewDraft.rawValue
        case "readytosend", "ready_to_send":
            return SessionStatus.readyToSend.rawValue
        case "noshow", "no_show":
            return SessionStatus.noShow.rawValue
        case "cancelled", "canceled":
            return SessionStatus.cancelled.rawValue
        case "pending":
            return SessionStatus.pending.rawValue
        case "received", "paid":
            return SessionStatus.received.rawValue
        default:
            return normalized
        }
    }
}
