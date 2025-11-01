import Foundation

/// Use case for fetching travel charges with various filters
public struct FetchTravelCharges: Sendable {
    private let repository: TravelChargeRepository
    
    public init(repository: TravelChargeRepository) {
        self.repository = repository
    }
    
    /// Fetch all travel charges
    public func callAsFunction() async throws -> [TravelCharge] {
        return try await repository.fetchAll()
    }
    
    /// Fetch travel charges by session ID
    public func callAsFunction(bySessionId sessionId: UUID) async throws -> [TravelCharge] {
        return try await repository.fetchBySessionId(sessionId)
    }
    
    /// Fetch travel charges by client ID
    public func callAsFunction(byClientId clientId: UUID) async throws -> [TravelCharge] {
        return try await repository.fetchByClientId(clientId)
    }
    
    /// Fetch travel charges by status
    public func callAsFunction(byStatus status: TravelChargeStatus) async throws -> [TravelCharge] {
        return try await repository.fetchByStatus(status)
    }
    
    /// Fetch a single travel charge by ID
    public func callAsFunction(byId id: UUID) async throws -> TravelCharge? {
        return try await repository.fetchById(id)
    }
    
    /// Fetch travel charges by date range
    public func callAsFunction(from startDate: Date, to endDate: Date) async throws -> [TravelCharge] {
        return try await repository.fetch(from: startDate, to: endDate)
    }
    
    /// Fetch travel charges requiring review
    public func callAsFunction(requiringReview: Bool) async throws -> [TravelCharge] {
        guard requiringReview else {
            return try await repository.fetchAll()
        }
        return try await repository.fetchRequiringReview()
    }
    
    /// Search travel charges by query
    public func callAsFunction(search query: String) async throws -> [TravelCharge] {
        return try await repository.search(query: query)
    }
    
    /// Fetch travel charges with pagination
    public func callAsFunction(limit: Int, offset: Int) async throws -> [TravelCharge] {
        return try await repository.fetch(limit: limit, offset: offset)
    }
    
    /// Count total travel charges
    public func callAsFunction(count: Bool) async throws -> Int {
        return try await repository.count()
    }
    
    /// Count travel charges by status
    public func callAsFunction(countByStatus status: TravelChargeStatus) async throws -> Int {
        return try await repository.count(by: status)
    }
    
    /// Fetch travel charges with multiple filters
    public func callAsFunction(
        sessionId: UUID? = nil,
        clientId: UUID? = nil,
        status: TravelChargeStatus? = nil,
        from startDate: Date? = nil,
        to endDate: Date? = nil,
        requiringReview: Bool = false,
        limit: Int? = nil,
        offset: Int = 0
    ) async throws -> [TravelCharge] {
        var results: [TravelCharge] = []
        
        // Apply filters in order of specificity
        if let sessionId = sessionId {
            results = try await repository.fetchBySessionId(sessionId)
        } else if let clientId = clientId {
            results = try await repository.fetchByClientId(clientId)
        } else if requiringReview {
            results = try await repository.fetchRequiringReview()
        } else {
            results = try await repository.fetchAll()
        }
        
        // Apply additional filters
        if let status = status {
            results = results.filter { $0.status == status }
        }
        
        if let startDate = startDate, let endDate = endDate {
            results = results.filter { travelCharge in
                travelCharge.createdDate >= startDate && travelCharge.createdDate <= endDate
            }
        }
        
        // Apply pagination
        if let limit = limit {
            let startIndex = offset
            let endIndex = min(startIndex + limit, results.count)
            if startIndex < results.count {
                results = Array(results[startIndex..<endIndex])
            } else {
                results = []
            }
        }
        
        return results
    }
}
