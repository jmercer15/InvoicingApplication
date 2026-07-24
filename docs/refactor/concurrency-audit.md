# SwiftData concurrency audit (workspace bootstrap)

**Purpose:** Single reference for where `@ModelActor` instances are constructed and how background work is scheduled. Complements `docs/refactor/contracts.md`.

## Background model actors (database bootstrap)

Constructed via `AppDatabase` in `AppWorkspaceBootstrap.loadDatabase()` (app target) and the factory methods on `AppDatabase` (Data package):

- `DataImporterActor`, `DataExporterActor`, `BulkClaimBuilderActor`, `TravelChargeAutomationActor`

The load phase runs on the main actor (`AppWorkspaceBootstrap`); actor initializers receive `ModelContainer` (`Sendable`). Callers cross isolation via `await` on actor methods—heavy work executes on each actor’s serial executor, not the UI `ModelContext`.

## NDIS compliance

`NDISComplianceValidator` is created in [`WorkspaceSceneSession.init`](../../InvoicingApplication/App/Composition/AppWorkspaceBootstrap.swift) on the main actor. Validation work is invoked through the actor’s public API; call sites should not pass live `Model` instances across the UI/actor boundary (use IDs / snapshots per project rules).

## Backfill (status tokens)

`ProductionRuntimeAssembly.scheduleStatusTokenBackfill` runs `BackfillModelActor` in an unstructured `Task` so the app session can reach `.ready` before backfill finishes. **No feature should assume** `statusToken` backfill is complete until we add an explicit gate; until then, queries that depend on backfilled fields should tolerate empty/missing values or re-check after import.

## Autosave and undo

- Workspace and settings **manual-save** UI contexts: `AppDatabase.makeMainContext()` and `PersistenceBundle` both set `autosaveEnabled = false` (see `AppDatabaseBootstrapTests`).
- Do not enable autosave on the primary editing context without an explicit product decision; it breaks coherent undo groupings for desktop editing.
