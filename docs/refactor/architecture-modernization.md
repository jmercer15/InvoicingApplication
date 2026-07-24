# Architecture Modernization

This note records the target architecture for the package-first refactor. It is
the operating contract for future package boundary, scene, dependency, and
persistence work.

## Package Responsibilities

### `InvoicingApplication`

- Owns the product app target and the thin `@main` entry point.
- Delegates SwiftUI scene topology to `InvoicingApplicationSceneTree`.
- Performs only app-wide process setup before handing runtime assembly to
  `AppShell`.

### `Packages/AppShell`

- Owns app scene topology, session lifecycle, workspace window roots, command
  routing, search binding, inspector fallback, and feature registration.
- Assembles runtime dependencies through `AppRuntime`, `AppSession`,
  `AppDependencies`, `WorkspaceDependencies`, and `SettingsDependencies`.
- Imports all feature packages and composes them through feature-owned public
  workspace factories.
- Must not own feature business logic, feature-specific persistence decisions,
  or feature presentation state beyond routing and workspace chrome.

### `Packages/Core`

- Owns domain types, protocols, value snapshots, routing values, and shared
  domain rules.
- Remains schema-safe: persisted model ownership, property names, relationships,
  and wire shapes must not change without a migration and matching tests.

### `Packages/Data`

- Owns database bootstrap, `ModelContainer` policy, SwiftData lifecycle,
  repositories, actors, import/export, sync, CloudKit policy, billing services,
  and long-running persistence workflows.
- Creates background contexts through app/data-owned boundaries only.
- Owns migrated-store and in-memory persistence coverage for schema or store
  behavior changes.

### `Packages/SharedUI` and `Packages/WorkspaceUI`

- Own reusable controls, workspace chrome primitives, navigation environment
  helpers, and broad service injection helpers.
- Must not import feature packages or become a cross-feature business logic
  layer.

### `Packages/Feature.*`

- Own feature view models, presentation state, navigation columns, sheets,
  popovers, toolbars, filters, detail sections, and user-facing persistence
  commands.
- Expose minimal public workspace entrypoints only when `AppShell` must compose
  the feature.
- Avoid feature-to-feature imports except the intentional
  `Feature.Invoices -> Feature.InvoiceTemplateEditor` integration.

## Scene Ownership

`InvoicingApplicationSceneTree(session:)` is the public app-facing scene entry.
It hosts explicit roots for startup, workspace windows, settings, and tool
windows. Scene roots own scene-local state and inject broad context at subtree
boundaries. `ContentView` and workspace split views remain orchestration layers:
they select tabs, bind search, expose commands, and route to feature-owned
columns/details.

Primary movement is selection-driven through `AppNavigationManager` and
`WorkspaceRoutingIntent`. Temporary flows remain feature-owned presentation
state. When a feature has multiple related sheets/popovers, prefer a typed
presentation enum over parallel booleans.

## Dependency Flow

Production assembly flows in one direction:

1. `InvoicingApplication` creates an `AppSession`.
2. `AppSession` boots an `AppRuntime`.
3. `AppRuntime` exposes `AppDependencies`, scene sessions, and feature
   registries.
4. Workspace roots derive `WorkspaceDependencies` from the runtime and scene
   session.
5. Feature wrappers call public feature workspace factories with explicit
   inputs.

Use SwiftUI environment values for broad scene context such as app dependencies,
workspace services, model context, navigation, and command actions. Pass
feature-local inputs through initializers and bindings.

## Persistence Boundaries

`ModelContainer` creation is centralized in app/data composition, tests, and
Data-owned actors/services. Feature roots may use the scene `ModelContext` for
live reads, selection reconciliation, and single-screen commands. Multi-model
mutations, imports/exports, sync, billing generation, migrations, and background
work belong in Data services or actors.

Do not create ad hoc `ModelContainer` or `ModelContext` instances in leaf UI.
Do not move `@Model` types across modules, rename persisted properties, change
relationships, or add uniqueness/index behavior without a migration and tests.

## Build and Test Matrix

Run the narrow package gate after each subsystem edit, then run AppShell after
feature-boundary changes.

| Scope | Command |
| --- | --- |
| Core domain/protocols | `swift test --package-path Packages/Core` |
| Data/persistence/services | `swift test --package-path Packages/Data` |
| Shared UI primitives | `swift test --package-path Packages/SharedUI` |
| Workspace UI helpers | `swift build --package-path Packages/WorkspaceUI` |
| Calendar feature | `swift build --package-path Packages/Feature.Calendar` |
| Billing Hub feature | `swift build --package-path Packages/Feature.BillingHub` |
| Clients feature | `swift build --package-path Packages/Feature.Clients` |
| NDIS feature | `swift build --package-path Packages/Feature.NDIS` |
| Invoices feature | `swift build --package-path Packages/Feature.Invoices` |
| Invoice template editor | `swift build --package-path Packages/Feature.InvoiceTemplateEditor` |
| Settings feature | `swift build --package-path Packages/Feature.Settings` |
| AppShell composition | `swift test --package-path Packages/AppShell` |
| Xcode app target | `xcodebuild -project InvoicingApplication.xcodeproj -scheme InvoicingApplication build` |

Acceptance for a modernization stage is package build success, relevant tests
passing where present, no new SwiftData migration warnings, and preserved
navigation/search/inspector/settings behavior.
