import Core
import PersistenceModels
import Data
import Foundation
import SwiftData
@testable import Feature_Invoices
import Testing
@MainActor
@Suite struct InvoicesPersistenceCommandsTests {
    @Test func FetchByUUIDPreservesRequestedOrderAndSkipsDeletedRows() throws {
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

        #expect(fetched.map(\.id) == [last.id, first.id])
    }

    @Test func ClearListFiltersRestoresUnfilteredState() throws {
        let (_, context) = try ModelContainerFactory.makeInMemoryContext()
        let viewModel = InvoicesContainerViewModel(modelContext: context)
        viewModel.invoiceSearchText = "Acme"
        viewModel.invoiceFilterStatus = [InvoiceStatus.pending.rawValue]
        viewModel.filterStartDate = Date()
        viewModel.filterEndDate = Date()
        viewModel.filterMinAmount = 10
        viewModel.filterMaxAmount = 100
        viewModel.filterClients = ["Acme"]

        #expect(viewModel.hasActiveListFilters)
        #expect(viewModel.filterInputResetRevision == 0)

        viewModel.clearListFilters()

        #expect(!(viewModel.hasActiveListFilters))
        #expect(viewModel.invoiceSearchText.isEmpty)
        #expect(viewModel.invoiceFilterStatus.isEmpty)
        #expect(viewModel.filterStartDate == nil)
        #expect(viewModel.filterEndDate == nil)
        #expect(viewModel.filterMinAmount == nil)
        #expect(viewModel.filterMaxAmount == nil)
        #expect(viewModel.filterClients.isEmpty)
        #expect(viewModel.filterInputResetRevision == 1)
    }

    @Test func FilterResetRevisionAdvancesWhenNumericBindingsAlreadyMatchBaseline() throws {
        let (_, context) = try ModelContainerFactory.makeInMemoryContext()
        let viewModel = InvoicesContainerViewModel(modelContext: context)

        #expect(viewModel.filterMinAmount == nil)
        #expect(viewModel.filterMaxAmount == nil)

        viewModel.clearAmountFilters()
        #expect(viewModel.filterInputResetRevision == 1)

        viewModel.clearListFilters()
        #expect(viewModel.filterInputResetRevision == 2)
    }

    @Test func FilterEndpointsStayOrderedAsUserEditsEitherBound() throws {
        let (_, context) = try ModelContainerFactory.makeInMemoryContext()
        let viewModel = InvoicesContainerViewModel(modelContext: context)
        let early = Date(timeIntervalSince1970: 1_000)
        let late = Date(timeIntervalSince1970: 2_000)

        viewModel.updateFilterEndDate(early)
        viewModel.updateFilterStartDate(late)
        #expect(viewModel.filterStartDate == late)
        #expect(viewModel.filterEndDate == late)

        viewModel.updateFilterMinimumAmount(200)
        viewModel.updateFilterMaximumAmount(50)
        #expect(viewModel.filterMinAmount == 50)
        #expect(viewModel.filterMaxAmount == 50)

        viewModel.updateFilterMaximumAmount(.infinity)
        #expect(viewModel.filterMaxAmount == nil)

        viewModel.updateFilterMinimumAmount(-1)
        #expect(viewModel.filterMinAmount == nil)

        viewModel.updateFilterMaximumAmount(.nan)
        #expect(viewModel.filterMaxAmount == nil)
    }

    @Test func OnlyNewestListLoadCanFinishLoadingState() throws {
        let (_, context) = try ModelContainerFactory.makeInMemoryContext()
        let viewModel = InvoicesContainerViewModel(modelContext: context)

        let olderRequest = viewModel.beginListLoad()
        let newestRequest = viewModel.beginListLoad()
        viewModel.finishListLoad(olderRequest)

        #expect(viewModel.isLoading)

        viewModel.finishListLoad(newestRequest)

        #expect(!(viewModel.isLoading))
    }

    @Test func OlderReloadCannotOverwriteNewerPublishedRows() async throws {
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
        #expect(viewModel.invoiceEntities.map(\.id) == [newerInvoice.id])

        await fetcher.resumeOlderRequest()
        let olderOutcome = await olderReload.value

        #expect(newerOutcome == .published)
        #expect(olderOutcome == .superseded)
        #expect(viewModel.invoiceEntities.map(\.id) == [newerInvoice.id])
        #expect(viewModel.totalInvoiceCount == 2)
        #expect(viewModel.listLoadError == nil)
        #expect(!(viewModel.isLoading))
    }

    @Test func DeepLinkRevealSupersedesOlderFilteredReload() async throws {
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
        #expect(viewModel.invoiceEntities.map(\.id) == [destination.id])
        #expect(viewModel.selectedInvoice?.id == destination.id)

        await fetcher.resumeOlderRequest()
        let staleOutcome = await staleReload.value

        #expect(staleOutcome == .superseded)
        #expect(viewModel.invoiceEntities.map(\.id) == [destination.id])
        #expect(viewModel.selectedInvoice?.id == destination.id)
        #expect(!(viewModel.hasActiveListFilters))
    }

    @Test func DeleteByStableIDsClearsActiveSelectionAndPreservesOtherInvoices() async throws {
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
        #expect(deletedCount == 1)
        #expect(viewModel.selectedInvoice == nil)
        #expect(remaining.map(\.id) == [preservedID])
    }

    @Test func FeatureOwnedCreationMaterializesAndSelectsNewInvoice() async throws {
        let (_, context) = try ModelContainerFactory.makeInMemoryContext()
        let viewModel = InvoicesContainerViewModel(modelContext: context)

        let id = try await viewModel.createInvoice()

        #expect(viewModel.selectedInvoice?.id == id)
        #expect(viewModel.invoiceEntities.map(\.id) == [id])
        #expect(viewModel.loadedInvoicesByID[id]?.id == id)
        #expect(viewModel.totalInvoiceCount == 1)
        #expect(viewModel.actionErrorMessage == nil)
        #expect(!(viewModel.isCreatingInvoice))
    }

    @Test func FeatureOwnedDuplicateUsesCanonicalActorSemanticsAndRevealsCopy() async throws {
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

        #expect(duplicateID != source.id)
        #expect(!(viewModel.hasActiveListFilters))
        #expect(viewModel.selectedInvoice?.id == duplicateID)
        #expect(viewModel.invoiceEntities.map(\.id) == [duplicateID])
        #expect(viewModel.totalInvoiceCount == 2)
        #expect(viewModel.actionErrorMessage == nil)
        #expect(!(viewModel.isCreatingInvoice))

        let duplicate = try try #require(viewModel.loadedInvoicesByID[duplicateID])
        #expect(duplicate.effectiveStatus == .reviewDraft)
        #expect(duplicate.invoiceNumber != source.invoiceNumber)
        #expect(duplicate.clientName == "Acme")
        #expect(duplicate.itemsArray.count == 1)
        #expect(duplicate.itemsArray.first?.itemDescription == "Support")
        #expect(duplicate.itemsArray.first?.id != item.id)
    }

    @Test func FeatureOwnedCreationDoesNotInsertWhenCurrentDraftCannotBePrepared() async throws {
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
            Issue.record("Creation should stop when current draft cannot be prepared")
        } catch {
            #expect(error as? InvoicesFeatureError == .currentInvoiceCouldNotBePrepared)
        }

        #expect(preparationCount == 1)
        #expect(try context.fetchCount(FetchDescriptor<Invoice>()) == 0)
        #expect(viewModel.invoiceEntities.isEmpty)
        #expect(viewModel.selectedInvoice == nil)
        #expect(viewModel.invoiceCreationPhase == .idle)
        #expect(!(viewModel.isCreatingInvoice))
    }

    @Test func InvoiceCreationGateRejectsOverlappingRequestsAndRecovers() throws {
        let (_, context) = try ModelContainerFactory.makeInMemoryContext()
        let viewModel = InvoicesContainerViewModel(modelContext: context)

        try viewModel.beginInvoiceCreation()
        #expect(viewModel.isCreatingInvoice)
        do {
            try viewModel.beginInvoiceCreation()
            Issue.record("Expected overlapping creation to throw")
        } catch {
            #expect(error as? InvoicesFeatureError == .creationAlreadyInProgress)
        }

        viewModel.finishInvoiceCreation()
        #expect(!(viewModel.isCreatingInvoice))
        #expect(throws: Never.self) { try viewModel.beginInvoiceCreation() }
        viewModel.finishInvoiceCreation()
    }

    @Test func FeatureOwnedCreationIncrementsKnownStoreTotalForFilteredList() async throws {
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

        #expect(!(viewModel.hasActiveListFilters))
        #expect(viewModel.totalInvoiceCount == 11)
        #expect(viewModel.invoiceEntities.map(\.id) == [id])
        #expect(viewModel.selectedInvoice?.id == id)
    }

    @Test func EditorMutationsReconcileRowsTotalsAndSelectionSymmetrically() async throws {
        let (_, context) = try ModelContainerFactory.makeInMemoryContext()
        let first = Invoice(invoiceNumber: "INV-FIRST")
        context.insert(first)
        try context.save()
        let viewModel = InvoicesContainerViewModel(modelContext: context)

        await viewModel.reconcileEditorMutation(.inserted(first.id))
        #expect(viewModel.totalInvoiceCount == 1)
        #expect(viewModel.selectedInvoice?.id == first.id)

        first.invoiceNumber = "INV-FIRST-UPDATED"
        try context.save()
        await viewModel.reconcileEditorMutation(.updated(first.id))
        #expect(viewModel.invoiceEntities.first?.invoiceNumber == "INV-FIRST-UPDATED")
        #expect(viewModel.totalInvoiceCount == 1)

        let second = Invoice(invoiceNumber: "INV-SECOND")
        context.insert(second)
        try context.save()
        await viewModel.reconcileEditorMutation(.inserted(second.id))
        #expect(viewModel.totalInvoiceCount == 2)
        #expect(viewModel.selectedInvoice?.id == second.id)

        context.delete(second)
        try context.save()
        await viewModel.reconcileEditorMutation(.deleted(second.id))
        #expect(viewModel.totalInvoiceCount == 1)
        #expect(viewModel.invoiceEntities.map(\.id) == [first.id])
        #expect(viewModel.selectedInvoice == nil)
    }

    @Test func EditorUpdateReappliesActivePersistenceFilters() async throws {
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
        #expect(viewModel.invoiceEntities.map(\.id) == [invoice.id])

        invoice.effectiveStatus = .reviewDraft
        try context.save()
        await viewModel.reconcileEditorMutation(.updated(invoice.id))

        #expect(viewModel.invoiceEntities.isEmpty)
        #expect(viewModel.totalInvoiceCount == 1)
    }

    @Test func EditorInsertionClearsFiltersBeforeRevealingCreatedInvoice() async throws {
        let (_, context) = try ModelContainerFactory.makeInMemoryContext()
        let invoice = Invoice(invoiceNumber: "INV-NEW")
        context.insert(invoice)
        try context.save()

        let viewModel = InvoicesContainerViewModel(modelContext: context)
        viewModel.invoiceSearchText = "No match"
        viewModel.invoiceFilterStatus = [InvoiceStatus.received.rawValue]

        await viewModel.reconcileEditorMutation(.inserted(invoice.id))

        #expect(!(viewModel.hasActiveListFilters))
        #expect(viewModel.invoiceEntities.map(\.id) == [invoice.id])
        #expect(viewModel.selectedInvoice?.id == invoice.id)
        #expect(viewModel.totalInvoiceCount == 1)
    }

    @Test func ActiveFilterDescriptionsAndSummaryFormatting() throws {
        let (_, context) = try ModelContainerFactory.makeInMemoryContext()
        let viewModel = InvoicesContainerViewModel(modelContext: context)

        #expect(viewModel.activeFilterDescriptions.isEmpty)
        #expect(viewModel.activeFilterSummaryText == "")

        viewModel.invoiceSearchText = "Acme"
        viewModel.invoiceFilterStatus = [InvoiceStatus.received.rawValue]
        viewModel.updateFilterMinimumAmount(100.0)
        viewModel.updateFilterMaximumAmount(500.0)

        #expect(!(viewModel.activeFilterDescriptions.isEmpty))
        #expect(viewModel.activeFilterSummaryText.contains("Search \"Acme\""))
        #expect(viewModel.activeFilterSummaryText.contains("Status: Received"))
        #expect(viewModel.activeFilterSummaryText.contains("Amount: 100.00 – 500.00"))

        viewModel.clearListFilters()
        #expect(viewModel.activeFilterDescriptions.isEmpty)
        #expect(viewModel.activeFilterSummaryText == "")
    }

    @Test func ReloadTracksStoreTotalSeparatelyFromMatchingRows() async throws {
        let (_, context) = try ModelContainerFactory.makeInMemoryContext()
        context.insert(Invoice(invoiceNumber: "INV-MATCH"))
        context.insert(Invoice(invoiceNumber: "INV-OTHER"))
        try context.save()

        let viewModel = InvoicesContainerViewModel(modelContext: context)
        let descriptor = FetchDescriptor<Invoice>(
            predicate: #Predicate<Invoice> { $0.invoiceNumber == "INV-MATCH" }
        )

        await viewModel.reloadInvoices(matching: descriptor)

        #expect(viewModel.invoiceEntities.map(\.invoiceNumber) == ["INV-MATCH"])
        #expect(viewModel.totalInvoiceCount == 2)
    }

    @Test func TransientReloadFailurePreservesLastGoodRowsAndSelection() async throws {
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

        #expect(!(viewModel.hasCompletedSuccessfulListLoad))
        await viewModel.reloadInvoices(matching: FetchDescriptor<Invoice>())
        viewModel.requestSelectInvoice(invoice)
        #expect(viewModel.canProjectCurrentListSpec)

        viewModel.invoiceFilterStatus = [InvoiceStatus.pending.rawValue]
        #expect(viewModel.isShowingPreviousQueryResults)
        await fetcher.failSubsequentRequests()

        await viewModel.reloadInvoices(matching: FetchDescriptor<Invoice>())

        #expect(viewModel.hasCompletedSuccessfulListLoad)
        #expect(viewModel.invoiceEntities.map(\.id) == [invoice.id])
        #expect(viewModel.loadedInvoicesByID[invoice.id]?.id == invoice.id)
        #expect(viewModel.selectedInvoice?.id == invoice.id)
        #expect(viewModel.totalInvoiceCount == 1)
        #expect(viewModel.listLoadError != nil)
        #expect(viewModel.isShowingPreviousQueryResults)
    }

    @Test func OpaqueSwiftDataReloadFailureUsesActionableListCopy() async throws {
        let (_, context) = try ModelContainerFactory.makeInMemoryContext()
        let viewModel = InvoicesContainerViewModel(
            modelContext: context,
            listFetcher: OpaqueInvoiceListFetcher()
        )

        let outcome = await viewModel.reloadInvoices(
            matching: FetchDescriptor<Invoice>()
        )

        #expect(outcome == .failed)
        #expect(viewModel.listLoadError == "Invoice data could not be refreshed. Try again.")
    }

    @Test func ReloadAdvancesProjectionRevisionWhenRowCountIsUnchanged() async throws {
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

        #expect(viewModel.listContentRevision > firstRevision)
        #expect(viewModel.invoiceEntities.first?.invoiceNumber == "INV-AFTER")
    }

    @Test func ReloadSeesInvoiceEditsSavedFromIndependentContext() async throws {
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
        let editorInvoice = try try #require(editorContext.fetch(editorDescriptor).first)
        editorInvoice.invoiceNumber = "INV-AFTER"
        try editorContext.save()

        await viewModel.reloadInvoices(matching: FetchDescriptor<Invoice>())

        #expect(viewModel.invoiceEntities.first?.invoiceNumber == "INV-AFTER")
    }

    @Test func StoreRevisionParticipatesInReloadTaskIdentity() {
        let spec = InvoicePersistenceQuerySpec(
            statuses: [InvoiceStatus.pending.rawValue],
            filterStartDate: .distantPast,
            filterEndDate: .distantFuture,
            minimumAmount: 0,
            maximumAmount: 100,
            sortField: .date,
            sortDirection: .descending
        )

        #expect(InvoicesReloadTaskID(persistenceSpec: spec, storeRevision: 1) != InvoicesReloadTaskID(persistenceSpec: spec, storeRevision: 2))
    }

    @Test func PersistenceQueryKeepsAllClientsAvailableForFacetExpansion() async throws {
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

        #expect(projection.availableClientNames == ["Acme", "North"])
        #expect(projection.filteredInvoices.map(\.invoiceNumber) == ["INV-ACME"])
    }

    @Test func DeepLinkClearsFiltersWhenDestinationIsOutsideCurrentRows() throws {
        let (_, context) = try ModelContainerFactory.makeInMemoryContext()
        let destination = Invoice(invoiceNumber: "INV-DESTINATION")
        context.insert(destination)
        try context.save()

        let viewModel = InvoicesContainerViewModel(modelContext: context)
        viewModel.invoiceSearchText = "Other"
        viewModel.invoiceFilterStatus = [InvoiceStatus.pending.rawValue]

        viewModel.selectInvoiceForDeepLink(id: destination.id)

        #expect(viewModel.selectedInvoice?.id == destination.id)
        #expect(!(viewModel.hasActiveListFilters))
    }

    @Test func DeepLinkMaterializesDestinationIntoListImmediately() throws {
        let (_, context) = try ModelContainerFactory.makeInMemoryContext()
        let destination = Invoice(invoiceNumber: "INV-NEW-ROUTE")
        context.insert(destination)
        try context.save()
        let viewModel = InvoicesContainerViewModel(modelContext: context)

        viewModel.selectInvoiceForDeepLink(id: destination.id)

        #expect(viewModel.selectedInvoice?.id == destination.id)
        #expect(viewModel.invoiceEntities.map(\.id) == [destination.id])
        #expect(viewModel.loadedInvoicesByID[destination.id]?.id == destination.id)
        #expect(viewModel.totalInvoiceCount == 1)
    }

    @Test func MissingDeepLinkPreservesListContextAndReportsActionError() throws {
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

        #expect(viewModel.invoiceEntities.map(\.id) == [visibleInvoice.id])
        #expect(viewModel.selectedInvoice == nil)
        #expect(viewModel.invoiceSearchText == "Current search")
        #expect(viewModel.hasActiveListFilters)
        #expect(viewModel.listLoadError == nil)
        #expect(viewModel.actionErrorMessage == "Invoice couldn't be opened because it no longer exists.")
    }

    @Test func ActionErrorDoesNotReplaceListLoadState() throws {
        let (_, context) = try ModelContainerFactory.makeInMemoryContext()
        let invoice = Invoice(invoiceNumber: "INV-STAYS-VISIBLE")
        context.insert(invoice)
        try context.save()
        let viewModel = InvoicesContainerViewModel(modelContext: context)
        viewModel.invoiceEntities = [invoice]

        viewModel.reportActionError("New invoice could not be created.")

        #expect(viewModel.invoiceEntities.map(\.id) == [invoice.id])
        #expect(viewModel.listLoadError == nil)
        #expect(viewModel.actionErrorMessage == "New invoice could not be created.")

        viewModel.dismissActionError()
        #expect(viewModel.actionErrorMessage == nil)
    }

    @Test func SuccessfulInvoiceSelectionDismissesStaleActionError() throws {
        let (_, context) = try ModelContainerFactory.makeInMemoryContext()
        let invoice = Invoice(invoiceNumber: "INV-RECOVERED")
        context.insert(invoice)
        try context.save()
        let viewModel = InvoicesContainerViewModel(modelContext: context)
        viewModel.reportActionError("Previous invoice action failed.")

        viewModel.requestSelectInvoice(invoice)

        #expect(viewModel.selectedInvoice?.id == invoice.id)
        #expect(viewModel.actionErrorMessage == nil)
    }

    @Test func DeepLinkClearsClientFilterWhenDestinationIsAlreadyLoaded() throws {
        let (_, context) = try ModelContainerFactory.makeInMemoryContext()
        let destination = Invoice(invoiceNumber: "INV-NORTH")
        destination.clientName = "North"
        context.insert(destination)
        try context.save()

        let viewModel = InvoicesContainerViewModel(modelContext: context)
        viewModel.updateLoadedInvoices([destination])
        viewModel.filterClients = ["Acme"]

        viewModel.selectInvoiceForDeepLink(id: destination.id)

        #expect(viewModel.selectedInvoice?.id == destination.id)
        #expect(!(viewModel.hasActiveListFilters))
    }

    @Test func SelectionReconciliationClosesFilteredOutInvoice() throws {
        let (_, context) = try ModelContainerFactory.makeInMemoryContext()
        let selected = Invoice(invoiceNumber: "INV-SELECTED")
        context.insert(selected)
        try context.save()

        let viewModel = InvoicesContainerViewModel(modelContext: context)
        viewModel.requestSelectInvoice(selected)

        viewModel.reconcileSelection(visibleInvoiceIDs: [])

        #expect(viewModel.selectedInvoice == nil)
    }

    @Test func SelectionReconciliationPreservesInvoiceHiddenByFilters() throws {
        let (_, context) = try ModelContainerFactory.makeInMemoryContext()
        let selected = Invoice(invoiceNumber: "INV-SELECTED")
        context.insert(selected)
        try context.save()

        let viewModel = InvoicesContainerViewModel(modelContext: context)
        viewModel.requestSelectInvoice(selected)
        viewModel.invoiceSearchText = "No match"

        viewModel.reconcileSelection(visibleInvoiceIDs: [])

        #expect(viewModel.selectedInvoice?.id == selected.id)
    }

    @Test func BulkExportDestinationPreservesExistingPDFs() throws {
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

        #expect(destination.lastPathComponent == "Invoice-001 3.pdf")
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
