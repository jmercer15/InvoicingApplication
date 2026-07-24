# Refactoring Changes and Test Outcomes

This document lists the changes applied to resolve the data-fetching and concurrency issues in `InvoicingApplication`.

## Target File Changes

### 1. `Packages/Feature.Clients/Sources/Feature_Clients/Views/ServiceAssignmentSheetView.swift`
- **Before**: Fetched elements via `modelContext.model(for:)` in a task block.
- **After**: Implemented `FetchDescriptor<NDISItem>` query filtering by ID array. Wrapped the fetch in `MainActor.run` and transferred via a local `@unchecked Sendable` struct `UncheckedSendable<T>` to avoid concurrency warnings on non-`Sendable` SwiftData models. Marked task block with `@MainActor`.

### 2. `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/Editor/ModernTemplateEditorView.swift`
- **Before**: Used `modelContext.model(for:)` to load invoices and businesses.
- **After**: Replaced with `FetchDescriptor<Invoice>` and `FetchDescriptor<Business>` querying by `persistentModelID` inside `MainActor.run`. Transferred via `UncheckedSendable` to the task context. Marked task block with `@MainActor`.

### 3. `Packages/Feature.Settings/Sources/Feature_Settings/Views/TravelCharge/TravelChargeAutomationTestView.swift`
- **Before**: Fetched sessions and businesses using `modelContext.model(for:)`.
- **After**: Replaced with `FetchDescriptor<Session>` and `FetchDescriptor<Business>` querying by `persistentModelID` inside `MainActor.run`. Transferred via `UncheckedSendable`. Marked task block with `@MainActor`.

### 4. `Packages/Feature.Clients/Sources/Feature_Clients/ViewModels/ClientDetailViewModel+Loading.swift`
- **Before**: Loaded services, invoices, agreements, payees, and plan managers via `modelContext.model(for:)`.
- **After**: Replaced both occurrences with direct `FetchDescriptor` queries filtering by `client?.id == clientID` and `FetchDescriptor` with empty arguments for catalogues.

### 5. `Packages/Feature.Clients/Sources/Feature_Clients/ViewModels/PayeeDetailViewModel.swift`
- **Before**: Loaded clients and invoices via `modelContext.model(for:)`.
- **After**: Replaced with direct `FetchDescriptor` queries filtering by `payee?.id == payeeID`.

### 6. `Packages/Feature.Clients/Sources/Feature_Clients/ViewModels/PlanManagerDetailViewModel.swift`
- **Before**: Loaded clients and invoices via `modelContext.model(for:)`.
- **After**: Replaced with direct `FetchDescriptor` queries filtering by `planManager?.id == managerID` and `client?.planManager?.id == managerID`.

### 7. `Packages/Feature.Invoices/Sources/Feature_Invoices/ViewModels/InvoicesContainerViewModel+List.swift`
- **Before**: Loaded invoice IDs and mapped via `modelContext.model(for:)`.
- **After**: Fetched the `FetchDescriptor<Invoice>` descriptor directly.

### 8. `Packages/Feature.Settings/Sources/Feature_Settings/ViewModels/ClaimBatchesViewModel.swift`
- **Before**: Loaded bulk claim batches and line IDs and mapped via `modelContext.model(for:)`.
- **After**: Replaced with `FetchDescriptor<BulkClaimBatch>` sorted by `createdAt` descending, and `FetchDescriptor<BulkClaimLine>` filtered by `batch?.id == batchId`.

### 9. `Packages/Feature.Settings/Sources/Feature_Settings/Views/TravelCharge/TravelChargeReviewViewModel.swift`
- **Before**: Fetched travel charge review items using `modelContext.model(for:)`.
- **After**: Replaced with `FetchDescriptor<TravelChargeReviewItem>` query.

### 10. `Packages/Feature.Calendar/Sources/Feature_Calendar/ViewModels/CalendarViewModel+Fetching.swift`
- **Before**: Loaded sessions via `modelContext.model(for:)`.
- **After**: Replaced with `FetchDescriptor<Session>` filtering by `sessionIDs.contains($0.persistentModelID)`.

---

## Verification Outcomes

The script `bash scripts/refactor-verify.sh` was executed to verify the build and test status:

1. **Swift LOC / pattern counts**: Checked successfully.
2. **Architecture guardrails**: Passed successfully.
3. **SharedUI package tests**:
   - Executed: 27 tests
   - Failures: 0
   - Outcome: **PASSED**
4. **Feature.Settings package tests**:
   - Executed: 6 tests
   - Failures: 0
   - Outcome: **PASSED**
5. **Feature.Calendar build**:
   - Outcome: **SUCCESS**
6. **App Debug build**:
   - Outcome: **BUILD SUCCEEDED**
