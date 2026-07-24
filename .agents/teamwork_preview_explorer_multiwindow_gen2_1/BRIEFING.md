# BRIEFING — 2026-06-23T15:25:00+10:00

## Mission
Investigate multi-window scene topology, SwiftData thread safety compliance, and scoped window state in the InvoicingApplication project, locating existing tests and document findings.

## 🔒 My Identity
- Archetype: Explorer
- Roles: Read-only investigator, analyzer
- Working directory: /Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/teamwork_preview_explorer_multiwindow_gen2_1
- Original parent: 9ce654ff-231e-4340-ab03-9018e77b1b53
- Milestone: Multi-window & SwiftData Investigation

## 🔒 Key Constraints
- Read-only investigation — do NOT implement
- CODE_ONLY network mode restriction (no external curl/wget)
- Write analysis.md and handoff.md in working directory
- Communicate via send_message to caller agent

## Current Parent
- Conversation ID: 9ce654ff-231e-4340-ab03-9018e77b1b53
- Updated: not yet

## Investigation State
- **Explored paths**:
  - `InvoicingApplicationApp.swift` (App bootstrap)
  - `Packages/AppShell/Sources/AppShell/App/Scenes/InvoicingApplicationApp.swift` (Scene tree topology)
  - `Packages/AppShell/Sources/AppShell/App/Scenes/Tools/ToolWindowSceneRoots.swift` (Utility window roots)
  - `Packages/AppShell/Sources/AppShell/App/Scenes/Workspace/WorkspaceWindowRoot.swift` (Workspace root)
  - `Packages/AppShell/Sources/AppShell/App/Composition/AppSceneSessions.swift` (WorkspaceSceneSession & WorkspaceSceneNavigationState)
  - `Packages/AppShell/Sources/AppShell/App/Composition/WorkspaceFeatureRegistries.swift` (Feature VM lifecycle management)
  - `Packages/AppShell/Sources/AppShell/App/Composition/ProductionRuntimeAssembly.swift` (ModelContainer bootstrap & shared lifecycle)
  - `Packages/AppShell/Sources/AppShell/App/NativeSettingsRootView.swift` (Settings scene)
  - `Packages/AppShell/Sources/AppShell/App/Scenes/Workspace/ContentView.swift` (Workspace view hierarchy & SceneStorage navigation sync)
  - `Packages/SharedUI/Sources/SharedUI/Helpers/AppNavigationManager.swift` (Per-window navigation state)
  - `Packages/Data/Sources/Data/Actors/BulkClaimWorkspaceOperations.swift` (SwiftData concurrency risk analysis)
- **Key findings**:
  - SwiftUI Scene Tree has 4 main scenes: Workspace (WindowGroup), Settings, Inspector (UtilityWindow), and Activity (UtilityWindow).
  - Main Workspace supports multiple instances with independent window state (tab selections, navigation paths) encapsulated inside window-specific `WorkspaceSceneSession` owned via `@State`.
  - Settings and utility windows are panel-like singletons. Utility windows register presence on appear/disappear via `ToolWindowPresenceRegistry`.
  - ModelContainer is created once via `AppDatabase.bootstrap(...)` during app startup and is shared across all windows using `.modelContainer(runtime.modelContainer)`.
  - SwiftUI views query/mutate on `@MainActor` using the main ModelContext, whereas background tasks use serial `@ModelActor` classes (like `BackfillModelActor`, `TravelChargeAutomationActor`, `InvoiceDigestActor`).
  - Thread safety violation: `BulkClaimWorkspaceOperations` is a standard actor that creates local `ModelContext` instances and modifies SwiftData models across `await` suspension points. This risks data corruption and crashes.
  - UI state (selected tab, selection ID, navigation path) is successfully isolated using window-specific `AppNavigationManager` and SwiftUI `@SceneStorage`.
  - Standalone utility windows (`Inspector`, `Activity`) operate in isolated `WorkspaceSceneSession`s, breaking selection sync and navigation actions with the active workspace window.
  - Test suites are located in app and package targets (e.g., `SharedUITests`, `AppShellTests`, etc.). Tests pass via `swift test` and `xcodebuild`.
- **Unexplored areas**:
  - Deep-dive into other packages' background actors (e.g., `DataImporterActor`, `DataExporterActor`) to verify strict concurrency conformance.

## Key Decisions Made
- Document the findings in `analysis.md` and write a handoff report in `handoff.md`.
- Propose refactoring `BulkClaimWorkspaceOperations` to either a `@ModelActor` or wrapping context changes in contiguous synchronous blocks to resolve SwiftData concurrency violations.
- Propose using `@FocusedValue` or `@FocusedSceneValue` to sync active selection state with standalone utility windows.

## Artifact Index
- /Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/teamwork_preview_explorer_multiwindow_gen2_1/ORIGINAL_REQUEST.md — Original request containing prompt details
- /Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/teamwork_preview_explorer_multiwindow_gen2_1/BRIEFING.md — Persistent context indexing
- /Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/teamwork_preview_explorer_multiwindow_gen2_1/progress.md — Task tracking and heartbeat
