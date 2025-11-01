import Foundation
import Core

extension ClientService {
    /// Convert from ClientServiceEntity to domain model
    init(from entity: ClientServiceEntity) {
        self.init(
            id: entity.id,
            clientId: entity.client?.id ?? UUID(),
            serviceName: entity.serviceName,
            rate: entity.rate,
            unit: entity.unit,
            status: entity.status,
            isActive: entity.isActive,
            startDate: entity.startDate,
            endDate: entity.endDate,
            ndisItemId: entity.ndisItem?.id,
            ndisCode: entity.ndisCode
        )
    }
}

extension NDISItem {
    /// Convert from NDISItemEntity to domain model
    init(from entity: NDISItemEntity) {
        self.init(
            id: entity.id,
            itemNumber: entity.itemNumber,
            name: entity.name,
            description: entity.itemDescription,
            category: entity.category,
            unit: entity.unit,
            price: Self.extractRepresentativePrice(from: entity.regionalPrices)
        )
    }
    
    /// Extract representative price from regional prices array
    /// Priority order: NATIONAL > NSW > VIC > QLD > WA > SA > TAS > ACT > NT > First available
    private static func extractRepresentativePrice(from regionalPrices: [RegionalPriceEntity]) -> Double? {
        guard !regionalPrices.isEmpty else { return nil }
        
        // Priority order for price selection
        let priorityRegions = ["NATIONAL", "NSW", "VIC", "QLD", "WA", "SA", "TAS", "ACT", "NT"]
        
        // Try to find price by priority order
        for region in priorityRegions {
            if let priceEntity = regionalPrices.first(where: { $0.regionIdentifier == region }), priceEntity.amount > 0 {
                return priceEntity.amount
            }
        }
        
        // If no priority regions found, try any other regions
        for priceEntity in regionalPrices {
            if priceEntity.amount > 0 {
                return priceEntity.amount
            }
        }
        
        return nil
    }
}

extension ClientServiceEntity {
    /// Update entity from domain model
    func update(from clientService: ClientService) {
        self.serviceName = clientService.serviceName
        self.rate = clientService.rate
        self.unit = clientService.unit
        self.status = clientService.status
        self.isActive = clientService.isActive
        self.startDate = clientService.startDate
        self.endDate = clientService.endDate
        self.ndisCode = clientService.ndisCode
    }
}
