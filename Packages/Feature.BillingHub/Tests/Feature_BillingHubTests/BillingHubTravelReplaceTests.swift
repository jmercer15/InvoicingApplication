import Core
import PersistenceModels
import Data
import Foundation
import SwiftData
import Testing
@testable import Feature_BillingHub

@MainActor
@Suite(.tags(.integration))
struct BillingHubTravelReplaceTests {
    private func makeContext() throws -> (ModelContainer, ModelContext) {
        try ModelContainerFactory.makeInMemoryContext()
    }

    @Test func doubleAddSameDirectionLeavesOneRowMatchingCalculator() async throws {
        let (container, context) = try ModelContainerFactory.makeInMemoryContext()
        let workflow = BillingHubWorkflowActor(modelContainer: container)

        let client = Client(id: UUID(), ndisNumber: "4300000001", fullName: "Travel Client", status: .active)
        let service = ClientService(id: UUID(), serviceName: "Occupational Therapy", unit: "hour", rate: 120)
        service.ndisCode = "15_005_0128_1_3"
        service.client = client
        let session = Session(id: UUID())
        session.title = "OT Session"
        session.status = .completed
        session.startTime = Date()
        session.endTime = Date().addingTimeInterval(3600)
        session.client = client
        session.clientService = service
        context.insert(client)
        context.insert(service)
        context.insert(session)
        try context.save()
        let sessionID = session.id
        let modelID = session.persistentModelID

        try await workflow.addTravelCharge(
            sessionModelID: modelID,
            distance: 10,
            time: 20,
            tolls: 2,
            parking: 1,
            chargeType: "labour",
            vehicleType: "Standard Car",
            travelDirection: "before",
            participantCount: 1,
            splitCosts: false
        )
        try await workflow.addTravelCharge(
            sessionModelID: modelID,
            distance: 15,
            time: 25,
            tolls: 3,
            parking: 0,
            chargeType: "labour",
            vehicleType: "Standard Car",
            travelDirection: "before",
            participantCount: 1,
            splitCosts: false
        )

        let charges = try fetchTravelCharges(for: sessionID, in: context)
        #expect(charges.count == 1)
        #expect(charges.first?.travelDirection == .before)
        #expect(charges.first?.distanceKM == 15)

        let expected = BillingHubTravelChargeCalculator.breakdown(
            providerType: .therapist, hourlyRate: 120,
            mmmZoneDescriptor: nil,
            distance: 15,
            time: 25,
            tolls: 3,
            parking: 0,
            participantCount: 1,
            splitCosts: false,
            chargeType: "labour",
            vehicleType: "Standard Car")
        #expect(charges.first?.chargeAmount == Decimal(expected.chargeAmount))
        #expect(charges.first?.chargeAmount == Decimal(expected.labourPerParticipant))
        #expect(charges.first?.durationMinutes ?? -1 == expected.billableMinutes) // was accuracy: 0.0001
    }

    @Test func differentDirectionsKeepSeparateRows() async throws {
        let (container, context) = try ModelContainerFactory.makeInMemoryContext()
        let workflow = BillingHubWorkflowActor(modelContainer: container)

        let session = Session(id: UUID())
        session.title = "Session"
        session.status = .completed
        session.startTime = Date()
        session.endTime = Date().addingTimeInterval(3600)
        context.insert(session)
        try context.save()
        let sessionID = session.id
        let modelID = session.persistentModelID

        try await workflow.addTravelCharge(
            sessionModelID: modelID, distance: 5,
            time: 10,
            tolls: 0,
            parking: 0,
            chargeType: "labour",
            vehicleType: "Standard Car",
            travelDirection: "before",
            participantCount: 1,
            splitCosts: false)
        try await workflow.addTravelCharge(
            sessionModelID: modelID,
            distance: 8,
            time: 12,
            tolls: 0,
            parking: 0,
            chargeType: "labour",
            vehicleType: "Standard Car",
            travelDirection: "after",
            participantCount: 1,
            splitCosts: false
        )

        let charges = try fetchTravelCharges(for: sessionID, in: context)
        #expect(charges.count == 2)
        let directions = Set(charges.compactMap(\.travelDirection))
        #expect(directions == [.before, .after])
    }

    @Test func calendarThenHubSameDirectionReplacesSingleRow() async throws {
        let (container, context) = try ModelContainerFactory.makeInMemoryContext()
        let workflow = BillingHubWorkflowActor(modelContainer: container)

        let session = Session(id: UUID())
        session.title = "Session"
        session.status = .completed
        session.startTime = Date()
        session.endTime = Date().addingTimeInterval(3600)
        context.insert(session)

        // Simulate Calendar-persisted before charge.
        let calendarCharge = TravelCharge(
            id: UUID(), chargeAmount: 9.9,
            distanceKM: 10,
            durationMinutes: 15,
            status: .pending,
            chargeType: .labour,
            travelDirection: .before)
        calendarCharge.linkedSession = session
        context.insert(calendarCharge)
        try context.save()
        let sessionID = session.id
        let calendarChargeID = calendarCharge.id
        let modelID = session.persistentModelID

        try await workflow.addTravelCharge(
            sessionModelID: modelID,
            distance: 20,
            time: 30,
            tolls: 0,
            parking: 0,
            chargeType: "labour",
            vehicleType: "Standard Car",
            travelDirection: "before",
            participantCount: 1,
            splitCosts: false
        )

        let charges = try fetchTravelCharges(for: sessionID, in: context)
        #expect(charges.count == 1)
        #expect(charges.first?.distanceKM == 20)
        #expect(charges.first?.id != calendarChargeID)
    }

    @Test func previewBreakdownMatchesPersistedAmount() async throws {
        let (container, context) = try ModelContainerFactory.makeInMemoryContext()
        let workflow = BillingHubWorkflowActor(modelContainer: container)

        let service = ClientService(id: UUID(), serviceName: "Disability Support Work", unit: "hour", rate: 80)
        service.ndisCode = "01_011_0107_1_1"
        let session = Session(id: UUID())
        session.title = "DSW"
        session.status = .completed
        session.startTime = Date()
        session.endTime = Date().addingTimeInterval(3600)
        session.clientService = service
        context.insert(service)
        context.insert(session)
        try context.save()
        let sessionID = session.id
        let modelID = session.persistentModelID

        let preview = try await workflow.calculateTravelBreakdown(
            sessionModelID: modelID, distance: 12,
            time: 40,
            tolls: 1.5,
            parking: 2,
            chargeType: "standard",
            vehicleType: "Standard Car",
            participantCount: 2,
            splitCosts: true)
        let expectedPreview = try try #require(preview)

        try await workflow.addTravelCharge(
            sessionModelID: modelID,
            distance: 12,
            time: 40,
            tolls: 1.5,
            parking: 2,
            chargeType: "standard",
            vehicleType: "Standard Car",
            travelDirection: "after",
            participantCount: 2,
            splitCosts: true
        )

        let charge = try try #require(fetchTravelCharges(for: sessionID, in: context).first)
        #expect(charge.chargeAmount == Decimal(expectedPreview.chargeAmount))
        #expect(charge.chargeAmount == Decimal(expectedPreview.totalPerParticipant))
        #expect(charge.durationMinutes ?? -1 == expectedPreview.billableMinutes) // was accuracy: 0.0001
    }

    @Test func addTravelThrowsWhenSessionMissing() async throws {
        let (container, context) = try ModelContainerFactory.makeInMemoryContext()
        let workflow = BillingHubWorkflowActor(modelContainer: container)
        let session = Session(id: UUID())
        context.insert(session)
        try context.save()
        let orphanID = session.persistentModelID
        context.delete(session)
        try context.save()

        do {
            try await workflow.addTravelCharge(
                sessionModelID: orphanID, distance: 1,
                time: 1,
                tolls: 0,
                parking: 0,
                chargeType: "labour",
                vehicleType: "Standard Car",
                travelDirection: "before",
                participantCount: 1,
                splitCosts: false)
            Issue.record("Expected sessionNotFound")
        } catch let error as BillingHubTravelError {
            #expect(error == .sessionNotFound)
        }
    }

    private func fetchTravelCharges(for sessionID: UUID, in context: ModelContext) throws -> [TravelCharge] {
        let descriptor = FetchDescriptor<TravelCharge>(
            predicate: #Predicate { $0.linkedSession?.id == sessionID }
        )
        return try context.fetch(descriptor)
    }
}

@MainActor
@Suite(.tags(.integration))
struct BillingHubTravelChargeCalculatorTests {
    @Test func effectiveParticipantCountHonoursSplitFlag() {
        #expect(BillingHubTravelChargeCalculator.effectiveParticipantCount(participantCount: 3, splitCosts: false) == 1)
        #expect(BillingHubTravelChargeCalculator.effectiveParticipantCount(participantCount: 3, splitCosts: true) == 3)
    }

    @Test func breakdownMatchesNDISTravelChargeCalculator() {
        let hub = BillingHubTravelChargeCalculator.breakdown(
            providerType: .therapist,
            hourlyRate: 100,
            mmmZoneDescriptor: "MMM 1-3",
            distance: 10,
            time: 45,
            tolls: 2,
            parking: 1,
            participantCount: 1,
            splitCosts: false,
            chargeType: "standard",
            vehicleType: "Standard Car"
        )
        let core = NDISTravelChargeCalculator.calculate(
            providerType: .therapist,
            hourlyRate: 100,
            mmmZoneDescriptor: "MMM 1-3",
            minutesTravelled: 45,
            kilometresTravelled: 10,
            ancillaryCosts: 3,
            participantCount: 1
        )
        #expect(hub.labourTotal == core.labourTotal) // was accuracy: 0.0001
        #expect(hub.nonLabourTotal == core.nonLabourTotal) // was accuracy: 0.0001
        #expect(hub.grossTotal == core.grossTotal) // was accuracy: 0.0001
        #expect(hub.billableMinutes == core.billableMinutes) // was accuracy: 0.0001
        #expect(hub.totalPerParticipant == core.totalPerParticipant) // was accuracy: 0.0001
        #expect(hub.chargeAmount == core.totalPerParticipant) // was accuracy: 0.0001
    }

    @Test func labourChargeAmountUsesPricingMathNotGrossTotal() {
        let labour = BillingHubTravelChargeCalculator.breakdown(
            providerType: .dsw, hourlyRate: 60,
            mmmZoneDescriptor: nil,
            distance: 10,
            time: 30,
            tolls: 0,
            parking: 0,
            participantCount: 1,
            splitCosts: false,
            chargeType: "labour",
            vehicleType: "Standard Car")
        let nonLabour = BillingHubTravelChargeCalculator.breakdown(
            providerType: .dsw,
            hourlyRate: 60,
            mmmZoneDescriptor: nil,
            distance: 10,
            time: 30,
            tolls: 0,
            parking: 0,
            participantCount: 1,
            splitCosts: false,
            chargeType: "non-labour",
            vehicleType: "Standard Car"
        )
        #expect(labour.chargeAmount == labour.labourPerParticipant) // was accuracy: 0.0001
        #expect(nonLabour.chargeAmount == nonLabour.nonLabourPerParticipant) // was accuracy: 0.0001
        #expect(abs(labour.chargeAmount - labour.totalPerParticipant) > 0.0001)
    }

    @Test func modifiedVehicleUsesHigherKilometreRate() {
        let standard = BillingHubTravelChargeCalculator.breakdown(
            providerType: .dsw, hourlyRate: 60,
            mmmZoneDescriptor: nil,
            distance: 10,
            time: 0,
            tolls: 0,
            parking: 0,
            participantCount: 1,
            splitCosts: false,
            chargeType: "activity-based",
            vehicleType: "Standard Car")
        let modified = BillingHubTravelChargeCalculator.breakdown(
            providerType: .dsw,
            hourlyRate: 60,
            mmmZoneDescriptor: nil,
            distance: 10,
            time: 0,
            tolls: 0,
            parking: 0,
            participantCount: 1,
            splitCosts: false,
            chargeType: "activity-based",
            vehicleType: "Modified/Bus"
        )
        #expect(standard.nonLabourTotal == 10 * NDISTravelChargeCalculator.vehicleRatePerKilometre) // was accuracy: 0.0001

        #expect(modified.nonLabourTotal == 10 * NDISTravelChargeCalculator.modifiedVehicleRatePerKilometre) // was accuracy: 0.0001

        #expect(modified.chargeAmount > standard.chargeAmount)
    }
}

@MainActor
@Suite(.tags(.integration))
struct BillingHubProjectionDebounceTests {
    @Test func cancelledDebounceSkipsRefresh() async {
        var refreshed = false
        let task = Task {
            await BillingHubProjectionDebounce.run(delay: .milliseconds(200)) {
                refreshed = true
            }
        }
        task.cancel()
        await task.value
        #expect(!(refreshed))
    }

    @Test func completedDebounceRunsRefresh() async {
        var refreshed = false
        await BillingHubProjectionDebounce.run(delay: .milliseconds(10)) {
            refreshed = true
        }
        #expect(refreshed)
    }
}

@MainActor
@Suite(.tags(.integration))
struct BillingHubProjectionRefreshGenerationTests {
    @Test func rapidRefreshRequestsAdvanceGenerationWithoutStuckLoading() async throws {
        let (container, context) = try ModelContainerFactory.makeInMemoryContext()
        let viewModel = BillingHubViewModel(
            modelContext: context, modelContainer: container,
            ndisBillingIntegrationService: NDISBillingIntegrationService(
                modelContainer: container,
                geocodingService: SwiftDataGeocodingService(),
                mmmZoneLookup: MMMZoneLookup())
        )

        async let firstRefresh: Void = viewModel.refreshProjection()
        async let secondRefresh: Void = viewModel.refreshProjection()
        await firstRefresh
        await secondRefresh

        #expect(viewModel.projectionRefreshGeneration >= 2)
        #expect(!viewModel.isLoading)
    }
}
