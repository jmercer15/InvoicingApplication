import Core
import PersistenceModels
import Foundation
import SwiftData

/// Handles import functionality for session data from JSON files
struct SessionImport {
    static func importSessions(data: Data, fileName: String, context: ModelContext) throws -> ImportResult {
        let decoder = JSONDecoder()
        if let sessions = try? decoder.decode([SessionImportJSON].self, from: data) {
            return try processSessions(sessions.map { $0.toSessionJSON() }, fileName: fileName, context: context)
        }
        if let session = try? decoder.decode(SessionImportJSON.self, from: data) {
            return try processSessions([session.toSessionJSON()], fileName: fileName, context: context)
        }
        if let sessions = try? decoder.decode([SessionJSON].self, from: data) {
            return try processSessions(sessions, fileName: fileName, context: context)
        }
        if let session = try? decoder.decode(SessionJSON.self, from: data) {
            return try processSessions([session], fileName: fileName, context: context)
        }

        throw NSError(
            domain: "JSONImportError",
            code: 1001,
            userInfo: [
                NSLocalizedDescriptionKey: "Failed to parse session data.",
                NSLocalizedFailureReasonErrorKey: "The JSON structure doesn't match any of the expected formats for sessions."
            ]
        )
    }
    
    private static func processSessions(_ sessions: [SessionJSON], fileName: String, context: ModelContext) throws -> ImportResult {
        var successful = 0
        var failed = 0
        var messages: [String] = []
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        
        let clientFetchDescriptor = FetchDescriptor<Client>()
        let allClients = try context.fetch(clientFetchDescriptor)
        let clientsByName = Dictionary(
            allClients.map { ($0.fullName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let candidateStartTimes = sessions.compactMap { session -> Date? in
            guard let date = ImportCalendarDate.date(from: session.date),
                  let time = timeFormatter.date(from: session.startTime)
            else { return nil }
            let components = Calendar.current.dateComponents([.hour, .minute], from: time)
            return Calendar.current.date(
                bySettingHour: components.hour ?? 0,
                minute: components.minute ?? 0,
                second: 0,
                of: date
            )
        }
        let existingSessions = try fetchExistingSessions(
            between: candidateStartTimes.min(),
            and: candidateStartTimes.max(),
            context: context
        )
        var sessionsByClientAndStart = Dictionary(
            existingSessions.compactMap { session -> (SessionImportKey, Session)? in
                guard let clientID = session.client?.id, let startTime = session.startTime else { return nil }
                return (SessionImportKey(clientID: clientID, startTime: startTime), session)
            },
            uniquingKeysWith: { first, _ in first }
        )
        
        for session in sessions {
            do {
                guard !session.title.isEmpty else {
                    throw NSError(domain: "ValidationError", code: 1002, userInfo: [NSLocalizedDescriptionKey: "Session title cannot be empty"])
                }
                
                guard !session.clientName.isEmpty else {
                    throw NSError(domain: "ValidationError", code: 1002, userInfo: [NSLocalizedDescriptionKey: "Client name cannot be empty"])
                }
                
                guard let date = ImportCalendarDate.date(from: session.date) else {
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
                
                let matchingClient = clientsByName[session.clientName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()]
                
                guard let client = matchingClient else {
                    throw NSError(domain: "ValidationError", code: 1002, userInfo: [NSLocalizedDescriptionKey: "Client '\(session.clientName)' not found"])
                }
                
                let key = SessionImportKey(clientID: client.id, startTime: startDateTime)
                let finalEndTime = endDateTime ?? Calendar.current.date(byAdding: .hour, value: 1, to: startDateTime) ?? startDateTime
                if let existingSession = sessionsByClientAndStart[key] {
                    apply(session, to: existingSession, client: client, startTime: startDateTime, endTime: finalEndTime)
                    messages.append("Updated session: \(session.title) for \(session.clientName) on \(session.date)")
                } else {
                    let newSession = Session(id: UUID())
                    apply(session, to: newSession, client: client, startTime: startDateTime, endTime: finalEndTime)
                    context.insert(newSession)
                    sessionsByClientAndStart[key] = newSession
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

    private static func fetchExistingSessions(
        between earliest: Date?,
        and latest: Date?,
        context: ModelContext
    ) throws -> [Session] {
        guard let earliest, let latest else { return [] }
        let nilStartFallback = Date.distantPast
        let descriptor = FetchDescriptor<Session>(predicate: #Predicate<Session> { session in
            (session.startTime ?? nilStartFallback) >= earliest
                && (session.startTime ?? nilStartFallback) <= latest
        })
        return try context.fetch(descriptor)
    }

    private static func apply(
        _ imported: SessionJSON,
        to session: Session,
        client: Client,
        startTime: Date,
        endTime: Date
    ) {
        session.title = imported.title
        session.startTime = startTime
        session.endTime = endTime
        session.client = client
        session.location = imported.location
        session.notes = imported.notes
        let statusToken = canonicalSessionStatusToken(imported.status) ?? SessionStatus.scheduled.rawValue
        session.status = SessionStatus(normalized: statusToken) ?? .scheduled
    }

    private struct SessionImportKey: Hashable {
        let clientID: UUID
        let startTime: Date
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
