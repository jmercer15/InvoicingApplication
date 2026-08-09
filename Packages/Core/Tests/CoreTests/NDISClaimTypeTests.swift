import Foundation
import Testing
@testable import Core

/// The NDIS billing engine (`Packages/Data/Sources/Data/Services/NDISBillingService*.swift`) emits
/// claim-type strings like "ProviderTravel_Labour" and "ActivityTransport" directly onto
/// `NDISClaimableLineItem.claimType`. Before these cases existed, `NDISClaimType(rawValue:)`
/// returned `nil` for every one of them and callers silently collapsed the result to `.direct`,
/// erasing the distinction between a support line and its travel/fee lines. These tests lock in
/// that every engine-emitted string now round-trips to a distinct case.
@Suite(.tags(.unit))
struct NDISClaimTypeTests {
    @Test func engineEmittedStringsNoLongerCollapseToDirect() {
        let engineEmittedRawValues = [
            "ProviderTravel_Labour",
            "ProviderTravel_NonLabour",
            "ProviderTravel_OtherCosts",
            "ActivityTransport",
            "EstablishmentFee",
            "CentreCapitalCost",
            "NightTimeSleepover",
            "ShadowShift",
            "TherapySupervision",
            "Subscription",
        ]

        for rawValue in engineEmittedRawValues {
            let claimType = NDISClaimType(rawValue: rawValue)
            #expect(claimType != nil, "Expected '\(rawValue)' to map to a claim type")
            #expect(claimType ?? .direct != .direct, "Engine claim type '\(rawValue)' must not collapse into .direct")
        }
    }

    @Test func newCasesRoundTripThroughRawValue() {
        for claimType in NDISClaimType.allCases {
            #expect(NDISClaimType(rawValue: claimType.rawValue) == claimType)
            #expect(!claimType.displayName.isEmpty)
        }
    }

    @Test func providerTravelVariantsShareCommonPrefix() {
        #expect(NDISClaimType.providerTravelLabour.rawValue.hasPrefix(NDISClaimType.providerTravel.rawValue))
        #expect(NDISClaimType.providerTravelNonLabour.rawValue.hasPrefix(NDISClaimType.providerTravel.rawValue))
        #expect(NDISClaimType.providerTravelOtherCosts.rawValue.hasPrefix(NDISClaimType.providerTravel.rawValue))
    }

    @Test func bPRClaimTypeCodesForEngineAndSpecialTypes() {
        #expect(NDISClaimType.providerTravelLabour.bprClaimTypeCode == .tran)
        #expect(NDISClaimType.activityTransport.bprClaimTypeCode == .tran)
        #expect(NDISClaimType.telehealth.bprClaimTypeCode == .thlt)
        #expect(NDISClaimType.nonFaceToFace.bprClaimTypeCode == .nf2f)
        #expect(NDISClaimType.cancellation.bprClaimTypeCode == .canc)
        #expect(NDISClaimType.ndiaReport.bprClaimTypeCode == .repw)
        #expect(NDISClaimType.irregularSILSupport.bprClaimTypeCode == .irss)

        #expect(NDISClaimType.direct.bprClaimTypeCode == nil)
        #expect(NDISClaimType.establishmentFee.bprClaimTypeCode == nil)
        #expect(NDISClaimType.nightTimeSleepover.bprClaimTypeCode == nil)
        #expect(NDISClaimType.shadowShift.bprClaimTypeCode == nil)
        #expect(NDISClaimType.centreCapitalCost.bprClaimTypeCode == nil)
        #expect(NDISClaimType.prepayment.bprClaimTypeCode == nil)

        #expect(NDISClaimType.bprClaimTypeCode(fromRaw: "ProviderTravel_Labour") == .tran)
        #expect(NDISClaimType.bprClaimTypeCode(fromRaw: "EstablishmentFee") == nil)    }
}
