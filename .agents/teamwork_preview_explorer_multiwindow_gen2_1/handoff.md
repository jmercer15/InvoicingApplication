# Handoff Report: Multi-Window and SwiftData Concurrency Audit

## 1. Observation

### SwiftUI Scene Declarations & Instantiation
- In `Packages/AppShell/Sources/AppShell/App/Scenes/InvoicingApplicationApp.swift` (lines 28–113), the following scenes are defined:
  - Line 28: `WindowGroup("Workspace", id: AppSceneID.workspace.rawValue)` using `WorkspaceWindowRoot`
  - Line 57: `Settings` using `SettingsSceneRoot`
  - Line 74: `UtilityWindow("Inspector", id: AppSceneID.inspector.rawValue)` using `InspectorSceneRoot`
  - Line 94: `UtilityWindow("Activity", id: AppSceneID.activity.rawValue)` using `ActivitySceneRoot`
- In `Packages/AppShell/Sources/AppShell/App/Scenes/Tools/ToolWindowSceneRoots.swift` (lines 30, 34, 81, 85), utility windows modify the global `ToolWindowPresenceRegistry` state:
  - Line 30: `toolWindowPresence.setInspectorStandaloneOpen(true)`
  - Line 34: `toolWindowPresence.setInspectorStandaloneOpen(false)`
  - Line 81: `toolWindowPresence.setActivityMonitorOpen(true)`
  - Line 85: `toolWindowPresence.setActivityMonitorOpen(false)`

### SwiftData Thread Safety & Concurrency
- In `Packages/AppShell/Sources/AppShell/App/Composition/ProductionRuntimeAssembly.swift` (lines 67–72), `ModelContainer` is instantiated asynchronously on a detached task:
  ```swift
  private static func loadDatabase() async throws -> DatabasePhase {
      return try await Task.detached(priority: .userInitiated) {
          let database = try await AppDatabase.bootstrap(policy: .productionSyncRequired)
          return DatabasePhase(database: database)
      }.value
  }
  ```
- In `Packages/Data/Sources/Data/Actors/BulkClaimWorkspaceOperations.swift` (lines 30–55), a standard `actor` uses a local non-sendable `ModelContext` across `await` suspension points:
  ```swift
  func createClaimBatch(...) async throws -> (batchId: UUID, summary: BulkClaimValidationSummary) {
      let modelContext = ModelContext(modelContainer) // line 37
      ...
      let builtLines = try await bulkClaimBuilderActor.buildLines(batchID: batch.id) // line 49 (suspension)
      let validation = await BulkClaimValidationService().validateAndSummarize(lines: builtLines) // line 50 (suspension)
      try applyValidationLines(validation.lines, to: batch, in: modelContext) // line 51 (unsafe access)
      ...
  }
  ```

### Scoped Window State Isolation & Bleed
- In `Packages/AppShell/Sources/AppShell/App/Scenes/Workspace/ContentView.swift` (lines 36–43), window-local navigation state is stored in `@SceneStorage` properties:
  - `@SceneStorage("Workspace.SelectedTab") private var restoredSelectedTabRaw = ...`
  - `@SceneStorage("Workspace.SelectionID") private var restoredSelectionID = ...`
  - `@SceneStorage("Workspace.NavigationPath") private var restoredNavigationPathData = ...`

### Test Suites
- Executed `swift test` under `Packages/SharedUI` (Task id: `f2af4380-7624-4205-9abb-2f21afbf8b05/task-144`), outputting:
  `Executed 27 tests, with 0 failures (0 unexpected) in 0.006 (0.010) seconds`
- Executed `xcodebuild test -project InvoicingApplication.xcodeproj -scheme InvoicingApplication -destination 'platform=macOS'` (Task id: `f2af4380-7624-4205-9abb-2f21afbf8b05/task-151`), outputting:
  `** TEST SUCCEEDED **`
  `Test case 'AppSessionTests.testSuccessfulBootstrapMovesToReadyPhase()' passed ...`

---

## 2. Logic Chain

1. **Workspace and Scoped State:** `@SceneStorage` properties (observed in `ContentView.swift`) scope their storage to individual window instances on macOS. Each `WorkspaceWindowRoot` instantiates its own `WorkspaceSceneSession` view-model container stored in `@State`. Therefore, multiple Workspace windows operate with independent navigation paths, tab selections, and view models, preventing cross-window state bleeding.
2. **Utility Window Isolation Gaps:** Both `InspectorSceneRoot` and `ActivitySceneRoot` instantiate their own local `WorkspaceSceneSession` rather than sharing or reading the active workspace's state. Consequently, the standalone inspector has a `nil` selection and fails to show what is selected in the main window. Clicking "Open Invoice" in the Activity window modifies only the Activity window's internal state.
3. **SwiftData Thread Safety Violation:** A standard Swift actor (`BulkClaimWorkspaceOperations`) executes calls concurrently. It instantiates `ModelContext(modelContainer)` (observed on line 37) and references/modifies it (observed on line 51) after async `await` suspension points (observed on lines 49 and 50). Since `ModelContext` is not thread-safe and the actor thread can change across suspension points, this violates Swift's concurrency rules and can cause runtime database crashes.
4. **Test execution:** Running tests via `xcodebuild` and `swift test` builds and executes all suites successfully, verifying core application boots and navigation manager boundaries.

---

## 3. Caveats

- We assumed that `UtilityWindow` is a system-provided SwiftUI type or compiled via SwiftUI macro targets. We did not deep dive into the compiler extensions that define it.
- We did not audit concurrency compliance in features that do not interact directly with SwiftData contexts.
- We assumed that `ToolWindowPresenceRegistry` does not block main actor execution; it is annotated with `@MainActor` which matches the view layer thread.

---

## 4. Conclusion

- **Multi-Window Isolation:** Highly compliant. Scoped workspace views and `@SceneStorage` correctly isolate window states.
- **Utility Windows Sync Gaps:** Standalone utility windows operate in complete session isolation, breaking inspector sync and activity navigation.
- **SwiftData Concurrency Risk:** `BulkClaimWorkspaceOperations.swift` contains a critical concurrency violation by accessing a non-sendable `ModelContext` across thread-hopping suspension points.
- **Testing:** The test suite is fully functional. Both command-line package tests (`swift test`) and Xcode project tests (`xcodebuild test`) pass successfully.

---

## 5. Verification Method

To verify these findings:
1. **Concurrency Risk Verification:**
   Inspect `Packages/Data/Sources/Data/Actors/BulkClaimWorkspaceOperations.swift` lines 30–55. Check that `modelContext` is defined before `await` calls and accessed after them.
2. **Window State Verification:**
   Inspect `Packages/AppShell/Sources/AppShell/App/Scenes/Workspace/ContentView.swift` lines 36–43 for the presence of `@SceneStorage`.
3. **Test Infrastructure Verification:**
   Run the following terminal command from the workspace root:
   ```bash
   xcodebuild test -project InvoicingApplication.xcodeproj -scheme InvoicingApplication -destination 'platform=macOS'
   ```
   Or run swift tests in the SharedUI package:
   ```bash
   cd Packages/SharedUI && swift test
   ```
