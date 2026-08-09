# Audit Closeout Evidence Matrix (Zero-Waiver)

**Date:** 2026-07-29  
**Workstream:** Phase 7 gate — zero-waiver closeout  
**Ledger:** [audit-closeout-ledger.md](./audit-closeout-ledger.md)  
**Policy:** All findings **fix** with build/test evidence — **0 waive / 0 open / 0 partial**

---

## Verification Run (2026-07-29)

| Check | Result | Evidence |
|-------|--------|----------|
| macOS app build (`InvoicingApplication`, Debug) | **PASS** | `xcodebuild -project InvoicingApplication.xcodeproj -scheme InvoicingApplication -destination 'platform=macOS' build` → **BUILD SUCCEEDED** |
| `rg 'import XCTest' Packages` | **0** | Full Swift Testing migration complete |
| `rg 'DispatchQueue.global' Packages` | **0** | Structured concurrency only |
| `rg 'onTapGesture' Packages` | **0** | Button-based selection everywhere audited |

### Package test matrix

| Package | Result | Count |
|---------|--------|------:|
| Core | **PASS** | 37 |
| Data (UseCase + Service + BusinessLogic + Validation) | **PASS** | 212 (20 + 80 + 52 + 60) |
| DataInterfaces | **PASS** | 3 |
| SharedUI | **PASS** | 47 |
| AppShell | **PASS** | 47 |
| Feature.Clients | **PASS** | 9 |
| Feature.Settings | **PASS** | 6 |
| Feature.Invoices | **PASS** | 75 |
| Feature.BillingHub | **PASS** | 85 |
| Feature.InvoiceTemplateEditor | **PASS** | 156 |
| Feature.Calendar | **PASS** | 36 |
| Feature.NDIS | **PASS** | 12 |
| **Total SPM tests** | **PASS** | **725** |

---

## Architecture closeout (Phase 4b)

| Item | Result | Evidence |
|------|--------|----------|
| Feature_BillingHub → Data dep removed | **fix** | `Packages/Feature.BillingHub/Package.swift` — main target depends on `DataInterfaces` only; tests retain `Data` for `ModelContainerFactory` |
| ComplianceValidating boundary | **fix** | `any ComplianceValidating` in factory/VM/coordinator/workflow actor; AppShell wires `NDISComplianceValidator` |
| EntityPredicateBuilders dedup | **fix** | Canonical `PersistenceModels/Query/EntityPredicateBuilders.swift`; Data re-exports `typealias` only |
| AppMeshBackdrop preference key (SU-P3-2) | **fix** | `AppMeshBackdropMetricsPreferenceKey` publishes fallback GeometryReader size |
| BillingHubPhase2Honesty LOC (ST-10) | **fix** | Split into Fixtures (71) + Kanban (214) + ViewModel (178) + Workflow (266); all ≤350 LOC |

---

## Hotspot re-grep (2026-07-29)

| Hotspot | Count | Notes |
|---------|------:|-------|
| `import XCTest` in Packages | **0** | — |
| `DispatchQueue.global` in Packages | **0** | — |
| `onTapGesture` in Packages | **0** | — |
| Feature → Data in Package.swift | **11** | BillingHub main target removed; remaining deps are composition/test targets (Clients, Calendar, Invoices, InvoiceTemplateEditor, BillingHub tests) |
| Money `Double` on `@Model` entities | **0** | Phase 2 Decimal cutover; residual `taxRate: Double` on `InvoiceCreationDefaults` (non-persisted defaults struct) |
| `NumberFormatter` in UI sources | **6 files** | PhoneNumberFormatter + validated decimal fields + NDIS price utilities — not currency display singletons (A5 closed) |

---

## Waiver Register

**Empty.** Zero intentional deferrals. All ledger rows `decision=fix`.

---

## Residual Counts

| Severity | Open | Fix | Waive | Partial |
|----------|-----:|----:|------:|--------:|
| P0 | 0 | 8 | 0 | 0 |
| P1 | 0 | 42 | 0 | 0 |
| P2 | 0 | 68 | 0 | 0 |
| P3 | 0 | 36 | 0 | 0 |
| **Total** | **0** | **154** | **0** | **0** |

---

## Overall Closeout Verdict

**PASS — zero waive.**

- **154/154 fix** with build + test evidence  
- **0 open / 0 waive / 0 partial / 0 TRUE blockers**  
- macOS app **BUILD SUCCEEDED**; SPM matrix **725/725 PASS**  
- Evidence: this matrix + [audit-closeout-ledger.md](./audit-closeout-ledger.md)
