# SwiftUI Multi-Window & SwiftData Thread Safety Investigation

## Executive Summary
This report analyzes the InvoicingApplication codebase to verify compliance with SwiftUI multi-window patterns, SwiftData thread safety guidelines, scoped scene-state isolation, and test infrastructure.

---

## 1. SwiftUI Scene Topology

### Scene Declarations & Instantiation Logic
The application's scene structure is declared in `Packages/AppShell/Sources/AppShell/App/Scenes/InvoicingApplicationApp.swift` (wrapped by `InvoicingApplicationSceneTree` struct, which is instantiated in the main app `InvoicingApplicationApp.swift`):

1. **Workspace Window**: 
   - **Declaration**: `WindowGroup("Workspace", id: AppSceneID.workspace.rawValue)` (lines 28–55)
   - **Content**: `SessionPhaseRoot` wrapping `WorkspaceWindowRoot` in ready state.
   - **Modifiers**: macOS-specific expansion modifiers (`.windowStyle(.hiddenTitleBar)`, `.windowToolbarStyle(.expanded)`) and app-level command sets.
2. **Settings Window**:
   - **Declaration**: `Settings` (lines 57–72)
   - **Content**: `SessionPhaseRoot` wrapping `SettingsSceneRoot`.
3. **Utility Window - Inspector**:
   - **Declaration**: `UtilityWindow("Inspector", id: AppSceneID.inspector.rawValue)` (lines 74–93)
   - **Content**: `SessionPhaseRoot` wrapping `InspectorSceneRoot`.
   - **Modifiers**: `.commandsRemoved()`, `.defaultLaunchBehavior(.suppressed)`, and `.restorationBehavior(.disabled)`.
4. **Utility Window - Activity Monitor**:
   - **Declaration**: `UtilityWindow("Activity", id: AppSceneID.activity.rawValue)` (lines 94–113)
   - **Content**: `SessionPhaseRoot` wrapping `ActivitySceneRoot`.
   - **Modifiers**: Same as the Inspector utility window.

Each window scene executes `session.bootstrap()` inside `SessionPhaseRoot` in `.task` asynchronously on launch, which resolves the production runtime (`AppRuntime`).

### Presence Tracking via ToolWindowPresenceRegistry
`ToolWindowPresenceRegistry` (declared in `Packages/AppShell/Sources/AppShell/App/Composition/ToolWindowPresenceRegistry.swift`) is a `@Observable @MainActor` class. It is instantiated at the app root level (`@State private var toolWindowPresence` in `InvoicingApplicationApp`) and injected into all scenes via the environment (`.environment(toolWindowPresence)`).

- **Inspector registration**: Inside `InspectorSceneRoot` (`ToolWindowSceneRoots.swift` lines 28–35), `onAppear` sets `toolWindowPresence.setInspectorStandaloneOpen(true)` and `onDisappear` sets it to `false`.
- **Activity registration**: Inside `ActivitySceneRoot` (`ToolWindowSceneRoots.swift` lines 79–86), `onAppear` sets `toolWindowPresence.setActivityMonitorOpen(true)` and `onDisappear` sets it to `false`.

### Prevention of Double Presentation
In `Packages/AppShell/Sources/AppShell/App/Scenes/Workspace/ContentView.swift`, the inline split inspector view is presented via `.inspector(isPresented: workspaceInspectorPresentation)`.
The computed binding `workspaceInspectorPresentation` (lines 180–191) utilizes:
```swift
    private var workspaceInspectorPresentation: Binding<Bool> {
        Binding(
            get: {
                inspectorPresentation.splitPresented && !inspectorPresentation.standaloneOpen
            },
            set: { newValue in
                if nav.inspectorIsPresented != newValue {
                    nav.inspectorIsPresented = newValue
                }
            }
        )
    }
```
This getter suppresses the inline split inspector column (`!inspectorPresentation.standaloneOpen`) when the standalone inspector utility window is open (`toolWindowPresence.inspectorStandaloneOpen == true`), successfully preventing duplicate inspector presentation across windows.

---

## 2. SwiftData Thread Safety

### ModelContainer Instantiation & Sharing
- **Instantiation**: The `ModelContainer` is instantiated asynchronously during app bootstrap. `ProductionRuntimeAssembly.makeAppRuntime` spawns `loadDatabase()` on a detached task (`Task.detached(priority: .userInitiated)`). This task executes `AppDatabase.bootstrap(policy: .productionSyncRequired)` which delegates container setup to `ModelContainerFactory.makePersistentContainer()` or `makeInMemoryContainer()`.
- **Sharing**: The container instance is stored on the `database.container` property of the shared `AppRuntime` struct inside `AppSession`. This single shared container is attached to each window group root using `.modelContainer(runtime.modelContainer)`.

### ModelContext Access (MainActor UI vs Background Actors)
- **MainActor UI Contexts**: 
  - Standard views resolve the container's default main-actor context via `@Environment(\.modelContext)`.
  - The Settings window uses a manually created MainActor context (`AppRuntime.Persistence.settingsContext`) which has `autosaveEnabled = false` for transaction safety.
- **Background Actors (ModelActors)**:
  - Heavily computational or background persistence operations are offloaded to specialized `ModelActor` actors to ensure strict concurrency isolation and avoid blocking the main thread.
  - The database layer (`AppDatabase.swift`) defines dedicated creation methods:
    1. `DataImporterActor`: Heavy background imports.
    2. `DataExporterActor`: Background data exports.
    3. `BulkClaimBuilderActor`: Computes and generates bulk NDIS claims.
    4. `TravelChargeAutomationActor`: Evaluates and automates travel charge additions.
    5. `InvoiceDigestActor`: Background invoice status digests.
    6. `BackfillModelActor`: Pages (limit of 1,000 per save) and backfills status tokens upon startup.
  - Each actor conforms to `ModelActor` (using `DefaultSerialModelExecutor` and local `ModelContext` with `autosaveEnabled = false`), verifying complete Swift 6 strict concurrency safety.

---

## 3. Scoped Window State

### Navigation & Tab Isolation
State bleeding is prevented by design in the app architecture:
- Each instance of a Workspace window (declared under `WindowGroup`) instantiates `WorkspaceWindowRoot`, which hosts a local `@State private var sceneSession: WorkspaceSceneSession?`.
- `WorkspaceSceneSession` creates independent instances of `WorkspaceSceneNavigationState` (containing a fresh `AppNavigationManager`) and `WorkspaceFeatureRegistries` (containing window-scoped view models like `CalendarViewModel` and `InvoicesContainerViewModel`).
- As a result, the tab selection (`selectedTab`), active selection (`selection`), navigation history stack, and inspector toggles are unique to each individual window instance and do not bleed.

### State Persistence via SceneStorage
In `ContentView.swift`, individual window states are stored and restored across sessions using SwiftUI's `@SceneStorage` property wrapper:
- `@SceneStorage("Workspace.SelectedTab")`
- `@SceneStorage("Workspace.ColumnVisibility")`
- `@SceneStorage("Workspace.PreferredCompactColumn")`
- `@SceneStorage("Workspace.SelectionKind")` and `@SceneStorage("Workspace.SelectionID")`
- `@SceneStorage("Workspace.NavigationContext")` and `@SceneStorage("Workspace.NavigationPath")`
- `@SceneStorage("Workspace.InspectorPresented")`

### Architectural Proposal & Refinements
1. **View-Local States for Editing**: All editing sheets, modal presentation states, and temporary filters must remain local (`@State`) or bound to `@SceneStorage` to prevent window crossover.
2. **App-Wide vs. Window-Scoped Settings**: App-wide configurations (e.g., tax rate, billing rates) are stored globally via `@AppStorage` (which writes to `UserDefaults.standard`) inside settings views like `InvoiceSettingsView` and `NDISBillingSettingsView`. This is compliant and correct since settings modifications must apply globally.
3. **Restoration Sanitation**: The code already includes a sanitization step (`scheduleRestoredNavigationSanitization`) that validates restored UUIDs asynchronously off the launch path, protecting the app from crashes if an entity was deleted or changed from another window.

---

## 4. Test Infrastructure & Execution

### Test Locations
Test targets are distributed across the packages and the main app:
- **Main App tests**: `InvoicingApplicationTests/AppSessionTests.swift`
- **AppShell tests**: `Packages/AppShell/Tests/AppShellTests/` (contains scene composition, history restoration, and inspector visibility tests)
- **Core tests**: `Packages/Core/Tests/CoreTests/`
- **Data tests**: `Packages/Data/Tests/DataTests/` (divided into `UseCases`, `Services`, `BusinessLogic`, and `Validation`)
- **Feature package tests**: Under each package `Packages/Feature.*/Tests/`

### Test Commands
1. **Running Main App Tests (xcodebuild)**:
   ```bash
   xcodebuild test -project InvoicingApplication.xcodeproj -scheme InvoicingApplication -destination 'platform=macOS'
   ```
2. **Running Individual Package Tests (swift test)**:
   Change directory to the package root and run:
   ```bash
   swift test
   ```
   Example:
   ```bash
   cd Packages/AppShell
   swift test
   ```
