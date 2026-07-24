# System Integration & Architectural Handoff Report

## 1. Observation

- **Package Dependency Declarations (`Packages/Feature.Invoices/Package.swift:14-33` & `Packages/Feature.InvoiceTemplateEditor/Package.swift:8-29`)**:
  - `Feature.InvoiceTemplateEditor` builds library product `"InvoiceTableLayoutEditor"` target. It depends on `Core` and `Data`.
  - `Feature.Invoices` depends on `Core`, `Data`, `SharedUI`, and `.product(name: "InvoiceTableLayoutEditor", package: "Feature.InvoiceTemplateEditor")`.

- **AppShell Composition Bridge (`Packages/AppShell/Sources/AppShell/App/Composition/WorkspaceFeatureRegistries.swift:7-78` & `Packages/AppShell/Sources/AppShell/App/Scenes/Workspace/WorkspaceFeatureColumns.swift:48-225`)**:
  - `WorkspaceFeatureRegistries` instantiates `InvoicesFeature` per `WorkspaceSceneSession`, lazily vending `InvoicesContainerViewModel`.
  - `WorkspaceFeatureContentColumn` hosts `InvoicesContentColumn` for `.invoices` tab.
  - `WorkspaceFeatureDetailColumn` routes `.invoices` tab to `TableLayoutInvoiceEditorView` initialized with `selection` binding and `session: features.invoices.editorSession`.
  - `WorkspaceFeatureDetailColumn` routes `.invoiceTemplateEditor` tab to `TableLayoutInvoiceEditorView` initialized in `.template` workspace mode with mock document and preference editor controls.

- **Architecture Check Script (`./scripts/architecture-check.sh:14-106`)**:
  - `architecture-check.sh` executes 6 strict rules via `ripgrep`:
    1. **Forbidden AppShell imports in features**: `import AppShell` forbidden in `Packages/Feature.*`.
    2. **Constrained service injection**: `workspaceStandardServicesEnvironment` callsites restricted to `AppDependencyInjection.swift` and `WorkspaceStandardServicesInjection.swift`.
    3. **Unsafe identifier materialization**: `self[..., as:]` or `.model(for:)` forbidden in non-test source.
    4. **Feature-owned ModelContainer creation**: `ModelContainer(` forbidden in feature packages outside previews.
    5. **Workspace search ownership**: `.searchable(` restricted to `WorkspaceSearchHost.swift`.
    6. **Invoice template preference ownership**: `InvoiceTemplatePreferenceStore` restricted to template workspace / editor boundaries.

- **Build & Test Suite Execution (`xcodebuild` vs `swift test`)**:
  - Scheme inspection via `xcodebuild -list -project InvoicingApplication.xcodeproj`:
    - Project targets: `InvoicingApplication`, `InvoicingApplicationTests`.
    - Schemes: `InvoicingApplication`, `AppShell`, `Core`, `Data`, `DataInterfaces`, `Feature_BillingHub`, `Feature_Calendar`, `Feature_Clients`, `Feature_Invoices`, `Feature_NDIS`, `Feature_Settings`, `InvoiceTableLayoutEditor`, `SharedUI`, `WorkspaceUI`.
  - Command `swift test --package-path Packages/Feature.Invoices`: Passed 74 unit tests in 0.8s.
  - Command `swift test --package-path Packages/Feature.InvoiceTemplateEditor`: Passed 146 unit tests in 1.6s.
  - Command `xcodebuild test -project InvoicingApplication.xcodeproj -scheme InvoicingApplication -destination 'platform=macOS'` (with `BypassSandbox: true`):
    - Failed compilation in `Feature_Invoices` target on static property `isoDateFormatter` / `shortDateFormatter` in `InvoiceDataExporter.swift:149-159` due to Swift 6 strict concurrency checks (`ISO8601DateFormatter` non-sendable static stored property).

- **Shared Models & Cross-Package Interaction (`Packages/Feature.InvoiceTemplateEditor/Sources/InvoiceTableLayoutEditor/Data/CoreInvoiceAdapter.swift:1-312`)**:
  - `Core`: Provides DTO Snapshots (`InvoiceSnapshot`, `InvoiceItemSnapshot`, `ClientSnapshot`, `BusinessEntitySnapshot`), `AppTab`, `AppSelection`, `WorkspaceRoute`, and `WorkspaceServiceProtocols` (`WorkspaceInvoicePDFExporting`, `WorkspaceTemplateManaging`, `WorkspaceTemplateDataServing`).
  - `Data`: Owns `@Model` SwiftData persistence types (`Invoice`, `Client`, `Session`) and background actors (`InvoiceDigestActor`, `NDISComplianceValidator`).
  - `CoreInvoiceAdapter`: Encapsulates bidirectional mapping between `Core.Invoice` / `InvoiceSnapshot` and `InvoiceDocument` (including JSON-encoded `InvoiceDocumentConfigurationEnvelope` stored in `invoice.invoiceEditorStateData`).

## 2. Logic Chain

1. **Feature Integration Logic**:
   - `Feature.InvoiceTemplateEditor` provides rendering and editing engines (`TableLayoutInvoiceEditorView`, `InvoiceEditorSession`, `InvoiceEditorViewModel`, `InvoiceDocument`).
   - `Feature.Invoices` consumes `InvoiceTableLayoutEditor` to manage active selection and session state in `InvoicesContainerViewModel`.
   - `AppShell` connects both features into workspace scenes, using `TableLayoutInvoiceEditorView` for both live invoice editing (in `.invoices` tab) and template design (in `.invoiceTemplateEditor` tab).

2. **Architectural Rules Logic**:
   - Modernized SPM architecture segregates core data (`Core`, `Data`) from UI routing (`SharedUI`) and environment composition (`WorkspaceUI`).
   - Enforcement script `./scripts/architecture-check.sh` prevents layer violations (e.g. features calling `ModelContainer` or importing `AppShell`) and ensures thread safety by blocking direct unsafe `PersistentIdentifier` materializations (`self[id, as: ...]`).

3. **Test Suite & Build Logic**:
   - SPM package tests (`swift test --package-path Packages/Feature.Invoices` and `swift test --package-path Packages/Feature.InvoiceTemplateEditor`) run isolated package tests using SwiftPM defaults.
   - Project-level builds (`xcodebuild test -scheme InvoicingApplication`) compile all targets with strict Xcode Swift 6 settings. This reveals a static concurrency issue in `InvoiceDataExporter.swift` (`private static let isoDateFormatter: ISO8601DateFormatter`).

4. **Cross-Package Model Interaction Logic**:
   - Data boundaries between features rely on thread-safe value snapshots (`InvoiceSnapshot`) and adapter enums (`CoreInvoiceAdapter`).
   - Template configuration is stored inside `Invoice.invoiceEditorStateData` via `InvoiceDocumentConfigurationEnvelope`, ensuring legacy invoices remain visually stable while newly created invoices inherit defaults from `InvoiceTemplatePreferenceStore`.

## 3. Caveats

- **No source modifications performed**: Investigation was strictly read-only as required. The identified concurrency issue in `InvoiceDataExporter.swift` (`ISO8601DateFormatter` static property) remains unedited in source code.
- **Xcode test scheme coverage**: `InvoiceTableLayoutEditor` scheme in `InvoicingApplication.xcodeproj` is a target scheme without a test action configured; tests for `InvoiceTableLayoutEditor` are run via SPM package test commands (`swift test --package-path Packages/Feature.InvoiceTemplateEditor`).

## 4. Conclusion

- `Feature.Invoices` and `Feature.InvoiceTemplateEditor` are cleanly integrated via `InvoiceTableLayoutEditor` and `WorkspaceFeatureColumns` in `AppShell`.
- Architectural boundaries are strictly checked by `./scripts/architecture-check.sh` and documented in `.cursor/rules/`.
- Package unit test suites in `Packages/Feature.Invoices` (74 tests) and `Packages/Feature.InvoiceTemplateEditor` (146 tests) pass 100% green via `swift test`.
- Full project test suite via `xcodebuild` requires addressing the static `ISO8601DateFormatter` non-sendable error in `InvoiceDataExporter.swift` to pass full strict concurrency compilation under Xcode.

## 5. Verification Method

To verify these findings independently:

1. **Verify Architecture Script**:
   ```bash
   ./scripts/architecture-check.sh
   ```
   *Expected output*: `✅ Architecture check completed.`

2. **Verify SPM Unit Tests for Feature.Invoices**:
   ```bash
   swift test --package-path Packages/Feature.Invoices
   ```
   *Expected output*: `Executed 74 tests, with 0 failures`

3. **Verify SPM Unit Tests for Feature.InvoiceTemplateEditor**:
   ```bash
   swift test --package-path Packages/Feature.InvoiceTemplateEditor
   ```
   *Expected output*: `Executed 146 tests, with 0 failures`

4. **Verify Xcode Build / Scheme Behavior**:
   ```bash
   xcodebuild -list -project InvoicingApplication.xcodeproj
   ```
   *Expected output*: Shows target schemes including `InvoicingApplication`, `Feature_Invoices`, and `InvoiceTableLayoutEditor`.
