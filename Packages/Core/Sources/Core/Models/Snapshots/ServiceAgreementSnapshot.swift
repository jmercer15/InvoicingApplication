//
//  ServiceAgreementSnapshot.swift
//  Core
//
//  Sendable value mirrors of SwiftData `@Model` types for cross-actor transfer.
//

import Foundation
import SwiftData

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

    public init(_ agreement: ServiceAgreement) {
        self.id = agreement.id
        self.effectiveFrom = agreement.effectiveFrom
        self.effectiveTo = agreement.effectiveTo
        self.pricingDisclosureAcceptedAt = agreement.pricingDisclosureAcceptedAt
        self.cancellationPolicyType = agreement.cancellationPolicyType
        self.allowsProviderTravel = agreement.allowsProviderTravel
        self.allowsTelehealth = agreement.allowsTelehealth
        self.allowsNonFaceToFace = agreement.allowsNonFaceToFace
        self.participantSignatoryName = agreement.participantSignatoryName
        self.participantSignatoryRole = agreement.participantSignatoryRole
        self.signedAt = agreement.signedAt
        self.signatureMethod = agreement.signatureMethod
        self.notes = agreement.notes
        self.isArchived = agreement.isArchived
        self.clientId = agreement.client?.id
    }
}

