# InvoicingApplication: Multi-Window and SwiftData Concurrency Audit Report

This report presents the findings of a read-only architectural investigation of the `InvoicingApplication` codebase. The focus of this investigation is to map SwiftUI scene topology, evaluate SwiftData thread safety compliance, audit scoped window state isolation, and document the test infrastructure.

---

## 1. SwiftUI Scene Topology & Instantiation (Task 1)

### Scene Declarations
The root scene tree is bootstraped in `InvoicingApplicationApp.swift` (lines 17–24) and delegates to `InvoicingApplicationSceneTree` declared in `Packages/AppShell/Sources/AppShell/App/Scenes/InvoicingApplicationApp.swift`:

1. **Workspace Window Group:**
   - **Declaration:** `WindowGroup("Workspace", id: AppSceneID.workspace.rawValue)` (lines 28–55)
   - **Main Component:** `WorkspaceWindowRoot` configured with `.modelContainer(runtime.modelContainer)`.
   - **macOS Customizations:** Styled with `.windowStyle(.hiddenTitleBar)` and `.windowToolbarStyle(.expanded)`.
2. **Settings Window:**
   - **Declaration:** `Settings` (lines 57–72)
   - **Main Component:** `SettingsSceneRoot` configured with `.modelContainer(runtime.modelContainer)`.
3. **Inspector Utility Window:**
   - **Declaration:** `UtilityWindow("Inspector", id: AppSceneID.inspector.rawValue)` (lines 74–93)
   - **Main Component:** `InspectorSceneRoot` configured with `.modelContainer(runtime.modelContainer)`.
   - **macOS Customizations:** Configuration uses `.commandsRemoved()`, `.defaultLaunchBehavior(.suppressed)`, and `.restorationBehavior(.disabled)` to present as a panel-like utility window.
4. **Activity Utility Window:**
   - **Declaration:** `UtilityWindow("Activity", id: AppSceneID.activity.rawValue)` (lines 94–113)
   - **Main Component:** `ActivitySceneRoot` configured with `.modelContainer(runtime.modelContainer)`.
   - **macOS Customizations:** Configured with similar panel-like behaviors: `.commandsRemoved()`, `.defaultLaunchBehavior(.suppressed)`, and `.restorationBehavior(.disabled)`.

### Instantiation Logic
All scene groups wrap their contents in `SessionPhaseRoot`. When the asynchronous app bootstrap completes, the ready closure resolves, passing the `AppRuntime` (containing the database container) to the root view.

### Utility Window Presence Registry
Utility window visibility is tracked via the app-level `ToolWindowPresenceRegistry` (in `Packages/AppShell/Sources/AppShell/App/Composition/ToolWindowPresenceRegistry.swift`), which is a `@MainActor @Observable` class injected into the environment.
- **Inspector window visibility** is registered inside `InspectorSceneRoot` (in `ToolWindowSceneRoots.swift`):
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
- **Activity window visibility** is registered inside `ActivitySceneRoot`:
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

## 2. SwiftData Thread Safety Audit (Task 2)

### ModelContainer Instantiation & Sharing
- **Instantiation:** The `ModelContainer` is instantiated asynchronously on a detached thread during bootstrap in `ProductionRuntimeAssembly.swift` via `AppDatabase.bootstrap(policy: .productionSyncRequired)`:
  ```swift
  private static func loadDatabase() async throws -> DatabasePhase {
      return try await Task.detached(priority: .userInitiated) {
          let database = try await AppDatabase.bootstrap(policy: .productionSyncRequired)
          return DatabasePhase(database: database)
      }.value
  }
  ```
- **Sharing:** Since `InvoicingApplicationApp` owns a single `@State private var session = AppSession()`, only one `ModelContainer` is initialized. This container is shared across all windows using the `.modelContainer(runtime.modelContainer)` modifier at each scene level.

### ModelContext Access (MainActor vs Background)
1. **MainActor UI Context:**
   - SwiftUI views retrieve the window's context using `@Environment(\.modelContext)`. This is the container's MainActor-bound `mainContext`.
   - Inside `WorkspaceWindowRoot`, this MainActor-bound context is retrieved and passed down to `WorkspaceSceneSession(Dependencies(..., modelContext: modelContext))` to instantiate view models (such as `CalendarFeature`, `InvoicesFeature`), ensuring safe mutation on the MainActor.
2. **Background Tasks & ModelActors:**
   - Dedicated actors for heavy/background work conform to `ModelActor` (using `DefaultSerialModelExecutor`). This isolates their operations to their own private serial database connection/context.
   - Conforming actors: `BackfillModelActor`, `TravelChargeAutomationActor`, `InvoiceDigestActor`, `WipeDataModelActor`, `BulkClaimBuilderActor`, `DataImporterActor`, `DataExporterActor`, etc.
   - Example (`TravelChargeAutomationActor`):
     ```swift
     public actor TravelChargeAutomationActor: ModelActor {
         nonisolated public let modelContainer: ModelContainer
         nonisolated public let modelExecutor: any ModelExecutor
         public init(modelContainer: ModelContainer) {
             self.modelContainer = modelContainer
             let context = ModelContext(modelContainer)
             context.autosaveEnabled = false
             self.modelExecutor = DefaultSerialModelExecutor(modelContext: context)
         }
     }
     ```

### Thread Safety Compliance Concurrency Risks
- **Concurrency Violation in `BulkClaimWorkspaceOperations.swift`:**
  The `BulkClaimWorkspaceOperations` class is a standard `actor` (not a `@ModelActor` or `@MainActor`).
  Inside `createClaimBatch(...)` (lines 30–55), it instantiates a local `ModelContext` on its background executor, performs asynchronous calls (`await`), and then resumes to read/write from the context:
  ```swift
  func createClaimBatch(...) async throws -> (batchId: UUID, summary: BulkClaimValidationSummary) {
      let modelContext = ModelContext(modelContainer) // 1. context created on background thread
      let batch = BulkClaimBatch(id: UUID())
      ...
      modelContext.insert(batch)
      try modelContext.save()

      let builtLines = try await bulkClaimBuilderActor.buildLines(batchID: batch.id) // 2. SUSPENSION POINT (threat of thread hopping)
      let validation = await BulkClaimValidationService().validateAndSummarize(lines: builtLines) // 3. SUSPENSION POINT
      try applyValidationLines(validation.lines, to: batch, in: modelContext) // 4. Unsafe context access
      try modelContext.save()
      return (batchId: batch.id, summary: validation.summary)
  }
  ```
  **Risk:** SwiftData `ModelContext` and `PersistentModel` (such as `batch`) are not thread-safe. Accessing/modifying them after suspension points on a standard actor violates concurrency rules, leading to race conditions or crashes.
  **Proposals:**
  1. *Refactor to `@ModelActor`*: Make `BulkClaimWorkspaceOperations` conform to `ModelActor`. This enforces that all async tasks resume on the actor's dedicated serial executor, ensuring thread-safe database interactions.
  2. *Refactor to Contiguous Synchronous Block*: Perform the `await` tasks before initializing the context or database models, doing the writes in a single, synchronous, non-await block:
     ```swift
     func createClaimBatch(...) async throws -> (batchId: UUID, summary: BulkClaimValidationSummary) {
         let batchID = UUID()
         let builtLines = try await bulkClaimBuilderActor.buildLines(batchID: batchID)
         let validation = await BulkClaimValidationService().validateAndSummarize(lines: builtLines)
         
         // Perform database updates in a contiguous synchronous method
         try performSynchronousInsert(batchID: batchID, validation: validation, ...)
         return (batchId: batchID, summary: validation.summary)
     }
     ```

---

## 3. Scoped Window State Isolation & Bleed Risks (Task 3)

### State Isolation Mechanism
- **Window Scope:** Each workspace window owns its state. `WorkspaceWindowRoot` uses a `@State private var sceneSession: WorkspaceSceneSession?`, giving each window its own `AppNavigationManager` and local feature view-model caches.
- **Scene Storage:** Window-specific UI settings (e.g. `restoredSelectedTabRaw`, `restoredSelectionID`, `restoredNavigationPathData`, `restoredInspectorPresented`) are isolated using `@SceneStorage` in `AppRootView` (lines 36–43). Since `@SceneStorage` scopes data to the individual window, layout and navigation histories do not bleed across workspace windows.

### Standalone Utility Window Isolation Gaps
Because standalone utility windows instantiate their own completely independent `WorkspaceSceneSession`, they suffer from synchronization gaps:
1. **Inspector Selection Sync:**
   - `InspectorSceneRoot` instantiates its own independent `WorkspaceSceneSession` rather than subscribing to the active/focused workspace.
   - As a result, its local `navigationManager.selection` is `nil` on open, displaying "Select an item to inspect" and failing to track selections made in the main Workspace window.
2. **Activity Window Actions:**
   - In `ActivitySceneRoot`, the navigation handlers (`openInvoice` and `openSession`) are linked to the Activity window's own isolated `navigationManager`. Clicking them updates the Activity window's selection rather than focusing/updating the active Workspace window.

### Proposed Isolation & Synchronization Fixes
To bridge these gaps without bleeding state:
- **Use Focused Scene Values:** Bind Workspace selection/navigation state using `@FocusedSceneValue` (e.g., publishing the active window's `AppNavigationManager`). Standalone utility windows can then read `@FocusedSceneValue` to sync display details or trigger routing on the active workspace.
- **Scene-Level Routing Actions:** Expose a focused command pattern where clicking "Open Invoice" in the Activity window calls a closure published by the active workspace scene, shifting focus and selecting the invoice in the main window instead of internally.

---

## 4. Test Infrastructure (Task 4)

Test targets verify bootstrap processes, navigation management, and model behavior.

### How to Run Tests
1. **Using Xcode Command Line (`xcodebuild`):**
   Run unit/integration tests for the main application and its dependency targets:
   ```bash
   xcodebuild test -project InvoicingApplication.xcodeproj -scheme InvoicingApplication -destination 'platform=macOS'
   ```
2. **Using Swift PM CLI (`swift test`):**
   Run target tests for package components directly (run within the package directory):
   ```bash
   # Execute inside Packages/SharedUI
   swift test
   # Execute inside Packages/AppShell
   swift test
   ```

### Test Coverage Highlights
- **`AppSessionTests` (App level):** Validates the bootstrap engine phases (`.starting`, `.ready(AppRuntime)`, `.failed(AppStartupError)`).
- **`WorkspaceCompositionTests` (AppShell level):** Verifies that multiple `WorkspaceSceneNavigationState` instances maintain completely independent selections and navigation parameters.
- **`WorkspaceInspectorContextTests` (AppShell level):** Tests combined split-screen and standalone inspector visibility calculations, checking that the `ToolWindowPresenceRegistry` responds to appear/disappear triggers.
- **`WorkspaceNavigationRestorationTests` (AppShell level):** Assures navigation paths are correctly sanitized and truncated if they point to deleted or stale database entities.
