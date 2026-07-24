# SwiftData Persistence Boundaries

This note classifies current `ModelContext` ownership for the refactor roadmap.
It is a working contract for reducing broad persistence reach without replacing
SwiftData's `@Query`-first read model.

## Ownership Classes

### App and Storage Bootstrap

Keep context/container construction centralized in:

- `InvoicingApplication/App/Composition/AppWorkspaceBootstrap.swift`
- `InvoicingApplication/App/Scenes/InvoicingApplicationApp.swift`
- `Packages/Data/Sources/Data/Persistence/AppDatabase.swift`
- `Packages/Data/Sources/Data/Persistence/ModelContainerFactory.swift`

Allowed responsibilities:

- create the production or in-memory `ModelContainer`
- create manual-save scene/settings contexts through `AppDatabase.makeMainContext()`
- create actor-backed persistence workers
- inject the scene-owned context at the workspace/settings/tool-window root

### Data-Layer Write Boundaries

Keep multi-model writes and heavy persistence workflows in `Packages/Data` or
actor-backed services:

- import/export and wipe workflows
- billing draft and bulk-claim generation
- EventKit synchronization and remote import/reconciliation
- migration orchestration and post-open maintenance
- geocoding persistence
- NDIS compliance and billing integration

These flows should pass value snapshots or identifiers across actor/context
boundaries and refetch models inside the owning context.

### Core boundary DTOs (`*Snapshot` types)

Cross-actor / automation / interop value mirrors (`AddressSnapshot`, `SessionSnapshot`, etc.) live in **`Packages/Core/Sources/Core/Models/Snapshots/`** (one public type per file). `EntitySnapshots.swift` is **deliberately empty** (navigation anchor only); edit the matching `Snapshots/<TypeName>.swift` when changing fields or initializers.

### Feature Commands and View Models

Feature-level `ModelContext` ownership is acceptable only when the type is a
feature root/coordinator for user-initiated edits, selection, or command
orchestration. Current examples to reduce over time:

- `Feature_BillingHub`: `BillingHubViewModel`, `BillableDraftsViewModel`
- `Feature_Calendar`: `CalendarViewModel`, `SessionModificationService`
- `Feature_Clients`: `RelationshipsContainerViewModel`,
  `ClientDetailView`, `PlanManagerDetailViewModel`, `PayeeDetailViewModel`
- `Feature_Invoices`: `InvoicesContainerViewModel`, `InvoiceEditorViewModel`
- **`Feature.Settings` package** (`Feature_Settings` SPM module): `ImportExportViewModel`,
  `ClaimBatchesViewModel`, `CompanyViewModel`

When one of these types only forwards live read state, prefer moving the read
to a feature root with `@Query`. When it performs multi-model mutation, keep a
small command/use-case object and move background work to `Packages/Data`.

### SwiftUI Read Roots

`@Query` remains the preferred ownership model for simple live reads in root
list/detail entry views. Do not add container view models solely to mirror
SwiftData query state.

## Migration Rule

For each touched feature, classify every direct `ModelContext` use before
editing:

1. Simple live read: keep or move to `@Query`.
2. Single-screen edit command: keep near the feature root or extract a small
   command type.
3. Multi-model or background workflow: move behind a Data-layer service or
   model actor.

Do not add compatibility adapters for unreleased in-branch code. Replace the
old shape once the touched feature has test or preview coverage.
