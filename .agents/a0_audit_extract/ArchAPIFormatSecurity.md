# InvoicingApplication — Four-Skill Read-Only Audit

Scope: `Packages/{Core,DataInterfaces,SharedUI,AppShell}` + cross-package patterns. Ignored `.build/` / `BuildData/`. Sampled ~120+ Swift files, public API surfaces, formatter usage, layering, export/PDF paths.

---

## 1. Swift API Design Guidelines

**SkillCoverage: 58%**

Guidelines partially met. Strong navigation/coordination APIs; weak documentation and naming consistency on domain/public utility surfaces.

### Strengths

- **`AppNavigationManager`** — exemplary public API: summary docs, symbol references, clear `navigateTo` vs `selectTab` semantics, fluent routing helpers.
- **DataInterfaces protocols** (`InvoiceDigesting`, `StoreChangeMonitoring`, `ClientRelationshipDeleting`) — concise role-based summaries; implementation hidden behind abstractions.
- **`CurrencyFormatting` / `MeasurementFormatting`** — side-effect-free noun-phrase naming; clear intent at call site.
- **`InvoiceTemporaryPDF.discard()`** — imperative verb for mutating cleanup; paired with value-type wrapper.
- **`AppDependencyInjection.withAppDependencies(_:)`** — labeled defaulted param; readable composition-root API.
- **Domain enums** (`GSTCode`, `BPRClaimTypeCode`) — terminology matches NDIS domain precedent.

### Findings

| ID | Sev | Finding |
|----|-----|---------|
| AD-1 | P2 | **`PhoneNumberFormatter`** public class in SharedUI with 280+ lines of `print()` debug logging in `didSet`/init — pollutes public API contract, noisy in production, `@Observable class` not value-type formatter. |
| AD-2 | P2 | **`Client.phone` / `phoneNumber`** legacy alias pair on `@Model` — duplicate accessors violate “omit needless words” and confuse which to use at call sites. |
| AD-3 | P2 | **Core domain structs** (`NDISParticipantInfo`, `NDISServiceInfo`, etc.) — public with no per-member or behavior docs; skill requires doc comment on every declaration. |
| AD-4 | P2 | **`ReferenceDataFetching`** returns `[PersistentIdentifier]` — leaks SwiftData type into interface layer; parameter/associated-type naming by framework not role. |
| AD-5 | P3 | **`SharedUI/Utilities.swift`** exposes `DateFormatter.shortDate`, `NumberFormatter.currency` as public static legacy formatters — encourages deprecated patterns at shared API boundary. |
| AD-6 | P3 | **`InvoiceDataExporter.escapeCSVField`** — unlabeled `_ value:` fine internally, but public free function without summary; skill prefers methods on types unless special-case. |
| AD-7 | P3 | **`DataExporterActor.exportClients()`** etc. — method names omit entity scope clarity (`exportClientsToJSON` would read clearer); no `Throws`/return docs. |
| AD-8 | P3 | **`GeocodingServiceProtocol.geocodeAddressString(_:)`** — unlabeled `String` param; role noun (`addressString`) helps but first-arg label omission borderline for non-phrase grammar. |
| AD-9 | P3 | **`AppRuntime.Services`** — nested public struct but members lack individual documentation; container doc only. |
| AD-10 | P3 | **`InvoiceDataExporter.exportCSV`** — local var named `shortDateFormatter` holds `ISO8601DateFormatter`; name contradicts semantics (confuses readers/reviewers). |
| AD-11 | P3 | **`ClientRelationshipDeleting.deleteClient(_:deleteSessions:)`** — good labels; protocol lacks `- Throws:` markup for failure modes. |
| AD-12 | P3 | **`FoldPaperContainer`, `TreeItem`** — public UI components without summary comments describing composition intent. |

### PrioritizedFixes (Top 3)

1. **Strip debug logging from `PhoneNumberFormatter`; consider `struct` + `FormatStyle` or narrow to internal module** — highest public-surface harm.
2. **Document Core/DataInterfaces public protocols and domain input structs** — batch-add `///` summaries + `- Throws`/`Returns` where applicable.
3. **Deprecate/remove public `DateFormatter`/`NumberFormatter` extensions in SharedUI** — redirect to `CurrencyFormatting`; shrink legacy API footprint.

---

## 2. Swift FormatStyle

**SkillCoverage: 38%**

Modern FormatStyle adopted in newer billing/travel code; legacy formatters and `String(format:)` still dominate UI, export, and shared utilities.

### Strengths

- **`CurrencyFormatting.display(_:code:locale:)`** — `Decimal` + `.formatted(.currency(code:).locale(locale))`; correct pattern.
- **`MeasurementFormatting`** — `.formatted(.number.precision(...))` for km/min/hours.
- **BillingHub / Calendar / Invoices VMs** — widespread `.formatted(.dateTime...)` and `.formatted(.currency(code: "AUD"))`.
- **`MonthDayCellView`** — `Text(date, formatter: Self.accessibilityDateFormatter)` (partial SwiftUI integration).
- **Invoice CSV dates** — `ISO8601DateFormatter` with `.withFullDate` for machine-readable export (fixed-format exception reasonable).

### Findings

| ID | Sev | Finding |
|----|-----|---------|
| FS-1 | P1 | **`SharedUI/Utilities.swift`** — public `DateFormatter`/`NumberFormatter` static singletons; direct skill anti-pattern at shared boundary. |
| FS-2 | P1 | **`NumberFormatter.currency.string(from:)`** in `BillingHubAddTravelPanel`, `BillingHubViewModel+Reordering` — legacy currency display bypasses `CurrencyFormatting`. |
| FS-3 | P1 | **`InvoiceFormatting.swift` / `InvoiceDateFormatter`** — 4× cached `DateFormatter` for UI document dates; should use `Date.FormatStyle` or shared `FormatStyle` config. |
| FS-4 | P2 | **`String(format: "%.2f", ...)`** in `InvoiceDataExporter`, `DataExporterActor`, `BPRCSVWriter` — ~15 call sites for currency/quantity; use `Decimal.formatted(.number.precision(...))`. |
| FS-5 | P2 | **`Text("$\(invoice.totalAmount, specifier: "%.2f")")`** in `CompactRowViews` — skill prefers `Text(amount, format: .currency(code:))`. |
| FS-6 | P2 | **Calendar month/week views** — 6+ private `DateFormatter` caches (`MonthDayCellView`, `WeekHeaderComponents`, etc.) duplicating locale logic. |
| FS-7 | P2 | **`NDISChangesSummaryView`** — `String(format: "%.1f%%", ...)` for percent display; use `.formatted(.percent.precision(...))`. |
| FS-8 | P2 | **`BulkClaimBuilderActor`** — `String(format: "%03d:%02d", hours, minutes)`; use `Duration.formatted(.time(pattern: .hourMinute))`. |
| FS-9 | P3 | **`EventKitSyncService` / `EventKitSyncActor`** — multiple `ISO8601DateFormatter` + legacy `DateFormatter`; machine sync tags OK but duplicated config. |
| FS-10 | P3 | **`BPRCSVWriter.sha256Hex`** — `String(format: "%02x", $0)` for hex digest; acceptable non-locale byte formatting (low priority). |
| FS-11 | P3 | **`TravelChargeAutomationService+PricingAndNotes`** — 8× `String(format:)` in note strings; migrate to `MeasurementFormatting` / currency FormatStyle. |
| FS-12 | P3 | **Mixed `Double` for currency** in exports (`InvoiceExportDTO.totalAmount: Double`) — skill recommends `Decimal` for currency values end-to-end. |

### PrioritizedFixes (Top 3)

1. **Remove/replace public legacy formatters in `SharedUI/Utilities.swift`** — unblock all feature consumers.
2. **Migrate invoice editor date display (`InvoiceDateFormatter`) to `Date.FormatStyle`** — highest user-visible legacy cluster.
3. **Replace `String(format:)` currency paths in `InvoiceDataExporter` + `DataExporterActor` with `Decimal.formatted`** — export correctness + locale consistency.

---

## 3. Swift Architecture (Deep Refactor Mode: MVVM + Clean + Multi-Window)

**SkillCoverage: 62%**

### ArchitectureVerdict

| Aspect | Result |
|--------|--------|
| **Fit** | **MVVM (primary) — fit** for SwiftUI `@Observable` ViewModels, per-feature state, async coordinators |
| **Secondary** | **Scene-session routing (Coordinator-like) — fit** for multi-window macOS |
| **Clean Architecture** | **Partial mismatch** — intended layering undermined by Feature→Data imports and SwiftData-in-Core |
| **Overall** | **Pragmatic modular MVVM with incomplete Clean boundaries** — workable; refactor path clear |

**Reasons:** Multi-window isolation via `WorkspaceSceneSession` per `WindowGroup` is well-designed. MVVM decomposition (BillingHub coordinators, `@ModelActor` background work) aligns playbook. Clean dependency rule violated: all 7 Feature packages import `Data`; `Core` hosts `@Model` entities + SwiftData services; views hold `@Environment(\.modelContext)`.

### Strengths

- **SPM module graph** — `AppShell` composition root, `Core`, `Data`, `DataInterfaces`, feature slices, `SharedUI`.
- **Per-window state** — `WorkspaceWindowRoot` + `WorkspaceSceneSession` give independent navigation/VM caches per workspace window.
- **Multi-scene macOS** — `InvoicingApplicationSceneTree`: Workspace `WindowGroup`, Settings, Inspector/Activity `UtilityWindow`s.
- **Actor isolation** — `DataExporterActor`, `InvoiceDigestActor`, `BillingHubWorkflowActor`, `@ModelActor` pattern for background persistence.
- **Protocol seams started** — `InvoiceDigesting`, `ReferenceDataFetching`, `StoreChangeMonitoring`, `ClientRelationshipDeleting`.
- **Snapshot pattern** — `ClientServiceSnapshot`, `InvoiceSnapshot` for cross-actor value transfer.
- **Testing** — broad test coverage per package (BillingHub honesty tests, calendar continuity, Data use-case tests).

### Findings

| ID | Sev | Finding |
|----|-----|---------|
| AR-1 | P1 | **All Feature packages depend on `Data`** — direct `import Data` in ViewModels/views; bypasses use-case/repository boundary; Features should depend on `DataInterfaces` (+ Core) only. |
| AR-2 | P1 | **`Core` contains `@Model` entities + SwiftData services** (`TravelChargeAutomationService+SwiftData`, `ClientEntity` imports SwiftUI) — domain not framework-independent; violates Clean entity/use-case purity. |
| AR-3 | P1 | **Views access `ModelContext` directly** — `BillableDraftDetailView`, `RelationshipsColumns`, Settings claim views, etc.; MVVM anti-pattern (View→Persistence). |
| AR-4 | P2 | **No explicit Use Cases layer** — business orchestration lives in services/actors/view-model extensions; Clean playbook expects named use-case types with protocol boundaries. |
| AR-5 | P2 | **`DataInterfaces` leaks SwiftData** — `PersistentIdentifier` in public protocol; interface adapters should expose domain IDs (`UUID`) not persistence IDs. |
| AR-6 | P2 | **`BillingHubViewModel` imports 6 modules** incl. `Data`, `InvoiceTableLayoutEditor` — god-boundary; coordinator split helps but root VM still wide. |
| AR-7 | P2 | **`ClientRelationshipDeleting` takes live `Client` model** — cross-layer model references in protocol; prefer ID + actor resolution. |
| AR-8 | P3 | **`AppRuntime.Services` exposes concrete Data types** (`EventKitSyncService`, `CloudKitSyncMonitor`) — composition root OK, but features reaching through env may skip abstractions. |
| AR-9 | P3 | **Duplicate NDIS billing** — `Core.NDISBillingIntegrationService` + `Data.NDISBillingIntegrationService`; unclear single ownership. |
| AR-10 | P3 | **Feature.InvoiceTemplateEditor lacks `DataInterfaces` dep** — only `Data`; tightest coupling to persistence implementation. |
| AR-11 | P3 | **Settings window shares `AppRuntime` model container** — correct for data, but settings + workspace contexts not fully isolated at persistence boundary. |
| AR-12 | P3 | **Navigation history in SharedUI, workspace sessions in AppShell** — reasonable split; deep-link intent delivery adds cross-module coupling (`WorkspaceRoutingIntent`). |

### PrioritizedFixes (Top 3)

1. **Stop Feature→Data imports** — expand `DataInterfaces` (invoice ops, export, billing workflows); wire implementations only in AppShell.
2. **Extract pure domain from Core** — move `@Model` entities to `Data`/persistence module; keep Sendable snapshots + protocols in Core; remove `import SwiftUI` from entities.
3. **Route persistence through ViewModels/actors** — eliminate `@Environment(\.modelContext)` from feature views; inject `@ModelActor` or protocol services.

### Incremental Migration Path

1. Audit Feature `import Data` sites → protocol per workflow.
2. Move `@Model` types out of Core (big-bang risky; do entity-by-entity with snapshot compatibility).
3. Introduce use-case structs in Data (`UpdateInvoiceStatus`-style tests already exist conceptually).
4. Keep `WorkspaceSceneSession` as multi-window anchor — no change needed.

---

## 4. Swift Security Expert

**SkillCoverage: 48%**

App is local-first macOS invoicing with CloudKit sync — no OAuth/API-key storage found. Security posture strong on temp PDFs; gaps on export PII handling and absence of keychain infrastructure for future secrets.

### Strengths

- **No secrets in UserDefaults/plist/source** — scanned patterns; `@AppStorage` used for UI prefs (tax rate, tips), not credentials.
- **`InvoiceTemporaryPDFWorkspace`** — `0o700`/`0o600` permissions, `isExcludedFromBackup`, UUID subdirs; deliberate temp-file hygiene.
- **`InvoiceTemporaryPDF.discard()` + `BillingHubMailComposer` deinit/finish** — temp PDF cleanup on mail share completion/cancel.
- **`BPRCSVWriter.sha256Hex`** — CryptoKit `SHA256` for export integrity (correct symmetric hashing use).
- **`DataExporterActor`** — background actor for export (not `@MainActor` keychain violation — N/A here).
- **No `LAContext.evaluatePolicy` standalone gate** — biometrics not used.
- **macOS app** — no missing `kSecUseDataProtectionKeychain` impact yet (no SecItem calls).

### Findings

| ID | Sev | Finding |
|----|-----|---------|
| SEC-1 | P1 | **Full-database export includes PII/financial data in plaintext** — `SwiftDataExportService.exportAllEntitiesToJSON`, `DataExporterActor.exportPayees()` exports bank BSB/account, NDIS numbers, emails, addresses with no encryption or user confirmation gate beyond save panel. OWASP M9 surface. |
| SEC-2 | P2 | **`InvoiceDataExporter` / `InvoiceExportDTO`** — exports `clientEmail`, `clientNDISNumber`, `businessABN` in JSON/CSV without field-level redaction option. |
| SEC-3 | P2 | **No Keychain infrastructure** — zero `SecItem*` usage; acceptable today (no stored credentials) but no protocol/actor wrapper for future API keys, mail tokens, or mTLS certs. |
| SEC-4 | P2 | **Temp PDF lacks `NSFileProtection` / explicit secure-delete** — POSIX perms good; no `FileManager` `.completeFileProtection` or overwrite-before-delete for sensitive PDFs on shared volumes. |
| SEC-5 | P3 | **User-chosen export paths** — `NSSavePanel` writes full JSON/CSV/XML to user-selected location with no post-export handling guidance (FileVault/user responsibility). |
| SEC-6 | P3 | **CloudKit sync** — participant PII synced via Apple infrastructure; client-side encryption model relies on Apple; out of keychain skill scope but audit-relevant for NDIS data. |
| SEC-7 | P3 | **No first-launch credential cleanup** — N/A without keychain items; becomes required if secrets added later (skill anti-pattern #10). |
| SEC-8 | P3 | **`PersistentStoreSanitizer` uses UserDefaults flag** — fine for migration state, not secrets. |
| SEC-9 | P3 | **Import paths read external files** — `UnifiedImportService` / CSV parsers; validate untrusted input size/schema (availability, not crypto). |
| SEC-10 | P3 | **Debug logging in `PhoneNumberFormatter`** — may log phone numbers to console in DEBUG-like always-on prints; PII in logs. |
| SEC-11 | P3 | **No certificate pinning / mTLS** — no network auth layer; N/A unless remote APIs added. |
| SEC-12 | P3 | **BPR CSV NDIS export** — `BPRCSVWriter` writes participant NDIS numbers to CSV by design (regulatory export); document sensitivity for users. |

### PrioritizedFixes (Top 3)

1. **Add export confirmation + sensitivity labeling** for full/PII-heavy exports (NDIS, bank details); optional field redaction for JSON/CSV.
2. **Harden temp PDF lifecycle** — consider secure delete, document retention policy, audit log when PDFs touch disk.
3. **Introduce Keychain actor wrapper (protocol-first)** before any credential feature — `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`, add-or-update pattern, OSStatus handling ready.

---

## Cross-Skill Summary Matrix

| Skill | Coverage | P0 | P1 | P2 | P3 |
|-------|----------|----|----|----|-----|
| API Design | 58% | 0 | 0 | 4 | 8 |
| FormatStyle | 38% | 0 | 3 | 5 | 4 |
| Architecture | 62% | 0 | 3 | 4 | 5 |
| Security | 48% | 0 | 1 | 3 | 8 |

**No P0 findings** — nothing immediately exploitable or blocking release; highest-impact themes are **Feature→Data coupling**, **legacy formatters at SharedUI boundary**, and **plaintext PII exports**.

---

## Reference Files Used

- `swift-api-design-guidelines-skill/SKILL.md` + fundamentals/parameters conventions
- `swift-format-style/SKILL.md` + anti-patterns guidance
- `swift-architecture-skill/SKILL.md` + `mvvm.md`, `clean-architecture.md` (Deep Refactor Mode)
- `swift-security-expert/SKILL.md` + Top-Level Review Checklist, anti-pattern scan table

[REDACTED]