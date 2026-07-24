# InvoicingApplication: Multi-Window and SwiftData Concurrency Audit

## Executive Summary
This report presents the findings of a read-only architectural investigation of the `InvoicingApplication` codebase. The focus of this investigation is twofold: evaluating the application's readiness for SwiftUI multi-window compliance and auditing SwiftData concurrency safety (specifically regarding thread-safe context usage and container lifecycle sharing).

Key findings include:
- **Shared Storage Foundation:** The application successfully implements a single, shared `ModelContainer` instance pointing to the same SQLite store. This container is loaded at bootstrap time and passed across all scenes.
- **Window State Isolation:** Selection and navigation state are correctly encapsulated in window-specific `WorkspaceSceneSession` view-model trees, preventing cross-window state bleeding.
- **Utility Window Gaps:** Standalone utility windows (`Inspector`, `Activity`) operate in isolated sessions, which breaks selection synchronization and command routing between the active workspace and these panels.
- **Critical Concurrency Risk:** `BulkClaimWorkspaceOperations` (an actor) creates local `ModelContext` instances on a background thread and performs asynchronous `await` calls. Resuming after suspension points on different cooperative threads violates thread safety, risking crashes during concurrent reads and writes.

---

## 1. Scene Topology & Windowing (R1)

### Scene Declarations
The application root is declared in `InvoicingApplication/InvoicingApplicationApp.swift`:
```swift
@MainActor
@main
struct InvoicingApplicationApp: App {
    @State private var session = AppSession()
    @State private var workspaceContext = ApplicationWorkspaceContext()
    @State private var toolWindowPresence = ToolWindowPresenceRegistry()

    init() {
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    var body: some Scene {
        InvoicingApplicationSceneTree(
            session: $session,
            workspaceContext: workspaceContext,
            toolWindowPresence: toolWindowPresence
        )
    }
}
```
The scenes are structured inside `Packages/AppShell/Sources/AppShell/App/Scenes/InvoicingApplicationApp.swift` in `InvoicingApplicationSceneTree`:
1. **Workspace WindowGroup:**
   - **Declaration:** `WindowGroup("Workspace", id: AppSceneID.workspace.rawValue)` (lines 28–55)
   - **Content:** `SessionPhaseRoot` yielding `WorkspaceWindowRoot` injected with `.modelContainer(runtime.modelContainer)` and `.environment` keys.
2. **Settings:**
   - **Declaration:** `Settings` (lines 57–72)
   - **Content:** `SettingsSceneRoot` injected with the shared model container.
3. **Utility Windows (Inspector and Activity):**
   - **Declaration:** `UtilityWindow("Inspector", id: AppSceneID.inspector.rawValue)` (lines 74–93) and `UtilityWindow("Activity", id: AppSceneID.activity.rawValue)` (lines 94–113).
   - **Modifiers:** Both utilize `.commandsRemoved()`, `.defaultLaunchBehavior(.suppressed)`, and `.restorationBehavior(.disabled)` to function as macOS panel style windows.

### Custom `UtilityWindow` Type
`UtilityWindow` is a custom Scene type provided by SwiftUI (part of the macOS SDK, as the application targets `.macOS("26.0")` and imports only `SwiftUI` and `SwiftData` in `InvoicingApplicationApp.swift`).

### Window Presence Registry
Window presence is tracked using `ToolWindowPresenceRegistry` (in `AppShell/Sources/AppShell/App/Composition/ToolWindowPresenceRegistry.swift`), which is a `@MainActor @Observable` class instantiated at the App level and injected into all scenes.
Utility windows update presence via `onAppear` and `onDisappear` modifiers in `ToolWindowSceneRoots.swift`:
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

### Scene Management and Window Opening
- **Workspace:** Supports multiple window instances (e.g. File > New Window) through standard `WindowGroup` behavior.
- **Settings:** Managed as a native macOS Preferences window.
- **Utility Windows:** Opened and toggled via app-level menu commands in `AppCommandSet.swift` (lines 110-112) using `WindowVisibilityToggle`:
  ```swift
  WindowVisibilityToggle(windowID: AppSceneID.inspector.rawValue)
  WindowVisibilityToggle(windowID: AppSceneID.activity.rawValue)
      .keyboardShortcut("a", modifiers: [.command, .shift])
  ```

---

## 2. SwiftData Usage & Concurrency (R2)

### Container Lifecycle
- **Single Authority:** All scenes share a single `ModelContainer` instance pointing to the same persistent store.
- **Creation:** `ModelContainer` is initialized asynchronously during the app bootstrap phase using `ModelContainerFactory.makePersistentContainer(...)` called inside `AppDatabase.bootstrap(...)` (invoked via a detached background task in `ProductionRuntimeAssembly.loadDatabase()`).
- **Sharing:** The container is stored in `AppDatabase` on the `AppRuntime` struct inside `AppSession`. Since the root `InvoicingApplicationApp` maintains a single `@State private var session = AppSession()`, only one runtime and database are initialized. The views retrieve the container via `runtime.modelContainer` and pass it to all scenes via `.modelContainer(container)`.

### Concurrency Strategy & Actor Isolation
The application utilizes `@MainActor` for user-facing database queries/mutations and serial `@ModelActor` background actors for heavy or off-thread tasks:
1. **UI Operations (@MainActor):**
   - Workspace UI and ViewModels (e.g. `ClientDetailViewModel`, `InvoicesContainerViewModel`) run on the `@MainActor`.
   - Each workspace window resolves its main-thread context using `@Environment(\.modelContext)`. This scene-specific `modelContext` is captured and passed down to feature view models, isolating UI transactions to the main actor.
2. **Background Actors (ModelActor):**
   - **`NDISComplianceValidator`:** Actor-isolated validation fetches.
   - **`RelationshipsProjectionActor`:** Heavy search/filter projection computations.
   - **`BackfillModelActor`:** Post-bootstrap migrations and status token backfilling.
   - **`DataImporterActor` / `DataExporterActor`:** JSON/CSV serialization and deserialization.
   - **`BulkClaimBuilderActor`:** Bulk claim BPR line items compilation.
   - **`TravelChargeAutomationActor`:** Off-thread rule-based validation checks.

### Concurrency Vulnerabilities & Context Sharing Risks
- **Unsafe Context Sharing across Suspension Points:**
  In `Packages/Data/Sources/Data/Actors/BulkClaimWorkspaceOperations.swift` (a normal `actor`, not a `@ModelActor`), local `ModelContext` instances are created and used across `await` statements.
  *Example (`BulkClaimWorkspaceOperations.swift:30-55`):*
  ```swift
  func createClaimBatch(...) async throws -> (batchId: UUID, summary: BulkClaimValidationSummary) {
      let modelContext = ModelContext(modelContainer) // 1. Local context created
      let batch = BulkClaimBatch(id: UUID())
      ...
      modelContext.insert(batch)
      try modelContext.save()

      let builtLines = try await bulkClaimBuilderActor.buildLines(batchID: batch.id) // 2. SUSPENSION POINT (hops threads)
      let validation = await BulkClaimValidationService().validateAndSummarize(lines: builtLines) // 3. SUSPENSION POINT (hops threads)
      
      try applyValidationLines(validation.lines, to: batch, in: modelContext) // 4. Unsafe access of context on a potentially different thread!
      try modelContext.save()
      return (batchId: batch.id, summary: validation.summary)
  }
  ```
  Since `ModelContext` is not thread-safe, referencing and modifying it after suspension points in a standard actor violates SwiftData's concurrency rules. The actor should either be refactored into a `@ModelActor` or restrict all context operations to contiguous synchronous blocks or dedicated actors.

- **Ad-Hoc Actor Instantiation in Settings:**
  In `Feature_Settings/SettingsDependencies.swift`, background actors are created on-demand inside computed properties:
  ```swift
  public var importExportCoordinator: ImportExportCoordinator {
      ...
      let coordinator = ImportExportCoordinator(
          dataImporterActor: DataImporterActor(modelContainer: database.container),
          dataExporterActor: DataExporterActor(modelContainer: database.container),
          ...
      )
  }
  ```
  This bypasses `AppDatabase`'s designated factory methods (e.g. `makeDataImporterActor()`), which may lead to multiple concurrent actors operating on separate context pipelines without central coordination.

---

## 3. Window-Specific UI State (R3)

### State Isolation Mechanism
- **Workspace Isolation:** Every workspace window manages its own selection, navigation path, and feature view-model cache.
- **Implementation:** The root view of a workspace window, `WorkspaceWindowRoot`, creates a local `@State private var sceneSession: WorkspaceSceneSession?` on appear. This session instantiates a `WorkspaceSceneNavigationState` (with a dedicated `AppNavigationManager`) and a `WorkspaceFeatureRegistries` bundle.
- **Scene Storage Sync:** UI selection state is bound to `@SceneStorage` keys inside `AppRootView` (e.g. `"Workspace.SelectionID"`, `"Workspace.NavigationPath"`). Because scene storage is per-window, state does not mirror or bleed across workspace windows.

### Utility Window Isolation Gaps
Standalone utility windows behave incorrectly under multi-window conditions due to complete session isolation:
1. **Standalone Inspector Selection:**
   - `InspectorSceneRoot` instantiates its own `WorkspaceSceneSession` rather than subscribing to the active/focused workspace.
   - Its `navigationManager.selection` is initially `nil`, displaying "Select an item to inspect."
   - When a user changes the selection in a workspace window, the standalone Inspector's selection does not update because it lacks a binding to the focused scene's navigation state.
2. **Activity Window Navigation Actions:**
   - In `ActivitySceneRoot`, the navigation handlers (`openInvoice` / `openSession`) are linked to the Activity window's own isolated `navigationManager`.
   - Clicking "Open Invoice" inside the Activity window updates the Activity window's selection rather than focusing and selecting the item in the active workspace window.

---

## 4. Existing Tests (R4)

The test suites verify bootstrap logic, navigation manager decoupling, and persistent storage features:

### Test File Locations
1. **App Tests:**
   - `InvoicingApplicationTests/AppSessionTests.swift`
2. **Framework Tests:**
   - `Packages/AppShell/Tests/AppShellTests/AppSessionTests.swift`
   - `Packages/AppShell/Tests/AppShellTests/WorkspaceCompositionTests.swift`
   - `Packages/AppShell/Tests/AppShellTests/WorkspaceInspectorContextTests.swift`
   - `Packages/AppShell/Tests/AppShellTests/WorkspaceNavigationRestorationTests.swift`

### Test Coverage Highlights
- **`AppSessionTests`:**
  - Verifies that bootstrap failure updates the state to the `.failed` phase.
  - Ensures duplicate bootstrap calls while loading do not trigger multiple runtime loads.
  - Checks that a successful bootstrap correctly updates the phase to `.ready(AppRuntime)`.
- **`WorkspaceCompositionTests`:**
  - `testWorkspaceSceneNavigationStatesOwnIndependentNavigationManagers`: Confirms that two separate `WorkspaceSceneNavigationState` instances maintain completely independent selections and navigation parameters (vital for multi-window).
  - Verifies Command actions (switchToTab, toggleInspector) correctly route and execute through `AppNavigationManager`.
  - Assures search configuration updates route to the corresponding ViewModel.
- **`WorkspaceInspectorContextTests`:**
  - Tests combined split-screen and standalone inspector visibility calculations.
  - Assures `ToolWindowPresenceRegistry` correctly toggles state properties when tool windows appear/disappear.
- **`WorkspaceNavigationRestorationTests`:**
  - `testSanitizedPathTruncatesAtFirstMissingEntity`: Verifies that a stored navigation path is truncated if it points to an entity that no longer exists in the SwiftData database.
  - `testSanitizedSelectionReturnsNilForDeletedEntity`: Confirms selection sanitization correctly resolves to `nil` for deleted entities.
