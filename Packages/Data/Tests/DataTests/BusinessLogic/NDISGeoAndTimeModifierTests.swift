import Foundation
import Testing
import SwiftData
import Core
import PersistenceModels
@testable import Data

/// Phase 1.5: missing lat/lon → 1.0x geo (no throw); agreedPrice bill + ceiling;
/// time modifier uses therapist/DSW from context.
@MainActor
@Suite(.tags(.integration))
struct NDISGeoAndTimeModifierTests {
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

    // MARK: - Geo multiplier

    @Test func GeoMultiplierDefaultsToOneWithoutCoordinates() throws {
        let harness = try BillingHarness()
        let context = harness.context
        let billingService = harness.billingService
        let configService = harness.configService
        let integration = harness.integration
let location = NDISLocation(postcode: "0872", suburb: "Alice Springs", state: "NT")
        #expect(configService.getGeoMultiplier(for: location) == 1.0)
        #expect(configService.getMmmRating(for: location) == nil)
    }

    @Test func GeoMultiplierDefaultsToOneWithEmptyLocation() throws {
        let harness = try BillingHarness()
        let context = harness.context
        let billingService = harness.billingService
        let configService = harness.configService
        let integration = harness.integration
let location = NDISLocation(postcode: "")
        #expect(configService.getGeoMultiplier(for: location) == 1.0)
    }

    @Test func applyGeoModifierDoesNotThrowWithoutCoordinates() throws {
        let harness = try BillingHarness()
        let context = harness.context
        let billingService = harness.billingService
        let configService = harness.configService
        let integration = harness.integration
let inputVector = makeInputVector(
            agreedPrice: 50, latitude: nil,
            longitude: nil,
            providerType: TravelChargeProviderType.dsw.rawValue)
        let modified = try billingService.applyGeoModifier(100, inputVector)
        #expect(modified == 100)
    }

    @Test func applyGeoModifierUsesResolvedMetroCoordinatesAsOnePointZero() throws {
        let harness = try BillingHarness()
        let context = harness.context
        let billingService = harness.billingService
        let configService = harness.configService
        let integration = harness.integration
// Sydney CBD — metro MMM, multiplier 1.0 when lookup resolves.
        let inputVector = makeInputVector(
            agreedPrice: 50, latitude: -33.8688,
            longitude: 151.2093,
            providerType: TravelChargeProviderType.dsw.rawValue)
        let modified = try billingService.applyGeoModifier(100, inputVector)
        #expect(modified == 100)
    }

    // MARK: - Geo under-bill gate (A2)

    @Test func GeoBillingGateFailsWhenAddressPresentButMMMUnresolved() throws {
        let harness = try BillingHarness()
        let context = harness.context
        let billingService = harness.billingService
        let configService = harness.configService
        let integration = harness.integration
#expect(
            NDISBillingIntegrationService.geoBillingGate(hasAddressOrPostcode: true, mmmRating: nil) == .failUnresolvedWithAddress)
    }

    @Test func GeoBillingGateAllowsFallbackWhenNoAddress() throws {
        let harness = try BillingHarness()
        let context = harness.context
        let billingService = harness.billingService
        let configService = harness.configService
        let integration = harness.integration
#expect(NDISBillingIntegrationService.geoBillingGate(hasAddressOrPostcode: false, mmmRating: nil) == .proceedWithFallbackWarning)
    }

    @Test func GeoBillingGateProceedsWhenMMMResolved() throws {
        let harness = try BillingHarness()
        let context = harness.context
        let billingService = harness.billingService
        let configService = harness.configService
        let integration = harness.integration
#expect(NDISBillingIntegrationService.geoBillingGate(hasAddressOrPostcode: true, mmmRating: 2) == .proceed)
        #expect(NDISBillingIntegrationService.geoBillingGate(hasAddressOrPostcode: false, mmmRating: 6) == .proceed)
    }

    @Test func centreCapitalSoftSkipsWhenMMMUnresolved() throws {
        let harness = try BillingHarness()
        let context = harness.context
        let billingService = harness.billingService
        let configService = harness.configService
        let integration = harness.integration
let inputVector = makeInputVector(
            agreedPrice: 50,
            latitude: nil,
            longitude: nil,
            providerType: TravelChargeProviderType.dsw.rawValue
        )
        #expect(try billingService.calculateCentreCapitalCost(inputVector) == nil)
    }

    @Test func establishmentFeeSoftSkipsWhenMMMUnresolved() throws {
        let billingService = try BillingHarness().billingService
        let now = TestClock.now
        let inputVector = NDISBillingInputVector(
            participant: NDISParticipantInfo(
                ndisNumber: "4300000001",
                planManagementType: "Plan-Managed",
                location: NDISLocation(postcode: "")
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
                consecutiveMonths: 1
            ),
            agreement: NDISAgreementInfo(agreedPrice: 100),
            context: NDISContextInfo(isDirectService: true)
        )
        #expect(billingService.isEligibleForEstablishmentFee(inputVector))
        #expect(try billingService.calculateEstablishmentFee(inputVector) == nil)
    }

    @Test func establishmentFeeSoftSkipEmitsWarning() async throws {
        let harness = try BillingHarness()
        let billingService = harness.billingService
        let itemNumber = "01_010_0107_1_1"
        _ = try insertPricedItem(itemNumber: itemNumber, nationalPrice: 100, modelContext: harness.context)
        let day = weekday(atHour: 10)
        let inputVector = NDISBillingInputVector(
            participant: NDISParticipantInfo(
                ndisNumber: "4300000001",
                planManagementType: "Plan-Managed",
                location: NDISLocation(postcode: "")
            ),
            provider: NDISProviderInfo(
                abn: "12345678901",
                location: NDISLocation(postcode: "2000"),
                foundAlternativeWork: false
            ),
            service: NDISServiceInfo(
                supportItemNumber: itemNumber,
                startTime: day,
                endTime: day.addingTimeInterval(3600),
                duration: 1,
                quantity: 1,
                date: day,
                consecutiveMonths: 1
            ),
            agreement: NDISAgreementInfo(agreedPrice: 100),
            context: NDISContextInfo(isDirectService: true)
        )
        let result = try await billingService.calculateBillableAmountWithWarnings(context: inputVector)
        #expect(result.lines.contains(where: { $0.claimType == "EstablishmentFee" }) == false)
        #expect(result.warnings.contains(NDISBillingService.establishmentFeeSoftSkipWarning))
    }

    // MARK: - Time modifier / provider type

    @Test func TimeModifierDSWEveningAppliesLoading() throws {
        let harness = try BillingHarness()
        let context = harness.context
        let billingService = harness.billingService
        let configService = harness.configService
        let integration = harness.integration
let evening = weekday(atHour: 18)
        let modifier = configService.getTimeModifier(
            for: evening, providerType: TravelChargeProviderType.dsw.rawValue)
        #expect(modifier == 1.25)
    }

    @Test func TimeModifierTherapistEveningDoesNotApplyDSWLoading() throws {
        let harness = try BillingHarness()
        let context = harness.context
        let billingService = harness.billingService
        let configService = harness.configService
        let integration = harness.integration
let evening = weekday(atHour: 18)
        let modifier = configService.getTimeModifier(
            for: evening, providerType: TravelChargeProviderType.therapist.rawValue)
        #expect(modifier == 1.0)
    }

    @Test func applyTimeModifierUsesProviderTypeFromContext() throws {
        let harness = try BillingHarness()
        let context = harness.context
        let billingService = harness.billingService
        let configService = harness.configService
        let integration = harness.integration
let evening = weekday(atHour: 18)
        let end = evening.addingTimeInterval(3600)

        let dswContext = makeInputVector(
            agreedPrice: 50, latitude: nil,
            longitude: nil,
            providerType: TravelChargeProviderType.dsw.rawValue,
            start: evening,
            end: end)
        let therapistContext = makeInputVector(
            agreedPrice: 50,
            latitude: nil,
            longitude: nil,
            providerType: TravelChargeProviderType.therapist.rawValue,
            start: evening,
            end: end
        )

        let dswRate = try billingService.applyTimeModifier(100, dswContext)
        let therapistRate = try billingService.applyTimeModifier(100, therapistContext)

        #expect(dswRate == 125)
        #expect(therapistRate == 100)
    }

    // MARK: - Agreed price + ceiling

    @Test func agreedPriceCeilingStillThrowsWhenExceedsLimit() async throws {
        let harness = try BillingHarness()
        let context = harness.context
        let billingService = harness.billingService
        let configService = harness.configService
        let integration = harness.integration
let itemNumber = "15_001_0117_1_3"
        _ = try insertPricedItem(itemNumber: itemNumber, nationalPrice: 80, modelContext: harness.context)

        // Weekday daytime → time/geo modifiers 1.0 → finalRateLimit = 80.
        let day = weekday(atHour: 10)
        let inputVector = makeInputVector(
            agreedPrice: 100, latitude: nil,
            longitude: nil,
            providerType: TravelChargeProviderType.dsw.rawValue,
            start: day,
            end: day.addingTimeInterval(3600),
            supportItemNumber: itemNumber)

        do {
            _ = try await billingService.calculateBillableAmount(context: inputVector)
            Issue.record("Expected agreedPriceExceedsLimit")
        } catch NDISBillingError.agreedPriceExceedsLimit {
            // expected
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func agreedPriceBillsWhenWithinLimitWithoutCoordinates() async throws {
        let harness = try BillingHarness()
        let context = harness.context
        let billingService = harness.billingService
        let configService = harness.configService
        let integration = harness.integration
let itemNumber = "15_002_0117_1_3"
        _ = try insertPricedItem(itemNumber: itemNumber, nationalPrice: 100, modelContext: harness.context)

        let day = weekday(atHour: 10)
        let agreed: Double = 90
        let inputVector = makeInputVector(
            agreedPrice: agreed,
            latitude: nil,
            longitude: nil,
            providerType: TravelChargeProviderType.dsw.rawValue,
            start: day,
            end: day.addingTimeInterval(3600),
            supportItemNumber: itemNumber
        )

        let lines = try await billingService.calculateBillableAmount(context: inputVector)
        guard let primary = lines.first(where: { $0.claimType == "Direct" || $0.claimType == "Telehealth" })
            ?? lines.first else {
            Issue.record("Expected at least one claim line")
            return
        }
        #expect(primary.unitPrice == Decimal(agreed))
    }

    // MARK: - Helpers

    private func insertPricedItem(
        itemNumber: String,
        nationalPrice: Double,
        modelContext: ModelContext
    ) throws -> NDISItem {
        let entity = NDISItem(id: UUID())
        entity.itemNumber = itemNumber
        entity.name = "Test \(itemNumber)"
        entity.itemDescription = "Test"
        entity.category = "Test"
        entity.unit = "H"
        entity.isCurrent = true
        entity.status = "Active"
        entity.quoteRequired = false

        let price = RegionalPrice(id: UUID())
        price.regionIdentifier = "National"
        price.amount = Decimal(nationalPrice)
        price.ndisItem = entity
        modelContext.insert(price)
        modelContext.insert(entity)
        try modelContext.save()
        return entity
    }

    private func weekday(atHour hour: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Australia/Sydney") ?? .current
        // 2024-07-03 was a Wednesday (non-holiday).
        var components = DateComponents()
        components.year = 2024
        components.month = 7
        components.day = 3
        components.hour = hour
        components.minute = 0
        return calendar.date(from: components)!
    }

    private func makeInputVector(
        agreedPrice: Double,
        latitude: Double?,
        longitude: Double?,
        providerType: String,
        start: Date = TestClock.now,
        end: Date = TestClock.addingTimeInterval(3600),
        supportItemNumber: String = "01_001_0107_1_1"
    ) -> NDISBillingInputVector {
        let duration = end.timeIntervalSince(start) / 3600
        return NDISBillingInputVector(
            participant: NDISParticipantInfo(
                ndisNumber: "4300000001",
                planManagementType: "Plan-Managed",
                location: NDISLocation(
                    postcode: "2000",
                    latitude: latitude,
                    longitude: longitude
                )
            ),
            provider: NDISProviderInfo(
                abn: "12345678901",
                location: NDISLocation(postcode: "2000"),
                foundAlternativeWork: false
            ),
            service: NDISServiceInfo(
                supportItemNumber: supportItemNumber,
                startTime: start,
                endTime: end,
                duration: max(duration, 0),
                quantity: max(duration, 0),
                date: start
            ),
            agreement: NDISAgreementInfo(agreedPrice: agreedPrice),
            context: NDISContextInfo(
                isDirectService: true,
                providerType: providerType
            )
        )
    }
}
