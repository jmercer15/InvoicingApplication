import Core
import Data
import Foundation
import PersistenceModels
import SwiftData
import Testing
@testable import InvoiceTableLayoutEditor

@Suite struct InvoiceModelActorIntegrationTests {
    @Test func SharedCoreEditorConfigurationLoadsWithFeaturePresentationDefaults() async throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let context = ModelContext(container)
        let invoice = Invoice(invoiceNumber: "INV-SHARED-STATE")
        invoice.invoiceEditorStateData = try InvoiceEditorConfiguration(
            title: "NDIS Invoice",
            billParticipantDirectly: false,
            billToPhone: "07 3000 0000",
            discountAmount: 15,
            showsTaxSummary: false
        ).encoded()
        context.insert(invoice)
        try context.save()

        let snapshot = try await InvoiceModelActor(modelContainer: container).fetchInvoice(id: invoice.id)

        #expect(snapshot?.title == "NDIS Invoice")
        #expect(snapshot?.billParticipantDirectly == false)
        #expect(snapshot?.billToPhone == "07 3000 0000")
        #expect(snapshot?.discountAmount == 15)
        #expect(snapshot?.showsTaxSummary == false)
        #expect(snapshot?.paperSize == .default)
        #expect(snapshot?.pageOrientation == .portrait)
        #expect(snapshot?.templateConfiguration == .default)
    }

    @Test func EditorOpensExistingCoreInvoiceWithoutEditorState() async throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let context = ModelContext(container)
        let invoice = Invoice(invoiceNumber: "INV-2026-001")
        invoice.clientName = "Existing Client"
        invoice.businessName = "Existing Provider"
        invoice.currencyCode = "AUD"
        invoice.effectiveStatus = .cancelled
        let item = InvoiceItem(itemDescription: "Existing support")
        item.quantity = 1.5
        item.rate = 80
        item.taxRate = 10
        item.invoice = invoice
        invoice.items = [item]
        context.insert(invoice)
        context.insert(item)
        try context.save()

        let actor = InvoiceModelActor(modelContainer: container)
        let fetchedValue = try await actor.fetchInvoice(id: invoice.id)
        let fetched = try #require(fetchedValue)
        #expect(fetched.invoiceNumber == "INV-2026-001")
        #expect(fetched.clientName == "Existing Client")
        #expect(fetched.status == .cancelled)
        #expect(fetched.lineItems.first?.itemDescription == "Existing support")
        #expect(fetched.grandTotal == 132)
        #expect(fetched.templateConfiguration == .default)

        var layoutEdit = InvoiceDraft(fetched)
        layoutEdit.title = "Cancelled Invoice Layout"
        let validation = try await actor.updateInvoice(
            id: invoice.id,
            expectedRevision: fetched.revision,
            draft: layoutEdit
        )
        #expect(validation.isValid)
        #expect(validation.savedSnapshot?.revision == fetched.revision + 1)
        #expect(validation.savedSnapshot?.title == "Cancelled Invoice Layout")
        let afterLayoutEditValue = try await actor.fetchInvoice(id: invoice.id)
        let afterLayoutEdit = try #require(afterLayoutEditValue)
        #expect(afterLayoutEdit.status == .cancelled)
        #expect(invoice.effectiveStatus == .cancelled)
    }

    @Test func EditorFallsBackForMalformedPersistedCurrencyAtSnapshotBoundary() async throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let context = ModelContext(container)
        let invoice = Invoice(invoiceNumber: "INV-LEGACY-CURRENCY")
        invoice.currencyCode = "12!"
        context.insert(invoice)
        try context.save()

        let snapshot = try await InvoiceModelActor(modelContainer: container).fetchInvoice(id: invoice.id)

        #expect(snapshot?.currencyCode == InvoiceCurrencyCode.defaultValue)
    }

    @Test func ExistingInvoiceWithoutEditorStateIgnoresCurrentTemplateDefaults() async throws {
        let suiteName = "InvoiceModelActorIntegrationTests.\(UUID().uuidString)"
        let preferences = try #require(UserDefaults(suiteName: suiteName))
        defer {
            preferences.removePersistentDomain(forName: suiteName)
        }

        var currentTemplate = InvoiceTemplatePreset.modern.configuration
        currentTemplate.accentTheme = .forest
        #expect(InvoiceTemplatePreferenceStore.save(
            InvoiceTemplateDefaults(
                paperSize: .legal,
                pageOrientation: .landscape,
                configuration: currentTemplate
            ),
            to: preferences
        ))

        let container = try ModelContainerFactory.makeInMemoryContainer()
        let context = ModelContext(container)
        let existing = Invoice(invoiceNumber: "INV-PRE-TEMPLATE")
        existing.clientName = "Existing Client"
        context.insert(existing)
        try context.save()

        let snapshot = try await InvoiceModelActor(modelContainer: container).fetchInvoice(id: existing.id)

        #expect(snapshot?.paperSize == .default)
        #expect(snapshot?.pageOrientation == .portrait)
        #expect(snapshot?.templateConfiguration == .default)
    }

    @Test func ExistingRelationshipDataBackfillsMissingInvoiceSnapshots() async throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let context = ModelContext(container)
        let clientAddress = Address()
        clientAddress.streetNumber = "8"
        clientAddress.streetName = "Market Street"
        clientAddress.city = "Brisbane"
        clientAddress.state = "QLD"
        clientAddress.postcode = "4000"
        let businessAddress = Address()
        businessAddress.streetNumber = "14"
        businessAddress.streetName = "Provider Lane"
        businessAddress.city = "Brisbane"
        businessAddress.state = "QLD"
        businessAddress.postcode = "4001"
        let business = Business(abn: "53 004 085 616")
        business.name = "Example Supports"
        business.email = "billing@example-supports.com"
        business.phone = "07 3000 0000"
        business.address = businessAddress
        business.bankName = "Example Bank"
        business.bankAccountName = "Example Supports"
        business.bankBSB = "123-456"
        business.bankAccountNumber = "12345678"
        let manager = PlanManager(abn: "12 345 678 901")
        manager.name = "Example Plan Management"
        manager.email = "accounts@example.com"
        manager.phone = "07 3111 1111"
        let client = Client(
            ndisNumber: "4300999999",
            fullName: "Legacy Participant",
            email: "participant@example.com",
            phone: "0400 999 999",
            billingAuthority: .planManager
        )
        client.address = clientAddress
        client.planManager = manager
        let invoice = Invoice(invoiceNumber: "INV-LINKED")
        invoice.business = business
        invoice.client = client
        context.insert(clientAddress)
        context.insert(businessAddress)
        context.insert(business)
        context.insert(manager)
        context.insert(client)
        context.insert(invoice)
        try context.save()

        let fetchedValue = try await InvoiceModelActor(modelContainer: container).fetchInvoice(id: invoice.id)
        let fetched = try #require(fetchedValue)
        #expect(fetched.sellerName == "Example Supports")
        #expect(fetched.sellerAddress == "14 Provider Lane, Brisbane, QLD, 4001")
        #expect(fetched.sellerEmail == "billing@example-supports.com")
        #expect(fetched.sellerPhone == "07 3000 0000")
        #expect(fetched.sellerTaxID == "53 004 085 616")
        #expect(fetched.bankName == "Example Bank")
        #expect(fetched.bankAccountName == "Example Supports")
        #expect(fetched.bankBSB == "123-456")
        #expect(fetched.bankAccountNumber == "12345678")
        #expect(fetched.clientID == client.id)
        #expect(fetched.clientName == "Legacy Participant")
        #expect(fetched.clientAddress == "8 Market Street, Brisbane, QLD, 4000")
        #expect(fetched.clientEmail == "participant@example.com")
        #expect(fetched.clientPhone == "0400 999 999")
        #expect(fetched.clientTaxID == "4300999999")
        #expect(fetched.billingAuthority == Core.BillingAuthority.planManager.rawValue)
        #expect(fetched.billToName == "Example Plan Management")
        #expect(fetched.billToEmail == "accounts@example.com")
        #expect(fetched.billToPhone == "07 3111 1111")
        #expect(!(fetched.billParticipantDirectly))
    }

    @Test func BlankPersistedSnapshotsDoNotMaskLinkedLiveData() async throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let context = ModelContext(container)

        let business = Business(abn: "11 222 333 444")
        business.name = "Live Provider"
        business.email = "accounts@live-provider.example"
        business.phone = "07 3555 0100"
        business.bankName = "Live Bank"
        business.bankAccountName = "Live Provider Operating"
        business.bankBSB = "111-222"
        business.bankAccountNumber = "123456"
        let businessAddress = Address()
        businessAddress.streetNumber = "18"
        businessAddress.streetName = "Live Street"
        businessAddress.city = "Brisbane"
        businessAddress.state = "QLD"
        businessAddress.postcode = "4000"
        business.address = businessAddress

        let client = Client(
            ndisNumber: "4300123456",
            fullName: "Live Participant",
            email: "participant@live.example",
            phone: "0400 123 456",
            billingAuthority: .client
        )
        let clientAddress = Address()
        clientAddress.streetNumber = "42"
        clientAddress.streetName = "Participant Road"
        clientAddress.city = "Brisbane"
        clientAddress.state = "QLD"
        clientAddress.postcode = "4001"
        client.address = clientAddress

        let invoice = Invoice(invoiceNumber: "INV-BLANK-SNAPSHOTS")
        invoice.business = business
        invoice.client = client
        invoice.businessName = "   "
        invoice.businessEmail = ""
        invoice.businessPhone = " "
        invoice.businessABN = ""
        invoice.clientName = " "
        invoice.clientEmail = ""
        invoice.clientPhone = " "
        invoice.clientNDISNumber = ""
        invoice.billToName = " "
        invoice.billToEmail = ""
        invoice.bankName = " "
        invoice.bankAccountName = ""
        invoice.bankBSB = " "
        invoice.bankAccountNumber = ""
        invoice.invoiceEditorStateData = try InvoiceEditorConfiguration(
            billToPhone: "   "
        ).encoded()

        context.insert(businessAddress)
        context.insert(clientAddress)
        context.insert(business)
        context.insert(client)
        context.insert(invoice)
        try context.save()

        let fetchedValue = try await InvoiceModelActor(modelContainer: container).fetchInvoice(id: invoice.id)
        let fetched = try #require(fetchedValue)

        #expect(fetched.sellerName == "Live Provider")
        #expect(fetched.sellerAddress == "18 Live Street, Brisbane, QLD, 4000")
        #expect(fetched.sellerEmail == "accounts@live-provider.example")
        #expect(fetched.sellerPhone == "07 3555 0100")
        #expect(fetched.sellerTaxID == "11 222 333 444")
        #expect(fetched.clientName == "Live Participant")
        #expect(fetched.clientAddress == "42 Participant Road, Brisbane, QLD, 4001")
        #expect(fetched.clientEmail == "participant@live.example")
        #expect(fetched.clientPhone == "0400 123 456")
        #expect(fetched.clientTaxID == "4300123456")
        #expect(fetched.billToName == "Live Participant")
        #expect(fetched.billToEmail == "participant@live.example")
        #expect(fetched.billToAddress == "42 Participant Road, Brisbane, QLD, 4001")
        #expect(fetched.billToPhone == "0400 123 456")
        #expect(fetched.bankName == "Live Bank")
        #expect(fetched.bankAccountName == "Live Provider Operating")
        #expect(fetched.bankBSB == "111-222")
        #expect(fetched.bankAccountNumber == "123456")
    }

    @Test func PersistedClientSnapshotBackfillsDirectBillingWithoutRelationship() async throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let context = ModelContext(container)
        let clientAddress = Address()
        clientAddress.streetNumber = "9"
        clientAddress.streetName = "Snapshot Avenue"
        clientAddress.city = "Brisbane"
        clientAddress.state = "QLD"
        clientAddress.postcode = "4002"
        let invoice = Invoice(invoiceNumber: "INV-DIRECT-SNAPSHOT")
        invoice.billingAuthority = .client
        invoice.clientName = "Persisted Participant"
        invoice.clientEmail = "persisted.participant@example.com"
        invoice.clientPhone = "0400 222 333"
        invoice.clientNDISNumber = "4300222333"
        invoice.clientAddressSnapshot = clientAddress.snapshot()
        context.insert(invoice)
        try context.save()

        let fetchedValue = try await InvoiceModelActor(modelContainer: container).fetchInvoice(id: invoice.id)
        let fetched = try #require(fetchedValue)

        #expect(fetched.clientName == "Persisted Participant")
        #expect(fetched.clientAddress == "9 Snapshot Avenue, Brisbane, QLD, 4002")
        #expect(fetched.clientEmail == "persisted.participant@example.com")
        #expect(fetched.clientPhone == "0400 222 333")
        #expect(fetched.clientTaxID == "4300222333")
        #expect(fetched.billToName == "Persisted Participant")
        #expect(fetched.billToAddress == "9 Snapshot Avenue, Brisbane, QLD, 4002")
        #expect(fetched.billToEmail == "persisted.participant@example.com")
        #expect(fetched.billToPhone == "0400 222 333")
        #expect(fetched.billParticipantDirectly)
    }

    @Test func LinkedServiceDataBackfillsSparseInvoiceLineItemDocumentFields() async throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let context = ModelContext(container)
        let service = ClientService(serviceName: "Capacity building support", unit: "hour", rate: 193.99)
        service.ndisItemNumber = "15_037_0117_1_3"
        service.gstCode = "P2"
        let session = Session(
            title: "Therapy session",
            assignedServiceName: "Therapy supports",
            assignedRate: 215
        )
        session.clientService = service
        let invoice = Invoice(invoiceNumber: "INV-LINE-BACKFILL")
        let item = InvoiceItem(itemDescription: "   ")
        item.invoice = invoice
        item.clientService = service
        item.session = session
        item.quantity = 2
        item.rate = 0
        item.unit = " "
        item.ndisItemNumber = ""
        item.gstCode = ""
        invoice.items = [item]

        context.insert(service)
        context.insert(session)
        context.insert(invoice)
        context.insert(item)
        try context.save()

        let fetchedValue = try await InvoiceModelActor(modelContainer: container).fetchInvoice(id: invoice.id)
        let fetched = try #require(fetchedValue)
        let fetchedItem = try #require(fetched.lineItems.first)

        #expect(fetchedItem.itemDescription == "Therapy supports")
        #expect(fetchedItem.itemCode == "15_037_0117_1_3")
        #expect(fetchedItem.unit == "hour")
        #expect(fetchedItem.unitPrice == 215)
        #expect(fetchedItem.gstCode == "P2")
        #expect(fetchedItem.sessionID == session.id)
        #expect(fetchedItem.clientServiceID == service.id)
    }

    @Test func ExistingPayeeSnapshotsBackfillParentGuardianRecipient() async throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let context = ModelContext(container)
        let payeeAddress = Address()
        payeeAddress.streetNumber = "25"
        payeeAddress.streetName = "Guardian Road"
        payeeAddress.city = "Brisbane"
        payeeAddress.state = "QLD"
        payeeAddress.postcode = "4002"
        let invoice = Invoice(invoiceNumber: "INV-PAYEE-SNAPSHOT")
        invoice.billingAuthority = .parentGuardian
        invoice.payeeName = "Morgan Guardian"
        invoice.payeeEmail = "morgan@example.com"
        invoice.payeePhone = "0400 111 222"
        invoice.payeeAddressSnapshot = payeeAddress.snapshot()
        context.insert(invoice)
        try context.save()

        let fetchedValue = try await InvoiceModelActor(modelContainer: container).fetchInvoice(id: invoice.id)
        let fetched = try #require(fetchedValue)

        #expect(fetched.billToName == "Morgan Guardian")
        #expect(fetched.billToEmail == "morgan@example.com")
        #expect(fetched.billToPhone == "0400 111 222")
        #expect(fetched.billToAddress == "25 Guardian Road, Brisbane, QLD, 4002")
        #expect(fetched.billingAuthority == Core.BillingAuthority.parentGuardian.rawValue)
        #expect(!(fetched.billParticipantDirectly))
    }

    @Test func FirstClassFieldsOverrideLegacyEditorEnvelopeShadows() async throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let context = ModelContext(container)
        let invoice = Invoice(invoiceNumber: "INV-2026-LEGACY")
        invoice.businessPhone = "current seller phone"
        invoice.clientPhone = "current client phone"
        invoice.taxRate = 10
        invoice.invoiceEditorStateData = try JSONEncoder().encode(
            LegacyConfigurationEnvelope(
                sellerPhone: "stale seller phone",
                clientPhone: "stale client phone",
                defaultTaxRate: 5
            )
        )
        let item = InvoiceItem(itemDescription: "Legacy taxed item")
        item.quantity = 1
        item.rate = 100
        item.invoice = invoice
        invoice.items = [item]
        context.insert(invoice)
        context.insert(item)
        try context.save()

        let fetched = try await InvoiceModelActor(modelContainer: container).fetchInvoice(id: invoice.id)
        let snapshot = try #require(fetched)
        #expect(snapshot.sellerPhone == "current seller phone")
        #expect(snapshot.clientPhone == "current client phone")
        #expect(snapshot.defaultTaxRate == 10)
        #expect(snapshot.lineItems.first?.taxRate == 10)
        #expect(snapshot.grandTotal == 110)
    }

    @Test func EditorUsesAppSchemaForCreateUpdateFetchAndDelete() async throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let actor = InvoiceModelActor(modelContainer: container)

        let id = try await actor.createInvoice()
        let createdSnapshot = try await actor.fetchInvoice(id: id)
        var snapshot = try #require(createdSnapshot)
        #expect(snapshot.revision == 0)
        #expect(snapshot.lineItems.count == 1)

        var draft = InvoiceDraft(snapshot)
        draft.title = "Service Invoice"
        draft.client.name = "Taylor Client"
        draft.seller.name = "Example Provider"
        draft.billing.authority = Core.BillingAuthority.client.rawValue
        draft.currencyCode = "aud"
        draft.defaultTaxRate = 10
        draft.adjustments.discountPercent = 5
        draft.lineItems[0].itemDescription = "Support service"
        draft.lineItems[0].quantity = 2
        draft.lineItems[0].unitPrice = 100
        draft.lineItems[0].taxRate = 10

        let validation = try await actor.updateInvoice(
            id: id,
            expectedRevision: snapshot.revision,
            draft: draft
        )
        #expect(validation.isValid)
        #expect(validation.savedSnapshot?.revision == 1)
        #expect(validation.savedSnapshot?.clientName == "Taylor Client")

        let updatedSnapshot = try await actor.fetchInvoice(id: id)
        snapshot = try #require(updatedSnapshot)
        #expect(snapshot.revision == 1)
        #expect(snapshot.title == "Service Invoice")
        #expect(snapshot.clientName == "Taylor Client")
        #expect(snapshot.currencyCode == "AUD")
        #expect(snapshot.grandTotal == 209)

        let context = ModelContext(container)
        let invoices = try context.fetch(FetchDescriptor<Invoice>())
        let persisted = try #require(invoices.first { $0.id == id })
        #expect(persisted.invoiceEditorRevision == 1)
        #expect(persisted.clientName == "Taylor Client")
        #expect(persisted.itemsArray.count == 1)
        #expect(persisted.itemsArray[0].itemDescription == "Support service")
        #expect(persisted.invoiceEditorStateData != nil)

        try await actor.deleteInvoice(id: id, expectedRevision: snapshot.revision)
        let deletedSnapshot = try await actor.fetchInvoice(id: id)
        #expect(deletedSnapshot == nil)
    }

    @Test func PersistenceCanonicalizesDirectBillingOverStaleAuthority() async throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let actor = InvoiceModelActor(modelContainer: container)
        let id = try await actor.createInvoice()
        let originalValue = try await actor.fetchInvoice(id: id)
        let original = try #require(originalValue)
        var draft = InvoiceDraft(original)
        draft.client.name = "Direct Participant"
        draft.billing.billsParticipantDirectly = true
        draft.billing.authority = Core.BillingAuthority.planManager.rawValue
        draft.lineItems[0].itemDescription = "Direct support"

        let result = try await actor.updateInvoice(
            id: id,
            expectedRevision: original.revision,
            draft: draft
        )
        let saved = try #require(result.savedSnapshot)

        #expect(saved.billingAuthority == Core.BillingAuthority.client.rawValue)
        #expect(saved.billParticipantDirectly)

        let context = ModelContext(container)
        let persisted = try #require(
            context.fetch(FetchDescriptor<Invoice>()).first(where: { $0.id == id })
        )
        #expect(persisted.billingAuthority == .client)
    }

    @MainActor
    @Test func ClientPickerLoadsBillingSnapshotAndPersistsRelationship() async throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let context = ModelContext(container)

        let clientAddress = Address()
        clientAddress.streetNumber = "12"
        clientAddress.streetName = "River Street"
        clientAddress.city = "Brisbane"
        clientAddress.state = "QLD"
        clientAddress.postcode = "4000"

        let payeeAddress = Address()
        payeeAddress.streetNumber = "4"
        payeeAddress.streetName = "Guardian Road"
        payeeAddress.city = "Brisbane"
        payeeAddress.state = "QLD"
        payeeAddress.postcode = "4001"

        let payee = Payee(fullName: "Jordan Guardian")
        payee.email = "guardian@example.com"
        payee.phone = "07 3000 0000"
        payee.address = payeeAddress

        let client = Client(
            ndisNumber: "4300123456",
            fullName: "Alex Participant",
            email: "alex@example.com",
            phone: "0400 000 000",
            billingAuthority: .parentGuardian
        )
        client.address = clientAddress
        client.payee = payee
        context.insert(clientAddress)
        context.insert(payeeAddress)
        context.insert(payee)
        context.insert(client)
        try context.save()

        let actor = InvoiceModelActor(modelContainer: container)
        let invoiceID = try await actor.createInvoice()
        let viewModel = InvoiceEditorViewModel(actor: actor)
        await viewModel.bootstrap(preferredInvoiceID: invoiceID)
        await viewModel.loadClientOptions()

        viewModel.selectClient(id: client.id)
        #expect(viewModel.clientName == "Alex Participant")
        #expect(viewModel.clientAddress == "12 River Street, Brisbane, QLD, 4000")
        #expect(viewModel.clientTaxID == "4300123456")
        #expect(viewModel.billingAuthority == Core.BillingAuthority.parentGuardian.rawValue)
        #expect(viewModel.billToName == "Jordan Guardian")
        #expect(viewModel.billToEmail == "guardian@example.com")
        #expect(!(viewModel.billParticipantDirectly))

        viewModel.lineItems[0].itemDescription = "Support service"
        await viewModel.saveCurrentInvoice()

        let persistedValue = try await actor.fetchInvoice(id: invoiceID)
        let persisted = try #require(persistedValue)
        #expect(persisted.clientID == client.id)
        #expect(persisted.clientName == "Alex Participant")
        #expect(persisted.billToName == "Jordan Guardian")
        #expect(persisted.billToPhone == "07 3000 0000")
    }

    @MainActor
    @Test func ClientOptionsLoadAfterColdWorkspaceReceivesFirstSelection() async throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let context = ModelContext(container)
        let client = Client(
            ndisNumber: "4300987654",
            fullName: "Cold Workspace Client"
        )
        let invoice = Invoice(invoiceNumber: "INV-COLD-SELECTION")
        context.insert(client)
        context.insert(invoice)
        try context.save()

        let viewModel = InvoiceEditorViewModel(
            actor: InvoiceModelActor(modelContainer: container)
        )
        await viewModel.bootstrap(preferredInvoiceID: nil)
        #expect(viewModel.clientOptions.isEmpty)

        await viewModel.selectInvoice(id: invoice.id)
        await viewModel.loadClientOptionsIfNeeded()

        #expect(viewModel.currentInvoice?.id == invoice.id)
        #expect(viewModel.clientOptions.map(\.id) == [client.id])
        #expect(viewModel.clientOptionsLoadError == nil)
    }

    @Test func CreateAppliesSharedDefaultsAndSupportsManualInvoiceNumber() async throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let actor = InvoiceModelActor(modelContainer: container)
        let defaults = InvoiceCreationDefaults(
            paymentTermsDays: 7,
            taxRate: 15,
            showsTaxSummary: false,
            autoGeneratesInvoiceNumbers: false,
            notes: "Thank you for your business.",
            paymentTermsText: "Payment due in seven days."
        )

        let id = try await actor.createInvoice(defaults: defaults)
        let createdValue = try await actor.fetchInvoice(id: id)
        let created = try #require(createdValue)
        #expect(created.invoiceNumber == "")
        #expect(created.defaultTaxRate == 15)
        #expect(created.lineItems.first?.taxRate == 15)
        #expect(created.paymentTerms == "Payment due in seven days.")
        #expect(created.notes == "Thank you for your business.")
        #expect(!(created.showsTaxSummary))
        #expect(Calendar.current.dateComponents([.day], from: created.issueDate, to: created.dueDate).day == 7)

        var draft = InvoiceDraft(created)
        draft.invoiceNumber = "MANUAL-001"
        draft.client.name = "Manual Number Client"
        draft.lineItems[0].itemDescription = "Support"
        let result = try await actor.updateInvoice(
            id: id,
            expectedRevision: created.revision,
            draft: draft
        )
        #expect(result.isValid)

        let savedValue = try await actor.fetchInvoice(id: id)
        let saved = try #require(savedValue)
        #expect(saved.invoiceNumber == "MANUAL-001")
        #expect(saved.notes == defaults.notes)
        #expect(!(saved.showsTaxSummary))
    }

    @Test func CreateCapturesTemplateEditorDefaultsAtFeatureBoundary() async throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let actor = InvoiceModelActor(modelContainer: container)
        let creationDefaults = InvoiceCreationDefaults(
            paymentTermsDays: 14,
            taxRate: 10,
            showsTaxSummary: true,
            autoGeneratesInvoiceNumbers: true,
            notes: "",
            paymentTermsText: ""
        )
        var configuration = InvoiceTemplateConfiguration.default
        configuration.accentTheme = .forest
        configuration.headerStyle = .fullBleed
        configuration.showPaymentTerms = false
        let templateDefaults = InvoiceTemplateDefaults(
            paperSize: .legal,
            pageOrientation: .landscape,
            configuration: configuration
        )

        let id = try await actor.createInvoice(
            defaults: creationDefaults,
            templateDefaults: templateDefaults
        )
        let createdValue = try await actor.fetchInvoice(id: id)
        let created = try #require(createdValue)

        #expect(created.paperSize == .legal)
        #expect(created.pageOrientation == .landscape)
        #expect(created.templateConfiguration.accentTheme == .forest)
        #expect(created.templateConfiguration.headerStyle == .fullBleed)
        #expect(!(created.templateConfiguration.showPaymentTerms))
    }

    @MainActor
    @Test func BootstrapRestoresPreferredInvoiceSelection() async throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let actor = InvoiceModelActor(modelContainer: container)
        _ = try await actor.createInvoice()
        let preferredID = try await actor.createInvoice()
        let viewModel = InvoiceEditorViewModel(actor: actor)

        await viewModel.bootstrap(preferredInvoiceID: preferredID)

        #expect(viewModel.selectedInvoiceID == preferredID)
        #expect(viewModel.currentInvoice?.id == preferredID)
    }

    @MainActor
    @Test func InvoiceSelectionWaitsForActiveDocumentGeneration() async throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let actor = InvoiceModelActor(modelContainer: container)
        let firstID = try await actor.createInvoice()
        let secondID = try await actor.createInvoice()
        let viewModel = InvoiceEditorViewModel(actor: actor)
        await viewModel.bootstrap(preferredInvoiceID: firstID)

        viewModel.isGeneratingDocument = true
        let selectionTask = Task { @MainActor in
            await viewModel.selectInvoice(id: secondID)
        }

        try await Task.sleep(for: .milliseconds(60))
        #expect(viewModel.currentInvoice?.id == firstID)

        viewModel.isGeneratingDocument = false
        await selectionTask.value
        #expect(viewModel.currentInvoice?.id == secondID)
    }

    @MainActor
    @Test func InvoiceSelectionInvalidatesPreviousDocumentPaginationMeasurements() async throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let actor = InvoiceModelActor(modelContainer: container)
        let firstID = try await actor.createInvoice()
        let secondID = try await actor.createInvoice()
        let viewModel = InvoiceEditorViewModel(actor: actor)
        await viewModel.bootstrap(preferredInvoiceID: firstID)
        let (dimensions, _) = InvoicePagination.MeasuredHeights.uniformRows(
            count: 1,
            rowHeight: 44
        )
        viewModel.updateMeasuredDimensions(dimensions)
        #expect(viewModel.measuredDimensions == dimensions)

        await viewModel.selectInvoice(id: secondID)

        #expect(viewModel.selectedInvoiceID == secondID)
        #expect(viewModel.measuredDimensions == nil)
    }

    @MainActor
    @Test func CancelledSelectionDoesNotResumeAfterDocumentGeneration() async throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let actor = InvoiceModelActor(modelContainer: container)
        let firstID = try await actor.createInvoice()
        let secondID = try await actor.createInvoice()
        let viewModel = InvoiceEditorViewModel(actor: actor)
        await viewModel.bootstrap(preferredInvoiceID: firstID)

        viewModel.isGeneratingDocument = true
        let selectionTask = Task { @MainActor in
            await viewModel.selectInvoice(id: secondID)
        }

        try await Task.sleep(for: .milliseconds(60))
        selectionTask.cancel()
        viewModel.isGeneratingDocument = false
        await selectionTask.value

        #expect(viewModel.selectedInvoiceID == firstID)
        #expect(viewModel.currentInvoice?.id == firstID)
    }

    @MainActor
    @Test func FeatureOwnedCreationPreparationSavesCurrentDraftBeforeAllowingCreation() async throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let actor = InvoiceModelActor(modelContainer: container)
        let firstID = try await actor.createInvoice()
        let viewModel = InvoiceEditorViewModel(actor: actor)
        await viewModel.bootstrap(preferredInvoiceID: firstID)

        viewModel.title = "Saved before creation"
        viewModel.clientName = "Prepared Client"
        viewModel.lineItems[0].itemDescription = "Support service"
        let isPrepared = await viewModel.prepareForFeatureOwnedInvoiceCreation()

        #expect(isPrepared)
        #expect(!(viewModel.hasUnsavedChanges))
        #expect(viewModel.selectedInvoiceID == firstID)
        #expect(viewModel.statusMessage == "Changes saved before creating invoice.")
        let persisted = try await actor.fetchInvoice(id: firstID)
        #expect(persisted?.title == "Saved before creation")
        let context = ModelContext(container)
        #expect(try context.fetchCount(FetchDescriptor<Invoice>()) == 1)
    }

    @MainActor
    @Test func FeatureOwnedCreationPreparationBlocksInvalidDraftWithoutCreatingRecord() async throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let actor = InvoiceModelActor(modelContainer: container)
        let id = try await actor.createInvoice()
        let viewModel = InvoiceEditorViewModel(actor: actor)
        await viewModel.bootstrap(preferredInvoiceID: id)
        let savedTitle = viewModel.title

        viewModel.title = "Must remain local"
        viewModel.invoiceNumber = ""
        let isPrepared = await viewModel.prepareForFeatureOwnedInvoiceCreation()

        #expect(!(isPrepared))
        #expect(viewModel.hasUnsavedChanges)
        #expect(viewModel.statusMessage == "Review the Validation section and try again.")
        let persisted = try await actor.fetchInvoice(id: id)
        #expect(persisted?.title == savedTitle)
        let context = ModelContext(container)
        #expect(try context.fetchCount(FetchDescriptor<Invoice>()) == 1)
    }

    @MainActor
    @Test func LaterSelectionSupersedesExternalCloseWaitingForDocumentGeneration() async throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let actor = InvoiceModelActor(modelContainer: container)
        let firstID = try await actor.createInvoice()
        let secondID = try await actor.createInvoice()
        let viewModel = InvoiceEditorViewModel(actor: actor)
        await viewModel.bootstrap(preferredInvoiceID: firstID)

        viewModel.isGeneratingDocument = true
        let closeTask = Task { @MainActor in
            await viewModel.closeInvoiceDeletedExternally(id: firstID)
        }
        try await Task.sleep(for: .milliseconds(30))
        let selectionTask = Task { @MainActor in
            await viewModel.selectInvoice(id: secondID)
        }
        try await Task.sleep(for: .milliseconds(30))

        viewModel.isGeneratingDocument = false
        await closeTask.value
        await selectionTask.value

        #expect(viewModel.selectedInvoiceID == secondID)
        #expect(viewModel.currentInvoice?.id == secondID)
    }

    @MainActor
    @Test func BootstrapWithoutSelectionDoesNotClaimListOwnership() async throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let actor = InvoiceModelActor(modelContainer: container)
        _ = try await actor.createInvoice()
        let viewModel = InvoiceEditorViewModel(actor: actor)

        await viewModel.bootstrap()

        #expect(viewModel.selectedInvoiceID == nil)
        #expect(viewModel.currentInvoice == nil)
        #expect(viewModel.statusMessage == nil)
    }

    @MainActor
    @Test func EditorSessionPreservesInvalidDraftAcrossWorkspaceReentry() async throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let actor = InvoiceModelActor(modelContainer: container)
        let id = try await actor.createInvoice()
        let session = InvoiceEditorSession(modelContainer: container)

        await session.viewModel.bootstrap(preferredInvoiceID: id)
        session.viewModel.title = "Unfinished session draft"
        #expect(session.viewModel.hasUnsavedChanges)

        await session.viewModel.saveBeforeLeavingWorkspace()
        await session.viewModel.bootstrap(preferredInvoiceID: id)

        #expect(session.viewModel.title == "Unfinished session draft")
        #expect(session.viewModel.hasUnsavedChanges)
        #expect(session.viewModel.currentInvoice?.id == id)
    }

    @MainActor
    @Test func WorkspaceReentryUsesDraftTransitionBeforeOpeningDifferentInvoice() async throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let actor = InvoiceModelActor(modelContainer: container)
        let firstID = try await actor.createInvoice()
        let secondID = try await actor.createInvoice()
        let viewModel = InvoiceEditorViewModel(actor: actor)
        await viewModel.bootstrap(preferredInvoiceID: firstID)
        viewModel.title = "Unfinished routed draft"
        viewModel.updateNumericInputValidity(id: "invoice.discountAmount", isInvalid: true)

        await viewModel.openForWorkspace(requestedInvoiceID: secondID)

        #expect(viewModel.selectedInvoiceID == firstID)
        #expect(viewModel.currentInvoice?.id == firstID)
        #expect(viewModel.title == "Unfinished routed draft")
        #expect(viewModel.hasPendingDiscardTransition)
        #expect(viewModel.pendingDiscardTransitionTitle == "Discard Changes and Switch Invoices?")
    }

    @MainActor
    @Test func InvalidDraftCanBeDiscardedWhenSwitchingInvoices() async throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let actor = InvoiceModelActor(modelContainer: container)
        let firstID = try await actor.createInvoice()
        let secondID = try await actor.createInvoice()
        let viewModel = InvoiceEditorViewModel(actor: actor)
        await viewModel.bootstrap(preferredInvoiceID: firstID)
        viewModel.title = "Unsaved invalid draft"
        viewModel.updateNumericInputValidity(id: "discountAmount", isInvalid: true)

        await viewModel.selectInvoice(id: secondID)

        #expect(viewModel.selectedInvoiceID == firstID)
        #expect(viewModel.hasPendingDiscardTransition)
        #expect(viewModel.pendingDiscardTransitionTitle == "Discard Changes and Switch Invoices?")
        #expect(viewModel.validationRecoveryRequestRevision == 1)

        let transition = try #require(
            viewModel.prepareToDiscardDraftAndContinueTransition()
        )
        #expect(!(viewModel.hasPendingDiscardTransition))

        // Mirrors confirmationDialog's dismissal write after its button action.
        // Captured destination must survive this presentation-state cleanup.
        viewModel.keepEditingAfterBlockedTransition()
        await viewModel.continueDiscardedTransition(transition)

        #expect(viewModel.selectedInvoiceID == secondID)
        #expect(viewModel.currentInvoice?.id == secondID)
        #expect(!(viewModel.hasPendingDiscardTransition))
        #expect(!(viewModel.hasInvalidNumericInput))
        #expect(viewModel.statusMessage == "Unsaved changes discarded.")
    }

    @MainActor
    @Test func RevisionConflictResolutionSurvivesDialogDismissalWrite() async throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let actor = InvoiceModelActor(modelContainer: container)
        let id = try await actor.createInvoice()
        let viewModel = InvoiceEditorViewModel(actor: actor)
        await viewModel.bootstrap(preferredInvoiceID: id)

        let originalValue = try await actor.fetchInvoice(id: id)
        let original = try #require(originalValue)
        var remoteDraft = InvoiceDraft(original)
        remoteDraft.title = "Saved in another window"
        remoteDraft.client.name = "Conflict Test Client"
        let remoteUpdate = try await actor.updateInvoice(
            id: id,
            expectedRevision: original.revision,
            draft: remoteDraft
        )
        #expect(remoteUpdate.isValid)

        viewModel.title = "Local conflicting draft"
        viewModel.clientName = "Conflict Test Client"
        await viewModel.saveCurrentInvoice()
        #expect(viewModel.hasRevisionConflict)
        #expect(viewModel.revisionConflictCanReload)

        let resolution = try #require(
            viewModel.beginRevisionConflictResolution(.reloadLatest)
        )
        #expect(viewModel.isResolvingRevisionConflict)

        // Mirrors confirmationDialog's dismissal write after its button action.
        // Active resolution must retain conflict context until async work settles.
        viewModel.keepEditingAfterRevisionConflict()
        #expect(viewModel.hasRevisionConflict)
        #expect(viewModel.revisionConflictCanReload)

        await viewModel.continueRevisionConflictResolution(resolution)

        #expect(!(viewModel.isResolvingRevisionConflict))
        #expect(!(viewModel.hasRevisionConflict))
        #expect(viewModel.title == "Saved in another window")
        #expect(viewModel.statusMessage == "Reloaded the latest saved invoice.")
    }

    @MainActor
    @Test func DeletionDiscardsInvalidLocalInputAfterConfirmation() async throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let actor = InvoiceModelActor(modelContainer: container)
        let id = try await actor.createInvoice()
        let viewModel = InvoiceEditorViewModel(actor: actor)
        await viewModel.bootstrap(preferredInvoiceID: id)
        viewModel.updateNumericInputValidity(id: "lineItem.invalid.quantity", isInvalid: true)

        await viewModel.deleteSelectedInvoice()

        let deletedInvoice = try await actor.fetchInvoice(id: id)
        #expect(deletedInvoice == nil)
        #expect(viewModel.selectedInvoiceID == nil)
        #expect(viewModel.currentInvoice == nil)
        #expect(!(viewModel.hasInvalidNumericInput))
        #expect(viewModel.statusMessage == "Invoice deleted.")
    }

    @MainActor
    @Test func EditorSessionPublishesInsertUpdateDuplicateAndDeleteMutations() async throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let actor = InvoiceModelActor(modelContainer: container)
        let createdID = try await actor.createInvoice()
        let session = InvoiceEditorSession(modelContainer: container)
        var mutations: [InvoiceEditorMutation] = []
        session.setMutationHandler { mutations.append($0) }

        await session.viewModel.bootstrap(preferredInvoiceID: createdID)
        session.viewModel.clientName = "Mutation Client"
        session.viewModel.lineItems[0].itemDescription = "Support service"
        await session.viewModel.saveCurrentInvoice()
        await session.viewModel.duplicateSelectedInvoice()
        let duplicatedID = try #require(session.viewModel.selectedInvoiceID)
        await session.viewModel.deleteSelectedInvoice()

        #expect(mutations == [
            .updated(createdID),
            .inserted(duplicatedID),
            .deleted(duplicatedID),
        ])
    }

    @MainActor
    @Test func OwningFeatureDeletionClosesMatchingDraftWithoutSavingIt() async throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let actor = InvoiceModelActor(modelContainer: container)
        let deletedID = try await actor.createInvoice()
        let preservedID = try await actor.createInvoice()
        let session = InvoiceEditorSession(modelContainer: container)
        await session.viewModel.bootstrap(preferredInvoiceID: deletedID)
        session.viewModel.title = "Unsaved local title"
        #expect(session.viewModel.hasUnsavedChanges)

        let unrelatedLease = await session.prepareForDeletingInvoices([preservedID])
        #expect(unrelatedLease == nil)
        #expect(session.viewModel.currentInvoice?.id == deletedID)
        #expect(session.viewModel.hasUnsavedChanges)

        let cancelledLease = await session.prepareForDeletingInvoices([deletedID])
        #expect(cancelledLease != nil)
        session.cancelDeletingInvoices(cancelledLease)
        #expect(session.viewModel.currentInvoice?.id == deletedID)
        #expect(session.viewModel.hasUnsavedChanges)

        let committedLease = await session.prepareForDeletingInvoices([deletedID])
        session.completeDeletingInvoices(committedLease, deletedInvoiceIDs: [deletedID])
        #expect(session.viewModel.selectedInvoiceID == nil)
        #expect(session.viewModel.currentInvoice == nil)
        #expect(!(session.viewModel.hasUnsavedChanges))
        #expect(session.viewModel.statusMessage == "Closed the deleted invoice.")

        let persistedValue = try await actor.fetchInvoice(id: deletedID)
        let persisted = try #require(persistedValue)
        #expect(persisted.title != "Unsaved local title")
    }

    @MainActor
    @Test func OwningFeatureDeletionWaitsForDocumentWorkBeforeClosingDraft() async throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let actor = InvoiceModelActor(modelContainer: container)
        let deletedID = try await actor.createInvoice()
        let session = InvoiceEditorSession(modelContainer: container)
        await session.viewModel.bootstrap(preferredInvoiceID: deletedID)
        session.viewModel.title = "Draft removed with invoice"
        session.viewModel.isGeneratingDocument = true

        let preparationTask = Task { @MainActor in
            await session.prepareForDeletingInvoices([deletedID])
        }
        try await Task.sleep(for: .milliseconds(30))

        #expect(session.viewModel.currentInvoice?.id == deletedID)
        #expect(session.viewModel.hasUnsavedChanges)

        session.viewModel.isGeneratingDocument = false
        let lease = await preparationTask.value

        #expect(lease != nil)
        #expect(session.viewModel.isBusy)
        #expect(session.viewModel.currentInvoice?.id == deletedID)

        session.completeDeletingInvoices(lease, deletedInvoiceIDs: [deletedID])

        #expect(session.viewModel.selectedInvoiceID == nil)
        #expect(session.viewModel.currentInvoice == nil)
        #expect(!(session.viewModel.hasUnsavedChanges))
    }

    @MainActor
    @Test func LeavingWorkspacePersistsValidDraft() async throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let actor = InvoiceModelActor(modelContainer: container)
        let id = try await actor.createInvoice()
        let session = InvoiceEditorSession(modelContainer: container)

        await session.viewModel.bootstrap(preferredInvoiceID: id)
        session.viewModel.clientName = "Saved Client"
        session.viewModel.lineItems[0].itemDescription = "Support service"

        await session.viewModel.saveBeforeLeavingWorkspace()

        let persistedValue = try await actor.fetchInvoice(id: id)
        let persisted = try #require(persistedValue)
        #expect(persisted.clientName == "Saved Client")
        #expect(persisted.lineItems.first?.itemDescription == "Support service")
        #expect(!(session.viewModel.hasUnsavedChanges))
    }

    @MainActor
    @Test func WorkspaceHandoffPersistsValidDraftBeforeAllowingNavigation() async throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let actor = InvoiceModelActor(modelContainer: container)
        let id = try await actor.createInvoice()
        let session = InvoiceEditorSession(modelContainer: container)
        await session.viewModel.bootstrap(preferredInvoiceID: id)
        session.viewModel.title = "Saved before template handoff"
        session.viewModel.clientName = "Saved Client"
        session.viewModel.lineItems[0].itemDescription = "Support service"

        let canNavigate = await session.viewModel.prepareForWorkspaceHandoff()
        let persisted = try await actor.fetchInvoice(id: id)

        #expect(canNavigate)
        #expect(!(session.viewModel.hasUnsavedChanges))
        #expect(persisted?.title == "Saved before template handoff")
    }

    @MainActor
    @Test func WorkspaceHandoffKeepsInvalidDraftOpenAndRejectsNavigation() async throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let actor = InvoiceModelActor(modelContainer: container)
        let id = try await actor.createInvoice()
        let session = InvoiceEditorSession(modelContainer: container)
        await session.viewModel.bootstrap(preferredInvoiceID: id)
        session.viewModel.title = "Invalid draft stays open"
        session.viewModel.updateNumericInputValidity(
            id: "invoice.discountAmount",
            isInvalid: true
        )

        let canNavigate = await session.viewModel.prepareForWorkspaceHandoff()

        #expect(!(canNavigate))
        #expect(session.viewModel.selectedInvoiceID == id)
        #expect(session.viewModel.title == "Invalid draft stays open")
        #expect(session.viewModel.hasUnsavedChanges)
        #expect(session.viewModel.statusMessage == "Enter valid numeric values before saving.")
        #expect(session.viewModel.validationRecoveryRequestRevision == 1)
    }

    @MainActor
    @Test func LeavingWorkspaceWaitsForActiveDocumentWorkBeforeSaving() async throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let actor = InvoiceModelActor(modelContainer: container)
        let id = try await actor.createInvoice()
        let session = InvoiceEditorSession(modelContainer: container)
        await session.viewModel.bootstrap(preferredInvoiceID: id)
        let originalTitle = session.viewModel.title
        session.viewModel.title = "Saved after document work"
        session.viewModel.clientName = "Saved Client"
        session.viewModel.lineItems[0].itemDescription = "Support service"
        session.viewModel.isGeneratingDocument = true

        let saveTask = Task { @MainActor in
            await session.viewModel.saveBeforeLeavingWorkspace()
        }
        try await Task.sleep(for: .milliseconds(50))

        #expect(session.viewModel.currentInvoice?.title == originalTitle)
        #expect(session.viewModel.hasUnsavedChanges)

        session.viewModel.isGeneratingDocument = false
        await saveTask.value

        #expect(session.viewModel.statusMessage == "Changes saved.")

        let saved = try await actor.fetchInvoice(id: id)
        #expect(saved?.title == "Saved after document work")
        #expect(!(session.viewModel.hasUnsavedChanges))
    }

    @MainActor
    @Test func ValidationIssuesLinkToRecoverableInspectorFields() async throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let actor = InvoiceModelActor(modelContainer: container)
        let id = try await actor.createInvoice()
        let viewModel = InvoiceEditorViewModel(actor: actor)
        await viewModel.bootstrap(preferredInvoiceID: id)

        viewModel.invoiceNumber = ""
        viewModel.clientName = ""
        viewModel.dueDate = viewModel.issueDate.addingTimeInterval(-86_400)
        viewModel.currencyCode = "invalid"
        viewModel.defaultTaxRate = -1
        viewModel.discountPercent = 101
        viewModel.discountAmount = -1
        viewModel.creditApplied = -1
        viewModel.lineItems = []

        #expect(viewModel.validationRecoveryRequestRevision == 0)
        await viewModel.saveCurrentInvoice()

        let targets = Set(viewModel.validationIssues.compactMap(\.target))
        #expect(targets.contains(.invoiceNumber))
        #expect(targets.contains(.clientName))
        #expect(targets.contains(.dueDate))
        #expect(targets.contains(.currencyCode))
        #expect(targets.contains(.defaultTaxRate))
        #expect(targets.contains(.discountPercent))
        #expect(targets.contains(.discountAmount))
        #expect(targets.contains(.creditApplied))
        #expect(targets.contains(.lineItems))
        #expect(targets.count == 9)
        #expect(viewModel.statusMessage == "Review the Validation section and try again.")
        #expect(viewModel.validationRecoveryRequestRevision == 1)
    }

    @MainActor
    @Test func PublicStoreCreatesAndExportsUsingAppContainer() async throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let id = try await InvoiceEditorStore.createInvoice(in: container)

        let firstPDF = try await InvoiceEditorStore.temporaryPDF(
            invoiceID: id,
            in: container
        )
        let secondPDF = try await InvoiceEditorStore.temporaryPDF(
            invoiceID: id,
            in: container
        )
        defer {
            firstPDF.discard()
            secondPDF.discard()
        }

        let data = try Data(contentsOf: firstPDF.url)
        #expect(data.count > 100)
        #expect(data.prefix(4) == Data("%PDF".utf8))
        #expect(firstPDF.url.lastPathComponent == secondPDF.url.lastPathComponent)
        #expect(firstPDF.url != secondPDF.url)

        let discardedURL = firstPDF.url
        firstPDF.discard()
        #expect(!(FileManager.default.fileExists(atPath: discardedURL.path)))
    }

    @MainActor
    @Test func EditorSessionBulkDocumentSavesAndRendersActiveDraft() async throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let actor = InvoiceModelActor(modelContainer: container)
        let id = try await actor.createInvoice()
        let session = InvoiceEditorSession(modelContainer: container)
        await session.viewModel.bootstrap(preferredInvoiceID: id)
        session.viewModel.invoiceNumber = "INV-LIVE-DRAFT"
        session.viewModel.clientName = "Live Draft Client"

        let pdf = try await session.temporaryPDF(invoiceID: id)
        defer { pdf.discard() }

        let saved = try await actor.fetchInvoice(id: id)
        #expect(saved?.invoiceNumber == "INV-LIVE-DRAFT")
        #expect(pdf.url.lastPathComponent == "Invoice-INV-LIVE-DRAFT.pdf")
        #expect(!(session.viewModel.hasUnsavedChanges))
    }

    @MainActor
    @Test func EditorSessionBulkDocumentPreservesInvalidActiveDraft() async throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let actor = InvoiceModelActor(modelContainer: container)
        let id = try await actor.createInvoice()
        let originalSnapshot = try await actor.fetchInvoice(id: id)
        let original = try #require(originalSnapshot)
        let session = InvoiceEditorSession(modelContainer: container)
        await session.viewModel.bootstrap(preferredInvoiceID: id)
        session.viewModel.invoiceNumber = ""

        do {
            _ = try await session.temporaryPDF(invoiceID: id)
            Issue.record("Expected invalid active draft to block PDF generation")
        } catch let error as InvoiceEditorSessionDocumentError {
            #expect(error == .activeDraftCouldNotBeSaved)
        }

        let persisted = try await actor.fetchInvoice(id: id)
        #expect(persisted?.invoiceNumber == original.invoiceNumber)
        #expect(session.viewModel.invoiceNumber == "")
        #expect(session.viewModel.hasUnsavedChanges)
    }
}

private struct LegacyConfigurationEnvelope: Codable {
    var version = 1
    var title = "Legacy Layout"
    var billParticipantDirectly = true
    var sellerPhone: String
    var billToPhone = "billing phone"
    var clientPhone: String
    var defaultTaxRate: Decimal
    var discountAmount: Decimal = 0
    var paperSize: PaperSize = .default
    var pageOrientation: PageOrientation = .portrait
    var template: InvoiceTemplateConfiguration = .default
}
