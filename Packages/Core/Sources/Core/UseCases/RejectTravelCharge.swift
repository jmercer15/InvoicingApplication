import Foundation

/// Use case for rejecting travel charges
public struct RejectTravelCharge: Sendable {
    private let repository: TravelChargeRepository
    
    public init(repository: TravelChargeRepository) {
        self.repository = repository
    }
    
    /// Reject a single travel charge
    public func callAsFunction(id: UUID, reason: String? = nil) async throws -> TravelCharge {
        // Verify the travel charge exists and can be rejected
        guard let travelCharge = try await repository.fetchById(id) else {
            throw TravelChargeError.travelChargeNotFound
        }
        
        guard canReject(travelCharge) else {
            throw TravelChargeError.cannotRejectTravelCharge
        }
        
        return try await repository.reject(id: id, reason: reason)
    }
    
    /// Reject multiple travel charges
    public func callAsFunction(ids: [UUID], reason: String? = nil) async throws -> [TravelCharge] {
        var rejectedCharges: [TravelCharge] = []
        
        for id in ids {
            do {
                let rejectedCharge = try await callAsFunction(id: id, reason: reason)
                rejectedCharges.append(rejectedCharge)
            } catch {
                // Log error but continue with other rejections
                print("Failed to reject travel charge \(id): \(error)")
            }
        }
        
        return rejectedCharges
    }
    
    /// Reject all pending travel charges for a session
    public func callAsFunction(forSessionId sessionId: UUID, reason: String? = nil) async throws -> [TravelCharge] {
        let pendingCharges = try await repository.fetchBySessionId(sessionId)
        let rejectableIds = pendingCharges.compactMap { travelCharge in
            canReject(travelCharge) ? travelCharge.id : nil
        }
        
        return try await callAsFunction(ids: rejectableIds, reason: reason)
    }
    
    /// Reject all pending travel charges for a client
    public func callAsFunction(forClientId clientId: UUID, reason: String? = nil) async throws -> [TravelCharge] {
        let pendingCharges = try await repository.fetchByClientId(clientId)
        let rejectableIds = pendingCharges.compactMap { travelCharge in
            canReject(travelCharge) ? travelCharge.id : nil
        }
        
        return try await callAsFunction(ids: rejectableIds, reason: reason)
    }
    
    /// Check if a travel charge can be rejected based on business rules
    private func canReject(_ travelCharge: TravelCharge) -> Bool {
        // Business rule: Only pending travel charges can be rejected
        return travelCharge.status == .pending
    }
}

