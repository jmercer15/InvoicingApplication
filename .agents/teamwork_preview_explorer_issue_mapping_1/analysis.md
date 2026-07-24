# Codebase Performance & SwiftData Fetching Audit Report

## 1. Executive Summary
This report summarizes the findings of a read-only performance audit of the `InvoicingApplication` SwiftUI and SwiftData codebase. The scan focused on two main areas:
1. **Structural Layout Anti-patterns**: Nested scroll views, unconstrained `GeometryReader` loops, and eager vertical/horizontal stacks (`VStack`/`HStack`) instead of lazy stacks (`LazyVStack`/`LazyHStack`) inside scroll areas.
2. **Data-Fetching Inefficiencies**: Synchronous SwiftData fetches, eager model resolution loops (`modelContext.model(for:)`), and thread-safety violations (accessing `ModelContext` on background cooperative task threads).

Multiple critical performance bottlenecks and architectural violations were discovered. Most notably:
- Automatic size-reporting logic utilizing `GeometryReader` registers undo/redo actions, polluting the user's undo stack on every layout pass.
- Eager synchronous model resolution loops resolve all list/calendar sessions on the Main Thread.
- Concurrency violations exist where non-thread-safe `modelContext` calls are executed on cooperative background threads before dispatching to the `MainActor`.

---

## 2. Structural Layout Anti-patterns

### 2.1 Eager VStack inside ScrollView wrapping ForEach
Eager stacks render all of their child views immediately upon initialization, even if they are far off-screen. When rendering lists or templates that can grow arbitrarily, this results in significant frame drops and main-thread stutter.

#### Finding 2.1.1: Document Outline List
- **File**: `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/TemplateEditor/DocumentOutlinePanel.swift`
- **Line Numbers**: 14-16
- **Code Snippet**:
  ```swift
  ScrollView {
      VStack(alignment: .leading, spacing: 2) {
          ForEach(outline) { node in
              // ... renders each outline node eagerly
  ```
- **Rule Violated**: Standard `VStack` inside a `ScrollView` wrapping a `ForEach` loop that renders unbounded data (`outline` of template nodes).
- **Remediation**: Replace `VStack` with `LazyVStack` to defer rendering of off-screen nodes.

#### Finding 2.1.2: Address Search Dropdown
- **File**: `Packages/WorkspaceUI/Sources/WorkspaceUI/NativeAddressSearchField.swift`
- **Line Numbers**: 109-111
- **Code Snippet**:
  ```swift
  ScrollView {
      VStack(alignment: .leading, spacing: 0) {
          ForEach(0..<service.searchResults.count, id: \.self) { index in
              // ... renders search results eagerly
  ```
- **Rule Violated**: Standard `VStack` inside a `ScrollView` wrapping a `ForEach` loop that renders search results.
- **Remediation**: Replace `VStack` with `LazyVStack` to prevent UI pauses when processing large quantities of autocompletion results.

---

### 2.2 Nested ScrollViews on the Same Axis
Nested scroll areas on the same axis create layout ambiguity, break inertial scrolling, and often confuse the SwiftUI layout engine, leading to double-layout passes and poor scroll performance.

#### Finding 2.2.1: Import Results Detail View
- **File**: `Packages/Feature.Settings/Sources/Feature_Settings/Views/ImportExport/ImportExportView.swift`
- **Line Numbers**: 351-358 nested inside 369
- **Code Snippet**:
  ```swift
  // Main view body wrapper (Line 369)
  ScrollView {
      VStack {
          // ...
          SettingsCard(title: "Details") {
              ScrollView { // Line 351 (Nested on the same vertical axis)
                  LazyVStack(alignment: .leading, spacing: 4) {
                      ForEach(Array(results.messages.enumerated()), id: \.offset) { index, message in
                          Text(message)
                          // ...
  ```
- **Rule Violated**: Nested `ScrollView`s within the same vertical axis.
- **Remediation**: Set a fixed height or layout constraint for the details container, or extract the detail view into a separate panel/sheet that has its own scroll boundary, avoiding double-nested vertical scrolling.

---

## 3. GeometryReader Measurement Loops & Undo Pollution

### 3.1 Sizing Reports Modifying Model and Registering Undos
Using `GeometryReader` to dynamically calculate component sizes and column widths is common, but updating a persistent model in `onPreferenceChange` during the layout pass can trigger infinite measurement loops. Even when bounded, writing layout sizes to a model context that tracks undo state registers layout passes as undo history.

#### Finding 3.1.1: Document Grid Layout Height/Width and Column Sizing
- **File**: `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/Components/DocumentGrid/DocumentGridComponent+Layout.swift`
- **Line Numbers**: 5-29 (`updateColumnWidths`), 31-44 (`updateComponentWidth`), 46-59 (`updateComponentHeight`)
- **Code Snippet**:
  ```swift
  @MainActor
  func updateComponentHeight(_ height: CGFloat) {
      guard height > 0 else { return }
      let currentHeight = currentComponent.size.height
      
      // Only update if significantly different to avoid infinite loops
      // And only if the component is NOT currently being resized by the user
      guard abs(height - currentHeight) > 0.5, !currentComponent.isResizing else { return }
      
      document.saveStateForUndo(actionName: "Resize Table") // <--- VIOLATION: registers layout passes for undo
      document.updateComponent(id: currentComponent.id) { component in
          component.size.height = height
      }
  }
  ```
- **Rule Violated**: `GeometryReader` layout measurements trigger persistent state updates that register undo states (`saveStateForUndo`) on layout pass triggers. This pollutes the undo history stack (users cannot undo actual edits because of layout-sized states on stack) and forces double layout passes.
- **Remediation**: 
  1. Do not register undo events when automatically updating widths/heights from layout measurements. Undo registration should only occur when the user explicitly resizes a component via drag handles.
  2. Use a distinct transient/non-undoable state for auto-layout sizes, and only commit them to the persistent model context at discrete intervals or on view dismissal.

---

## 4. Synchronous SwiftData Queries & Thread Concurrency Violations

Accessing `ModelContext` on background cooperative task threads violates SwiftData thread-isolation guidelines (which mandate that a context must only be accessed on its associated queue/thread). Furthermore, running loops to resolve hundreds or thousands of `PersistentIdentifier`s synchronously via `modelContext.model(for:)` on the Main Actor blocks the UI during view setup.

### 4.1 SwiftData Thread-Safety Concurrency Violations

#### Finding 4.1.1: Service Assignment Sheet loading NDIS items
- **File**: `Packages/Feature.Clients/Sources/Feature_Clients/Views/ServiceAssignmentSheetView.swift`
- **Line Numbers**: 61-76
- **Code Snippet**:
  ```swift
  .task {
      isLoadingItems = true
      let actor = ReferenceDataWorkflowActor(modelContainer: modelContext.container)
      do {
          let ids = try await actor.fetchAllNDISItemIDs()
          // VIOLATION: modelContext is accessed on cooperative thread pool
          let items = ids.compactMap { modelContext.model(for: $0) as? NDISItem } 
          await MainActor.run {
              self.availableNDISItems = items
              self.updateFilteredItems()
              self.isLoadingItems = false
          }
      } // ...
  ```
- **Rule Violated**: Concurrency guidelines violated by accessing `modelContext.model(for:)` on a background thread instead of wrapping it inside `MainActor.run` or performing the resolution on the background `ReferenceDataWorkflowActor`. Eager resolution of all database NDIS items.
- **Remediation**: Run the `model(for:)` mapping on the Main Actor or implement background resolution on the actor.

#### Finding 4.1.2: Template Editor data refresh
- **File**: `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/Editor/ModernTemplateEditorView.swift`
- **Line Numbers**: 58-71
- **Code Snippet**:
  ```swift
  .task(id: refreshTaskID) {
      let actor = ReferenceDataWorkflowActor(modelContainer: modelContext.container)
      do {
          let invoiceIDs = try await actor.fetchAllInvoiceIDs()
          let businessIDs = try await actor.fetchAllBusinessIDs()
          // VIOLATION: modelContext is accessed on cooperative thread pool
          let invoices = invoiceIDs.compactMap { modelContext.model(for: $0) as? Invoice }
          let businesses = businessIDs.compactMap { modelContext.model(for: $0) as? Business }
          
          await templateDataService.refreshSelectedInvoice(from: invoices)
          templateDataService.updateFallbackBusiness(businesses.first)
      } // ...
  ```
- **Rule Violated**: Concurrency guideline violation and main thread/cooperative pool blocking. Eagerly instantiates all database invoices and businesses.
- **Remediation**: Safely dispatch the `modelContext` calls to the Main Actor, and fetch only the specific models needed (e.g. limit queries instead of loading everything).

#### Finding 4.1.3: Travel Charge Automation Test View
- **File**: `Packages/Feature.Settings/Sources/Feature_Settings/Views/TravelCharge/TravelChargeAutomationTestView.swift`
- **Line Numbers**: 121-137
- **Code Snippet**:
  ```swift
  .task(id: refreshTaskID) {
      let actor = ReferenceDataWorkflowActor(modelContainer: modelContext.container)
      do {
          let sessionIDs = try await actor.fetchAllSessionIDs()
          let businessIDs = try await actor.fetchAllBusinessIDs()
          
          // VIOLATION: modelContext is accessed on cooperative thread pool
          let sessions = sessionIDs.compactMap { modelContext.model(for: $0) as? Session }
          let businesses = businessIDs.compactMap { modelContext.model(for: $0) as? Business }
          
          await MainActor.run {
              viewModel.updateSessions(sessions)
              viewModel.updateBusiness(businesses.first)
          }
      } // ...
  ```
- **Rule Violated**: Thread safety violation (using main thread context on background cooperative thread pool task) and synchronous mapping of all sessions and businesses in the database during view load.
- **Remediation**: Restrict the lookup to required entries only, and run the lookup block inside the Main Actor or a dedicated actor context.

---

### 4.2 Main-Thread Blocking Model Resolution Loops (`model(for:)`)
These ViewModels use `ReferenceDataWorkflowActor` to fetch identifiers in the background, but immediately block the Main Thread (Main Actor) resolving all corresponding model objects in loops.

#### Finding 4.2.1: Client Detail View Relationships
- **File**: `Packages/Feature.Clients/Sources/Feature_Clients/ViewModels/ClientDetailViewModel+Loading.swift`
- **Line Numbers**: 17-31 (`refreshProjectedData`), 37-48 (`loadReferencePickers`)
- **Code Snippet**:
  ```swift
  // Executed on @MainActor view modifier task callback:
  let services = serviceIDs.compactMap { self.modelContext.model(for: $0) as? ClientService }
  let invoices = invoiceIDs.compactMap { self.modelContext.model(for: $0) as? Invoice }
  let agreements = agreementIDs.compactMap { self.modelContext.model(for: $0) as? ServiceAgreement }
  ```
- **Rule Violated**: Synchronous `modelContext.model(for:)` resolution loops executed on the Main Thread during view setup.
- **Remediation**: Use batch fetch descriptors or paginated fetching, or fetch full lightweight representations from the actor rather than doing loop-based entity faulting on the main context.

#### Finding 4.2.2: Payee Detail View Relationships
- **File**: `Packages/Feature.Clients/Sources/Feature_Clients/ViewModels/PayeeDetailViewModel.swift`
- **Line Numbers**: 90-111
- **Code Snippet**:
  ```swift
  // Executed on @MainActor:
  let linkedClients = clientIDs.compactMap { self.modelContext.model(for: $0) as? Client }
  let fetchedInvoices = invoiceIDs.compactMap { self.modelContext.model(for: $0) as? Invoice }
  ```
- **Rule Violated**: Synchronous model resolution loop on the Main Actor during view setup.
- **Remediation**: Avoid resolving all invoices; paginate the list or fetch only recent invoices.

#### Finding 4.2.3: Plan Manager Detail View Relationships
- **File**: `Packages/Feature.Clients/Sources/Feature_Clients/ViewModels/PlanManagerDetailViewModel.swift`
- **Line Numbers**: 82-99
- **Code Snippet**:
  ```swift
  // Executed on @MainActor:
  let linkedClients = clientIDs.compactMap { self.modelContext.model(for: $0) as? Client }
  let fetchedInvoices = invoiceIDs.compactMap { self.modelContext.model(for: $0) as? Invoice }
  ```
- **Rule Violated**: Synchronous model resolution loop on the Main Actor during view setup.
- **Remediation**: Offload resolution or paginate the invoice history list.

#### Finding 4.2.4: Invoices Container List Reload
- **File**: `Packages/Feature.Invoices/Sources/Feature_Invoices/ViewModels/InvoicesContainerViewModel+List.swift`
- **Line Numbers**: 29-45
- **Code Snippet**:
  ```swift
  // Executed on @MainActor:
  let invoices = modelIDs.compactMap { modelContext.model(for: $0) as? Invoice }
  ```
- **Rule Violated**: Eager synchronous model resolution of all list items (potentially hundreds of invoices) on the Main Actor during range or query reloads.
- **Remediation**: Paginate the invoice list or fetch only the visible page items.

#### Finding 4.2.5: Claim Batches List & Lines Refresh
- **File**: `Packages/Feature.Settings/Sources/Feature_Settings/ViewModels/ClaimBatchesViewModel.swift`
- **Line Numbers**: 46-54 (`refreshBatches`), 56-64 (`fetchLines`)
- **Code Snippet**:
  ```swift
  let batches = ids.compactMap { self.modelContext.model(for: $0) as? BulkClaimBatch }
  let lines = ids.compactMap { self.modelContext.model(for: $0) as? BulkClaimLine }
  ```
- **Rule Violated**: Eager synchronous database model resolution loop on the Main Thread.
- **Remediation**: Limit the number of lines fetched at once or use paginated scroll displays.

#### Finding 4.2.6: Travel Charge Review Items Refresh
- **File**: `Packages/Feature.Settings/Sources/Feature_Settings/Views/TravelCharge/TravelChargeReviewViewModel.swift`
- **Line Numbers**: 48-56
- **Code Snippet**:
  ```swift
  let reviews = ids.compactMap { modelContext.model(for: $0) as? TravelChargeReviewItem }
  ```
- **Rule Violated**: Synchronous database model resolution loop on the Main Thread during refresh/view appearance.
- **Remediation**: Restrict the returned reviews or load review models asynchronously.

#### Finding 4.2.7: Calendar View Session Loading
- **File**: `Packages/Feature.Calendar/Sources/Feature_Calendar/ViewModels/CalendarViewModel+Fetching.swift`
- **Line Numbers**: 165-178
- **Code Snippet**:
  ```swift
  // Executed on @MainActor:
  fetchedSessions = sessionIDs.compactMap {
      self.modelContext.model(for: $0) as? Session
  }
  ```
- **Rule Violated**: Eager synchronous model resolution of all calendar session instances in the visible date range on the Main Actor.
- **Remediation**: Resolve sessions incrementally or lazily as day rows render.

---

## 5. Comprehensive Summary of Recommended Remediation Actions

| Issue Area | Targeted Files | Problem Description | Recommended Remediation Action |
| :--- | :--- | :--- | :--- |
| **Structural Layout** | `DocumentOutlinePanel.swift`, `NativeAddressSearchField.swift` | Eager rendering of list content in `ScrollView` via `VStack` | Replace `VStack` with `LazyVStack` to optimize layout time. |
| **Nested ScrollViews** | `ImportExportView.swift` | Nested vertical `ScrollView`s inside a parent vertical `ScrollView` | Constrain height of the details text or extract import details to a separate sheet panel. |
| **GeometryReader Loops** | `DocumentGridComponent+Layout.swift` | Layout preference changes trigger model updates that register undo states | Remove `document.saveStateForUndo` from layout size/column update paths. Make auto-updates transient/non-undoable. |
| **SwiftData Threading** | `ServiceAssignmentSheetView.swift`, `ModernTemplateEditorView.swift`, `TravelChargeAutomationTestView.swift` | Accessing main thread `ModelContext` from cooperative background tasks | Wrap `modelContext.model(for:)` in `await MainActor.run` or fetch entities inside actor/background context boundaries. |
| **Main-Thread Blocking** | `ClientDetailViewModel+Loading.swift`, `InvoicesContainerViewModel+List.swift`, `CalendarViewModel+Fetching.swift`, etc. | Loop-based synchronous entity faulting using `model(for:)` | Implement pagination, lazy model loading, or batch fetch descriptors with fetch limit properties. |
