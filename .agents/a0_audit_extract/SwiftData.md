# SwiftData Audit — InvoicingApplication

Read-only review against **swiftdata-pro**, **swiftdata-testing**, and all **10 project `.cursor/skills/swiftdata-*`**. Scope: `Packages/Data`, `Packages/Core` models, feature `@Query`/`@ModelActor`, AppShell wiring, test fixtures. `.build/BuildData` ignored.

---

## 1. swiftdata-pro

**SkillCoverage: 84%**

### Strengths
- Central `ModelContainerFactory` + `AppDatabase` with explicit manual-save contract and CloudKit container ID
- No `#Unique` / `@Attribute(.unique)` — CloudKit-safe
- Broad `#Index<>` usage on high-query entities (`Invoice`, `Session`, `Client`, `NDISItem`, etc.)
- `@Query` confined to SwiftUI views; services/actors use `FetchDescriptor`
- `statusToken` mirror pattern avoids predicating encoded enum `Data` — smart workaround
- `localizedStandardContains` used for invoice search (`InvoicesListQuery.swift:245`)
- `fetchLimit`, `relationshipKeyPathsForPrefetching` on hot paths (`InvoiceModelActor.swift:50`, `BulkClaimBuilderActor.swift:38`)
- In-memory migration-plan guard tested (`ModelContainerFactoryTests.swift:50`)

### Findings

| Sev | Location | Rule | Why | Fix |
|-----|----------|------|-----|-----|
| **P1** | `Invoice.swift:18`, `InvoiceItemEntity.swift:18-19`, `ClientServiceEntity.swift:11`, `TravelChargeEntity.swift:16` | core-rules / decimal-money | Money stored as `Double` in `@Model` — binary drift under repeated arithmetic | Migrate money columns to `Decimal`; bridge at UI/API boundaries |
| **P2** | `NDISItemEntity.swift:40` | core-rules inverse | `regionalPrices` has no `@Relationship` macro; inverse only on `RegionalPrice` side | Add `@Relationship(deleteRule: .cascade, inverse: \RegionalPrice.ndisItem)` on one side |
| **P2** | Production bootstrap (`AppDatabase.swift:36`, `MigrationOrchestrator.swift`) | core-rules migration | No `SchemaMigrationPlan` / `VersionedSchema`; custom orchestrator only — fragile for non-lightweight schema changes | Introduce versioned schema + plan; keep orchestrator for data backfills in `didMigrate` |
| **P2** | `NDISBillingIntegrationService.swift:14-15` | core-rules actor boundary | Heavy batch persistence on `@MainActor` class, not `@ModelActor` | Extract writes to `@ModelActor`; return `Sendable` DTOs |
| **P3** | `ModelContainerFactory.swift:46-48` | core-rules | Unreachable dead code after throw at `:35-36` | Remove unreachable `if let migrationPlan` block |
| **P3** | `InvoicesContainerViewModel.swift:402`, `BulkClaimBuilderActor.swift:86` | predicates | `ids.contains($0.id)` in `#Predicate` — large ID sets may hit runtime limits | Batch fetches or predicate splitting for bulk ops |
| **P3** | `BillableDraftSessionPickerList.swift:27-35` | predicates | Predicate uses `if let` + multi-clause — compiles but harder to validate | Extract shared predicate builder; add unit test |
| **P3** | `SessionEntity.swift:47`, `InvoiceItemEntity.swift:40-42` | relationships inverse | Several `@Relationship` without explicit `inverse:` on this side (inverse on peer) — OK per one-side rule but `Session.clientService` / `InvoiceItem.invoice` rely on inference | Audit graph; add explicit inverse where inference ambiguous |
| **P3** | Index proliferation | indexing | 15+ indexed string fields on `NDISItem` — write cost on catalogue import | Measure; drop low-selectivity indexes (e.g. `itemDescription`) |

### PrioritizedFixes (Top 3)
1. **P1** — Plan `Decimal` migration for `Invoice.totalAmount`, `InvoiceItem.rate/quantity`, `ClientService.rate`, `TravelCharge.chargeAmount`
2. **P2** — Add `SchemaMigrationPlan` wired into `makePersistentContainer`; keep orchestrator for data backfill only
3. **P2** — Move `NDISBillingIntegrationService` persistence off main actor into `@ModelActor`

---

## 2. swiftdata-testing

**SkillCoverage: 71%**

### Strengths
- `ModelContainerFactory.makeInMemoryContext()` used widely — always `isStoredInMemoryOnly: true`
- Migration-plan + in-memory rejection explicitly tested (`ModelContainerFactoryTests.swift:50-58`)
- `AppDatabaseBootstrapTests` validates context isolation between workspace windows (`:42-61`)
- `BillingHubWorkflowActorTests` — modern `@Test` + `#expect`, fresh container per test, actor via `modelContainer`
- `BackfillModelActorTests` — separate context for assertions after actor call (`:19-25`)
- `SwiftDataStoreChangeMonitorTests` — cross-context save observation with revision wait
- `InvoiceEditorTransferRoundTripTests` — second import path tested (`:88-98`)

### Findings

| Sev | Location | Rule | Why | Fix |
|-----|----------|------|-----|-----|
| **P2** | ~90 XCTest files vs ~12 `import Testing` in `Packages/` | SKILL core — Testing framework | Skill targets Swift Testing; vast majority still XCTest | Migrate Data/actor tests first; keep XCTest only where UIKit lifecycle needed |
| **P2** | `RelationshipDeletionTests.swift:23-37` | model-container-fixtures | Shared `modelContainer`/`modelContext` in `setUp`/`tearDown` — order-dependent leakage risk | Fresh `makeInMemoryContext()` per test method |
| **P2** | `TravelChargeAutomationActorTests.swift:12-18` | model-container-fixtures | Same shared-container pattern in async setUp | Per-`@Test` / per-`func` container |
| **P2** | `NDISBillingIntegrationServiceTests.swift:115` | decimal-money-values | `XCTAssertEqual(..., accuracy: 0.0001)` on quantities — masks `Double` bugs | Seed/assert with `Decimal`; exact `==` |
| **P3** | No dedicated idempotency test | import-hash-dedup | `InvoiceEditorTransferRoundTripTests` checks revision bump, not `imported`/`skipped` counts | Add `@Test importingSameFileTwiceIsIdempotent` with fixed dates + summary assertions |
| **P3** | `BulkClaimExportHashVerifierTests.swift:23-40` | import-hash-dedup | Hash tested; no normalization edge cases (whitespace, trailing space) | Add hash-stability tests for string normalization policy |
| **P3** | `AllDataComplianceRoundTripTests.swift:8-23` | import-hash-dedup | Single import only — no re-import duplicate guard | Re-run `importAllData` on same payload; assert row counts unchanged |
| **P3** | `CalendarBillingHubNudgeContinuityTests.swift` | mock-repositories | ViewModel test constructs real in-memory container for continuity | Acceptable for integration; split pure VM tests behind protocol mocks |
| **P3** | `InvoiceModelActorIntegrationTests.swift` (40+ cases) | model-actor-testing | XCTest class; some tests pass `@Model` into actor methods | Audit actor API surface; assert via return DTOs or fresh context fetch |
| **P3** | 17 Data test files with `override func setUp` | model-container-fixtures | Shared setup pattern across Data tests | Standardize on per-test factory helper |

### PrioritizedFixes (Top 3)
1. **P2** — Eliminate shared-container `setUp` in `RelationshipDeletionTests` + `TravelChargeAutomationActorTests`
2. **P2** — Begin Swift Testing migration for `Packages/Data/Tests` actor/integration suites
3. **P3** — Add import idempotency tests with fixed dates + summary count assertions

---

## 3. swiftdata-model-definition

**SkillCoverage: 82%**

### Strengths
- All persistable types annotated `@Model` in `Packages/Core/Models`
- `#Index<>` aligned to query surfaces (calendar windows, invoice lists, NDIS catalogue)
- Encoded enum storage (`statusData`) + predicate mirror (`statusToken`) — migration-safe
- `@Attribute(originalName:)` used for CloudKit-safe renames (`Invoice.swift:29`, `AddressEntity.swift`)
- No `description` property on `@Model` classes

### Findings

| Sev | Location | Rule | Why | Fix |
|-----|----------|------|-----|-----|
| **P1** | `Invoice.swift:18-20`, `InvoiceItemEntity.swift:18-23` | model-definition — money types | Financial fields as `Double` violate precision intent | `Decimal` + value transformer if needed |
| **P2** | `NDISItemEntity.swift:40` | model-definition `@Relationship` | Collection without explicit relationship macro | Add `@Relationship` with delete rule |
| **P3** | `NDISItemEntity.swift:14` | indexing anti-pattern | 12 single-property indexes on one model | Compound indexes for common filter combos |
| **P3** | Project rule shows `@Attribute(.unique)` example | CloudKit conflict | Rule doc contradicts CloudKit skill — codebase correctly avoids it | Update rule doc, not code |

### PrioritizedFixes
1. Decimal migration for money columns
2. Explicit `@Relationship` on `NDISItem.regionalPrices`
3. Index audit on `NDISItem`

---

## 4. swiftdata-query-system

**SkillCoverage: 88%**

### Strengths
- Layer-appropriate split: `@Query` in views (`BillableDraftsQueryList`, `RelationshipsDetailColumn`, `ClaimBatchesQueryList`)
- Dynamic `@Query` reconstruction via initializer (`BillableDraftSessionPickerList.swift:15-43`, `CalendarSessionWindowProjection`)
- Centralized invoice filtering in `InvoicesListQuery.swift`
- Actor/service fetches use `FetchDescriptor` with limits
- ViewModels document `@Query`-fed data instead of duplicating fetches (`CompanyViewModel.swift:53`, `BillableDraftsViewModel.swift:36`)

### Findings

| Sev | Location | Rule | Why | Fix |
|-----|----------|------|-----|-----|
| **P3** | `InvoicesListQuery.swift:220-247` | query-system scale | Full in-memory filter after `@Query` materialization — OK now, scales poorly | Push filters into `@Query` initializer reconstruction |
| **P3** | `TravelChargeViewModel.swift:50` | predicates | Optional relationship chain in predicate | Verify runtime; add fetch tests |
| **P3** | Duplicate predicate shapes | query-system DRY | `#Predicate { $0.id == id }` repeated 30+ times | Shared predicate builders in `Packages/Data` |

### PrioritizedFixes
1. Shared predicate module for UUID lookups
2. Push invoice search/date filters into `@Query` when list grows
3. Predicate regression tests for relationship-optionals

---

## 5. swiftdata-relationships

**SkillCoverage: 86%**

### Strengths
- Explicit delete rules on virtually every relationship
- CloudKit-compatible optional relationships throughout
- Dedicated `RelationshipDeletionTests` suite (676+ lines) for cascade/nullify behavior
- Ownership modeled correctly: `BillableDraft.items` cascade, `Invoice.items` cascade, `Client.clientServices` cascade
- `BillableDraftEntity.swift:21` — full inverse chain for draft issues

### Findings

| Sev | Location | Rule | Why | Fix |
|-----|----------|------|-----|-----|
| **P2** | `SessionEntity.swift:52-54` | delete rules | `travelCharges`, `supportLogs`, `reviewItems` all `.cascade` — deleting session destroys billing audit trail | Consider `.nullify` or soft-delete for compliance entities |
| **P3** | `ClientServiceEntity.swift:28` | inverse | `travelCharges` cascade without inverse on this side (on `TravelCharge.service`) — valid one-side pattern | Document in model header |
| **P3** | `Invoice.swift:75-121` | legacy relationships | Dual snapshot + live `@Relationship` address fields — migration drain exists but graph complexity high | Complete drain migration; remove legacy `@Relationship` reads |
| **P3** | `DraftIssueEntity.swift:7` | inverse | `draft` nullify; inverse declared on `BillableDraft.issues` — correct one-side | No change |

### PrioritizedFixes
1. Review cascade-on-session-delete for audit/compliance data retention
2. Finish legacy address relationship drain
3. Extend `RelationshipDeletionTests` for `SupportLog` + session cascade

---

## 6. swiftdata-storage-infrastructure

**SkillCoverage: 92%**

### Strengths
- Single authoritative container via `AppDatabase.bootstrap` → injected via `.modelContainer(runtime.modelContainer)` (`InvoicingApplicationApp.swift:35`)
- `ManualSaveModelContextModifier` disables autosave on scene contexts (`ManualSaveModelContext.swift:11-12`)
- Per-window independent `ModelContext`, shared container (`AppDatabaseBootstrapTests.swift:30-39`)
- Factory methods: persistent / in-memory / ephemeral contexts
- Actor construction centralized in `AppDatabase` (`makeDataImporterActor`, etc.)
- CloudKit explicitly configured: `.private("iCloud.com.jesse.InvoicingApplication")`

### Findings

| Sev | Location | Rule | Why | Fix |
|-----|----------|------|-----|-----|
| **P3** | `ManualSaveModelContext.swift:11` | storage timing | `autosaveEnabled = false` set in `onAppear` — window could mutate before appear | Set at context creation in `AppSceneSessions` / scene bootstrap |
| **P3** | `AppDatabase.performPostOpenMigrations` (`:78-83`) | context ownership | Ad-hoc `ModelContext` for migrations separate from scene contexts | OK pattern; document as migration-only context |
| **P3** | `ModelContainerFactory.swift:46-48` | dead code | Unreachable migration branch | Delete |

### PrioritizedFixes
1. Disable autosave at context creation, not `onAppear`
2. Remove dead factory code
3. Document migration context lifecycle

---

## 7. swiftdata-concurrency-model

**SkillCoverage: 78%**

### Strengths
- 10+ `@ModelActor` types: `BulkClaimBuilderActor`, `BackfillModelActor`, `BillingHubWorkflowActor`, `InvoiceListFetchActor`, `TravelChargeAutomationActor`, etc.
- `PersistentIdentifier` / snapshot DTOs cross boundaries (`BillingHubWorkflowActorTests` uses `modelID`)
- `DefaultSerialModelExecutor` + manual-save contexts in actors (`BulkClaimBuilderActor.swift:27-30`)
- `AppDatabase` documents supported actor construction sites (`AppDatabase.swift:11`)
- `ProductionRuntimeAssembly.backfillStatusTokens` runs off main thread via actor

### Findings

| Sev | Location | Rule | Why | Fix |
|-----|----------|------|-----|-----|
| **P2** | `NDISBillingIntegrationService.swift:14` | concurrency — main actor heavy work | Invoice generation fetches/writes on `@MainActor` | `@ModelActor` + async report DTO |
| **P2** | `SessionModificationService.swift:29` | concurrency | Holds `ModelContext`; recurring merge logic on caller's actor | Route through `@ModelActor` or document main-actor confinement |
| **P3** | `InvoicesContainerViewModel.swift:368-419` | concurrency | Main-actor class deletes/saves invoices directly | Delegate to `InvoiceListFetchActor` or dedicated actor |
| **P3** | `CalendarViewModel.swift:189` | concurrency | VM holds `ModelContext` for ad-hoc fetches | Prefer `@Query` + actor for off-window resolves |
| **P3** | `BackfillModelActor.swift:8` | actor pattern | Manual `ModelActor` conformance vs macro — works but non-standard | Consider `@ModelActor` macro for consistency |

### PrioritizedFixes
1. `@ModelActor` for `NDISBillingIntegrationService` writes
2. Audit `SessionModificationService` isolation
3. Reduce main-actor `ModelContext` in ViewModels

---

## 8. swiftdata-persistence-lifecycle

**SkillCoverage: 86%**

### Strengths
- Manual-save contract enforced app-wide (`AppDatabase.swift:6-8`, `autosaveEnabled = false`)
- Explicit `save()` after mutations; rollback on failure (`InvoicesContainerViewModel.swift:409-418`)
- Batch paging in backfill with `save()` per page (`BackfillModelActor.swift:27-57`)
- Selection-aware delete documented (`RelationshipsContainerViewModel.swift:105`)
- Post-open migrations awaited before feature queries (`AppDatabase.swift:47-50`)

### Findings

| Sev | Location | Rule | Why | Fix |
|-----|----------|------|-----|-----|
| **P2** | `ManualSaveModelContext.swift:11` | lifecycle timing | Autosave window before `onAppear` | Set at context birth |
| **P3** | No undo configuration | persistence-lifecycle | Undo not enabled — intentional for macOS invoice app | Document as deliberate; no change unless product requires |
| **P3** | `MigrationOrchestrator` | lifecycle | Data migrations run outside SwiftData save boundaries | Ensure idempotent + transactional per migration step |

### PrioritizedFixes
1. Fix autosave timing at context creation
2. Add migration failure surfacing to bootstrap UI
3. Document no-undo policy

---

## 9. swiftdata-change-tracking

**SkillCoverage: 70%**

### Strengths
- `SwiftDataStoreChangeMonitor` uses token-based `fetchHistory` (`SwiftDataStoreChangeMonitor.swift:62-66, 91-106`)
- Observes `ModelContext.didSave` + `NSPersistentStoreRemoteChange` for CloudKit merges
- Revision counter drives projection refresh in Billing Hub / Invoices
- Test proves cross-context revision bumps (`SwiftDataStoreChangeMonitorTests.swift:8-31`)

### Findings

| Sev | Location | Rule | Why | Fix |
|-----|----------|------|-----|-----|
| **P2** | `SwiftDataStoreChangeMonitor.swift:105-106` | change-tracking token persistence | `lastToken` in-memory only — restart replays or misses history | Persist token to `UserDefaults`/file |
| **P2** | Same file | change-tracking cleanup | No `deleteHistory` — history grows unbounded | Bounded retention policy after successful processing |
| **P3** | Same file | relevance filtering | All transactions bump revision regardless of model type | Filter `HistoryChange` by entity type for feature-specific refresh |
| **P3** | Same file:101 | error handling | `try?` swallows fetch failures silently | Log + surface degraded mode |

### PrioritizedFixes
1. Persist history token durably
2. Add stale history cleanup
3. Filter transactions by relevant model types

---

## 10. swiftdata-synchronization

**SkillCoverage: 84%**

### Strengths
- Explicit CloudKit container ID (`CloudKitConfiguration.containerIdentifier`)
- No unique constraints — CloudKit-compatible
- Optional relationships throughout
- `CloudKitSyncMonitor` with account status, consecutive-error escalation (`CloudKitSyncMonitor.swift:159-195`)
- `PersistenceBootstrapPolicy.productionSyncRequired` fails fast without sync-compatible store
- Sidebar sync indicator in AppShell

### Findings

| Sev | Location | Rule | Why | Fix |
|-----|----------|------|-----|-----|
| **P2** | Enum via `Data` encoding | sync eventual consistency | Devices may see nil status until backfill runs | Backfill on every launch is good; add UI tolerance for nil status |
| **P3** | No sync integration tests | synchronization | CloudKit behavior untested in CI | Add mocked notification tests for `CloudKitSyncMonitor` |
| **P3** | `productionSyncRequired` throws on any container error (`AppDatabase.swift:34-39`) | bootstrap | Local dev without iCloud blocked | `.localOnly` policy exists — document dev workflow |
| **P3** | Project rule example uses `@Attribute(.unique)` | doc drift | Rule contradicts CloudKit constraints | Update rule doc |

### PrioritizedFixes
1. CloudKit monitor unit tests with synthetic notifications
2. Document dev bootstrap policies
3. Harden nil-status UI paths for unsynced devices

---

## 11. swiftdata-migration

**SkillCoverage: 65%**

### Strengths
- Rich custom `MigrationOrchestrator` with 10+ data migrations, history file, rollback hooks
- `@Attribute(originalName:)` for property renames without CloudKit rename
- Dedicated migration tests (`BackfillInvoiceAddressSnapshotsMigrationTests`, `DrainLegacyInvoiceAddressRelationshipsMigrationTests`, etc.)
- `BackfillModelActor` for post-open token backfill
- `ModelContainerFactory` rejects migration plan on in-memory stores

### Findings

| Sev | Location | Rule | Why | Fix |
|-----|----------|------|-----|-----|
| **P1** | No production `SchemaMigrationPlan` | migration Step 4 | Skill requires versioned schema for production changes; only custom orchestrator | Add `SchemaV1`/`SchemaV2` + plan; wire to `makePersistentContainer` |
| **P2** | `MigrationOrchestrator.swift:55+` | migration safety | Data migrations fetch live `@Model` types post-schema-change — fragile if structure shifts | Run data backfills in `didMigrate` with versioned types |
| **P3** | In-memory tests skip post-open migrations (`AppDatabase.swift:47`) | test gap | In-memory never exercises migration path | Add persistent-store migration integration test target |
| **P3** | `EnumRawValueColumn_Migration.swift` comment | migration drift | References `@Transient` enum pattern not fully adopted | Align docs with `statusToken` approach |

### PrioritizedFixes
1. **P1** — Introduce `SchemaMigrationPlan` for structural schema changes
2. Move data backfills into plan stages where possible
3. Add migration integration test on temp on-disk store

---

## 12. swiftdata-specialist (cross-cutting)

**SkillCoverage: 80%**

### Strengths
- Clean package boundaries: `Core` models, `Data` persistence/services, `AppShell` composition, feature `@Query`/actors
- Snapshot DTOs throughout `Packages/Core/Models/Snapshots/` for cross-actor transfer
- `PersistenceSchema.appModels` single registry (`PersistenceSchema.swift:5-28`)
- Feature factories receive `ModelContext` + `ModelContainer` from AppShell (`WorkspaceSceneSession.swift:36-54`)
- Strong test fixture centralization via `ModelContainerFactory`

### Findings

| Sev | Location | Rule | Why | Fix |
|-----|----------|------|-----|-----|
| **P1** | Double money across Core + tests | specialist baseline | Undermines billing correctness | Decimal migration (cross-cutting) |
| **P2** | No `SchemaMigrationPlan` | specialist storage + migration | Biggest architectural gap | Versioned schema rollout |
| **P2** | Main-actor persistence services | specialist concurrency | `NDISBillingIntegrationService`, several VMs | Actor extraction |
| **P3** | XCTest vs Testing split | specialist testing | Inconsistent test modernity | Unified testing strategy |
| **P3** | History token not durable | specialist change-tracking | Restart loses incremental checkpoint | Persist token |

### PrioritizedFixes
1. Decimal money migration (models + tests + UI formatters)
2. SchemaMigrationPlan + versioned schema
3. Main-actor persistence → `@ModelActor` extraction plan

---

## Cross-Skill Summary

| Priority | Theme | Impact |
|----------|-------|--------|
| **P0** | None found | No immediate crash/data-loss bugs identified in static review |
| **P1** | `Double` money in `@Model`; no `SchemaMigrationPlan` | Cent drift; risky schema evolution |
| **P2** | Main-actor heavy persistence; shared test containers; history token not persisted | UI jank, flaky tests, restart replay |
| **P3** | Predicate DRY, index tuning, Testing migration, import dedup test gaps | Maintainability |

**Overall project SwiftData maturity: strong.** Container wiring, CloudKit-safe schema, relationship testing, and actor adoption are above average. Highest ROI: **Decimal money**, **SchemaMigrationPlan**, **eliminate shared test fixtures**, **persist history tokens**.

[REDACTED]