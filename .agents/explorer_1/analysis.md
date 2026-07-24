# Requirement R1 Investigation & Recommendations: `Packages/Feature.Invoices`

## Overview
This report contains the findings and recommendations from investigating `Packages/Feature.Invoices` for Requirement R1. The investigation focused on four key areas:
1. Empty state matching feedback & active filters
2. Batch deletion & selection reconciliation
3. VoiceOver & accessibility announcements
4. Existing test coverage and gaps

---

## 1. Empty State Matching Feedback & Active Filters

### Findings & Existing Code Locations
- **Empty State Resolution Policy**: `InvoicesListEmptyStatePolicy.resolve(...)` in `InvoicesView.swift` (lines 107-117) evaluates `totalInvoiceCount`, `filteredCount`, and `hasActiveFilters` to return one of four enum states:
  - `.noInvoices`: (`totalInvoiceCount == 0`) — Renders `EmptyStateView` with title `"No Invoices Yet"` and `"New Invoice"` button.
  - `.noMatches`: (`totalInvoiceCount > 0`, `filteredCount == 0`, `hasActiveFilters == true`) — Renders `EmptyStateView` with title `"No Matching Invoices"`, message `activeFilterSummaryText`, and `"Clear Search and Filters"` button.
  - `.needsRefresh`: (`totalInvoiceCount > 0`, `filteredCount == 0`, `hasActiveFilters == false`) — Renders `"Invoices Need Refresh"` with a retry button.
  - `.content`: (`filteredCount > 0`) — Renders `FoldPaperContainer` list.
- **Empty State Rendering**: `ScrollableInvoicesList` in `InvoicesView.swift` (lines 1093-1189).
- **Active Filters Model**:
  - Owned by `InvoicesContainerViewModel` (`InvoicesContainerViewModel.swift` & `InvoicesContainerViewModel+List.swift`):
    - `invoiceSearchText` (`String`)
    - `invoiceFilterStatus` (`Set<String>`)
    - `filterStartDate` / `filterEndDate` (`Date?`)
    - `filterMinAmount` / `filterMaxAmount` (`Double?`)
    - `filterClients` (`Set<String>`)
    - Computed properties: `isDateFilterActive`, `isAmountFilterActive`, `isClientFilterActive`, `hasActiveListFilters`, `activeFilterDescriptions` (`[String]`), `activeFilterSummaryText` (`String`).
- **Filter UI Components**:
  - `InvoicesContentToolbar.swift`: Toolbar item with filter button (`AppToolbarFilterMenuLabel`) displaying `activeFilterCount` badge and popover trigger.
  - `InvoiceFilterPopoverContent.swift`: Popover content containing status grid, date range pickers, amount range fields, and client filter list.
  - `InvoiceFilterAmountField.swift`: Amount field with parsing, validation, and reset revision tracking (`filterInputResetRevision`).
  - `listContextBar` in `InvoicesView.swift` (lines 821-863): Header bar showing result summary string (e.g. `"3 of 10 invoices"`), `"Clear Filters"` button, and `"Selected invoice hidden"` orange badge with `"Reveal Selected"` button if active selection is hidden by list filters.
- **Clear Button Behavior**:
  - `clearListFilters()` in `InvoicesContainerViewModel.swift` (lines 172-181) resets search, status, date bounds, amount bounds, clients, and increments `filterInputResetRevision`.
  - Popover reset buttons: Section-level reset for Status, Date, Amount, and Client, plus top `"Clear All"`.
  - Empty state reset button: `"Clear Search and Filters"` calls `onClearFilters()`.
  - Context bar reset buttons: `"Clear Filters"` and `"Reveal Selected"` call `clearListFilters()`.

### Recommendations for R1
1. **Granular Empty State Dismissal**: In `.noMatches` empty state, provide chip buttons for clearing specific active filter components (e.g., clear search vs. clear status) alongside the all-inclusive `"Clear Search and Filters"`.
2. **Animation Continuity**: Ensure smooth layout transitions when clearing filters or when transitioning between empty state and content.

---

## 2. Batch Deletion & Selection Reconciliation

### Findings & Existing Code Locations
- **Selection State**:
  - Single selection: `selectedInvoice` (`Invoice?`) on `InvoicesContainerViewModel` (modified via `requestSelectInvoice`, `clearSelection`, `applySelection` in `InvoicesContainerViewModel+Detail.swift`).
  - Multi-selection state: `@State private var isMultiSelectMode = false` and `@State private var selectedInvoiceIDs: Set<UUID> = []` in `InvoicesView.swift` (lines 255-256).
  - Tree item selection highlighting: `highlightedTreeItemIDs` in `InvoicesView.swift` (lines 879-887) maps active selection to tree item IDs (`"invoice_\(id)"`).
- **Batch Deletion Flow**:
  - Multi-select bar: `multiSelectBar` in `InvoicesView.swift` (lines 676-743) displays `"Actions"` Menu with `"Delete Selected"` (role `.destructive`) triggering `deleteSelectedInvoices()`.
  - Confirmation dialog: `deleteSelectedInvoices()` sets `deleteBatch = InvoiceDeleteBatch(invoiceIDs: selectedInvoiceIDs)`. `InvoicesView` shows `.confirmationDialog` using count-aware titles/messages from `InvoiceDeleteCopy`.
  - Execution: `performDeleteInvoices` calls `containerViewModel.deleteInvoices(ids: Array(invoiceIDs))`.
  - Persistence logic: `deleteInvoices(ids:)` in `InvoicesContainerViewModel+List.swift` (lines 103-128):
    - Prepares deletion lease on `editorSession.prepareForDeletingInvoices`.
    - Executes deletion via `persistenceCommands.deleteInvoices`.
    - Completes deletion lease via `editorSession.completeDeletingInvoices`.
    - Removes deleted IDs from `invoiceEntities`, updates `totalInvoiceCount`.
    - Clears single selection if `selectedInvoice?.id` was deleted (`applySelection(nil)`).
- **Selection Reconciliation Logic**:
  - In `InvoicesView.swift` (lines 350-356): `.onChange(of: visibleInvoiceIDs)` prunes `selectedInvoiceIDs` to `selectedInvoiceIDs.intersection(visibleIDs)` and calls `reconcileSelection(visibleInvoiceIDs:)`.
  - `reconcileSelection(visibleInvoiceIDs:)` in `InvoicesContainerViewModel+List.swift` (lines 141-148):
    - If `selectedInvoice?.id` is not in `visibleInvoiceIDs`:
      - If `!hasActiveListFilters`: clears selection (`requestClearSelection()`).
      - If `hasActiveListFilters`: retains `selectedInvoice` so open draft session stays alive, and UI displays `"Selected invoice hidden"` badge.
  - Editor mutation reconciliation: `reconcileEditorMutation(_ mutation:)` (lines 192-234):
    - `.deleted(id)`: removes from loaded entities and clears `selectedInvoice` if matching.
    - `.inserted(id)`: clears list filters and selects new invoice.
    - `.updated(id)`: reloads list query.

### Recommendations for R1
1. **Keyboard Shortcuts for Batch Operations**:
   - Currently, batch deletion can only be triggered via mouse click on the `"Actions"` menu.
   - **Recommendation**: Add key binding for `Cmd+Delete` or `Delete`/`Backspace` key in `InvoicesView` when `isMultiSelectMode` is true or when list focus is present.
2. **Keyboard Shortcut for Select All**:
   - **Recommendation**: Wire `Cmd+A` keyboard shortcut in `InvoicesView` to toggle select all visible invoices when in multi-select mode.

---

## 3. VoiceOver & Accessibility Announcements

### Findings & Existing Code Locations
- **Existing Accessibility Attributes**:
  - `InvoiceFilterAmountField.swift`: `.accessibilityLabel("\(title) invoice amount")`, `.accessibilityValue`, `.accessibilityHint`.
  - `InvoiceFilterPopoverContent.swift`: `StatusFilterButton` and `ClientFilterButton` add `.accessibilityAddTraits(.isButton)` and `.accessibilityAddTraits(isSelected ? [.isSelected] : [])`.
  - `InvoicesContentToolbar.swift`: `.appToolbarLinkStyle(help: filterHelpText)` supplies help tooltips.
  - `InvoicesView.swift`: `bulkActionProgress` has `.accessibilityLabel` and `.accessibilityValue`. `ScrollableInvoicesList` `.noMatches` button has `.accessibilityLabel("Clear search and all active filters")`. Banners combine/contain accessibility elements.
- **CRITICAL GAP: Missing Dynamic Accessibility Announcements**:
  - **No `AccessibilityNotification.Announcement`** (or `NSAccessibility.post`) calls exist anywhere in `Packages/Feature.Invoices`.
  - Specific unannounced state changes for VoiceOver users:
    1. **Filter changes & Search updates**: When applying or clearing filters, VoiceOver does not announce the updated match count (e.g. `"Filtered to 4 invoices"` or `"Filters cleared, showing 15 invoices"`).
    2. **Empty state transitions**: VoiceOver is not notified when filtering results in 0 matches.
    3. **Multi-selection changes**: VoiceOver is not notified when toggling multi-select mode, changing item selection count, or selecting/deselecting all (e.g. `"3 invoices selected"`).
    4. **Batch operation status**: Bulk export/delete completion messages are not announced dynamically via `AccessibilityNotification.Announcement`.

### Recommendations for R1
1. **Add `AccessibilityNotification.Announcement` Postings**:
   - Post accessibility announcements on filter state update, filter clear, selection count change, and batch action finish.
2. **Focus Management**:
   - Ensure VoiceOver focus moves logically back to the filter button when popover is closed or when search is cleared.

---

## 4. Existing Tests & Verification Coverage

### Summary of Existing Tests in `Packages/Feature.Invoices/Tests/Feature_InvoicesTests/`
1. `InvoiceSnapshotRelatedDataTests.swift` (114 lines):
   - Validates snapshot related data overrides for plan manager, payee, and client billing authority.
2. `InvoicesListQueryTests.swift` (851 lines):
   - Tests `InvoiceFilterSummary` amount formatting.
   - Tests `InvoicesListPresentationPolicy` surface decisions.
   - Tests `InvoicesListEmptyStatePolicy` resolution logic.
   - Tests `InvoicesProjectionPublicationPolicy` publication rules.
   - Tests `InvoiceFilterAmountInput` localized parsing and display.
   - Tests `InvoicesListQueryEngine.project` filtering (search, status, amount, client), grouping (client, status, month, quarter), and natural sorting.
   - Tests row title/subtitle presentation and range bounds safety.
   - Tests bulk action state machines (`InvoiceBulkActionActivity`, `InvoiceMultiSelectExitAction`).
   - Tests copy formatting helpers (`InvoiceDeleteCopy`, `InvoiceBulkResultCopy`, `InvoiceBulkCancellationCopy`, `InvoiceEmailCopy`, `InvoiceEmailAttachmentManifest`).
3. `InvoicesPersistenceCommandsTests.swift` (771 lines):
   - Tests persistence commands fetching by IDs while preserving order.
   - Tests filter clear & reset revision behavior.
   - Tests date/amount endpoint ordering updates.
   - Tests list load request invalidation and supersession (`reloadInvoices`).
   - Tests deep-link selection behavior (clearing filters, materialization, missing destination error handling).
   - Tests `deleteInvoices(ids:)` clearing selection and deleting records.
   - Tests invoice creation flow (`createInvoice()`).
   - Tests editor mutation reconciliation (`reconcileEditorMutation`).
   - Tests filter summary formatting, transient reload errors, store revision handling, export filename clash avoidance.

### Test Coverage Gaps for R1
- **Accessibility Announcement Tests**: No existing unit tests verify accessibility notification strings or accessibility trait updates.
- **Keyboard Shortcut Trigger Tests**: No unit tests cover keyboard shortcut state handlers for batch selection or deletion.

---

## Summary Recommendation Matrix for Requirement R1

| Focus Area | Current Implementation | Identified Gap | Actionable Recommendation |
|---|---|---|---|
| **Empty State** | `ScrollableInvoicesList` in `InvoicesView.swift` with 4 states | Summary string can be long; single clear button | Add chip-level reset buttons in empty state view for granular filter dismissal |
| **Batch Deletion** | `multiSelectBar` menu -> `.confirmationDialog` -> `deleteInvoices(ids:)` | Missing keyboard shortcut (Delete / Cmd+Delete) | Add `.keyboardShortcut(.delete, modifiers: [.command])` to trigger deletion confirmation |
| **Selection Reconciliation** | `reconcileSelection` preserves hidden selection with orange badge | Fully functional | Retain current dual-reconciliation pattern |
| **VoiceOver Announcements** | Static `.accessibilityLabel` / `.accessibilityValue` present | Zero dynamic `AccessibilityNotification` posts | Implement `AccessibilityNotification.Announcement` posts for filter changes, empty states, selection counts, and bulk actions |
| **Test Suite** | Comprehensive engine, query, persistence & copy unit tests | No accessibility announcement or shortcut unit tests | Add unit tests verifying accessibility announcement text generation and shortcut handlers |
