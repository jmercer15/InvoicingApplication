# InvoicingApplication — Read-Only Audit

Code-backed review only (no Instruments traces). Hotspots scanned per your list. `.build/` / `BuildData` ignored.

---

## 1. swift-concurrency-pro

**SkillCoverage: ~72%**

Reviewed against: hotspots, actors, structured/unstructured concurrency, cancellation, bug-patterns, bridging, async-streams (minimal usage found), interop/GCD.

### Strengths

- **Model actors at persistence boundaries** — `EventKitSyncActor`, `BillingHubWorkflowActor`, `InvoiceModelActor` keep SwiftData off UI paths.
- **Structured outbound EventKit saves** — `saveDetachedEventsConcurrently` uses `withThrowingTaskGroup` with concurrency cap (3).
- **Cooperative cancellation in bulk fetch** — segment loop calls `Task.checkCancellation()` in `EventKitSyncService+Fetch.swift`.
- **Generation-token refresh** — `BillingHubViewModel.refreshProjection()` and `CalendarViewModel.updateDisplayableItems()` cancel stale tasks and filter `CancellationError`.
- **MapKit actor hop** — `MapKitTravelService` actor wraps `@MainActor` MapKit APIs so callers stay off main actor.
- **AppSession bootstrap** — clean `@MainActor` async `bootstrap()` with reentrancy guard (`isBootstrapping`).
- **Legitimate `@unchecked Sendable`** — `AppIntentModelAccess` uses `NSLock` around container storage.

### Findings

#### P0

| ID | Location | Rule | Why | Fix |
|----|----------|------|-----|-----|
| C-P0-1 | `EventKitSyncService+Push.swift:311–335` | Unstructured GCD + no cancellation (`interop.md`, `cancellation.md`) | `delete(syncIdentifier:)` uses `DispatchQueue.global().async` with nested `Task { @MainActor }`. No `withTaskCancellationHandler`, no stored task handle. Sync disable / service teardown cannot stop in-flight delete. | Mirror `saveDetachedEvent`: `Task.detached` + `checkCancellation`, hop to `@MainActor` for error state, store/cancel task handle like `activeOutboundSyncTask`. |
| C-P0-2 | `CalendarViewModel+Fetching.swift:148–317` | Main-actor blocking (`bug-patterns.md`) | Comment says avoid blocking main thread, but entire pipeline runs in `Task { @MainActor }`: recurrence expansion, multi-day split, sort, `groupItemsByDay()`, `updateAllDayLayout()`. Large week + recurring series can freeze UI. | Split: background actor/task produces `DisplayItemsSnapshot` (Sendable); `@MainActor` VM assigns caches only. |

#### P1

| ID | Location | Rule | Why | Fix |
|----|----------|------|-----|-----|
| C-P1-1 | `EventKitSyncActor.swift:258–271` | Actor reentrancy (`actors.md`, `bug-patterns.md`) | `parsedLocation` checks cache, `await`s geocode, then writes cache. Concurrent callers for same coordinate can duplicate geocode. | Capture in-flight geocode tasks per cache key (pattern in `actors.md`). |
| C-P1-2 | `TravelChargeFormState.swift:350–377` | Legacy callback API (`interop.md`, `cancellation.md`) | Uses `MKDirections.calculate` completion handler + unstructured `Task { @MainActor }`. No Swift cancellation bridge; overlapping requests possible. | Route through `MapKitTravelService` async API; cancel prior calculation task on new input. |
| C-P1-3 | `BillingHubAddTravelPanel.swift:147–154` | Unstructured `Task {}` in reactive handlers (`unstructured.md`) | Eight `onChange` handlers each spawn fire-and-forget `Task { await refreshBreakdown() }`. Rapid edits stack concurrent breakdown work. | Single debounced `.task(id: breakdownInputs)` or coalesced task with cancel/replace. |
| C-P1-4 | `BillingHubViewModel+Sessions.swift:220–221,255` | Swallowed errors in unstructured tasks (`bug-patterns.md`) | `Task { _ = await moveSession(...) }` discards result; user gets no feedback on failure. | `Task { let r = await moveSession(...); if r == nil { ... } }` or surface via `bulkActionFeedback`. |
| C-P1-5 | `MapKitTravelService.swift:57–94` | Main-actor MapKit saturation | Every travel calc hops to main actor for `MKDirections.calculate()`. Bulk travel (Billing Hub day sessions) serializes on main actor. | Batch/limit concurrent `@MainActor` requests; consider `@concurrent` wrapper for non-UI MapKit where API allows. |

#### P2

| ID | Location | Rule | Why | Fix |
|----|----------|------|-----|-----|
| C-P2-1 | `EventKitSyncService+Push.swift:24–26` | `Task.detached` usage (`unstructured.md`) | `saveDetachedEvent` uses detached task (justified for EKEventStore thread confinement) but sheds priority/isolation without explicit comment at call sites. | Document intent; ensure all callers propagate cancellation (already has `checkCancellation`). |
| C-P2-2 | `EventKitSyncService+Access.swift:88–101` | Redundant `MainActor.run` (`hotspots.md`) | `fetchAvailableCalendars()` already on `@MainActor` class; inner `await MainActor.run { }` is no-op overhead. | Assign `availableCalendars` directly. |
| C-P2-3 | `CalendarViewModel.swift:391–408` | Unstored unstructured task (`cancellation.md`) | `executeRecurringModification` spawns bare `Task` with no handle; VM deinit won't cancel mid-modification. | Store `recurringModificationTask`, cancel in `deinit`, filter `CancellationError`. |
| C-P2-4 | `BillingHubViewModel.swift:186–194` | Sequential actor hops (`structured.md`) | `sessionReferences` loops `await sessionModelID` per ID — N round-trips. | `withTaskGroup` or batch API on `BillingHubWorkflowActor`. |
| C-P2-5 | `InvoiceEditorViewModel+SaveLifecycle.swift:205–214` | Polling via continuation (`bridging.md`) | `waitForActiveOperationBeforeWorkspaceExit` uses `withCheckedContinuation` + `asyncAfter` polling; ignores cooperative cancellation by design. | Acceptable for teardown; add timeout cap to avoid infinite wait if save hangs. |
| C-P2-6 | `EventKitSyncService.swift:213–224` | Recursive observation task | `observeSyncEnabledPreference` re-registers via nested `Task { @MainActor }` on every change — works but fragile under rapid toggles. | Single long-lived observation task or Combine pipeline. |

#### P3

| ID | Location | Rule | Why | Fix |
|----|----------|------|-----|-----|
| C-P3-1 | `ProductionRuntimeAssembly.swift:68–71` | `Task.detached` (`unstructured.md`) | DB bootstrap detached — documented, appropriate. | No change. |
| C-P3-2 | `DayColumnView.swift:249–302` | GCD in drag handlers (`interop.md`) | `DispatchQueue.main.async` in drop delegates — framework callback interop. | Prefer `Task { @MainActor }` for consistency. |
| C-P3-3 | `BillingHubInvoiceCoordinator.swift:1168–1182` | Continuation bridging (`bridging.md`) | Mail share uses `withCheckedContinuation` + `withTaskCancellationHandler` — correct pattern. | No change. |
| C-P3-4 | `AppSession.swift:44–95` | — | Solid startup concurrency. | No change. |

### PrioritizedFixes (Concurrency)

1. **Replace EventKit delete GCD path** (`EventKitSyncService+Push.swift:311`) — structured async + cancellation + task handle.
2. **Move calendar display pipeline off main actor** (`CalendarViewModel+Fetching.swift:148+`) — biggest UI-freeze risk.
3. **Coalesce travel breakdown tasks** (`BillingHubAddTravelPanel.swift:147`) — stop unstructured task storms.

---

## 2. swiftui-performance-audit

**SkillCoverage: ~65%**

Reviewed against: code-smells (observation fan-out, heavy body work, identity, layout), report template. No runtime traces — hypotheses marked code-backed.

### Strengths

- **Debounced projection refresh** — `BillingHubProjectionDebounce` + `.task(id: projectionTaskID)` in `BillingHubView.swift`.
- **Display refresh dedup** — `DisplayItemsRefreshFingerprint` skips redundant calendar rebuilds.
- **Precomputed day caches** — `timedItemsByDay`, `combinedItemsByDay`, `relativePlacementsByDay` avoid per-column re-filter in `getTimedItems`.
- **Viewport culling** — `WeekView` `visibleHourRange` limits rendered blocks in `DayColumnView`.
- **Narrow Kanban observation surface** — `KanbanBoardDisplayState` passes only `searchText` / `hasActiveFilters` into board chrome.
- **`.task(id:)` over `onAppear` Task** — `CalendarView` filter task, Billing Hub projection/focus tasks.

### Findings

#### P0

| ID | Location | Smell | Why | Fix |
|----|----------|-------|-----|-----|
| P-P0-1 | `CalendarViewModel+Fetching.swift:238–315` | Main-thread work during render (`code-smells.md` triage #3) | Recurrence expansion + multi-day split + sort + overlap geometry + all-day layout run on main actor inside display refresh. Symptom: week scroll jank, CPU spikes on filter/date change. | Background snapshot build; main actor assigns immutable caches only. Validate with Time Profiler on week navigation. |
| P-P0-2 | `InvoiceEditorViewModel+Draft.swift:7–59`, `+Layout.swift:264–271`, `InvoiceEditorViewModel.swift:137–143` | Heavy computed properties + broad `@Observable` | `draftPayload` rebuilds full struct from 80+ fields; `invoicePages` runs pagination; `validationErrors` validates draft. Any field edit invalidates preview/inspector/document subtree. | Split VM: layout/validation `@ObservationIgnored` + explicit invalidation tokens; or child `@Observable` per pane. |

#### P1

| ID | Location | Smell | Why | Fix |
|----|----------|-------|-----|-----|
| P-P1-1 | `CalendarViewModel.swift:14–157` | Observation fan-out (`code-smells.md`) | Single `@Observable` owns loading, bulk ops, travel sheet, filters, item caches, nudge banners. `isLoading` or `bulkOperationProgress` change re-invalidates entire `WeekView`/`MonthView`. | Extract `CalendarDisplayState` (items/caches) vs `CalendarInteractionState` (selection/sheets). Pass narrow bindings to week grid. |
| P-P1-2 | `BillingHubViewModel.swift:14–36` | Observation fan-out | One VM owns search, bulk progress, focus queue, projection, sort options, feedback. `bulkActionProgress` updates during bulk ops invalidate full Kanban. | `@ObservationIgnored` on bulk progress with explicit progress view model, or isolate toolbar state. |
| P-P1-3 | `KanbanBoardView.swift:219–221` | Heavy work in view builder | `sectionPresentations` rebuilds all lane presentations every `body` eval. | Precompute in VM when `boardProjection` changes; pass `let sections:` into view. |
| P-P1-4 | `BillingHubView.swift:221–276` | Unstable action closures | `boardContent` constructs new `KanbanBoardActions` / `KanbanCardActions` each body pass — child identity churn. | Stable action struct stored on VM, updated only on projection revision. |
| P-P1-5 | `WeekView.swift:38–72` | Layout thrash (`code-smells.md`) | Nested `GeometryReader` (grid + scroll offset) recalculates column widths, hour height, all-day strip on every layout pass. | Fixed/minimum column width via preferences; hoist geometry to parent once. |

#### P2

| ID | Location | Smell | Why | Fix |
|----|----------|-------|-----|-----|
| P-P2-1 | `CalendarViewModel+Fetching.swift:24–29` | Sort/filter in refresh path | Fingerprint builds sorted joined signature over all sessions each refresh — O(n log n) string work on main actor. | Hash-based signature (revision + count + max modified date). |
| P-P2-2 | `CalendarItemBlockView.swift:31–58` | Repeated decode in hot path | `CalendarColorProvider.color(for:)` decodes UserDefaults JSON until cache warm; many blocks × many colors on first paint. | Warm cache at VM init; inject color map from `CalendarViewModel`. |
| P-P2-3 | `BillingHubAddTravelPanel.swift:147–154` | Excessive invalidation | Eight `onChange` → eight async breakdown refreshes without debounce. Symptom: typing distance spikes CPU. | `.task(id: BreakdownInputID)` with 150ms debounce (mirror Billing Hub projection). |
| P-P2-4 | `InvoiceDocumentPreview.swift:242,734` | Pagination in view update path | Reads `viewModel.invoicePages` during render/measure cycles. | Cache pages behind `@ObservationIgnored` + measurement token (partially exists via `paginationMeasurementToken`). |
| P-P2-5 | `BillingHubView.swift:59–60` | Broad opacity overlay | Whole board at 0.6 opacity during `isLoading` — forces large subtree redraw. | Overlay `ProgressView` only; avoid mutating board opacity. |

#### P3

| ID | Location | Smell | Why | Fix |
|----|----------|-------|-----|-----|
| P-P3-1 | `WeekView.swift:110` | `ForEach(..., id: \.self)` on `Date` | Week days stable within view — acceptable. | Monitor if timezone/DST causes identity churn. |
| P-P3-2 | `GlobalHourGridView` Canvas | — | 24-line Canvas is cheap. | No change unless profiling shows otherwise. |
| P-P3-3 | `KanbanBoardView.swift:157–173` | Horizontal scroll of 3 sections | Low card count per lane typically. | Profile with large datasets before optimizing. |

### Metrics

| Metric | Before | After | Notes |
|--------|--------|-------|-------|
| CPU | — | — | Profile week navigation + Billing Hub filter churn on device, Release |
| Frame drops | — | — | SwiftUI timeline during calendar date scrub |
| Memory peak | — | — | Large recurring calendar import + editor with 50+ line items |

### PrioritizedFixes (Performance)

1. **Offload calendar display pipeline** (`CalendarViewModel+Fetching.swift`) — same as concurrency P0; highest impact for WeekView.
2. **Split InvoiceEditorViewModel observation surface** — stop full-document invalidation on every keystroke.
3. **Precompute Kanban section presentations + stable actions** — cut board invalidation storms during bulk ops.

---

## Cross-Skill Overlap

| Hotspot | Concurrency issue | Performance issue |
|---------|-------------------|-------------------|
| `CalendarViewModel+Fetching` | Main-actor blocking | Main-thread render work |
| `MapKitTravelService` / travel panels | Main-actor MapKit queue | Repeated breakdown refresh |
| `BillingHubViewModel` | Unstructured fire-and-forget tasks | Broad `@Observable` fan-out |
| `InvoiceEditorViewModel` | Actor hops on save (OK) | 80+ observed fields → preview thrash |
| `EventKitSyncService+Push.delete` | GCD + no cancellation | — |
| `AppSession` | Clean | Minimal UI surface |

---

## Summary

Both skills show **mature patterns in the right places** (model actors, task-group EventKit saves, generation tokens, fingerprint dedup, viewport culling). Gaps cluster in **hot paths still monolithic on `@MainActor`** (calendar display, invoice editor observation) and **legacy unstructured concurrency** (EventKit delete, travel panel `onChange` tasks).

Recommended validation after fixes: Instruments SwiftUI timeline + Time Profiler on (1) week date scrub with recurring sessions, (2) Billing Hub bulk move, (3) invoice editor rapid typing with live preview.

[REDACTED]