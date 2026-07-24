import Foundation
import SwiftData

/// SwiftData write path for travel charge automation (charges, reviews, audit logs).
public final class TravelChargeAutomationPersistence: @unchecked Sendable {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Travel charge

    public func persistTravelCharge(_ snapshot: TravelChargeSnapshot) throws {
        let entity = TravelCharge(id: snapshot.id)
        updateTravelChargeEntity(entity, with: snapshot)
        try applyTravelChargeRelationships(from: snapshot, to: entity)
        modelContext.insert(entity)
        try modelContext.save()
    }

    private func updateTravelChargeEntity(_ entity: TravelCharge, with snapshot: TravelChargeSnapshot) {
        entity.title = snapshot.title
        entity.location = snapshot.location
        entity.notes = snapshot.notes
        entity.ekEventID = snapshot.ekEventID
        entity.ekCalendarID = snapshot.ekCalendarID
        entity.ekCreationDate = snapshot.ekCreationDate
        entity.ekLastModifiedDate = snapshot.ekLastModifiedDate
        entity.latitude = snapshot.latitude
        entity.longitude = snapshot.longitude
        entity.distanceKM = snapshot.distanceKM
        entity.durationMinutes = snapshot.durationMinutes
        entity.travelType = snapshot.travelType
        entity.chargeAmount = snapshot.chargeAmount
    }

    private func applyTravelChargeRelationships(from snapshot: TravelChargeSnapshot, to entity: TravelCharge) throws {
        entity.client = try resolveTravelChargeLinkedClient(by: snapshot.clientId)
        entity.linkedSession = try resolveTravelChargeLinkedSession(by: snapshot.sessionId)
        entity.service = try resolveTravelChargeLinkedClientService(by: snapshot.serviceId)
    }

    private func resolveTravelChargeLinkedClient(by id: UUID?) throws -> Client? {
        guard let id else { return nil }
        let predicate = #Predicate<Client> { $0.id == id }
        return try modelContext.fetch(FetchDescriptor<Client>(predicate: predicate)).first
    }

    private func resolveTravelChargeLinkedSession(by id: UUID?) throws -> Session? {
        guard let id else { return nil }
        let predicate = #Predicate<Session> { $0.id == id }
        return try modelContext.fetch(FetchDescriptor<Session>(predicate: predicate)).first
    }

    private func resolveTravelChargeLinkedClientService(by id: UUID?) throws -> ClientService? {
        guard let id else { return nil }
        let predicate = #Predicate<ClientService> { $0.id == id }
        return try modelContext.fetch(FetchDescriptor<ClientService>(predicate: predicate)).first
    }

    // MARK: - Review

    public func fetchAllTravelChargeReviewSnapshots() throws -> [TravelChargeReviewSnapshot] {
        let descriptor = FetchDescriptor<TravelChargeReviewItem>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).map { $0.snapshot() }
    }

    public func fetchTravelChargeReviewSnapshot(byId id: UUID) throws -> TravelChargeReviewSnapshot? {
        let predicate = #Predicate<TravelChargeReviewItem> { $0.id == id }
        let descriptor = FetchDescriptor<TravelChargeReviewItem>(predicate: predicate)
        guard let entity = try modelContext.fetch(descriptor).first else { return nil }
        return entity.snapshot()
    }

    public func resolveTravelChargeReview(id: UUID, status: String, notes: String?) throws {
        let predicate = #Predicate<TravelChargeReviewItem> { $0.id == id }
        let descriptor = FetchDescriptor<TravelChargeReviewItem>(predicate: predicate)
        guard let entity = try modelContext.fetch(descriptor).first else {
            throw PersistenceError.notFound(id: id)
        }
        entity.status = status
        entity.resolutionNotes = notes
        entity.timestamp = Date()
        try modelContext.save()
    }

    private func applyTravelChargeReviewSnapshot(_ snapshot: TravelChargeReviewSnapshot, to entity: TravelChargeReviewItem) {
        entity.reason = snapshot.reason
        entity.timestamp = snapshot.timestamp
        entity.status = snapshot.status
        entity.overrideReason = snapshot.overrideReason
        entity.overrideType = snapshot.overrideType
        entity.resolutionNotes = snapshot.resolutionNotes
        entity.sessionID = snapshot.sessionID
        entity.sessionTitle = snapshot.sessionTitle
        entity.clientName = snapshot.clientName
        entity.violations = snapshot.violations
        entity.violationDetails = snapshot.violationDetails
        entity.suggestedActions = snapshot.suggestedActions
        entity.overrideOptions = snapshot.overrideOptions
    }

    public func persistTravelChargeReview(_ snapshot: TravelChargeReviewSnapshot) throws {
        let entity = TravelChargeReviewItem(id: snapshot.id)
        applyTravelChargeReviewSnapshot(snapshot, to: entity)
        if let sessionId = snapshot.sessionId {
            let sessionDescriptor = FetchDescriptor<Session>(predicate: #Predicate<Session> { $0.id == sessionId })
            entity.session = try modelContext.fetch(sessionDescriptor).first
        }
        modelContext.insert(entity)
        try modelContext.save()
    }

    // MARK: - Audit

    public func persistTravelChargeAuditLog(_ snapshot: TravelChargeAuditLogSnapshot) throws {
        let entity = TravelChargeAuditLog(id: snapshot.id)
        entity.timestamp = snapshot.timestamp
        entity.summary = snapshot.summary
        entity.action = snapshot.action
        entity.details = snapshot.details
        if let chargeId = snapshot.travelChargeId {
            let chargeDescriptor = FetchDescriptor<TravelCharge>(
                predicate: #Predicate<TravelCharge> { $0.id == chargeId }
            )
            entity.charge = try modelContext.fetch(chargeDescriptor).first
        }
        modelContext.insert(entity)
        try modelContext.save()
    }
}
