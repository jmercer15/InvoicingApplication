# Project: InvoicingApplication Multi-Window & SwiftData Compliance

## Architecture
- Apple SwiftUI App with SwiftData persistence.
- Main Workspace: WindowGroup supporting multiple independent window instances.
- Settings: Singleton scene.
- Utility Windows: Standalone Inspector and Activity Monitor windows whose visibility is tracked by `ToolWindowPresenceRegistry`.
- SwiftData: Single shared `ModelContainer` accessed thread-safely via `@MainActor`-isolated contexts (UI) and background actors.

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| 1 | Baseline & Investigation | Examine App/AppShell scenes, window state, SwiftData usages, and current test suite. Run baseline tests. | none | DONE |
| 2 | SwiftUI Multi-Window Compliance | Refactor app scene topology (Workspace, Settings, UtilityWindows) to support independent workspace instances and singleton utility windows. | M1 | DONE |
| 3 | SwiftData Thread Safety | Ensure all scenes share a single ModelContainer and all contexts are thread-safe (MainActor or background actors). | M2 | DONE |
| 4 | Scoped Window State | Isolate tab selections, active panel focus, and navigation history using `@SceneStorage` or local states. | M3 | DONE |
| 5 | Testing & Verification | Implement automated tests for multi-window state isolation and thread safety. Run verification gates. | M4 | DONE |
| 6 | Final Verification & Synthesis | Run full test suite, verify no warnings/errors, perform integrity audit, and prepare handoff. | M5 | DONE |

## Interface Contracts
- All windows must share the same `ModelContainer` instance pointing to the same persistent store.
- Window-specific UI states (e.g. selection, tab navigation) must not bleed between separate workspace windows.
- Any background operations or database writes must be isolated to background contexts or ModelActors.

## Code Layout
- `InvoicingApplication/` - Main App target, entry point bootstraps the AppSession and environment.
- `Packages/AppShell/Sources/AppShell/App/Scenes/` - Scene declarations, Workspace window root, Settings, Utility windows.
- `Packages/AppShell/Sources/AppShell/App/Composition/` - App bootstrapper, dependencies, and `ToolWindowPresenceRegistry`.
- `Packages/Data/Sources/Data/Persistence/` - AppDatabase, ModelContainerFactory, model actors.
- `Packages/SharedUI/Sources/SharedUI/Helpers/` - AppNavigationManager, NavigationHistoryStore.
