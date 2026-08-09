# InvoicingApplication Test Audit — Swift Testing Skills

**Scope:** `Packages/*/Tests` (109 files) + `InvoicingApplicationTests` (1 file). Excludes `.build/` / `BuildData/`.

**Inventory**

| Metric | Count |
|--------|------:|
| Total test Swift files | 110 |
| XCTest (`XCTestCase` / `import XCTest`) | 98 (~89%) |
| Swift Testing (`@Test` / `import Testing`) | 11 (~10%) |
| Mixed (both frameworks in one file) | 0 |
| `@Test` functions | 46 |
| `XCTAssert*` calls | ~2,412 |
| Files with `setUp`/`tearDown` | 20 |
| Parameterized suites (`@Test(arguments:)`) | 1 |
| Custom `Tag` usage | 0 |
| Model `.fixture()` in Sources | 0 |

---

## 1. swift-testing-pro

**SkillCoverage: 18%**

Scored against core-rules, writing-better-tests, async-tests, new-features, migrating-from-xctest. Strong where Swift Testing exists; bulk of suite still XCTest-shaped.

### Strengths

- **Modern islands done well:** `UpdateInvoiceStatusTests`, `WorkspaceSceneStorageRoundTripTests`, `BillingHubWorkflowActorTests`, `AppNavigationManagerTests` use `struct` suites, `#expect`, async/throws correctly.
- **Parameterized test:** `UpdateInvoiceStatusTests` maps 7 status aliases in one `@Test(arguments:)` — exactly what the skill recommends.
- **Suite serialization where needed:** `AppIntentTests` uses `@Suite(.serialized)` for shared singletons — correct trait use.
- **Multi-window Swift Testing:** `WorkspaceSceneStorageRoundTripTests` + `AppNavigationManagerTests` cover per-window isolation with `#expect`.
- **In-memory SwiftData:** Widespread `ModelContainerFactory.makeInMemoryContext()` keeps tests fast and isolated.
- **Billing workflow actor migrated:** `BillingHubWorkflowActorTests` is a good XCTest→Swift Testing template (throws, `#require`-ready fetches, `Issue.record` for enum cases).

### Findings

| ID | Sev | Location | Rule | Why | Fix |
|----|-----|----------|------|-----|-----|
| STP-1 | **P0** | 98/110 files (e.g. `BillingHubPhase2HonestyTests.swift:8-9`, `NDISClaimTypeMapperTests.swift:10`) | Core: structs over `XCTestCase`; no `XCTAssert` | ~89% suite still XCTest; blocks parallel discovery, `#require`, traits | Migrate package-by-package; start BillingHub/Data NDIS suites |
| STP-2 | **P1** | 20 files (e.g. `NDISClaimTypeMapperTests.swift:14-24`, `RelationshipDeletionTests.swift:23-34`) | Core: `init`/`deinit` not `setUp`/`tearDown` | XCTest lifecycle; harder parallel isolation | Replace with struct `init() throws` holding container/context |
| STP-3 | **P1** | `BillingHubPhase2HonestyTests.swift:23`, `BillingHubSmokeTests.swift:177`, `NDISContainerViewModelTests.swift:9` | writing-better-tests: `#require` not `try!` | Force-unwrap setup masks real failures | `let (container, context) = try ModelContainerFactory.makeInMemoryContext()` |
| STP-4 | **P1** | `AppNavigationManagerTests.swift:26,50,81,186,200`, `WorkspaceSceneStorageRoundTripTests.swift:42`, `BillingHubWorkflowActorTests.swift:44,46`, `CalendarDisplayItemsGenerationTests.swift:28,52`, `AppIntentTests.swift:28` | Core: never `#expect(!bool)` | Defeats macro expansion; poor failure messages | `#expect(x == false)` |
| STP-5 | **P1** | `UpdateInvoiceStatusTests.swift:29` | writing-better-tests: name specific errors in `#expect(throws:)` | `(any Error).self` passes on wrong error type | `#expect(throws: ImportError.unsupportedStatus)` or `Issue.record` in catch |
| STP-6 | **P2** | `BillingHubWorkflowActorTests.swift:64-68` | writing-better-tests: prefer `#expect(throws:)` / pattern match | Manual `if case` + `Issue.record` is verbose | `#expect(result == .invalidTransition(...))` or dedicated helper with `#_sourceLocation` |
| STP-7 | **P2** | `InvoicingApplicationTests/AppSessionTests.swift:43` vs `AppShellTests/AppSessionTests.swift:6-55` | Organization | Duplicate `AppSessionTests` names; split coverage | Consolidate into one target; one struct suite |
| STP-8 | **P2** | `BillingHubPhase2HonestyTests.swift:734`, `BillingHubSmokeTests.swift:552`, `BillingHubFocusContinuityTests.swift:238` | writing-better-tests: shared fixtures | Same `StubNDISBillingIntegrationService` copy-pasted 3× | Single shared test helper or `#if DEBUG` stub on protocol |
| STP-9 | **P2** | All 110 files | Core: tags | No `.networking`, `.integration`, `.slow`, `.smoke` | Add `extension Tag` + tag migration/integration/migration tests |
| STP-10 | **P2** | `BillingHubPhase2HonestyTests.swift:11-19`, `ModelContainerFactoryTests.swift:8-18` | Core: parameterized tests | Repetitive duration/status assertions | `@Test(arguments:)` for parser + kanban transitions |
| STP-11 | **P2** | `NDISContainerViewModelTests.swift:250-264` | async-tests: avoid poll loops | Custom `assertEventually` (80×25ms) — flakiness under load | `confirmation()` or `@MainActor` synchronous refresh API |
| STP-12 | **P2** | `CalendarDisplayItemsGenerationTests.swift:49` | async-tests: time limits | `Task.sleep(80ms)` with no `.timeLimit` | `@Test(.timeLimit(.minutes(1)))` on async refresh tests |
| STP-13 | **P3** | `CurrencyFormattingTests.swift:8-9` | Assertions clarity | `#expect(formatted.contains("45") \|\| contains("4"))` is weak | Exact format string or snapshot |
| STP-14 | **P3** | 0 files | new-features: attachments, `.bug`, exit tests | No regression artifacts or bug traits | Attach CSV/PDF fixtures; `.bug("…")` on fixed regressions |
| STP-15 | **P3** | `InvoiceEditorAccessibilityAndNavigationTests.swift:138,144` | migrating-from-xctest: `XCTUnwrap` → `#require` | Mixed XCTest unwrap in otherwise modern file | `let itemID = try #require(items.first?.id)` |

### PrioritizedFixes (Top 3)

1. **Migrate BillingHub + Data NDIS suites to Swift Testing** — highest business risk, partial migration already (`BillingHubWorkflowActorTests`).
2. **Eliminate `try!` setup and `#expect(!…)`** across Swift Testing files before expanding migration.
3. **Replace 20 `setUp`/`tearDown` files** with struct `init() throws` + in-memory container per test.

### TestGaps (swift-testing-pro lens)

| Domain | Covered | Gap |
|--------|---------|-----|
| Billing / Kanban | Strong (10+ BillingHub files) | `BillingHubViewModel` drag-drop persistence E2E still mostly XCTest |
| NDIS integration | Strong Data layer | Feature.NDIS UI VM only XCTest + polling |
| Persistence / migrations | Strong (15+ migration/round-trip) | CloudKit/sync conflict paths untagged/unfiltered |
| Multi-window | Good ST coverage (SceneStorage, NavigationManager) | No Swift Testing for `WorkspaceNavigationRestorationTests`; no 3+ window stress |
| Async concurrency | Partial | No `confirmation()` anywhere; actor isolation untested under parallel ST |

---

## 2. swift-testing

**SkillCoverage: 32%**

Scored against Agent Behavior Contract, F.I.R.S.T., fixtures, test doubles, organization, integration pyramid. Good domain tests and DI at call sites; weak fixture/double placement and repeatability.

### Strengths

- **Protocol DI in billing:** `NDISBillingIntegrationServiceProtocol` injected into `BillingHubViewModel` / `BillingHubWorkflowActor` — testable without live NDIS.
- **Integration depth:** `NDISBillingIntegrationServiceTests`, `InvoiceModelActorIntegrationTests`, `AllDataComplianceRoundTripTests` exercise real SwiftData stacks.
- **Feature-aligned layout:** Tests live in package test targets mirroring production modules (BillingHub, Calendar, Data, AppShell).
- **State verification dominant:** Most tests assert persisted state / projections, not call-order mocks.
- **Deterministic IDs in places:** `NDISContainerViewModelTests` uses fixed UUID strings for catalogue items.
- **DEBUG test hooks (partial):** `TravelChargeAutomationService+TestHooks.swift` exposes internal logic under `#if DEBUG` — correct placement pattern.
- **Multi-window isolation tests:** `AppNavigationManagerTests` + `WorkspaceSceneStorageRoundTripTests` verify independent window state (F.I.R.S.T. Isolated).

### Findings

| ID | Sev | Location | Rule | Why | Fix |
|----|-----|----------|------|-----|-----|
| ST-1 | **P0** | 0 files in `Packages/**/Sources` | fixtures.md: `.fixture()` near models, `#if DEBUG` | No shared fixtures; every test builds entities inline | Add `Client.fixture()`, `Session.fixture()`, `Invoice.fixture()` on Core/Data models |
| ST-2 | **P0** | `Core/.../NDISBillingIntegrationService.swift:4-6` (no DEBUG stub) vs 3 test-file copies | test-doubles.md: doubles near interface | Stubs live in test targets only; triplicated | `NDISBillingIntegrationServiceSpyingStub` in Core `#if DEBUG` |
| ST-3 | **P1** | 98 XCTest files | Contract #1: Swift Testing for new tests | New BillingHub/NDIS work still XCTest (`BillingHubPhase2HonestyTests` 741 lines) | New tests → `@Test`; migrate on touch |
| ST-4 | **P1** | `NDISClaimTypeMapperTests.swift:40-42`, `NDISBillingIntegrationServiceTests.swift:425-426`, widespread | fixtures.md: fixed dates, not `Date()` | Repeatability risk; time-dependent NDIS batches | Fixed epoch dates or injectable `Clock` |
| ST-5 | **P1** | `NDISContainerViewModelTests.swift:250-264` | F.I.R.S.T. Repeatable | Poll loop up to 2s — CI flake risk | Drive VM refresh synchronously or use `@MainActor` test helper |
| ST-6 | **P1** | `AppIntentTests.swift:14,32` | F.I.R.S.T. Isolated | Mutates `AppIntentModelAccess.shared`, `WorkspaceIntentDeliveryCenter.shared` | Inject dependencies; reset in `init`/`deinit` or `@Suite(.serialized)` + explicit reset |
| ST-7 | **P2** | `DataInterfacesSmokeTests.swift:25-45` | test-doubles.md: placement | Stubs private to test file; not reusable across packages | Move to `DataInterfaces` `#if DEBUG` |
| ST-8 | **P2** | `SessionModificationThisAndFutureTests.swift:301` | test-doubles.md: `SpyingStub` naming | `StubCalendarEventService` in test file only | `CalendarEventServiceSpyingStub` beside protocol |
| ST-9 | **P2** | All integration tests (e.g. `NDISBillingIntegrationServiceTests`, `InvoiceModelActorIntegrationTests`) | integration-testing.md: `.tags(.integration)` | Cannot filter slow/integration runs | `@Suite(.tags(.integration))` on round-trip suites |
| ST-10 | **P2** | `BillingHubPhase2HonestyTests.swift`, `BillingHubSmokeTests.swift` | Arrange-Act-Assert | 700+ line XCTestCase; helpers mixed with tests | Split helpers to `BillingHubTestSupport.swift`; mark AAA sections |
| ST-11 | **P2** | `WorkspaceUISmokeTests.swift:15-30` | Contract: don't test views directly | Instantiates `NativeAddressSearchField` (SwiftUI) | Test view model / readiness logic only |
| ST-12 | **P2** | `Feature.NDIS/Tests` (2 files only) | Test pyramid / Timely | Thin Feature.NDIS coverage vs heavy Data NDIS | Add catalogue import, price sync, selection VM ST tests |
| ST-13 | **P2** | `WorkspaceNavigationRestorationTests.swift` (XCTest) | Multi-window gap | Path sanitization untested in Swift Testing multi-window flow | Add ST integration: restore → sanitize → per-window apply |
| ST-14 | **P3** | Helper naming inconsistency | test-doubles taxonomy | `Stub*` vs `Test*` vs inline builders (`makeSession`) | Standardize: builders = fixtures, `*SpyingStub` = doubles |
| ST-15 | **P3** | `UpdateInvoiceStatusTests.swift` only | parameterized-tests.md | Duration parser, claim types, status transitions could parameterize | Expand `@Test(arguments:)` to Core/NDIS enums |

### PrioritizedFixes (Top 3)

1. **Add `#if DEBUG` fixtures on Core models** (`Client`, `Session`, `Invoice`, `NDISItem`) — cuts boilerplate in 50+ files.
2. **Colocate `NDISBillingIntegrationServiceSpyingStub`** (and Calendar event stub) with protocols — remove 3× duplication.
3. **Tag integration suites** + fix `Date()` / polling in NDIS Feature tests for F.I.R.S.T. Repeatable.

### TestGaps (swift-testing lens)

| Domain | Current Tests | Gap | Priority |
|--------|---------------|-----|----------|
| **Billing** | 10 BillingHub + pipeline progress | Bulk export hash → kanban refresh integration; payment reconciliation | High |
| **NDIS** | 15+ Data, 2 Feature.NDIS | Catalogue price override UI; BPR export E2E; claim-type matrix parameterized | High |
| **Persistence** | Migrations, RelationshipDeletion, round-trips | CloudKit disabled bootstrap; concurrent ModelActor writes | Medium |
| **Multi-window** | SceneStorage ST, NavigationManager ST | Inspector per-window; template editor mock isolation (`WorkspaceCompositionTests:252` XCTest only); restoration after entity delete | Medium |
| **DI / doubles** | Protocol injection in billing | No shared DEBUG stubs; EventKit/Geocoding fakes scattered | High |
| **Fixtures** | Per-file `makeSession`/`insertClient` | No model-level `.fixture()`; random UUIDs everywhere | High |

---

## Cross-Skill Summary

| Dimension | swift-testing-pro | swift-testing |
|-----------|------------------:|--------------:|
| **SkillCoverage** | 18% | 32% |
| **Framework mix** | 10% ST / 89% XCTest | Same |
| **Fixtures** | N/A (not emphasized) | 0% — critical gap |
| **Test doubles placement** | Duplication flagged | 0% near interfaces |
| **Billing coverage** | Good (needs migration) | Good (needs fixtures/tags) |
| **NDIS coverage** | Good Data, weak Feature ST | Good Data, weak Feature |
| **Persistence** | Strong | Strong |
| **Multi-window** | Best modern examples exist | Good start, gaps in restoration |

**Migration wedge (recommended order):**

1. `UpdateInvoiceStatusTests` pattern → Data import/NDIS mappers  
2. `BillingHubWorkflowActorTests` pattern → remaining BillingHub XCTest files  
3. `WorkspaceSceneStorageRoundTripTests` pattern → AppShell workspace XCTest  
4. Add fixtures + DEBUG stubs before bulk migration (swift-testing contract)

No code was modified. Audit is read-only.

[REDACTED]