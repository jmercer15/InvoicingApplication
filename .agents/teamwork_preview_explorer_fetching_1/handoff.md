# Handoff Report - SwiftData Fetching & Concurrency (Milestone 2)

## 1. Observation
1. **ServiceAssignmentSheetView.swift**:
   * Location: Lines 61-76
   * Observed: `.task` modifier launches a cooperative background thread. Inside, `modelContext.model(for: $0)` (which is an environment context retrieved from the view) is accessed directly:
     ```swift
     let items = ids.compactMap { modelContext.model(for: $0) as? NDISItem }
     ```
2. **ModernTemplateEditorView.swift**:
   * Location: Lines 58-71
   * Observed: Cooperative background task maps `invoiceIDs` and `businessIDs` using `modelContext.model(for:)` directly on the thread pool:
     ```swift
     let invoices = invoiceIDs.compactMap { modelContext.model(for: $0) as? Invoice }
     let businesses = businessIDs.compactMap { modelContext.model(for: $0) as? Business }
     ```
3. **TravelChargeAutomationTestView.swift**:
   * Location: Lines 121-137
   * Observed: Maps background ids to `Session` and `Business` on the background thread pool:
     ```swift
     let sessions = sessionIDs.compactMap { modelContext.model(for: $0) as? Session }
     let businesses = businessIDs.compactMap { modelContext.model(for: $0) as? Business }
     ```
4. **ClientDetailViewModel+Loading.swift**:
   * Location: Lines 17-31 (`refreshProjectedData`), 37-48 (`loadReferencePickers`)
   * Observed: Resolves relationships by looping through ids with `modelContext.model(for:)` synchronously on `@MainActor`:
     ```swift
     let services = serviceIDs.compactMap { self.modelContext.model(for: $0) as? ClientService }
     ```
5. **PayeeDetailViewModel.swift**:
   * Location: Lines 90-111
   * Observed: Loop-based sequential resolution on `@MainActor`:
     ```swift
     let linkedClients = clientIDs.compactMap { self.modelContext.model(for: $0) as? Client }
     let fetchedInvoices = invoiceIDs.compactMap { self.modelContext.model(for: $0) as? Invoice }
     ```
6. **PlanManagerDetailViewModel.swift**:
   * Location: Lines 82-99
   * Observed: Synchronous ID mapping loop on `@MainActor`:
     ```swift
     let linkedClients = clientIDs.compactMap { self.modelContext.model(for: $0) as? Client }
     let fetchedInvoices = invoiceIDs.compactMap { self.modelContext.model(for: $0) as? Invoice }
     ```
7. **InvoicesContainerViewModel+List.swift**:
   * Location: Lines 29-45
   * Observed: Loop-based mapping of all loaded invoices on `@MainActor`:
     ```swift
     let invoices = modelIDs.compactMap { modelContext.model(for: $0) as? Invoice }
     ```
8. **ClaimBatchesViewModel.swift**:
   * Location: Lines 46-54 (`refreshBatches`), 56-64 (`fetchLines`)
   * Observed: Sequentially resolves bulk claim batches and line models on `@MainActor`:
     ```swift
     let batches = ids.compactMap { self.modelContext.model(for: $0) as? BulkClaimBatch }
     let lines = ids.compactMap { self.modelContext.model(for: $0) as? BulkClaimLine }
     ```
9. **TravelChargeReviewViewModel.swift**:
   * Location: Lines 48-56
   * Observed: Sequentially resolves review items on `@MainActor`:
     ```swift
     let reviews = ids.compactMap { modelContext.model(for: $0) as? TravelChargeReviewItem }
     ```
10. **CalendarViewModel+Fetching.swift**:
    * Location: Lines 163-178
    * Observed: Eager loop resolution of all session identifiers on `@MainActor`:
      ```swift
      fetchedSessions = sessionIDs.compactMap {
          self.modelContext.model(for: $0) as? Session
      }
      ```

## 2. Logic Chain
1. **Concurrency Violations**:
   * Accessing `modelContext` outside its designated queue/thread violates the concurrency rules of SwiftData/CoreData, leading to runtime data races or crashes.
   * Modifiers like `.task` run on cooperative background threads unless isolated to `@MainActor`.
   * Therefore, wrapping these resolutions in `MainActor.run` or fetching directly on `@MainActor` resolves the violations.
2. **Main Thread Blocking**:
   * Loop-based mapping of IDs to models executing `model(for:)` performs sequential lookups.
   * If there are many entities (such as invoices, NDIS items, or sessions), this incurs O(N) database queries or cache lookups, blocking the Main Actor.
   * SwiftData's `FetchDescriptor` and `modelContext.fetch` execute a single optimized SQLite block fetch.
   * Therefore, replacing sequential loops with a batch `FetchDescriptor` query eliminates Main Actor stutter and improves lookup performance from O(N) to O(1) DB calls.

## 3. Caveats
* None. The proposed modifications are restricted to local concurrency wrapping and batch fetch optimizations.

## 4. Conclusion
* Concurrency violations and main thread blocking issues in the 10 target files have been fully mapped. Detailed replacement code snippets are documented in `analysis.md`.

## 5. Verification Method
1. Apply the replacement snippets to the 10 target files.
2. Open the project in Xcode (`InvoicingApplication.xcworkspace`).
3. Compile the application and ensure no Swift concurrency warnings or compilation errors are generated.
4. Run the test suite:
   ```bash
   xcodebuild -workspace InvoicingApplication.xcworkspace -scheme InvoicingApplicationTests -sdk macosx test
   ```
5. Confirm that all tests pass.
