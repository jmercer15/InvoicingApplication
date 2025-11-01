import Foundation
import Core

// MARK: - TravelCharge Mapping
// ARCHITECTURAL DECISION: Domain model is the source of truth
// Entity model will be simplified to match domain requirements

extension TravelCharge {
    /// Convert from TravelChargeEntity to domain model
    /// 
    /// This mapping handles the conceptual differences between the entity and domain models.
    /// The entity model contains EventKit integration properties that are not part of the domain model.
    init(from entity: TravelChargeEntity) {
        // Map addresses from location field
        let (fromAddress, toAddress): (String?, String?)
        if let location = entity.location {
            let addressComponents = location.components(separatedBy: " to ")
            if addressComponents.count == 2 {
                fromAddress = addressComponents[0].trimmingCharacters(in: .whitespaces)
                toAddress = addressComponents[1].trimmingCharacters(in: .whitespaces)
            } else {
                fromAddress = location
                toAddress = nil
            }
        } else {
            fromAddress = nil
            toAddress = nil
        }
        
        // Map status from notes field (status is embedded in notes until entity is updated with dedicated status field)
        let status: TravelChargeStatus
        if let notes = entity.notes, notes.contains("Status:") {
            let statusString = notes.components(separatedBy: "Status: ").last?.trimmingCharacters(in: .whitespacesAndNewlines)
            status = TravelChargeStatus(rawValue: statusString ?? "pending") ?? .pending
        } else {
            status = .pending
        }
        
        // Map created date
        let createdDate = entity.ekCreationDate ?? Date()
        
        // Initialize with all values
        self.init(
            id: entity.id,
            sessionId: entity.linkedSession?.id ?? UUID(),
            amount: entity.parkingCost ?? 0.0,
            distance: entity.travelDistance,
            travelTime: entity.travelDuration,
            fromAddress: fromAddress,
            toAddress: toAddress,
            status: status,
            createdDate: createdDate,
            lastModifiedDate: entity.lastModifiedDate,
            notes: entity.notes
        )
    }
}

extension TravelChargeEntity {
    /// Update entity from domain model
    /// 
    /// This method updates the entity with values from the domain model,
    /// handling the conceptual differences between the two models.
    func update(from domainModel: TravelCharge) {
        self.id = domainModel.id
        self.travelDistance = domainModel.distance
        self.travelDuration = domainModel.travelTime
        self.notes = domainModel.notes
        self.lastModifiedDate = domainModel.lastModifiedDate
        
        // Store amount in parkingCost field (using parkingCost as amount storage)
        self.parkingCost = domainModel.amount
        
        // Map addresses to location field
        if let fromAddress = domainModel.fromAddress, let toAddress = domainModel.toAddress {
            self.location = "\(fromAddress) to \(toAddress)"
        } else if let fromAddress = domainModel.fromAddress {
            self.location = fromAddress
        } else {
            self.location = nil
        }
        
        // Store status in notes field (status is embedded in notes until entity is updated with dedicated status field)
        let statusNote = "Status: \(domainModel.status.rawValue)"
        if let existingNotes = self.notes, !existingNotes.contains("Status:") {
            self.notes = "\(existingNotes)\n\(statusNote)"
        } else if self.notes == nil {
            self.notes = statusNote
        }
        
        // Set creation date if not already set
        if self.ekCreationDate == nil {
            self.ekCreationDate = domainModel.createdDate
        }
    }
}

// MARK: - TravelChargeAuditLog Mapping
// Note: TravelChargeAuditLogEntity is not yet implemented
// These extensions will be added when the corresponding entity type is created

// MARK: - TravelChargeReviewItem Mapping
// Note: TravelChargeReviewItemEntity is not yet implemented
// These extensions will be added when the corresponding entity type is created
