# SwiftData Architecture Refactor Contracts

**Date:** 2026-04-20  
**Owner:** InvoicingApplication refactor working set

See also [concurrency-audit.md](concurrency-audit.md) for model-actor construction sites, backfill behavior, and manual-save context policy.

## 1) Invariants and acceptance criteria

### 1.1 Core invariants

- `ModelContext` mutation pathways remain actor-owned for heavy workflows.
- Query reads stay VM-light and source from view-backed `@Query` / model fetch paths.
- Snapshots remain allowed only at persistence/interop boundaries; no feature-internal, long-lived snapshot caches for control flow.
- Feature bootstrap is environment-centered: scenes receive injected services and feature providers, not a single mutable global orchestration singleton.

### 1.2 Acceptance for phase gates

- Buildable compilation on changed modules after each phase.
- Existing startup windows (Workspace/Inspector/Activity/Settings) load within acceptable latency envelope documented in section 3.
- No `TODO` in files touched by a completed phase remains unaddressed.
- Existing deep-link paths and inspector selection still resolve before/after refactor.

### 1.3 Stop-the-line conditions

- Any build-breaking change in `InvoicingApplicationApp.swift`, bootstrap wiring, or persistence path.
- Regression in invoice selection/deep-link, NDIS search/filter, or drag/drop movement.
- Actor boundary deadlock/timeouts in travel or draft generation flows.

### 1.4 Rollback criteria

- If build fails in a completed phase due to a changed public contract.
- If feature smoke checks in section 6 regress versus current production behavior.
- If startup fails to produce a usable `ModelContainer` on a healthy machine/container state.

## 2) Dependency matrix

| File                                                                                 | Ownership                                  | Inputs                                                             | Output responsibilities                                                | Shared coupling risk                                               |
| ------------------------------------------------------------------------------------ | ------------------------------------------ | ------------------------------------------------------------------ | ---------------------------------------------------------------------- | ------------------------------------------------------------------ |
| `InvoicingApplication/App/Composition/AppWorkspaceBootstrap.swift`                   | App bootstrap                              | service constructors, `AppDatabase`                                | Produces `AppDatabase`, `WorkspaceServicesPhase`, `persistence bundle` | `AppDatabase`, settings and service assembly                       |
| `InvoicingApplication/App/Scenes/InvoicingApplicationApp.swift`                      | Scene composition                          | `AppSession`, `AppRuntime`, environment keys                       | Scene roots, service hydration, model container attachment             | `WorkspaceSceneSession` lifecycle, `modelContext` distribution     |
| `Packages/Data/Sources/Data/Services/BillingDraftBuilderService.swift`               | Persistence/actor service                  | `ModelContainer`, `NDISBillingIntegrationService`, `MMMZoneLookup` | Draft + issue + claimable-line persistence                             | Concurrency contract with callers (`@MainActor`/actor boundary)    |
| `Packages/Data/Sources/Data/Actors/BulkClaimBuilderActor.swift`                      | Domain actor                               | `ModelContext` via actor model isolation                           | Claim line batching and draft aggregation                              | `Session`/`Invoice` graph traversal                                |
| `Packages/Feature.NDIS/Sources/Feature_NDIS/ViewModels/NDISContainerViewModel.swift` | UI domain state + projection orchestration | `@Query` snapshots, settings values, user filters                  | Search/filter/sort projection and inspector selection                  | In-memory catalogue persistence and projection freshness           |
| `Packages/Core/Sources/Core/Models/Snapshots/*.swift`                                | Core DTOs (Sendable boundaries)            | `@Model` entities at `snapshot()` / init boundaries                | Value-type mirrors for actors, automation, import/export               | Field changes ripple across Features/Data that consume `Core` DTOs |

## 3) Baseline telemetry points (manual notes at implementation start and checkpoint)

### Startup

- `AppSession.bootstrap()` wall-clock duration (ms) from `.task { await session.bootstrap() }` start to first workspace root render.
- Container bootstrap to scene-ready transition.

### Invoices

- Invoices filter invocation duration for repeated filter/sort mutation (ms).
- End-to-end `InvoicesContentColumn` redraw latency (ms) for filter bursts.

### NDIS

- NDIS catalogue rebuild duration for current seed dataset (ms).
- Projection build time for `item.versionFilter + feature/unit/menu` transitions.

### Background actor channels

- Actor queue latency:
  - `TravelChargeAutomationActor.runAutomation` start-to-completion
  - `DataExporterActor`/`BulkClaimBuilderActor` command round-trip

## 4) Cross-feature boundary contract

### 4.1 PersistentIdentifier handoff

- UI/state transitions between scenes and actors use `PersistentIdentifier` whenever available.
- ID fallback to `UUID` is allowed only for legacy APIs and only at adapter boundaries.
- Actors receiving identifiers are responsible for local resolution and validation.

### 4.2 Snapshot boundary policy

- Boundary snapshots permitted for:
  - Import/export serialization payloads
  - actor-to-actor message passing where `@Model` graph cannot be sent safely
  - deterministic command payloads in legacy service adapters
- Boundary snapshots prohibited for:
  - long-lived in-memory feature UIs
  - view state duplication of live entity graphs

### 4.2.1 Boundary callsite mapping (snapshot -> model object handoff)

- Build and draft flow:
  - `Packages/Feature.BillingHub/.../BillableDraftsViewModel` should pass `Session`, `Client`, and `ClientService` model IDs and keep `BillableDraft`/`ClaimableLine` model materialization in the service layer.
  - `Packages/Data/Sources/Data/Services/BillingDraftBuilderService` should convert incoming `UUID` identifiers to `Model` objects before persistence.
- Claim batching and BPR:
  - `Packages/Feature.Settings/.../ClaimBatchesViewModel` should resolve `BulkClaimBatch`/`BillableDraft` models before persistence mutation.
  - `Packages/Data/Sources/Data/Actors/BulkClaimBuilderActor` should return `BulkClaimLineSnapshot` only from actor boundary, with insertion into `BulkClaimLine` performed by callers.
- Travel-charge automation:
  - `Packages/Feature.Settings/.../TravelChargeAutomationViewModel`/review flow should pass `Session` references, not `SessionSnapshot` collections, where immediate model context access is available.
  - `Packages/Core/Sources/Core/Services/TravelChargeAutomationService.swift` may continue using snapshots internally as long as long-lived UI state does not retain them. Persistence for charges/reviews/audit logs is centralized in `TravelChargeAutomationPersistence`; duplicate detection uses `TravelChargeDuplicatePolicy`; pricing mapping uses `TravelChargePricingMath`.
- Import/export:
  - `Packages/Data/Sources/Data/Actors/DataExporterActor` and `InvoiceTemplateEditor` helpers should continue to emit DTO payloads only at file boundary.

### 4.3 Compile-compatibility notes (public API snapshot types)

- **Stub policy:** retain `EntitySnapshots.swift` as an empty anchor file; do not reintroduce types here. (Removing the path is optional but would break bookmarks and some team muscle memory.)
- Keep snapshot DTO **public API** stable when touched. Implementations live in `Packages/Core/Sources/Core/Models/Snapshots/` (one type per file). When changing a snapshot, edit the matching `Snapshots/<TypeName>.swift` file.
- Snapshot types (same module visibility as before):
  - `AddressSnapshot`
  - `TravelChargeSnapshot`
  - `ClientSnapshot`
  - `ClientServiceSnapshot`
  - `RegionalPriceSnapshot`
  - `NDISItemSnapshot`
  - `InvoiceItemSnapshot`
  - `InvoiceSnapshot`
  - `SessionSnapshot`
  - `BusinessSnapshot`
  - `ClaimableLineSnapshot`
  - `BillableDraftSnapshot`
  - `BulkClaimBatchSnapshot`
  - `BulkClaimLineSnapshot`
  - `DraftIssueSnapshot`
  - `TravelChargeAuditLogSnapshot`
  - `TravelChargeReviewSnapshot`
  - `ServiceAgreementSnapshot`
  - `SupportLogSnapshot`
- Preserve `snapshot()` public entrypoints on entities already exposing boundary serialization.
- When changing DTO fields, keep backward-compatible initializers available in the corresponding module before removing call sites.

## 5) Publicly visible migration checkpoints

### Pre-phase checkpoint (Phase 1 complete)

- Plan contract file exists and all teams have approved no-go list.
- App still starts and opens workspace scene with read-only content.

### Post-phase checkpoint (Phases 2–3 complete)

- One feature factory protocol in place and injected through environment.
- Invoices list no longer mutates `@Query` rows into long-lived VM snapshots.

### Post-phase checkpoint (Phases 4–5 complete)

- NDIS and draft building use actor-backed heavy processing for intensive sections.
- Snapshot usage in active UI flows moved to boundary-only paths.

### Post-phase checkpoint (Phases 6–7 complete)

- Import/export and bulk workflows routed via dedicated orchestration boundaries.
- Verification smoke paths pass for invoice and NDIS flows after each window.

## 6) Final architecture notes (phase 07)

- The data layer is now boundary-driven:
  - long-running domain actions flow through Data actors (`@ModelActor`, dedicated services, or `ImportExportCoordinator`).
  - feature view models remain thin and query-oriented, pushing heavy work out to coordinators/workflow actors.
  - UI transitions now consume `PersistentIdentifier` or bounded command payloads as the default path, with UUID fallback only at explicit adapter boundaries.
- Query behavior now follows projection-first refresh semantics:
  - computed properties and explicit query paths drive updates instead of manual batch re-snapshots.
  - long-lived in-memory lists are now used only for transient UI state (selection/search UI affordances), not as durable truth.
- Drag/drop behavior is now split into policy (`BillingHubDragDropCoordinator`) and execution (`BillingHubWorkflowActor`), which keeps validation and mutation testable without view dependency.

## 7) Deprecated compatibility-shim removal checklist

Completed shim rows are intentionally not kept as path-based inventory after deletion. Current cleanup gates are:

- The historical repository/mapper/unit-of-work persistence stack stays removed from `Packages/Data`; use services, actors, and scene-owned contexts instead.
- No runtime path depends on removed test-helper or settings compatibility aliases.
- Core-owned recurrence and NDIS billing types remain imported from `Core` or through explicit Data service APIs only.
