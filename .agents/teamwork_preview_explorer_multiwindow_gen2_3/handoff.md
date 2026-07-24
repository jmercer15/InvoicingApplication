# Handoff Report

## 1. Observation
We observed the following definitions, paths, and patterns in the codebase:
- **Scene Declarations:** In `Packages/AppShell/Sources/AppShell/App/Scenes/InvoicingApplicationApp.swift`, we found:
  - Line 28: `WindowGroup("Workspace", id: AppSceneID.workspace.rawValue) {`
  - Line 57: `Settings {`
  - Line 74: `UtilityWindow("Inspector", id: AppSceneID.inspector.rawValue) {`
  - Line 94: `UtilityWindow("Activity", id: AppSceneID.activity.rawValue) {`
- **Tool Window Tracking:** In `Packages/AppShell/Sources/AppShell/App/Scenes/Tools/ToolWindowSceneRoots.swift`, we found:
  - Lines 30 & 34: `toolWindowPresence.setInspectorStandaloneOpen(true)` / `toolWindowPresence.setInspectorStandaloneOpen(false)` inside `onAppear` / `onDisappear` for `InspectorSceneRoot`.
  - Lines 81 & 85: `toolWindowPresence.setActivityMonitorOpen(true)` / `toolWindowPresence.setActivityMonitorOpen(false)` inside `onAppear` / `onDisappear` for `ActivitySceneRoot`.
- **ModelContainer Initialization:** In `Packages/AppShell/Sources/AppShell/App/Composition/ProductionRuntimeAssembly.swift`, we found:
  - Line 67: `private static func loadDatabase() async throws -> DatabasePhase {` which launches a detached background task executing `AppDatabase.bootstrap(...)`.
- **SwiftData Concurrency Vulnerability:** In `Packages/Data/Sources/Data/Actors/BulkClaimWorkspaceOperations.swift`, we found a standard actor containing the method:
  - Lines 30–55:
    ```swift
    func createClaimBatch(...) async throws -> (batchId: UUID, summary: BulkClaimValidationSummary) {
        let modelContext = ModelContext(modelContainer)
        let batch = BulkClaimBatch(id: UUID())
        ...
        modelContext.insert(batch)
        try modelContext.save()

        let builtLines = try await bulkClaimBuilderActor.buildLines(batchID: batch.id)
        let validation = await BulkClaimValidationService().validateAndSummarize(lines: builtLines)
        try applyValidationLines(validation.lines, to: batch, in: modelContext)
        try modelContext.save()
        ...
    }
    ```
- **UI State Scoping & Gaps:** In `Packages/AppShell/Sources/AppShell/App/Scenes/Workspace/WorkspaceWindowRoot.swift`, line 14: `@State private var sceneSession: WorkspaceSceneSession?` instantiates a new session per-window. In `Packages/AppShell/Sources/AppShell/App/Scenes/Tools/ToolWindowSceneRoots.swift`, line 11: `@State private var sceneSession: WorkspaceSceneSession?` creates an independent, isolated session for the standalone utility inspector window.
- **Verification Commands:** Run `swift test --package-path Packages/AppShell` to verify AppShell tests. All 13 tests passed cleanly. We also ran `xcodebuild -project InvoicingApplication.xcodeproj -scheme InvoicingApplication -sdk macosx test`, which failed due to a flaky test: `AppSessionTests.testDuplicateBootstrapWhileInFlightDoesNotInvokeBootstrapperTwice()`.

## 2. Logic Chain
- **Scene & Visibility Logic:** The scene tree utilizes SwiftUI's native `WindowGroup` for document workspaces and `Settings` for preferences, while declaring custom `UtilityWindow` scenes for panels. The panels use lifecycle closures to record their presence in `ToolWindowPresenceRegistry`.
- **Shared ModelContainer:** The model container is instantiated during a detached startup thread and held on the app-wide `AppRuntime` struct inside `AppSession`. The application propagates this container using `.modelContainer(runtime.modelContainer)` on all scenes. Therefore, the database is shared across all windows, ensuring unified persistence.
- **Concurrency Defect:** `ModelContext` and managed `PersistentModel` instances are thread-confined in SwiftData. In `BulkClaimWorkspaceOperations`, `modelContext` and `batch` are created, suspended over `await` calls, and subsequently accessed/modified. Because `BulkClaimWorkspaceOperations` is a standard `actor` rather than a `@ModelActor`, thread hops across cooperative boundaries will occur, violating SwiftData thread confinement and causing data races or crashes.
- **State Isolation & Sync Gaps:** Scoped UI state is correctly isolated per-window since each window group creates a separate `@State` view-lifecycle-bound `WorkspaceSceneSession`. However, the utility inspector and activity windows also instantiate their own isolated `WorkspaceSceneSession` rather than tracking the focused window. This causes a sync gap: selection changes do not propagate to the inspector, and activity navigation commands target the local, inactive session.
- **Test Flakiness:** The test `testDuplicateBootstrapWhileInFlightDoesNotInvokeBootstrapperTwice()` uses `Task.yield()` to wait for the bootstrapper's async execution. In loaded environments like `xcodebuild`, the cooperative scheduler can execute concurrently or in a different order, leading to double-init calls.

## 3. Caveats
- We did not modify any source code files as we have read-only permissions.
- We assumed `@FocusedValue` propagation is the desired mechanism to resolve utility window session state sharing.

## 4. Conclusion
1. **Scene Topology:** SwiftUI scenes are cleanly separated into Workspace, Settings, and Utility helper windows.
2. **SwiftData Thread Safety:** The shared container is safe, but `BulkClaimWorkspaceOperations` is unsafe due to model context use across thread suspension boundaries. It must be refactored into a `@ModelActor` or restrict context interactions to synchronous boundaries.
3. **State Isolation:** Per-window UI state is successfully isolated, but standalone panels are disconnected. Utilizing `@FocusedValue` to share `WorkspaceSceneSession` with the utility windows will resolve this.
4. **Testing:** Package tests compile and execute cleanly under `swift test`. The app-level `AppSessionTests` suite contains a flaky timing-dependent test `testDuplicateBootstrapWhileInFlightDoesNotInvokeBootstrapperTwice()` that fails under `xcodebuild`.

## 5. Verification Method
- **Command:** Run `swift test --package-path Packages/AppShell` to verify navigation, command, and registry logic.
- **Command:** Run `xcodebuild -project InvoicingApplication.xcodeproj -scheme InvoicingApplication -sdk macosx test` to run the full application-level test suite (with expected flakiness in `AppSessionTests`).
- **Validation:** Inspect `Packages/Data/Sources/Data/Actors/BulkClaimWorkspaceOperations.swift` to verify the presence of the `ModelContext` thread safety vulnerability.

