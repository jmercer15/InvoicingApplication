import Testing
import CoreTesting
import SwiftData
import Core
import PersistenceModels
@testable import Data

/// `isEligibleForEstablishmentFee` used to treat a missing `consecutiveMonths` as `1`
/// (`context.service.consecutiveMonths ?? 1`), which silently made every direct-service claim
/// eligible for an establishment fee. It must now only fire when `consecutiveMonths` is
/// explicitly provided and eligible.
@MainActor
@Suite(.tags(.integration))
struct NDISEstablishmentFeeGatingTests {
    private func makeContext() throws -> (ModelContainer, ModelContext) {
        try ModelContainerFactory.makeInMemoryContext()
    }

    @MainActor
    private struct BillingHarness {
        let container: ModelContainer
        let context: ModelContext
        let configService: NDISBillingConfigService
        let billingService: NDISBillingService
        let integration: NDISBillingIntegrationService

        init(models: [any PersistentModel.Type]? = nil) throws {
            let (container, context): (ModelContainer, ModelContext)
            if let models {
                (container, context) = try ModelContainerFactory.makeInMemoryContext(models: models)
            } else {
                (container, context) = try ModelContainerFactory.makeInMemoryContext()
            }
            self.container = container
            self.context = context
            self.configService = NDISBillingConfigService(mmmZoneLookup: MMMZoneLookup())
            self.billingService = NDISBillingService(modelContext: context, configService: configService)
            self.integration = NDISBillingIntegrationService(
                modelContainer: container,
                geocodingService: SwiftDataGeocodingService(),
                mmmZoneLookup: MMMZoneLookup()
            )
        }
    }

    @Test func NotEligibleWhenConsecutiveMonthsIsNil() throws {
        let billingService = try BillingHarness().billingService
        let inputVector = makeInputVector(consecutiveMonths: nil)
        #expect(billingService.isEligibleForEstablishmentFee(inputVector) == false)
    }

    @Test func EligibleWhenConsecutiveMonthsIsExplicitlyOne() throws {
        let billingService = try BillingHarness().billingService
        let inputVector = makeInputVector(consecutiveMonths: 1)
        #expect(billingService.isEligibleForEstablishmentFee(inputVector))
    }

    @Test func NotEligibleAfterFirstConsecutiveMonth() throws {
        let billingService = try BillingHarness().billingService
        let inputVector = makeInputVector(consecutiveMonths: 2)
        #expect(billingService.isEligibleForEstablishmentFee(inputVector) == false)
    }

    @Test func NotEligibleWhenNotDirectServiceEvenIfFirstMonth() throws {
        let billingService = try BillingHarness().billingService
        let inputVector = makeInputVector(consecutiveMonths: 1, isDirectService: false)
        #expect(billingService.isEligibleForEstablishmentFee(inputVector) == false)
    }

    // MARK: - Helpers

    private func makeInputVector(consecutiveMonths: Int?, isDirectService: Bool = true) -> NDISBillingInputVector {
        let now = TestClock.now
        return NDISBillingInputVector(
            participant: NDISParticipantInfo(
                ndisNumber: "4300000001",
                planManagementType: "Plan-Managed",
                location: NDISLocation(postcode: "2000")
            ),
            provider: NDISProviderInfo(
                abn: "12345678901",
                location: NDISLocation(postcode: "2000"),
                foundAlternativeWork: false
            ),
            service: NDISServiceInfo(
                supportItemNumber: "01_010_0107_1_1",
                startTime: now,
                endTime: now.addingTimeInterval(3600),
                duration: 1,
                quantity: 1,
                date: now,
                consecutiveMonths: consecutiveMonths
            ),
            agreement: NDISAgreementInfo(agreedPrice: 100),
            context: NDISContextInfo(isDirectService: isDirectService)
        )
    }
}
