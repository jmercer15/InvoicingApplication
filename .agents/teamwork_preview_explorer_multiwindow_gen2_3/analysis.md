# InvoicingApplication: Multi-Window and SwiftData Concurrency Audit

## Executive Summary
This report analyzes the SwiftUI scene topology, SwiftData thread-safety compliance, window-scoped UI state isolation, and testing framework of the InvoicingApplication. The analysis identifies key concurrency vulnerabilities in asynchronous background contexts and selection synchronization gaps in standalone utility windows, proposing concrete structural remediations.

---

## 1. SwiftUI Scene Topology & Instantiation (R1)

### Scene Declarations
The application's scene tree is declared in `Packages/AppShell/Sources/AppShell/App/Scenes/InvoicingApplicationApp.swift` under the `InvoicingApplicationSceneTree` struct, which is instantiated in `InvoicingApplicationApp.swift`. The topology consists of:

1. **Workspace WindowGroup**
   - **Declaration:** `WindowGroup("Workspace", id: AppSceneID.workspace.rawValue)` (lines 28–55)
   - **Root View:** `SessionPhaseRoot` wrapping `WorkspaceWindowRoot`.
   - **Modifiers:** Configuration of `windowStyle(.hiddenTitleBar)` and `windowToolbarStyle(.expanded)` for macOS.
   - **Commands:** Custom commands including `SidebarCommands()`, `ToolbarCommands()`, `InspectorCommands()`, and `AppCommandSet()`.

2. **Settings Window**
   - **Declaration:** `Settings` (lines 57–72)
   - **Root View:** `SessionPhaseRoot` wrapping `SettingsSceneRoot`.
   
3. **Utility Windows (Inspector and Activity)**
   - **Declarations:** 
     - `UtilityWindow("Inspector", id: AppSceneID.inspector.rawValue)` (lines 74–89)
     - `UtilityWindow("Activity", id: AppSceneID.activity.rawValue)` (lines 94–109)
   - **Modifiers:** Both use `.commandsRemoved()`, `.defaultLaunchBehavior(.suppressed)`, and `.restorationBehavior(.disabled)` to act as non-restored panel-style helper windows.

### Instantiation Logic
- The `Workspace` window group supports opening multiple independent document/workspace instances natively (e.g., via File > New Window).
- The `Settings` window is managed as a standard Preferences window.
- The `Utility` windows are panel-like helpers. Their visibility is toggled using `WindowVisibilityToggle` in `AppCommandSet.swift` mapped to menu commands.

### ToolWindowPresenceRegistry Visibility Tracking
The visibility of utility windows is tracked using `ToolWindowPresenceRegistry` (located in `AppShell/Sources/AppShell/App/Composition/ToolWindowPresenceRegistry.swift`), which is a `@MainActor @Observable` class. The tracking logic is bound to the view lifecycle (`onAppear` / `onDisappear`) in `ToolWindowSceneRoots.swift`:
- **Inspector Window:**
  ```swift
  .onAppear {
      toolWindowContext.isOpen = true
      toolWindowPresence.setInspectorStandaloneOpen(true)
  }
  .onDisappear {
      toolWindowContext.isOpen = false
      toolWindowPresence.setInspectorStandaloneOpen(false)
  }
  ```
- **Activity Window:**
  ```swift
  .onAppear {
      toolWindowContext.isOpen = true
      toolWindowPresence.setActivityMonitorOpen(true)
  }
  .onDisappear {
      toolWindowContext.isOpen = false
      toolWindowPresence.setActivityMonitorOpen(false)
  }
  ```

---

## 2. SwiftData Usage & Concurrency (R2)

### Container Lifecycle
- **ModelContainer Initialization:** The shared container is created asynchronously during app bootstrap using `ModelContainerFactory.makePersistentContainer(...)` within `AppDatabase.bootstrap(...)`. This call is scheduled via a detached task in `ProductionRuntimeAssembly.loadDatabase()` to keep it off the launch path.
- **Scope and Sharing:** The container resides in `AppDatabase` on the `AppRuntime` struct inside `AppSession`. The root `InvoicingApplicationApp` maintains a single `@State private var session = AppSession()`, which ensures a single container is loaded. Each scene propagates this container to its view hierarchy using `.modelContainer(runtime.modelContainer)`.

### Concurrency Strategy & Actor Isolation
The codebase enforces strict boundary separation between UI thread execution and background tasks:
1. **UI context (@MainActor):** Feature view-models (e.g., `InvoicesContainerViewModel`, `InvoiceEditorViewModel`) operate on the `@MainActor` and utilize `@Environment(\.modelContext)` from their local window scope.
2. **Off-thread Background Operations (`ModelActor`):** Long-running migrations, CSV/JSON data serialization, and heavy database operations are isolated to custom `ModelActor` instances:
   - `BackfillModelActor` (Status token backfilling)
   - `BulkClaimBuilderActor` (Bulk claim generation)
   - `DataImporterActor` / `DataExporterActor` (JSON/Excel handling)
   - `NDISComplianceValidator` (Rule checking)
   - `TravelChargeAutomationActor` (Geocoding/travel charges)
   - `InvoiceDigestActor` (Aggregate statistics)

### Critical Concurrency Vulnerability: Standard Actor Thread Hops
A severe thread-safety risk exists in `Packages/Data/Sources/Data/Actors/BulkClaimWorkspaceOperations.swift` (lines 30–55):
```swift
    func createClaimBatch(...) async throws -> (batchId: UUID, summary: BulkClaimValidationSummary) {
        let modelContext = ModelContext(modelContainer)
        let batch = BulkClaimBatch(id: UUID())
        ...
        modelContext.insert(batch)
        try modelContext.save()

        let builtLines = try await bulkClaimBuilderActor.buildLines(batchID: batch.id) // ⚠️ SUSPENSION POINT
        let validation = await BulkClaimValidationService().validateAndSummarize(lines: builtLines) // ⚠️ SUSPENSION POINT
        try applyValidationLines(validation.lines, to: batch, in: modelContext) // ⚠️ UNSAFE resumption
        try modelContext.save()
        ...
    }
```
* **Vulnerability:** `BulkClaimWorkspaceOperations` is a standard `actor`, not a `@ModelActor`. A local `ModelContext` and managed `BulkClaimBatch` model instance are created prior to asynchronous `await` calls. When the thread resumes after a suspension point, it may execute on a different cooperative thread. Interacting with the same `modelContext` and `batch` instances on a different thread violates SwiftData's thread confinement, leading to crashes or data corruption.
* **Proposed Solution:** Refactor `BulkClaimWorkspaceOperations` as a `@ModelActor` so all operations are serialized on its isolated executor, or encapsulate database operations in synchronous blocks that do not cross suspension points.

---

## 3. Scoped Window State Isolation (R3)

### State Isolation Mechanism
- **Workspace Windows:** Each workspace window manages its own view-model cache and selection state. The root `WorkspaceWindowRoot` creates a per-window `@State private var sceneSession: WorkspaceSceneSession?` on appear, ensuring independent navigation pipelines.
- **Scene Storage:** UI values like tab selections, visibility states, navigation paths, and selected entity identifiers are persisted per-window using `@SceneStorage` in `AppRootView` (e.g., `"Workspace.SelectedTab"`, `"Workspace.SelectionID"`).

### State Isolation Gaps
1. **Disconnected Standalone Utility Windows:**
   - Standalone utility windows (`Inspector` and `Activity`) currently initialize their own independent `WorkspaceSceneSession` rather than tracking the focused workspace window.
   - Consequently, the standalone `Inspector` does not reflect the selection changes of the focused workspace window, and navigation events triggered inside the `Activity` window (e.g., clicking "Open Invoice") are applied to the Activity window's own hidden session rather than the active workspace.
2. **Proposals for Synchronization:**
   - Expose the active workspace's session using SwiftUI's `@FocusedValue`:
     ```swift
     struct ActiveWorkspaceSessionKey: FocusedValueKey {
         typealias Value = WorkspaceSceneSession
     }
     extension FocusedValues {
         var activeWorkspaceSession: WorkspaceSceneSession? {
             get { self[ActiveWorkspaceSessionKey.self] }
             set { self[ActiveWorkspaceSessionKey.self] = newValue }
         }
     }
     ```
   - Publish it in `AppRootView` / `ContentView`:
     ```swift
     .focusedSceneValue(\.activeWorkspaceSession, sceneSession)
     ```
   - Consume it within `InspectorSceneRoot` and `ActivitySceneRoot` to share navigation managers and feature view models dynamically, aligning their behavior with focused workspace actions.

---

## 4. Existing Tests & Execution (R4)

### Test File Locations
1. **App Target Tests:**
   - `InvoicingApplicationTests/AppSessionTests.swift`
2. **AppShell Framework Tests:**
   - `Packages/AppShell/Tests/AppShellTests/AppSessionTests.swift`
   - `Packages/AppShell/Tests/AppShellTests/WorkspaceCompositionTests.swift`
   - `Packages/AppShell/Tests/AppShellTests/WorkspaceInspectorContextTests.swift`
   - `Packages/AppShell/Tests/AppShellTests/WorkspaceNavigationRestorationTests.swift`
3. **Data Package Tests:**
   - `Packages/Data/Tests/DataTests/` (contains UseCase, Service, BusinessLogic, and Validation sub-suites)
4. **Feature Package Tests:**
   - `Packages/Feature.BillingHub/Tests/`
   - `Packages/Feature.Invoices/Tests/`
   - `Packages/Feature.Settings/Tests/`

### How to Run Tests
1. **Run Package-Level Tests:**
   ```bash
   for pkg in Packages/*; do
       if [ -d "$pkg/Tests" ]; then
           swift test --package-path "$pkg"
       fi
   done
   ```
2. **Run Application Target Tests:**
   ```bash
   xcodebuild -project InvoicingApplication.xcodeproj -scheme InvoicingApplication -sdk macosx test
   ```

### Test Audit & Concurrency Issues
During our execution of application target tests via `xcodebuild`, we observed a test failure:
- **Failing Test:** `AppSessionTests.testDuplicateBootstrapWhileInFlightDoesNotInvokeBootstrapperTwice()`
- **Reason for Failure:** The test relies on a flaky async pattern:
  ```swift
  async let first: Void = session.bootstrap()
  await Task.yield()
  await session.bootstrap()
  ```
  In heavily loaded test environments, `Task.yield()` does not guarantee that the first task has run enough to transition the state. Under `xcodebuild`, this results in both calls executing simultaneously before state transitions can be checked, leading to duplicate bootstrapper invocations.
- **Remediation:** Refactor the test in the same style as `AppShellTests.testConcurrentBootstrapRunsOnlyOneRuntimeFactory()`, which uses a `Task.sleep` inside the factory closure and invokes `async let` concurrently, preventing timing dependencies on `Task.yield()`.

