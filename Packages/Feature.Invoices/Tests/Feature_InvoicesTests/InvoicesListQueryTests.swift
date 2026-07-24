import XCTest
import Core
@testable import Feature_Invoices

@MainActor
final class InvoicesListQueryTests: XCTestCase {
    func testAmountFilterSummaryPreservesLocalizedFractionsAndHugeValues() {
        let locale = Locale(identifier: "en_AU")

        XCTAssertEqual(
            InvoiceFilterSummary.amountRange(
                minimum: 1_234.5,
                maximum: nil,
                locale: locale
            ),
            "Amount: 1,234.5 – –"
        )

        let hugeSummary = InvoiceFilterSummary.amountRange(
            minimum: Double.greatestFiniteMagnitude,
            maximum: nil,
            locale: locale
        )
        XCTAssertTrue(hugeSummary.hasPrefix("Amount: "))
        XCTAssertTrue(hugeSummary.hasSuffix(" – –"))
    }

    func testListPresentationBlocksOnlyBeforeFirstSuccessfulLoad() {
        XCTAssertEqual(
            InvoicesListPresentationPolicy.surface(
                hasProjection: false,
                hasCompletedSuccessfulLoad: false,
                loadError: nil
            ),
            .loading
        )
        XCTAssertEqual(
            InvoicesListPresentationPolicy.surface(
                hasProjection: true,
                hasCompletedSuccessfulLoad: false,
                loadError: "Unavailable"
            ),
            .blockingError("Unavailable")
        )
        XCTAssertEqual(
            InvoicesListPresentationPolicy.surface(
                hasProjection: true,
                hasCompletedSuccessfulLoad: true,
                loadError: "Unavailable"
            ),
            .list(refreshError: "Unavailable")
        )
        XCTAssertEqual(
            InvoicesListPresentationPolicy.surface(
                hasProjection: true,
                hasCompletedSuccessfulLoad: true,
                loadError: nil
            ),
            .list(refreshError: nil)
        )
    }

    func testListEmptyStateOffersOnlyRelevantRecovery() {
        XCTAssertEqual(
            InvoicesListEmptyStatePolicy.resolve(
                totalInvoiceCount: 0,
                filteredCount: 0,
                hasActiveFilters: false
            ),
            .noInvoices
        )
        XCTAssertEqual(
            InvoicesListEmptyStatePolicy.resolve(
                totalInvoiceCount: 4,
                filteredCount: 0,
                hasActiveFilters: true
            ),
            .noMatches
        )
        XCTAssertEqual(
            InvoicesListEmptyStatePolicy.resolve(
                totalInvoiceCount: 4,
                filteredCount: 0,
                hasActiveFilters: false
            ),
            .needsRefresh
        )
        XCTAssertEqual(
            InvoicesListEmptyStatePolicy.resolve(
                totalInvoiceCount: 4,
                filteredCount: 2,
                hasActiveFilters: true
            ),
            .content
        )
    }

    func testProjectionWaitsForMatchingFetchedMembershipButAllowsSortChanges() {
        let loaded = InvoicePersistenceQuerySpec(
            statuses: [InvoiceStatus.pending.rawValue],
            filterStartDate: .distantPast,
            filterEndDate: .distantFuture,
            minimumAmount: 0,
            maximumAmount: 500,
            sortField: .date,
            sortDirection: .descending
        )
        let sortOnlyChange = InvoicePersistenceQuerySpec(
            statuses: loaded.statuses,
            filterStartDate: loaded.filterStartDate,
            filterEndDate: loaded.filterEndDate,
            minimumAmount: loaded.minimumAmount,
            maximumAmount: loaded.maximumAmount,
            sortField: .amount,
            sortDirection: .ascending
        )
        let membershipChange = InvoicePersistenceQuerySpec(
            statuses: [InvoiceStatus.received.rawValue],
            filterStartDate: loaded.filterStartDate,
            filterEndDate: loaded.filterEndDate,
            minimumAmount: loaded.minimumAmount,
            maximumAmount: loaded.maximumAmount,
            sortField: loaded.sortField,
            sortDirection: loaded.sortDirection
        )

        XCTAssertTrue(
            InvoicesProjectionPublicationPolicy.canProject(
                currentSpec: sortOnlyChange,
                loadedSpec: loaded
            )
        )
        XCTAssertFalse(
            InvoicesProjectionPublicationPolicy.canProject(
                currentSpec: membershipChange,
                loadedSpec: loaded
            )
        )
        XCTAssertFalse(
            InvoicesProjectionPublicationPolicy.canProject(
                currentSpec: loaded,
                loadedSpec: nil
            )
        )
    }

    func testAmountFilterInputRequiresCompleteNonnegativeLocalizedNumber() {
        let locale = Locale(identifier: "en_AU")

        XCTAssertEqual(InvoiceFilterAmountInput.parse("", locale: locale), .empty)
        XCTAssertEqual(InvoiceFilterAmountInput.parse("1,234.50", locale: locale), .value(1234.5))
        XCTAssertEqual(InvoiceFilterAmountInput.parse("12x", locale: locale), .invalid)
        XCTAssertEqual(InvoiceFilterAmountInput.parse("-1", locale: locale), .invalid)
        XCTAssertEqual(InvoiceFilterAmountInput.parse("nan", locale: locale), .invalid)
    }

    func testAmountFilterInputRoundTripsLocalizedDisplay() {
        let locale = Locale(identifier: "de_DE")
        let display = InvoiceFilterAmountInput.string(for: 1234.5, locale: locale)

        XCTAssertEqual(InvoiceFilterAmountInput.parse(display, locale: locale), .value(1234.5))
    }

    func testProject_filtersSearchStatusClientAndSortsByAmountDescending() {
        let matching = makeInvoice(
            invoiceNumber: "INV-200",
            totalAmount: 200,
            status: InvoiceStatus.pending.rawValue,
            clientName: "Acme Therapy",
            notes: "Priority invoice"
        )
        let lowerAmountMatch = makeInvoice(
            invoiceNumber: "INV-050",
            totalAmount: 50,
            status: InvoiceStatus.pending.rawValue,
            clientName: "Acme Therapy",
            notes: "Priority follow-up"
        )
        let wrongStatus = makeInvoice(
            invoiceNumber: "INV-999",
            totalAmount: 999,
            status: InvoiceStatus.received.rawValue,
            clientName: "Acme Therapy",
            notes: "Priority"
        )
        let wrongClient = makeInvoice(
            invoiceNumber: "INV-300",
            totalAmount: 300,
            status: InvoiceStatus.pending.rawValue,
            clientName: "Other Client",
            notes: "Priority"
        )

        let spec = InvoicesListQuerySpec(
            searchText: "priority",
            statuses: [InvoiceStatus.pending.rawValue],
            filterStartDate: nil,
            filterEndDate: nil,
            minimumAmount: 40,
            maximumAmount: 250,
            clientNames: ["Acme Therapy"],
            sortField: .amount,
            sortDirection: .descending,
            groupBy: .none
        )

        let projection = InvoicesListQueryEngine.project(
            invoices: [lowerAmountMatch, wrongStatus, matching, wrongClient],
            spec: spec
        )

        XCTAssertEqual(projection.filteredInvoices.map { $0.invoiceNumber }, ["INV-200", "INV-050"])
        XCTAssertEqual(projection.treeItems.map { $0.title }, ["INV-200", "INV-050"])
        XCTAssertEqual(projection.availableClientNames, ["Acme Therapy", "Other Client"])
    }

    func testProject_groupsByClientIntoSectionTreeItems() {
        let first = makeInvoice(invoiceNumber: "INV-001", totalAmount: 100, status: InvoiceStatus.reviewDraft.rawValue, clientName: "Client A")
        let second = makeInvoice(invoiceNumber: "INV-002", totalAmount: 120, status: InvoiceStatus.readyToSend.rawValue, clientName: "Client A")
        let third = makeInvoice(invoiceNumber: "INV-003", totalAmount: 140, status: InvoiceStatus.pending.rawValue, clientName: "Client B")
        let fourth = makeInvoice(invoiceNumber: "INV-004", totalAmount: 160, status: InvoiceStatus.pending.rawValue, clientName: "Client B")
        let fifth = makeInvoice(invoiceNumber: "INV-005", totalAmount: 180, status: InvoiceStatus.received.rawValue, clientName: "Client C")
        let sixth = makeInvoice(invoiceNumber: "INV-006", totalAmount: 200, status: InvoiceStatus.received.rawValue, clientName: "Client C")

        let projection = InvoicesListQueryEngine.project(
            invoices: [first, second, third, fourth, fifth, sixth],
            spec: InvoicesListQuerySpec(
                searchText: "",
                statuses: [],
                filterStartDate: nil,
                filterEndDate: nil,
                minimumAmount: nil,
                maximumAmount: nil,
                clientNames: [],
                sortField: .invoiceNumber,
                sortDirection: .ascending,
                groupBy: .client
            )
        )

        XCTAssertEqual(projection.groupedInvoices.keys.sorted(), ["Client A", "Client B", "Client C"])
        XCTAssertEqual(projection.treeItems.count, 3)
        XCTAssertEqual(projection.treeItems.first?.title, "Client A")
        XCTAssertEqual(projection.treeItems.first?.children?.map { $0.title }, ["INV-001", "INV-002"])
    }

    func testProjectOrdersStatusGroupsByInvoiceWorkflow() {
        let invoices = [
            makeInvoice(invoiceNumber: "INV-VOID", totalAmount: 700, status: InvoiceStatus.voided.rawValue, clientName: "Client"),
            makeInvoice(invoiceNumber: "INV-OVERDUE", totalAmount: 500, status: InvoiceStatus.overdue.rawValue, clientName: "Client"),
            makeInvoice(invoiceNumber: "INV-DRAFT", totalAmount: 100, status: InvoiceStatus.reviewDraft.rawValue, clientName: "Client"),
            makeInvoice(invoiceNumber: "INV-RECEIVED", totalAmount: 400, status: InvoiceStatus.received.rawValue, clientName: "Client"),
            makeInvoice(invoiceNumber: "INV-READY", totalAmount: 200, status: InvoiceStatus.readyToSend.rawValue, clientName: "Client"),
            makeInvoice(invoiceNumber: "INV-CANCELLED", totalAmount: 600, status: InvoiceStatus.cancelled.rawValue, clientName: "Client"),
            makeInvoice(invoiceNumber: "INV-PENDING", totalAmount: 300, status: InvoiceStatus.pending.rawValue, clientName: "Client")
        ]

        let projection = InvoicesListQueryEngine.project(
            invoices: invoices,
            spec: InvoicesListQuerySpec(
                searchText: "",
                statuses: [],
                filterStartDate: nil,
                filterEndDate: nil,
                minimumAmount: nil,
                maximumAmount: nil,
                clientNames: [],
                sortField: .invoiceNumber,
                sortDirection: .ascending,
                groupBy: .status
            )
        )

        XCTAssertEqual(
            projection.treeItems.map(\.title),
            [
                "Review Draft",
                "Ready To Send",
                "Pending",
                "Received",
                "Overdue",
                "Cancelled",
                "Voided"
            ]
        )
    }

    func testProjectOrdersMonthAndQuarterGroupsNewestFirst() {
        let calendar = Calendar(identifier: .gregorian)
        let oldest = makeInvoice(invoiceNumber: "INV-OLD", totalAmount: 100, status: InvoiceStatus.pending.rawValue, clientName: "Client")
        oldest.date = calendar.date(from: DateComponents(year: 2025, month: 1, day: 15))!
        let middle = makeInvoice(invoiceNumber: "INV-MIDDLE", totalAmount: 200, status: InvoiceStatus.pending.rawValue, clientName: "Client")
        middle.date = calendar.date(from: DateComponents(year: 2025, month: 12, day: 15))!
        let newest = makeInvoice(invoiceNumber: "INV-NEW", totalAmount: 300, status: InvoiceStatus.pending.rawValue, clientName: "Client")
        newest.date = calendar.date(from: DateComponents(year: 2026, month: 2, day: 15))!
        let invoices = [oldest, newest, middle]

        for grouping in [GroupBy.month, .quarter] {
            let projection = InvoicesListQueryEngine.project(
                invoices: invoices,
                spec: InvoicesListQuerySpec(
                    searchText: "",
                    statuses: [],
                    filterStartDate: nil,
                    filterEndDate: nil,
                    minimumAmount: nil,
                    maximumAmount: nil,
                    clientNames: [],
                    sortField: .invoiceNumber,
                    sortDirection: .ascending,
                    groupBy: grouping
                )
            )

            XCTAssertEqual(
                projection.treeItems.compactMap { $0.children?.first?.title },
                ["INV-NEW", "INV-MIDDLE", "INV-OLD"],
                "Unexpected \(grouping) group order"
            )
        }
    }

    func testProject_flattensSingleSmallGroupTree() {
        let first = makeInvoice(invoiceNumber: "INV-010", totalAmount: 100, status: InvoiceStatus.pending.rawValue, clientName: "Solo Client")
        let second = makeInvoice(invoiceNumber: "INV-011", totalAmount: 120, status: InvoiceStatus.pending.rawValue, clientName: "Solo Client")

        let projection = InvoicesListQueryEngine.project(
            invoices: [second, first],
            spec: InvoicesListQuerySpec(
                searchText: "",
                statuses: [],
                filterStartDate: nil,
                filterEndDate: nil,
                minimumAmount: nil,
                maximumAmount: nil,
                clientNames: [],
                sortField: .invoiceNumber,
                sortDirection: .ascending,
                groupBy: .status
            )
        )

        XCTAssertEqual(projection.treeItems.map { $0.title }, ["INV-010", "INV-011"])
        XCTAssertNil(projection.treeItems.first?.children)
        XCTAssertEqual(
            projection.treeItems.first?.entityState,
            InvoiceStatus.pending.rawValue
        )
    }

    func testProject_updatesWhenQuerySpecChangesState() {
        var spec = InvoicesListQuerySpec(
            searchText: "",
            statuses: [InvoiceStatus.readyToSend.rawValue],
            filterStartDate: nil,
            filterEndDate: nil,
            minimumAmount: nil,
            maximumAmount: nil,
            clientNames: [],
            sortField: .amount,
            sortDirection: .descending,
            groupBy: .none
        )
        let invoices = [
            makeInvoice(invoiceNumber: "INV-001", totalAmount: 120, status: InvoiceStatus.readyToSend.rawValue, clientName: "Acme", notes: "alpha"),
            makeInvoice(invoiceNumber: "INV-002", totalAmount: 210, status: InvoiceStatus.pending.rawValue, clientName: "Acme", notes: "alpha"),
            makeInvoice(invoiceNumber: "INV-003", totalAmount: 180, status: InvoiceStatus.received.rawValue, clientName: "North", notes: "zeta")
        ]

        let readyOnly = InvoicesListQueryEngine.project(invoices: invoices, spec: spec)
        XCTAssertEqual(readyOnly.filteredInvoices.map(\.invoiceNumber), ["INV-001"])

        spec.searchText = "alpha"
        spec.statuses = [InvoiceStatus.readyToSend.rawValue, InvoiceStatus.pending.rawValue]
        let readyAndPending = InvoicesListQueryEngine.project(invoices: invoices, spec: spec)
        XCTAssertEqual(readyAndPending.filteredInvoices.map(\.invoiceNumber), ["INV-002", "INV-001"])

        spec.statuses = [InvoiceStatus.received.rawValue]
        spec.searchText = ""
        let receivedOnly = InvoicesListQueryEngine.project(invoices: invoices, spec: spec)
        XCTAssertEqual(receivedOnly.filteredInvoices.map(\.invoiceNumber), ["INV-003"])
    }

    func testProjectIgnoresWhitespaceOnlySearchAndUsesStableTieBreak() {
        let lowID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let highID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let first = Invoice(id: highID, invoiceNumber: "INV-HIGH")
        let second = Invoice(id: lowID, invoiceNumber: "INV-LOW")
        first.totalAmount = 100
        second.totalAmount = 100
        let spec = InvoicesListQuerySpec(
            searchText: "  \n ",
            statuses: [],
            filterStartDate: nil,
            filterEndDate: nil,
            minimumAmount: nil,
            maximumAmount: nil,
            clientNames: [],
            sortField: .amount,
            sortDirection: .descending,
            groupBy: .none
        )

        let projection = InvoicesListQueryEngine.project(invoices: [first, second], spec: spec)

        XCTAssertEqual(projection.filteredInvoices.map(\.id), [lowID, highID])
    }

    func testProjectNaturallySortsInvoiceNumbersInEitherDirection() {
        let invoices = [
            makeInvoice(invoiceNumber: "INV-10", totalAmount: 100, status: InvoiceStatus.pending.rawValue, clientName: "Client"),
            makeInvoice(invoiceNumber: "INV-2", totalAmount: 200, status: InvoiceStatus.pending.rawValue, clientName: "Client"),
            makeInvoice(invoiceNumber: "INV-1", totalAmount: 300, status: InvoiceStatus.pending.rawValue, clientName: "Client")
        ]
        var spec = InvoicesListQuerySpec(
            searchText: "",
            statuses: [],
            filterStartDate: nil,
            filterEndDate: nil,
            minimumAmount: nil,
            maximumAmount: nil,
            clientNames: [],
            sortField: .invoiceNumber,
            sortDirection: .ascending,
            groupBy: .none
        )

        XCTAssertEqual(
            InvoicesListQueryEngine.project(invoices: invoices, spec: spec)
                .filteredInvoices.map(\.invoiceNumber),
            ["INV-1", "INV-2", "INV-10"]
        )

        spec.sortDirection = .descending
        XCTAssertEqual(
            InvoicesListQueryEngine.project(invoices: invoices, spec: spec)
                .filteredInvoices.map(\.invoiceNumber),
            ["INV-10", "INV-2", "INV-1"]
        )
    }

    func testProjectNaturallySortsClientNames() {
        let invoices = [
            makeInvoice(invoiceNumber: "INV-1", totalAmount: 100, status: InvoiceStatus.pending.rawValue, clientName: "Client 10"),
            makeInvoice(invoiceNumber: "INV-2", totalAmount: 200, status: InvoiceStatus.pending.rawValue, clientName: "Client 2")
        ]
        let spec = InvoicesListQuerySpec(
            searchText: "",
            statuses: [],
            filterStartDate: nil,
            filterEndDate: nil,
            minimumAmount: nil,
            maximumAmount: nil,
            clientNames: [],
            sortField: .clientName,
            sortDirection: .ascending,
            groupBy: .none
        )

        XCTAssertEqual(
            InvoicesListQueryEngine.project(invoices: invoices, spec: spec)
                .filteredInvoices.compactMap(\.clientName),
            ["Client 2", "Client 10"]
        )
    }

    func testListRowPresentationUsesUsefulMetadataAndSafeFallbacks() {
        let invoice = makeInvoice(
            invoiceNumber: "   ",
            totalAmount: 125.5,
            status: InvoiceStatus.pending.rawValue,
            clientName: "  "
        )
        invoice.currencyCode = "aud"

        let title = InvoiceListRowPresentation.title(for: invoice)
        let subtitle = InvoiceListRowPresentation.subtitle(for: invoice)
        let projection = InvoicesListQueryEngine.project(
            invoices: [invoice],
            spec: InvoicesListQuerySpec(
                searchText: "",
                statuses: [],
                filterStartDate: nil,
                filterEndDate: nil,
                minimumAmount: nil,
                maximumAmount: nil,
                clientNames: [],
                sortField: .date,
                sortDirection: .descending,
                groupBy: .none
            )
        )

        XCTAssertEqual(title, "Untitled Invoice")
        XCTAssertTrue(subtitle.contains("No Client"))
        XCTAssertTrue(subtitle.contains("Pending"))
        XCTAssertTrue(subtitle.contains("125"))
        XCTAssertEqual(projection.treeItems.first?.title, title)
        XCTAssertEqual(projection.treeItems.first?.subtitle, subtitle)
    }

    func testListRowPresentationUsesSharedDefaultForMalformedCurrency() {
        let invoice = makeInvoice(
            invoiceNumber: "INV-001",
            totalAmount: 125.5,
            status: InvoiceStatus.pending.rawValue,
            clientName: "Example Client"
        )
        invoice.currencyCode = "12!"

        let subtitle = InvoiceListRowPresentation.subtitle(for: invoice)
        let expectedAmount = invoice.totalAmount.formatted(
            .currency(code: InvoiceCurrencyCode.defaultValue)
        )

        XCTAssertTrue(subtitle.contains(expectedAmount))
    }

    func testProjectAndPersistenceSpecDefensivelyOrderInvertedRanges() {
        let calendar = Calendar(identifier: .gregorian)
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let middle = calendar.date(byAdding: .day, value: 10, to: start)!
        let end = calendar.date(byAdding: .day, value: 20, to: start)!
        let inside = makeInvoice(
            invoiceNumber: "INV-INSIDE",
            totalAmount: 100,
            status: InvoiceStatus.pending.rawValue,
            clientName: "Acme"
        )
        inside.date = middle
        let outside = makeInvoice(
            invoiceNumber: "INV-OUTSIDE",
            totalAmount: 500,
            status: InvoiceStatus.pending.rawValue,
            clientName: "Acme"
        )
        outside.date = calendar.date(byAdding: .day, value: 30, to: start)!
        let spec = InvoicesListQuerySpec(
            searchText: "",
            statuses: [],
            filterStartDate: end,
            filterEndDate: start,
            minimumAmount: 250,
            maximumAmount: 50,
            clientNames: [],
            sortField: .date,
            sortDirection: .ascending,
            groupBy: .none
        )

        let persistenceSpec = InvoicesListQueryEngine.buildPersistenceQuerySpec(from: spec)
        let projection = InvoicesListQueryEngine.project(invoices: [outside, inside], spec: spec)

        XCTAssertLessThanOrEqual(persistenceSpec.filterStartDate, persistenceSpec.filterEndDate)
        XCTAssertEqual(persistenceSpec.minimumAmount, 50)
        XCTAssertEqual(persistenceSpec.maximumAmount, 250)
        XCTAssertEqual(projection.filteredInvoices.map(\.invoiceNumber), ["INV-INSIDE"])
    }

    func testProjectAndPersistenceSpecIgnoreInvalidProgrammaticAmountBounds() {
        let negative = makeInvoice(
            invoiceNumber: "INV-CREDIT",
            totalAmount: -10,
            status: InvoiceStatus.pending.rawValue,
            clientName: "Acme"
        )
        let positive = makeInvoice(
            invoiceNumber: "INV-STANDARD",
            totalAmount: 100,
            status: InvoiceStatus.pending.rawValue,
            clientName: "Acme"
        )
        let spec = InvoicesListQuerySpec(
            searchText: "",
            statuses: [],
            filterStartDate: nil,
            filterEndDate: nil,
            minimumAmount: -1,
            maximumAmount: .infinity,
            clientNames: [],
            sortField: .amount,
            sortDirection: .ascending,
            groupBy: .none
        )

        let persistenceSpec = InvoicesListQueryEngine.buildPersistenceQuerySpec(from: spec)
        let projection = InvoicesListQueryEngine.project(invoices: [positive, negative], spec: spec)

        XCTAssertEqual(persistenceSpec.minimumAmount, -Double.infinity)
        XCTAssertEqual(persistenceSpec.maximumAmount, Double.infinity)
        XCTAssertEqual(
            projection.filteredInvoices.map(\.invoiceNumber),
            ["INV-CREDIT", "INV-STANDARD"]
        )
    }

    func testBulkActionActivityRejectsOverlapAndStaysBusyWhileSharing() {
        var activity = InvoiceBulkActionActivity()

        XCTAssertTrue(activity.begin(.email, totalCount: 2))
        XCTAssertEqual(activity.phase, .preparing)
        XCTAssertEqual(activity.operation, .email)
        XCTAssertEqual(activity.completedCount, 0)
        XCTAssertEqual(activity.totalCount, 2)
        XCTAssertTrue(activity.canCancel)
        XCTAssertTrue(activity.isBusy)
        XCTAssertFalse(activity.begin(.export, totalCount: 1))

        activity.advance()
        XCTAssertEqual(activity.completedCount, 1)

        activity.beginSharing()
        XCTAssertEqual(activity.phase, .sharing)
        XCTAssertFalse(activity.canCancel)
        XCTAssertTrue(activity.isBusy)
        XCTAssertFalse(activity.begin(.export, totalCount: 1))

        activity.finish()
        XCTAssertEqual(activity.phase, .idle)
        XCTAssertNil(activity.operation)
        XCTAssertEqual(activity.completedCount, 0)
        XCTAssertEqual(activity.totalCount, 0)
        XCTAssertFalse(activity.isBusy)
        XCTAssertTrue(activity.begin(.delete, totalCount: 3))
        XCTAssertFalse(activity.canCancel)
    }

    func testBulkActionActivityCapsProgressAtTotal() {
        var activity = InvoiceBulkActionActivity()

        XCTAssertTrue(activity.begin(.export, totalCount: 1))
        activity.advance()
        activity.advance()

        XCTAssertEqual(activity.completedCount, 1)
        XCTAssertEqual(activity.progressTitle, "Exporting PDFs")
    }

    func testMultiSelectEscapeEndsOnlyIdleSelection() {
        var activity = InvoiceBulkActionActivity()

        XCTAssertEqual(
            InvoiceMultiSelectExitAction.resolve(
                isMultiSelectMode: false,
                activity: activity
            ),
            .ignore
        )
        XCTAssertEqual(
            InvoiceMultiSelectExitAction.resolve(
                isMultiSelectMode: true,
                activity: activity
            ),
            .endSelection
        )

        XCTAssertTrue(activity.begin(.export, totalCount: 2))
        XCTAssertEqual(
            InvoiceMultiSelectExitAction.resolve(
                isMultiSelectMode: true,
                activity: activity
            ),
            .cancelActivity
        )

        activity.beginSharing()
        XCTAssertEqual(
            InvoiceMultiSelectExitAction.resolve(
                isMultiSelectMode: true,
                activity: activity
            ),
            .ignore
        )

        activity.finish()
        XCTAssertTrue(activity.begin(.delete, totalCount: 1))
        XCTAssertEqual(
            InvoiceMultiSelectExitAction.resolve(
                isMultiSelectMode: true,
                activity: activity
            ),
            .ignore
        )
    }

    func testDeleteCopyUsesSingularAndCountAwareBulkLanguage() {
        XCTAssertEqual(InvoiceDeleteCopy.title(count: 1), "Delete Invoice")
        XCTAssertEqual(InvoiceDeleteCopy.actionTitle(count: 1), "Delete Invoice")
        XCTAssertEqual(
            InvoiceDeleteCopy.message(count: 1),
            "Delete 1 invoice? This action cannot be undone."
        )

        XCTAssertEqual(InvoiceDeleteCopy.title(count: 3), "Delete Invoices")
        XCTAssertEqual(InvoiceDeleteCopy.actionTitle(count: 3), "Delete 3 Invoices")
        XCTAssertEqual(
            InvoiceDeleteCopy.message(count: 3),
            "Delete 3 invoices? This action cannot be undone."
        )
        XCTAssertEqual(
            InvoiceDeleteCopy.message(count: 2, discardsUnsavedChanges: true),
            "Delete 2 invoices? This action cannot be undone. Unsaved changes to the open invoice will also be discarded."
        )
    }

    func testBulkResultCopyIdentifiesFailuresAndBoundsDetails() {
        XCTAssertEqual(
            InvoiceBulkResultCopy.message(
                completed: 1,
                action: "exported",
                failures: []
            ),
            "1 invoice exported successfully."
        )

        let failures = [
            InvoiceBulkFailure(invoiceNumber: "INV-1", reason: "Invalid draft."),
            InvoiceBulkFailure(invoiceNumber: "INV-2", reason: "File unavailable."),
            InvoiceBulkFailure(invoiceNumber: "INV-3", reason: "Invoice deleted."),
            InvoiceBulkFailure(invoiceNumber: "INV-4", reason: "Editor busy.")
        ]
        XCTAssertEqual(
            InvoiceBulkResultCopy.message(
                completed: 2,
                action: "attached",
                failures: failures
            ),
            "2 invoices attached; 4 invoices failed.\n"
                + "INV-1: Invalid draft.\n"
                + "INV-2: File unavailable.\n"
                + "INV-3: Invoice deleted.\n"
                + "And 1 more."
        )
    }

    func testBulkDocumentRequestSnapshotsIdentityBeforeAsyncWorkBegins() {
        let invoice = Invoice(invoiceNumber: "INV-ORIGINAL")
        let request = InvoiceBulkDocumentRequest(invoice: invoice)

        invoice.invoiceNumber = "INV-EDITED"

        XCTAssertEqual(request.invoiceID, invoice.id)
        XCTAssertEqual(request.invoiceNumber, "INV-ORIGINAL")
    }

    func testCancelledExportCopyExplainsFilesAlreadyWritten() {
        XCTAssertEqual(
            InvoiceBulkCancellationCopy.exportMessage(
                exportedCount: 0,
                processedCount: 0,
                totalCount: 4,
                failures: []
            ),
            "Export cancelled before any PDFs were created."
        )

        let failures = [
            InvoiceBulkFailure(invoiceNumber: "INV-2", reason: "Invoice deleted.")
        ]
        XCTAssertEqual(
            InvoiceBulkCancellationCopy.exportMessage(
                exportedCount: 2,
                processedCount: 3,
                totalCount: 5,
                failures: failures
            ),
            "Export cancelled after processing 3 of 5 invoices. 2 PDFs were kept.\n\n"
                + "2 invoices exported; 1 invoice failed.\n"
                + "INV-2: Invoice deleted."
        )
    }

    func testEmailCopyUsesInvoiceIdentityForSingleSelection() {
        XCTAssertEqual(
            InvoiceEmailCopy.subject(invoiceNumbers: [" INV-1042 "]),
            "Invoice INV-1042"
        )
        XCTAssertEqual(
            InvoiceEmailCopy.body(invoiceNumbers: [" INV-1042 "]),
            "Please find attached invoice INV-1042."
        )
        XCTAssertEqual(
            InvoiceEmailCopy.subject(invoiceNumbers: ["  "]),
            "Invoice"
        )
        XCTAssertEqual(
            InvoiceEmailCopy.body(invoiceNumbers: ["  "]),
            "Please find attached the invoice."
        )
    }

    func testEmailCopyUsesCountAwareLanguageForBulkSelection() {
        XCTAssertEqual(
            InvoiceEmailCopy.subject(invoiceNumbers: ["INV-1", "INV-2", "INV-3"]),
            "3 Invoices"
        )
        XCTAssertEqual(
            InvoiceEmailCopy.body(invoiceNumbers: ["INV-1", "INV-2", "INV-3"]),
            "Please find attached the selected invoices."
        )
    }

    func testEmailAttachmentManifestDescribesOnlySuccessfulAttachments() {
        var manifest = InvoiceEmailAttachmentManifest()

        manifest.recordAttachment(invoiceNumber: "INV-1")
        // INV-2 failed PDF generation and is intentionally never recorded.
        manifest.recordAttachment(invoiceNumber: " INV-3 ")

        XCTAssertEqual(manifest.invoiceNumbers, ["INV-1", " INV-3 "])
        XCTAssertEqual(manifest.subject, "2 Invoices")
        XCTAssertEqual(manifest.body, "Please find attached the selected invoices.")
    }

    func testShareLifetimeRetainsOwnerUntilTerminalRelease() {
        let lifetime = InvoiceShareLifetime()
        var owner: NSObject? = NSObject()
        weak let weakOwner = owner

        lifetime.begin(retaining: owner!)
        owner = nil

        XCTAssertTrue(lifetime.isActive)
        XCTAssertNotNil(weakOwner)

        lifetime.finish()

        XCTAssertFalse(lifetime.isActive)
        XCTAssertNil(weakOwner)
    }

    private func makeInvoice(
        invoiceNumber: String,
        totalAmount: Double,
        status: String,
        clientName: String,
        notes: String? = nil
    ) -> Invoice {
        let issueDate = Date(timeIntervalSince1970: totalAmount)
        let invoice = Invoice(id: UUID(), invoiceNumber: invoiceNumber)
        invoice.totalAmount = totalAmount
        invoice.date = issueDate
        invoice.dueDate = issueDate.addingTimeInterval(86400)
        invoice.issueDate = issueDate
        invoice.notes = notes
        invoice.status = InvoiceStatus(rawValue: status)
        invoice.clientName = clientName
        return invoice
    }
}
