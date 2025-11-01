import Foundation

/// Use case for creating a new travel charge
public struct CreateTravelCharge: Sendable {
    private let repository: TravelChargeRepository
    
    public init(repository: TravelChargeRepository) {
        self.repository = repository
    }
    
    /// Create a new travel charge
    public func callAsFunction(
        sessionId: UUID,
        amount: Double,
        distance: Double? = nil,
        travelTime: TimeInterval? = nil,
        fromAddress: String? = nil,
        toAddress: String? = nil,
        notes: String? = nil
    ) async throws -> TravelCharge {
        let travelCharge = TravelCharge(
            id: UUID(),
            sessionId: sessionId,
            amount: amount,
            distance: distance,
            travelTime: travelTime,
            fromAddress: fromAddress,
            toAddress: toAddress,
            status: .pending,
            createdDate: Date(),
            lastModifiedDate: Date(),
            notes: notes
        )
        
        return try await repository.create(travelCharge)
    }
}
