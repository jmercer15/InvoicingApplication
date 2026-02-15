import Foundation
import Core

/// Maps between the `TravelCharge` domain model and `TravelChargeEntity` persistence model.
public struct TravelChargeMapper: ModelMapper {
    public typealias DomainModel = TravelCharge
    public typealias PersistenceEntity = TravelChargeEntity
    
    public init() {}
    
    public func mapToDomain(_ entity: TravelChargeEntity) -> TravelCharge {
        let participantCount = max(Int(entity.participantCount ?? 1), 1)
        let shouldSplit = entity.splitCosts ?? false
        let effectiveParticipants = shouldSplit ? participantCount : 1
        let parking = entity.parkingCost ?? 0
        let tolls = entity.tollCost ?? 0
        let chargeType = entity.chargeType?.rawValue ?? "standard"
        let distance = entity.travelDistance ?? 0
        let duration = entity.travelDuration ?? 0
        let mmmZoneName = entity.mmmZoneName
        let baseRate = entity.service?.rate ?? 0
        let providerType = NDISTravelChargeCalculator.inferredProviderType(
            itemName: entity.service?.serviceName,
            itemDescription: entity.service?.ndisItem?.itemDescription,
            ndisCode: entity.service?.ndisCode
        )

        let breakdown = NDISTravelChargeCalculator.calculate(
            providerType: providerType,
            hourlyRate: baseRate,
            mmmZoneDescriptor: mmmZoneName,
            minutesTravelled: duration,
            kilometresTravelled: distance,
            ancillaryCosts: parking + tolls,
            participantCount: effectiveParticipants
        )

        let fallbackAmount: Double
        switch chargeType.lowercased() {
        case "labour":
            fallbackAmount = breakdown.labourPerParticipant
        case "non-labour":
            fallbackAmount = breakdown.nonLabourPerParticipant
        case "activity-based":
            fallbackAmount = breakdown.totalPerParticipant
        default:
            fallbackAmount = breakdown.totalPerParticipant
        }
        let amount = entity.calculatedAmount ?? fallbackAmount
        let status = Self.status(from: entity.notes)
        let parsedAddresses = Self.parseLocation(entity.location)
        
        return TravelCharge(
            id: entity.id,
            sessionId: entity.linkedSession?.id ?? UUID(),
            clientId: entity.client?.id ?? UUID(), // Should always be linked
            serviceId: entity.service?.id,
            amount: amount,
            distance: entity.travelDistance,
            travelTime: entity.travelDuration,
            fromAddress: parsedAddresses.from,
            toAddress: parsedAddresses.to,
            status: status,
            chargeType: chargeType,
            travelDirection: entity.travelDirection?.rawValue ?? "to_client",
            vehicleType: entity.vehicleType?.rawValue,
            participantCount: participantCount,
            splitCosts: shouldSplit,
            parkingCost: parking,
            tollCost: tolls,
            createdDate: entity.startTime ?? Date(),
            lastModifiedDate: entity.lastModifiedDate,
            notes: entity.notes
        )
    }
    
    public func mapToEntity(_ domain: TravelCharge) -> TravelChargeEntity {
        let entity = TravelChargeEntity(id: domain.id)
        updateEntityProperties(entity, from: domain)
        return entity
    }
    
    public func updateEntity(_ entity: inout TravelChargeEntity, from domain: TravelCharge) {
        updateEntityProperties(entity, from: domain)
    }
    
    private func updateEntityProperties(_ entity: TravelChargeEntity, from domain: TravelCharge) {
        entity.travelDistance = domain.distance
        entity.travelDuration = domain.travelTime
        entity.calculatedAmount = domain.amount
        entity.location = Self.composeLocation(from: domain.fromAddress, to: domain.toAddress)
        entity.notes = domain.notes
        entity.startTime = domain.createdDate
        entity.lastModifiedDate = domain.lastModifiedDate
        
        // Extended attributes
        entity.chargeType = Self.chargeType(for: domain.chargeType)
        entity.travelDirection = Self.travelDirection(for: domain.travelDirection)
        entity.vehicleType = domain.vehicleType.flatMap { VehicleType(rawValue: $0) }
        entity.participantCount = Int16(domain.participantCount)
        entity.splitCosts = domain.splitCosts
        entity.parkingCost = domain.parkingCost
        entity.tollCost = domain.tollCost
        
        // Note: LinkedSession, Client, and Service relationships are handled separately via repository
    }

    private static func parseLocation(_ location: String?) -> (from: String?, to: String?) {
        guard let location, !location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return (nil, nil)
        }

        let separators = [" to ", " -> ", " → "]
        for separator in separators {
            if location.contains(separator) {
                let parts = location.components(separatedBy: separator)
                if parts.count >= 2 {
                    let from = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                    let to = parts[1...].joined(separator: separator).trimmingCharacters(in: .whitespacesAndNewlines)
                    return (
                        from.isEmpty ? nil : from,
                        to.isEmpty ? nil : to
                    )
                }
            }
        }

        return (location, nil)
    }

    private static func composeLocation(from: String?, to: String?) -> String? {
        let fromValue = from?.trimmingCharacters(in: .whitespacesAndNewlines)
        let toValue = to?.trimmingCharacters(in: .whitespacesAndNewlines)

        switch (fromValue?.isEmpty == false ? fromValue : nil, toValue?.isEmpty == false ? toValue : nil) {
        case let (from?, to?):
            return "\(from) to \(to)"
        case let (from?, nil):
            return from
        case let (nil, to?):
            return to
        case (nil, nil):
            return nil
        }
    }

    private static func chargeType(for rawValue: String) -> TravelChargeType {
        if let exact = TravelChargeType(rawValue: rawValue) {
            return exact
        }

        switch rawValue.lowercased() {
        case "labour", "labor":
            return .labour
        case "non-labour", "nonlabor", "non_labour":
            return .nonLabour
        case "activity-based", "activity_based":
            return .activityBased
        default:
            return .standard
        }
    }

    private static func travelDirection(for rawValue: String) -> TravelChargeDirection {
        if let exact = TravelChargeDirection(rawValue: rawValue) {
            return exact
        }

        switch rawValue.lowercased() {
        case "before":
            return .before
        case "after":
            return .after
        case "to client", "to_client":
            return .toClient
        case "from client", "from_client":
            return .fromClient
        default:
            return .toClient
        }
    }

    private static func status(from notes: String?) -> TravelChargeStatus {
        guard let notes = notes?.lowercased() else {
            return .pending
        }

        if notes.contains("status: approved") {
            return .approved
        }
        if notes.contains("status: rejected") {
            return .rejected
        }
        if notes.contains("status: paid") {
            return .paid
        }
        return .pending
    }
}
