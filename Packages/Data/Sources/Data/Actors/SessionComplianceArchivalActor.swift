import Foundation
import PersistenceModels
import SwiftData

/// Explicit archival/detach for session-linked compliance rows (travel, support logs, review items).
///
/// Session deletion no longer cascades these rows; callers must archive or reassign first when retention is required.
@ModelActor
public actor SessionComplianceArchivalActor {
    public enum ArchivalMode: Sendable {
        /// Detaches compliance rows from the session while preserving audit history.
        case detachFromSession
        /// Deletes compliance rows when the caller confirms destruction is acceptable.
        case deleteComplianceRows
    }

    public struct ArchivalSummary: Sendable, Equatable {
        public let travelChargeCount: Int
        public let supportLogCount: Int
        public let reviewItemCount: Int

        public init(travelChargeCount: Int, supportLogCount: Int, reviewItemCount: Int) {
            self.travelChargeCount = travelChargeCount
            self.supportLogCount = supportLogCount
            self.reviewItemCount = reviewItemCount
        }
    }

    public func archiveComplianceRows(
        forSessionId sessionId: UUID,
        mode: ArchivalMode
    ) throws -> ArchivalSummary {
        let sessionID = sessionId
        var descriptor = FetchDescriptor<Session>(predicate: #Predicate { $0.id == sessionID })
        descriptor.fetchLimit = 1
        guard let session = try modelContext.fetch(descriptor).first else {
            return ArchivalSummary(travelChargeCount: 0, supportLogCount: 0, reviewItemCount: 0)
        }

        let travel = session.travelCharges ?? []
        let logs = session.supportLogs ?? []
        let reviews = session.reviewItems ?? []

        switch mode {
        case .detachFromSession:
            for charge in travel { charge.linkedSession = nil }
            for log in logs { log.session = nil }
            for review in reviews { review.session = nil }
        case .deleteComplianceRows:
            for charge in travel { modelContext.delete(charge) }
            for log in logs { modelContext.delete(log) }
            for review in reviews { modelContext.delete(review) }
            session.travelCharges = []
            session.supportLogs = []
            session.reviewItems = []
        }

        if modelContext.hasChanges {
            try modelContext.save()
        }

        return ArchivalSummary(
            travelChargeCount: travel.count,
            supportLogCount: logs.count,
            reviewItemCount: reviews.count
        )
    }
}
