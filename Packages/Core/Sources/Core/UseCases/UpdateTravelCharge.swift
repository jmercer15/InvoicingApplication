import Foundation

/// Use case for updating an existing travel charge
public struct UpdateTravelCharge: Sendable {
    private let repository: TravelChargeRepository
    
    public init(repository: TravelChargeRepository) {
        self.repository = repository
    }
    
    /// Update an existing travel charge
    public func callAsFunction(_ travelCharge: TravelCharge) async throws -> TravelCharge {
        let updatedTravelCharge = TravelCharge(
            id: travelCharge.id,
            sessionId: travelCharge.sessionId,
            amount: travelCharge.amount,
            distance: travelCharge.distance,
            travelTime: travelCharge.travelTime,
            fromAddress: travelCharge.fromAddress,
            toAddress: travelCharge.toAddress,
            status: travelCharge.status,
            createdDate: travelCharge.createdDate,
            lastModifiedDate: Date(),
            notes: travelCharge.notes
        )
        
        return try await repository.update(updatedTravelCharge)
    }
    
    /// Update travel charge amount
    public func callAsFunction(updateAmount id: UUID, amount: Double) async throws -> TravelCharge {
        guard let travelCharge = try await repository.fetchById(id) else {
            throw TravelChargeError.travelChargeNotFound
        }
        
        let updatedTravelCharge = TravelCharge(
            id: travelCharge.id,
            sessionId: travelCharge.sessionId,
            amount: amount,
            distance: travelCharge.distance,
            travelTime: travelCharge.travelTime,
            fromAddress: travelCharge.fromAddress,
            toAddress: travelCharge.toAddress,
            status: travelCharge.status,
            createdDate: travelCharge.createdDate,
            lastModifiedDate: Date(),
            notes: travelCharge.notes
        )
        
        return try await repository.update(updatedTravelCharge)
    }
    
    /// Update travel charge notes
    public func callAsFunction(updateNotes id: UUID, notes: String?) async throws -> TravelCharge {
        guard let travelCharge = try await repository.fetchById(id) else {
            throw TravelChargeError.travelChargeNotFound
        }
        
        let updatedTravelCharge = TravelCharge(
            id: travelCharge.id,
            sessionId: travelCharge.sessionId,
            amount: travelCharge.amount,
            distance: travelCharge.distance,
            travelTime: travelCharge.travelTime,
            fromAddress: travelCharge.fromAddress,
            toAddress: travelCharge.toAddress,
            status: travelCharge.status,
            createdDate: travelCharge.createdDate,
            lastModifiedDate: Date(),
            notes: notes
        )
        
        return try await repository.update(updatedTravelCharge)
    }
}

/// Travel charge specific errors
public enum TravelChargeError: Error, LocalizedError {
    case travelChargeNotFound
    case invalidAmount
    case invalidSessionId
    case cannotApproveTravelCharge
    case cannotDeleteTravelCharge
    case cannotRejectTravelCharge
    
    public var errorDescription: String? {
        switch self {
        case .travelChargeNotFound:
            return "Travel charge not found"
        case .invalidAmount:
            return "Invalid amount value"
        case .invalidSessionId:
            return "Invalid session ID"
        case .cannotApproveTravelCharge:
            return "Only pending travel charges can be approved"
        case .cannotDeleteTravelCharge:
            return "Cannot delete approved or paid travel charges"
        case .cannotRejectTravelCharge:
            return "Only pending travel charges can be rejected"
        }
    }
}
