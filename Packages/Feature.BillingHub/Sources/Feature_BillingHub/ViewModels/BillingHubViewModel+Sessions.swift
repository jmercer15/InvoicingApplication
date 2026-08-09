import Core
import PersistenceModels
import Foundation
import SwiftData

extension BillingHubViewModel {

    /// - Returns: move result when the mutation ran; `nil` when soft-lock staged a confirm or lookup failed.
    @discardableResult
    public func moveSession(
        _ id: UUID,
        to column: KanbanCardData.BillingColumnType,
        force: Bool = false
    ) async -> MoveResult? {
        if !force {
            let locked = requireInvoiceConfirmation(
                for: id,
                message: "This session is already on an invoice. Moving it in Billing Hub will not update that invoice.",
                confirmTitle: "Move Anyway"
            ) { [weak self] in
                _ = await self?.moveSession(id, to: column, force: true)
            }
            if locked { return nil }
        }

        guard let modelID = await sessionModelID(for: id) else {
            bulkActionFeedback = "Session could not be found."
            return .notFound
        }
        do {
            let result = try await workflow.moveSession(modelID: modelID, to: column)
            if result.isSuccess {
                bulkActionFeedback = BillingHubBoardCopy.movedRecord(
                    "Session",
                    to: column
                )
            } else {
                bulkActionFeedback = result.description
            }
            return result
        } catch {
            bulkActionFeedback = "Session could not be moved. \(error.localizedDescription)"
            return nil
        }
    }

    /// - Returns: `true` when details were saved; `false` when soft-lock staged confirm or save failed.
    @discardableResult
    public func updateSessionDetails(id: UUID, durationString: String, force: Bool = false) async -> Bool {
        if !force {
            let locked = requireInvoiceConfirmation(
                for: id,
                message: "This session is already on an invoice. Changing duration here will not update that invoice.",
                confirmTitle: "Save Anyway"
            ) { [weak self] in
                _ = await self?.updateSessionDetails(id: id, durationString: durationString, force: true)
            }
            if locked { return false }
        }

        guard let modelID = await sessionModelID(for: id) else {
            bulkActionFeedback = "Session could not be found."
            return false
        }
        do {
            try await workflow.updateSessionDetails(modelID: modelID, durationString: durationString)
            return true
        } catch {
            bulkActionFeedback = "Session details could not be saved. \(error.localizedDescription)"
            return false
        }
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

    /// - Returns: `true` when the support log was saved. Soft-lock stages a confirm and returns
    ///   `false` so the UI does not treat the cancel/confirm wait as a successful save.
    @discardableResult
    public func upsertSupportLog(sessionId: UUID, draft: SupportLogDraft, force: Bool = false) async throws -> Bool {
        if !force {
            let locked = requireInvoiceConfirmation(
                for: sessionId,
                message: "This session is already on an invoice. Updating the support log will not change that invoice.",
                confirmTitle: "Save Anyway"
            ) { [weak self] in
                do {
                    _ = try await self?.upsertSupportLog(sessionId: sessionId, draft: draft, force: true)
                } catch {
                    self?.bulkActionFeedback = "Support log could not be saved. \(error.localizedDescription)"
                }
            }
            if locked { return false }
        }

        guard let modelID = await sessionModelID(for: sessionId) else {
            bulkActionFeedback = "Support log could not be saved. Session could not be found."
            return false
        }
        try await workflow.upsertSupportLog(sessionModelID: modelID, draft: draft)
        return true
    }

    public func calculateTravelBreakdown(
        sessionId: UUID,
        distance: Double,
        time: Double,
        tolls: Double,
        parking: Double,
        chargeType: String,
        vehicleType: String,
        participantCount: Int,
        splitCosts: Bool
    ) async -> TravelCalculationBreakdown? {
        guard let modelID = await sessionModelID(for: sessionId) else { return nil }
        return try? await workflow.calculateTravelBreakdown(
            sessionModelID: modelID,
            distance: distance,
            time: time,
            tolls: tolls,
            parking: parking,
            chargeType: chargeType,
            vehicleType: vehicleType,
            participantCount: participantCount,
            splitCosts: splitCosts
        )
    }

    public func moveSessionToGrouped(sessionID: UUID) {
        Task {
            if await moveSession(sessionID, to: .grouped) == nil, bulkActionFeedback == nil {
                bulkActionFeedback = "Session could not be moved to Grouped."
            }
        }
    }

    /// Bulk "Move to Grouped" for every session currently sitting in Completed. Mirrors the other
    /// bulk board actions: best-effort per session, with a single summary in `bulkActionFeedback`.
    public func moveAllCompletedSessionsToGrouped(from projection: BillingHubBoardProjection) async {
        guard !bulkProgress.isBulkProcessing else { return }
        let sessions = projection.sessionsByStatus[.completed] ?? []
        guard !sessions.isEmpty else { return }
        bulkProgress.isBulkProcessing = true
        bulkActionFeedback = nil
        let total = sessions.count
        bulkProgress.bulkActionProgress = BillingHubBulkActionProgress(
            action: "Moving to Grouped",
            completedCount: 0,
            totalCount: total
        )
        defer {
            bulkProgress.isBulkProcessing = false
            bulkProgress.bulkActionProgress = nil
        }

        var preMoveSnapshots: [UUID: SessionWorkflowSnapshot] = [:]
        for session in sessions {
            guard let entity = fetchSessionOnMainContext(by: session.id) else { continue }
            preMoveSnapshots[entity.id] = SessionWorkflowSnapshot(
                id: entity.id,
                status: entity.status?.rawValue ?? BillingStatus.completed.rawValue,
                groupID: entity.groupID
            )
        }

        var movedIDs: [UUID] = []
        var skippedInvoiced = 0
        for (index, session) in sessions.enumerated() {
            // Soft-lock: skip invoiced sessions in bulk rather than stacking confirms.
            if let entity = fetchSessionOnMainContext(by: session.id), entity.invoice != nil {
                skippedInvoiced += 1
                bulkProgress.bulkActionProgress = BillingHubBulkActionProgress(
                    action: "Moving to Grouped",
                    completedCount: index + 1,
                    totalCount: total
                )
                continue
            }
            guard let modelID = await sessionModelID(for: session.id) else {
                bulkProgress.bulkActionProgress = BillingHubBulkActionProgress(
                    action: "Moving to Grouped",
                    completedCount: index + 1,
                    totalCount: total
                )
                continue
            }
            do {
                let result = try await workflow.moveSession(modelID: modelID, to: .grouped)
                if result == .success { movedIDs.append(session.id) }
            } catch {
                print("❌ [BillingHubViewModel] Bulk move-to-grouped error: \(error)")
            }
            bulkProgress.bulkActionProgress = BillingHubBulkActionProgress(
                action: "Moving to Grouped",
                completedCount: index + 1,
                totalCount: total
            )
        }

        if !movedIDs.isEmpty {
            let undoSnapshots = movedIDs.compactMap { preMoveSnapshots[$0] }
            if !undoSnapshots.isEmpty {
                lastBulkUndoAction = BulkUndoAction(label: "Move to Grouped", sessionSnapshots: undoSnapshots)
            }
            var message = "Moved \(movedIDs.count) session\(movedIDs.count == 1 ? "" : "s") to Grouped."
            if skippedInvoiced > 0 {
                message += " Skipped \(skippedInvoiced) already invoiced."
            }
            bulkActionFeedback = message
        } else {
            bulkActionFeedback = skippedInvoiced > 0
                ? "No completed sessions could be moved to Grouped. \(skippedInvoiced) already invoiced."
                : "No completed sessions could be moved to Grouped."
        }
    }

    public func dropIntoGroupedColumn(sessionID: UUID) {
        Task {
            if await moveSession(sessionID, to: .grouped) == nil, bulkActionFeedback == nil {
                bulkActionFeedback = "Session could not be moved to Grouped."
            }
        }
    }

    /// Removes a session from its group while keeping it in the Grouped column, ungrouped.
    /// - Returns: `true` when ungrouped; `false` when soft-lock staged confirm or mutation failed.
    @discardableResult
    public func ungroupSession(id: UUID, force: Bool = false) async -> Bool {
        if !force {
            let locked = requireInvoiceConfirmation(
                for: id,
                message: "This session is already on an invoice. Removing it from the group will not update that invoice.",
                confirmTitle: "Remove Anyway"
            ) { [weak self] in
                _ = await self?.ungroupSession(id: id, force: true)
            }
            if locked { return false }
        }

        guard let modelID = await sessionModelID(for: id) else {
            bulkActionFeedback = "Session could not be removed from the group. Session could not be found."
            return false
        }
        do {
            try await workflow.ungroupSessions(modelIDs: [modelID])
            return true
        } catch {
            bulkActionFeedback = "Session could not be removed from the group. \(error.localizedDescription)"
            return false
        }
    }

    /// Removes a session from its current group while keeping it in the Grouped column,
    /// distinct from `dropIntoGroupedColumn` (which only moves column, not group membership).
    public func ungroupSession(sessionID: UUID) {
        Task {
            if !(await ungroupSession(id: sessionID)), bulkActionFeedback == nil {
                bulkActionFeedback = "Session could not be removed from the group."
            }
        }
    }

    @discardableResult
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
        splitCosts: Bool,
        force: Bool = false
    ) async -> Bool {
        if !force {
            let locked = requireInvoiceConfirmation(
                for: id,
                message: "This session is already on an invoice. Adding travel here will not update that invoice.",
                confirmTitle: "Add Anyway"
            ) { [weak self] in
                _ = await self?.addTravelToSession(
                    id: id,
                    distance: distance,
                    time: time,
                    tolls: tolls,
                    parking: parking,
                    chargeType: chargeType,
                    vehicleType: vehicleType,
                    travelDirection: travelDirection,
                    participantCount: participantCount,
                    splitCosts: splitCosts,
                    force: true
                )
            }
            if locked { return false }
        }

        guard let modelID = await sessionModelID(for: id) else {
            bulkActionFeedback = "Travel charge could not be added. Session could not be found."
            return false
        }
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
            bulkActionFeedback = "Travel charge added. Session returned to Completed."
            return true
        } catch {
            bulkActionFeedback = "Travel charge could not be added. \(error.localizedDescription)"
            return false
        }
    }

    /// Groups two sessions after the workflow await completes. Returns `false` on failure
    /// or when soft-lock stages a confirm for an invoiced session.
    @discardableResult
    public func groupSessionsSmooth(sourceID: UUID, targetID: UUID, force: Bool = false) async -> Bool {
        if !force {
            let invoicedIDs = [sourceID, targetID].filter { id in
                fetchSessionOnMainContext(by: id)?.invoice != nil
            }
            if let firstInvoiced = invoicedIDs.first {
                let locked = requireInvoiceConfirmation(
                    for: firstInvoiced,
                    message: "One or more sessions are already on an invoice. Grouping them will not update that invoice.",
                    confirmTitle: "Group Anyway"
                ) { [weak self] in
                    _ = await self?.groupSessionsSmooth(sourceID: sourceID, targetID: targetID, force: true)
                }
                if locked { return false }
            }
        }

        let modelIDs = await sessionModelIDs(for: [sourceID, targetID])
        guard let sourceModelID = modelIDs[sourceID],
              let targetModelID = modelIDs[targetID] else {
            bulkActionFeedback = "Sessions could not be grouped. One or both could not be found."
            return false
        }
        do {
            try await workflow.groupSessions(modelIDs: [sourceModelID, targetModelID], groupID: UUID())
            return true
        } catch {
            bulkActionFeedback = "Sessions could not be grouped. \(error.localizedDescription)"
            return false
        }
    }

    /// Adds a session to an existing group after the workflow await completes.
    @discardableResult
    public func addSessionToGroup(sessionID: UUID, groupID: UUID, force: Bool = false) async -> Bool {
        if !force {
            let locked = requireInvoiceConfirmation(
                for: sessionID,
                message: "This session is already on an invoice. Adding it to a group will not update that invoice.",
                confirmTitle: "Add Anyway"
            ) { [weak self] in
                _ = await self?.addSessionToGroup(sessionID: sessionID, groupID: groupID, force: true)
            }
            if locked { return false }
        }

        guard let sessionModelID = await sessionModelID(for: sessionID) else {
            bulkActionFeedback = "Session could not be added to the group."
            return false
        }
        do {
            try await workflow.groupSessions(modelIDs: [sessionModelID], groupID: groupID)
            return true
        } catch {
            bulkActionFeedback = "Session could not be added to the group. \(error.localizedDescription)"
            return false
        }
    }

    public enum ProviderType { case therapist, dsw }

    public func inferProviderType(for sessionId: UUID) -> ProviderType {
        let service = fetchSessionOnMainContext(by: sessionId)?.clientService
        let inferred = BillingHubTravelChargeCalculator.inferredProviderType(
            itemName: service?.serviceName,
            itemDescription: nil,
            ndisCode: service?.ndisCode
        )
        return inferred == .therapist ? .therapist : .dsw
    }
}
