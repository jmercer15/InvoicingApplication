import Foundation

/// Use case for approving travel charges
public struct ApproveTravelCharge: Sendable {
    private let repository: TravelChargeRepository
    
    public init(repository: TravelChargeRepository) {
        self.repository = repository
    }
    
    /// Approve a single travel charge
    public func callAsFunction(id: UUID) async throws -> TravelCharge {
        // Verify the travel charge exists and can be approved
        guard let travelCharge = try await repository.fetchById(id) else {
            throw TravelChargeError.travelChargeNotFound
        }
        
        guard canApprove(travelCharge) else {
            throw TravelChargeError.cannotApproveTravelCharge
        }
        
        return try await repository.approve(id: id)
    }
    
    /// Approve multiple travel charges
    public func callAsFunction(ids: [UUID]) async throws -> [TravelCharge] {
        var approvedCharges: [TravelCharge] = []
        
        for id in ids {
            do {
                let approvedCharge = try await callAsFunction(id: id)
                approvedCharges.append(approvedCharge)
            } catch {
                // Log error but continue with other approvals
                print("Failed to approve travel charge \(id): \(error)")
            }
        }
        
        return approvedCharges
    }
    
    /// Approve all pending travel charges for a session
    public func callAsFunction(forSessionId sessionId: UUID) async throws -> [TravelCharge] {
        let pendingCharges = try await repository.fetchBySessionId(sessionId)
        let approvableIds = pendingCharges.compactMap { travelCharge in
            canApprove(travelCharge) ? travelCharge.id : nil
        }
        
        return try await callAsFunction(ids: approvableIds)
    }
    
    /// Approve all pending travel charges for a client
    public func callAsFunction(forClientId clientId: UUID) async throws -> [TravelCharge] {
        let pendingCharges = try await repository.fetchByClientId(clientId)
        let approvableIds = pendingCharges.compactMap { travelCharge in
            canApprove(travelCharge) ? travelCharge.id : nil
        }
        
        return try await callAsFunction(ids: approvableIds)
    }
    
    /// Check if a travel charge can be approved based on business rules
    private func canApprove(_ travelCharge: TravelCharge) -> Bool {
        // Business rule: Only pending travel charges can be approved
        return travelCharge.status == .pending
    }
}

