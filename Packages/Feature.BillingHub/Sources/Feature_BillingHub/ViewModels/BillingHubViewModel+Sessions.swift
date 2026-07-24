import Core
import Data
import Foundation
import SwiftData

extension BillingHubViewModel {
    
    public func moveSession(_ id: UUID, to column: KanbanCardData.BillingColumnType) async {
        guard let modelID = await sessionModelID(for: id) else { return }
        do {
            _ = try await workflow.moveSession(modelID: modelID, to: column)
        } catch {
            print("❌ [BillingHubViewModel] Session move error: \(error)")
        }
    }
    
    public func updateSessionDetails(id: UUID, durationString: String) async {
        guard let modelID = await sessionModelID(for: id) else { return }
        do {
            try await workflow.updateSessionDetails(modelID: modelID, durationString: durationString)
        } catch { print("❌ Update session details error: \(error)") }
    }

    public func fetchSupportLog(forSessionId sessionId: UUID) async -> SupportLog? {
        guard let session = fetchSessionOnMainContext(by: sessionId),
              let supportLogs = session.supportLogs else {
            return nil
        }
        return supportLogs.max { lhs, rhs in
            lhs.attestedAt < rhs.attestedAt
        }
    }

    public func upsertSupportLog(sessionId: UUID, draft: SupportLogDraft) async throws {
        guard let modelID = await sessionModelID(for: sessionId) else { return }
        try await workflow.upsertSupportLog(sessionModelID: modelID, draft: draft)
    }

    public func calculateTravelBreakdown(
        sessionId: UUID,
        distance: Double,
        time: Double,
        tolls: Double,
        parking: Double,
        chargeType _: String,
        vehicleType _: String,
        participantCount: Int,
        splitCosts _: Bool
    ) async -> TravelCalculationBreakdown? {
        guard (try? await workflow.sessionExists(id: sessionId)) == true else { return nil }
        return TravelCalculationBreakdown(
            labourTotal: time * 1.5,
            nonLabourTotal: distance * 0.85 + tolls + parking,
            grossTotal: (time * 1.5) + (distance * 0.85) + tolls + parking,
            billableMinutes: time,
            requestedMinutes: time,
            totalPerParticipant: ((time * 1.5) + (distance * 0.85) + tolls + parking) / Double(participantCount)
        )
    }

    public func moveSessionToGrouped(sessionID: UUID) {
        Task { await moveSession(sessionID, to: .grouped) }
    }

    public func dropIntoGroupedColumn(sessionID: UUID) {
        Task { await moveSession(sessionID, to: .grouped) }
    }

    public func addTravelToSession(
        id: UUID,
        distance: Double,
        time: Double,
        tolls: Double,
        parking: Double,
        chargeType: String,
        vehicleType: String,
        travelDirection: String,
        participantCount: Int,
        splitCosts: Bool
    ) async {
        guard let modelID = await sessionModelID(for: id) else { return }
        do {
            try await workflow.addTravelCharge(
                sessionModelID: modelID,
                distance: distance,
                time: time,
                tolls: tolls,
                parking: parking,
                chargeType: chargeType,
                vehicleType: vehicleType,
                travelDirection: travelDirection,
                participantCount: participantCount,
                splitCosts: splitCosts
            )
        } catch { print("❌ Add travel error: \(error)") }
    }

    public func groupSessionsSmooth(sourceID: UUID, targetID: UUID) -> Bool {
        Task {
            guard let sourceModelID = await sessionModelID(for: sourceID),
                  let targetModelID = await sessionModelID(for: targetID) else { return }
            try? await workflow.groupSessions(modelIDs: [sourceModelID, targetModelID], groupID: UUID())
        }
        return true
    }

    public func addSessionToGroup(sessionID: UUID, groupID: UUID) -> Bool {
        Task {
            guard let sessionModelID = await sessionModelID(for: sessionID) else { return }
            try? await workflow.groupSessions(modelIDs: [sessionModelID], groupID: groupID)
        }
        return true
    }

    public enum ProviderType { case therapist, dsw }
    public func inferProviderType() -> ProviderType {
        return .therapist
    }
}
