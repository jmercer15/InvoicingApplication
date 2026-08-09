import SwiftData
import Foundation
import Testing
import PersistenceModels
@testable import Core
@testable import Data

@MainActor
@Suite struct PersistenceValueTransformersTests {
    private let modelContainer: ModelContainer
    private let modelContext: ModelContext

    init() throws {
        let (container, context) = try ModelContainerFactory.makeInMemoryContext()
        self.modelContainer = container
        self.modelContext = context
    }

    @Test func RegisterAllInstallsLegacyTransformerSupport() {
        PersistenceValueTransformers.registerAll()

        #expect(ValueTransformer(forName: DateArrayValueTransformer.name) != nil)
    }

    @Test func CustomTransformersRoundTripPersistedValues() throws {
        let client = Client(
            id: UUID(),
            ndisNumber: "4300000000",
            fullName: "Transformer Test",
            status: .active
        )
        client.billingAuthority = .parentGuardian

        let session = Session(id: UUID())
        session.title = "Transformer Session"
        session.status = .grouped

        let invoice = Invoice(invoiceNumber: "INV-TRANSFORMER")
        invoice.status = .pending
        invoice.billingAuthority = .parentGuardian
        invoice.businessAddressSnapshot = AddressSnapshot(
            id: UUID(),
            country: "Australia",
            postcode: "2000",
            state: "NSW",
            streetName: "Bridge Street",
            streetNumber: "123",
            city: "Sydney",
            suburb: "Sydney",
            unitNumber: "Suite 7",
            poBox: "PO123",
            fullAddressText: "123 Bridge Street, Sydney NSW 2000",
            latitude: -33.8651,
            longitude: 151.2099
        )

        let travelCharge = TravelCharge(id: UUID())
        travelCharge.vehicleType = .car
        travelCharge.chargeType = .labour
        travelCharge.travelDirection = .toClient

        let creditHistory = CreditHistoryEntry(id: UUID())
        creditHistory.type = .credit

        let address = Address()
        address.validationStatus = .valid

        modelContext.insert(client)
        modelContext.insert(session)
        modelContext.insert(invoice)
        modelContext.insert(travelCharge)
        modelContext.insert(creditHistory)
        modelContext.insert(address)
        try modelContext.save()

        let readContext = ModelContext(modelContainer)
        readContext.autosaveEnabled = false
        let clientID = client.id
        let sessionID = session.id
        let invoiceID = invoice.id
        let travelChargeID = travelCharge.id
        let creditHistoryID = creditHistory.id
        let addressID = address.id

        let fetchedClient = try readContext.fetch(
            FetchDescriptor<Client>(predicate: #Predicate<Client> { $0.id == clientID })
        ).first
        #expect(fetchedClient?.status == .active)
        #expect(fetchedClient?.billingAuthority == .parentGuardian)

        let fetchedSession = try readContext.fetch(
            FetchDescriptor<Session>(predicate: #Predicate<Session> { $0.id == sessionID })
        ).first
        #expect(fetchedSession?.status == .grouped)

        let fetchedInvoice = try readContext.fetch(
            FetchDescriptor<Invoice>(predicate: #Predicate<Invoice> { $0.id == invoiceID })
        ).first
        #expect(fetchedInvoice?.status == .pending)
        #expect(fetchedInvoice?.billingAuthority == .parentGuardian)
        #expect(fetchedInvoice?.businessAddressSnapshot?.streetName == "Bridge Street")
        #expect(fetchedInvoice?.businessAddressSnapshot?.poBox == "PO123")

        let fetchedTravelCharge = try readContext.fetch(
            FetchDescriptor<TravelCharge>(predicate: #Predicate<TravelCharge> { $0.id == travelChargeID })
        ).first
        #expect(fetchedTravelCharge?.vehicleType == .car)
        #expect(fetchedTravelCharge?.chargeType == .labour)
        #expect(fetchedTravelCharge?.travelDirection == .toClient)

        let fetchedCreditHistory = try readContext.fetch(
            FetchDescriptor<CreditHistoryEntry>(predicate: #Predicate<CreditHistoryEntry> { $0.id == creditHistoryID })
        ).first
        #expect(fetchedCreditHistory?.type == .credit)

        let fetchedAddress = try readContext.fetch(
            FetchDescriptor<Address>(predicate: #Predicate<Address> { $0.id == addressID })
        ).first
        #expect(fetchedAddress?.validationStatus == .valid)
    }
}
