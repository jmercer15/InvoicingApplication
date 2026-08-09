# SwiftData remediation ledger

| Area | Evidence | Status |
| --- | --- | --- |
| Historical schema safety | `AppMigrationPlan` exposes only current immutable schema; no live-model historical aliases remain. | Blocked pending redacted shipped stores and matching source/build revisions. |
| Release migration gate | `AppMigrationPlan.legacyStoreMigrationIsQualified == false`. | Release migration support blocked. |
| Persistent store placement | `ModelContainerFactory.persistentStoreURL()` resolves `Application Support/com.jesse.InvoicingApplication/InvoicingApplication.store`. | Implemented. |
| Recovery copy | `PersistentStoreRecovery` copies store plus `-wal` and `-shm`; source remains untouched. | Implemented; migration caller must enable after fixtures qualify stages. |
| CloudKit history | `SwiftDataStoreChangeMonitor` uses public persistent-history fetch and expiry handling only. | Implemented. |
| Session import | Bounded start-time fetch and client/start-time upsert. | Implemented; `ImportIdempotenceTests`. |
| NDIS import | Stable version ID; legacy date fallback; regional prices replaced per touched version. | Implemented; `ImportIdempotenceTests`. |

Fixture matrix remains required before any historical schema or migration stage is released.
