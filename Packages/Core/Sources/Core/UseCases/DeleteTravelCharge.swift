import Foundation

/// Use case for deleting a travel charge
public struct DeleteTravelCharge: Sendable {
    private let repository: TravelChargeRepository
    
    public init(repository: TravelChargeRepository) {
        self.repository = repository
    }
    
    /// Delete a travel charge by ID
    public func callAsFunction(id: UUID) async throws {
        // Verify the travel charge exists before deletion
        guard let travelCharge = try await repository.fetchById(id) else {
            throw TravelChargeError.travelChargeNotFound
        }
        
        // Check if travel charge can be deleted (business rules)
        guard canDelete(travelCharge) else {
            throw TravelChargeError.cannotDeleteTravelCharge
        }
        
        try await repository.delete(id: id)
    }
    
    /// Delete multiple travel charges
    public func callAsFunction(ids: [UUID]) async throws {
        for id in ids {
            try await callAsFunction(id: id)
        }
    }
    
    /// Delete all travel charges for a session
    public func callAsFunction(forSessionId sessionId: UUID) async throws {
        let travelCharges = try await repository.fetchBySessionId(sessionId)
        let deletableIds = travelCharges.compactMap { travelCharge in
            canDelete(travelCharge) ? travelCharge.id : nil
        }
        
        try await callAsFunction(ids: deletableIds)
    }
    
    /// Check if a travel charge can be deleted based on business rules
    private func canDelete(_ travelCharge: TravelCharge) -> Bool {
        // Business rule: Cannot delete approved or paid travel charges
        switch travelCharge.status {
        case .approved, .paid:
            return false
        case .pending, .rejected:
            return true
        }
    }
}

