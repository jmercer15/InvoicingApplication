//
//  ClaimableLineSnapshot.swift
//  Core
//
//  Sendable value mirrors of SwiftData `@Model` types for cross-actor transfer.
//

import Foundation

// MARK: - ClaimableLineSnapshot

public struct ClaimableLineSnapshot: Sendable, Equatable, Hashable {
    public let id: UUID
    public let claimType: String
    public let supportItemNumber: String
    public let serviceFrom: Date
    public let serviceTo: Date
    public let quantity: Decimal?
    public let hoursHHHMM: String?
    public let unitPrice: Decimal
    public let gstCode: String
    public let cancellationReason: String?
    public let travelKM: Double?
    public let travelMinutes: Int32?
    public let metadata: Data?
    public let claimReference: String?
    public let draftId: UUID
    public let bulkClaimLineId: UUID?

    public init(
        id: UUID,
        claimType: String,
        supportItemNumber: String,
        serviceFrom: Date,
        serviceTo: Date,
        quantity: Decimal? = nil,
        hoursHHHMM: String? = nil,
        unitPrice: Decimal,
        gstCode: String,
        cancellationReason: String? = nil,
        travelKM: Double? = nil,
        travelMinutes: Int32? = nil,
        metadata: Data? = nil,
        claimReference: String? = nil,
        draftId: UUID,
        bulkClaimLineId: UUID? = nil
    ) {
        self.id = id
        self.claimType = claimType
        self.supportItemNumber = supportItemNumber
        self.serviceFrom = serviceFrom
        self.serviceTo = serviceTo
        self.quantity = quantity
        self.hoursHHHMM = hoursHHHMM
        self.unitPrice = unitPrice
        self.gstCode = gstCode
        self.cancellationReason = cancellationReason
        self.travelKM = travelKM
        self.travelMinutes = travelMinutes
        self.metadata = metadata
        self.claimReference = claimReference
        self.draftId = draftId
        self.bulkClaimLineId = bulkClaimLineId
    }

}
