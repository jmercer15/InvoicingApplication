import Core
import PersistenceModels
import Data
import Foundation
import SwiftData
import Testing
import CoreTesting
@testable import InvoiceTableLayoutEditor

/// Phase 1.4: editor save must not strip NDIS claimType / session / clientService lineage.
@Suite(.tags(.integration))
struct InvoiceLineageRoundTripTests {
    @Test func adapterRoundTripsClaimTypeAndSessionID() async throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let context = ModelContext(container)
        let session = Session(id: UUID(), title: "Travel session")
        let clientService = ClientService(
            id: UUID(),
            serviceName: "Support",
            unit: "hour",
            rate: 100
        )
        let invoice = Invoice(invoiceNumber: "INV-LINEAGE-FETCH")
        let travel = InvoiceItem(itemDescription: "Provider travel")
        travel.quantity = 1
        travel.rate = 25
        travel.claimType = .providerTravelLabour
        travel.session = session
        travel.clientService = clientService
        travel.invoice = invoice
        invoice.items = [travel]
        context.insert(session)
        context.insert(clientService)
        context.insert(invoice)
        context.insert(travel)
        try context.save()

        let snapshot = try await InvoiceModelActor(modelContainer: container).fetchInvoice(id: invoice.id)
        let line = try #require(snapshot?.lineItems.first)
        #expect(line.claimType == .providerTravelLabour)
        #expect(line.sessionID == session.id)
        #expect(line.clientServiceID == clientService.id)
    }

    @Test func editSavePreservesTravelClaimTypeSessionAndClientService() async throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let context = ModelContext(container)
        let sessionID = UUID()
        let clientServiceID = UUID()
        let travelItemID = UUID()
        let session = Session(id: sessionID, title: "Billable session")
        let clientService = ClientService(
            id: clientServiceID, serviceName: "Therapy",
            unit: "hour",
            rate: 193.99)
        let invoice = Invoice(invoiceNumber: "INV-LINEAGE-SAVE")
        invoice.clientName = "Lineage Client"
        invoice.currencyCode = "AUD"
        invoice.effectiveStatus = .reviewDraft
        let travel = InvoiceItem(id: travelItemID, itemDescription: "Travel labour")
        travel.quantity = 0.5
        travel.rate = 40
        travel.unit = "hour"
        travel.ndisItemNumber = "04_590_0125_6_1"
        travel.claimType = .providerTravelLabour
        travel.session = session
        travel.clientService = clientService
        travel.invoice = invoice
        invoice.items = [travel]
        context.insert(session)
        context.insert(clientService)
        context.insert(invoice)
        context.insert(travel)
        try context.save()

        let actor = InvoiceModelActor(modelContainer: container)
        let fetchedValue = try await actor.fetchInvoice(id: invoice.id)
        let fetched = try #require(fetchedValue)
        var draft = InvoiceDraft(fetched)
        draft.lineItems[0].itemDescription = "Travel labour (edited)"
        draft.title = "Edited draft"

        let result = try await actor.updateInvoice(
            id: invoice.id,
            expectedRevision: fetched.revision,
            draft: draft
        )
        #expect(result.isValid)

        let saved = try #require(result.savedSnapshot)
        #expect(saved.lineItems.first?.claimType == .providerTravelLabour)
        #expect(saved.lineItems.first?.sessionID == sessionID)
        #expect(saved.lineItems.first?.clientServiceID == clientServiceID)
        #expect(saved.lineItems.first?.itemDescription == "Travel labour (edited)")

        let refetchedValue = try await actor.fetchInvoice(id: invoice.id)
        let refetched = try #require(refetchedValue)
        #expect(refetched.lineItems.first?.claimType == .providerTravelLabour)
        #expect(refetched.lineItems.first?.sessionID == sessionID)

        // Claim batching reads InvoiceItem.claimType — must remain travel after editor save.
        let verifyContext = ModelContext(container)
        let persistedTravel = try #require(try verifyContext.fetch(
                FetchDescriptor<InvoiceItem>(predicate: #Predicate { $0.id == travelItemID })
            ).first
        )
        #expect(persistedTravel.claimType == .providerTravelLabour)
        #expect(persistedTravel.session?.id == sessionID)
        #expect(persistedTravel.clientService?.id == clientServiceID)
    }

    @Test func createFromDraftPersistsClaimTypeAndSessionOnNewLineIDs() async throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let context = ModelContext(container)
        let sessionID = UUID()
        let session = Session(id: sessionID, title: "Source session")
        context.insert(session)
        try context.save()

        let actor = InvoiceModelActor(modelContainer: container)
        let seedID = try await actor.createInvoice()
        let seedValue = try await actor.fetchInvoice(id: seedID)
        let seed = try #require(seedValue)
        var draft = InvoiceDraft(seed)
        draft.client.name = "Draft Lineage Client"
        draft.currencyCode = "AUD"
        draft.lineItems = [
            InvoiceLineItemSnapshot(
                sortOrder: 0, itemDescription: "Travel from draft",
                itemCode: "04_590_0125_6_1",
                quantity: 1,
                unit: "km",
                unitPrice: 0.85,
                taxRate: 0,
                claimType: .providerTravelNonLabour,
                sessionID: sessionID)
        ]

        let createdID = try await actor.createInvoice(from: draft)
        let createdValue = try await actor.fetchInvoice(id: createdID)
        let created = try #require(createdValue)
        let line = try #require(created.lineItems.first)
        #expect(line.id != seed.lineItems.first?.id)
        #expect(line.claimType == .providerTravelNonLabour)
        #expect(line.sessionID == sessionID)

        let lineID = line.id
        let verifyContext = ModelContext(container)
        let persisted = try verifyContext.fetch(
            FetchDescriptor<InvoiceItem>(predicate: #Predicate { $0.id == lineID })
        )
        #expect(persisted.first?.claimType == .providerTravelNonLabour)
        #expect(persisted.first?.session?.id == sessionID)
    }

    @Test func saveDoesNotClearExistingLineageWhenReplacementIDsCannotResolve() async throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let context = ModelContext(container)
        let session = Session(id: UUID(), title: "Source session")
        let clientService = ClientService(id: UUID(), serviceName: "Support", unit: "hour", rate: 100)
        let invoice = Invoice(invoiceNumber: "INV-LINEAGE-RECOVERY")
        let item = InvoiceItem(itemDescription: "Support")
        item.session = session
        item.clientService = clientService
        item.invoice = invoice
        invoice.items = [item]
        context.insert(session)
        context.insert(clientService)
        context.insert(invoice)
        context.insert(item)
        try context.save()

        let actor = InvoiceModelActor(modelContainer: container)
        let fetchedSnapshot = try await actor.fetchInvoice(id: invoice.id)
        let snapshot = try #require(fetchedSnapshot)
        var draft = InvoiceDraft(snapshot)
        draft.lineItems[0].sessionID = UUID()
        draft.lineItems[0].clientServiceID = UUID()

        _ = try await actor.updateInvoice(
            id: invoice.id, expectedRevision: snapshot.revision,
            draft: draft)

        let verifyContext = ModelContext(container)
        let itemID = item.id
        let persisted = try #require(verifyContext.fetch(FetchDescriptor<InvoiceItem>(predicate: #Predicate { $0.id == itemID })).first
        )
        #expect(persisted.session?.id == session.id)
        #expect(persisted.clientService?.id == clientService.id)
    }
}
