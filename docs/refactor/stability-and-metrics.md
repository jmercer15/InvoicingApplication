## Stability and Metrics Plan

### 1) Query reactivity verification

- Confirm invoice deep links still resolve even when list content is refreshed by filter/search changes.
- Verify NDIS inspector selection updates without waiting for full reloads by running:
  - Filter by status.
  - Select an item and change query text.
  - Confirm selection remains valid or resolves via fallback fetch within one run loop.
- Confirm `@Query` update flow does not leave stale references after deletion by deleting a selected invoice and validating inspector resets.

### 2) Actor handoff correctness

- Confirm `BillingDraftBuilderService` and background NDIS projection flows execute without touching main-actor-only model instances.
- Ensure every actor boundary receives `PersistentIdentifier`/UUID input and resolves entities in its own context.
- Add lightweight diagnostics around:
  - `BillingDraftBuilderService.buildDraft` success/failure.
  - `NDISContainerViewModel` catalogue projections after filter changes.
  - `TravelChargeAutomationActor` task lifecycle and cancellation.

### 3) Responsiveness checks (manual + sample timings)

- Measure:
  - filter burst latency in `InvoicesContentColumn` (toggle filters quickly for 10+ events).
  - catalogue rebuild latency in NDIS when toggling category/feature filters.
  - startup timeline from `AppSession.bootstrap()` start to first workspace root render.
- Flag and investigate any operation that exceeds existing budget in `docs/refactor/contracts.md`.

#### Suggested lightweight instrumentation points (implemented)

- `com.invoicingapplication.app` (startup): `AppInitialize`, `LoadDatabase`, `BuildWorkspaceServices`, `CreatePersistenceBundle`.
- `com.invoicingapplication.app` (invoice-query): `InvoicesListQuery`.
- `com.invoicingapplication.app` (ndis-projection): `NDISCatalogueProjection`.
- `com.invoicingapplication.app` (billing-draft-builder): `buildDraft`.
- `com.invoicingapplication.app` (travel-charge): `TravelChargeAutomationActor.runAutomation`.

Use Instruments > Points of Interest to verify:

- launch to first workspace root render,
- filter/projection span durations (p95 under your baseline),
- actor-lifecycle durations for automation/building flows.

### 4) Regression command checklist

- Launch app on baseline dataset and run:
  - Open all four window scenes.
  - Navigate invoice list, invoices > filters, invoice inspector.
  - Navigate NDIS catalogue > region switch + feature/quote filters.
  - Open billing hub, run one draft generation action.
- Close and reopen app to confirm warm start behavior and persisted context recovery.

### 5) End-to-end verification runbook (copy this into your notes)

- Before you start, load baseline targets from `docs/refactor/baseline-metrics.md` and open Instruments with the Point of Interest template.
- Run the scenario below twice: once with a small dataset (approx. 100 rows) and once with a larger dataset (approx. 2000+ rows).
- In every scenario, record:
  - App launch-to-first-workspace-frame duration.
  - Invoice filter burst latency for 10 rapid filter mutations.
  - NDIS catalogue rebuild duration for each filter mutation.
  - Draft generation queue latency for one successful billing draft run.
  - Travel charge automation run latency for a representative date window.

#### Runbook

- Step 1: start Instruments trace
  - Capture points of interest from `com.invoicingapplication.app` for one full launch-through-check sequence.
  - Keep tracing only during the steps below to keep traces comparable.
- Step 2: startup baseline
  - Quit the app, then reopen.
  - Verify signposts:
    - `AppInitialize`
    - `LoadDatabase`
    - `BuildWorkspaceServices`
    - `CreatePersistenceBundle`
  - Acceptable if every segment is within 20% of baseline and no segment regresses by >200ms.
- Step 3: query-reactivity check
  - Open invoices list, then quickly:
    - change status filter,
    - change search text,
    - change date window,
    - switch clients.
  - Verify signpost `InvoicesListQuery` is emitted for each mutation and UI update stays within 20% of baseline budget.
  - Open an invoice, then select another while deleting the first to confirm inspector fallback/reselect path does not hold stale data.
- Step 4: actor handoff check
  - Trigger one draft generation in billing hub and capture `buildDraft`.
  - Edit NDIS filters to force a projection recalculation and capture `NDISCatalogueProjection`.
  - Run one travel charge automation batch and capture `TravelChargeAutomationActor.runAutomation`.
  - Ensure no actor-boundary violations appear in logs and cancellation/resubmission paths complete quickly.
- Step 5: stability pass
  - Repeat step 3 with a 10-second burst and observe frame pacing.
  - Validate no long main-thread blocks (>100ms spikes) around the above signposted sections.
  - If any phase regresses beyond budget, capture the trace and add follow-up task for narrow regression investigation.

#### Exit criteria

- All key signposts recorded and attributed to the intended owner.
- No unexpected stale data behavior during deep link, selection, and filtering flows.
- All measured segments meet the corresponding baseline budgets or have documented remediation tickets.

### 6) SwiftUI/SwiftData refactor smoke checklist

Run this checklist at the end of each composition, navigation, environment, or persistence refactor slice.

- Startup and scenes:
  - Cold-launch the app and confirm the workspace leaves the loading state exactly once.
  - Open Workspace, Settings, Inspector, and Activity windows from the app/menu commands.
  - Confirm Settings shows real settings content after bootstrap, not the loading placeholder.
  - Confirm Activity shows CloudKit/sync status and billing hub content from the singleton tool-window session.
- Workspace navigation:
  - Switch through every `AppTab` and verify the expected two-column or three-column layout.
  - Use toolbar back and forward after at least three tab/detail navigations.
  - Deep-link from Billing Hub to an invoice and to a session, then return with toolbar history.
  - Select an invoice, relationship, and NDIS item; confirm the inline inspector updates.
- Search:
  - Confirm there is only one workspace search field in the macOS toolbar.
  - Type search text on invoices, relationships, NDIS catalogue, and Billing Hub; verify the active feature receives the query.
  - Switch to a tab without workspace search and confirm the search field does not apply stale text to an unrelated feature.
- Inspector:
  - Toggle the inline inspector from the workspace.
  - Open the standalone Inspector window and confirm it shows the singleton tool-window inspector state.
  - Clear selection or delete a selected record and confirm inspector content resets instead of holding a stale reference.
- Persistence:
  - Create or edit an invoice/session and confirm the workflow explicitly saves.
  - Run the clear-all-sessions settings action on a disposable dataset and confirm the main context autosave policy remains unchanged.
  - Run one import/export or bulk claim preview flow and confirm save failures, if any, are visible in the UI/logs.
- Hotspot UI flows:
  - For session form changes, create and edit a recurring session with an address.
  - For Billing Hub drag/drop changes, drag a card between each supported lane and grouped/ungrouped area.
  - For NDIS changes, combine search, region, quote, category, and feature filters.
