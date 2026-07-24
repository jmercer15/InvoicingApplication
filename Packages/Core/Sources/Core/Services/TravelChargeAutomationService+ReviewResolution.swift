import Foundation
import os
import SwiftData

extension TravelChargeAutomationService {
    /// Fetches pending review items that need user attention.
    public func fetchPendingReviews() async -> [TravelChargeReviewSnapshot] {
        do {
            return try persistence.fetchAllTravelChargeReviewSnapshots().filter { $0.status == "pending" }
        } catch {
            Logger.automation.error("Failed to fetch review items: \(error)")
            return []
        }
    }

    /// Resolves a review item by creating a travel charge with override (safe for concurrency).
    public func resolveReviewWithOverride(reviewItemId: UUID, overrideType: String, overrideReason: String? = nil) async throws {
        guard let reviewItem = try? persistence.fetchTravelChargeReviewSnapshot(byId: reviewItemId) else {
            throw TravelChargeError.invalidSession // Using generic error for item not found
        }

        try await resolveReviewWithOverride(reviewItem, overrideType: overrideType, overrideReason: overrideReason)
    }

    /// Resolves a review item by skipping the travel charge (safe for concurrency).
    public func resolveReviewBySkipping(reviewItemId: UUID, reason: String? = nil) async throws {
        guard let reviewItem = try? persistence.fetchTravelChargeReviewSnapshot(byId: reviewItemId) else {
            throw TravelChargeError.invalidSession
        }

        try await resolveReviewBySkipping(reviewItem, reason: reason)
    }

    /// Resolves a review item by creating a travel charge with override.
    private func resolveReviewWithOverride(_ reviewItem: TravelChargeReviewSnapshot, overrideType: String, overrideReason: String? = nil) async throws {
        guard let sessionId = reviewItem.sessionId,
              let session = try? fetchSession(byId: sessionId)
        else {
            throw TravelChargeError.invalidSession
        }

        // Construct a automation context to leverage existing logic
        let contexts = try await prefetchContexts(for: [session])
        guard let context = contexts.first else { throw TravelChargeError.invalidSession }

        // Resolve the review item state in SwiftData.
        let notes = "Overridden with type: \(overrideType). Reason: \(overrideReason ?? "None")"
        try persistence.resolveTravelChargeReview(id: reviewItem.id, status: "resolved", notes: notes)

        // Create the travel charge with override information
        try await createTravelChargeForSession(context, overrideType: overrideType, overrideReason: overrideReason)

        // Log the override action
        await logReviewResolution(reviewItem, action: "overridden", details: "Override type: \(overrideType)")

        _ = try? modelContext.fetchCount(FetchDescriptor<Session>()) // Nudge the manual-save context to process pending changes.
    }

    /// Resolves a review item by skipping the travel charge.
    private func resolveReviewBySkipping(_ reviewItem: TravelChargeReviewSnapshot, reason: String? = nil) async throws {
        // Resolve the review item state in SwiftData.
        let notes = "Skipped by user. Reason: \(reason ?? "None")"
        try persistence.resolveTravelChargeReview(id: reviewItem.id, status: "resolved", notes: notes)

        // Log the skip action
        await logReviewResolution(reviewItem, action: "skipped", details: reason ?? "User chose to skip")

        _ = try? modelContext.fetchCount(FetchDescriptor<Session>()) // Nudge the manual-save context to process pending changes.
    }

    /// Creates a travel charge for a session with override information.
    private func createTravelChargeForSession(_ session: SessionAutomationContext, overrideType: String? = nil, overrideReason: String? = nil) async throws {
        let _ = (overrideType, overrideReason)
        Logger.automation.info("Creating travel charge for session: \(session.title) with override")

        guard let client = session.client, let startTime = session.session.startTime else {
            throw TravelChargeError.invalidSession
        }

        // 1. Re-construct context: Fetch sibling sessions for the same day to determine travel logic
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: startTime)

        // Fetch sessions for the client on this day from SwiftData.
        let clientSessions = (try? fetchSessions(byClientId: client.id)) ?? []

        let startOfNextDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        let daySessionsRaw = clientSessions.filter { clientSession in
            guard let sessionStart = clientSession.startTime else { return false }
            return sessionStart >= startOfDay && sessionStart < startOfNextDay && !clientSession.isTravel
        }

        // Convert raw sessions to automation contexts for helper compatibility
        let daySessions = try await prefetchContexts(for: daySessionsRaw)

        let daySessionInstances = expandSessionsToInstances(daySessions)
        let sortedSessions = sortSessionsChronologically(daySessionInstances)

        // Find the index of the current session
        guard let index = sortedSessions.firstIndex(where: { $0.session.id == session.session.id }) else {
            throw TravelChargeError.invalidSession
        }

        // 2. Determine necessary travel directions
        let directions = determineTravelDirections(sessionIndex: index, daySessions: sortedSessions)

        for direction in directions {
            // 3. Resolve Locations
            let (fromLocation, toLocation, fromTime, toTime): (String?, String?, Date?, Date?) = {
                switch direction {
                case .before:
                    let prev = previousNonTravelSession(sessionIndex: index, daySessions: sortedSessions)
                    return (prev?.session.location, session.session.location, prev?.instanceEnd, session.session.startTime)
                case .after:
                    let next = nextNonTravelSession(sessionIndex: index, daySessions: sortedSessions)
                    return (session.session.location, next?.session.location, session.session.endTime, next?.instanceStart)
                case .toClient, .fromClient, .roundTrip, .betweenClients:
                    return (nil, nil, nil, nil)
                }
            }()

            // Resolve final origin/dest considering business address
            let businessAddr = await getBusinessAddress()
            let finalFromLoc = fromLocation ?? businessAddr
            let finalToLoc = toLocation ?? businessAddr

            guard let fromLoc = finalFromLoc, let toLoc = finalToLoc else {
                Logger.automation.error("Missing location data for session \(session.title)")
                continue
            }

            // 4. Calculate Metrics (Async)
            guard let fromCoord = await geocodeAddressAsync(fromLoc),
                  let toCoord = await geocodeAddressAsync(toLoc),
                  let distance = await calculateDrivingDistanceAsync(from: fromCoord, to: toCoord)
            else {
                Logger.automation.error("Failed to calculate metrics for session \(session.title)")
                continue
            }

            let travelTime = estimateTravelTime(distance: distance) ?? businessRules.defaultTravelTime

            // The mmmZone and charge types depend on the session context.
            guard let mmmZone = lookupMMMZone(for: session) else {
                await queueForUserReview(
                    session: session,
                    reason: "MMM zone could not be resolved from available coordinates",
                    suggestedActions: ["Review Session Location", "Add Coordinates"],
                    overrideOptions: ["MMM Zone Override"]
                )
                continue
            }

            // 5. Determine Charge Types
            let chargeTypes = await determineChargeTypes(session: session)

            for chargeType in chargeTypes {
                if TravelChargeDuplicatePolicy.hasExistingCharge(
                    sessionId: session.id,
                    clientId: session.client?.id,
                    chargeType: chargeType,
                    direction: direction,
                    existing: session.session.travelCharges
                ) {
                    Logger.automation.info("Travel charge already exists, skipping duplicate.")
                    continue
                }

                // 6. Create Charge with Overrides
                let ndisService = await findTravelServiceSnapshotAsync(client: client, session: session, chargeType: chargeType)

                let finalContext = SessionAutomationContext(
                    session: session.session,
                    client: client,
                    service: ndisService,
                    ndisItem: nil,
                    address: nil
                )

                let sharedParticipants = await detectSharedTravelParticipantsAsync(
                    session: finalContext,
                    daySessions: sortedSessions,
                    direction: direction
                )
                let participantCount = determineParticipantCount(session: finalContext, sharedParticipants: sharedParticipants)
                let splitCosts = participantCount > 1
                let vehicleType = determineVehicleType(session: finalContext, chargeType: chargeType)

                let travelCharge = await buildTravelCharge(
                    client: client,
                    session: finalContext,
                    serviceSnapshot: ndisService,
                    direction: direction,
                    startTime: (direction == .before) ? fromTime : session.session.endTime,
                    endTime: (direction == .before) ? session.session.startTime : toTime,
                    location: (direction == .before) ? fromLoc : toLoc,
                    mmmZone: mmmZone,
                    distance: distance,
                    travelTime: travelTime,
                    vehicleType: vehicleType,
                    parking: nil,
                    tolls: nil,
                    participantCount: Int16(participantCount),
                    chargeType: chargeType,
                    splitCosts: splitCosts,
                    status: .pending
                )

                await saveTravelCharge(travelCharge, context: finalContext)
            }
        }
    }

    // MARK: - Async helper wrappers

    private func getBusinessAddress() async -> String? {
        let business = try? fetchFirstBusinessSnapshot()
        return business?.address?.fullFormattedAddress
    }

    /// Logs review resolution for audit purposes.
    private func logReviewResolution(_ reviewItem: TravelChargeReviewSnapshot, action: String, details: String) async {
        let log = TravelChargeAuditLogSnapshot(
            id: UUID(),
            timestamp: Date(),
            summary: "Item: \(reviewItem.reason ?? "Unknown") - \(details)",
            action: action,
            details: "Performed by: System",
            travelChargeId: nil
        )
        try? persistence.persistTravelChargeAuditLog(log)
        Logger.automation.info("Review resolution log: \(reviewItem.reason ?? "Unknown") - Action: \(action) - Details: \(details)")
    }

    /// Logs review items for audit/compliance purposes
    func logReviewItem(_ reviewItem: TravelChargeReviewSnapshot, action: String = "flagged") async {
        let log = TravelChargeAuditLogSnapshot(
            id: UUID(),
            timestamp: Date(),
            summary: reviewItem.reason ?? "No reason",
            action: action,
            details: "Performed by: System",
            travelChargeId: nil
        )
        try? persistence.persistTravelChargeAuditLog(log)
        Logger.automation.info("Review item log: \(action) - \(reviewItem.reason ?? "No reason")")
    }
}

