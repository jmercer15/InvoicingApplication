# Developer Notes

## Composition & Dependency Injection

The app no longer uses a monolithic `AppServices` composition object. Bootstrap is split into two
lifetimes so SwiftUI scene ownership and SwiftData save scope match.

### `AppRuntime` vs `WorkspaceSceneSession`

- **`AppRuntime`** (`InvoicingApplication/App/Composition/AppWorkspaceBootstrap.swift`) is
  app-session scoped. It carries:
  - the shared `ModelContainer` (via `AppDatabase`)
  - app-wide services (`WorkspaceServicesPhase`: geocoding, EventKit, MMM zone lookup,
    recurrence, CloudKit monitor, template manager, export service, etc.)
  - the Settings-scoped `PersistenceBundle` (a manual-save `settingsContext` plus
    `SettingsServices` for import/export/wipe/travel automation)
  - the shared `NDISBillingIntegrationService`
  - `toolWindowSessionHolder: ToolWindowSessionHolder`, which lazily builds one shared
    `WorkspaceSceneSession` for the singleton Inspector and Activity windows using each scene’s
    SwiftUI environment `ModelContext`
- **`WorkspaceSceneSession`** is per workspace window or shared by singleton tool windows. Each
  workspace window’s root (`WorkspaceWindowRoot`) creates its own session once `\.modelContext`
  is available from `.modelContainer(sharedContainer)`. A scene session owns:
  - its own `AppNavigationManager`
  - its own `WorkspaceFeatureRegistries`
    (`InvoicingApplication/App/Composition/WorkspaceFeatureRegistries.swift`), a strangler
    over `WorkspaceFeatureProvider` that lazily builds each feature container VM on first access
  - a per-scene `NDISComplianceValidator` against the shared `ModelContainer`
- Two workspace windows therefore have independent navigation, selection, inspector
  visibility, search text, and cached feature VMs while still sharing one
  `ModelContainer`.

### Scene scopes

- `WindowGroup("Workspace")` → `WorkspaceWindowRoot` → fresh `WorkspaceSceneSession` per
  window.
- `Settings` scene → uses `runtime.settingsContext` and `runtime.settingsServices` (the
  Settings-scoped manual-save context).
- `Window("Inspector")` and `Window("Activity")` → singleton tool windows. They resolve the same
  cached session via `runtime.toolWindowSessionHolder` (first opened window seeds the shared
  `WorkspaceSceneSession`), not the focused workspace window’s provider. The inline `.inspector`
  inside each workspace window remains the per-window inspector.

Bootstrap phases live in `AppWorkspaceBootstrap.swift` (`loadDatabase`,
`makeWorkspaceServices`, `makePersistenceBundle`) to keep startup readable. Feature VMs are
**not** built in bootstrap; they are created by each scene session's
`WorkspaceFeatureRegistries` when a tab or command first touches the corresponding factory
method.

View hierarchies receive dependencies via a mix of:

- explicit view initializers (`WorkspaceFeatureRegistries` and `AppNavigationManager` passed
  into `ContentView` / inspector roots from the scene session)
- SwiftUI environment values for contextual services (e.g. `\.cloudKitSyncMonitor`)
- `\.modelContext` from `.modelContainer` on workspace, inspector, and activity scenes;
  Settings overrides with `runtime.settingsContext`; per-feature columns inherit rather than
  re-injecting
- **`workspaceStandardServicesEnvironment`**
  (`Packages/WorkspaceUI/Sources/WorkspaceUI/WorkspaceStandardServicesInjection.swift`) for shared workspace
  services, including **`\.ndisBillingIntegrationService`** and protocol-typed invoice
  template/PDF hooks: **`\.workspaceTemplateManaging`**, **`\.workspaceTemplateDataServing`**,
  **`\.workspaceInvoicePDFExporting`** (`WorkspaceServiceProtocols` in Core; concrete types
  conform in `Feature_InvoiceTemplateEditor`). The app still passes
  **`\.environment(TemplateManager.self)`** / **`TemplateDataService.self`** where views
  already use `@Environment(TemplateManager.self)`; new code can prefer the protocol keys for
  tests and softer coupling.
- SwiftData persistence ownership is tracked in
  `docs/refactor/swiftdata-persistence-boundaries.md`.

Tab-local SwiftUI navigation stacks (`NavigationPath` + typed routes) live on coordinators in `Packages/SharedUI/Sources/SharedUI/Helpers/WorkspaceTabNavigation.swift`. **`AppNavigationManager.selection`** `didSet` calls **`recordFocused*`** helpers so **`inspectorFallbackSelection()`** reflects list-driven selection without appending routes on every tap; **`syncFromDeepLink`** (used from `navigateTo*` helpers) updates the same fallback fields and pushes onto **`NavigationPath`** when appropriate.

### Scope of each runtime object → consumers

| Object                                                   | Lifetime                                           | Primary consumer                                                                                                                                                                    |
| -------------------------------------------------------- | -------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `AppDatabase` / `ModelContainer`                         | App-session                                        | All scenes                                                                                                                                                                          |
| `WorkspaceServicesPhase`                                 | App-session                                        | `workspaceStandardServicesEnvironment` on workspace, inspector, activity; selected settings services via `settingsServicesEnvironment`                                              |
| `NDISBillingIntegrationService`                          | App-session                                        | `\.ndisBillingIntegrationService` on workspace, inspector, and activity roots; each `WorkspaceSceneSession.features`                                                                |
| `PersistenceBundle.settingsContext` / `SettingsServices` | App-session, Settings-scoped use                   | Settings scene only (`\.modelContext` + `\.settingsServices`)                                                                                                                       |
| `runtime.toolWindowSessionHolder`                        | App-session; caches one shared tool-window session | Inspector and Activity singleton windows (lazy; uses environment `ModelContext`)                                                                                                    |
| `ModelContext` (workspace / tool scenes)                 | Per scene from `.modelContainer`                   | Passed into `WorkspaceSceneSession` / feature providers; not `AppDatabase.makeMainContext()` for those scenes                                                                       |
| `WorkspaceSceneSession.navigationManager`                | Per workspace window                               | `ContentView` / inline `.inspector` via initializer injection                                                                                                                       |
| `WorkspaceSceneSession.features`                         | Per workspace window                               | `ContentView` → feature tabs                                                                                                                                                        |
| `templateManager` / `templateDataService`                | App-session                                        | `.environment` on workspace, inspector, activity roots                                                                                                                              |
| `cloudKitSyncMonitor`                                    | App-session                                        | Activity scene via environment                                                                                                                                                      |
| `sharedExportService` (`ExportService`)                  | App-session                                        | Bootstrap (`WorkspaceServicesPhase.exportService`); **`\.workspaceInvoicePDFExporting`** at scene roots; **`InvoiceSharingService`** / invoices VM via `WorkspaceFeatureRegistries` |

Feature container VMs (`InvoicesContainerViewModel`, `RelationshipsContainerViewModel`, etc.) are factory methods on `WorkspaceFeatureRegistries` (delegating to `WorkspaceFeatureProvider`); access them only from UI or commands that need that feature so startup does not allocate every VM.

### Workspace search (macOS)

- Use **one** `.searchable` on the workspace shell (`AppRootView` / `dynamicSplitView`). Each `.searchable` registers `com.apple.SwiftUI.search` on `NSToolbar`; attaching search to multiple columns (e.g. list + detail) duplicates that identifier and **crashes**. Tab-specific query strings still live on each feature VM; the root binding switches by `selectedTab`.

### Geocoding services

- **`Core.GeocodingService`** (actor, MapKit): `\.geocodingService` — pure address → coordinate.
- **`SwiftDataGeocodingService`**: `\.swiftDataGeocodingService` — persists lat/long on SwiftData entities; **one instance** from app bootstrap, same reference passed into `NDISBillingIntegrationService`. Previews/tests use `WorkspacePreviewServices.makeSwiftDataGeocodingService()` (`WorkspaceUI` / `Packages/WorkspaceUI`).
- **Invoice PDF / template previews & tests** — `InvoiceTemplatePreviewServices` (`Packages/Feature.InvoiceTemplateEditor/.../InvoiceTemplatePreviewServices.swift`): `makeExportService()`, protocol-shaped `makeWorkspaceInvoicePDFExporting()`, and SwiftUI `previewWorkspaceInvoicePDFExporting()` (imports `WorkspaceUI` for `\.workspaceInvoicePDFExporting`; **`SharedUI` stays free of `Data`**).

### Settings services bundle

- **`SettingsServices`** (`Feature_Settings/SettingsDependencies.swift`) intentionally groups settings-only actors (`DataImporterActor`, `DataExporterActor`, `BulkClaimBuilderActor`, `TravelChargeAutomationActor`) and `DataWipeService`. It is injected only after app bootstrap finishes; until then the Settings scene shows a loading placeholder.

### Calendar recurrence

- **`RecurrenceRuleManager`** is created once in `AppWorkspaceBootstrap.makeWorkspaceServices()`, shared by `EventKitSyncService` and `CalendarViewModel`. The same object is also exposed as `\.recurrenceRuleManager` for SwiftUI. Do not construct a second manager for the calendar stack.
- `CalendarViewModel` / `SessionModificationService` are not SwiftUI views, so they receive the manager through feature initializers instead of resolving it from global state.

### Lazy feature VMs

- **`WorkspaceFeatureRegistries`** (and the underlying `WorkspaceFeatureProvider`) cache each container VM after first use for the lifetime of its owning `WorkspaceSceneSession` (same stability as eager construction inside that scene, lower cold-start cost). Optional teardown on tab switch is a product decision if memory becomes an issue.
- The current ownership classification is:
  - **Workspace + inline inspector shared:** invoices, relationships, NDIS catalogue, calendar, template editor, Billing Hub.
  - **Singleton tool windows:** Inspector and Activity share `runtime.toolWindowSessionHolder`, not the focused workspace window's provider.
  - **Settings scoped:** import/export, travel automation, and data wipe services remain in `SettingsServices`, not in `WorkspaceFeatureRegistries`.
- New features should avoid adding another cached workspace VM unless the state genuinely needs to survive tab switches inside one scene session. Prefer feature-root constructor injection for narrow services.

### NDIS compliance validation

- **`NDISComplianceValidator`** is a SwiftData `@ModelActor` on the app’s `ModelContainer`, conforming to `ComplianceValidating`. Validation uses snapshot fetches on the actor’s executor (not the UI `ModelContext`). If invoice transitions feel slow, profile with Instruments before moving more logic.

### Billing Hub Kanban projection

- See the file-level note on `BillingHubProjectionBuilder`: projection isolates lane mapping, sorting, and DnD-stable card payloads.
- Billing Hub read tightening now uses predicate-friendly `statusToken` mirrors on `Session` / `Invoice` (backfilled on bootstrap) so `BillingHubView` can narrow:
  - sessions to dated rows (`startTime != nil`)
  - invoices to lane-relevant statuses (`review_draft`, `ready_to_send`, `pending`, `received`, `overdue`)

## SwiftData & Concurrency

- **Manual-save everywhere:** All app `ModelContext`s keep `autosaveEnabled = false` — workspace/tool scene environments (via `manualSaveModelContext()`), Settings (`AppDatabase.makeMainContext()`), and ephemeral billing/worker contexts (`ModelContainerFactory.makeEphemeralContext(from:)`). Explicit `save()` is the commit API.

- Core boundary DTOs (`*Snapshot` types) live in `Packages/Core/Sources/Core/Models/Snapshots/` (one file per type). **`EntitySnapshots.swift` is deliberately empty** — a stable navigation anchor only (do not add types back there); edit the matching `Snapshots/<TypeName>.swift` when changing a snapshot.

- Prefer query-driven UI (`@Query` / bounded `FetchDescriptor`) over fetch-all + in-memory filtering.
- Example: payee and plan manager detail screens pass `@Query` results into their view models instead of `modelContext.fetch` for the same graphs.

**Aligned recently (query / actor first, VM no longer duplicates the same graph):**

- **Client detail** — Filtered `@Query` by client id; `ClientDetailViewModel.refreshProjectedData(...)` applies snapshots from the view (no bulk list fetches for services/invoices/agreements/catalogues).
- **Company** — `CompanyViewModel.refreshPersistedBusiness(snapshot:)` takes `businessEntities.first` from `@Query` (no duplicate “primary business” fetch in the VM).
- **Claim batches** — Batch detail uses `@Query` for lines + batch; VM APIs take models/snapshots for preflight/export/submitted/exported; wizard export uses `WizardBatchExportCoordinator` with a filtered `@Query` for lines. **`draftId(containingClaimableLineId:)`** remains a **single-row** `ClaimableLine` fallback when reconciliation cannot resolve `draftId` from in-memory relationships.
- **Invoices** — List selection prefers a snapshot from the container VM; **`InvoiceDigestActor`** backs invoice-number generation; **`selectInvoiceForDeepLink(id:)`** is the only path that performs a bounded id fetch when the snapshot misses.
- **Calendar** — `sessionRegistry` merges each projection refresh; **`resolveSessionEntity`** uses registry + `filteredSessions`, then a single-row fetch for deep-linked / off-window ids.
- **Billing Hub** — Lane/card identity and bulk workflow go through **`BillingHubWorkflowActor`**; UI `ModelContext` reads are limited to cases that need relationship traversal on the main context.
- **Billable drafts** — Generate sheet uses nested `BillableDraftsSessionWindowQuery` (`@Query` over the date window); **`BillableDraftsViewModel.applySessionsWithoutDraft`** filters by draft-overlap ids. **`generateDrafts(for: [Session])`** still uses **optional single-row** client/service fetches when relationship faults are missing.

**Remaining VM-scoped `FetchDescriptor` / `fetch` (inventory — next refactors if you want stricter view-only reads):**

| Location                              | Role                                                                                                                                                                                  |
| ------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **`BillingHubViewModel`**             | Bounded **by-id** main-context fetch for `Session` / `Invoice` where the UI context must resolve relationships (e.g. support logs).                                                   |
| **`BillableDraftsViewModel`**         | **Single-row** client / client-service fetch when `Session` relationships are not loaded (`generateDrafts` fault fallback).                                                           |
| **`InvoicesContainerViewModel`**      | **`selectInvoiceForDeepLink(id:)`** — bounded fetch when the list snapshot does not contain the id (Billing Hub / inspector). List selection uses **`selectInvoice(_:)`** (no fetch). |
| **`RelationshipsContainerViewModel`** | _(aligned)_ Deletes take the same `@Query`-materialized `Client` / `Payee` / `PlanManager` passed from the detail column (no delete-by-id fetch).                                     |
| **`TravelChargeViewModel`**           | _(aligned)_ **`applyTravelChargeQuerySnapshot`** consumes view `@Query` rows; VM holds no `ClientService` / `TravelCharge` list fetches.                                              |
| **`CalendarViewModel`**               | **`resolveSessionEntity`**: registry + working set first, then bounded **single-row** fetch for off-window ids (e.g. Billing Hub → Calendar).                                         |
| **`ClaimBatchesViewModel`**           | **`draftId(containingClaimableLineId:)`** only — one-row lookup (see above).                                                                                                          |

**Non-view / service code:** **`SessionModificationService`** and similar types appropriately use **`FetchDescriptor`** for service-backed reads outside `@Query`; that is separate from view-bound `@Query` rules.

- Avoid passing SwiftData `@Model` instances across concurrency boundaries.
  - Use `UUID` or `PersistentIdentifier` for handoff to actors.
  - Re-fetch inside the actor’s isolated `ModelContext`.

## Periphery (unused code)

- Repo root `.periphery.yml` sets **`retain_public: true`** because SPM modules expose public APIs consumed only by the app target; without it, those symbols look unused. Optional stricter pass: flip to `false` on a branch and add explicit `retain:` entries (or `// periphery:ignore`) for real false positives.

## Build/Debug hygiene

- After deleting SwiftPM sources, if you see “missing inputs” errors, run:
  - `swift package clean`
  - then rebuild the package.

## Export & sensitive file threat model

- **Settings JSON / CSV exports** — User picks the destination via the system save panel. Exports are **plaintext** JSON or CSV containing client PII, NDIS catalogue rows, invoice totals, and claim-line identifiers. The Import/Export UI shows a standing sensitivity notice, requires explicit consent before PII-heavy exports, and offers an optional **Omit bank & NDIS IDs** redaction preset (`ExportRedactionPreset.omitBankAndNDISIdentifiers`) for generic backups. Operators must still store files on encrypted volumes and limit sharing; redaction is not encryption.
- **Accepted residual risk (exports)** — Full exports remain plaintext by design (local-first backup/transfer). Field redaction omits bank and participant NDIS identifiers only; names, emails, addresses, and support-item codes may remain. Claim CSV exports always include participant identifiers required for NDIA submission.
- **Invoice PDF temp files — lifecycle**
  - **Creation:** `InvoicePDFRenderer.temporaryPDF` renders to `NSTemporaryDirectory()/com.invoicing.invoice-pdf/<uuid>/` via `InvoiceTemporaryPDFWorkspace.makeDirectory()` with `0700` directory / `0600` file permissions and `isExcludedFromBackup`.
  - **Ownership:** `InvoiceTemporaryPDF` holds the workspace URL; callers must invoke `discard()` (or hold a type that does so in `deinit`).
  - **Success paths:** Mail share (`BillingHubMailComposer.finish` / `deinit`), bulk PDF workflows (`defer { pdf.discard() }` in Invoices/Billing Hub), editor preview flows, and integration tests.
  - **Error paths:** If `PDFDocument.write(to:)` fails, `InvoicePDFRenderer` removes the workspace directory before rethrowing. Attribute application failures propagate without leaving an orphaned workspace when write never succeeded.
  - **Retention:** Temp PDFs are not retained across app relaunch; macOS may purge `NSTemporaryDirectory()` independently. User-chosen Save Panel / export paths are operator-controlled plaintext (same trust model as Mail attachments).
  - **Secure delete:** `InvoiceTemporaryPDFWorkspace.securelyDeleteWorkspace` zero-fills before unlink (SEC-4); `InvoiceTemporaryPDF.discard()` on all success/error paths.
- **Keychain scaffold** — `KeychainStoring` + `KeychainStore` in Core provide generic-password storage (`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`, add-or-update). No production call sites yet; adopt when persisting API keys or mail tokens outside SwiftData.
- **FormatStyle** — UI currency, date, and measurement labels use `CurrencyFormatting`, `DateFormatting`, and `MeasurementFormatting` in SharedUI. Fixed-pattern export filenames use `MachineFormatting`. Reserve C-style `String(format:)` for machine tokens (claim codes, checksums, coordinate literals, CSV quantity columns).

## Phase 8 — App Intents + remaining P3 (audit program)

### App Intents (minimal surface)

- **`OpenWorkspaceTabIntent`** and **`OpenClientIntent`** live in `Packages/AppShell/Sources/AppShell/App/Intents/` with **`InvoicingAppShortcuts`** (`AppShortcutsProvider`).
- **`AppIntentModelAccess`** holds the shared `ModelContainer` (Sendable). Registered in `AppIntentBootstrap.registerSharedDependencies()` from `InvoicingApplicationApp.init()` so headless Shortcuts launches see dependencies. **`AppSession.bootstrap()`** calls `AppIntentBootstrap.adoptModelContainer(_:)` when runtime is ready.
- Intents enqueue navigation on **`WorkspaceIntentDeliveryCenter`**; **`WorkspaceWindowRoot`** consumes pending navigation via `AppNavigationManager`. No `ModelContext` in intent `perform()`.
- Shortcuts phrases include `\(.applicationName)` per App Intents requirements.

### P3 backlog disposition

| Item | Status | Notes |
| ---- | ------ | ----- |
| MigrationOrchestrator store-scoped cache | **Done** | Applied-migration cache keyed by migration-history file path (store-scoped). |
| SupportLog fetch batching / `sessionId` | **Done** | Denormalized `SupportLog.sessionId`, migration `backfill_supportlog_session_id_v1`, `BulkClaimBuilderActor` fetches by session id set. |
| BillableDraft plan-type denormalize | **Done** | `BackfillBillableDraftPlanType_v1` migration; clientId-scoped `@Query` + in-memory plan filter at current volume |
| Predicate optional-date cleanup | **Done** | `BillableDraftSessionPickerList` uses optional binding in `#Predicate` (no `startTime!`). |
| `foregroundColor` → `foregroundStyle` (high-traffic) | **Done** | AppShell sidebar/sync indicator, Billing Hub shell status rows, startup loading. Remaining feature files deferred (cosmetic; no behavior change). |
| SessionPhaseRoot Dynamic Type | **Done** | Startup icon uses `@ScaledMetric(relativeTo: .largeTitle)`. |
| UserDefaults Sendable cleanup | **Done** | Removed unused `UserDefaultsObservationHandle`. `observedValue` is `@MainActor`; KVO observer uses `nonisolated(unsafe)` for teardown only. `UserDefaultsKeyObserver` keeps `@unchecked Sendable` at KVO boundary. |

### Audit closeout (Phase 7 — zero waive)

All A0–A8 findings closed as **fix** with build/test evidence. See [audit-closeout-evidence.md](./docs/audit-closeout-evidence.md) — waiver register empty; 154/154 fix; 725 SPM tests PASS (2026-07-29).
