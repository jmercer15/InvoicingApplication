//
//  ServiceAgreementSnapshot.swift
//  Core
//
//  Sendable value mirrors of SwiftData `@Model` types for cross-actor transfer.
//

import Foundation

// MARK: - ServiceAgreementSnapshot

public struct ServiceAgreementSnapshot: Sendable, Equatable, Hashable {
    public let id: UUID
    public let effectiveFrom: Date
    public let effectiveTo: Date?
    public let pricingDisclosureAcceptedAt: Date?
    public let cancellationPolicyType: String
    public let allowsProviderTravel: Bool
    public let allowsTelehealth: Bool
    public let allowsNonFaceToFace: Bool
    public let participantSignatoryName: String?
    public let participantSignatoryRole: String?
    public let signedAt: Date?
    public let signatureMethod: String?
    public let notes: String?
    public let isArchived: Bool
    public let clientId: UUID?


    public init(
        id: UUID,
        effectiveFrom: Date,
        effectiveTo: Date?,
        pricingDisclosureAcceptedAt: Date?,
        cancellationPolicyType: String,
        allowsProviderTravel: Bool,
        allowsTelehealth: Bool,
        allowsNonFaceToFace: Bool,
        participantSignatoryName: String?,
        participantSignatoryRole: String?,
        signedAt: Date?,
        signatureMethod: String?,
        notes: String?,
        isArchived: Bool,
        clientId: UUID?
    ) {
        self.id = id
        self.effectiveFrom = effectiveFrom
        self.effectiveTo = effectiveTo
        self.pricingDisclosureAcceptedAt = pricingDisclosureAcceptedAt
        self.cancellationPolicyType = cancellationPolicyType
        self.allowsProviderTravel = allowsProviderTravel
        self.allowsTelehealth = allowsTelehealth
        self.allowsNonFaceToFace = allowsNonFaceToFace
        self.participantSignatoryName = participantSignatoryName
        self.participantSignatoryRole = participantSignatoryRole
        self.signedAt = signedAt
        self.signatureMethod = signatureMethod
        self.notes = notes
        self.isArchived = isArchived
        self.clientId = clientId
    }

}
