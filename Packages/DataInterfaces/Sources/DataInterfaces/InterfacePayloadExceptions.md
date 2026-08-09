# DataInterfaces payload exceptions

Workstream A3 prefers domain UUIDs and Core `*Snapshot` DTOs at protocol boundaries.
These are the documented exceptions where SwiftData types remain intentional.

## `PersistentIdentifier` in `ReferenceDataFetching`

| Method | Why not UUID |
|--------|----------------|
| `fetchAllNDISItemIDs()` | Service assignment sheet resolves `@Query` rows via `persistentModelID` set membership without a second sort pass. |
| `fetchAllPayeeIDs()` | Same pattern for payee picker `@Query` hydration. |
| `fetchAllPlanManagerIDs()` | Same pattern for plan-manager picker `@Query` hydration. |

New feature code should call the `fetchAll*UUIDs()` variants when only domain identity
is needed, or request snapshot/DTO methods when crossing actor boundaries.

## Live `@Model` types in `@MainActor` protocols

| Protocol | Live model | Why |
|----------|------------|-----|
| `ClaimBatchPersisting` | `BulkClaimBatch`, `BulkClaimLine` | Settings claim UI binds directly to main-context rows for `@Query` detail/export; snapshots used for inserts only. |
| `BusinessPersisting` | `Business`, `Address` | Company settings VM keeps draft copies off the persisted graph until save; persistence helper needs live insert/update semantics. |
| `TravelChargeReviewFetching` | `TravelChargeReviewItem` | Review resolution passes `PersistentIdentifier` to `TravelChargeAutomationActor`. |
| `ClientRelationshipDeleting` | `Client`, `Payee`, `PlanManager` | Cascade delete operates on live relationship graph in caller context. |

## SwiftData import in DataInterfaces

`ReferenceDataFetching` imports `SwiftData` solely for `PersistentIdentifier` in the
legacy methods above. No `ModelContext` or fetch descriptors appear in this package.
