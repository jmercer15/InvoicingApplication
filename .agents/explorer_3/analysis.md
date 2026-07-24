# Project Structure, Dependency Graph, Architectural Rules, and Test Baseline Report

## Executive Summary
This report presents a thorough investigation of the `InvoicingApplication` repository architecture, package dependency graph, guardrail validation script (`scripts/architecture-check.sh`), and automated test suite baseline across `Feature.Invoices`, `Feature.InvoiceTemplateEditor`, and the main `InvoicingApplication` App target.

All 6 architectural rules enforced by `architecture-check.sh` were verified against source code and found to be **100% compliant**. A critical flaw was discovered in `scripts/architecture-check.sh`: it relies on `rg` (ripgrep) without verifying its existence, leading to silent failures (`rg: command not found`) while reporting false success.

The test suite baseline for `Feature.Invoices`, `Feature.InvoiceTemplateEditor`, and `InvoicingApplication` passed with **195 total tests and 0 failures**.

---

## 1. Architectural Guardrails Analysis (`scripts/architecture-check.sh`)

### Script Mechanics & Rules Summary
The `scripts/architecture-check.sh` script enforces 6 distinct architectural constraints to preserve modularization integrity, data persistence safety, and macOS windowing constraints.

| # | Rule Name | Regex Pattern / Command | Target Files | Enforced Constraint & Rationale |
|---|-----------|-------------------------|--------------|---------------------------------|
| 1 | Forbidden AppShell Imports | `^\s*import\s+AppShell\b` | `Packages/Feature.*/**/*.swift` | Feature packages must remain decoupled from `AppShell`. |
| 2 | Constrained Dependency Injection | `workspaceStandardServicesEnvironment(` | `Packages/**/*.swift` | Injection strictly limited to bridge points: `AppDependencyInjection.swift` and `WorkspaceStandardServicesInjection.swift`. |
| 3 | Safe Identifier Resolution | `self\[[^]]+, as:|\.model\(for:` | `Packages/**/*.swift` (excl. `Tests`) | Direct `PersistentIdentifier` materialization traps on stale IDs. Bounded `FetchDescriptor` required. |
| 4 | Feature ModelContainer Isolation | `ModelContainer(` | `Packages/Feature.*/Sources/**/*.swift` (excl. `*Preview*.swift`) | Feature source must not instantiate `ModelContainer`; container creation belongs strictly to `Data` composition layer. |
| 5 | Single Window Search Host | `\.searchable\s*\(` | `Packages/AppShell/Sources`, `Packages/Feature.*/Sources` | macOS windowing requires a single window-level owner (`WorkspaceSearchHost.swift`). |
| 6 | Invoice Template Preference Isolation | `InvoiceTemplatePreferenceStore` | `Packages/Feature.InvoiceTemplateEditor/Sources` | Allowed only in `Data/InvoiceTemplatePreferenceStore.swift`, `InvoiceEditorStore.swift`, and `Views/InvoiceRootView.swift`. |

### Critical Finding: Script Dependency Defect
- **Issue**: `architecture-check.sh` executes `rg` (ripgrep) commands. If `rg` is not installed on the host system (as is true in this environment), line 20 prints `./scripts/architecture-check.sh: line 20: rg: command not found`, while lines 8, 38, 50, 62, 83 fail silently (stderr redirected to `/dev/null` or piped to `grep -q "."`).
- **Impact**: The script reports `✅ Architecture check completed.` even when `rg` fails to run, creating a false-positive safety check.
- **Recommendation**: Update `architecture-check.sh` to check for `rg` availability (`command -v rg >/dev/null 2>&1 || { echo "❌ rg is required"; exit 1; }`) or provide a `grep`/`git grep` fallback.

### Independent Code Verification Results
Using direct code search tools across all source files:
- **Rule 1 (AppShell imports)**: 0 occurrences in `Packages/Feature.*`. PASS.
- **Rule 2 (DI callsites)**: 5 occurrences, all in `AppDependencyInjection.swift` (lines 27, 36) and `WorkspaceStandardServicesInjection.swift` (lines 36, 45, 58). PASS.
- **Rule 3 (Unsafe ID materialization)**: 0 occurrences in non-test production source. PASS.
- **Rule 4 (ModelContainer creation)**: 0 occurrences in feature source files; restricted to `ModelContainerFactory.swift` (and unit tests). PASS.
- **Rule 5 (Search host ownership)**: 1 occurrence in `WorkspaceSearchHost.swift` (line 15). PASS.
- **Rule 6 (Template preference store)**: Strictly limited to `InvoiceTemplatePreferenceStore.swift`, `InvoiceEditorStore.swift`, `InvoiceRootView.swift`, and test files. PASS.

---

## 2. Package Dependency Graph & Module Hierarchy

### Dependency Topology

```
                  ┌──────────────────────────────┐
                  │    InvoicingApplication      │ (App Target)
                  └──────────────┬───────────────┘
                                 │
                                 ▼
                  ┌──────────────────────────────┐
                  │          AppShell            │
                  └──────────────┬───────────────┘
          ┌──────────────────────┼──────────────────────┐
          ▼                      ▼                      ▼
┌───────────────────┐  ┌───────────────────┐  ┌───────────────────┐
│ Feature.Invoices  │  │  Feature.Clients  │  │ Feature.Settings  │ ... (Other Features)
└─────────┬─────────┘  └─────────┬─────────┘  └─────────┬─────────┘
          │                      │                      │
          │ ┌────────────────────┘                      │
          ▼ ▼                                           │
┌───────────────────┐                                   │
│    WorkspaceUI    │                                   │
└─────────┬─────────┘                                   │
          │                                             │
          ▼                                             │
┌───────────────────────────────────────────────────────┼───────────────────┐
│                       SharedUI                        │                   │
└───────────────────────────────────┬───────────────────┘                   │
                                    │                                       │
                                    ▼                                       ▼
┌───────────────────────────────────────────────────────────────────────────────┐
│                                    Data                                       │
└───────────────────────────────────┬───────────────────────────────────────────┘
                                    │
                                    ▼
┌───────────────────────────────────────────────────────────────────────────────┐
│                               DataInterfaces                                  │
└───────────────────────────────────┬───────────────────────────────────────────┘
                                    │
                                    ▼
┌───────────────────────────────────────────────────────────────────────────────┐
│                                    Core                                       │
└───────────────────────────────────────────────────────────────────────────────┘
```

### Key Package Relationships Detailed

1. **`InvoicingApplication` (App Target)**
   - Entry point: `InvoicingApplicationApp.swift`
   - Direct Dependencies: `AppShell`
   - Instantiates root `@State` properties (`AppSession`, `ApplicationWorkspaceContext`, `ToolWindowPresenceRegistry`) and mounts `InvoicingApplicationSceneTree`.

2. **`AppShell` Package**
   - Products: `AppShell`
   - Dependencies: `Core`, `Data`, `SharedUI`, `WorkspaceUI`, `Feature.Settings`, `Feature.BillingHub`, `Feature.Calendar`, `Feature.NDIS`, `Feature.Clients`, `Feature.Invoices`, `Feature.InvoiceTemplateEditor` (target `InvoiceTableLayoutEditor`).
   - Role: System assembly, scene tree definition, window host management, and dependency injection wiring.

3. **`Packages/Feature.Invoices` Package**
   - Products: `Feature_Invoices`
   - Dependencies: `Core`, `Data`, `SharedUI`, `Feature.InvoiceTemplateEditor` (`InvoiceTableLayoutEditor`)
   - Role: Invoice list management, queries, persistence commands, and embedding of invoice editor components.

4. **`Packages/Feature.InvoiceTemplateEditor` Package**
   - Products: `InvoiceTableLayoutEditor`
   - Target Dependencies: `Core` (production target `InvoiceTableLayoutEditor` depends ONLY on `Core`).
   - Test Target Dependencies: `InvoiceTableLayoutEditor`, `Core`, `Data`.
   - Role: Low-level invoice layout, pagination, document preview generation, and invoice preference defaults.

5. **`Packages/WorkspaceUI` Package**
   - Products: `WorkspaceUI`
   - Dependencies: `Core`, `Data`, `SharedUI`
   - Role: Shared workspace components, multi-window layout primitives, and standard service injection wrappers.

6. **`Packages/SharedUI` Package**
   - Products: `SharedUI`
   - Dependencies: `Core`
   - Role: Shared UI elements, `AppNavigationManager`, navigation history tracking, and reusable design assets.

7. **`Packages/Data` Package**
   - Products: `Data`
   - Dependencies: `Core`, `DataInterfaces`, `CoreXLSX` (external SPM dependency)
   - Role: Persistence implementation, SwiftData models, `ModelContainerFactory`, model actors, and data use cases.

8. **`Packages/DataInterfaces` Package**
   - Products: `DataInterfaces`
   - Dependencies: `Core`
   - Role: Abstract data protocols and interfaces decoupling persistence implementations from higher-level features.

9. **`Packages/Core` Package**
   - Products: `Core`
   - Dependencies: None (Leaf package)
   - Role: Foundational types, base models, extensions, utilities.

---

## 3. Test Runners and Baseline Test Structure

### Test Suite Execution Mechanisms
1. **SPM Packages**: Executed via Swift Package Manager CLI:
   `swift test --package-path Packages/<PackageName>`
2. **Xcode App Target**: Executed via XcodeBuild CLI:
   `xcodebuild test -project InvoicingApplication.xcodeproj -scheme InvoicingApplication -destination 'platform=macOS'`

### Baseline Test Results Summary

| Target / Package | Test Runner | Test Suite Files | Test Count | Failure Count | Duration |
|------------------|-------------|------------------|------------|---------------|----------|
| `Feature.Invoices` | `swift test` | `InvoiceSnapshotRelatedDataTests.swift`<br>`InvoicesListQueryTests.swift`<br>`InvoicesPersistenceCommandsTests.swift` | 65 | 0 | ~0.65s |
| `Feature.InvoiceTemplateEditor` | `swift test` | `InvoiceEditorSeparationTests.swift`<br>`InvoiceModelActorIntegrationTests.swift`<br>`InvoicePaginationTests.swift` | 127 | 0 | ~1.51s |
| `InvoicingApplication` | `xcodebuild test` | `AppSessionTests.swift` | 3 | 0 | ~0.86s |
| **Total Baseline** | | | **195** | **0** | **~3.02s** |

### Test Structure & Coverage Highlights
- **`Feature.Invoices`**: Validates deep link resolution, filtering revisions, invoice deletion/creation gates, store total calculations, selection reconciliation, and SwiftData reload resilience.
- **`Feature.InvoiceTemplateEditor`**: Validates document pagination, line item pagination boundaries, draft persistence, workspace transition handoffs, payee backfilling, and first-class field overrides.
- **`InvoicingApplication`**: Validates `AppSession` state machine transitions (`uninitialized` -> `bootstrapping` -> `ready` / `failed`) and duplicate bootstrap prevention.

---

## 4. Summary & Recommendations

1. **Fix `scripts/architecture-check.sh` Guardrail**:
   Add a pre-check `command -v rg >/dev/null 2>&1 || { echo "❌ ERROR: ripgrep (rg) is not installed."; exit 1; }` so missing binaries cause immediate failure instead of reporting false pass results.
2. **Maintain Strict Dependency Boundaries**:
   Ensure `Feature.InvoiceTemplateEditor` (`InvoiceTableLayoutEditor`) continues to depend only on `Core` in production targets, avoiding unwanted persistence coupling.
3. **Continuous Integration Verification**:
   Incorporate both `swift test` for SPM packages and `xcodebuild test` for the app bundle into the automated verification pipeline (`scripts/refactor-verify.sh`).
