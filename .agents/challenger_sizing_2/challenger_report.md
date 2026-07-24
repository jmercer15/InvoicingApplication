# Sizing Refactor Empirical Challenge Report

This report presents the empirical verification and adversarial stress-testing results for the sizing refactor.

## Challenge Summary

**Overall risk assessment**: LOW

The sizing refactor introduces a robust layout architecture that successfully resolves SwiftUI layout unreliability, height collapse, and infinite rendering loops. By establishing the deterministic CoreText-based `analyticGridHeight` as the single source of truth and floor, the view converges in a single pass and is invariant to live layout updates. Package test coverage is extensive and passes cleanly. Backward compatibility for older document models is preserved.

---

## Challenges

### [Low] Challenge 1: Column configurations during initial render

- **Assumption challenged**: Column widths are always fully resolved before grid rendering.
- **Attack scenario**: On initial appearance, when `gridWidth` is `0`, auto-sized columns might resolve to their minimum bounds or a default width (e.g. `20` pt) rather than the actual wrapped text widths, causing a transient vertical layout stretch.
- **Blast radius**: Visual layout pop/jank during the first render frame when columns transition from default width to text-measured width.
- **Mitigation**: Pre-compute `resolvedGridLayoutWidth` using `measureColumnContentWidths` to populate initial widths, which is already correctly implemented in `DocumentGridComponent.resolvedGridLayoutWidth(for:)` to fall back to the leaf container width or sum of auto-column content widths.

### [Low] Challenge 2: Missing styling fields in legacy templates

- **Assumption challenged**: Synthesized `Codable` compliance is sufficient to prevent decoding crashes for older template files.
- **Attack scenario**: If a new non-optional style field is added to `ComponentStyle` without an optional type or explicit custom decoding implementation, decoding old templates lacking that key will throw a decoding error.
- **Blast radius**: Deserialization failure when loading existing customer templates, resulting in data loss or editor crashes.
- **Mitigation**: `ComponentStyle` fields are initialized with default values in their property declarations. In Swift, compiler-synthesized `Codable` handles missing fields by assigning their default values, provided the fields are optional or custom decoder logic is implemented. Tests confirm that missing properties like `sectionHeightRatios` and `isVisible` fallback gracefully to default values.

---

## Stress Test Results

### 1. Layout Math Regression (CoreText Measurement)
- **Scenario**: Measure cell with long wrapping text at a narrow column width (`90` pt) with line limit capped vs. unlimited.
- **Expected behavior**: Wrapped multi-line cell must be taller than single-line capped cell.
- **Actual behavior**: Multi-line is taller (`XCTAssertGreaterThan` passes).
- **Pass/Fail**: PASS (Verified in `DocumentGridHeightReliabilityTests.testResolvedRowHeights_wrappedMultiLineCellIsTallerThanSingleLine`)

- **Scenario**: Mixed configurations of fixed-height and auto-height rows.
- **Expected behavior**: Fixed rows use configured size verbatim, auto-rows adjust to text.
- **Actual behavior**: Row 0 remained at fixed `73` pt, Row 1 measured to text height.
- **Pass/Fail**: PASS (Verified in `DocumentGridHeightReliabilityTests.testResolvedRowHeights_mixedFixedAndAutoRows`)

### 2. Document Serialization & Backward Compatibility
- **Scenario**: Decode a template JSON payload completely lacking the new `sectionHeightRatios` field.
- **Expected behavior**: Decodes successfully and restores section height ratios to default single-section `[1.0]`.
- **Actual behavior**: Successfully restored to `[1.0]` without errors.
- **Pass/Fail**: PASS (Verified in `InvoiceDocumentDataPersistenceTests.testSectionHeightRatios_defaultsToSingleSectionWhenMissingFromJSON`)

- **Scenario**: Decode a component JSON payload completely lacking the `isVisible` field.
- **Expected behavior**: Decodes successfully and defaults `isVisible` to `true`.
- **Actual behavior**: `isVisible` is evaluated as `true`.
- **Pass/Fail**: PASS (Verified in `InvoiceDocumentDataPersistenceTests.testComponentIsVisible_defaultsTrueWhenMissingFromJSON`)

### 3. SwiftUI Previews & Infinite Rendering Loop Prevention
- **Scenario**: Simulating noisy, out-of-order GeometryReader updates (`cellMeasuredHeight` and `renderedHeight`) mid-convergence.
- **Expected behavior**: Reconciled height remains pinned to the CoreText analytic height floor, ignoring intermediate layout noise.
- **Actual behavior**: Reconciled height remained invariant at `144` pt across all noisy passes.
- **Pass/Fail**: PASS (Verified in `DocumentGridHeightWiringTests.testReconciledGridHeight_isInvariantUnderOscillatingLiveMeasurements`)

- **Scenario**: Proposing layout updates under the size epsilon threshold (`0.5` pt).
- **Expected behavior**: Layout engine ignores changes smaller than epsilon to prevent rendering loops.
- **Actual behavior**: Proposals smaller than `0.5` pt are discarded by the layout engine.
- **Pass/Fail**: PASS (Verified in `TemplateLayoutEngineTests.testIgnoresSubEpsilonSizeChanges`)

### 4. Complete Package Test Suite Passage
- **Scenario**: Run unit tests across all package targets.
- **Expected behavior**: Clean compilation and 100% test passage.
- **Actual behavior**: All 10 package test targets passed with 0 failures:
  - `Core`: 15 tests passed
  - `Data`: 133 tests passed (2 skipped)
  - `SharedUI`: 27 tests passed
  - `AppShell`: 14 tests passed
  - `Feature.BillingHub`: 3 tests passed
  - `Feature.Clients`: 4 tests passed
  - `Feature.InvoiceTemplateEditor`: 160 tests passed
  - `Feature.Invoices`: 32 tests passed
  - `Feature.NDIS`: 12 tests passed
  - `Feature.Settings`: 6 tests passed
- **Pass/Fail**: PASS

---

## Unchallenged Areas

- **DTOMacros package** — Excluded from manual testing because it is a gitignored macro development directory and lacks a `Package.swift` manifest in the active branch.
- **Feature.Calendar, WorkspaceUI, DataInterfaces packages** — Excluded from test runner because they do not contain a `Tests` directory.
