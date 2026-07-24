import Core
import Data
import Foundation
import SwiftData
import XCTest
@testable import InvoiceTableLayoutEditor

final class InvoiceModelActorIntegrationTests: XCTestCase {
    func testSharedCoreEditorConfigurationLoadsWithFeaturePresentationDefaults() async throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let context = ModelContext(container)
        let invoice = Core.Invoice(invoiceNumber: "INV-SHARED-STATE")
        invoice.invoiceEditorStateData = try Core.InvoiceEditorConfiguration(
            title: "NDIS Invoice",
            billParticipantDirectly: false,
            billToPhone: "07 3000 0000",
            discountAmount: 15,
            showsTaxSummary: false
        ).encoded()
        context.insert(invoice)
        try context.save()

        let snapshot = try await InvoiceModelActor(modelContainer: container).fetchInvoice(id: invoice.id)

        XCTAssertEqual(snapshot?.title, "NDIS Invoice")
        XCTAssertEqual(snapshot?.billParticipantDirectly, false)
        XCTAssertEqual(snapshot?.billToPhone, "07 3000 0000")
        XCTAssertEqual(snapshot?.discountAmount, 15)
        XCTAssertEqual(snapshot?.showsTaxSummary, false)
        XCTAssertEqual(snapshot?.paperSize, .default)
        XCTAssertEqual(snapshot?.pageOrientation, .portrait)
        XCTAssertEqual(snapshot?.templateConfiguration, .default)
    }

    func testEditorOpensExistingCoreInvoiceWithoutEditorState() async throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let context = ModelContext(container)
        let invoice = Core.Invoice(invoiceNumber: "INV-2026-001")
        invoice.clientName = "Existing Client"
        invoice.businessName = "Existing Provider"
        invoice.currencyCode = "AUD"
        invoice.effectiveStatus = .cancelled
        let item = Core.InvoiceItem(itemDescription: "Existing support")
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
        let fetched = try XCTUnwrap(fetchedValue)
        XCTAssertEqual(fetched.invoiceNumber, "INV-2026-001")
        XCTAssertEqual(fetched.clientName, "Existing Client")
        XCTAssertEqual(fetched.status, .cancelled)
        XCTAssertEqual(fetched.lineItems.first?.itemDescription, "Existing support")
        XCTAssertEqual(fetched.grandTotal, 132)
        XCTAssertEqual(fetched.templateConfiguration, .default)

        var layoutEdit = InvoiceDraft(fetched)
        layoutEdit.title = "Cancelled Invoice Layout"
        let validation = try await actor.updateInvoice(
            id: invoice.id,
            expectedRevision: fetched.revision,
            draft: layoutEdit
        )
        XCTAssertTrue(validation.isValid)
        XCTAssertEqual(validation.savedSnapshot?.revision, fetched.revision + 1)
        XCTAssertEqual(validation.savedSnapshot?.title, "Cancelled Invoice Layout")
        let afterLayoutEditValue = try await actor.fetchInvoice(id: invoice.id)
        let afterLayoutEdit = try XCTUnwrap(afterLayoutEditValue)
        XCTAssertEqual(afterLayoutEdit.status, .cancelled)
        XCTAssertEqual(invoice.effectiveStatus, .cancelled)
    }

    func testEditorFallsBackForMalformedPersistedCurrencyAtSnapshotBoundary() async throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let context = ModelContext(container)
        let invoice = Core.Invoice(invoiceNumber: "INV-LEGACY-CURRENCY")
        invoice.currencyCode = "12!"
        context.insert(invoice)
        try context.save()

        let snapshot = try await InvoiceModelActor(modelContainer: container).fetchInvoice(id: invoice.id)

        XCTAssertEqual(snapshot?.currencyCode, InvoiceCurrencyCode.defaultValue)
    }

    func testExistingInvoiceWithoutEditorStateIgnoresCurrentTemplateDefaults() async throws {
        let preferences = UserDefaults.standard
        let original = preferences.data(forKey: InvoiceTemplatePreferenceStore.preferenceKey)
        defer {
            if let original {
                preferences.set(original, forKey: InvoiceTemplatePreferenceStore.preferenceKey)
            } else {
                preferences.removeObject(forKey: InvoiceTemplatePreferenceStore.preferenceKey)
            }
        }

        var currentTemplate = InvoiceTemplatePreset.modern.configuration
        currentTemplate.accentTheme = .forest
        XCTAssertTrue(InvoiceTemplatePreferenceStore.save(
            InvoiceTemplateDefaults(
                paperSize: .legal,
                pageOrientation: .landscape,
                configuration: currentTemplate
            ),
            to: preferences
        ))

        let container = try ModelContainerFactory.makeInMemoryContainer()
        let context = ModelContext(container)
        let existing = Core.Invoice(invoiceNumber: "INV-PRE-TEMPLATE")
        existing.clientName = "Existing Client"
        context.insert(existing)
        try context.save()

        let snapshot = try await InvoiceModelActor(modelContainer: container).fetchInvoice(id: existing.id)

        XCTAssertEqual(snapshot?.paperSize, .default)
        XCTAssertEqual(snapshot?.pageOrientation, .portrait)
        XCTAssertEqual(snapshot?.templateConfiguration, .default)
    }

    func testExistingRelationshipDataBackfillsMissingInvoiceSnapshots() async throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let context = ModelContext(container)
        let clientAddress = Core.Address()
        clientAddress.streetNumber = "8"
        clientAddress.streetName = "Market Street"
        clientAddress.city = "Brisbane"
        clientAddress.state = "QLD"
        clientAddress.postcode = "4000"
        let businessAddress = Core.Address()
        businessAddress.streetNumber = "14"
        businessAddress.streetName = "Provider Lane"
        businessAddress.city = "Brisbane"
        businessAddress.state = "QLD"
        businessAddress.postcode = "4001"
        let business = Core.Business(abn: "53 004 085 616")
        business.name = "Example Supports"
        business.email = "billing@example-supports.com"
        business.phone = "07 3000 0000"
        business.address = businessAddress
        business.bankName = "Example Bank"
        business.bankAccountName = "Example Supports"
        business.bankBSB = "123-456"
        business.bankAccountNumber = "12345678"
        let manager = Core.PlanManager(abn: "12 345 678 901")
        manager.name = "Example Plan Management"
        manager.email = "accounts@example.com"
        manager.phone = "07 3111 1111"
        let client = Core.Client(
            ndisNumber: "4300999999",
            fullName: "Legacy Participant",
            email: "participant@example.com",
            phone: "0400 999 999",
            billingAuthority: .planManager
        )
        client.address = clientAddress
        client.planManager = manager
        let invoice = Core.Invoice(invoiceNumber: "INV-LINKED")
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
        let fetched = try XCTUnwrap(fetchedValue)
        XCTAssertEqual(fetched.sellerName, "Example Supports")
        XCTAssertEqual(fetched.sellerAddress, "14 Provider Lane, Brisbane, QLD, 4001")
        XCTAssertEqual(fetched.sellerEmail, "billing@example-supports.com")
        XCTAssertEqual(fetched.sellerPhone, "07 3000 0000")
        XCTAssertEqual(fetched.sellerTaxID, "53 004 085 616")
        XCTAssertEqual(fetched.bankName, "Example Bank")
        XCTAssertEqual(fetched.bankAccountName, "Example Supports")
        XCTAssertEqual(fetched.bankBSB, "123-456")
        XCTAssertEqual(fetched.bankAccountNumber, "12345678")
        XCTAssertEqual(fetched.clientID, client.id)
        XCTAssertEqual(fetched.clientName, "Legacy Participant")
        XCTAssertEqual(fetched.clientAddress, "8 Market Street, Brisbane, QLD, 4000")
        XCTAssertEqual(fetched.clientEmail, "participant@example.com")
        XCTAssertEqual(fetched.clientPhone, "0400 999 999")
        XCTAssertEqual(fetched.clientTaxID, "4300999999")
        XCTAssertEqual(fetched.billingAuthority, Core.BillingAuthority.planManager.rawValue)
        XCTAssertEqual(fetched.billToName, "Example Plan Management")
        XCTAssertEqual(fetched.billToEmail, "accounts@example.com")
        XCTAssertEqual(fetched.billToPhone, "07 3111 1111")
        XCTAssertFalse(fetched.billParticipantDirectly)
    }

    func testExistingPayeeSnapshotsBackfillParentGuardianRecipient() async throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let context = ModelContext(container)
        let payeeAddress = Core.Address()
        payeeAddress.streetNumber = "25"
        payeeAddress.streetName = "Guardian Road"
        payeeAddress.city = "Brisbane"
        payeeAddress.state = "QLD"
        payeeAddress.postcode = "4002"
        let invoice = Core.Invoice(invoiceNumber: "INV-PAYEE-SNAPSHOT")
        invoice.billingAuthority = .parentGuardian
        invoice.payeeName = "Morgan Guardian"
        invoice.payeeEmail = "morgan@example.com"
        invoice.payeePhone = "0400 111 222"
        invoice.payeeAddressSnapshot = payeeAddress.snapshot()
        context.insert(invoice)
        try context.save()

        let fetchedValue = try await InvoiceModelActor(modelContainer: container).fetchInvoice(id: invoice.id)
        let fetched = try XCTUnwrap(fetchedValue)

        XCTAssertEqual(fetched.billToName, "Morgan Guardian")
        XCTAssertEqual(fetched.billToEmail, "morgan@example.com")
        XCTAssertEqual(fetched.billToPhone, "0400 111 222")
        XCTAssertEqual(fetched.billToAddress, "25 Guardian Road, Brisbane, QLD, 4002")
        XCTAssertEqual(fetched.billingAuthority, Core.BillingAuthority.parentGuardian.rawValue)
        XCTAssertFalse(fetched.billParticipantDirectly)
    }

    func testFirstClassFieldsOverrideLegacyEditorEnvelopeShadows() async throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let context = ModelContext(container)
        let invoice = Core.Invoice(invoiceNumber: "INV-2026-LEGACY")
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
        let item = Core.InvoiceItem(itemDescription: "Legacy taxed item")
        item.quantity = 1
        item.rate = 100
        item.invoice = invoice
        invoice.items = [item]
        context.insert(invoice)
        context.insert(item)
        try context.save()

        let fetched = try await InvoiceModelActor(modelContainer: container).fetchInvoice(id: invoice.id)
        let snapshot = try XCTUnwrap(fetched)
        XCTAssertEqual(snapshot.sellerPhone, "current seller phone")
        XCTAssertEqual(snapshot.clientPhone, "current client phone")
        XCTAssertEqual(snapshot.defaultTaxRate, 10)
        XCTAssertEqual(snapshot.lineItems.first?.taxRate, 10)
        XCTAssertEqual(snapshot.grandTotal, 110)
    }

    func testEditorUsesAppSchemaForCreateUpdateFetchAndDelete() async throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let actor = InvoiceModelActor(modelContainer: container)

        let id = try await actor.createInvoice()
        let createdSnapshot = try await actor.fetchInvoice(id: id)
        var snapshot = try XCTUnwrap(createdSnapshot)
        XCTAssertEqual(snapshot.revision, 0)
        XCTAssertEqual(snapshot.lineItems.count, 1)

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
        XCTAssertTrue(validation.isValid)
        XCTAssertEqual(validation.savedSnapshot?.revision, 1)
        XCTAssertEqual(validation.savedSnapshot?.clientName, "Taylor Client")

        let updatedSnapshot = try await actor.fetchInvoice(id: id)
        snapshot = try XCTUnwrap(updatedSnapshot)
        XCTAssertEqual(snapshot.revision, 1)
        XCTAssertEqual(snapshot.title, "Service Invoice")
        XCTAssertEqual(snapshot.clientName, "Taylor Client")
        XCTAssertEqual(snapshot.currencyCode, "AUD")
        XCTAssertEqual(snapshot.grandTotal, 209)

        let context = ModelContext(container)
        let invoices = try context.fetch(FetchDescriptor<Core.Invoice>())
        let persisted = try XCTUnwrap(invoices.first { $0.id == id })
        XCTAssertEqual(persisted.invoiceEditorRevision, 1)
        XCTAssertEqual(persisted.clientName, "Taylor Client")
        XCTAssertEqual(persisted.itemsArray.count, 1)
        XCTAssertEqual(persisted.itemsArray[0].itemDescription, "Support service")
        XCTAssertNotNil(persisted.invoiceEditorStateData)

        try await actor.deleteInvoice(id: id, expectedRevision: snapshot.revision)
        let deletedSnapshot = try await actor.fetchInvoice(id: id)
        XCTAssertNil(deletedSnapshot)
    }

    func testPersistenceCanonicalizesDirectBillingOverStaleAuthority() async throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let actor = InvoiceModelActor(modelContainer: container)
        let id = try await actor.createInvoice()
        let originalValue = try await actor.fetchInvoice(id: id)
        let original = try XCTUnwrap(originalValue)
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
        let saved = try XCTUnwrap(result.savedSnapshot)

        XCTAssertEqual(saved.billingAuthority, Core.BillingAuthority.client.rawValue)
        XCTAssertTrue(saved.billParticipantDirectly)

        let context = ModelContext(container)
        let persisted = try XCTUnwrap(
            context.fetch(FetchDescriptor<Core.Invoice>()).first(where: { $0.id == id })
        )
        XCTAssertEqual(persisted.billingAuthority, .client)
    }

    @MainActor
    func testClientPickerLoadsBillingSnapshotAndPersistsRelationship() async throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let context = ModelContext(container)

        let clientAddress = Core.Address()
        clientAddress.streetNumber = "12"
        clientAddress.streetName = "River Street"
        clientAddress.city = "Brisbane"
        clientAddress.state = "QLD"
        clientAddress.postcode = "4000"

        let payeeAddress = Core.Address()
        payeeAddress.streetNumber = "4"
        payeeAddress.streetName = "Guardian Road"
        payeeAddress.city = "Brisbane"
        payeeAddress.state = "QLD"
        payeeAddress.postcode = "4001"

        let payee = Core.Payee(fullName: "Jordan Guardian")
        payee.email = "guardian@example.com"
        payee.phone = "07 3000 0000"
        payee.address = payeeAddress

        let client = Core.Client(
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
        XCTAssertEqual(viewModel.clientName, "Alex Participant")
        XCTAssertEqual(viewModel.clientAddress, "12 River Street, Brisbane, QLD, 4000")
        XCTAssertEqual(viewModel.clientTaxID, "4300123456")
        XCTAssertEqual(viewModel.billingAuthority, Core.BillingAuthority.parentGuardian.rawValue)
        XCTAssertEqual(viewModel.billToName, "Jordan Guardian")
        XCTAssertEqual(viewModel.billToEmail, "guardian@example.com")
        XCTAssertFalse(viewModel.billParticipantDirectly)

        viewModel.lineItems[0].itemDescription = "Support service"
        await viewModel.saveCurrentInvoice()

        let persistedValue = try await actor.fetchInvoice(id: invoiceID)
        let persisted = try XCTUnwrap(persistedValue)
        XCTAssertEqual(persisted.clientID, client.id)
        XCTAssertEqual(persisted.clientName, "Alex Participant")
        XCTAssertEqual(persisted.billToName, "Jordan Guardian")
        XCTAssertEqual(persisted.billToPhone, "07 3000 0000")
    }

    @MainActor
    func testClientOptionsLoadAfterColdWorkspaceReceivesFirstSelection() async throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let context = ModelContext(container)
        let client = Core.Client(
            ndisNumber: "4300987654",
            fullName: "Cold Workspace Client"
        )
        let invoice = Core.Invoice(invoiceNumber: "INV-COLD-SELECTION")
        context.insert(client)
        context.insert(invoice)
        try context.save()

        let viewModel = InvoiceEditorViewModel(
            actor: InvoiceModelActor(modelContainer: container)
        )
        await viewModel.bootstrap(preferredInvoiceID: nil)
        XCTAssertTrue(viewModel.clientOptions.isEmpty)

        await viewModel.selectInvoice(id: invoice.id)
        await viewModel.loadClientOptionsIfNeeded()

        XCTAssertEqual(viewModel.currentInvoice?.id, invoice.id)
        XCTAssertEqual(viewModel.clientOptions.map(\.id), [client.id])
        XCTAssertNil(viewModel.clientOptionsLoadError)
    }

    func testCreateAppliesSharedDefaultsAndSupportsManualInvoiceNumber() async throws {
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
        let created = try XCTUnwrap(createdValue)
        XCTAssertEqual(created.invoiceNumber, "")
        XCTAssertEqual(created.defaultTaxRate, 15)
        XCTAssertEqual(created.lineItems.first?.taxRate, 15)
        XCTAssertEqual(created.paymentTerms, "Payment due in seven days.")
        XCTAssertEqual(created.notes, "Thank you for your business.")
        XCTAssertFalse(created.showsTaxSummary)
        XCTAssertEqual(
            Calendar.current.dateComponents([.day], from: created.issueDate, to: created.dueDate).day,
            7
        )

        var draft = InvoiceDraft(created)
        draft.invoiceNumber = "MANUAL-001"
        draft.client.name = "Manual Number Client"
        draft.lineItems[0].itemDescription = "Support"
        let result = try await actor.updateInvoice(
            id: id,
            expectedRevision: created.revision,
            draft: draft
        )
        XCTAssertTrue(result.isValid)

        let savedValue = try await actor.fetchInvoice(id: id)
        let saved = try XCTUnwrap(savedValue)
        XCTAssertEqual(saved.invoiceNumber, "MANUAL-001")
        XCTAssertEqual(saved.notes, defaults.notes)
        XCTAssertFalse(saved.showsTaxSummary)
    }

    func testCreateCapturesTemplateEditorDefaultsAtFeatureBoundary() async throws {
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
        let created = try XCTUnwrap(createdValue)

        XCTAssertEqual(created.paperSize, .legal)
        XCTAssertEqual(created.pageOrientation, .landscape)
        XCTAssertEqual(created.templateConfiguration.accentTheme, .forest)
        XCTAssertEqual(created.templateConfiguration.headerStyle, .fullBleed)
        XCTAssertFalse(created.templateConfiguration.showPaymentTerms)
    }

    @MainActor
    func testBootstrapRestoresPreferredInvoiceSelection() async throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let actor = InvoiceModelActor(modelContainer: container)
        _ = try await actor.createInvoice()
        let preferredID = try await actor.createInvoice()
        let viewModel = InvoiceEditorViewModel(actor: actor)

        await viewModel.bootstrap(preferredInvoiceID: preferredID)

        XCTAssertEqual(viewModel.selectedInvoiceID, preferredID)
        XCTAssertEqual(viewModel.currentInvoice?.id, preferredID)
    }

    @MainActor
    func testInvoiceSelectionWaitsForActiveDocumentGeneration() async throws {
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
        XCTAssertEqual(viewModel.currentInvoice?.id, firstID)

        viewModel.isGeneratingDocument = false
        await selectionTask.value
        XCTAssertEqual(viewModel.currentInvoice?.id, secondID)
    }

    @MainActor
    func testInvoiceSelectionInvalidatesPreviousDocumentPaginationMeasurements() async throws {
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
        XCTAssertEqual(viewModel.measuredDimensions, dimensions)

        await viewModel.selectInvoice(id: secondID)

        XCTAssertEqual(viewModel.selectedInvoiceID, secondID)
        XCTAssertNil(viewModel.measuredDimensions)
    }

    @MainActor
    func testCancelledSelectionDoesNotResumeAfterDocumentGeneration() async throws {
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

        XCTAssertEqual(viewModel.selectedInvoiceID, firstID)
        XCTAssertEqual(viewModel.currentInvoice?.id, firstID)
    }

    @MainActor
    func testFeatureOwnedCreationPreparationSavesCurrentDraftBeforeAllowingCreation() async throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let actor = InvoiceModelActor(modelContainer: container)
        let firstID = try await actor.createInvoice()
        let viewModel = InvoiceEditorViewModel(actor: actor)
        await viewModel.bootstrap(preferredInvoiceID: firstID)

        viewModel.title = "Saved before creation"
        viewModel.clientName = "Prepared Client"
        viewModel.lineItems[0].itemDescription = "Support service"
        let isPrepared = await viewModel.prepareForFeatureOwnedInvoiceCreation()

        XCTAssertTrue(isPrepared)
        XCTAssertFalse(viewModel.hasUnsavedChanges)
        XCTAssertEqual(viewModel.selectedInvoiceID, firstID)
        XCTAssertEqual(viewModel.statusMessage, "Changes saved before creating invoice.")
        let persisted = try await actor.fetchInvoice(id: firstID)
        XCTAssertEqual(persisted?.title, "Saved before creation")
        let context = ModelContext(container)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Core.Invoice>()), 1)
    }

    @MainActor
    func testFeatureOwnedCreationPreparationBlocksInvalidDraftWithoutCreatingRecord() async throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let actor = InvoiceModelActor(modelContainer: container)
        let id = try await actor.createInvoice()
        let viewModel = InvoiceEditorViewModel(actor: actor)
        await viewModel.bootstrap(preferredInvoiceID: id)
        let savedTitle = viewModel.title

        viewModel.title = "Must remain local"
        viewModel.invoiceNumber = ""
        let isPrepared = await viewModel.prepareForFeatureOwnedInvoiceCreation()

        XCTAssertFalse(isPrepared)
        XCTAssertTrue(viewModel.hasUnsavedChanges)
        XCTAssertEqual(viewModel.statusMessage, "Review the Validation section and try again.")
        let persisted = try await actor.fetchInvoice(id: id)
        XCTAssertEqual(persisted?.title, savedTitle)
        let context = ModelContext(container)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Core.Invoice>()), 1)
    }

    @MainActor
    func testLaterSelectionSupersedesExternalCloseWaitingForDocumentGeneration() async throws {
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

        XCTAssertEqual(viewModel.selectedInvoiceID, secondID)
        XCTAssertEqual(viewModel.currentInvoice?.id, secondID)
    }

    @MainActor
    func testBootstrapWithoutSelectionDoesNotClaimListOwnership() async throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let actor = InvoiceModelActor(modelContainer: container)
        _ = try await actor.createInvoice()
        let viewModel = InvoiceEditorViewModel(actor: actor)

        await viewModel.bootstrap()

        XCTAssertNil(viewModel.selectedInvoiceID)
        XCTAssertNil(viewModel.currentInvoice)
        XCTAssertNil(viewModel.statusMessage)
    }

    @MainActor
    func testEditorSessionPreservesInvalidDraftAcrossWorkspaceReentry() async throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let actor = InvoiceModelActor(modelContainer: container)
        let id = try await actor.createInvoice()
        let session = InvoiceEditorSession(modelContainer: container)

        await session.viewModel.bootstrap(preferredInvoiceID: id)
        session.viewModel.title = "Unfinished session draft"
        XCTAssertTrue(session.viewModel.hasUnsavedChanges)

        await session.viewModel.saveBeforeLeavingWorkspace()
        await session.viewModel.bootstrap(preferredInvoiceID: id)

        XCTAssertEqual(session.viewModel.title, "Unfinished session draft")
        XCTAssertTrue(session.viewModel.hasUnsavedChanges)
        XCTAssertEqual(session.viewModel.currentInvoice?.id, id)
    }

    @MainActor
    func testWorkspaceReentryUsesDraftTransitionBeforeOpeningDifferentInvoice() async throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let actor = InvoiceModelActor(modelContainer: container)
        let firstID = try await actor.createInvoice()
        let secondID = try await actor.createInvoice()
        let viewModel = InvoiceEditorViewModel(actor: actor)
        await viewModel.bootstrap(preferredInvoiceID: firstID)
        viewModel.title = "Unfinished routed draft"
        viewModel.updateNumericInputValidity(id: "invoice.discountAmount", isInvalid: true)

        await viewModel.openForWorkspace(requestedInvoiceID: secondID)

        XCTAssertEqual(viewModel.selectedInvoiceID, firstID)
        XCTAssertEqual(viewModel.currentInvoice?.id, firstID)
        XCTAssertEqual(viewModel.title, "Unfinished routed draft")
        XCTAssertTrue(viewModel.hasPendingDiscardTransition)
        XCTAssertEqual(
            viewModel.pendingDiscardTransitionTitle,
            "Discard Changes and Switch Invoices?"
        )
    }

    @MainActor
    func testInvalidDraftCanBeDiscardedWhenSwitchingInvoices() async throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let actor = InvoiceModelActor(modelContainer: container)
        let firstID = try await actor.createInvoice()
        let secondID = try await actor.createInvoice()
        let viewModel = InvoiceEditorViewModel(actor: actor)
        await viewModel.bootstrap(preferredInvoiceID: firstID)
        viewModel.title = "Unsaved invalid draft"
        viewModel.updateNumericInputValidity(id: "discountAmount", isInvalid: true)

        await viewModel.selectInvoice(id: secondID)

        XCTAssertEqual(viewModel.selectedInvoiceID, firstID)
        XCTAssertTrue(viewModel.hasPendingDiscardTransition)
        XCTAssertEqual(viewModel.pendingDiscardTransitionTitle, "Discard Changes and Switch Invoices?")
        XCTAssertEqual(viewModel.validationRecoveryRequestRevision, 1)

        let transition = try XCTUnwrap(
            viewModel.prepareToDiscardDraftAndContinueTransition()
        )
        XCTAssertFalse(viewModel.hasPendingDiscardTransition)

        // Mirrors confirmationDialog's dismissal write after its button action.
        // Captured destination must survive this presentation-state cleanup.
        viewModel.keepEditingAfterBlockedTransition()
        await viewModel.continueDiscardedTransition(transition)

        XCTAssertEqual(viewModel.selectedInvoiceID, secondID)
        XCTAssertEqual(viewModel.currentInvoice?.id, secondID)
        XCTAssertFalse(viewModel.hasPendingDiscardTransition)
        XCTAssertFalse(viewModel.hasInvalidNumericInput)
        XCTAssertEqual(viewModel.statusMessage, "Unsaved changes discarded.")
    }

    @MainActor
    func testRevisionConflictResolutionSurvivesDialogDismissalWrite() async throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let actor = InvoiceModelActor(modelContainer: container)
        let id = try await actor.createInvoice()
        let viewModel = InvoiceEditorViewModel(actor: actor)
        await viewModel.bootstrap(preferredInvoiceID: id)

        let originalValue = try await actor.fetchInvoice(id: id)
        let original = try XCTUnwrap(originalValue)
        var remoteDraft = InvoiceDraft(original)
        remoteDraft.title = "Saved in another window"
        remoteDraft.client.name = "Conflict Test Client"
        let remoteUpdate = try await actor.updateInvoice(
            id: id,
            expectedRevision: original.revision,
            draft: remoteDraft
        )
        XCTAssertTrue(remoteUpdate.isValid)

        viewModel.title = "Local conflicting draft"
        viewModel.clientName = "Conflict Test Client"
        await viewModel.saveCurrentInvoice()
        XCTAssertTrue(viewModel.hasRevisionConflict)
        XCTAssertTrue(viewModel.revisionConflictCanReload)

        let resolution = try XCTUnwrap(
            viewModel.beginRevisionConflictResolution(.reloadLatest)
        )
        XCTAssertTrue(viewModel.isResolvingRevisionConflict)

        // Mirrors confirmationDialog's dismissal write after its button action.
        // Active resolution must retain conflict context until async work settles.
        viewModel.keepEditingAfterRevisionConflict()
        XCTAssertTrue(viewModel.hasRevisionConflict)
        XCTAssertTrue(viewModel.revisionConflictCanReload)

        await viewModel.continueRevisionConflictResolution(resolution)

        XCTAssertFalse(viewModel.isResolvingRevisionConflict)
        XCTAssertFalse(viewModel.hasRevisionConflict)
        XCTAssertEqual(viewModel.title, "Saved in another window")
        XCTAssertEqual(viewModel.statusMessage, "Reloaded the latest saved invoice.")
    }

    @MainActor
    func testDeletionDiscardsInvalidLocalInputAfterConfirmation() async throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let actor = InvoiceModelActor(modelContainer: container)
        let id = try await actor.createInvoice()
        let viewModel = InvoiceEditorViewModel(actor: actor)
        await viewModel.bootstrap(preferredInvoiceID: id)
        viewModel.updateNumericInputValidity(id: "lineItem.invalid.quantity", isInvalid: true)

        await viewModel.deleteSelectedInvoice()

        let deletedInvoice = try await actor.fetchInvoice(id: id)
        XCTAssertNil(deletedInvoice)
        XCTAssertNil(viewModel.selectedInvoiceID)
        XCTAssertNil(viewModel.currentInvoice)
        XCTAssertFalse(viewModel.hasInvalidNumericInput)
        XCTAssertEqual(viewModel.statusMessage, "Invoice deleted.")
    }

    @MainActor
    func testEditorSessionPublishesInsertUpdateDuplicateAndDeleteMutations() async throws {
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
        let duplicatedID = try XCTUnwrap(session.viewModel.selectedInvoiceID)
        await session.viewModel.deleteSelectedInvoice()

        XCTAssertEqual(
            mutations,
            [
                .updated(createdID),
                .inserted(duplicatedID),
                .deleted(duplicatedID)
            ]
        )
    }

    @MainActor
    func testOwningFeatureDeletionClosesMatchingDraftWithoutSavingIt() async throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let actor = InvoiceModelActor(modelContainer: container)
        let deletedID = try await actor.createInvoice()
        let preservedID = try await actor.createInvoice()
        let session = InvoiceEditorSession(modelContainer: container)
        await session.viewModel.bootstrap(preferredInvoiceID: deletedID)
        session.viewModel.title = "Unsaved local title"
        XCTAssertTrue(session.viewModel.hasUnsavedChanges)

        let unrelatedLease = await session.prepareForDeletingInvoices([preservedID])
        XCTAssertNil(unrelatedLease)
        XCTAssertEqual(session.viewModel.currentInvoice?.id, deletedID)
        XCTAssertTrue(session.viewModel.hasUnsavedChanges)

        let cancelledLease = await session.prepareForDeletingInvoices([deletedID])
        XCTAssertNotNil(cancelledLease)
        session.cancelDeletingInvoices(cancelledLease)
        XCTAssertEqual(session.viewModel.currentInvoice?.id, deletedID)
        XCTAssertTrue(session.viewModel.hasUnsavedChanges)

        let committedLease = await session.prepareForDeletingInvoices([deletedID])
        session.completeDeletingInvoices(committedLease, deletedInvoiceIDs: [deletedID])
        XCTAssertNil(session.viewModel.selectedInvoiceID)
        XCTAssertNil(session.viewModel.currentInvoice)
        XCTAssertFalse(session.viewModel.hasUnsavedChanges)
        XCTAssertEqual(session.viewModel.statusMessage, "Closed the deleted invoice.")

        let persistedValue = try await actor.fetchInvoice(id: deletedID)
        let persisted = try XCTUnwrap(persistedValue)
        XCTAssertNotEqual(persisted.title, "Unsaved local title")
    }

    @MainActor
    func testOwningFeatureDeletionWaitsForDocumentWorkBeforeClosingDraft() async throws {
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

        XCTAssertEqual(session.viewModel.currentInvoice?.id, deletedID)
        XCTAssertTrue(session.viewModel.hasUnsavedChanges)

        session.viewModel.isGeneratingDocument = false
        let lease = await preparationTask.value

        XCTAssertNotNil(lease)
        XCTAssertTrue(session.viewModel.isBusy)
        XCTAssertEqual(session.viewModel.currentInvoice?.id, deletedID)

        session.completeDeletingInvoices(lease, deletedInvoiceIDs: [deletedID])

        XCTAssertNil(session.viewModel.selectedInvoiceID)
        XCTAssertNil(session.viewModel.currentInvoice)
        XCTAssertFalse(session.viewModel.hasUnsavedChanges)
    }

    @MainActor
    func testLeavingWorkspacePersistsValidDraft() async throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let actor = InvoiceModelActor(modelContainer: container)
        let id = try await actor.createInvoice()
        let session = InvoiceEditorSession(modelContainer: container)

        await session.viewModel.bootstrap(preferredInvoiceID: id)
        session.viewModel.clientName = "Saved Client"
        session.viewModel.lineItems[0].itemDescription = "Support service"

        await session.viewModel.saveBeforeLeavingWorkspace()

        let persistedValue = try await actor.fetchInvoice(id: id)
        let persisted = try XCTUnwrap(persistedValue)
        XCTAssertEqual(persisted.clientName, "Saved Client")
        XCTAssertEqual(persisted.lineItems.first?.itemDescription, "Support service")
        XCTAssertFalse(session.viewModel.hasUnsavedChanges)
    }

    @MainActor
    func testWorkspaceHandoffPersistsValidDraftBeforeAllowingNavigation() async throws {
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

        XCTAssertTrue(canNavigate)
        XCTAssertFalse(session.viewModel.hasUnsavedChanges)
        XCTAssertEqual(persisted?.title, "Saved before template handoff")
    }

    @MainActor
    func testWorkspaceHandoffKeepsInvalidDraftOpenAndRejectsNavigation() async throws {
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

        XCTAssertFalse(canNavigate)
        XCTAssertEqual(session.viewModel.selectedInvoiceID, id)
        XCTAssertEqual(session.viewModel.title, "Invalid draft stays open")
        XCTAssertTrue(session.viewModel.hasUnsavedChanges)
        XCTAssertEqual(
            session.viewModel.statusMessage,
            "Enter valid numeric values before saving."
        )
        XCTAssertEqual(session.viewModel.validationRecoveryRequestRevision, 1)
    }

    @MainActor
    func testLeavingWorkspaceWaitsForActiveDocumentWorkBeforeSaving() async throws {
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

        XCTAssertEqual(session.viewModel.currentInvoice?.title, originalTitle)
        XCTAssertTrue(session.viewModel.hasUnsavedChanges)

        session.viewModel.isGeneratingDocument = false
        await saveTask.value

        XCTAssertEqual(session.viewModel.statusMessage, "Changes saved.")

        let saved = try await actor.fetchInvoice(id: id)
        XCTAssertEqual(saved?.title, "Saved after document work")
        XCTAssertFalse(session.viewModel.hasUnsavedChanges)
    }

    @MainActor
    func testValidationIssuesLinkToRecoverableInspectorFields() async throws {
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

        XCTAssertEqual(viewModel.validationRecoveryRequestRevision, 0)
        await viewModel.saveCurrentInvoice()

        let targets = Set(viewModel.validationIssues.compactMap(\.target))
        XCTAssertTrue(targets.contains(.invoiceNumber))
        XCTAssertTrue(targets.contains(.clientName))
        XCTAssertTrue(targets.contains(.dueDate))
        XCTAssertTrue(targets.contains(.currencyCode))
        XCTAssertTrue(targets.contains(.defaultTaxRate))
        XCTAssertTrue(targets.contains(.discountPercent))
        XCTAssertTrue(targets.contains(.discountAmount))
        XCTAssertTrue(targets.contains(.creditApplied))
        XCTAssertTrue(targets.contains(.lineItems))
        XCTAssertEqual(targets.count, 9)
        XCTAssertEqual(viewModel.statusMessage, "Review the Validation section and try again.")
        XCTAssertEqual(viewModel.validationRecoveryRequestRevision, 1)
    }

    @MainActor
    func testPublicStoreCreatesAndExportsUsingAppContainer() async throws {
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
        XCTAssertGreaterThan(data.count, 100)
        XCTAssertEqual(data.prefix(4), Data("%PDF".utf8))
        XCTAssertEqual(firstPDF.url.lastPathComponent, secondPDF.url.lastPathComponent)
        XCTAssertNotEqual(firstPDF.url, secondPDF.url)

        let discardedURL = firstPDF.url
        firstPDF.discard()
        XCTAssertFalse(FileManager.default.fileExists(atPath: discardedURL.path))
    }

    @MainActor
    func testEditorSessionBulkDocumentSavesAndRendersActiveDraft() async throws {
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
        XCTAssertEqual(saved?.invoiceNumber, "INV-LIVE-DRAFT")
        XCTAssertEqual(pdf.url.lastPathComponent, "Invoice-INV-LIVE-DRAFT.pdf")
        XCTAssertFalse(session.viewModel.hasUnsavedChanges)
    }

    @MainActor
    func testEditorSessionBulkDocumentPreservesInvalidActiveDraft() async throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let actor = InvoiceModelActor(modelContainer: container)
        let id = try await actor.createInvoice()
        let originalSnapshot = try await actor.fetchInvoice(id: id)
        let original = try XCTUnwrap(originalSnapshot)
        let session = InvoiceEditorSession(modelContainer: container)
        await session.viewModel.bootstrap(preferredInvoiceID: id)
        session.viewModel.invoiceNumber = ""

        do {
            _ = try await session.temporaryPDF(invoiceID: id)
            XCTFail("Expected invalid active draft to block PDF generation")
        } catch let error as InvoiceEditorSessionDocumentError {
            XCTAssertEqual(error, .activeDraftCouldNotBeSaved)
        }

        let persisted = try await actor.fetchInvoice(id: id)
        XCTAssertEqual(persisted?.invoiceNumber, original.invoiceNumber)
        XCTAssertEqual(session.viewModel.invoiceNumber, "")
        XCTAssertTrue(session.viewModel.hasUnsavedChanges)
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
