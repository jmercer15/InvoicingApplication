import Foundation
import Testing
import SwiftData
import Core
import PersistenceModels
@testable import Data

/// A3: ActivityTransport XOR provider travel; prefer chargeAmount; vehicleType → isModifiedVehicle.
@MainActor
@Suite(.tags(.integration))
struct NDISActivityTravelTests {
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

    @Test func activityTransportPreferredChargeAmountHonored() throws {
        let harness = try BillingHarness()
        let context = harness.context
        let billingService = harness.billingService
        let configService = harness.configService
        let integration = harness.integration
        let travelInput = makeTravelInput(
            isActivityTransport: true,
            isProviderTravel: false,
            kilometres: 40,
            preferredChargeAmount: 17.5,
            isModifiedVehicle: false
        )
        let claim = try #require(try billingService.calculateActivityTransport(travelInput))
        #expect(claim.claimType == "ActivityTransport")
        #expect(claim.unitPrice == Decimal(string: "17.5")!)
        // Preferred amount must win over km recomputation (40 km × standard rate ≫ 17.5).
        let recomputed = try #require(
            try billingService.calculateActivityTransport(
                makeTravelInput(
                    isActivityTransport: true, isProviderTravel: false,
                    kilometres: 40,
                    preferredChargeAmount: nil,
                    isModifiedVehicle: false)
            )
        )
        #expect(recomputed.unitPrice > Decimal(string: "17.5")!)
    }

    @Test func modifiedVehicleUsesHigherTransportRateWhenRecomputing() throws {
        let harness = try BillingHarness()
        let context = harness.context
        let billingService = harness.billingService
        let configService = harness.configService
        let integration = harness.integration
let standard = try #require(
            try billingService.calculateActivityTransport(
                makeTravelInput(
                    isActivityTransport: true, isProviderTravel: false,
                    kilometres: 10,
                    preferredChargeAmount: nil,
                    isModifiedVehicle: false)
            )
        )
        let modified = try #require(
            try billingService.calculateActivityTransport(
                makeTravelInput(
                    isActivityTransport: true,
                    isProviderTravel: false,
                    kilometres: 10,
                    preferredChargeAmount: nil,
                    isModifiedVehicle: true
                )
            )
        )
        #expect(modified.unitPrice > standard.unitPrice)
    }

    @Test func IsModifiedVehicleMapsModifiedBusOnly() throws {
        let harness = try BillingHarness()
        let context = harness.context
        let billingService = harness.billingService
        let configService = harness.configService
        let integration = harness.integration
#expect(NDISBillingIntegrationService.isModifiedVehicle(.modifiedBus))
        #expect(NDISBillingIntegrationService.isModifiedVehicle(.standardCar) == false)
        #expect(NDISBillingIntegrationService.isModifiedVehicle(.car) == false)
        #expect(NDISBillingIntegrationService.isModifiedVehicle(nil) == false)
    }

    @Test func resolveBillingContextActivityChargeXORsProviderTravel() async throws {
        let harness = try BillingHarness()
        let context = harness.context
        let billingService = harness.billingService
        let configService = harness.configService
        let integration = harness.integration
        let modelContext = harness.context
        let client = Client(id: UUID(), ndisNumber: "4300000001", fullName: "Jamie", status: .active)
        let session = Session(id: UUID())
        session.title = "Activity"
        session.client = client
        session.startTime = TestClock.now
        session.endTime = TestClock.addingTimeInterval(3600)
        modelContext.insert(client)
        modelContext.insert(session)

        let charge = TravelCharge(
            id: UUID(), chargeAmount: 22.0,
            distanceKM: 8,
            durationMinutes: 15,
            chargeType: .activityBased,
            vehicleType: .modifiedBus,
            parkingCost: 1,
            tollCost: 2)
        charge.linkedSession = session
        modelContext.insert(charge)
        try modelContext.save()

        let billingContext = await integration.resolveBillingContext(forSessionId: session.id)

        #expect(billingContext.isActivityTransport)
        #expect(billingContext.isProviderTravel == false)
        #expect(billingContext.activityTransportChargeAmount == 22.0)
        #expect(billingContext.isModifiedVehicle)
        #expect(billingContext.travelDistance == 8)
    }

    @Test func resolveBillingContextProviderTravelWhenNotActivity() async throws {
        let harness = try BillingHarness()
        let context = harness.context
        let billingService = harness.billingService
        let configService = harness.configService
        let integration = harness.integration
        let modelContext = harness.context
        let client = Client(id: UUID(), ndisNumber: "4300000001", fullName: "Jamie", status: .active)
        let session = Session(id: UUID())
        session.title = "Provider travel"
        session.client = client
        session.startTime = TestClock.now
        session.endTime = TestClock.addingTimeInterval(3600)
        modelContext.insert(client)
        modelContext.insert(session)

        let charge = TravelCharge(
            id: UUID(), distanceKM: 12,
            durationMinutes: 20,
            chargeType: .labour,
            vehicleType: .standardCar,
            parkingCost: 0,
            tollCost: 0)
        charge.linkedSession = session
        modelContext.insert(charge)
        try modelContext.save()

        let billingContext = await integration.resolveBillingContext(forSessionId: session.id)

        #expect(billingContext.isProviderTravel)
        #expect(billingContext.isActivityTransport == false)
        #expect(billingContext.activityTransportChargeAmount == nil)
        #expect(billingContext.isModifiedVehicle == false)
    }

    /// Labour TravelCharges win XOR even when orchestrator would flag activity transport.
    @Test func labourChargesIgnoreOrchestratorActivityFlag() async throws {
        let harness = try BillingHarness()
        let context = harness.context
        let billingService = harness.billingService
        let configService = harness.configService
        let integration = harness.integration
        let modelContext = harness.context
        let client = Client(id: UUID(), ndisNumber: "4300000001", fullName: "Jamie", status: .active)
        let item = try insertTransportEligibleItem(in: modelContext, itemNumber: "02_590_0107_1_1", nationalPrice: 100)
        let service = ClientService(id: UUID(), serviceName: "Community Access Transport", unit: "H", rate: 90)
        service.ndisCode = item.itemNumber
        service.ndisItem = item
        service.client = client
        let session = Session(id: UUID())
        session.title = "Labour XOR"
        session.client = client
        session.clientService = service
        session.startTime = TestClock.now
        session.endTime = TestClock.addingTimeInterval(3600)
        modelContext.insert(client)
        modelContext.insert(service)
        modelContext.insert(session)

        let charge = TravelCharge(
            id: UUID(), chargeAmount: 33.0,
            distanceKM: 0,
            durationMinutes: 30,
            chargeType: .labour,
            vehicleType: .standardCar,
            parkingCost: 0,
            tollCost: 0)
        charge.linkedSession = session
        modelContext.insert(charge)
        try modelContext.save()

        let billingContext = await integration.resolveBillingContext(forSessionId: session.id)

        #expect(billingContext.isProviderTravel)
        #expect(billingContext.isActivityTransport == false)
        #expect(billingContext.providerTravelLabourChargeAmount == 33.0)
        #expect(billingContext.activityTransportChargeAmount == nil)
    }

    @Test func providerTravelHonorsLabourChargeAmount() throws {
        let harness = try BillingHarness()
        let billingService = harness.billingService
        let modelContext = harness.context
        let itemNumber = "15_005_0117_1_3"
        _ = try insertTransportEligibleItem(in: modelContext, itemNumber: itemNumber, nationalPrice: 100)
        let travelInput = makeTravelInput(
            isActivityTransport: false, isProviderTravel: true,
            kilometres: 0,
            preferredChargeAmount: nil,
            isModifiedVehicle: false,
            timeTo: 30,
            preferredLabourChargeAmount: 19.5,
            preferredNonLabourChargeAmount: nil)
        let item = try supportItemSnapshot(in: modelContext, itemNumber: itemNumber)
        let claims = try billingService.calculateProviderTravel(travelInput, 100, item)
        let labour = try #require(claims.first(where: { $0.claimType == "ProviderTravel_Labour" }))
        #expect(labour.unitPrice == Decimal(string: "19.5")!)
        #expect(labour.quantity == 1)
        #expect(claims.count == 1)
    }

    @Test func providerTravelHonorsNonLabourChargeAmount() throws {
        let harness = try BillingHarness()
        let billingService = harness.billingService
        let modelContext = harness.context
        let itemNumber = "15_006_0117_1_3"
        _ = try insertTransportEligibleItem(in: modelContext, itemNumber: itemNumber, nationalPrice: 100)
        let travelInput = makeTravelInput(
            isActivityTransport: false, isProviderTravel: true,
            kilometres: 40,
            preferredChargeAmount: nil,
            isModifiedVehicle: false,
            timeTo: 0,
            preferredLabourChargeAmount: nil,
            preferredNonLabourChargeAmount: 27.0)
        let item = try supportItemSnapshot(in: modelContext, itemNumber: itemNumber)
        let claims = try billingService.calculateProviderTravel(travelInput, 100, item)
        let nonLabour = try #require(claims.first(where: { $0.claimType == "ProviderTravel_NonLabour" }))
        #expect(nonLabour.unitPrice == Decimal(string: "27")!)
        #expect(nonLabour.quantity == 1)
    }

    @Test func KmRatesMatchCalculator() throws {
        let harness = try BillingHarness()
        let context = harness.context
        let billingService = harness.billingService
        let configService = harness.configService
        let integration = harness.integration
#expect(abs(configService.getTravelRatePerKm() - NDISTravelChargeCalculator.vehicleRatePerKilometre) < 0.0001)
        #expect(abs(configService.getTransportRate(isModified: false) - NDISTravelChargeCalculator.vehicleRatePerKilometre) < 0.0001)
        #expect(abs(configService.getTransportRate(isModified: true) - NDISTravelChargeCalculator.modifiedVehicleRatePerKilometre) < 0.0001)
        #expect(NDISTravelChargeCalculator.vehicleRatePerKilometre == 0.99)
        #expect(NDISTravelChargeCalculator.modifiedVehicleRatePerKilometre == 2.76)
    }

    @Test func activityRecomputeUsesCalculatorRates() throws {
        let harness = try BillingHarness()
        let context = harness.context
        let billingService = harness.billingService
        let configService = harness.configService
        let integration = harness.integration
let standard = try #require(
            try billingService.calculateActivityTransport(
                makeTravelInput(
                    isActivityTransport: true, isProviderTravel: false,
                    kilometres: 10,
                    preferredChargeAmount: nil,
                    isModifiedVehicle: false)
            )
        )
        #expect(abs(standard.unitPrice - Decimal(10 * NDISTravelChargeCalculator.vehicleRatePerKilometre)) < Decimal(string: "0.0001")!)
        let modified = try #require(
            try billingService.calculateActivityTransport(
                makeTravelInput(
                    isActivityTransport: true,
                    isProviderTravel: false,
                    kilometres: 10,
                    preferredChargeAmount: nil,
                    isModifiedVehicle: true
                )
            )
        )
        #expect(abs(modified.unitPrice - Decimal(10 * NDISTravelChargeCalculator.modifiedVehicleRatePerKilometre)) < Decimal(string: "0.0001")!)
    }

    @Test func providerTravelIneligibleWithMoneyThrows() async throws {
        let harness = try BillingHarness()
        let context = harness.context
        let billingService = harness.billingService
        let configService = harness.configService
        let integration = harness.integration
        let modelContext = harness.context
        let itemNumber = "01_099_0107_1_1"
        let entity = NDISItem(id: UUID())
        entity.itemNumber = itemNumber
        entity.name = "Daily Living"
        entity.itemDescription = "assistance"
        entity.category = "Daily Living"
        entity.unit = "H"
        entity.isCurrent = true
        entity.status = "Active"
        entity.quoteRequired = false
        entity.providerTravel = false
        let price = RegionalPrice(id: UUID())
        price.regionIdentifier = "National"
        price.amount = 100
        price.ndisItem = entity
        modelContext.insert(price)
        modelContext.insert(entity)
        try modelContext.save()

        let day = weekday(atHour: 10)
        let billingInput = makeTravelInput(
            isActivityTransport: false,
            isProviderTravel: true,
            kilometres: 0,
            preferredChargeAmount: nil,
            isModifiedVehicle: false,
            timeTo: 20,
            preferredLabourChargeAmount: 15,
            supportItemNumber: itemNumber,
            serviceStart: day,
            serviceEnd: day.addingTimeInterval(3600),
            agreedPrice: 90
        )

        do {
            _ = try await billingService.calculateBillableAmount(context: billingInput)
            Issue.record("Expected travelNotEligible")
        } catch NDISBillingError.travelNotEligible(let reason) {
            #expect(reason.contains("not eligible"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func billingServiceNeverEmitsBothTravelSchedules() async throws {
        let harness = try BillingHarness()
        let billingService = harness.billingService
        let itemNumber = "02_590_0107_1_1"
        _ = try insertTransportEligibleItem(in: harness.context, itemNumber: itemNumber, nationalPrice: 100)

        let day = weekday(atHour: 10)
        // Orchestrator can flag both travel modes; billing must emit activity transport only.
        let billingInput = makeTravelInput(
            isActivityTransport: true,
            isProviderTravel: true,
            kilometres: 40,
            preferredChargeAmount: 12.5,
            isModifiedVehicle: false,
            timeTo: 30,
            preferredLabourChargeAmount: 19.5,
            supportItemNumber: itemNumber,
            serviceStart: day,
            serviceEnd: day.addingTimeInterval(3600),
            agreedPrice: 90
        )

        let lines = try await billingService.calculateBillableAmount(context: billingInput)
        let travelTypes = lines.map(\.claimType).filter {
            $0.hasPrefix("ProviderTravel") || $0 == "ActivityTransport"
        }
        #expect(travelTypes == ["ActivityTransport"])
        let activityLine = try #require(lines.first(where: { $0.claimType == "ActivityTransport" }))
        #expect(activityLine.unitPrice == Decimal(string: "12.5")!)
    }

    @Test func selfManagedIncludesActivityTravelWithClaimType() async throws {
        let harness = try BillingHarness()
        let billingService = harness.billingService
        let itemNumber = "02_590_0107_1_1"
        _ = try insertTransportEligibleItem(in: harness.context, itemNumber: itemNumber, nationalPrice: 100)

        let day = weekday(atHour: 10)
        let billingInput = makeTravelInput(
            isActivityTransport: true,
            isProviderTravel: false,
            kilometres: 0,
            preferredChargeAmount: 18.25,
            isModifiedVehicle: false,
            supportItemNumber: itemNumber,
            planManagementType: "Self-Managed",
            serviceStart: day,
            serviceEnd: day.addingTimeInterval(3600),
            agreedPrice: 75
        )

        let lines = try await billingService.calculateBillableAmount(context: billingInput)
        #expect(lines.count == 2)
        #expect(lines.first?.claimType == "Direct")
        let travel = try #require(lines.first(where: { $0.claimType == "ActivityTransport" }))
        #expect(travel.unitPrice == Decimal(string: "18.25")!)
        #expect(
            NDISBillingIntegrationService.selfManagedTravelInvoiceOnlyWarning == "Self-managed: travel included on invoice only"
        )
    }

    // MARK: - Helpers

    private func insertTransportEligibleItem(in modelContext: ModelContext, itemNumber: String, nationalPrice: Double) throws -> NDISItem {
        let entity = NDISItem(id: UUID())
        entity.itemNumber = itemNumber
        entity.name = "Community Access Transport"
        entity.itemDescription = "activity based transport"
        entity.category = "Transport"
        entity.unit = "H"
        entity.isCurrent = true
        entity.status = "Active"
        entity.quoteRequired = false
        entity.providerTravel = true

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
        var components = DateComponents()
        components.year = 2024
        components.month = 7
        components.day = 3
        components.hour = hour
        components.minute = 0
        return calendar.date(from: components)!
    }

    private func makeTravelInput(
        isActivityTransport: Bool,
        isProviderTravel: Bool,
        kilometres: Double,
        preferredChargeAmount: Double?,
        isModifiedVehicle: Bool,
        timeTo: Double = 0,
        preferredLabourChargeAmount: Double? = nil,
        preferredNonLabourChargeAmount: Double? = nil,
        supportItemNumber: String = "02_001_0107_1_1",
        planManagementType: String = "Plan-Managed",
        serviceStart: Date? = nil,
        serviceEnd: Date? = nil,
        agreedPrice: Double = 50
    ) -> NDISBillingInputVector {
        let start = serviceStart ?? TestClock.now
        let end = serviceEnd ?? start.addingTimeInterval(3600)
        return NDISBillingInputVector(
            participant: NDISParticipantInfo(
                ndisNumber: "4300000001",
                planManagementType: planManagementType,
                location: NDISLocation(postcode: "")
            ),
            provider: NDISProviderInfo(
                abn: "12345678901",
                location: NDISLocation(postcode: ""),
                foundAlternativeWork: false
            ),
            service: NDISServiceInfo(
                supportItemNumber: supportItemNumber,
                startTime: start,
                endTime: end,
                duration: 1,
                quantity: 1,
                date: start
            ),
            agreement: NDISAgreementInfo(agreedPrice: agreedPrice),
            context: NDISContextInfo(
                isProviderTravel: isProviderTravel,
                isActivityTransport: isActivityTransport,
                isDirectService: true
            ),
            travel: NDISTravelInfo(
                timeTo: timeTo,
                timeFrom: 0,
                kilometres: kilometres,
                tolls: 0,
                parking: 0,
                preferredLabourChargeAmount: preferredLabourChargeAmount,
                preferredNonLabourChargeAmount: preferredNonLabourChargeAmount
            ),
            transport: NDISTransportInfo(
                kilometres: kilometres,
                tolls: 0,
                parking: 0,
                isModifiedVehicle: isModifiedVehicle,
                preferredChargeAmount: preferredChargeAmount
            )
        )
    }

    private func supportItemSnapshot(in modelContext: ModelContext, itemNumber: String) throws -> NDISItemSnapshot {
        let descriptor = FetchDescriptor<NDISItem>(predicate: #Predicate { $0.itemNumber == itemNumber })
        let entity = try #require(try modelContext.fetch(descriptor).first)
        return NDISItemSnapshot(entity)
    }
}
