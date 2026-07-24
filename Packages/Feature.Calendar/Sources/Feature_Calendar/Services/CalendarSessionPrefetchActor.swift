import Core
import Foundation
import SwiftData

/// Resolves session relationships inside an isolated SwiftData executor and returns value data to UI.
@ModelActor
actor CalendarSessionPrefetchActor {
    func load(sessionID: UUID) -> PreloadedSessionData {
        var descriptor = FetchDescriptor<Session>(
            predicate: #Predicate<Session> { $0.id == sessionID }
        )
        descriptor.fetchLimit = 1
        guard let session = try? modelContext.fetch(descriptor).first else {
            return PreloadedSessionData(clientID: nil, clientServiceID: nil, supportLog: nil)
        }

        let supportLog = session.supportLogs?.first.map {
            SessionSupportLogDraft(
                isEnabled: true,
                participantName: $0.participantName,
                participantNdisNumber: $0.participantNdisNumber,
                supportItemNumber: $0.supportItemNumber,
                serviceDescription: $0.serviceDescription,
                location: $0.location,
                deliveredFrom: $0.deliveredFrom,
                deliveredTo: $0.deliveredTo,
                deliveredBy: $0.deliveredBy,
                attestedBy: $0.attestedBy,
                attestedAt: $0.attestedAt,
                signatureMethod: $0.signatureMethod,
                signedBy: $0.signedBy,
                signedAt: $0.signedAt,
                cancellationReasonCode: $0.cancellationReasonCode,
                notes: $0.notes
            )
        }

        return PreloadedSessionData(
            clientID: session.client?.id,
            clientServiceID: session.clientService?.id,
            supportLog: supportLog
        )
    }
}
