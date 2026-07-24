# Handoff Report: Packages/Feature.Invoices Analysis & Feature Extension Strategy

## 1. Observation

### 1.1 Package Structure & Target Configuration
- **Package Path**: `Packages/Feature.Invoices`
- **Package.swift Dependencies** (`Packages/Feature.Invoices/Package.swift`, lines 14–19, 23–30):
  ```swift
  dependencies: [
      .package(path: "../Core"),
      .package(path: "../Data"),
      .package(path: "../SharedUI"),
      .package(path: "../Feature.InvoiceTemplateEditor")
  ]
  ```
- **Targets**: `Feature_Invoices` (library target) and `Feature_InvoicesTests` (test target). Strict concurrency enabled (`StrictConcurrency`).

### 1.2 Data Structures & Domain Models
- **Core Domain Model (`Invoice`)** (`Packages/Core/Sources/Core/Models/Invoice.swift`):
  - Model attributes: `id: UUID`, `invoiceNumber: String`, `totalAmount: Double`, `taxRate: Double`, `creditApplied: Double`, `discount: Double`, `date: Date`, `dueDate: Date?`, `issueDate: Date`, `notes: String?`, `paidDate: Date?`, `sentDate: Date?`, `currencyCode: String = "AUD"`, `statusToken: String`, `effectiveStatus: InvoiceStatus`.
  - Financial properties: `financialTotals: InvoiceFinancialCalculator.Totals`, `calculatedTotal: Double`, `subtotal: Double`, `taxAmount: Double`, `discountAmount: Double`.
  - Related entity snapshots: `businessName`, `businessABN`, `businessAddressSnapshot`, `clientName`, `clientNDISNumber`, `clientAddressSnapshot`, `billToName`, `billToEmail`, `billToAddressSnapshot`, `payeeName`, `payeeEmail`, `payeeAddressSnapshot`.
  - Relationships: `items: [InvoiceItem]?`, `client: Client?`, `payee: Payee?`, `business: Business?`, `sessions: [Session]?`.
- **Query & Projection Models** (`Packages/Feature.Invoices/Sources/Feature_Invoices/Models/InvoicesListQuery.swift`):
  - `InvoicesListQuerySpec` (lines 7–18): `searchText`, `statuses`, `filterStartDate`, `filterEndDate`, `minimumAmount`, `maximumAmount`, `clientNames`, `sortField`, `sortDirection`, `groupBy`.
  - `InvoicesListProjection` (lines 20–25): `filteredInvoices: [Invoice]`, `groupedInvoices: [String: [Invoice]]`, `treeItems: [TreeItem]`, `availableClientNames: [String]`.
  - `InvoicePersistenceQuerySpec` (lines 43–51) & `InvoicePersistenceMembershipSpec` (lines 53–59): Bounded constraints for SwiftData predicates.
  - `InvoicesListQueryEngine` (lines 90–439): In-memory and predicate filtering, natural sorting (`compareLocalized`), grouping (`by: status | client | month | quarter | none`), tree item materialization (`makeTreeItems`).
- **View State Models** (`Packages/Feature.Invoices/Sources/Feature_Invoices/ViewModels/InvoicesContainerViewModel.swift` & `Views/InvoicesView.swift`):
  - `InvoiceFilterTag` (lines 13–28): Categorized filter tokens (`search`, `status`, `date`, `amount`, `client`).
  - `GroupBy` enum (lines 31–38): `.none`, `.status`, `.client`, `.month`, `.quarter`.
  - `InvoiceCreationPhase` (lines 57–73): `.idle`, `.preparing`, `.savingCurrentInvoice`, `.creating`.
  - `InvoiceBulkActionActivity` & `InvoiceBulkActionOperation` (`InvoicesView.swift`, lines 21–82): `.export`, `.email`, `.delete` tracking phase, progress, and cancellation capability.

### 1.3 View Models & Architecture
- **`InvoicesContainerViewModel`** (`Packages/Feature.Invoices/Sources/Feature_Invoices/ViewModels/InvoicesContainerViewModel.swift`):
  - `@Observable @MainActor` coordinator. Holds dependencies: `modelContext`, `editorSession: InvoiceEditorSession`, `persistenceCommands: InvoicesPersistenceCommands`, `listFetcher: any InvoiceListFetching`.
  - Subscribes to `SwiftDataStoreChangeMonitor` for reactive updates across windows/tabs.
  - Controls list filter state (`invoiceSearchText`, `invoiceFilterStatus`, `filterStartDate`, `filterEndDate`, `filterMinAmount`, `filterMaxAmount`, `filterClients`).
  - Manages deep-linking selection via `selectInvoiceForDeepLink(id: UUID)` (lines 150–190 in `InvoicesContainerViewModel+List.swift`).
  - Handles feature-owned invoice creation via `createInvoice()` (lines 38–58 in `InvoicesContainerViewModel+List.swift`).
  - Handles editor mutation notifications via `reconcileEditorMutation(_ mutation: InvoiceEditorMutation)` (`inserted`, `updated`, `deleted`).
- **`InvoicesPersistenceCommands`** (`InvoicesContainerViewModel.swift`, lines 385–413):
  - MainActor helper executing SwiftData fetches (`fetchInvoice`, `fetchInvoices`) and deletes (`deleteInvoices`).
- **`InvoiceListFetchActor`** (`InvoicesContainerViewModel.swift`, lines 420–429):
  - `@ModelActor` executing off-main-thread candidate ID fetching and count queries.

### 1.4 Views & Components
- **`InvoicesView`** (`Packages/Feature.Invoices/Sources/Feature_Invoices/Views/InvoicesView.swift`):
  - Primary feature view. Coordinates list context header (`listContextBar`), empty state and content switching (`ScrollableInvoicesList`), multi-selection toolbar (`multiSelectBar`), delete confirmation dialog (`confirmationDialog`), and alert presentations.
  - Integrates bulk export (`bulkExportSelectedInvoices`), bulk email (`bulkEmailSelectedInvoices` using `NSSharingService`), and batch deletion (`performDeleteInvoices`).
- **`InvoicesContentToolbar`** (`Packages/Feature.Invoices/Sources/Feature_Invoices/Views/InvoicesContentToolbar.swift`):
  - `ToolbarContent` defining "New Invoice" primary button, Organize menu (GroupBy & SortBy), and Filter popover button (`InvoiceFilterPopoverContent`).
- **`InvoiceFilterPopoverContent` & `InvoiceFilterAmountField`**:
  - Filter UI allowing users to select multi-status, date ranges, min/max amount thresholds, and client names.

### 1.5 Existing Unit Tests Audit
- Found 4 test files in `Packages/Feature.Invoices/Tests/Feature_InvoicesTests/`:
  1. `InvoicesListQueryTests.swift` (851 lines):
     - Amount filter summary formatting (`testAmountFilterSummaryPreservesLocalizedFractionsAndHugeValues`).
     - Empty state policy resolution (`testListEmptyStateOffersOnlyRelevantRecovery`).
     - Projection publication policy & persistence spec matching (`testProjectionWaitsForMatchingFetchedMembershipButAllowsSortChanges`).
     - Filter amount input parsing (`testAmountFilterInputRequiresCompleteNonnegativeLocalizedNumber`).
     - List projection filtering, natural sorting by invoice number and client name, and grouping (`testProject_filtersSearchStatusClientAndSortsByAmountDescending`, `testProject_groupsByClientIntoSectionTreeItems`, `testProjectOrdersStatusGroupsByInvoiceWorkflow`, `testProjectOrdersMonthAndQuarterGroupsNewestFirst`).
     - Bulk action activity state transitions, exit resolution, delete language, email copy, and export cancellation messaging (`testBulkActionActivityRejectsOverlapAndStaysBusyWhileSharing`, `testMultiSelectEscapeEndsOnlyIdleSelection`, `testBulkResultCopyIdentifiesFailuresAndBoundsDetails`, `testCancelledExportCopyExplainsFilesAlreadyWritten`, `testEmailCopyUsesCountAwareLanguageForBulkSelection`).
  2. `InvoicesPersistenceCommandsTests.swift` (771 lines):
     - Persistence fetch order preservation & deletion handling (`testFetchByUUIDPreservesRequestedOrderAndSkipsDeletedRows`).
     - Filter state clearing & revision tracking (`testClearListFiltersRestoresUnfilteredState`).
     - List load supersession & concurrency safety (`testOlderReloadCannotOverwriteNewerPublishedRows`, `testDeepLinkRevealSupersedesOlderFilteredReload`).
     - Stable deletion (`testDeleteByStableIDsClearsActiveSelectionAndPreservesOtherInvoices`).
     - Creation workflow & preparation failure handling (`testFeatureOwnedCreationMaterializesAndSelectsNewInvoice`, `testFeatureOwnedCreationDoesNotInsertWhenCurrentDraftCannotBePrepared`).
     - Editor mutation reconciliation (`testEditorMutationsReconcileRowsTotalsAndSelectionSymmetrically`, `testEditorUpdateReappliesActivePersistenceFilters`).
     - Transient error recovery & deep-link edge cases (`testTransientReloadFailurePreservesLastGoodRowsAndSelection`, `testMissingDeepLinkPreservesListContextAndReportsActionError`).
     - Export filename collision resolution (`testBulkExportDestinationPreservesExistingPDFs`).
  3. `InvoiceSnapshotRelatedDataTests.swift`:
     - Verification of snapshot generation and related entity snapshotting.
  4. `InvoicesPolishAndAccessibilityTests.swift`:
     - Accessibility announcements and filter tag formatting.

---

## 2. Logic Chain

### 2.1 Revenue & Status Analytics Summary Implementation
1. **Observation**: The current `InvoicesListProjection` (`InvoicesListQuery.swift:20–25`) computes `filteredInvoices: [Invoice]`, but does not aggregate financial metrics across statuses or currencies. Each `Invoice` has a `totalAmount: Double`, `effectiveStatus: InvoiceStatus`, `isOverdue: Bool`, and `currencyCode: String`.
2. **Deduction**: Aggregating metrics on `[Invoice]` (either filtered or total loaded) requires grouping by normalized currency code (`InvoiceCurrencyCode.normalizedOrDefault(invoice.currencyCode)`).
3. **Design Proposal**:
   - Create `InvoiceAnalyticsEngine` in `Packages/Feature.Invoices/Sources/Feature_Invoices/Models/InvoiceAnalyticsEngine.swift`:
     ```swift
     public struct CurrencyAnalyticsMetrics: Equatable, Sendable {
         public let currencyCode: String
         public let totalBilled: Double
         public let totalReceived: Double
         public let totalOutstanding: Double
         public let totalOverdue: Double
         public let draftCount: Int
         public let totalCount: Int
     }

     public struct RevenueAnalyticsSummary: Equatable, Sendable {
         public let metricsByCurrency: [String: CurrencyAnalyticsMetrics]
         public var primaryCurrencyCode: String
     }

     public enum InvoiceAnalyticsEngine {
         public static func summarize(invoices: [Invoice]) -> RevenueAnalyticsSummary { ... }
     }
     ```
   - **Calculation Rules**:
     - `totalBilled`: Sum of `totalAmount` for all active invoices (excluding `.voided` / `.cancelled`).
     - `totalReceived`: Sum of `totalAmount` for invoices with `effectiveStatus == .received`.
     - `totalOutstanding`: Sum of `totalAmount` for invoices with `effectiveStatus == .pending`, `.readyToSend`, or `.overdue`.
     - `totalOverdue`: Sum of `totalAmount` for invoices where `effectiveStatus == .overdue` or `invoice.isOverdue`.
     - `draftCount`: Count of invoices with `effectiveStatus == .reviewDraft`.
   - **ViewModel & UI Integration**:
     - Add `public var analyticsSummary: RevenueAnalyticsSummary` to `InvoicesContainerViewModel`, updated whenever `projection` changes.
     - Add a card-based SwiftUI view `RevenueAnalyticsSummaryView` displayed above `ScrollableInvoicesList` in `InvoicesView` or integrated into `listContextBar`. Provides currency tabs/segmented controls if multiple currencies are present in data.

### 2.2 Invoice Duplication Workflow Implementation
1. **Observation**: `InvoicesContainerViewModel` provides `createInvoice()` which calls `InvoiceEditorStore.createInvoice(in: modelContainer)`. `Invoice` model in `Core` holds line items (`items`), configuration state (`invoiceEditorStateData`), and client/payee/address snapshots.
2. **Deduction**: Duplicating an existing invoice requires creating a clone with a newly generated, auto-incremented invoice number, current dates, draft status, and deep-copied line items.
3. **Design Proposal**:
   - **Auto-Increment Invoice Number Logic**:
     - Helper method `InvoiceNumberGenerator.nextInvoiceNumber(from sourceNumber: String, existingNumbers: Set<String>) -> String`.
     - Parse prefix (e.g. `INV-`) and numeric suffix (e.g. `1042` -> `1043`). If source has no number or is non-standard, append `-COPY` or find next sequential integer.
   - **Duplication Action on `InvoicesContainerViewModel`**:
     ```swift
     @discardableResult
     public func duplicateInvoice(_ sourceInvoice: Invoice) async throws -> UUID {
         try beginInvoiceCreation()
         defer { finishInvoiceCreation() }

         let allExisting = try persistenceCommands.fetchInvoices(ids: ...) // or fetch existing numbers
         let newNumber = InvoiceNumberGenerator.nextInvoiceNumber(
             from: sourceInvoice.invoiceNumber,
             existingNumbers: Set(allExisting.map(\.invoiceNumber))
         )

         let clonedInvoice = Invoice(invoiceNumber: newNumber)
         clonedInvoice.totalAmount = sourceInvoice.totalAmount
         clonedInvoice.taxRate = sourceInvoice.taxRate
         clonedInvoice.discount = sourceInvoice.discount
         clonedInvoice.creditApplied = sourceInvoice.creditApplied
         clonedInvoice.currencyCode = sourceInvoice.currencyCode
         clonedInvoice.date = Date()
         clonedInvoice.issueDate = Date()
         clonedInvoice.dueDate = Calendar.current.date(byAdding: .day, value: 30, to: Date())
         clonedInvoice.effectiveStatus = .reviewDraft
         clonedInvoice.notes = sourceInvoice.notes
         clonedInvoice.paymentTerms = sourceInvoice.paymentTerms
         clonedInvoice.invoiceEditorStateData = sourceInvoice.invoiceEditorStateData

         // Deep clone relationships & snapshots
         clonedInvoice.client = sourceInvoice.client
         clonedInvoice.payee = sourceInvoice.payee
         clonedInvoice.business = sourceInvoice.business
         clonedInvoice.snapshotRelatedData()

         // Deep clone line items
         let clonedItems = (sourceInvoice.items ?? []).map { item in
             InvoiceItem(
                 itemDescription: item.itemDescription,
                 quantity: item.quantity,
                 rate: item.rate,
                 position: item.position,
                 taxRate: item.taxRate
             )
         }
         clonedInvoice.items = clonedItems

         modelContext.insert(clonedInvoice)
         try modelContext.save()

         revealInvoiceInList(clonedInvoice, countAsNew: true)
         requestSelectInvoice(clonedInvoice)
         return clonedInvoice.id
     }
     ```
   - **UI Action Triggers**:
     - Add "Duplicate Invoice" action to context menu in `InvoicesView` tree items, row context menus, and list context toolbar when an invoice is selected.

### 2.3 Batch Data Export Implementation (CSV & JSON)
1. **Observation**: `InvoicesView` already contains `bulkExportSelectedInvoices()` (lines 478–553) which prompts for a destination folder using `NSOpenPanel` and exports individual PDFs.
2. **Deduction**: Supporting CSV and JSON batch data export requires defining summary projections and formatting services for RFC 4180 CSV and ISO-8601 JSON.
3. **Design Proposal**:
   - **Export Formats & Models**:
     - `enum InvoiceDataExportFormat: String, CaseIterable, Identifiable`: `.csv`, `.json`.
     - `struct InvoiceExportRecord: Codable, Sendable`:
       - `invoiceNumber`, `clientName`, `status`, `date`, `dueDate`, `totalAmount`, `subtotal`, `taxAmount`, `discountAmount`, `currencyCode`, `itemCount`, `notes`.
   - **Exporter Engine** (`Services/InvoiceDataExporter.swift`):
     - `static func generateCSV(from invoices: [Invoice]) -> String`: Formats CSV headers and quotes string values containing commas or quotes.
     - `static func generateJSON(from invoices: [Invoice]) throws -> Data`: Uses `JSONEncoder` with `.prettyPrinted` and `.iso8601` date formatting.
   - **UI & Multi-Select Bar Integration**:
     - In `multiSelectBar` and action menus, expand export choices:
       - "Export Data..." -> Submenu: "Export as CSV...", "Export as JSON...".
     - Uses `NSSavePanel` (or `NSOpenPanel`) to let user select save destination file (e.g. `Invoices_Export_2026-07-24.csv`).

### 2.4 Unit Testing Strategy & New Test Coverage
1. **Observation**: Existing unit tests cover query filtering, list projection, persistence commands, editor reconciliation, empty state policies, and bulk PDF/email workflows.
2. **Deduction**: New features must be thoroughly covered by unit tests in `Tests/Feature_InvoicesTests/`.
3. **Required New Tests**:
   - `InvoiceAnalyticsTests.swift`:
     - `testSummarize_calculatesMetricsPerCurrency`: Multi-currency invoices (AUD, USD) correctly segregated into metrics cards.
     - `testSummarize_handlesEmptyList`: Returns empty metrics dictionary without crashing.
     - `testSummarize_excludesVoidedAndCancelledInvoicesFromBilledAndOutstanding`: Verifies voided/cancelled statuses don't inflate revenue figures.
     - `testSummarize_correctlyFlagsOverdueInvoices`: Verifies past `dueDate` with non-received status increments `totalOverdue`.
   - `InvoiceDuplicationTests.swift`:
     - `testDuplicateInvoice_autoIncrementsStandardNumber`: `INV-042` -> `INV-043`.
     - `testDuplicateInvoice_handlesNonNumericSuffixes`: `INV-CUSTOM` -> `INV-CUSTOM-1` or `INV-CUSTOM-COPY`.
     - `testDuplicateInvoice_resetsStatusAndDates`: `date` updated to today, status reset to `reviewDraft`, `paidDate`/`sentDate` cleared.
     - `testDuplicateInvoice_deepClonesItemsAndSnapshots`: Line items and snapshots copied with new unique item IDs.
     - `testDuplicateInvoice_selectsAndRevealsInViewModel`: Selected invoice state in `InvoicesContainerViewModel` points to cloned invoice.
   - `InvoiceDataExportTests.swift`:
     - `testCSVExporter_escapesSpecialCharactersAndFormatsHeaders`: Proper RFC 4180 formatting for client names with commas/quotes.
     - `testJSONExporter_encodesISO8601DatesAndFinancialFields`: Encodes correctly formatted JSON array.
     - `testBatchExport_handlesEmptyAndSingleInvoiceSelections`: Edge cases for zero or single row export.

---

## 3. Caveats

- **Read-Only Scope**: This report provides analysis and architectural design proposals only. No source files under `Packages/Feature.Invoices` or `Packages/Core` were modified.
- **Model Relationship Constraints**: `Invoice` uses SwiftData `@Model` macro with relationships to `InvoiceItem`, `Client`, `Payee`, and `Business`. Duplication must clone child entities within the active `ModelContext` to maintain SwiftData graph integrity.
- **Strict Concurrency**: `Feature.Invoices` is compiled with strict concurrency enabled (`StrictConcurrency`). Any new actors or async exporters must conform to `Sendable` and respect `@MainActor` / `@ModelActor` isolation boundaries.

---

## 4. Conclusion

`Packages/Feature.Invoices` possesses a clean architecture separating persistent querying (`InvoicesListQueryEngine`, `InvoicePersistenceQuerySpec`), state management (`InvoicesContainerViewModel`), UI components (`InvoicesView`, `InvoicesContentToolbar`), and background data fetching (`InvoiceListFetchActor`). 

1. **Analytics Summary**: Can be seamlessly integrated by creating `InvoiceAnalyticsEngine` and a `RevenueAnalyticsSummaryView` component hooked into `InvoicesContainerViewModel.analyticsSummary`.
2. **Invoice Duplication**: Can be cleanly implemented via `duplicateInvoice(_ sourceInvoice: Invoice)` on `InvoicesContainerViewModel`, leveraging `InvoiceNumberGenerator` for auto-incrementing numbers and deep-cloning line items/snapshots.
3. **Batch Export**: Can expand on the existing bulk action UI in `InvoicesView` by adding `InvoiceDataExporter` supporting CSV and JSON generation via `NSSavePanel`.
4. **Unit Tests**: All three new features can be covered by dedicated test suites (`InvoiceAnalyticsTests`, `InvoiceDuplicationTests`, `InvoiceDataExportTests`) in `Packages/Feature.Invoices/Tests/Feature_InvoicesTests`.

---

## 5. Verification Method

To verify existing functionality and future implementations:
1. **Run Unit Tests**:
   ```bash
   swift test --package-path Packages/Feature.Invoices
   ```
2. **Inspect Files**:
   - `Packages/Feature.Invoices/Package.swift`
   - `Packages/Feature.Invoices/Sources/Feature_Invoices/Models/InvoicesListQuery.swift`
   - `Packages/Feature.Invoices/Sources/Feature_Invoices/ViewModels/InvoicesContainerViewModel.swift`
   - `Packages/Feature.Invoices/Sources/Feature_Invoices/ViewModels/InvoicesContainerViewModel+List.swift`
   - `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/InvoicesView.swift`
   - `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/InvoicesContentToolbar.swift`
   - `Packages/Feature.Invoices/Tests/Feature_InvoicesTests/InvoicesListQueryTests.swift`
   - `Packages/Feature.Invoices/Tests/Feature_InvoicesTests/InvoicesPersistenceCommandsTests.swift`
3. **Invalidation Conditions**:
   - Changes to `Invoice` model schema in `Core` breaking financial calculation or snapshot generation.
   - Non-MainActor mutation calls on `InvoicesContainerViewModel` causing strict concurrency compiler errors.
