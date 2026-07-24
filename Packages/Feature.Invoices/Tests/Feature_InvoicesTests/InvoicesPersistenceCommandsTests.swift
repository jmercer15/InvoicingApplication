import Core
import Data
import Foundation
import SwiftData
@testable import Feature_Invoices
import XCTest

@MainActor
final class InvoicesPersistenceCommandsTests: XCTestCase {
    func testFetchByUUIDPreservesRequestedOrderAndSkipsDeletedRows() throws {
        let (_, context) = try ModelContainerFactory.makeInMemoryContext()
        let first = Invoice(invoiceNumber: "INV-FIRST")
        let deleted = Invoice(invoiceNumber: "INV-DELETED")
        let last = Invoice(invoiceNumber: "INV-LAST")
        context.insert(first)
        context.insert(deleted)
        context.insert(last)
        try context.save()
        let deletedID = deleted.id
        context.delete(deleted)
        try context.save()

        let commands = InvoicesPersistenceCommands(modelContext: context)
        let fetched = try commands.fetchInvoices(ids: [last.id, deletedID, first.id])

        XCTAssertEqual(fetched.map(\.id), [last.id, first.id])
    }

    func testClearListFiltersRestoresUnfilteredState() throws {
        let (_, context) = try ModelContainerFactory.makeInMemoryContext()
        let viewModel = InvoicesContainerViewModel(modelContext: context)
        viewModel.invoiceSearchText = "Acme"
        viewModel.invoiceFilterStatus = [InvoiceStatus.pending.rawValue]
        viewModel.filterStartDate = Date()
        viewModel.filterEndDate = Date()
        viewModel.filterMinAmount = 10
        viewModel.filterMaxAmount = 100
        viewModel.filterClients = ["Acme"]

        XCTAssertTrue(viewModel.hasActiveListFilters)
        XCTAssertEqual(viewModel.filterInputResetRevision, 0)

        viewModel.clearListFilters()

        XCTAssertFalse(viewModel.hasActiveListFilters)
        XCTAssertTrue(viewModel.invoiceSearchText.isEmpty)
        XCTAssertTrue(viewModel.invoiceFilterStatus.isEmpty)
        XCTAssertNil(viewModel.filterStartDate)
        XCTAssertNil(viewModel.filterEndDate)
        XCTAssertNil(viewModel.filterMinAmount)
        XCTAssertNil(viewModel.filterMaxAmount)
        XCTAssertTrue(viewModel.filterClients.isEmpty)
        XCTAssertEqual(viewModel.filterInputResetRevision, 1)
    }

    func testFilterResetRevisionAdvancesWhenNumericBindingsAlreadyMatchBaseline() throws {
        let (_, context) = try ModelContainerFactory.makeInMemoryContext()
        let viewModel = InvoicesContainerViewModel(modelContext: context)

        XCTAssertNil(viewModel.filterMinAmount)
        XCTAssertNil(viewModel.filterMaxAmount)

        viewModel.clearAmountFilters()
        XCTAssertEqual(viewModel.filterInputResetRevision, 1)

        viewModel.clearListFilters()
        XCTAssertEqual(viewModel.filterInputResetRevision, 2)
    }

    func testFilterEndpointsStayOrderedAsUserEditsEitherBound() throws {
        let (_, context) = try ModelContainerFactory.makeInMemoryContext()
        let viewModel = InvoicesContainerViewModel(modelContext: context)
        let early = Date(timeIntervalSince1970: 1_000)
        let late = Date(timeIntervalSince1970: 2_000)

        viewModel.updateFilterEndDate(early)
        viewModel.updateFilterStartDate(late)
        XCTAssertEqual(viewModel.filterStartDate, late)
        XCTAssertEqual(viewModel.filterEndDate, late)

        viewModel.updateFilterMinimumAmount(200)
        viewModel.updateFilterMaximumAmount(50)
        XCTAssertEqual(viewModel.filterMinAmount, 50)
        XCTAssertEqual(viewModel.filterMaxAmount, 50)

        viewModel.updateFilterMaximumAmount(.infinity)
        XCTAssertNil(viewModel.filterMaxAmount)

        viewModel.updateFilterMinimumAmount(-1)
        XCTAssertNil(viewModel.filterMinAmount)

        viewModel.updateFilterMaximumAmount(.nan)
        XCTAssertNil(viewModel.filterMaxAmount)
    }

    func testOnlyNewestListLoadCanFinishLoadingState() throws {
        let (_, context) = try ModelContainerFactory.makeInMemoryContext()
        let viewModel = InvoicesContainerViewModel(modelContext: context)

        let olderRequest = viewModel.beginListLoad()
        let newestRequest = viewModel.beginListLoad()
        viewModel.finishListLoad(olderRequest)

        XCTAssertTrue(viewModel.isLoading)

        viewModel.finishListLoad(newestRequest)

        XCTAssertFalse(viewModel.isLoading)
    }

    func testOlderReloadCannotOverwriteNewerPublishedRows() async throws {
        let (_, context) = try ModelContainerFactory.makeInMemoryContext()
        let olderInvoice = Invoice(invoiceNumber: "INV-OLDER-QUERY")
        let newerInvoice = Invoice(invoiceNumber: "INV-NEWER-QUERY")
        context.insert(olderInvoice)
        context.insert(newerInvoice)
        try context.save()

        let fetcher = SupersededInvoiceListFetcher(
            olderIDs: [olderInvoice.id],
            newerIDs: [newerInvoice.id],
            totalCount: 2
        )
        let viewModel = InvoicesContainerViewModel(
            modelContext: context,
            listFetcher: fetcher
        )

        let olderReload = Task {
            await viewModel.reloadInvoices(matching: FetchDescriptor<Invoice>())
        }
        await fetcher.waitUntilOlderRequestIsSuspended()

        let newerOutcome = await viewModel.reloadInvoices(matching: FetchDescriptor<Invoice>())
        XCTAssertEqual(viewModel.invoiceEntities.map(\.id), [newerInvoice.id])

        await fetcher.resumeOlderRequest()
        let olderOutcome = await olderReload.value

        XCTAssertEqual(newerOutcome, .published)
        XCTAssertEqual(olderOutcome, .superseded)
        XCTAssertEqual(viewModel.invoiceEntities.map(\.id), [newerInvoice.id])
        XCTAssertEqual(viewModel.totalInvoiceCount, 2)
        XCTAssertNil(viewModel.listLoadError)
        XCTAssertFalse(viewModel.isLoading)
    }

    func testDeepLinkRevealSupersedesOlderFilteredReload() async throws {
        let (_, context) = try ModelContainerFactory.makeInMemoryContext()
        let staleInvoice = Invoice(invoiceNumber: "INV-STALE-FILTER")
        let destination = Invoice(invoiceNumber: "INV-DEEP-LINK")
        context.insert(staleInvoice)
        context.insert(destination)
        try context.save()

        let fetcher = SupersededInvoiceListFetcher(
            olderIDs: [staleInvoice.id],
            newerIDs: [destination.id],
            totalCount: 2
        )
        let viewModel = InvoicesContainerViewModel(
            modelContext: context,
            listFetcher: fetcher
        )
        viewModel.invoiceSearchText = "Hidden by stale query"

        let staleReload = Task {
            await viewModel.reloadInvoices(matching: FetchDescriptor<Invoice>())
        }
        await fetcher.waitUntilOlderRequestIsSuspended()

        viewModel.selectInvoiceForDeepLink(id: destination.id)
        XCTAssertEqual(viewModel.invoiceEntities.map(\.id), [destination.id])
        XCTAssertEqual(viewModel.selectedInvoice?.id, destination.id)

        await fetcher.resumeOlderRequest()
        let staleOutcome = await staleReload.value

        XCTAssertEqual(staleOutcome, .superseded)
        XCTAssertEqual(viewModel.invoiceEntities.map(\.id), [destination.id])
        XCTAssertEqual(viewModel.selectedInvoice?.id, destination.id)
        XCTAssertFalse(viewModel.hasActiveListFilters)
    }

    func testDeleteByStableIDsClearsActiveSelectionAndPreservesOtherInvoices() async throws {
        let (_, context) = try ModelContainerFactory.makeInMemoryContext()
        let deletedInvoice = Invoice(invoiceNumber: "INV-DELETE")
        let preservedInvoice = Invoice(invoiceNumber: "INV-KEEP")
        let deletedID = deletedInvoice.id
        let preservedID = preservedInvoice.id
        context.insert(deletedInvoice)
        context.insert(preservedInvoice)
        try context.save()

        let viewModel = InvoicesContainerViewModel(modelContext: context)
        viewModel.requestSelectInvoice(deletedInvoice)

        let deletedCount = try await viewModel.deleteInvoices(ids: [deletedID])

        let remaining = try context.fetch(FetchDescriptor<Invoice>())
        XCTAssertEqual(deletedCount, 1)
        XCTAssertNil(viewModel.selectedInvoice)
        XCTAssertEqual(remaining.map(\.id), [preservedID])
    }

    func testFeatureOwnedCreationMaterializesAndSelectsNewInvoice() async throws {
        let (_, context) = try ModelContainerFactory.makeInMemoryContext()
        let viewModel = InvoicesContainerViewModel(modelContext: context)

        let id = try await viewModel.createInvoice()

        XCTAssertEqual(viewModel.selectedInvoice?.id, id)
        XCTAssertEqual(viewModel.invoiceEntities.map(\.id), [id])
        XCTAssertEqual(viewModel.loadedInvoicesByID[id]?.id, id)
        XCTAssertEqual(viewModel.totalInvoiceCount, 1)
        XCTAssertNil(viewModel.actionErrorMessage)
        XCTAssertFalse(viewModel.isCreatingInvoice)
    }

    func testFeatureOwnedDuplicateUsesCanonicalActorSemanticsAndRevealsCopy() async throws {
        let (_, context) = try ModelContainerFactory.makeInMemoryContext()
        let source = Invoice(invoiceNumber: "INV-SOURCE")
        source.clientName = "Acme"
        source.effectiveStatus = .pending
        source.currencyCode = "AUD"
        let item = InvoiceItem(itemDescription: "Support")
        item.quantity = 2
        item.rate = 50
        item.taxRate = 10
        item.invoice = source
        source.items = [item]
        source.recalculateStoredTotal()
        context.insert(source)
        context.insert(item)
        try context.save()

        let viewModel = InvoicesContainerViewModel(modelContext: context)
        viewModel.invoiceSearchText = "Hidden"
        viewModel.filterClients = ["Nobody"]
        viewModel.totalInvoiceCount = 1

        let duplicateID = try await viewModel.duplicateInvoice(source)

        XCTAssertNotEqual(duplicateID, source.id)
        XCTAssertFalse(viewModel.hasActiveListFilters)
        XCTAssertEqual(viewModel.selectedInvoice?.id, duplicateID)
        XCTAssertEqual(viewModel.invoiceEntities.map(\.id), [duplicateID])
        XCTAssertEqual(viewModel.totalInvoiceCount, 2)
        XCTAssertNil(viewModel.actionErrorMessage)
        XCTAssertFalse(viewModel.isCreatingInvoice)

        let duplicate = try XCTUnwrap(viewModel.loadedInvoicesByID[duplicateID])
        XCTAssertEqual(duplicate.effectiveStatus, .reviewDraft)
        XCTAssertTrue(duplicate.invoiceNumber != source.invoiceNumber)
        XCTAssertEqual(duplicate.clientName, "Acme")
        XCTAssertEqual(duplicate.itemsArray.count, 1)
        XCTAssertEqual(duplicate.itemsArray.first?.itemDescription, "Support")
        XCTAssertNotEqual(duplicate.itemsArray.first?.id, item.id)
    }

    func testFeatureOwnedCreationDoesNotInsertWhenCurrentDraftCannotBePrepared() async throws {
        let (_, context) = try ModelContainerFactory.makeInMemoryContext()
        var preparationCount = 0
        let viewModel = InvoicesContainerViewModel(
            modelContext: context,
            invoiceCreationPreparation: {
                preparationCount += 1
                return false
            }
        )

        do {
            _ = try await viewModel.createInvoice()
            XCTFail("Creation should stop when current draft cannot be prepared")
        } catch {
            XCTAssertEqual(error as? InvoicesFeatureError, .currentInvoiceCouldNotBePrepared)
        }

        XCTAssertEqual(preparationCount, 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Invoice>()), 0)
        XCTAssertTrue(viewModel.invoiceEntities.isEmpty)
        XCTAssertNil(viewModel.selectedInvoice)
        XCTAssertEqual(viewModel.invoiceCreationPhase, .idle)
        XCTAssertFalse(viewModel.isCreatingInvoice)
    }

    func testInvoiceCreationGateRejectsOverlappingRequestsAndRecovers() throws {
        let (_, context) = try ModelContainerFactory.makeInMemoryContext()
        let viewModel = InvoicesContainerViewModel(modelContext: context)

        try viewModel.beginInvoiceCreation()
        XCTAssertTrue(viewModel.isCreatingInvoice)
        XCTAssertThrowsError(try viewModel.beginInvoiceCreation()) { error in
            XCTAssertEqual(error as? InvoicesFeatureError, .creationAlreadyInProgress)
        }

        viewModel.finishInvoiceCreation()
        XCTAssertFalse(viewModel.isCreatingInvoice)
        XCTAssertNoThrow(try viewModel.beginInvoiceCreation())
        viewModel.finishInvoiceCreation()
    }

    func testFeatureOwnedCreationIncrementsKnownStoreTotalForFilteredList() async throws {
        let (_, context) = try ModelContainerFactory.makeInMemoryContext()
        for index in 1...10 {
            context.insert(Invoice(invoiceNumber: "INV-\(index)"))
        }
        try context.save()
        let viewModel = InvoicesContainerViewModel(modelContext: context)
        viewModel.totalInvoiceCount = 10
        viewModel.invoiceSearchText = "No match"
        viewModel.invoiceFilterStatus = [InvoiceStatus.received.rawValue]
        viewModel.filterClients = ["Hidden client"]

        let id = try await viewModel.createInvoice()

        XCTAssertFalse(viewModel.hasActiveListFilters)
        XCTAssertEqual(viewModel.totalInvoiceCount, 11)
        XCTAssertEqual(viewModel.invoiceEntities.map(\.id), [id])
        XCTAssertEqual(viewModel.selectedInvoice?.id, id)
    }

    func testEditorMutationsReconcileRowsTotalsAndSelectionSymmetrically() async throws {
        let (_, context) = try ModelContainerFactory.makeInMemoryContext()
        let first = Invoice(invoiceNumber: "INV-FIRST")
        context.insert(first)
        try context.save()
        let viewModel = InvoicesContainerViewModel(modelContext: context)

        await viewModel.reconcileEditorMutation(.inserted(first.id))
        XCTAssertEqual(viewModel.totalInvoiceCount, 1)
        XCTAssertEqual(viewModel.selectedInvoice?.id, first.id)

        first.invoiceNumber = "INV-FIRST-UPDATED"
        try context.save()
        await viewModel.reconcileEditorMutation(.updated(first.id))
        XCTAssertEqual(viewModel.invoiceEntities.first?.invoiceNumber, "INV-FIRST-UPDATED")
        XCTAssertEqual(viewModel.totalInvoiceCount, 1)

        let second = Invoice(invoiceNumber: "INV-SECOND")
        context.insert(second)
        try context.save()
        await viewModel.reconcileEditorMutation(.inserted(second.id))
        XCTAssertEqual(viewModel.totalInvoiceCount, 2)
        XCTAssertEqual(viewModel.selectedInvoice?.id, second.id)

        context.delete(second)
        try context.save()
        await viewModel.reconcileEditorMutation(.deleted(second.id))
        XCTAssertEqual(viewModel.totalInvoiceCount, 1)
        XCTAssertEqual(viewModel.invoiceEntities.map(\.id), [first.id])
        XCTAssertNil(viewModel.selectedInvoice)
    }

    func testEditorUpdateReappliesActivePersistenceFilters() async throws {
        let (_, context) = try ModelContainerFactory.makeInMemoryContext()
        let invoice = Invoice(invoiceNumber: "INV-FILTERED")
        invoice.effectiveStatus = .received
        context.insert(invoice)
        try context.save()

        let viewModel = InvoicesContainerViewModel(modelContext: context)
        viewModel.invoiceFilterStatus = [InvoiceStatus.received.rawValue]
        await viewModel.reloadInvoices(
            matching: InvoicesListQueryEngine.buildPersistenceDescriptor(from: viewModel.listQuerySpec)
        )
        XCTAssertEqual(viewModel.invoiceEntities.map(\.id), [invoice.id])

        invoice.effectiveStatus = .reviewDraft
        try context.save()
        await viewModel.reconcileEditorMutation(.updated(invoice.id))

        XCTAssertTrue(viewModel.invoiceEntities.isEmpty)
        XCTAssertEqual(viewModel.totalInvoiceCount, 1)
    }

    func testEditorInsertionClearsFiltersBeforeRevealingCreatedInvoice() async throws {
        let (_, context) = try ModelContainerFactory.makeInMemoryContext()
        let invoice = Invoice(invoiceNumber: "INV-NEW")
        context.insert(invoice)
        try context.save()

        let viewModel = InvoicesContainerViewModel(modelContext: context)
        viewModel.invoiceSearchText = "No match"
        viewModel.invoiceFilterStatus = [InvoiceStatus.received.rawValue]

        await viewModel.reconcileEditorMutation(.inserted(invoice.id))

        XCTAssertFalse(viewModel.hasActiveListFilters)
        XCTAssertEqual(viewModel.invoiceEntities.map(\.id), [invoice.id])
        XCTAssertEqual(viewModel.selectedInvoice?.id, invoice.id)
        XCTAssertEqual(viewModel.totalInvoiceCount, 1)
    }

    func testActiveFilterDescriptionsAndSummaryFormatting() throws {
        let (_, context) = try ModelContainerFactory.makeInMemoryContext()
        let viewModel = InvoicesContainerViewModel(modelContext: context)

        XCTAssertTrue(viewModel.activeFilterDescriptions.isEmpty)
        XCTAssertEqual(viewModel.activeFilterSummaryText, "")

        viewModel.invoiceSearchText = "Acme"
        viewModel.invoiceFilterStatus = [InvoiceStatus.received.rawValue]
        viewModel.updateFilterMinimumAmount(100.0)
        viewModel.updateFilterMaximumAmount(500.0)

        XCTAssertFalse(viewModel.activeFilterDescriptions.isEmpty)
        XCTAssertTrue(viewModel.activeFilterSummaryText.contains("Search \"Acme\""))
        XCTAssertTrue(viewModel.activeFilterSummaryText.contains("Status: Received"))
        XCTAssertTrue(viewModel.activeFilterSummaryText.contains("Amount: 100.00 – 500.00"))

        viewModel.clearListFilters()
        XCTAssertTrue(viewModel.activeFilterDescriptions.isEmpty)
        XCTAssertEqual(viewModel.activeFilterSummaryText, "")
    }

    func testReloadTracksStoreTotalSeparatelyFromMatchingRows() async throws {
        let (_, context) = try ModelContainerFactory.makeInMemoryContext()
        context.insert(Invoice(invoiceNumber: "INV-MATCH"))
        context.insert(Invoice(invoiceNumber: "INV-OTHER"))
        try context.save()

        let viewModel = InvoicesContainerViewModel(modelContext: context)
        let descriptor = FetchDescriptor<Invoice>(
            predicate: #Predicate<Invoice> { $0.invoiceNumber == "INV-MATCH" }
        )

        await viewModel.reloadInvoices(matching: descriptor)

        XCTAssertEqual(viewModel.invoiceEntities.map(\.invoiceNumber), ["INV-MATCH"])
        XCTAssertEqual(viewModel.totalInvoiceCount, 2)
    }

    func testTransientReloadFailurePreservesLastGoodRowsAndSelection() async throws {
        let (_, context) = try ModelContainerFactory.makeInMemoryContext()
        let invoice = Invoice(invoiceNumber: "INV-PRESERVED")
        context.insert(invoice)
        try context.save()
        let fetcher = ControllableInvoiceListFetcher(
            invoiceIDs: [invoice.id],
            totalCount: 1
        )
        let viewModel = InvoicesContainerViewModel(
            modelContext: context,
            listFetcher: fetcher
        )

        XCTAssertFalse(viewModel.hasCompletedSuccessfulListLoad)
        await viewModel.reloadInvoices(matching: FetchDescriptor<Invoice>())
        viewModel.requestSelectInvoice(invoice)
        XCTAssertTrue(viewModel.canProjectCurrentListSpec)

        viewModel.invoiceFilterStatus = [InvoiceStatus.pending.rawValue]
        XCTAssertTrue(viewModel.isShowingPreviousQueryResults)
        await fetcher.failSubsequentRequests()

        await viewModel.reloadInvoices(matching: FetchDescriptor<Invoice>())

        XCTAssertTrue(viewModel.hasCompletedSuccessfulListLoad)
        XCTAssertEqual(viewModel.invoiceEntities.map(\.id), [invoice.id])
        XCTAssertEqual(viewModel.loadedInvoicesByID[invoice.id]?.id, invoice.id)
        XCTAssertEqual(viewModel.selectedInvoice?.id, invoice.id)
        XCTAssertEqual(viewModel.totalInvoiceCount, 1)
        XCTAssertNotNil(viewModel.listLoadError)
        XCTAssertTrue(viewModel.isShowingPreviousQueryResults)
    }

    func testOpaqueSwiftDataReloadFailureUsesActionableListCopy() async throws {
        let (_, context) = try ModelContainerFactory.makeInMemoryContext()
        let viewModel = InvoicesContainerViewModel(
            modelContext: context,
            listFetcher: OpaqueInvoiceListFetcher()
        )

        let outcome = await viewModel.reloadInvoices(
            matching: FetchDescriptor<Invoice>()
        )

        XCTAssertEqual(outcome, .failed)
        XCTAssertEqual(
            viewModel.listLoadError,
            "Invoice data could not be refreshed. Try again."
        )
    }

    func testReloadAdvancesProjectionRevisionWhenRowCountIsUnchanged() async throws {
        let (_, context) = try ModelContainerFactory.makeInMemoryContext()
        let invoice = Invoice(invoiceNumber: "INV-BEFORE")
        context.insert(invoice)
        try context.save()
        let viewModel = InvoicesContainerViewModel(modelContext: context)
        let descriptor = FetchDescriptor<Invoice>()

        await viewModel.reloadInvoices(matching: descriptor)
        let firstRevision = viewModel.listContentRevision
        invoice.invoiceNumber = "INV-AFTER"
        try context.save()
        await viewModel.reloadInvoices(matching: descriptor)

        XCTAssertGreaterThan(viewModel.listContentRevision, firstRevision)
        XCTAssertEqual(viewModel.invoiceEntities.first?.invoiceNumber, "INV-AFTER")
    }

    func testReloadSeesInvoiceEditsSavedFromIndependentContext() async throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let workspaceContext = ModelContext(container)
        let invoice = Invoice(invoiceNumber: "INV-BEFORE")
        workspaceContext.insert(invoice)
        try workspaceContext.save()
        let invoiceID = invoice.id
        let viewModel = InvoicesContainerViewModel(modelContext: workspaceContext)
        await viewModel.reloadInvoices(matching: FetchDescriptor<Invoice>())

        let editorContext = ModelContext(container)
        let editorDescriptor = FetchDescriptor<Invoice>(
            predicate: #Predicate<Invoice> { $0.id == invoiceID }
        )
        let editorInvoice = try XCTUnwrap(editorContext.fetch(editorDescriptor).first)
        editorInvoice.invoiceNumber = "INV-AFTER"
        try editorContext.save()

        await viewModel.reloadInvoices(matching: FetchDescriptor<Invoice>())

        XCTAssertEqual(viewModel.invoiceEntities.first?.invoiceNumber, "INV-AFTER")
    }

    func testStoreRevisionParticipatesInReloadTaskIdentity() {
        let spec = InvoicePersistenceQuerySpec(
            statuses: [InvoiceStatus.pending.rawValue],
            filterStartDate: .distantPast,
            filterEndDate: .distantFuture,
            minimumAmount: 0,
            maximumAmount: 100,
            sortField: .date,
            sortDirection: .descending
        )

        XCTAssertNotEqual(
            InvoicesReloadTaskID(persistenceSpec: spec, storeRevision: 1),
            InvoicesReloadTaskID(persistenceSpec: spec, storeRevision: 2)
        )
    }

    func testPersistenceQueryKeepsAllClientsAvailableForFacetExpansion() async throws {
        let (_, context) = try ModelContainerFactory.makeInMemoryContext()
        let acme = Invoice(invoiceNumber: "INV-ACME")
        acme.clientName = "Acme"
        let north = Invoice(invoiceNumber: "INV-NORTH")
        north.clientName = "North"
        context.insert(acme)
        context.insert(north)
        try context.save()

        let viewModel = InvoicesContainerViewModel(modelContext: context)
        viewModel.filterClients = ["Acme"]
        await viewModel.reloadInvoices(
            matching: InvoicesListQueryEngine.buildPersistenceDescriptor(from: viewModel.listQuerySpec)
        )
        let projection = InvoicesListQueryEngine.project(
            invoices: viewModel.invoiceEntities,
            spec: viewModel.listQuerySpec
        )

        XCTAssertEqual(projection.availableClientNames, ["Acme", "North"])
        XCTAssertEqual(projection.filteredInvoices.map(\.invoiceNumber), ["INV-ACME"])
    }

    func testDeepLinkClearsFiltersWhenDestinationIsOutsideCurrentRows() throws {
        let (_, context) = try ModelContainerFactory.makeInMemoryContext()
        let destination = Invoice(invoiceNumber: "INV-DESTINATION")
        context.insert(destination)
        try context.save()

        let viewModel = InvoicesContainerViewModel(modelContext: context)
        viewModel.invoiceSearchText = "Other"
        viewModel.invoiceFilterStatus = [InvoiceStatus.pending.rawValue]

        viewModel.selectInvoiceForDeepLink(id: destination.id)

        XCTAssertEqual(viewModel.selectedInvoice?.id, destination.id)
        XCTAssertFalse(viewModel.hasActiveListFilters)
    }

    func testDeepLinkMaterializesDestinationIntoListImmediately() throws {
        let (_, context) = try ModelContainerFactory.makeInMemoryContext()
        let destination = Invoice(invoiceNumber: "INV-NEW-ROUTE")
        context.insert(destination)
        try context.save()
        let viewModel = InvoicesContainerViewModel(modelContext: context)

        viewModel.selectInvoiceForDeepLink(id: destination.id)

        XCTAssertEqual(viewModel.selectedInvoice?.id, destination.id)
        XCTAssertEqual(viewModel.invoiceEntities.map(\.id), [destination.id])
        XCTAssertEqual(viewModel.loadedInvoicesByID[destination.id]?.id, destination.id)
        XCTAssertEqual(viewModel.totalInvoiceCount, 1)
    }

    func testMissingDeepLinkPreservesListContextAndReportsActionError() throws {
        let (_, context) = try ModelContainerFactory.makeInMemoryContext()
        let visibleInvoice = Invoice(invoiceNumber: "INV-VISIBLE")
        context.insert(visibleInvoice)
        try context.save()
        let viewModel = InvoicesContainerViewModel(modelContext: context)
        viewModel.invoiceEntities = [visibleInvoice]
        viewModel.updateLoadedInvoices([visibleInvoice])
        viewModel.requestSelectInvoice(visibleInvoice)
        viewModel.invoiceSearchText = "Current search"

        viewModel.selectInvoiceForDeepLink(id: UUID())

        XCTAssertEqual(viewModel.invoiceEntities.map(\.id), [visibleInvoice.id])
        XCTAssertNil(viewModel.selectedInvoice)
        XCTAssertEqual(viewModel.invoiceSearchText, "Current search")
        XCTAssertTrue(viewModel.hasActiveListFilters)
        XCTAssertNil(viewModel.listLoadError)
        XCTAssertEqual(
            viewModel.actionErrorMessage,
            "Invoice couldn't be opened because it no longer exists."
        )
    }

    func testActionErrorDoesNotReplaceListLoadState() throws {
        let (_, context) = try ModelContainerFactory.makeInMemoryContext()
        let invoice = Invoice(invoiceNumber: "INV-STAYS-VISIBLE")
        context.insert(invoice)
        try context.save()
        let viewModel = InvoicesContainerViewModel(modelContext: context)
        viewModel.invoiceEntities = [invoice]

        viewModel.reportActionError("New invoice could not be created.")

        XCTAssertEqual(viewModel.invoiceEntities.map(\.id), [invoice.id])
        XCTAssertNil(viewModel.listLoadError)
        XCTAssertEqual(viewModel.actionErrorMessage, "New invoice could not be created.")

        viewModel.dismissActionError()
        XCTAssertNil(viewModel.actionErrorMessage)
    }

    func testSuccessfulInvoiceSelectionDismissesStaleActionError() throws {
        let (_, context) = try ModelContainerFactory.makeInMemoryContext()
        let invoice = Invoice(invoiceNumber: "INV-RECOVERED")
        context.insert(invoice)
        try context.save()
        let viewModel = InvoicesContainerViewModel(modelContext: context)
        viewModel.reportActionError("Previous invoice action failed.")

        viewModel.requestSelectInvoice(invoice)

        XCTAssertEqual(viewModel.selectedInvoice?.id, invoice.id)
        XCTAssertNil(viewModel.actionErrorMessage)
    }

    func testDeepLinkClearsClientFilterWhenDestinationIsAlreadyLoaded() throws {
        let (_, context) = try ModelContainerFactory.makeInMemoryContext()
        let destination = Invoice(invoiceNumber: "INV-NORTH")
        destination.clientName = "North"
        context.insert(destination)
        try context.save()

        let viewModel = InvoicesContainerViewModel(modelContext: context)
        viewModel.updateLoadedInvoices([destination])
        viewModel.filterClients = ["Acme"]

        viewModel.selectInvoiceForDeepLink(id: destination.id)

        XCTAssertEqual(viewModel.selectedInvoice?.id, destination.id)
        XCTAssertFalse(viewModel.hasActiveListFilters)
    }

    func testSelectionReconciliationClosesFilteredOutInvoice() throws {
        let (_, context) = try ModelContainerFactory.makeInMemoryContext()
        let selected = Invoice(invoiceNumber: "INV-SELECTED")
        context.insert(selected)
        try context.save()

        let viewModel = InvoicesContainerViewModel(modelContext: context)
        viewModel.requestSelectInvoice(selected)

        viewModel.reconcileSelection(visibleInvoiceIDs: [])

        XCTAssertNil(viewModel.selectedInvoice)
    }

    func testSelectionReconciliationPreservesInvoiceHiddenByFilters() throws {
        let (_, context) = try ModelContainerFactory.makeInMemoryContext()
        let selected = Invoice(invoiceNumber: "INV-SELECTED")
        context.insert(selected)
        try context.save()

        let viewModel = InvoicesContainerViewModel(modelContext: context)
        viewModel.requestSelectInvoice(selected)
        viewModel.invoiceSearchText = "No match"

        viewModel.reconcileSelection(visibleInvoiceIDs: [])

        XCTAssertEqual(viewModel.selectedInvoice?.id, selected.id)
    }

    func testBulkExportDestinationPreservesExistingPDFs() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("InvoiceBulkExportNamingTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try Data().write(to: directory.appendingPathComponent("Invoice-001.pdf"))
        try Data().write(to: directory.appendingPathComponent("Invoice-001 2.pdf"))

        let destination = InvoiceBulkExportNaming.availableDestination(
            in: directory,
            preferredFilename: "Invoice-001.pdf"
        )

        XCTAssertEqual(destination.lastPathComponent, "Invoice-001 3.pdf")
    }
}

private struct FailingInvoiceListFetcher: InvoiceListFetching {
    enum Failure: LocalizedError {
        case unavailable

        var errorDescription: String? { "Invoice store temporarily unavailable." }
    }

    func invoiceIDs(matching descriptor: FetchDescriptor<Invoice>) async throws -> [UUID] {
        throw Failure.unavailable
    }

    func totalInvoiceCount() async throws -> Int {
        throw Failure.unavailable
    }
}

private struct OpaqueInvoiceListFetcher: InvoiceListFetching {
    private var failure: NSError {
        NSError(domain: "SwiftData.SwiftDataError", code: 1)
    }

    func invoiceIDs(matching descriptor: FetchDescriptor<Invoice>) async throws -> [UUID] {
        throw failure
    }

    func totalInvoiceCount() async throws -> Int {
        throw failure
    }
}

private actor ControllableInvoiceListFetcher: InvoiceListFetching {
    private let storedInvoiceIDs: [UUID]
    private let storedTotalCount: Int
    private var shouldFail = false

    init(invoiceIDs: [UUID], totalCount: Int) {
        storedInvoiceIDs = invoiceIDs
        storedTotalCount = totalCount
    }

    func failSubsequentRequests() {
        shouldFail = true
    }

    func invoiceIDs(matching descriptor: FetchDescriptor<Invoice>) async throws -> [UUID] {
        if shouldFail { throw FailingInvoiceListFetcher.Failure.unavailable }
        return storedInvoiceIDs
    }

    func totalInvoiceCount() async throws -> Int {
        if shouldFail { throw FailingInvoiceListFetcher.Failure.unavailable }
        return storedTotalCount
    }
}

private actor SupersededInvoiceListFetcher: InvoiceListFetching {
    private let olderIDs: [UUID]
    private let newerIDs: [UUID]
    private let storedTotalCount: Int
    private var invoiceIDRequestCount = 0
    private var olderRequestContinuation: CheckedContinuation<Void, Never>?

    init(olderIDs: [UUID], newerIDs: [UUID], totalCount: Int) {
        self.olderIDs = olderIDs
        self.newerIDs = newerIDs
        self.storedTotalCount = totalCount
    }

    func waitUntilOlderRequestIsSuspended() async {
        while olderRequestContinuation == nil {
            await Task.yield()
        }
    }

    func resumeOlderRequest() {
        olderRequestContinuation?.resume()
        olderRequestContinuation = nil
    }

    func invoiceIDs(matching descriptor: FetchDescriptor<Invoice>) async throws -> [UUID] {
        invoiceIDRequestCount += 1
        if invoiceIDRequestCount == 1 {
            await withCheckedContinuation { continuation in
                olderRequestContinuation = continuation
            }
            return olderIDs
        }
        return newerIDs
    }

    func totalInvoiceCount() async throws -> Int {
        storedTotalCount
    }
}
