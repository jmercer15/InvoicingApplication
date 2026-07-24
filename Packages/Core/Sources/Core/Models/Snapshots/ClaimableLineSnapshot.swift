//
//  ClaimableLineSnapshot.swift
//  Core
//
//  Sendable value mirrors of SwiftData `@Model` types for cross-actor transfer.
//

import Foundation
import SwiftData

// MARK: - ClaimableLineSnapshot

public struct ClaimableLineSnapshot: Sendable, Equatable, Hashable {
    public let id: UUID
    public let claimType: String
    public let supportItemNumber: String
    public let serviceFrom: Date
    public let serviceTo: Date
    public let quantityDecimal: Double?
    public let hoursHHHMM: String?
    public let unitPrice: Double
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
        quantityDecimal: Double? = nil,
        hoursHHHMM: String? = nil,
        unitPrice: Double,
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
        self.quantityDecimal = quantityDecimal
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

    public init(_ line: ClaimableLine) {
        self.id = line.id
        self.claimType = line.claimType
        self.supportItemNumber = line.supportItemNumber
        self.serviceFrom = line.serviceFrom
        self.serviceTo = line.serviceTo
        self.quantityDecimal = line.quantityDecimal
        self.hoursHHHMM = line.hoursHHHMM
        self.unitPrice = line.unitPrice
        self.gstCode = line.gstCode
        self.cancellationReason = line.cancellationReason
        self.travelKM = line.travelKM
        self.travelMinutes = line.travelMinutes
        self.metadata = line.metadata
        self.claimReference = line.claimReference
        self.draftId = line.draftId
        self.bulkClaimLineId = line.bulkClaimLine?.id
    }
}

