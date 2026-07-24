# Handoff Report — Explorer Fetching Remediation Plan

## 1. Observation
We observed thread concurrency violations and data fetching inefficiencies across 10 target files in `InvoicingApplication`:

* **`Packages/Feature.Clients/Sources/Feature_Clients/Views/ServiceAssignmentSheetView.swift`**: Lines 65-71, resolved NDIS items from IDs in a `.task` closure without MainActor isolation or batching:
  ```swift
  let ids = try await actor.fetchAllNDISItemIDs()
  let items = ids.compactMap { modelContext.model(for: $0) as? NDISItem }
  ```
* **`Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/Editor/ModernTemplateEditorView.swift`**: Lines 61-68, concurrency violation inside task:
  ```swift
  let invoices = invoiceIDs.compactMap { modelContext.model(for: $0) as? Invoice }
  ```
* **`Packages/Feature.Settings/Sources/Feature_Settings/Views/TravelCharge/TravelChargeAutomationTestView.swift`**: Lines 124-133, concurrency violation on cooperative thread:
  ```swift
  let sessions = sessionIDs.compactMap { modelContext.model(for: $0) as? Session }
  ```
* **`Packages/Feature.Clients/Sources/Feature_Clients/ViewModels/ClientDetailViewModel+Loading.swift`**: Lines 23-31 and 43-47, loop resolving relationships:
  ```swift
  let services = serviceIDs.compactMap { self.modelContext.model(for: $0) as? ClientService }
  ```
* **`Packages/Feature.Clients/Sources/Feature_Clients/ViewModels/PayeeDetailViewModel.swift`**: Lines 98-100, loop resolving payee relationship items.
* **`Packages/Feature.Clients/Sources/Feature_Clients/ViewModels/PlanManagerDetailViewModel.swift`**: Lines 90-92, loop resolving plan manager relationship items.
* **`Packages/Feature.Invoices/Sources/Feature_Invoices/ViewModels/InvoicesContainerViewModel+List.swift`**: Lines 32-37, list reload fetching model IDs in background but synchronously looping `model(for:)`.
* **`Packages/Feature.Settings/Sources/Feature_Settings/ViewModels/ClaimBatchesViewModel.swift`**: Lines 48-50 and 58-59, batches and lines loop resolution.
* **`Packages/Feature.Settings/Sources/Feature_Settings/Views/TravelCharge/TravelChargeReviewViewModel.swift`**: Lines 50-52, review items loop resolution.
* **`Packages/Feature.Calendar/Sources/Feature_Calendar/ViewModels/CalendarViewModel+Fetching.swift`**: Lines 173-175, calendar sessions loop resolution.

---

## 2. Logic Chain
* **Step 1 (Concurrency isolation)**: Since `modelContext` is not thread-safe and must be isolated to its home queue (Main Actor in this codebase), calling `model(for:)` in a non-isolated task or background thread produces compiler/runtime concurrency violations. Wrapping these lookups inside a `MainActor.run` closure forces thread-safe execution on the Main Actor.
* **Step 2 (Performance optimization)**: Loop-based model resolution (calling `modelContext.model(for:)` for $N$ identifiers sequentially) triggers $N$ database fetches. CoreData / SwiftData is optimized for batch operations. Replacing loops with a single `FetchDescriptor` query using predicate filters or collection containment (e.g. `ids.contains($0.persistentModelID)`) retrieves all items in a single, batched database query, eliminating thread contention and UI lags.

---

## 3. Caveats
* We assumed that the list of IDs fetched by background actors is small enough to fit within memory when batched (which is true, as they represent visible view ranges, specific clients, or template files).
* We did not test compilation or runtime changes as our scope is read-only.
* We assumed SwiftData's SQL translator handles `contains($0.persistentModelID)` for `PersistentIdentifier` arrays correctly. If compilation or runtime errors occur, converting `PersistentIdentifier` arrays to `UUID` arrays (e.g., `s.id`) and querying on `$0.id` is the recommended fallback.

---

## 4. Conclusion
We proposed a robust, detailed remediation plan for all 10 target files. By migrating concurrency-unsafe, loop-based fetches to batched `FetchDescriptor` queries wrapped in `MainActor.run`, the implementation team can resolve both SwiftData concurrency warnings and main-thread blocking bottlenecks.

---

## 5. Verification Method
1. Run target build command:
   ```bash
   swift build
   ```
2. Verify package tests pass:
   ```bash
   swift test --package-path Packages/Core
   ```
3. Use Xcode Instruments (Core Data template) during runtime execution of the client detail, calendar view, and invoice list to verify that the query pattern shifts from numerous sequential `SELECT` statements to single, batched `SELECT` statements.
